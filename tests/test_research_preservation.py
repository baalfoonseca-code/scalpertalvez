"""Whole-source observation-only invariants against the audited 94fddd7 EA.

Token projection proves source preservation, not real MT5 timing equivalence.
Deterministic entry fixtures separately exercise research OFF and ON.
"""
from pathlib import Path
import hashlib
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
import build_decisoria as delivery
import research_contract as contract
import verify_monolithic_independent as independent
from test_compatibility import function

BASE = delivery.RESEARCH_BASE


def old(path):
    return subprocess.check_output(['git', 'show', BASE+':'+path], cwd=ROOT, text=True)


def definitions(source):
    visible = contract.mask(source, True)
    return [name for name in dict.fromkeys(re.findall(r'(?m)^\w+\s+(\w+)\s*\(', visible)) if name not in {"if","for","while","switch"}]


class ResearchPreservationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before = old('scalpertalvez.mq5')
        cls.after = (ROOT/'scalpertalvez.mq5').read_text()

    def test_all_103_inputs_exact_and_only_research_false_appended(self):
        active = independent.MQLProjection(ROOT).project(ROOT/'scalpertalvez.mq5')
        current = delivery.preserved_inputs(active)
        previous = independent.inventory(old('REMORA_BOOK_PRO_DECISORIA.mq5'))['inputs']
        self.assertEqual(len(previous), 103)
        self.assertEqual(current[:103], previous)
        self.assertEqual(current[103:], ['input bool Inp_ResearchEnable = false'])

    def test_every_original_main_function_preserved_except_void_observation_hooks(self):
        count = 0
        for name in definitions(self.before):
            with self.subTest(function=name):
                previous = function(self.before, name)
                current = function(self.after, name)
                self.assertEqual(contract.operation_tokens(previous), contract.operation_tokens(current))
                count += 1
        self.assertGreater(count, 300)

    def test_existing_decision_financial_book_and_microstructure_modules_frozen(self):
        # Generated identity bindings/provenance legitimately include the new
        # bool; every existing hand-maintained module remains byte-identical.
        names = subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','Include'], cwd=ROOT,text=True).splitlines()
        for name in names:
            if name in ('Include/BookInputSnapshot.mqh','Include/BookBuildIdentity.mqh'):
                continue
            with self.subTest(path=name):
                if name == 'Include/BookDecisionRuntime.mqh':
                    # The completed pure assessment is copied before final book;
                    # no result or observer return participates in the decision.
                    self.assertEqual(contract.operation_tokens((ROOT/name).read_text()),
                                     contract.operation_tokens(old(name)))
                else:
                    self.assertEqual((ROOT/name).read_bytes(), old(name).encode())

    def test_no_research_financial_or_dispatch_side_effect_calls(self):
        modules = list((ROOT/'Include').glob('BookResearch*.mqh'))
        self.assertTrue(modules, 'research module missing')
        forbidden = ('PositionOpen','PositionClose','PositionClosePartial','PositionModify',
                     'OrderSend','OrderSendAsync','OrderDelete','OrderModify','Buy','Sell',
                     'PreparePendingExec','CompletePendingExec','ResetPendingExec',
                     'ReleasePreparedRequest','MarkRequestDispatchPossible','ResetArmedSignal',
                     'BookDecisionBind','BookDecisionInit','BookDecisionPump',
                     'BookDecisionEvaluateArmed','BookDecisionCandidate','BookRiskPrepareEntry',
                     'ResolveRequestJournal','SaveTradeMetadata','InitializeTradeCsvIndex')
        global_state = ('armed','gPendingExec','gPendingExit','gTradeRecords','dailyRiskBlocked',
                        'gAccountingUnresolved','gEntryJournalInvalid','gRequestJournalUnresolved')
        for path in modules:
            source = contract.mask(path.read_text(), True)
            with self.subTest(path=path.name):
                for name in forbidden:
                    self.assertNotRegex(source, r'\b'+name+r'\s*\(')
                for name in global_state:
                    self.assertNotRegex(source, r'\b'+name+r'\b(?:\s*\.\s*\w+|\s*\[[^\]]*\])*\s*(?:\+\+|--|[+*/-]?=(?!=))')
                self.assertNotRegex(source, r'(?<!const )\bArmedSignal\s*&')

    def test_frozen_reference_artifacts_and_control_unchanged(self):
        names = subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','artifacts','docs'],cwd=ROOT,text=True).splitlines()
        for name in names:
            with self.subTest(path=name):
                self.assertEqual((ROOT/name).read_bytes(), subprocess.check_output(['git','show',BASE+':'+name],cwd=ROOT))
        delivery.verify_control()

    def test_modular_monolithic_complete_equivalence_and_event_signatures(self):
        content, _, _ = delivery.build_text()
        self.assertEqual(content, delivery.TARGET.read_bytes())
        result = delivery.equivalent(content)
        self.assertTrue(result['active_tokens_equal'])
        self.assertTrue(result['inventories_equal'])
        self.assertEqual(result['research_reference_inputs_preserved'],103)
        self.assertEqual(result['input_count'],104)
        self.assertFalse(any(result['duplicates'].values()))
        self.assertFalse(result['native_compilation_executed'])

    def test_control_flow_projection_rejects_results_conditions_and_mutating_arguments(self):
        for invalid in ('if(BookResearchTick()) return;', 'bool x=BookResearchTick();',
                        'BookResearchTick(armed.dir++);', 'BookResearchTick(armed.dir=1);',
                        'return BookResearchTick();'):
            with self.subTest(invalid=invalid):
                with self.assertRaises(AssertionError):
                    contract.strip_void_hooks(invalid)
        self.assertEqual(contract.operation_tokens('void f(){BookResearchTick();return;}'),
                         contract.operation_tokens('void f(){return;}'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
