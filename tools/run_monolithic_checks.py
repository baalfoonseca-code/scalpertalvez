#!/usr/bin/env python3
"""Re-run all tests; write ONLY complementary evidence, never old reports."""
from pathlib import Path
import contextlib
import datetime
import hashlib
import io
import json
import os
import platform
import shutil
import subprocess
import sys
import time
import unittest
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / 'artifacts/matrix-id-fix1'
BASE = '824e0ced7a3ebb3fd9893c60a4547562ef4cea05'


def compiler_discovery():
    names = ['metaeditor', 'metaeditor64', 'metaeditor.exe', 'metaeditor64.exe', 'wine', 'wine64']
    path_tools = {name: shutil.which(name) for name in names}
    # Only accessible paths are inspected. Errors are retained instead of
    # representing a partial traversal as proof of machine-wide absence.
    probe = subprocess.run(['find', '/opt', '/usr/local', '/workspace', '/tmp', '/home',
                            '-type', 'f', '(', '-iname', 'metaeditor*.exe', '-o', '-iname',
                            'metaeditor', '-o', '-iname', 'metaeditor64', '-o', '-iname',
                            'terminal64.exe', ')', '-print'], capture_output=True, text=True)
    discovery = {'path_tools': path_tools, 'readable_path_candidates': probe.stdout.splitlines(),
                 'search_exit_code': probe.returncode, 'search_diagnostics': probe.stderr.splitlines(),
                 'absolute_filesystem_absence_proven': False}
    (ARTIFACTS / 'compiler-discovery.log').write_text(json.dumps(discovery,ensure_ascii=False,indent=2)+'\n')
    editors = [v for k,v in path_tools.items() if k.startswith('metaeditor') and v]
    editors += [v for v in discovery['readable_path_candidates'] if 'metaeditor' in Path(v).name.lower()]
    if editors:
        raise RuntimeError('MetaEditor candidate found: inspect/execute supported native compilation before claiming completion: '+repr(editors))
    status = {'schema':'BOOK_MONOLITH_NATIVE_STATUS_V1',
              'reason':'No accessible MetaEditor discovered; no Wine in PATH. Native compilation not executed.',
              'discovery_log':'compiler-discovery.log',
              'versions': {'modular':{'file':'scalpertalvez.mq5','executed':False,'errors':None,'warnings':None,'compiler_log':None},
                           'monolithic':{'file':'scalpertalvez_MONOLITICO.mq5','executed':False,'errors':None,'warnings':None,'compiler_log':None}},
              'ex5_produced':False,'production_modified':False}
    (ARTIFACTS / 'native-compilation-status.json').write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n')
    return status


def main():
    ARTIFACTS.mkdir(exist_ok=True,parents=True)
    began=time.monotonic()
    started=datetime.datetime.now(ZoneInfo('America/Sao_Paulo')).isoformat()
    revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    output=io.StringIO()
    for args in [['tools/build_monolithic.py','--check'],
                 ['tools/generate_identity_inputs.py','--check'],
                 ['tools/verify_delivery.py'],
                 ['tools/verify_monolithic_independent.py','--output','artifacts/matrix-id-fix1/independent-equivalence.json']]:
        completed=subprocess.run([sys.executable,*args],cwd=ROOT,text=True,capture_output=True)
        output.write(completed.stdout+completed.stderr)
        if completed.returncode:
            (ARTIFACTS/'tests-complementar.log').write_text(output.getvalue())
            print(output.getvalue())
            return completed.returncode
    native=compiler_discovery()
    suite=unittest.TestLoader().discover(str(ROOT/'tests'))
    with contextlib.redirect_stdout(output),contextlib.redirect_stderr(output):
        result=unittest.TextTestRunner(stream=output,verbosity=2).run(suite)
    # New tests are read-only against all 49 protected files, including old logs.
    sys.path.insert(0,str(ROOT/'tools'))
    import build_monolithic
    build_monolithic.verify_reference()
    report={'schema':'BOOK_MONOLITH_HOST_TESTS_V1','started_at':started,
            'elapsed_seconds':round(time.monotonic()-began,3),'reference_commit':BASE,
            'revision_at_test_start':revision,'python':platform.python_version(),
            'gpp':subprocess.check_output(['g++','--version'],text=True).splitlines()[0],
            'source_sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in
                             ['scalpertalvez.mq5','scalpertalvez_MONOLITICO.mq5']},
            'tests_run':result.testsRun,
            'passed':result.testsRun-len(result.failures)-len(result.errors)-len(result.skipped)-len(result.expectedFailures)-len(result.unexpectedSuccesses),
            'failures':[test.id() for test,_ in result.failures],
            'errors':[test.id() for test,_ in result.errors],
            'skipped':[{'test':test.id(),'reason':reason} for test,reason in result.skipped],
            'expected_failures':[test.id() for test,_ in result.expectedFailures],
            'unexpected_successes':[test.id() for test in result.unexpectedSuccesses],
            'native_compilation':native,'modular_reference_files_unchanged':49,
            'mt5_backtest_book_server_orders':'NOT_EXECUTED','homologated':False}
    (ARTIFACTS/'tests-complementar.log').write_text(output.getvalue(),encoding='utf8')
    (ARTIFACTS/'test-results-complementar.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(output.getvalue())
    print(json.dumps(report,ensure_ascii=False,indent=2))
    return 0 if result.wasSuccessful() and result.testsRun else 1


if __name__=='__main__':
    raise SystemExit(main())
