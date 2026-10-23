"""Compile and execute the production risk kernel; no broker API is simulated."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class RiskCoreTests(unittest.TestCase):
    def test_actual_risk_core(self):
        with tempfile.TemporaryDirectory(prefix="book-risk-test-") as td:
            exe = Path(td) / "risk-core"
            subprocess.run(["g++", "-std=c++17", "-O2", "-Wall", "-Wextra", "-Werror",
                            str(ROOT / "tests/test_risk_core.cpp"), "-o", str(exe)], check=True)
            result = subprocess.run([str(exe)], text=True, capture_output=True, check=True)
            print(result.stdout.strip())
            self.assertIn("assertions passed", result.stdout)

if __name__ == "__main__":
    unittest.main()
