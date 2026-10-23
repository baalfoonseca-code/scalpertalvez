"""Focused regression for the native-reported reserved `matrix` identifiers.

Host fixtures exercise actual formatter bodies. They do not compile MQL5 or
reproduce a broker/runtime. The delivered pre-fix revision remains evidence.
"""
from __future__ import annotations

import csv
import hashlib
import io
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASELINE = "eee1b308ed1ee5c92a699f852705413eca9a74ec"
CORRECTED_MODULAR_REFERENCE = "824e0ced7a3ebb3fd9893c60a4547562ef4cea05"
EXPECTED_PROVENANCE = {
    "BOOK_REVISION_AT_GENERATION": '"eee1b308ed1ee5c92a699f852705413eca9a74ec"',
    "BOOK_SOURCE_BUNDLE_SHA256": '"f631060deea71822d03f40b26d8d734e29310a8637b29f55bcc6d45ace5c52bd"',
}
MODULE = "Include/BookArmedDiagnostics.mqh"
sys.path.insert(0, str(ROOT / "tools"))
import verify_monolithic_independent as independent


def baseline_module() -> str:
    return subprocess.check_output(["git", "show", f"{BASELINE}:{MODULE}"], cwd=ROOT, text=True)


def alpha_rename(tokens: list[str]) -> list[str]:
    """Rename code identifiers only, selecting the field versus local binding."""
    result = []
    for i, token in enumerate(tokens):
        if token == "matrix":
            token = "matrixSnapshot" if i > 0 and tokens[i - 1] in (".", "MatrixSnapshot") else "matrixCsvCell"
        result.append(token)
    return result


def full_program_alpha_proof() -> dict:
    """Project both complete programs with only two pinned metadata exceptions."""
    names = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", BASELINE],
                                    cwd=ROOT, text=True).splitlines()
    selected = [name for name in names if name == "scalpertalvez.mq5" or
                (name.startswith("Include/") and name.endswith(".mqh"))]
    if len(selected) != 14:
        raise AssertionError("Expected main plus all 13 original custom modules")
    with tempfile.TemporaryDirectory(prefix="matrix-old-program-") as temporary:
        repo = pathlib.Path(temporary)
        for name in selected:
            target = repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(subprocess.check_output(["git", "show", f"{BASELINE}:{name}"], cwd=ROOT))
        old_active = independent.MQLProjection(repo).project(repo / "scalpertalvez.mq5")
        old = independent.tokenize(old_active)
        original_collisions = reserved_declaration_collisions(old_active)
    current = independent.tokenize(independent.MQLProjection(ROOT).project(ROOT / "scalpertalvez.mq5"))
    expected = alpha_rename(old)
    changed = []
    for name, pinned_value in EXPECTED_PROVENANCE.items():
        indices = [i for i in range(2, len(expected) - 1)
                   if expected[i - 2:i + 1] == ["#", "define", name]]
        current_indices = [i for i in range(2, len(current) - 1)
                           if current[i - 2:i + 1] == ["#", "define", name]]
        if len(indices) != 1 or len(current_indices) != 1:
            raise AssertionError(f"Expected one provenance definition: {name}")
        if current[current_indices[0] + 1] != pinned_value:
            raise AssertionError(f"Unreviewed provenance value: {name}")
        changed.append({"macro": name, "before": expected[indices[0] + 1], "after": pinned_value})
        expected[indices[0] + 1] = pinned_value
    if expected != current:
        difference = next((i for i, pair in enumerate(zip(expected, current)) if pair[0] != pair[1]),
                          min(len(expected), len(current)))
        raise AssertionError(f"Unexpected complete-program token change at {difference}: "
                             f"{expected[max(0, difference-4):difference+5]} vs "
                             f"{current[max(0, difference-4):difference+5]}")
    return {"source_files_materialized": len(selected), "before_tokens": len(old),
            "after_tokens": len(current), "identifier_tokens_renamed": old.count("matrix"),
            "before_reserved_declaration_collisions": original_collisions,
            "provenance_changes": changed, "equal_after_only_permitted_changes": True,
            "normalized_active_tokens_sha256": independent.sha256_json(current)}


MQL_TYPES = {
    "void", "bool", "char", "uchar", "short", "ushort", "int", "uint", "long", "ulong",
    "float", "double", "datetime", "color", "string", "complex", "matrix", "matrixf", "matrixc",
    "vector", "vectorf", "vectorc",
}
RESERVED = MQL_TYPES | {
    "break", "case", "continue", "default", "do", "else", "for", "if", "return", "switch", "while",
    "class", "struct", "enum", "public", "protected", "private", "virtual", "const", "extern", "static",
    "input", "sinput", "new", "delete", "this", "true", "false", "sizeof", "operator", "template",
    "typename", "typedef", "union", "using", "namespace", "import", "export",
}


def reserved_declaration_collisions(active: str) -> list[dict]:
    """Audit typed variable/member/parameter/function names in this MQL program.

    Types come from MQL primitives, source aggregates/enums and MQL/CTrade API
    types. This is an explicit lexical audit, not a replacement MQL parser.
    """
    code = "\n".join(line for line in independent.uncomment(active).splitlines()
                     if not re.match(r"^\s*#", line))
    t = independent.tokenize(code)
    types = set(MQL_TYPES) | {"CTrade", "CPositionInfo"}
    types.update(t[i + 1] for i in range(len(t) - 1) if t[i] in ("struct", "class", "enum"))
    types.update(x for x in t if re.fullmatch(r"(?:Mql[A-Za-z_]\w*|ENUM_[A-Z_0-9]+)", x))
    found = []
    seen = set()
    identifier = lambda value: re.fullmatch(r"[A-Za-z_]\w*", value) is not None
    for i, type_name in enumerate(t[:-2]):
        if type_name not in types:
            continue
        j = i + 1
        while j < len(t) and t[j] in ("&", "*"):
            j += 1
        if j >= len(t) - 1 or not identifier(t[j]) or t[j + 1] not in ("[", "(", ")", ";", ",", "="):
            continue
        candidates = [j]
        if t[j + 1] != "(":
            level = 0
            k = j + 1
            while k < len(t):
                value = t[k]
                if level == 0 and value in (";", ")"):
                    break
                if value in ("(", "[", "{"):
                    level += 1
                elif value in (")", "]", "}"):
                    level -= 1
                elif value == "," and level == 0:
                    if k + 1 < len(t) and identifier(t[k + 1]):
                        peek = k + 1
                        while peek < len(t) and t[peek] in ("const", "static", "extern"):
                            peek += 1
                        if peek + 1 < len(t) and t[peek] in types and (
                            identifier(t[peek + 1]) or t[peek + 1] in ("&", "*")
                        ):
                            break  # Next function parameter declares its own type.
                        candidates.append(k + 1)
                k += 1
        for position in candidates:
            if t[position] in RESERVED and position not in seen:
                found.append({"type": type_name, "name": t[position], "token_index": position})
                seen.add(position)
    return found


def mql_module_types() -> str:
    original = (ROOT / "scalpertalvez").read_text(encoding="utf-8")
    definitions = []
    for name in ("POCResult", "MatrixSnapshot"):
        match = re.search(r"struct " + name + r"\s*\{.*?\n\};", original, re.S)
        if not match:
            raise AssertionError(f"Missing baseline structure: {name}")
        definitions.append(match.group())
    return "\n".join(definitions)


def fill_matrix_fields(prefix: str) -> str:
    """Initialize every scalar in the actual historical snapshot/POC structs."""
    definitions = mql_module_types()
    output, seed = [], 1
    for name, target in (("MatrixSnapshot", prefix), ("POCResult", prefix + ".pocNow"),
                         ("POCResult", prefix + ".pocPrev")):
        body = re.search(r"struct " + name + r"\s*\{(.*?)\n\};", definitions, re.S).group(1)
        for match in re.finditer(r"\b(bool|double|int|long|datetime|ENUM_MSS|ENUM_POC_STATE)\s+([^;]+);",
                                 independent.uncomment(body)):
            kind, fields = match.groups()
            for field in fields.split(","):
                field = field.strip()
                if not re.fullmatch(r"[A-Za-z_]\w*", field):
                    raise AssertionError(f"Unsupported scalar field: {field}")
                value = f"((case_id+{seed})%2)!=0" if kind == "bool" else (
                    f"(case_id-3)*1.25+{seed}.125" if kind == "double" else f"case_id+{seed}")
                output.append(f"{target}.{field}={value};")
                seed += 1
    return "\n".join(output)


def formatter_fixture(source: str) -> str:
    stubs = (ROOT / "tests/armed_observer_stubs.hpp").read_text()
    old = 'template<class... A> string StringFormat(const char *f,const A&...) { return f; }'
    replacement = r'''template<class... A> string StringFormat(const char *f,const A&... values) {
 int n=std::snprintf(nullptr,0,f,values...); assert(n>=0);
 std::vector<char> out((std::size_t)n+1);std::snprintf(out.data(),out.size(),f,values...);
 return string(out.data(),(std::size_t)n);
}'''
    if old not in stubs:
        raise AssertionError("Host format adapter changed; review required")
    stubs = '#include <cstdio>\n#include <vector>\n' + stubs.replace(old, replacement)
    source = source.replace("uchar bytes[];", "std::vector<uchar> bytes;")
    signatures = re.findall(r"^(?:bool|void|string) BookDiag\w+\([^\n]*\)", source, re.M)
    prototypes = "\n".join(re.sub(r"=(?:false|true|\"\")", "", value) + ";" for value in signatures)
    source = source.replace("bool BookDiagEnabled()", prototypes + "\nbool BookDiagEnabled()", 1)
    member = "matrixSnapshot" if "MatrixSnapshot matrixSnapshot;" in source else "matrix"
    main = r'''
int main(){
 gBookDiagRun="run;\"A";gBookDiagExecutionContext="context-A";
 std::cout<<BookDiagHeader()<<"\r\n";
 for(int case_id=0;case_id<24;case_id++){
  BookArmedEvent e{};e.event="WAIT;\"MATRIX\"";e.reason="same\nreason";
  e.observed_msc=1000000+case_id;e.order=200+case_id;e.deal=300+case_id;
  e.position=400+case_id;e.request_id=500+case_id;e.retcode=10009;
  e.confirmed_volume=1.25;e.confirmed_entry=130000.25;
  auto &s=e.state;s.id="signal;\"id";s.route=case_id%2?"ABS":"CONT";
  s.mode=case_id%2?"BASE":"TURBO";s.subtype="DIVERGENCE";s.signal_bar=100;
  s.armed_at=100;s.high=130000.5;s.low=129990.5;s.margin=5;s.effort_min=1.5;
  s.live_available=case_id%2;s.matrix_available=case_id%3;s.book_consulted=case_id%4;
  s.live_direction=-1;s.live_effort=2.0;s.live_volume=1000;s.live_average=500;
  s.spread=5;s.overshoot=10;s.sigma=200;s.sigma_days=5;s.vwap_d1=130000;
  s.d1_high=131000;s.d1_low=129000;s.terminal="terminal;\"value";
  BookArmedResetTrace(s.trace,case_id%2?1:-1,100000,130005);
  BookArmedObserveTrade(s.trace,130006,101000,101000);
  BookArmedBlock(s.trace,BD_WAVE_EFFORT);
  FILL_MATRIX
  if(case_id==23)s.MEMBER.vwapVig=std::numeric_limits<double>::infinity();
  std::cout<<BookDiagFormat(e);
 }
}
'''.replace("FILL_MATRIX", fill_matrix_fields("s." + member)).replace("MEMBER", member)
    return stubs + "\n" + mql_module_types() + "\n" + source + "\n#include <limits>\n" + main


class MatrixIdentifierFixTests(unittest.TestCase):
    def test_entire_active_mql_program_changes_only_identifiers_and_pinned_provenance(self):
        result = full_program_alpha_proof()
        self.assertTrue(result["equal_after_only_permitted_changes"])
        self.assertEqual(result["source_files_materialized"], 14)
        self.assertEqual(len(result["provenance_changes"]), 2)
        self.assertEqual([x["name"] for x in result["before_reserved_declaration_collisions"]],
                         ["matrix", "matrix"])
    def test_corrected_modular_reference_changes_only_the_authorized_two_files(self):
        changed = subprocess.check_output(
            ["git", "diff", "--name-only", BASELINE, CORRECTED_MODULAR_REFERENCE], cwd=ROOT, text=True
        ).splitlines()
        self.assertEqual(changed, [MODULE, "Include/BookBuildIdentity.mqh"])

    def test_exact_identifier_alpha_renaming_and_nothing_else(self):
        original = independent.tokenize(baseline_module())
        current = independent.tokenize((ROOT / MODULE).read_text())
        self.assertEqual(current, alpha_rename(original))
        self.assertNotIn("matrix", current)
        self.assertIn("matrixSnapshot", current)
        self.assertIn("matrixCsvCell", current)

    def test_all_csv_string_literals_remain_exact(self):
        original = [t for t in independent.tokenize(baseline_module()) if t.startswith('"')]
        current = [t for t in independent.tokenize((ROOT / MODULE).read_text()) if t.startswith('"')]
        self.assertEqual(original, current)
        self.assertTrue(any(t.startswith('"matrix.') for t in current))

    def test_mql_active_declarations_have_no_reserved_type_name_collisions(self):
        for source in ("scalpertalvez.mq5", "scalpertalvez_MONOLITICO.mq5"):
            active = independent.MQLProjection(ROOT).project(ROOT / source)
            with self.subTest(source=source):
                self.assertEqual(reserved_declaration_collisions(active), [])

    def test_collision_audit_detects_member_local_parameter_and_comma_declarators(self):
        sample = "struct S {double matrix;};string vector;double x,matrixf;bool f(int vectorc);"
        found = reserved_declaration_collisions(sample)
        self.assertEqual([x["name"] for x in found], ["matrix", "vector", "matrixf", "vectorc"])
        self.assertEqual(reserved_declaration_collisions('matrix valid;string message="matrix";'), [])

    def test_frozen_reference_membership_rejects_changed_missing_and_omitted_paths(self):
        # Exercise the ACTUAL checker in an isolated fixture repository. Never
        # mutate a protected working-tree file to test the guard protecting it.
        with tempfile.TemporaryDirectory(prefix="matrix-reference-guard-") as temporary:
            repo = pathlib.Path(temporary)
            def git(*args):
                return subprocess.check_output(["git", *args], cwd=repo, text=True, stderr=subprocess.PIPE).strip()
            def commit(message):
                git("add", "-A")
                git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", message)
                return git("rev-parse", "HEAD")
            git("init", "-q")
            (repo / "protected.mqh").write_text("original\n")
            (repo / "second.txt").write_text("preserve\n")
            original = commit("original membership")
            corrected = "authorized corrected content\n"
            (repo / "protected.mqh").write_text(corrected)
            (repo / "complementary.txt").write_text("outside engineering membership\n")
            current = commit("corrected reference plus complementary file")
            report = independent.frozen_files(repo, current, original)
            self.assertTrue(report["unchanged"])
            self.assertEqual(report["checked_files"], 2)
            self.assertEqual(set(report["paths"]), {"protected.mqh", "second.txt"})
            (repo / "protected.mqh").write_text("unauthorized change\n")
            report = independent.frozen_files(repo, current, original)
            self.assertFalse(report["unchanged"])
            self.assertEqual(report["changed_or_missing"], ["protected.mqh"])
            (repo / "protected.mqh").write_text(corrected)
            (repo / "second.txt").unlink()
            report = independent.frozen_files(repo, current, original)
            self.assertFalse(report["unchanged"])
            self.assertEqual(report["changed_or_missing"], ["second.txt"])
            omitted = commit("invalid corrected reference omits original member")
            with self.assertRaisesRegex(independent.VerificationError, "omitted engineering paths"):
                independent.frozen_files(repo, omitted, original)

    @unittest.skipUnless(shutil.which("g++"), "g++ unavailable: formatter byte comparison not executed")
    def test_actual_csv_formatter_bytes_before_after_and_monolith(self):
        original = baseline_module()
        current = (ROOT / MODULE).read_text()
        monolith = (ROOT / "scalpertalvez_MONOLITICO.mq5").read_text()
        begin = monolith.index("#ifndef BOOK_ARMED_DIAGNOSTICS_V1")
        end = monolith.index("// END_INCORPORATED Include/BookArmedDiagnostics.mqh", begin)
        # The original custom math include is already incorporated in the
        # monolith; the host adapter requires its __cplusplus branch. The actual
        # formatter/module code after that math boundary is taken verbatim.
        math_end = monolith.index("// END_INCORPORATED Include/BookArmedMath.mqh", begin)
        mono_module = monolith[begin:math_end].split("// ORIGINAL_INCLUDE", 1)[0] + '#include "BookArmedMath.mqh"\n' + monolith[monolith.index("\n", math_end) + 1:end]
        outputs = []
        with tempfile.TemporaryDirectory(prefix="matrix-alpha-csv-") as temporary:
            for label, source in (("before", original), ("after", current), ("monolith", mono_module)):
                path = pathlib.Path(temporary) / (label + ".cpp")
                path.write_text(formatter_fixture(source))
                executable = path.with_suffix("")
                result = subprocess.run(["g++", "-std=c++17", "-Wall", "-Wextra", "-Werror", "-O2",
                                         "-I", str(ROOT / "Include"), str(path), "-o", str(executable)],
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                run = subprocess.run([str(executable)], capture_output=True)
                self.assertEqual(run.returncode, 0, run.stderr)
                outputs.append(run.stdout)
        self.assertEqual(outputs[0], outputs[1])
        self.assertEqual(outputs[1], outputs[2])
        rows = list(csv.reader(io.StringIO(outputs[0].decode()), delimiter=";"))
        self.assertEqual(len(rows), 25)
        self.assertEqual(len(rows[0]), 83)
        for row in rows[1:]:
            self.assertEqual(len(row), len(rows[0]))
        self.assertTrue(any('matrix.vwapVig=' in row[-1] for row in rows[1:]))
        print("MATRIX_IDENTIFIER_CSV: 24 actual formatter rows identical across before/after/monolith; "
              f"bytes={len(outputs[0])}; SHA256={hashlib.sha256(outputs[0]).hexdigest()}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
