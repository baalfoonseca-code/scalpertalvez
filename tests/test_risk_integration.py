"""Production trigger/path integration fixtures. No file or broker emulation."""
from pathlib import Path
import subprocess
import tempfile
import unittest
from test_compatibility import function

ROOT = Path(__file__).resolve().parents[1]


def execute(cpp):
    with tempfile.TemporaryDirectory(prefix='book-integration-') as td:
        source = Path(td) / 'fixture.cpp'
        binary = Path(td) / 'fixture'
        source.write_text(cpp)
        built = subprocess.run(['g++', '-std=c++17', '-O2', '-Wall', '-Wextra', str(source), '-o', str(binary)], capture_output=True, text=True)
        if built.returncode:
            raise AssertionError(built.stderr)
        result = subprocess.run([str(binary)], capture_output=True, text=True)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        return result.stdout


class RiskIntegrationTests(unittest.TestCase):
    def test_actual_original_and_configurable_be_trigger(self):
        old = (ROOT / 'scalpertalvez').read_text()
        new = (ROOT / 'scalpertalvez.mq5').read_text()
        cpp = '''#include <cmath>
#include <cassert>
#include <iostream>
struct TradeRecord { int direction; double weightedEntryPrice, slPrice; };
struct MqlTick { double bid, ask; };
double MathAbs(double v){return std::fabs(v);}
namespace original {
'''
        cpp += function(old, 'BERiskPoints') + '\n' + function(old, 'BETriggerReached') + '\n}\n'
        cpp += 'namespace updated { double BE_Trigger_R=1.0;\n'
        cpp += function(new, 'BERiskPoints') + '\n' + function(new, 'BETriggerReached') + '\n}\n'
        cpp += '''int main(){int cases=0;
for(int dir: {-1,1})for(double entry:{5500.0,5500.166666666667,135000.0})
for(double risk:{0.5,5.0,150.0})for(int offset=-200;offset<=200;offset++){
 TradeRecord r{dir,entry,entry-dir*risk};
 double quote=entry+dir*risk+offset*0.1;
 MqlTick tick{quote,quote+0.5};
 assert(original::BETriggerReached(r,tick)==updated::BETriggerReached(r,tick));cases++;
}
for(int dir: {-1,1})for(double multiple:{0.25,1.0,3.0,5.0}){
 updated::BE_Trigger_R=multiple;TradeRecord r{dir,5500,5500-dir*5};
 double trigger=r.weightedEntryPrice+dir*5*multiple;
 // Executable quote only: buy uses bid; sell uses ask, never last/mark.
 MqlTick at{trigger,trigger};assert(updated::BETriggerReached(r,at));
 MqlTick adverse{trigger-dir*0.001,trigger-dir*0.001};
 assert(!updated::BETriggerReached(r,adverse));cases+=2;
 assert(updated::BERiskPoints(r)==5);
}
std::cout<<"actual_BE_trigger_cases="<<cases<<" (controlled quotes, not broker execution)\\n";
}'''
        self.assertIn('actual_BE_trigger_cases=7234', execute(cpp))

    def test_actual_risk_paths_cannot_poison_legacy_emr_namespace(self):
        source = (ROOT / 'Include/BookAdvancedRisk.mqh').read_text()
        cpp = f'#include "{ROOT}/tests/risk_journal_host_support.hpp"\n'
        cpp += '''string TradeMetaPath(ulong pid){return "Scalper01_RC1_identity_"+(string)pid+".meta.csv";}
string RequestJournalPath(bool){return "Scalper01_RC1_identity_request.entry.intent";}
string BookRiskPendingIdentity(){return "frozen";}
string RJChecksum(string){return "7";}
'''
        cpp += function(source, 'BookRiskPath') + '\n' + function(source, 'BookRiskPendingPath')
        cpp += '''\nint main(){
for(ulong pid:{1UL,9007199254740993UL,18446744073709551615UL}){
 string path=BookRiskPath(pid);
 if(path.rfind("BOOK_RISK1_",0)!=0 || path.rfind("Scalper01_RC1_",0)==0)return 1;
 if(path.find((string)pid)==std::string::npos)return 2;
}
string pending=BookRiskPendingPath();
if(pending.rfind("BOOK_RISK1_",0)!=0 || pending==RequestJournalPath(false))return 3;
std::cout<<"separate durable risk namespace verified\\n";
}'''
        self.assertIn('separate durable risk namespace verified', execute(cpp))


if __name__ == '__main__':
    unittest.main()
