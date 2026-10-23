"""Actual shared arithmetic plus boundary/schema checks; not an MT5 compiler."""
import pathlib
import re
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class MicrostructureTests(unittest.TestCase):
    def test_actual_shared_math(self):
        with tempfile.TemporaryDirectory(prefix="book_micro_") as temp:
            binary = pathlib.Path(temp) / "micro"
            subprocess.run(
                ["g++", "-std=c++17", "-O2", "-Wall", "-Wextra", "-Werror",
                 str(ROOT / "tests/test_micro_math.cpp"), "-o", str(binary)],
                check=True, capture_output=True, text=True,
            )
            result = subprocess.run([str(binary)], check=True, capture_output=True, text=True)
            self.assertIn("20705 assertions", result.stdout)
            self.assertIn("not MT5 OnTick latency", result.stdout)

    def test_fixed_csv_schema_matches_formatter(self):
        source = (ROOT / "Include/BookMicrostructure.mqh").read_text()
        header = re.search(r'string BookMicroHeader\(\)\s*\{\s*return "([^"]+)";', source).group(1)
        cells = source.split("void BookMicroCells(", 1)[1]
        self.assertEqual(len(header.split(";")), cells.count("BookMicroCell(row,"))
        self.assertEqual(len(header.split(";")), len(set(header.split(";"))))

    def test_observer_has_no_financial_or_duplicate_feed_api(self):
        source = "\n".join((ROOT / "Include" / name).read_text() for name in
                           ["BookMicroMath.mqh", "BookMicrostructure.mqh"])
        # Strip comments so documentation can name APIs without executing them.
        source = re.sub(r"//[^\n]*|/\*.*?\*/", "", source, flags=re.S)
        for name in ["OrderSend", "PositionOpen", "PositionModify", "PositionClose",
                     "CopyTicks", "CopyTicksRange", "MarketBookGet", "EvaluateMatrix",
                     "ResetArmedSignal", "FileDelete", "Sleep"]:
            self.assertNotRegex(source, rf"\b{re.escape(name)}\s*\(")
        self.assertNotRegex(source, r"\barmed\.\w+\s*=(?!=)")
        self.assertNotRegex(source, r"\bgLastMatrixEvalBar\s*=")

    def test_main_integration_uses_existing_flow(self):
        source = (ROOT / "scalpertalvez.mq5").read_text()
        self.assertEqual(source.count("BookMicroFlowTick(f.micro,price,volume,msc);"), 1)
        self.assertEqual(source.count("BookMicroCapture(r);"), 1)
        self.assertEqual(source.count("BookMicroCells(row,r.micro);"), 1)
        self.assertIn("BookMicroFreezeWindow(gResponseWindows[index].flow.micro);", source)
        self.assertNotRegex(source, r"if\s*\([^\n]*(?:BookMicroCapture|BookMicroCompute)")


if __name__ == "__main__":
    unittest.main()
