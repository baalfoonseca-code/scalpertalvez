#!/usr/bin/env python3
"""Read-only RC1 financial CSV audit. Never rewrites or repairs financial evidence.

Python reference/diagnostic utility; passing this tool does not prove MQL5 runtime
behavior, server state, compilation or economic correctness of stored amounts.
"""
from dataclasses import dataclass, asdict
from pathlib import Path
import argparse
import json
import re

ROOT = Path(__file__).resolve().parents[1]
UINT64_MAX = 2**64 - 1


@dataclass
class Audit:
    valid: bool
    reason: str
    logical_row: int = 0
    expected_columns: int = 0
    received_columns: int = 0
    position_ids: tuple = ()


def schema_from_source(source=None):
    text = (source or ROOT / 'scalpertalvez').read_text(encoding='utf-8')
    columns = []
    for function in ('CsvConfigHeader', 'CsvTradeHeader'):
        body = re.search(r'void ' + function + r'\(string &line\)\s*\{([^}]+)\}', text).group(1)
        columns.extend(re.findall(r'CsvAdd\(line,"([^"]+)"\)', body))
    return columns


def parse_record(record):
    fields, value = [], ''
    quoted = after_quote = False
    i = 0
    while i < len(record):
        c = record[i]
        if quoted:
            if c == '"':
                if i + 1 < len(record) and record[i + 1] == '"':
                    value += '"'
                    i += 1
                else:
                    quoted, after_quote = False, True
            else:
                value += c
        elif c == ',':
            fields.append(value)
            value, after_quote = '', False
        elif c == '"':
            if value or after_quote:
                return fields, 'QUOTE_IN_UNQUOTED_FIELD'
            quoted = True
        else:
            if after_quote or c in '\r\n':
                return fields, 'CHARACTER_AFTER_CLOSING_QUOTE' if after_quote else 'UNQUOTED_LINE_BREAK'
            value += c
        i += 1
    if quoted:
        return fields, 'UNTERMINATED_QUOTED_FIELD'
    return [*fields, value], ''


def logical_records(content):
    quoted, start, i = False, 0, 0
    while i < len(content):
        c = content[i]
        if c == '"':
            if quoted and i + 1 < len(content) and content[i + 1] == '"':
                i += 1
            else:
                quoted = not quoted
        if c in '\r\n' and not quoted:
            record = content[start:i]
            if c == '\r' and i + 1 < len(content) and content[i + 1] == '\n':
                i += 1
            start = i + 1
            yield record, ''
        i += 1
    if start != len(content):
        yield content[start:], 'UNTERMINATED_QUOTED_TAIL' if quoted else 'UNTERMINATED_RECORD'


def audit_bytes(data, symbol, magic, schema=None):
    expected = schema or schema_from_source()
    n = len(expected)
    if not data:
        return Audit(False, 'EMPTY_OR_SIZE_QUERY_FAILED', expected_columns=n)
    if len(data) > 64 * 1024**2:
        return Audit(False, 'SCAN_LIMIT_64_MIB', expected_columns=n)
    if data.startswith((b'\xff\xfe', b'\xfe\xff')):
        return Audit(False, 'UTF16_ENCODING_REQUIRES_EXPLICIT_MIGRATION', expected_columns=n)
    if b'\0' in data:
        return Audit(False, 'EMBEDDED_NUL', expected_columns=n)
    content = data.decode('utf-8-sig') if data.startswith(b'\xef\xbb\xbf') else data.decode('cp1252')
    positions, header, row = [], None, 0
    for row, (record, tail_error) in enumerate(logical_records(content), 1):
        fields, error = parse_record(record)
        received = len(fields) + bool(error)
        if tail_error or error:
            return Audit(False, tail_error or error, row, n, received, tuple(positions))
        if header is None:
            if len(fields) != n:
                return Audit(False, 'HEADER_COLUMN_COUNT', row, n, len(fields))
            for k, (actual, wanted) in enumerate(zip(fields, expected), 1):
                if actual != wanted:
                    return Audit(False, f'HEADER_FIELD_{k}_EXPECTED_{wanted}', row, n, len(fields))
            header = fields
        elif record:
            if len(fields) != n:
                return Audit(False, 'ROW_COLUMN_COUNT', row, n, len(fields), tuple(positions))
            values = dict(zip(header, fields))
            if (values['SCHEMA_VERSION'], values['SYMBOL'], values['MAGIC']) != ('RC1', symbol, str(magic)):
                return Audit(False, 'ROW_SCHEMA_OR_OWNERSHIP_MISMATCH', row, n, len(fields), tuple(positions))
            if values['CLOSED'] != '1' or values['ACCOUNTING_RESOLVED'] not in ('0', '1'):
                return Audit(False, 'INVALID_FINALIZATION_FLAGS', row, n, len(fields), tuple(positions))
            raw_pid = values['POSITION_ID']
            if not re.fullmatch(r'[0-9]+', raw_pid) or not 0 < int(raw_pid) <= UINT64_MAX:
                return Audit(False, 'INVALID_OR_OVERFLOW_POSITION_ID', row, n, len(fields), tuple(positions))
            pid = int(raw_pid)
            if pid in positions:
                return Audit(False, f'DUPLICATE_POSITION_ID_{raw_pid}', row, n, len(fields), tuple(positions))
            positions.append(pid)
    if header is None:
        return Audit(False, 'UNTERMINATED_RECORD', row + 1, n, 0, tuple(positions))
    return Audit(True, 'VALID_STRUCTURE_ONLY', row, n, n, tuple(positions))


def audit_file(path, symbol, magic):
    try:
        return audit_bytes(path.read_bytes(), symbol, magic)
    except OSError as error:
        return Audit(False, f'OPEN_ERROR_{error.errno}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file', type=Path)
    parser.add_argument('--symbol', required=True)
    parser.add_argument('--magic', required=True, type=int)
    args = parser.parse_args()
    result = audit_file(args.file, args.symbol, args.magic)
    print(json.dumps(asdict(result), indent=2))
    raise SystemExit(0 if result.valid else 1)


if __name__ == '__main__':
    main()
