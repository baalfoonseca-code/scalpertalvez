#!/usr/bin/env python3
"""Run available checks and persist an honest machine-readable host report."""
from pathlib import Path
import contextlib
import datetime
import hashlib
import io
import json
import platform
import subprocess
import sys
import time
import unittest
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]


def main():
    output = io.StringIO()
    start = time.monotonic()
    started = datetime.datetime.now(ZoneInfo('America/Sao_Paulo')).isoformat()
    for script, args in [('verify_delivery.py', []), ('generate_identity_inputs.py', ['--check'])]:
        result = subprocess.run([sys.executable, str(ROOT / 'tools' / script), *args], cwd=ROOT, capture_output=True, text=True)
        output.write(result.stdout + result.stderr)
        if result.returncode:
            print(output.getvalue())
            return result.returncode
    suite = unittest.TestLoader().discover(str(ROOT / 'tests'))
    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
        result = unittest.TextTestRunner(stream=output, verbosity=2).run(suite)
    artifact = ROOT / 'artifacts'
    artifact.mkdir(exist_ok=True)
    log = output.getvalue()
    (artifact / 'tests-host.log').write_text(log, encoding='utf8')
    report = {
        'started_at': started,
        'elapsed_seconds': round(time.monotonic() - start, 3),
        'revision_at_test_start': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'source_sha256': hashlib.sha256((ROOT / 'scalpertalvez.mq5').read_bytes()).hexdigest(),
        'baseline_sha256': hashlib.sha256((ROOT / 'scalpertalvez').read_bytes()).hexdigest(),
        'python': platform.python_version(),
        'compiler': subprocess.check_output(['g++', '--version'], text=True).splitlines()[0],
        'tests_run': result.testsRun,
        'passed': result.testsRun - len(result.failures) - len(result.errors) - len(result.skipped) - len(result.expectedFailures) - len(result.unexpectedSuccesses),
        'failures': [name.id() for name, _ in result.failures],
        'errors': [name.id() for name, _ in result.errors],
        'skipped': [{'test': name.id(), 'reason': reason} for name, reason in result.skipped],
        'expected_failures': [name.id() for name, _ in result.expectedFailures],
        'unexpected_successes': [name.id() for name in result.unexpectedSuccesses],
        'native_metaeditor_compilation': 'NOT_RUN: MetaEditor/MT5 unavailable',
        'broker_book_orders_restart_backtest': 'NOT_RUN: no MT5, broker session or market replay data',
        'real_wdo_trade_csv': 'NOT_PROVIDED: real incident not repaired',
        'production_modified': False,
    }
    (artifact / 'test-results.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print(log)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if result.wasSuccessful() and result.testsRun else 1


if __name__ == '__main__':
    raise SystemExit(main())
