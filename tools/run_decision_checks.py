#!/usr/bin/env python3
"""Run frozen-control tests separately from the operational candidate tests.

The 815077e packaging/alpha-renaming assertions describe a frozen release. They
remain executable against that complete release, rather than being weakened to
accept an intentionally different operational program. Current preservation and
integration tests replace the explicitly listed zero-change contracts.
"""
from __future__ import annotations

import datetime
import hashlib
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import time
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
BASE = '815077efec40adf1897bcf64640756bb46c4c118'
ARTIFACTS = ROOT / 'artifacts/decisoria'
CONTROL_ONLY_MODULES = {
    'test_matrix_identifier_fix': 'Frozen MATRIX_ID_FIX1 alpha-renaming and provenance contract; tested on 815077e.',
    'test_monolithic_delivery': 'Frozen MATRIX_ID_FIX1 packaging/49-file/91-total-input contract; tested on 815077e.',
}
CONTROL_ONLY_TESTS = {}

CHILD = r'''
import json,sys,unittest
from pathlib import Path
root=Path.cwd()
sys.path.insert(0,str(root/'tests'))
suite=unittest.TestLoader().discover(str(root/'tests'))
def flat(node):
    for item in node:
        if isinstance(item,unittest.TestSuite):yield from flat(item)
        else:yield item
items=list(flat(suite));excluded=[]
policy=json.loads(sys.argv[1])
selected=[]
for item in items:
    name=item.id();module=name.split('.',1)[0]
    reason=policy['modules'].get(module) or policy['tests'].get(name)
    if reason:excluded.append({'test':name,'reason':reason})
    else:selected.append(item)
result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(selected))
report={'tests_run':result.testsRun,
        'passed':result.testsRun-len(result.failures)-len(result.errors)-len(result.skipped)-len(result.expectedFailures)-len(result.unexpectedSuccesses),
        'failures':[test.id() for test,_ in result.failures],
        'errors':[test.id() for test,_ in result.errors],
        'skipped':[{'test':test.id(),'reason':reason} for test,reason in result.skipped],
        'expected_failures':[test.id() for test,_ in result.expectedFailures],
        'unexpected_successes':[test.id() for test in result.unexpectedSuccesses],
        'control_only':excluded,'test_ids':[test.id() for test in selected],
        'successful':result.wasSuccessful() and bool(result.testsRun)}
print('BOOK_TEST_REPORT='+json.dumps(report,separators=(',',':')))
raise SystemExit(0 if report['successful'] else 1)
'''


def run_suite(checkout: Path, control: bool) -> tuple[dict, str]:
    policy = {'modules': {}, 'tests': {}} if control else {
        'modules': CONTROL_ONLY_MODULES, 'tests': CONTROL_ONLY_TESTS}
    result = subprocess.run([sys.executable, '-c', CHILD, json.dumps(policy)], cwd=checkout,
                            text=True, capture_output=True)
    marker = 'BOOK_TEST_REPORT='
    rows = [line for line in result.stdout.splitlines() if line.startswith(marker)]
    if len(rows) != 1:
        raise RuntimeError('Suite did not emit its result: '+result.stdout+result.stderr)
    report = json.loads(rows[0][len(marker):])
    report['process_exit_code'] = result.returncode
    text = result.stderr + '\n'.join(line for line in result.stdout.splitlines()
                                     if not line.startswith(marker))+'\n'
    return report, text


def native_discovery() -> dict:
    names = ['metaeditor', 'metaeditor64', 'metaeditor.exe', 'metaeditor64.exe', 'wine', 'wine64']
    path_tools = {name: shutil.which(name) for name in names}
    probe = subprocess.run(['find', '/opt', '/usr/local', '/workspace', '/tmp', '/home', '-type', 'f',
                            '(', '-iname', 'metaeditor*.exe', '-o', '-iname', 'metaeditor',
                            '-o', '-iname', 'metaeditor64', ')', '-print'], capture_output=True, text=True)
    candidates = probe.stdout.splitlines()
    report = {'path_tools': path_tools, 'readable_candidates': candidates,
              'search_exit_code': probe.returncode, 'search_diagnostics': probe.stderr.splitlines(),
              'absolute_filesystem_absence_proven': False,
              'executed': False, 'errors': None, 'warnings': None, 'compiler_log': None,
              'ex5_produced': False, 'production_modified': False}
    if candidates or any(value for name, value in path_tools.items() if name.startswith('metaeditor')):
        raise RuntimeError('An accessible MetaEditor candidate was found; inspect and compile natively: '+repr(report))
    report['reason'] = 'No accessible MetaEditor discovered. Native compilation was not executed.'
    return report


def source_digests() -> dict:
    names = [ROOT / 'scalpertalvez.mq5', ROOT / 'REMORA_BOOK_PRO_DECISORIA.mq5',
             *sorted((ROOT / 'Include').glob('*.mqh'))]
    return {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in names}


def main() -> int:
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    began = datetime.datetime.now(ZoneInfo('America/Sao_Paulo')).isoformat()
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    logs = []
    for command in [['tools/build_decisoria.py', '--check'],
                    ['tools/generate_identity_inputs.py', '--check'], ['tools/verify_delivery.py']]:
        checked = subprocess.run([sys.executable, *command], cwd=ROOT, text=True, capture_output=True)
        logs.append('COMMAND '+' '.join(command)+'\n'+checked.stdout+checked.stderr)
        if checked.returncode:
            (ARTIFACTS / 'tests.log').write_text('\n'.join(logs))
            print('\n'.join(logs))
            return checked.returncode
    before = source_digests()
    native = native_discovery()
    with tempfile.TemporaryDirectory(prefix='book-815-control-') as temporary:
        checkout = Path(temporary) / 'control'
        subprocess.run(['git', 'clone', '--shared', '--quiet', '--no-checkout', str(ROOT), str(checkout)],
                       check=True, capture_output=True)
        subprocess.run(['git', 'checkout', '--quiet', '--detach', BASE], cwd=checkout,
                       check=True, capture_output=True)
        control, text = run_suite(checkout, control=True)
        logs.append('FROZEN CONTROL '+BASE+'\n'+text)
        if control['tests_run'] != 52:
            raise RuntimeError('Frozen control discovery differs from its documented 52 tests')
    current, text = run_suite(ROOT, control=False)
    logs.append('CURRENT OPERATIONAL CANDIDATE\n'+text)
    if before != source_digests():
        raise RuntimeError('Source changed while tests were executing; rerun after edits finish')
    report = {'schema': 'BOOK_DECISION_TESTS_V1', 'started_at': began,
              'elapsed_seconds': round(time.monotonic()-start, 3), 'revision_at_start': revision,
              'control_reference': BASE, 'python': platform.python_version(),
              'gpp': subprocess.check_output(['g++', '--version'], text=True).splitlines()[0],
              'source_sha256': before, 'frozen_control': control, 'operational_candidate': current,
              'native_compilation': native, 'mt5_market_replay': 'NOT_EXECUTED',
              'financial_performance_comparison': 'NOT_EXECUTED_NO_MARKET_DATA',
              'production_modified': False, 'homologated': False}
    (ARTIFACTS / 'tests.log').write_text('\n'.join(logs), encoding='utf-8')
    (ARTIFACTS / 'test-results.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    (ARTIFACTS / 'native-compilation.json').write_text(json.dumps(native, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({'control': {key: control[key] for key in ['tests_run', 'passed', 'successful']},
                      'candidate': {key: current[key] for key in ['tests_run', 'passed', 'successful', 'failures', 'errors', 'skipped']},
                      'native_compilation_executed': False}, ensure_ascii=False, indent=2))
    return 0 if control['successful'] and current['successful'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
