#!/usr/bin/env python3
"""Read-only contracts for the observational extension; not an MQL compiler."""
from __future__ import annotations
import re


def mask(text: str, literals: bool = False) -> str:
    pattern = re.compile(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
    def replace(match):
        token = match.group()
        if literals or token.startswith(('//', '/*')):
            return ''.join('\n' if ch == '\n' else ' ' for ch in token)
        return token
    return pattern.sub(replace, text)


def strip_void_hooks(text: str) -> tuple[str, list[str]]:
    """Erase standalone research calls ONLY, rejecting expression/control uses.

    Declarations/definitions are not accepted here. Arguments stay visible to
    the isolation audit; this projection is solely a control-flow comparison.
    """
    hooks = []
    while True:
        visible = mask(text, True)
        call = re.search(r'\b(BookResearch\w*)\s*\(', visible)
        if not call:
            return text, hooks
        prefix = visible[:call.start()].rstrip()
        if prefix and prefix[-1] not in ';{}':
            raise AssertionError('Research hook is not a standalone void statement: '+call[1])
        end, depth = call.end(), 1
        while end < len(visible) and depth:
            depth += (visible[end] == '(') - (visible[end] == ')')
            end += 1
        if depth:
            raise AssertionError('Unbalanced research hook: '+call[1])
        arguments = visible[call.end():end-1]
        if re.search(r'\+\+|--|(?<![<>=!])=(?!=)', arguments):
            raise AssertionError('Research hook argument mutates state: '+call[1])
        while end < len(visible) and visible[end].isspace():
            end += 1
        if end >= len(visible) or visible[end] != ';':
            raise AssertionError('Research result participates in strategy expression: '+call[1])
        hooks.append(call[1])
        text = text[:call.start()] + text[end+1:]


def operation_tokens(text: str) -> list[str]:
    projected, _ = strip_void_hooks(text)
    # Observer-only braces may surround an existing return; no declaration,
    # nested condition, other expression or side effect is normalized away.
    projected = re.sub(r'\{\s*(return\b[^;{}]*;)\s*\}', r'\1', mask(projected))
    return re.findall(r'"(?:\\.|[^"\\])*"|[A-Za-z_]\w*|\d+(?:\.\d*)?|[^\s]', projected)
