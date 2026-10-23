#!/usr/bin/env python3
"""Independently compare the active MQL program before/after include expansion.

This verifier does not import the monolith builder or its tests. It handles the
directive subset actually used by this delivery, rejects unsupported semantics,
retains official library includes, and makes no MetaEditor compilation claim.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import pathlib
import re
import subprocess
import sys


class VerificationError(ValueError):
    pass


LITERALS_AND_COMMENTS = re.compile(
    r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\''
)
TOKEN = re.compile(
    r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|'
    r'[A-Za-z_]\w*|(?:0[xX][0-9A-Fa-f]+|(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)[uUlLfF]*|'
    r'>>=|<<=|==|!=|<=|>=|&&|\|\||\+\+|--|\+=|-=|\*=|/=|%=|&=|\|=|\^=|<<|>>|::|[^\s]'
)
OFFICIAL_INCLUDES = {"Trade/Trade.mqh", "Trade/PositionInfo.mqh"}
LOCATION_MACROS = {
    "__FILE__", "__LINE__", "__PATH__", "__DATE__", "__TIME__", "__DATETIME__",
    "__TIMESTAMP__", "__COUNTER__", "__FUNCTION__", "__FUNCSIG__",
}


def uncomment(text: str) -> str:
    def replacement(match):
        value = match.group()
        if value.startswith(("//", "/*")):
            return "".join("\n" if ch == "\n" else " " for ch in value)
        return value
    return LITERALS_AND_COMMENTS.sub(replacement, text)


def tokenize(text: str) -> list[str]:
    return TOKEN.findall(uncomment(text))


def sha256_json(value) -> str:
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")).hexdigest()


class MQLProjection:
    """Process object macros and guards; host-test macros start undefined."""

    def __init__(self, repo: pathlib.Path):
        self.repo = repo.resolve()
        self.macros: dict[str, str] = {}
        self.local_graph: list[str] = []
        self.official: list[str] = []

    def project(self, path: pathlib.Path, depth: int = 0) -> str:
        path = path.resolve()
        if not path.is_relative_to(self.repo):
            raise VerificationError(f"Include escapes checkout: {path}")
        if depth > 64:
            raise VerificationError(f"Include cycle/depth exceeds 64: {path}")
        if not path.is_file():
            raise VerificationError(f"Missing source/include: {path}")
        relative = path.relative_to(self.repo).as_posix()
        self.local_graph.append(relative)
        raw = path.read_text(encoding="utf-8")
        visible_lines = uncomment(raw).splitlines(keepends=True)
        raw_lines = raw.splitlines(keepends=True)
        if len(visible_lines) != len(raw_lines):
            raise VerificationError(f"Lexical line mapping failed: {relative}")
        output = []
        stack: list[tuple[bool, bool, bool]] = []
        active = True
        for line_no, (line, visible) in enumerate(zip(raw_lines, visible_lines), 1):
            match = re.match(r"^\s*#(\w+)\s*(.*)", visible)
            if not match:
                if active:
                    output.append(line)
                continue
            directive, argument = match.groups()
            argument = argument.strip()
            location = f"{relative}:{line_no}"
            if visible.rstrip().endswith("\\"):
                raise VerificationError(f"Unsupported continued directive at {location}")
            if directive in ("ifdef", "ifndef"):
                if not re.fullmatch(r"[A-Za-z_]\w*", argument):
                    raise VerificationError(f"Malformed conditional at {location}")
                condition = argument in self.macros
                if directive == "ifndef":
                    condition = not condition
                stack.append((active, condition, False))
                active = active and condition
            elif directive == "else":
                if argument or not stack or stack[-1][2]:
                    raise VerificationError(f"Malformed/repeated else at {location}")
                parent, condition, _ = stack[-1]
                stack[-1] = (parent, condition, True)
                active = parent and not condition
            elif directive == "endif":
                if argument or not stack:
                    raise VerificationError(f"Unmatched endif at {location}")
                active = stack.pop()[0]
            elif directive == "define":
                definition = re.fullmatch(r"([A-Za-z_]\w*)(.*)", argument)
                if not definition or definition[2].startswith("("):
                    raise VerificationError(f"Unsupported function-like/malformed macro at {location}")
                if active:
                    name, value = definition.groups()
                    value = value.strip()
                    if name in ("__cplusplus", "BOOK_RISK_HOST"):
                        raise VerificationError(f"Host-test profile enabled by source at {location}")
                    if name in self.macros and self.macros[name] != value:
                        raise VerificationError(f"Nonidentical macro redefinition at {location}: {name}")
                    self.macros[name] = value
                    output.append(line)
            elif directive == "include":
                if not active:
                    continue
                local = re.fullmatch(r'"([^"\n]+)"', argument)
                official = re.fullmatch(r"<([^>\n]+)>", argument)
                if local:
                    include = local[1].replace("\\", "/")
                    output.append(self.project(path.parent / include, depth + 1))
                elif official:
                    include = official[1].replace("\\", "/")
                    if include not in OFFICIAL_INCLUDES:
                        raise VerificationError(f"Unexpected active external include at {location}: {include}")
                    self.official.append(include)
                    output.append(line)
                else:
                    raise VerificationError(f"Unsupported macro/malformed include at {location}")
            elif directive == "property":
                if active:
                    output.append(line)
            else:
                # Do not guess the semantics of #if, #elif, #undef, #import,
                #pragma or a new directive even when currently in a dead arm.
                raise VerificationError(f"Unsupported directive #{directive} at {location}")
        if stack:
            raise VerificationError(f"Unclosed conditional in {relative}")
        result = "".join(output)
        locations = LOCATION_MACROS.intersection(tokenize(result))
        if locations:
            raise VerificationError(f"Location/time-sensitive macros require separate review: {sorted(locations)}")
        return result


def matching(tokens: list[str], start: int, opening="{", closing="}") -> int:
    depth = 0
    for i in range(start, len(tokens)):
        depth += (tokens[i] == opening) - (tokens[i] == closing)
        if depth == 0:
            return i
    raise VerificationError(f"Unbalanced {opening}{closing} inventory delimiters")


def split_top(tokens: list[str], delimiter=",") -> list[list[str]]:
    chunks, start, level = [], 0, 0
    for i, token in enumerate(tokens):
        if token in ("(", "[", "{"):
            level += 1
        elif token in (")", "]", "}"):
            level -= 1
        elif token == delimiter and level == 0:
            chunks.append(tokens[start:i]); start = i + 1
    chunks.append(tokens[start:])
    return chunks


def variable_names(statement: list[str]) -> list[str]:
    qualifiers = {"input", "sinput", "const", "static", "extern", "volatile"}
    declaration = list(statement)
    while declaration and declaration[0] in qualifiers:
        declaration.pop(0)
    if len(declaration) < 2:
        raise VerificationError(f"Unsupported global declaration: {' '.join(statement)}")
    declaration.pop(0)  # Current delivery has one-token MQL types.
    names = []
    for chunk in split_top(declaration):
        if not chunk or not re.fullmatch(r"[A-Za-z_]\w*", chunk[0]):
            raise VerificationError(f"Unsupported global declarator: {' '.join(chunk)}")
        names.append(chunk[0])
    return names


def inventory(active: str) -> dict:
    # Preprocessor directives remain part of full-token equality, but are not
    # declarations in the translation-unit symbol inventory.
    code = "\n".join(line for line in uncomment(active).splitlines()
                     if not re.match(r"^\s*#", line))
    t = tokenize(code)
    result = {"inputs": [], "functions": [], "structs": [], "enums": [], "globals": []}
    start, i = 0, 0
    while i < len(t):
        if t[i] == ";":
            statement = t[start:i]
            if statement:
                if "(" in statement and ("=" not in statement or statement.index("(") < statement.index("=")):
                    # Prototype inventory is distinct from function definitions.
                    raise VerificationError(f"Unexpected top-level prototype needs inventory support: {' '.join(statement)}")
                names = variable_names(statement)
                for name in names:
                    result["globals"].append({"name": name, "declaration": " ".join(statement)})
                if statement[0] in ("input", "sinput"):
                    result["inputs"].append(" ".join(statement))
            start = i + 1
        elif t[i] == "{":
            header = t[start:i]
            end = matching(t, i)
            if header and header[0] in ("struct", "class", "enum"):
                if len(header) != 2 or t[end + 1:end + 2] != [";"]:
                    raise VerificationError(f"Unsupported aggregate declaration: {' '.join(header)}")
                category = "enums" if header[0] == "enum" else "structs"
                result[category].append({"name": header[1], "tokens_sha256": sha256_json(t[start:end + 1])})
                i = end + 1
                start = i + 1
            elif "(" in header and header[-1:] == [")"]:
                opening = header.index("(")
                if opening < 2:
                    raise VerificationError(f"Unsupported function signature: {' '.join(header)}")
                result["functions"].append({"name": header[opening - 1], "signature": " ".join(header),
                                             "tokens_sha256": sha256_json(t[start:end + 1])})
                i = end
                start = i + 1
            else:
                # Braced global array initializers: retain their entire statement
                # until the following top-level semicolon.
                i = end
        i += 1
    if start != len(t):
        raise VerificationError(f"Unparsed translation-unit tail: {' '.join(t[start:start + 20])}")
    duplicates = {}
    for kind in ("functions", "structs", "enums", "globals"):
        counts = collections.Counter(item["name"] for item in result[kind])
        duplicates[kind] = {name: n for name, n in counts.items() if n > 1}
    result["duplicates"] = duplicates
    result["counts"] = {kind: len(result[kind]) for kind in ("inputs", "functions", "structs", "enums", "globals")}
    return result


def frozen_files(repo: pathlib.Path, baseline: str, reference_paths_baseline: str | None = None) -> dict:
    rows = subprocess.check_output(["git", "ls-tree", "-rz", baseline], cwd=repo).split(b"\0")
    selected = None
    if reference_paths_baseline is not None:
        selected = set(subprocess.check_output(
            ["git", "ls-tree", "-r", "--name-only", "-z", reference_paths_baseline], cwd=repo
        ).decode("utf-8").split("\0")) - {""}
    format_name = subprocess.check_output(["git", "rev-parse", "--show-object-format"], cwd=repo, text=True).strip()
    if format_name not in ("sha1", "sha256"):
        raise VerificationError(f"Unsupported Git object hash format: {format_name}")
    changed, paths = [], []
    for row in rows:
        if not row:
            continue
        metadata, raw_path = row.split(b"\t", 1)
        mode, kind, expected = metadata.split()
        relative = raw_path.decode("utf-8")
        if selected is not None and relative not in selected:
            continue
        paths.append(relative)
        path = repo / relative
        if kind != b"blob" or mode == b"120000":
            raise VerificationError(f"Unsupported baseline object (requires explicit review): {relative}")
        if not path.is_file() or path.is_symlink():
            changed.append(relative)
            continue
        payload = path.read_bytes()
        digest = hashlib.new(format_name, b"blob " + str(len(payload)).encode() + b"\0" + payload).hexdigest()
        if digest != expected.decode():
            changed.append(relative)
    if selected is not None and set(paths) != selected:
        raise VerificationError("Corrected reference omitted engineering paths: " + repr(sorted(selected - set(paths))))
    return {"baseline": baseline, "reference_paths_baseline": reference_paths_baseline,
            "checked_files": len(paths), "changed_or_missing": changed,
            "unchanged": not changed, "paths": paths}


def verify(repo: pathlib.Path, source: pathlib.Path, monolith: pathlib.Path, baseline: str,
           reference_paths_baseline: str | None = None) -> dict:
    frozen = frozen_files(repo, baseline, reference_paths_baseline)
    left, right = MQLProjection(repo), MQLProjection(repo)
    original = left.project(source)
    flattened = right.project(monolith)
    a, b = tokenize(original), tokenize(flattened)
    first_difference = None
    if a != b:
        position = next((i for i, pair in enumerate(zip(a, b)) if pair[0] != pair[1]), min(len(a), len(b)))
        first_difference = {"token_index": position, "modular": a[max(0, position - 8):position + 9],
                            "monolithic": b[max(0, position - 8):position + 9]}
    inv_a, inv_b = inventory(original), inventory(flattened)
    raw_monolith = uncomment(monolith.read_text(encoding="utf-8"))
    raw_includes = re.findall(r"(?m)^\s*#include\s+([^\n]+)", raw_monolith)
    direct_official_only = len(raw_includes) == 2 and all(
        re.fullmatch(r"<([^>]+)>", value.strip()) and
        value.strip()[1:-1].replace("\\", "/") in OFFICIAL_INCLUDES for value in raw_includes
    )
    matching_inventories = all(inv_a[kind] == inv_b[kind] for kind in inv_a)
    ready = frozen["unchanged"] and a == b and matching_inventories and direct_official_only
    return {
        "schema": "BOOK_MONOLITH_INDEPENDENT_V1", "status": "passed" if ready else "failed",
        "profile": {"language": "MQL5", "undefined_host_macros": ["__cplusplus", "BOOK_RISK_HOST"],
                    "official_headers_expanded": False,
                    "unsupported_directives": "fail_closed", "native_compilation_executed": False},
        "frozen_baseline": frozen,
        "modular": {"path": str(source.relative_to(repo)), "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                    "expanded_files": left.local_graph, "official_includes": left.official,
                    "active_token_count": len(a), "active_tokens_sha256": sha256_json(a), "inventory": inv_a},
        "monolithic": {"path": str(monolith.relative_to(repo)), "source_sha256": hashlib.sha256(monolith.read_bytes()).hexdigest(),
                       "expanded_files": right.local_graph, "official_includes": right.official,
                       "raw_active_includes": raw_includes, "only_two_official_includes": direct_official_only,
                       "active_token_count": len(b), "active_tokens_sha256": sha256_json(b), "inventory": inv_b},
        "comparison": {"active_tokens_equal": a == b, "inventories_equal": matching_inventories,
                       "duplicate_inventory_equal": inv_a["duplicates"] == inv_b["duplicates"],
                       "first_difference": first_difference},
        "limitations": ["Token equality and inventory equality are not native compilation or MT5 approval.",
                        "Official MT5 library headers are preserved as external includes, not expanded or validated.",
                        "Existing modular defects are deliberately preserved; this checks packaging equivalence."],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[1])
    parser.add_argument("--source", default="scalpertalvez.mq5")
    parser.add_argument("--monolith", default="scalpertalvez_MONOLITICO.mq5")
    parser.add_argument("--baseline", default="824e0ced7a3ebb3fd9893c60a4547562ef4cea05")
    parser.add_argument("--reference-paths-baseline", default="323750ad5bc3a9f4e5c92570313b206966dfdff6")
    parser.add_argument("--report", "--output", dest="report", type=pathlib.Path)
    args = parser.parse_args()
    repo = args.repo.resolve()
    try:
        report = verify(repo, repo / args.source, repo / args.monolith, args.baseline,
                        args.reference_paths_baseline)
    except (VerificationError, OSError, subprocess.SubprocessError) as error:
        report = {"schema": "BOOK_MONOLITH_INDEPENDENT_V1", "status": "failed",
                  "error": str(error), "native_compilation_executed": False}
    payload = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.report:
        report_path = args.report if args.report.is_absolute() else repo / args.report
        relative = report_path.resolve().relative_to(repo).as_posix()
        baseline_paths = report.get("frozen_baseline", {}).get("paths", [])
        if relative in baseline_paths:
            raise VerificationError("Refusing to overwrite a frozen baseline file with the report")
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(payload, encoding="utf-8")
        print(json.dumps({"status": report["status"], "report": relative,
                          "comparison": report.get("comparison"),
                          "counts": report.get("modular", {}).get("inventory", {}).get("counts"),
                          "error": report.get("error")}, ensure_ascii=False))
    else:
        print(payload, end="")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
