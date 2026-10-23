"""Complementary packaging tests; every original modular file remains frozen."""
from pathlib import Path
import importlib.util
import json
import re
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_monolithic as builder
import verify_monolithic_independent as independent
import test_compatibility as compatibility


class MonolithicDeliveryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.modular = (ROOT / 'scalpertalvez.mq5').read_text()
        cls.monolith = builder.TARGET.read_text()
        cls.report = independent.verify(ROOT, builder.SOURCE, builder.TARGET, builder.BASE)

    def test_entire_modular_reference_remains_byte_identical(self):
        files = builder.verify_reference()
        self.assertEqual(len(files), 49)
        self.assertEqual(len([x for x in files if x.startswith('Include/') and x.endswith('.mqh')]), 13)
        self.assertTrue(self.report['frozen_baseline']['unchanged'])

    def test_exact_regeneration_and_original_include_order(self):
        data, graph, records = builder.build_text()
        self.assertEqual(data, builder.TARGET.read_bytes())
        expected = ['BookRiskInputs', 'BookArmedInputs', 'BookAdvancedRisk', 'BookRiskCore',
                    'BookCsvDiagnostics', 'BookIdentity', 'BookBuildIdentity', 'BookInputSnapshot',
                    'BookMicroMath', 'BookMicrostructure', 'BookArmedDiagnostics', 'BookArmedMath',
                    'BookRuntimePerf']
        self.assertEqual([x['path'] for x in graph], ['Include/'+x+'.mqh' for x in expected])
        self.assertEqual([x['path'] for x in graph], self.report['modular']['expanded_files'][1:])

    def test_independent_full_mql_program_and_inventory_equality(self):
        self.assertEqual(self.report['status'], 'passed')
        self.assertTrue(self.report['comparison']['active_tokens_equal'])
        self.assertTrue(self.report['comparison']['inventories_equal'])
        self.assertIsNone(self.report['comparison']['first_difference'])
        counts = self.report['modular']['inventory']['counts']
        self.assertEqual(counts, {'inputs':91, 'functions':490, 'structs':31, 'enums':18, 'globals':468})
        for category, duplicate in self.report['monolithic']['inventory']['duplicates'].items():
            self.assertFalse(duplicate, category)
        # All financial/decision/observer bodies are included in this exact
        # stream comparison, beyond the representative controlled host fixtures.
        self.assertEqual(self.report['modular']['active_tokens_sha256'], self.report['monolithic']['active_tokens_sha256'])

    def test_91_inputs_and_official_dependencies_only(self):
        self.assertEqual(len(self.report['monolithic']['inventory']['inputs']), 91)
        self.assertEqual(self.report['modular']['inventory']['inputs'], self.report['monolithic']['inventory']['inputs'])
        includes = re.findall(r'^\s*#include\s+(.+)', independent.uncomment(self.monolith), re.M)
        self.assertEqual([x.strip() for x in includes], [r'<Trade\Trade.mqh>', r'<Trade\PositionInfo.mqh>'])
        self.assertFalse(re.search(r'^\s*#include\s+"', self.monolith, re.M))
        self.assertFalse(re.search(r'^\s*#include\s+<cmath>', self.monolith, re.M))

    def test_every_original_source_line_is_accounted_for(self):
        _, _, records = builder.build_text()
        cache = {path: (ROOT/path).read_text().splitlines(keepends=True)
                 for path in self.report['modular']['expanded_files']}
        covered = set()
        for rendered, path, line, kind in records:
            raw = cache[path][line-1]
            if kind == 'original':
                self.assertEqual(rendered, raw)
                covered.add((path,line))
            elif kind == 'inactive_host_comment':
                self.assertEqual(rendered, '// HOST_CPP_INACTIVE | '+raw)
                covered.add((path,line))
            elif kind == 'include_directive_comment':
                self.assertEqual(rendered, '// ORIGINAL_INCLUDE | '+raw.rstrip('\r\n')+'\n')
                covered.add((path,line))
            elif kind != 'boundary_comment':
                self.fail('Unknown generated rendering: '+kind)
        all_lines = {(path,line) for path, lines in cache.items() for line in range(1,len(lines)+1)}
        self.assertEqual(covered,all_lines)
        mapping=json.loads((builder.ARTIFACTS/'source-map.json').read_text())
        self.assertEqual(mapping['segments'],builder.compress_map(records))

    def test_modular_zip_is_exact_baseline_archive(self):
        files=builder.baseline_files()
        with zipfile.ZipFile(builder.ZIP) as archive:
            self.assertIsNone(archive.testzip())
            self.assertEqual({i.filename for i in archive.infolist() if not i.is_dir()},set(files))
            for name,data in files.items():
                self.assertEqual(archive.read(name),data,name)
            self.assertNotIn(builder.TARGET.name,archive.namelist())

    def test_independent_checker_rejects_unsupported_semantics(self):
        cases = [('#if 1\nint x;\n#endif\n','numeric if'),
                 ('int x=__LINE__;\n','location-dependent macro'),
                 ('#define __cplusplus 1\n','host flag enabled'),
                 ('#include <cmath>\n','nonofficial dependency'),
                 ('#define F(x) (x)\n','function macro'),
                 ('#ifdef NOT_DEFINED\nint x;\n','unclosed guard')]
        with tempfile.TemporaryDirectory(prefix='checker-',dir=ROOT/'artifacts/monolitico') as td:
            path=Path(td)/'probe.mq5'
            for text,label in cases:
                path.write_text(text)
                with self.subTest(case=label),self.assertRaises(independent.VerificationError):
                    independent.MQLProjection(ROOT).project(path)
            path.write_text('#ifdef __cplusplus\nint cpp_only;\n#else\nint mql_only;\n#endif\n')
            projected=independent.MQLProjection(ROOT).project(path)
            self.assertEqual(independent.tokenize(projected),['int','mql_only',';'])

    def test_actual_decision_and_poc_weis_fixtures_against_monolith(self):
        # Build fixtures from the actual function bodies of each representation,
        # with the same existing deterministic market/clock API substitutes.
        with tempfile.TemporaryDirectory(prefix='book-mono-fixtures-') as td:
            for name,fixture,expected in [('matrix_stage2',compatibility.build_fixture,'matrix=12000'),
                                          ('poc_weis',compatibility.build_poc_fixture,'poc=514 weis=128')]:
                outputs=[]
                for label,source in [('modular',self.modular),('monolithic',self.monolith)]:
                    cpp=Path(td)/(name+'_'+label+'.cpp');cpp.write_text(fixture(source));exe=cpp.with_suffix('')
                    built=subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra',str(cpp),'-o',str(exe)],capture_output=True,text=True)
                    self.assertEqual(built.returncode,0,built.stderr)
                    run=subprocess.run([str(exe)],capture_output=True,text=True)
                    self.assertEqual(run.returncode,0,run.stdout+run.stderr)
                    self.assertIn(expected,run.stdout)
                    outputs.append(run.stdout)
                self.assertEqual(outputs[0],outputs[1],name)
                print('MONOLITH FIXTURE '+name+': '+outputs[0].strip())


if __name__ == '__main__':
    unittest.main()
