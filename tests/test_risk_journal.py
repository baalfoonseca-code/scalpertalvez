"""Execute exact production journal/parser bodies with narrow ASCII host shims.

This verifies serialization, strict parsing and config validation. It does not
claim native MQL compilation, file durability or broker lifecycle verification.
"""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

def extract(source, name):
    match = re.search(r"^(?:bool|string|void|double|int)\s+" + re.escape(name) + r"\s*\(", source, re.M)
    if not match:
        raise AssertionError(f"production function missing: {name}")
    begin = source.index("{", match.start())
    depth = 1
    end = begin + 1
    while depth:
        if source[end] == "{":
            depth += 1
        elif source[end] == "}":
            depth -= 1
        end += 1
    return source[match.start():end]

class RiskJournalTests(unittest.TestCase):
    def test_actual_journal_parser_and_inputs(self):
        source = (ROOT / "scalpertalvez").read_text()
        risk = (ROOT / "Include/BookAdvancedRisk.mqh").read_text()
        struct = re.search(r"struct BookRiskState\s*\{.*?\};", risk, re.S).group(0)
        fragments = [extract(source, name) for name in
                     ("CsvParsePID", "RJUnsigned", "RJDouble", "RJEncode", "RJDecode", "RJRoute", "RJChecksum")]
        # The only syntax conversion maps MQL dynamic string arrays to vectors.
        bodies = [extract(risk, name) for name in ("BookRiskInputsValid", "BookRiskD", "BookRiskRow")]
        # Optional independent signed parser, when production needs one for PnL.
        for optional in ("BookRiskSignedDouble", "BookRiskParseSigned", "BookRiskSigned"):
            if re.search(r"^bool\s+" + optional + r"\(", risk, re.M):
                bodies.append(extract(risk, optional))
        bodies.append(extract(risk, "BookRiskParse").replace("string f[],symbol;", "std::vector<string> f; string symbol;"))
        content = ('#define BOOK_RISK_HOST\n#define input\n'
                   f'#include "{ROOT}/Include/BookRiskCore.mqh"\n'
                   f'#include "{ROOT}/Include/BookRiskInputs.mqh"\n'
                   f'#include "{ROOT}/tests/risk_journal_host_support.hpp"\n'
                   'bool Inp_EnableBreakEven=true;\n' + struct + '\n' + '\n'.join(fragments+bodies) + '\n' +
                   (ROOT / "tests/test_risk_journal.cpp").read_text())
        with tempfile.TemporaryDirectory(prefix="book-risk-journal-") as td:
            cpp = Path(td) / "risk-journal.cpp"
            cpp.write_text(content)
            exe = Path(td) / "risk-journal"
            built = subprocess.run(["g++", "-std=c++17", "-O2", "-Wall", "-Wextra", "-Wno-sign-compare",
                                    str(cpp), "-o", str(exe)], text=True, capture_output=True)
            self.assertEqual(built.returncode, 0, built.stderr)
            result = subprocess.run([str(exe)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            print(result.stdout.strip())

if __name__ == "__main__":
    unittest.main()
