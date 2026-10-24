"""Offline research parser/summary invariants; no MT5 or financial simulation."""
from pathlib import Path
import csv
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('research_analysis', ROOT / 'tools/analyze_research.py')
analysis = importlib.util.module_from_spec(spec)
spec.loader.exec_module(analysis)


class ResearchAnalysisTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.path = Path(self.temporary.name)

    def write(self, kind, rows, suffix=''):
        rows = [{'schema': 'REMORA_RESEARCH_V1', 'run_id': 'fixture-run', **row} for row in rows]
        columns = list(dict.fromkeys(k for row in rows for k in row))
        path = self.path / f'Research_fixture{suffix}_{kind}.csv'
        with path.open('w', newline='', encoding='utf-8') as handle:
            writer = csv.DictWriter(handle, columns)
            writer.writeheader()
            writer.writerows(rows)
        return path

    def candidate(self, name='c1', **extra):
        return {'event_id': name + '-candidate', 'candidate_id': name, 'observed_msc': '1000',
                'eligibility': '1', 'symbol': 'WDOX26', 'account': '123', 'magic': '60002',
                'route': 'ABS', 'mode': 'BASE', 'direction': '1', 'preset_hash': 'fixture-preset',
                'operational_possible': '1', 'sl_distance': '5', 'tp_distance': '10', **extra}

    def decision(self, name='c1', result='DADOS_INSUFICIENTES', **extra):
        return {'event_id': name + '-decision', 'candidate_id': name, 'observed_msc': '1100',
                'result': result, 'reason': 'ABS_COMPARABLE_REFERENCES_INSUFFICIENT',
                'bucket': '18', 'actual_mode': 'APLICAR', **extra}

    def outcome(self, name='c1', **extra):
        return {'event_id': name + '-outcome', 'candidate_id': name, 'observed_msc': '2500',
                'status': 'TP_FIRST', 'market_eligible': '1', 'entry_price': '5500',
                'entry_msc': '1400', 'first_touch': 'TP', 'collision': '0', **extra}

    def test_multiday_dedup_preserves_candidate_and_separates_unconfirmed_pnl(self):
        self.write('Candidates', [self.candidate()])
        self.write('Decisions', [self.decision()])
        self.write('Outcomes', [self.outcome()])
        # Re-exporting the same immutable event cannot manufacture another trade.
        self.write('Outcomes', [self.outcome()], '-export')
        report = analysis.analyze([self.path])
        self.assertEqual(report['aggregate']['matrix_candidates'], 1)
        self.assertEqual(report['aggregate']['hypothetical_tp_first'], 1)
        self.assertEqual(report['aggregate']['rejected_tp_barrier_opportunities'], 1)
        self.assertEqual(report['aggregate']['actual_confirmed_closed_trades'], 0)
        self.assertIsNone(report['aggregate']['actual_confirmed_net_pnl'])
        self.assertIsNone(report['aggregate']['hypothetical_reference_expectancy_points'])
        self.assertEqual(report['ingestion']['identical_duplicates'], 1)

    def test_conflicting_event_ids_excluded_not_first_wins(self):
        self.write('Candidates', [self.candidate()])
        self.write('Outcomes', [self.outcome()])
        self.write('Outcomes', [self.outcome(first_touch='SL', status='SL_FIRST')], '-conflict')
        report = analysis.analyze([self.path])
        self.assertEqual(report['aggregate']['hypothetical_tp_first'], 0)
        self.assertEqual(report['aggregate']['hypothetical_sl_first'], 0)
        self.assertEqual(len(report['ingestion']['conflicting_event_ids']), 1)

    def test_ambiguous_path_cannot_be_scored_as_tp_or_sl(self):
        self.write('Candidates', [self.candidate()])
        self.write('Outcomes', [self.outcome(status='AMBIGUOUS_PATH')])
        report = analysis.analyze([self.path], cost_points=1)
        self.assertEqual(report['aggregate']['hypothetical_ambiguous'], 1)
        self.assertEqual(report['aggregate']['hypothetical_tp_first'], 0)
        self.assertEqual(report['aggregate']['hypothetical_cost_qualified_samples'], 0)

    def test_explicit_cost_overlay_excludes_collisions_and_does_not_become_pnl(self):
        self.write('Candidates', [self.candidate(), self.candidate('c2', collision='1')])
        self.write('Outcomes', [self.outcome(), self.outcome('c2', first_touch='SL', status='SL_FIRST', collision='1')])
        report = analysis.analyze([self.path], cost_points=1.5)
        a = report['aggregate']
        self.assertEqual(a['hypothetical_reference_expectancy_points'], 8.5)
        self.assertEqual(a['hypothetical_cost_qualified_samples'], 1)
        self.assertEqual(a['collision_candidates'], 1)
        self.assertIsNone(a['actual_confirmed_net_pnl'])
        with self.assertRaises(ValueError):
            analysis.analyze([self.path], cost_points=float('nan'))

    def test_symbols_routes_buckets_preserved_points_not_aggregated(self):
        self.write('Candidates', [self.candidate(), self.candidate('c2', symbol='WINZ26', route='CONT', direction='-1')])
        self.write('Decisions', [self.decision(), self.decision('c2', result='VALIDAR', bucket='19')])
        self.write('Outcomes', [self.outcome(), self.outcome('c2')])
        report = analysis.analyze([self.path], cost_points=1)
        self.assertTrue(report['mixed_symbol_points_not_aggregated'])
        self.assertIsNone(report['aggregate']['hypothetical_reference_expectancy_points'])
        self.assertEqual({(g['symbol'], g['route'], g['bucket']) for g in report['groups']}, {('WDOX26', 'ABS', '18'), ('WINZ26', 'CONT', '19')})
        self.assertEqual({g['hypothetical_reference_expectancy_points'] for g in report['groups']}, {9})

    def test_actual_closed_reconciled_position_dedup_across_restart(self):
        self.write('Candidates', [self.candidate(), self.candidate('c2', run_id='restart')])
        actual = self.outcome(status='REAL_RECONCILED', first_touch='', position_id='9007199254740993',
                              pnl_confirmed='1', net='-12.5', duration_seconds='21')
        self.write('Outcomes', [actual, {**actual, 'run_id': 'restart', 'candidate_id': 'c2', 'event_id': 'c2-real'}])
        report = analysis.analyze([self.path])
        self.assertEqual(report['aggregate']['actual_confirmed_closed_trades'], 1)
        self.assertEqual(report['aggregate']['actual_confirmed_net_pnl'], -12.5)
        self.assertEqual(report['aggregate']['actual_exposure_seconds'], 21)
        self.assertEqual(report['aggregate']['hypothetical_tp_first'], 0)

    def test_missing_or_invalid_data_remain_unavailable_and_rejected(self):
        self.write('Candidates', [self.candidate()])
        self.write('Decisions', [self.decision(known_coverage='', effort_rank='', net_rank='')])
        self.write('Health', [{'event_id': 'health1', 'reason': 'WRITE_FAILED'},
                              {'event_id': 'health2', 'schema': 'FUTURE_V9', 'reason': 'X'}])
        report = analysis.analyze([self.path])
        self.assertEqual(report['aggregate']['insufficient_data_candidates'], 1)
        self.assertEqual(report['aggregate']['original_market_entry_eligible'], 0)
        self.assertEqual(report['health']['reasons'], {'WRITE_FAILED': 1})
        self.assertEqual(report['ingestion']['rejected'][0]['reason'], 'UNSUPPORTED_SCHEMA')
        self.assertNotIn('effort_rank', report['aggregate'])

    def test_evidence_phase_rows_share_one_assessment_not_four_decisions(self):
        self.write('Candidates', [self.candidate()])
        self.write('Decisions', [self.decision(event_id='d1-T', assessment_id='d1', phase='T'),
                                 self.decision(event_id='d1-R', assessment_id='d1', phase='R'),
                                 self.decision(event_id='d2', assessment_id='d2', result='VALIDAR', observed_msc='1200')])
        report = analysis.analyze([self.path])
        self.assertEqual(report['aggregate']['decision_state_events'], {'DADOS_INSUFICIENTES': 1, 'VALIDAR': 1})
        self.assertEqual(report['aggregate']['final_decision_states'], {'VALIDAR': 1})
        self.assertEqual(len(report['candidate_audit'][0]['evidence_event_ids']), 3)

    def test_cli_creates_report_without_modifying_csv_and_quotes_roundtrip(self):
        source = self.write('Candidates', [self.candidate(reason='quote, "test"\nsecond line')])
        before = source.read_bytes()
        json_path, markdown_path = self.path / 'daily.json', self.path / 'daily.md'
        subprocess.run([sys.executable, str(ROOT / 'tools/analyze_research.py'), str(self.path),
                        '--json', str(json_path), '--markdown', str(markdown_path)], check=True)
        self.assertEqual(source.read_bytes(), before)
        self.assertEqual(json.loads(json_path.read_text())['aggregate']['matrix_candidates'], 1)
        self.assertIn('INDISPONÍVEL', markdown_path.read_text())
        self.assertIn('TP/SL are observed reference-price barriers', markdown_path.read_text())

    def test_conditional_market_reference_never_becomes_original_dispatch_or_cost_expectancy(self):
        self.write('Candidates',[self.candidate()])
        self.write('Decisions',[self.decision()])
        self.write('Outcomes',[self.outcome(reference_kind='CONDITIONAL_MARKET_REFERENCE',dispatch_eligible_observed='0')])
        report=analysis.analyze([self.path],cost_points=1)
        self.assertEqual(report['aggregate']['conditional_reference_entries'],1)
        self.assertEqual(report['aggregate']['original_dispatch_eligible_observed'],0)
        self.assertEqual(report['aggregate']['hypothetical_cost_qualified_samples'],0)
        self.assertEqual(report['aggregate']['rejected_tp_barrier_opportunities'],1)

    def test_send_return_without_fill_does_not_erase_rejected_opportunity(self):
        self.write('Candidates',[self.candidate()])
        self.write('Decisions',[self.decision()])
        self.write('Outcomes',[self.outcome(),self.outcome(status='REAL_SEND_RETURN',event_id='send',position_id='',deal_id='0',actual_price='')])
        report=analysis.analyze([self.path])
        self.assertEqual(report['aggregate']['rejected_tp_barrier_opportunities'],1)
        self.assertEqual(report['aggregate']['actual_confirmed_closed_trades'],0)

    def test_mode_comparison_requires_identical_other_loaded_inputs_utf16(self):
        def encode(fields):
            def item(text):return str(len(text.encode('utf-16-le'))//2)+':'+text
            return ''.join(item(kind)+item(name)+item(loaded)+'\n' for kind,name,loaded in fields)
        common=[('string',f'N{i}','ç😀' if i==0 else str(i)) for i in range(102)]
        rows=[]
        for run,mode,change in [('original','0',False),('apply','1',False),('different-book','1',True)]:
            fields=common.copy()
            if change:fields[1]=('string','N1','DIFFERENT')
            fields += [('ENUM_BOOK_DECISION_MODE','Inp_DecisionMode',mode),('bool','Inp_ResearchEnable','1')]
            rows.append({'event_id':run+'-cfg','run_id':run,'reason':'OBSERVATION_ONLY','details':encode(fields)})
        self.write('Health',rows)
        self.write('Candidates',[self.candidate(run_id='original'),self.candidate('c2',run_id='apply'),self.candidate('c3',run_id='different-book')])
        comparison=analysis.analyze([self.path])['mode_comparison']
        self.assertEqual(len(comparison['groups']),2)
        self.assertTrue(any(set(group['modes'])=={'ORIGINAL','APLICAR'} for group in comparison['groups']))
        self.assertFalse(comparison['configuration_unavailable'])

    def test_schema_has_unique_columns_and_financial_csv_is_not_a_research_input(self):
        schema_spec=importlib.util.spec_from_file_location('research_schema',ROOT/'tools/export_research_schema.py')
        schema=importlib.util.module_from_spec(schema_spec);schema_spec.loader.exec_module(schema)
        for fields in schema.schema()['files'].values():self.assertEqual(len(fields),len(set(fields)))
        self.assertNotIn('Trades',schema.schema()['files'])

    def test_candidate_identity_conflict_is_not_silently_merged(self):
        self.write('Candidates', [self.candidate(), self.candidate(event_id='c1-conflict', direction='-1')])
        report = analysis.analyze([self.path])
        self.assertEqual(report['aggregate']['matrix_candidates'], 0)
        self.assertEqual(len(report['conflicting_candidate_identities']), 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
