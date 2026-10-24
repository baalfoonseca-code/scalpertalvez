"""Preserve the audited BOOK control while checking the new standalone candidate.

No test in this file asserts MetaEditor compilation or observed market results.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_decisoria as delivery
import verify_monolithic_independent as independent
from test_compatibility import function, tokens

BASE = '815077efec40adf1897bcf64640756bb46c4c118'


def old(path: str) -> str:
    return subprocess.check_output(['git', 'show', f'{BASE}:{path}'], cwd=ROOT, text=True)


# The additional validation belongs to the candidate/send wrappers, not to the
# matrix, original readiness predicates, book topology, financial helpers or exits.
PRESERVED_FUNCTIONS = (
    'ComputeMacroContext', 'ComputeMatrixSnapshot', 'HasHardDirectionalContradiction',
    'ComputePOCWithTie', 'RebuildWeisCache', 'ComputeLiveWaveO1', 'DOMGateClassify',
    'ComputeLotsForEntry', 'ComputeTrigger', 'NormEntrySL', 'NormEntryTP',
    'CheckArmedMarketReady', 'CheckArmedEntryReady', 'RecomputeDailyRiskBlock',
    'CountTodayTrades', 'RestoreDailyEconomicsFromHistory', 'ResetAccountingDay',
    'ParseScalperComment', 'CalcInitialRiskMoney', 'IsAcceptedRetcode', 'IsUncertainRetcode',
    'ProcessEOD', 'HasExecutionInFlight', 'PreparePendingExec', 'ReconcilePendingExecution',
    'ReconcilePendingExitIntent', 'TryFinalizeTrackedTrade', 'IsTrackedVolumeCycleComplete',
    'OwnPositionSafe', 'BEConfirm', 'BEAcceptResult', 'BEEntryComplete', 'BEReferenceValid',
    'BEStopsValid', 'RebuildTrackedHistory', 'ReconstructOpenPosition', 'RestoreDailyPersistence',
    'SyncOpenPositionFromRecord', 'ReleasePreparedRequest', 'MarkRequestDispatchPossible',
    'BEJournalRow', 'BEParseRow', 'RJRow', 'RJParse', 'OrderObligationSnapshot',
    'ParseOrderObligationSnapshot', 'SaveTradeMetadata', 'LoadTradeMetadata', 'CsvTradeHeader',
    'CsvTradeRow', 'ManageBreakEven', 'DOMGateRead', 'DOMBuildSnapshot',
)


class DecisionPreservationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.previous = old('scalpertalvez.mq5')
        cls.current = (ROOT / 'scalpertalvez.mq5').read_text()
        cls.active = independent.MQLProjection(ROOT).project(ROOT / 'scalpertalvez.mq5')

    def test_control_monolith_and_all_prior_reports_remain_byte_identical(self):
        delivery.verify_control()
        self.assertEqual(hashlib.sha256(delivery.CONTROL.read_bytes()).hexdigest(), delivery.CONTROL_SHA256)

    def test_all_historical_91_input_declarations_and_defaults_preserved_before_new_controls(self):
        inputs = delivery.preserved_inputs(self.active)
        self.assertGreater(len(inputs), 91)
        names = [statement.split()[2] for statement in inputs]
        self.assertEqual(len(names), len(set(names)))
        self.assertIn('input ENUM_BOOK_DECISION_MODE Inp_DecisionMode = DECISION_APLICAR', inputs[91:])
        self.assertIn('input ENUM_RESPONSE_MODE Inp_ResponseMode = RESPONSE_ORIGINAL', inputs[:91])

    def test_matrix_original_readiness_book_financial_and_exit_functions_preserved(self):
        for name in PRESERVED_FUNCTIONS:
            with self.subTest(function=name):
                self.assertEqual(tokens(function(self.previous, name)), tokens(function(self.current, name)))

    def test_all_existing_structures_and_enums_preserve_their_definitions(self):
        before = independent.inventory(delivery.control_source().decode('utf-8'))
        after = independent.inventory(self.active)
        for category in ['structs', 'enums']:
            current = {item['name']: item for item in after[category]}
            for definition in before[category]:
                with self.subTest(category=category, name=definition['name']):
                    self.assertEqual(current[definition['name']], definition)

    def test_financial_and_observational_arithmetic_modules_remain_byte_identical(self):
        for name in ['BookRiskInputs', 'BookAdvancedRisk', 'BookRiskCore', 'BookArmedInputs',
                     'BookArmedMath', 'BookIdentity', 'BookMicroMath',
                     'BookMicrostructure', 'BookRuntimePerf']:
            path = f'Include/{name}.mqh'
            with self.subTest(module=path):
                self.assertEqual((ROOT / path).read_bytes(), old(path).encode('utf-8'))

    def test_csv_correction_is_limited_to_transactional_scan_and_writer_lifecycle(self):
        # Explicitly authorized CSV fix: all unrelated parser/schema logic stays
        # byte-identical, and actual recovery/append behavior has integration tests.
        before = old('Include/BookCsvDiagnostics.mqh')
        after = (ROOT / 'Include/BookCsvDiagnostics.mqh').read_text()
        for name in ['BookCsvReject', 'InitializeTradeCsvIndex', 'BookCsvOpenInitialFile']:
            before = before.replace(function(before, name), 'AUTHORIZED_CSV_CORRECTION')
            after = after.replace(function(after, name), 'AUTHORIZED_CSV_CORRECTION')
        self.assertEqual(before, after)

    def test_diagnostic_change_is_only_demonstrated_late_breakout_mapping(self):
        path = 'Include/BookArmedDiagnostics.mqh'
        before, after = old(path), (ROOT / path).read_text()
        # The old diagnostic lost this terminal cancellation reason. It is a
        # mapping correction, not a new financial or matrix predicate.
        added = [line for line in after.splitlines(keepends=True) if line not in before.splitlines(keepends=True)]
        self.assertEqual(len(added), 1)
        self.assertIn('LATE_BREAKOUT_LOST', added[0])
        self.assertIn('CANCEL_BREAKOUT_LOST', added[0])
        self.assertEqual(after.replace(added[0], '', 1), before)
        self.assertIn('MatrixSnapshot matrixSnapshot;', after)
        self.assertIn('string matrixCsvCell=', after)
        self.assertNotRegex(independent.uncomment(after), r'\b(?:MatrixSnapshot|string)\s+matrix\b')

    def test_standalone_regeneration_independent_program_equivalence_and_events(self):
        content, graph, _ = delivery.build_text()
        self.assertEqual(content, delivery.TARGET.read_bytes())
        report = delivery.equivalent(content)
        self.assertEqual(report['status'], 'passed')
        self.assertTrue(report['active_tokens_equal'])
        self.assertTrue(report['inventories_equal'])
        self.assertEqual(report['historical_inputs_preserved'], 91)
        self.assertFalse(any(report['duplicates'].values()))
        self.assertEqual({item['path'] for item in graph},
                         {path.relative_to(ROOT).as_posix() for path in (ROOT / 'Include').glob('*.mqh')})
        visible = independent.uncomment(content.decode('utf-8'))
        self.assertNotRegex(visible, r'^\s*#\s*include\s+"')
        includes = re.findall(r'^\s*#\s*include\s+<([^>]+)>', visible, re.M)
        self.assertEqual(includes, [r'Trade\Trade.mqh', r'Trade\PositionInfo.mqh'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
