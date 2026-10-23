#!/usr/bin/env python3
"""Lossless MQL-target include transposition; existing modular files are immutable.

Personal includes are replaced in-place by their complete contents. Non-MQL
host adapters are retained verbatim after a comment prefix, not discarded. Only
__cplusplus/BOOK_RISK_HOST are fixed undefined, as in a normal MetaEditor build.
All ordinary guards/directives remain in their original order. This is NOT an
MQL5 compiler and does not assert native compilation or broker equivalence.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BASE = '323750ad5bc3a9f4e5c92570313b206966dfdff6'
SOURCE = ROOT / 'scalpertalvez.mq5'
TARGET = ROOT / 'scalpertalvez_MONOLITICO.mq5'
ARTIFACTS = ROOT / 'artifacts/monolitico'
ZIP = ARTIFACTS / 'scalpertalvez_MODULAR_323750a.zip'
HOST_UNDEFINED = frozenset({'__cplusplus', 'BOOK_RISK_HOST'})
OFFICIAL = (r'Trade\Trade.mqh', r'Trade\PositionInfo.mqh')
LOCAL = re.compile(r'^\s*#\s*include\s+"([^"\n]+)"[^\n]*$')
DIRECTIVE = re.compile(r'^\s*#\s*(\w+)\b(.*)$')
PREAMBLE = (
    '// GENERATED: scalpertalvez_MONOLITICO.mq5; complete MQL5-target transposition.\n'
    '// Immutable engineering reference: modular commit '+BASE+'.\n'
    '// All 13 custom modules are incorporated at their original include sites.\n'
    '// Host-only adapters remain as comments; only official MQL5 includes remain active.\n'
    '// Native MetaEditor compilation NOT verified; experimental, not homologated.\n\n'
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def baseline_files() -> dict[str, bytes]:
    names = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', '-z', BASE], cwd=ROOT).decode().split('\0')
    return {name: subprocess.check_output(['git', 'show', f'{BASE}:{name}'], cwd=ROOT) for name in names if name}


def verify_reference() -> dict[str, bytes]:
    files = baseline_files()
    for name, data in files.items():
        path = ROOT / name
        if not path.is_file() or path.read_bytes() != data:
            raise ValueError(f'Protected modular reference changed: {name}')
    return files


def expanded_records(source: Path = SOURCE):
    records = []
    graph = []
    def visit(path: Path, chain: tuple[Path, ...]):
        path = path.resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():
            raise ValueError(f'Missing or escaping local include: {path}')
        if path in chain:
            raise ValueError(f'Circular include: {path}')
        relative = path.relative_to(ROOT).as_posix()
        # Strict decoding, no replacement characters or implicit line conversion.
        for number, line in enumerate(path.read_bytes().decode('utf8').splitlines(keepends=True), 1):
            match = LOCAL.fullmatch(line.rstrip('\r\n'))
            if not match:
                records.append((line, relative, number, 'original'))
                continue
            dependency = (path.parent / match[1].replace('\\', '/')).resolve()
            if not dependency.is_relative_to(ROOT / 'Include'):
                raise ValueError(f'Unexpected custom include scope: {dependency}')
            label = dependency.relative_to(ROOT).as_posix()
            graph.append({'owner': relative, 'line': number, 'path': label, 'sha256': sha(dependency.read_bytes())})
            records.append(('// ORIGINAL_INCLUDE | '+line.rstrip('\r\n')+'\n', relative, number, 'include_directive_comment'))
            records.append(('// BEGIN_INCORPORATED '+label+'\n', relative, number, 'boundary_comment'))
            visit(dependency, chain + (path,))
            if records and not records[-1][0].endswith('\n'):
                text, owner, lineno, rendering = records[-1]
                records[-1] = (text+'\n', owner, lineno, rendering)
            records.append(('// END_INCORPORATED '+label+'\n', relative, number, 'boundary_comment'))
    visit(source, ())
    return records, graph


def mql_host_projection(records):
    """Select known MQL branches; preserve every original inactive line as comment."""
    stack = []
    enabled = True
    result = []
    for line, owner, number, rendering in records:
        match = DIRECTIVE.match(line)
        command, arg = (match[1], match[2].strip().split('//', 1)[0].strip()) if match else ('', '')
        comment = not enabled
        if command in ('ifdef', 'ifndef'):
            controlled = arg in HOST_UNDEFINED
            if controlled:
                condition = command == 'ifndef'
                stack.append((True, enabled, condition, False))
                enabled = enabled and condition
                comment = True
            else:
                stack.append((False, enabled, True, False))
        elif command == 'else':
            if not stack:
                raise ValueError(f'Orphan #else: {owner}:{number}')
            controlled, parent, condition, seen_else = stack[-1]
            if seen_else:
                raise ValueError(f'Duplicate #else: {owner}:{number}')
            stack[-1] = (controlled, parent, condition, True)
            if controlled:
                enabled = parent and not condition
                comment = True
            else:
                comment = not parent
        elif command == 'endif':
            if not stack:
                raise ValueError(f'Orphan #endif: {owner}:{number}')
            controlled, parent, condition, seen_else = stack.pop()
            comment = controlled or not parent
            enabled = parent
        elif command in ('if', 'elif'):
            raise ValueError(f'Unsupported conditional, requires explicit review: {owner}:{number}')
        elif command in ('define', 'undef') and arg.split(None, 1)[0] in HOST_UNDEFINED:
            raise ValueError(f'MQL host macro redefined: {owner}:{number}')
        if comment:
            line = '// HOST_CPP_INACTIVE | '+line
            rendering = 'inactive_host_comment'
        result.append((line, owner, number, rendering))
    if stack:
        raise ValueError('Unterminated preprocessor conditional')
    return result


def compress_map(records):
    segments = []
    generated = len(PREAMBLE.splitlines()) + 1
    for line, owner, number, rendering in records:
        count = len(line.splitlines())
        if count != 1:
            raise ValueError(f'Unexpected line mapping width: {owner}:{number}: {count}')
        if segments and segments[-1]['source_path'] == owner and segments[-1]['rendering'] == rendering and segments[-1]['source_end_line'] + 1 == number:
            segments[-1]['generated_end_line'] = generated
            segments[-1]['source_end_line'] = number
        else:
            segments.append({'generated_start_line': generated, 'generated_end_line': generated,
                             'source_path': owner, 'source_start_line': number,
                             'source_end_line': number, 'rendering': rendering})
        generated += 1
    return segments


def build_text():
    expanded, graph = expanded_records()
    records = mql_host_projection(expanded)
    content = PREAMBLE + ''.join(row[0] for row in records)
    if re.search(r'^\s*#\s*include\s+"', content, re.M):
        raise ValueError('Personal include survived transposition')
    official = tuple(re.findall(r'^\s*#\s*include\s+<([^>]+)>', content, re.M))
    if official != OFFICIAL:
        raise ValueError(f'Unexpected remaining includes: {official}')
    expected = {p.relative_to(ROOT).as_posix() for p in (ROOT / 'Include').glob('*.mqh')}
    paths = [item['path'] for item in graph]
    if set(paths) != expected or len(paths) != 13 or len(set(paths)) != 13:
        raise ValueError(f'Module coverage/duplicate mismatch: {paths}')
    return content.encode('utf8'), graph, records


def create_zip(files):
    ARTIFACTS.mkdir(exist_ok=True, parents=True)
    subprocess.run(['git', 'archive', '--format=zip', f'--output={ZIP}', BASE], cwd=ROOT, check=True)
    with zipfile.ZipFile(ZIP) as archive:
        names = {i.filename for i in archive.infolist() if not i.is_dir()}
        if names != set(files) or archive.testzip() is not None:
            raise ValueError('Modular archive membership/CRC mismatch')
        for name, data in files.items():
            if archive.read(name) != data:
                raise ValueError(f'Modular archive differs from reference: {name}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify output without modifying it')
    args = parser.parse_args()
    files = verify_reference()
    content, graph, records = build_text()
    mapping = {'schema': 'BOOK_MONOLITH_SOURCE_MAP_V1', 'reference_commit': BASE,
               'monolith_sha256': sha(content), 'segments': compress_map(records)}
    manifest = {'schema': 'BOOK_MONOLITH_TRANSPOSE_V1', 'reference_commit': BASE,
                'modular_main_sha256': sha(files['scalpertalvez.mq5']),
                'monolith_sha256': sha(content), 'monolith_bytes': len(content),
                'monolith_lines': len(content.splitlines()), 'module_count': len(graph),
                'include_order': graph, 'official_includes': list(OFFICIAL),
                'mql_target_undefined_host_macros': sorted(HOST_UNDEFINED),
                'inactive_host_lines_retained_as_comments': sum(r[3] == 'inactive_host_comment' for r in records),
                'protected_reference_file_count': len(files),
                'protected_reference_sha256': {name: sha(data) for name, data in sorted(files.items())},
                'native_compilation': {'modular': 'NOT_EXECUTED', 'monolithic': 'NOT_EXECUTED'}}
    payloads = {TARGET: content,
                ARTIFACTS / 'source-map.json': (json.dumps(mapping, ensure_ascii=False, indent=2)+'\n').encode(),
                ARTIFACTS / 'build-manifest.json': (json.dumps(manifest, ensure_ascii=False, indent=2)+'\n').encode()}
    if args.check:
        for path, expected in payloads.items():
            if not path.is_file() or path.read_bytes() != expected:
                raise SystemExit(f'Stale generated output: {path.relative_to(ROOT)}')
        # Validate the immutable ZIP too; never repair silently in check mode.
        with zipfile.ZipFile(ZIP) as archive:
            if {i.filename for i in archive.infolist() if not i.is_dir()} != set(files) or archive.testzip() is not None:
                raise SystemExit('Invalid modular archive')
            for name, data in files.items():
                if archive.read(name) != data:
                    raise SystemExit(f'Archive reference mismatch: {name}')
    else:
        ARTIFACTS.mkdir(exist_ok=True, parents=True)
        for path, data in payloads.items():
            path.write_bytes(data)
        create_zip(files)
    print(f'PASS: {len(files)} immutable modular files, 13 expanded modules, exactly 2 official MQL5 includes')
    print(f'Monolith: {len(content)} bytes; SHA256 {sha(content)}; native compilation NOT executed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
