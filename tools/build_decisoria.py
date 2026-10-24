#!/usr/bin/env python3
"""Generate the experimental decision EA without replacing the audited control.

Expansion and the independent MQL token comparison cover the complete program.
They do not constitute a native MetaEditor compilation or an MT5 approval.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

import build_monolithic as expansion
import verify_monolithic_independent as independent

ROOT = Path(__file__).resolve().parents[1]
BASE = '815077efec40adf1897bcf64640756bb46c4c118'
CONTROL = ROOT / 'scalpertalvez_MONOLITICO.mq5'
CONTROL_SHA256 = 'c3a2e1bd2ea4f9f04eeafa48a2c8fb70cd20af441d2c09b296e41f44c30534ae'
SOURCE = ROOT / 'scalpertalvez.mq5'
TARGET = ROOT / 'REMORA_BOOK_PRO_DECISORIA.mq5'
ARTIFACTS = ROOT / 'artifacts/decisoria'
PREAMBLE = (
    '// GENERATED: REMORA_BOOK_PRO_DECISORIA.mq5; integral modular expansion.\n'
    '// EXPERIMENTAL: operational ABS/CONT validation; DECISION_APLICAR is the source default.\n'
    '// Audited control: '+BASE+'; its monolithic file remains unchanged.\n'
    '// Provider aggressor flags require an independent explicit configuration assumption.\n'
    '// Only official MQL5 headers remain external; no custom repository include is required.\n'
    '// Native MetaEditor compilation NOT verified; no production deployment or approval.\n\n'
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def control_source() -> bytes:
    data = subprocess.check_output(['git', 'show', f'{BASE}:{CONTROL.name}'], cwd=ROOT)
    if sha(data) != CONTROL_SHA256:
        raise ValueError('Pinned Git control digest differs from the authorized reference')
    return data


def verify_control() -> None:
    if CONTROL.read_bytes() != control_source():
        raise ValueError('The audited monolithic control was modified')
    # Keep all historical evidence byte-identical. New evidence has its own folder.
    names = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', BASE,
                                     '--', 'artifacts', 'docs'], cwd=ROOT, text=True).splitlines()
    for name in names:
        expected = subprocess.check_output(['git', 'show', f'{BASE}:{name}'], cwd=ROOT)
        path = ROOT / name
        if not path.is_file() or path.read_bytes() != expected:
            raise ValueError('Historical control evidence changed: '+name)


def preserved_inputs(active: str) -> list[str]:
    baseline = independent.inventory(control_source().decode('utf-8'))['inputs']
    current = independent.inventory(active)['inputs']
    if len(baseline) != 91 or current[:91] != baseline:
        raise ValueError('The historical 91 input types/names/order/defaults were changed')
    if len(current) <= 91:
        raise ValueError('No independent decision inputs have been appended')
    return current


def build_text():
    records, graph = expansion.expanded_records(SOURCE)
    records = expansion.mql_host_projection(records)
    content = (PREAMBLE + ''.join(row[0] for row in records)).encode('utf-8')
    text = content.decode('utf-8')
    if re.search(r'^\s*#\s*include\s+"', text, re.M):
        raise ValueError('Custom include survived standalone transposition')
    official = tuple(re.findall(r'^\s*#\s*include\s+<([^>]+)>', text, re.M))
    if official != expansion.OFFICIAL:
        raise ValueError('Unexpected official dependencies: '+repr(official))
    paths = {entry['path'] for entry in graph}
    expected = {path.relative_to(ROOT).as_posix() for path in (ROOT / 'Include').glob('*.mqh')}
    if paths != expected:
        raise ValueError('Custom module coverage differs: '+repr(paths ^ expected))
    return content, graph, records


def equivalent(content: bytes) -> dict:
    # Check a temporary standalone path under the checkout, without overwriting
    # the delivered target or trusting the expansion helper's token stream.
    import tempfile
    with tempfile.TemporaryDirectory(prefix='decision-compare-', dir=ROOT) as temporary:
        path = Path(temporary) / TARGET.name
        path.write_bytes(content)
        left = independent.MQLProjection(ROOT).project(SOURCE)
        right = independent.MQLProjection(ROOT).project(path)
        a, b = independent.tokenize(left), independent.tokenize(right)
        if a != b:
            raise ValueError('Independent modular/standalone active-token comparison failed')
        inv_a, inv_b = independent.inventory(left), independent.inventory(right)
        if inv_a != inv_b:
            raise ValueError('Independent modular/standalone symbol inventory differs')
        if any(inv_a['duplicates'].values()):
            raise ValueError('Duplicate source inventory declarations: '+repr(inv_a['duplicates']))
        inputs = preserved_inputs(left)
        for name, signature in [('OnTick', 'void OnTick ( )'), ('OnTimer', 'void OnTimer ( )'),
                                ('OnInit', 'int OnInit ( )')]:
            matches = [item for item in inv_a['functions'] if item['name'] == name]
            if len(matches) != 1 or matches[0]['signature'] != signature:
                raise ValueError('Missing, duplicated or malformed event: '+name)
        return {'status': 'passed', 'active_tokens_equal': True, 'inventories_equal': True,
                'active_token_count': len(a), 'active_tokens_sha256': independent.sha256_json(a),
                'counts': inv_a['counts'], 'input_count': len(inputs),
                'historical_inputs_preserved': 91, 'new_inputs': inputs[91:],
                'duplicates': inv_a['duplicates'], 'native_compilation_executed': False}


def payloads():
    verify_control()
    content, graph, records = build_text()
    comparison = equivalent(content)
    mapping = expansion.compress_map(records)
    offset = len(PREAMBLE.splitlines()) - len(expansion.PREAMBLE.splitlines())
    for row in mapping:
        row['generated_start_line'] += offset
        row['generated_end_line'] += offset
    manifest = {'schema': 'BOOK_DECISION_STANDALONE_V1', 'control_commit': BASE,
                'control_sha256': CONTROL_SHA256, 'source': SOURCE.name,
                'target': TARGET.name, 'sha256': sha(content), 'bytes': len(content),
                'lines': len(content.splitlines()), 'include_order': graph,
                'official_includes': list(expansion.OFFICIAL), 'comparison': comparison,
                'source_sha256': {path: sha((ROOT / path).read_bytes())
                                  for path in [SOURCE.name, *sorted({item['path'] for item in graph})]},
                'native_compilation_executed': False, 'production_modified': False}
    encode = lambda value: (json.dumps(value, ensure_ascii=False, indent=2)+'\n').encode('utf-8')
    return {TARGET: content, ARTIFACTS / 'build-manifest.json': encode(manifest),
            ARTIFACTS / 'source-map.json': encode({'schema': 'BOOK_DECISION_SOURCE_MAP_V1',
                                                  'target_sha256': sha(content), 'segments': mapping})}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    outputs = payloads()
    for path, data in outputs.items():
        if args.check:
            if not path.is_file() or path.read_bytes() != data:
                raise SystemExit('Stale standalone output: '+path.relative_to(ROOT).as_posix())
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    manifest = json.loads(outputs[ARTIFACTS / 'build-manifest.json'])
    print(json.dumps({'status': 'passed', 'target': TARGET.name, 'sha256': manifest['sha256'],
                      'comparison': manifest['comparison'], 'native_compilation_executed': False},
                     ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
