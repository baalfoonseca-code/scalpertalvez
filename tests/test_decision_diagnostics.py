"""Diagnostic-cause regression; host fixture, not native MQL5 compilation.

The operational late-breakout predicate remains in SendOrder. This test executes
the actual diagnostic mapper and terminal/outcome bodies to prove that its cause
survives the following generic SEND_FINAL_FAILURE without attributing it to DOM.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest

from test_compatibility import function

ROOT = Path(__file__).resolve().parents[1]


class DecisionDiagnosticsTests(unittest.TestCase):
    def test_actual_late_breakout_mapping_survives_generic_send_outcome(self):
        module = (ROOT / "Include/BookArmedDiagnostics.mqh").read_text()
        cpp = '''#include "armed_observer_stubs.hpp"
#include "BookArmedMath.mqh"
struct MinimalDiagnostic { bool active=true; string terminal; BookArmedTrace trace{}; };
MinimalDiagnostic gBookDiagState;
bool gBookDiagReady=true;
std::vector<string> emitted;
int otherGateCalls=0;
bool BookDiagEnabled(){return Inp_EnableArmedDiagnostics && gBookDiagReady;}
void BookDiagEmit(string event,string reason,bool){
 assert(event=="TERMINAL");emitted.push_back(reason);
}
void BookDiagWait(int,string){otherGateCalls++;}
'''
        cpp += "\n".join(function(module, name) for name in
                         ("BookDiagFinish", "BookDiagAudit", "BookDiagSendOutcome"))
        cpp += '''
int main(){
 for(int dispatchSite=0;dispatchSite<2;dispatchSite++){
  gBookDiagState={};gBookDiagState.active=true;emitted.clear();
  BookDiagAudit("LATE_BREAKOUT_LOST");
  assert(!gBookDiagState.active);
  assert(gBookDiagState.terminal=="CANCEL_BREAKOUT_LOST");
  assert(emitted.size()==1 && emitted[0]=="CANCEL_BREAKOUT_LOST");
  BookDiagSendOutcome(SEND_FINAL_FAILURE);
  assert(gBookDiagState.terminal=="CANCEL_BREAKOUT_LOST" && emitted.size()==1);
  assert(otherGateCalls==0); // No invented book or another operational gate.
 }
 Inp_EnableArmedDiagnostics=false;gBookDiagState={};gBookDiagState.active=true;
 emitted.clear();BookDiagAudit("LATE_BREAKOUT_LOST");
 assert(gBookDiagState.active && emitted.empty());
 Inp_EnableArmedDiagnostics=true;
 BookDiagAudit("OVERSHOOT_BLOCK");assert(gBookDiagState.terminal=="CANCEL_OVERSHOOT");
 std::cout<<"late-breakout cause retained at both send sites; diagnostics-off unchanged\\n";
}
'''
        with tempfile.TemporaryDirectory(prefix="book-decision-diagnostic-") as temporary:
            source = Path(temporary) / "fixture.cpp"
            source.write_text(cpp)
            exe = source.with_suffix("")
            built = subprocess.run(["g++", "-std=c++17", "-Wall", "-Wextra", "-Werror", "-O2",
                                    "-I", str(ROOT / "tests"), "-I", str(ROOT / "Include"),
                                    str(source), "-o", str(exe)], text=True, capture_output=True)
            self.assertEqual(built.returncode, 0, built.stderr)
            run = subprocess.run([str(exe)], text=True, capture_output=True)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertIn("late-breakout cause retained at both send sites", run.stdout)

    def test_both_original_sendorder_late_breakout_diagnostics_are_preserved(self):
        body = function((ROOT / "scalpertalvez.mq5").read_text(), "SendOrder")
        self.assertEqual(body.count('WriteAuditRow("LATE_BREAKOUT_LOST"'), 2)


if __name__ == "__main__":
    unittest.main()
