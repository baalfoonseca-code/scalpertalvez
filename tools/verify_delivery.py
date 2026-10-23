#!/usr/bin/env python3
"""Read-only source integrity checks; deliberately not an MQL5 compiler."""
from pathlib import Path
import hashlib
import re

ROOT = Path(__file__).resolve().parents[1]
REFERENCE_SHA = 'c6e601429bea933ea937a3e985a2031a89b08bc42b199215dc5e8adfec2dd2a9'
PDF_SHA = 'eac0a690b26f3ff9ffba964c044a26fd678c4b0b21dda9128930ffe8047b3453'


def lexical_check(path):
    text = path.read_text(encoding='utf-8')
    stack = []
    state, line, index = 'code', 1, 0
    while index < len(text):
        ch = text[index]
        pair = text[index:index + 2]
        if ch == '\n':
            line += 1
        if state == 'comment':
            if pair == '*/':
                state = 'code'
                index += 2
                continue
        elif state == 'line':
            if ch == '\n':
                state = 'code'
        elif state in ('"', "'"):
            if ch == '\\':
                index += 2
                continue
            if ch == state:
                state = 'code'
            elif ch == '\n':
                raise AssertionError(f'{path.name}:{line}: unclosed literal')
        else:
            if pair == '/*':
                state = 'comment'
                index += 2
                continue
            if pair == '//':
                state = 'line'
                index += 2
                continue
            if ch in ('"', "'"):
                state = ch
            elif ch in '([{':
                stack.append((ch, line))
            elif ch in ')]}':
                assert stack and stack[-1][0] == {')': '(', ']': '[', '}': '{'}[ch], (path, line, stack[-1:] or None)
                stack.pop()
        index += 1
    assert state in ('code', 'line'), (path, 'unterminated literal/comment', state)
    assert not stack, (path, 'unbalanced delimiters', stack[-4:])
    for included in re.findall(r'^\s*#include\s+"([^"\n]+)"', text, re.M):
        local = (path.parent / included.replace('\\', '/')).resolve()
        assert local.is_relative_to(ROOT), (path, 'include escapes repository', local)
        assert local.is_file(), (path, 'missing local include', included)
    return len(text.splitlines())


def main():
    assert hashlib.sha256((ROOT / 'scalpertalvez').read_bytes()).hexdigest() == REFERENCE_SHA, 'Reference modified'
    assert hashlib.sha256((ROOT / 'comando.pdf').read_bytes()).hexdigest() == PDF_SHA, 'Master PDF modified'
    files = [ROOT / 'scalpertalvez', ROOT / 'scalpertalvez.mq5', *sorted((ROOT / 'Include').glob('*.mqh'))]
    for path in files:
        count = lexical_check(path)
        print(f'PASS lexical delimiters/local includes: {path.relative_to(ROOT)} ({count} lines)')
    print(f'PASS immutable reference and master PDF; {len(files)} files checked. Native compilation NOT performed.')


if __name__ == '__main__':
    main()
