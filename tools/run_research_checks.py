#!/usr/bin/env python3
"""Run research tests and both frozen engineering controls, without native claims.

The old MATRIX_ID_FIX1 delivery-only assertions remain tested on 815077e.
The 94fddd7 operational candidate's complete 90-test contract is tested unchanged
in an isolated checkout. Current tests exercise the observational extension and
all applicable legacy fixtures; any exclusions are enumerated in the JSON log.
"""
from __future__ import annotations
import datetime
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import time
from zoneinfo import ZoneInfo

import run_decision_checks as previous
from build_decisoria import RESEARCH_BASE

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT/'artifacts/research'


def isolated(reference: str, *, control: bool, expected: int):
    with tempfile.TemporaryDirectory(prefix='remora-research-control-') as temporary:
        checkout = Path(temporary)/'control'
        subprocess.run(['git','clone','--shared','--quiet','--no-checkout',str(ROOT),str(checkout)],
                       check=True,capture_output=True)
        subprocess.run(['git','checkout','--quiet','--detach',reference],cwd=checkout,
                       check=True,capture_output=True)
        report, log = previous.run_suite(checkout, control=control)
        if report['tests_run'] != expected:
            raise RuntimeError(f'Frozen {reference} expected {expected} tests, discovered {report["tests_run"]}')
        return report, log


def source_digests():
    paths = [ROOT/'scalpertalvez.mq5', ROOT/'REMORA_BOOK_PRO_DECISORIA.mq5',
             *sorted((ROOT/'Include').glob('*.mqh')), *sorted((ROOT/'tools').glob('*.py')),
             *sorted((ROOT/'tests').glob('*.py')), *sorted((ROOT/'tests').glob('*.hpp')), *sorted((ROOT/'tests').glob('*.cpp'))]
    return {path.relative_to(ROOT).as_posix():hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}


def main():
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    began = datetime.datetime.now(ZoneInfo('America/Sao_Paulo')).isoformat()
    revision = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    logs = []
    for command in [('tools/generate_identity_inputs.py','--check'),
                    ('tools/build_decisoria.py','--check'), ('tools/verify_delivery.py',)]:
        result = subprocess.run([sys.executable,*command],cwd=ROOT,text=True,capture_output=True)
        logs.append('COMMAND '+' '.join(command)+'\n'+result.stdout+result.stderr)
        if result.returncode:
            (ARTIFACTS/'tests.log').write_text('\n'.join(logs))
            print('\n'.join(logs))
            return result.returncode
    before = source_digests()
    native = previous.native_discovery()
    control, text = isolated(previous.BASE, control=True, expected=52)
    logs.append('FROZEN BOOK CONTROL '+previous.BASE+'\n'+text)
    (ARTIFACTS/'frozen-book-control.json').write_text(json.dumps(control,indent=2)+'\n')
    candidate_control, text = isolated(RESEARCH_BASE, control=False, expected=90)
    logs.append('FROZEN DECISION CONTROL '+RESEARCH_BASE+'\n'+text)
    (ARTIFACTS/'frozen-decision-control.json').write_text(json.dumps(candidate_control,indent=2)+'\n')
    (ARTIFACTS/'control-tests.log').write_text('\n'.join(logs))
    current, text = previous.run_suite(ROOT, control=False)
    logs.append('CURRENT RESEARCH CANDIDATE\n'+text)
    if before != source_digests():
        raise RuntimeError('Source changed during tests; rerun after edits are complete')
    report = {'schema':'BOOK_RESEARCH_TESTS_V1','started_at':began,
              'elapsed_seconds':round(time.monotonic()-started,3),'revision_at_start':revision,
              'research_reference':RESEARCH_BASE,'frozen_book_reference':previous.BASE,
              'python':platform.python_version(),
              'gpp':subprocess.check_output(['g++','--version'],text=True).splitlines()[0],
              'source_sha256':before,'frozen_book_control':control,
              'frozen_decision_control':candidate_control,'research_candidate':current,
              'native_compilation':native,'mt5_market_replay':'NOT_EXECUTED',
              'broker_execution_or_native_timing':'NOT_EXECUTED',
              'financial_performance_comparison':'NOT_EXECUTED_NO_MARKET_DATA',
              'production_modified':False,'homologated':False}
    (ARTIFACTS/'tests.log').write_text('\n'.join(logs),encoding='utf-8')
    (ARTIFACTS/'test-results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    (ARTIFACTS/'native-compilation.json').write_text(json.dumps(native,ensure_ascii=False,indent=2)+'\n')
    brief = {name:{key:value[key] for key in ('tests_run','passed','successful','failures','errors','skipped')}
             for name,value in [('frozen_book',control),('frozen_decision',candidate_control),('research',current)]}
    brief['native_compilation_executed'] = native['executed']
    print(json.dumps(brief,ensure_ascii=False,indent=2))
    return 0 if all(suite['successful'] for suite in (control,candidate_control,current)) else 1


if __name__ == '__main__':
    raise SystemExit(main())
