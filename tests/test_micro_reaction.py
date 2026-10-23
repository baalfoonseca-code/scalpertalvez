"""Execute actual reaction lifecycle on controlled completed windows (no MT5)."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from test_compatibility import function

ROOT = Path(__file__).resolve().parents[1]


class MicroReactionTests(unittest.TestCase):
    def test_actual_delayed_detection_reaction_and_invalidation(self):
        source = (ROOT / 'Include/BookMicrostructure.mqh').read_text()
        main = (ROOT / 'scalpertalvez.mq5').read_text()
        flow = re.search(r'struct ResponseFlow\s*\{.*?\n\};', main, re.S).group(0)
        cpp = f'''#include <cassert>
#include <iostream>
#include <algorithm>
#include "{ROOT}/Include/BookMicroMath.mqh"
{flow}
struct ResponseRecord {{ ResponseFlow now; long event_msc; double tick_size;
 struct {{struct {{bool ok;double poc;}} pocNow;}} snapshot; }};
long gBookMicroTestStart=1,gBookMicroTestEnd=59999,gBookMicroReactionStart=0;
long gBookMicroTestReferenceMSC=1000,gBookMicroTestLastWindow=59999,gBookMicroTestRecognizedMSC=60500;
double gBookMicroTestLevel=100,gBookMicroTestTolerance=0.5,gBookMicroTestExtreme=99,gBookMicroTestPOC=100;
int gBookMicroTestDirection=-1,gBookMicroReactionState=1;
bool Inp_Obs_TrustAggressorFlags=true;
bool BookMicroSameDay(long a,long b){{return a>0&&b>0&&a/86400000==b/86400000;}}
long MathMax(long a,long b){{return std::max(a,b);}}
'''
        cpp += function(source, 'BookMicroTestReaction')
        cpp += '''
int main(){
 ResponseRecord r{};BookMicroSnapshot o{};
 r.now.from_msc=60000;r.now.to_msc=119999;r.now.first_msc=60001;
 BookMicroTestReaction(r,o);
 assert(o.reaction_status==7&&gBookMicroReactionStart==0&&gBookMicroReactionState==1);
 assert(gBookMicroTestLastWindow==119999); // no retrospective reaction
 r.now.from_msc=120000;r.now.to_msc=179999;r.now.first_msc=120001;
 r.now.vb=60;r.now.complete=true;r.tick_size=1;r.snapshot.pocNow={true,102};
 o={};BookMicroFlowReset(o.flow,120000,179999,100,0.5,1000);
 for(int i=0;i<60;i++)BookMicroFlowTick(o.flow,101+i/59.0,1,120001+i*1000);
 r.now.last_price=o.flow.last;o.metrics.volume=60;
 BookMicroTestReaction(r,o);
 assert(o.reaction_status==3&&gBookMicroReactionState==3);
 assert(o.reaction_recovery_ticks>0&&o.reaction_efficiency>0.9&&o.regime==5);
 // A missing independent window is unknown, never a fabricated reaction.
 gBookMicroReactionState=1;gBookMicroTestLastWindow=179999;
 r.now.from_msc=180001;r.now.to_msc=239999;o={};
 o.flow.level_available=true;o.flow.level=100;o.flow.reference_msc=1000;
 BookMicroTestReaction(r,o);assert(o.reaction_status==5&&gBookMicroReactionState==5);
 // Acceptance in the original selling direction invalidates reversal candidacy.
 gBookMicroReactionState=1;gBookMicroReactionStart=0;gBookMicroTestLastWindow=119999;
 r.now.from_msc=120000;r.now.to_msc=179999;r.now.first_msc=120001;
 r.now.vb=0;r.now.vs=60;r.snapshot.pocNow={true,98};o={};
 BookMicroFlowReset(o.flow,120000,179999,100,0.5,1000);
 for(int i=0;i<60;i++)BookMicroFlowTick(o.flow,99-i/59.0,1,120001+i*1000);
 r.now.last_price=o.flow.last;o.metrics.volume=60;o.metrics.level_available=true;o.metrics.temporal_coverage=1;
 BookMicroTestReaction(r,o);assert(o.reaction_status==4&&gBookMicroReactionState==4);
 // A late touch cannot attribute the whole window's earlier effort to a test.
 gBookMicroReactionState=0;o={};o.flow.level_available=true;
 o.flow.first_msc=120001;o.flow.touch_msc=150000;
 o.metrics.pressure_robust=true;o.pressure_label=1;o.conditional_available=true;
 o.resistance=1;o.metrics.temporal_coverage=1;o.metrics.acceptance_volume_ratio=0;
 BookMicroTestReaction(r,o);assert(o.test_status==3&&gBookMicroReactionState==0);
 std::cout<<"actual micro reaction: delayed recognition, confirmation, gap, invalidation, late-touch cases passed\\n";
}'''
        with tempfile.TemporaryDirectory(prefix='book-reaction-') as td:
            path=Path(td)/'reaction.cpp';path.write_text(cpp);exe=path.with_suffix('')
            result=subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra','-Werror',str(path),'-o',str(exe)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            result=subprocess.run([str(exe)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            print(result.stdout.strip())


if __name__ == '__main__':
    unittest.main()
