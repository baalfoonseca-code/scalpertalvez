import pathlib
import re
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ArmedDiagnostics(unittest.TestCase):
    def test_actual_observer_collection_state(self):
        base = (ROOT / "scalpertalvez").read_text()
        structs = "\n".join(re.search(r"struct " + name + r"\s*\{.*?\n\};", base, re.S).group(0)
                            for name in ("POCResult", "MatrixSnapshot"))
        code = (ROOT / "Include/BookArmedDiagnostics.mqh").read_text()
        # Exactly one syntax adaptation for MQL5 dynamic arrays; no financial
        # branch or collection logic is removed/reimplemented by this adapter.
        code = code.replace("uchar bytes[];", "std::vector<uchar> bytes;")
        signatures = re.findall(r"^(?:bool|void|string) BookDiag\w+\([^\n]*\)", code, re.M)
        prototypes = "\n".join(re.sub(r"=(?:false|true|\"\")", "", x) + ";" for x in signatures)
        code = code.replace("bool BookDiagEnabled()", prototypes + "\nbool BookDiagEnabled()", 1)
        with tempfile.TemporaryDirectory() as temp:
            cpp = pathlib.Path(temp) / "armed.cpp"
            cpp.write_text('#include "armed_observer_stubs.hpp"\n' + structs + "\n" + code
                           + '\n#include "armed_observer_cases.cpp"\n')
            exe = pathlib.Path(temp) / "armed"
            build = subprocess.run(["g++", "-std=c++17", "-Wall", "-Wextra", "-Werror", "-O2",
                                    "-I", str(ROOT / "tests"), "-I", str(ROOT / "Include"),
                                    str(cpp), "-o", str(exe)], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            result = subprocess.run([str(exe)], check=True, capture_output=True, text=True)
            self.assertIn("21 deterministic host-adapted collection cases passed", result.stdout)

    def test_actual_shared_trace_math(self):
        with tempfile.TemporaryDirectory() as temp:
            exe = pathlib.Path(temp) / "armed_trace"
            subprocess.run(
                ["g++", "-std=c++17", "-Wall", "-Wextra", "-Werror", "-O2",
                 str(ROOT / "tests/armed_trace_harness.cpp"), "-o", str(exe)],
                check=True, capture_output=True, text=True,
            )
            run = subprocess.run([str(exe)], check=True, capture_output=True, text=True)
            self.assertIn("23 deterministic cases passed", run.stdout)

    def test_csv_schema_column_integrity(self):
        source = (ROOT / "Include/BookArmedDiagnostics.mqh").read_text()
        formatter = source.split("string BookDiagFormat(", 1)[1].split("string BookDiagHeader()", 1)[0]
        header = re.search(r'string BookDiagHeader\(\)\s*\{\s*return "([^"]+)";', source).group(1)
        # Every outer field uses this helper; the full frozen matrix is a nested
        # escaped cell, not an accidental variable number of columns.
        cells = len(re.findall(r"BookDiagCell\(row,", formatter))
        self.assertEqual(len(header.split(";")), cells)
        self.assertEqual(len(set(header.split(";"))), cells)

    def test_no_financial_or_market_read_side_effects(self):
        source = (ROOT / "Include/BookArmedDiagnostics.mqh").read_text()
        self.assertNotRegex(source, r"\b(?:PositionModify|PositionOpen|PositionClose|OrderSend|CopyTicks|CopyRates|MarketBookGet|HistorySelect|SymbolInfoTick)\s*\(")
        self.assertNotRegex(source, r"\b(?:armed|gPendingExec|gPendingExit|SigmaD1)\.[\w]+\s*=")
        self.assertIn('"ORDER_SENT"', source)
        self.assertIn('"AUTHORITATIVE_ENTRY_DEALS_NOT_FULL_FILL_GUARANTEE"', source)


if __name__ == "__main__":
    unittest.main()
