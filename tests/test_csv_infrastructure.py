"""Offline corruption/recovery contract tests; not MT5 runtime tests."""
import csv
import hashlib
import io
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from audit_trade_csv import audit_bytes, audit_file, schema_from_source


class CsvInfrastructureTests(unittest.TestCase):
    def setUp(self):
        self.schema = schema_from_source()
        self.values = dict.fromkeys(self.schema, '')
        self.values.update(SCHEMA_VERSION='RC1', SYMBOL='WDOX26', MAGIC='60002',
                           POSITION_ID='18446744073709551615', CLOSED='1', ACCOUNTING_RESOLVED='1')

    def data(self, rows=None, newline='\r\n', header=None):
        out = io.StringIO(newline='')
        writer = csv.writer(out, lineterminator=newline)
        writer.writerow(header or self.schema)
        for row in rows or [self.values]:
            writer.writerow([row.get(name, '') for name in self.schema])
        return out.getvalue().encode('cp1252')

    def audit(self, data):
        return audit_bytes(data, 'WDOX26', 60002, self.schema)

    def test_intact_and_large_position_id(self):
        result = self.audit(self.data())
        self.assertTrue(result.valid)
        self.assertEqual(result.position_ids, (2**64 - 1,))

    def test_line_ending_compatibility(self):
        for newline in ('\r\n', '\n', '\r'):
            with self.subTest(newline=newline):
                self.assertTrue(self.audit(self.data(newline=newline)).valid)

    def test_quoted_multiline_and_escaped_quotes(self):
        self.values['EXIT_REASON'] = 'SL, "proteção"\r\nconfirmada'
        self.assertTrue(self.audit(self.data()).valid)

    def test_truncation_is_not_success(self):
        result = self.audit(self.data()[:-5])
        self.assertFalse(result.valid)
        self.assertEqual(result.logical_row, 2)
        self.assertIn('UNTERMINATED', result.reason)

    def test_missing_columns_reports_expected_received_and_row(self):
        data = self.data()
        header, record = data.split(b'\r\n')[:2]
        record = b','.join(record.split(b',')[:-1])
        result = self.audit(header + b'\r\n' + record + b'\r\n')
        self.assertEqual((result.reason, result.logical_row), ('ROW_COLUMN_COUNT', 2))
        self.assertEqual(result.received_columns, result.expected_columns - 1)

    def test_incompatible_header(self):
        header = list(self.schema)
        header[0] = 'UNKNOWN_SCHEMA'
        self.assertIn('HEADER_FIELD_1', self.audit(self.data(header=header)).reason)

    def test_duplicate_position_is_uncertain(self):
        result = self.audit(self.data([self.values, self.values]))
        self.assertFalse(result.valid)
        self.assertTrue(result.reason.startswith('DUPLICATE_POSITION_ID_'))
        self.assertEqual(result.logical_row, 3)

    def test_invalid_and_overflow_position_ids(self):
        for pid in ('0', '-1', '1.5', '1e3', str(2**64), ''):
            with self.subTest(pid=pid):
                self.values['POSITION_ID'] = pid
                self.assertEqual(self.audit(self.data()).reason, 'INVALID_OR_OVERFLOW_POSITION_ID')

    def test_foreign_row_not_silently_accepted(self):
        self.values['MAGIC'] = '60001'
        self.assertEqual(self.audit(self.data()).reason, 'ROW_SCHEMA_OR_OWNERSHIP_MISMATCH')

    def test_unresolved_accounting_is_retained_not_invented(self):
        self.values['ACCOUNTING_RESOLVED'] = '0'
        self.values['NET_PNL'] = ''
        result = self.audit(self.data())
        self.assertTrue(result.valid)
        self.assertEqual(len(result.position_ids), 1)

    def test_incomplete_quote_is_distinct(self):
        header = self.data().split(b'\r\n')[0]
        result = self.audit(header + b'\r\n"partial,unfinished\r\n')
        self.assertEqual(result.reason, 'UNTERMINATED_QUOTED_TAIL')

    def test_utf8_bom_and_utf16_diagnosis(self):
        self.assertTrue(self.audit(b'\xef\xbb\xbf' + self.data()).valid)
        self.assertEqual(self.audit(self.data().decode('cp1252').encode('utf-16')).reason,
                         'UTF16_ENCODING_REQUIRES_EXPLICIT_MIGRATION')

    def test_embedded_nul(self):
        self.assertEqual(self.audit(self.data() + b'\0').reason, 'EMBEDDED_NUL')

    def test_recovery_reads_only_and_repeats_without_duplicates(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'trades.csv'
            valid = self.data()
            path.write_bytes(valid[:-4])
            before = hashlib.sha256(path.read_bytes()).digest()
            self.assertFalse(audit_file(path, 'WDOX26', 60002).valid)
            self.assertEqual(hashlib.sha256(path.read_bytes()).digest(), before)
            # Explicit simulated external restore, never an auto repair.
            path.write_bytes(valid)
            for _ in range(2):
                result = audit_file(path, 'WDOX26', 60002)
                self.assertTrue(result.valid)
                self.assertEqual(len(result.position_ids), 1)
            self.assertEqual(path.read_bytes(), valid)

    def test_absent_file_is_not_empty_success(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'missing.csv'
            result = audit_file(path, 'WDOX26', 60002)
            self.assertFalse(result.valid)
            self.assertTrue(result.reason.startswith('OPEN_ERROR_'))
            self.assertFalse(path.exists())


if __name__ == '__main__':
    unittest.main()
