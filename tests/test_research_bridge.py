"""Execute the delivered bridge state hook with mechanical MQL string casts."""
from pathlib import Path
import re
import unittest
from test_compatibility import declaration, function
from test_decision_integration import execution_fixture, decision_adapter_policy
from test_research_runtime import run_program
ROOT=Path(__file__).resolve().parents[1]

class ResearchBridgeTests(unittest.TestCase):
    def test_repeated_native_wait_return_is_deduplicated_and_finances_unchanged(self):
        bridge=(ROOT/'Include/BookResearchBridge.mqh').read_text()
        body=function(bridge,'BookResearchAfterSend')
        body=re.sub(r'\(string\)((?:\(int\))?\w+(?:\.\w+)*)',r'research_string(\1)',body)
        extra=decision_adapter_policy()+f'''
bool Inp_ResearchEnable=true;constexpr int COPY_TICKS_ALL=3,COPY_TICKS_TRADE=1;
template<class T>void ArrayFree(std::vector<T>&x){{x.clear();}}
int CopyTicks(string,std::vector<MqlTick>&x,int,ulong,uint){{x.clear();return 0;}}
#include "{ROOT}/Include/BookResearchRuntime.mqh"
#define BOOK_RESEARCH_CAPTURE_CAP 32
{declaration(bridge,'struct','BookResearchEvidenceCapture')}
BookResearchEvidenceCapture gBookResearchEvidenceCaptures[32],gBookResearchLastOperational;
BookDecisionHistory gBookResearchReferenceCaptures[32],gBookDecisionHistory;
bool gBookResearchReferenceAvailable[32];
int gBookResearchEvidenceHead=0,gBookResearchEvidenceCount=0;
string gBookResearchArmedID="test",gBookResearchAfterSendStamp="",gBookDecisionReason="INSUFFICIENT_REFERENCES";
ulong gBookResearchDispatchSequence=0,gBookResearchLastAfterDispatchSequence=0;
long gBookDecisionEpoch=1,gBookDecisionDataVersion=1;
template<class T>string research_string(T x){{return std::to_string(x);}}
{body}
'''
        main=r'''
int main(){fixture_reset(1,false,false,1);BookDecisionConfig c;BookDecisionConfigDefaults(c);
 BookResearchRuntimeInit("bridge","preset","fixture","1","2","code",DECISION_APLICAR,c);
 auto pending=gPendingExec;auto signal=armed;int quota=ordersEnteredToday;
 for(int i=0;i<10000;i++)BookResearchAfterSend(SEND_WAIT_ARMED);
 assert(gBookResearchQueueCount==2&&!gBookResearchSuspended&&gBookResearchEvidenceCount==0);
 assert(trade.calls==0&&gPendingExec.active==pending.active&&armed.armedAt==signal.armedAt&&ordersEnteredToday==quota);
 gBookDecisionReason="DIFFERENT_REASON";BookResearchAfterSend(SEND_WAIT_ARMED);assert(gBookResearchQueueCount==3);
 std::cout<<"native_bridge_wait_returns=10000 events=1 API=0 finances_unchanged=1\n";
}
'''
        source=(ROOT/'scalpertalvez.mq5').read_text()
        program=execution_fixture(source,extra,main,full_guards=True,operational=True)
        program=program.replace('struct MqlTick { long long time_msc=', 'struct MqlTick { long long time=0,time_msc=')
        out,_=run_program(f'#include "{ROOT}/tests/research_noop_hooks.hpp"\n'+program)
        self.assertIn('wait_returns=10000 events=1',out)
        print(out.strip())

    def test_blocked_read_only_snapshots_keep_their_own_bar_clock(self):
        from test_research_runtime import run
        bridge=(ROOT/'Include/BookResearchBridge.mqh').read_text()
        body=function(bridge,'BookResearchObserveBlockedMatrix')
        code=r'''
struct MatrixSnapshot{bool absValid=true,contValid=false;};
std::vector<long> bars;
void BookResearchQueueCandidate(const MatrixSnapshot&,int,bool,string,double,double,bool,string,string,long bar){bars.push_back(bar);}
'''+body+r'''
int main(){MatrixSnapshot s;BookResearchObserveBlockedMatrix(s,960);BookResearchObserveBlockedMatrix(s,1020);
 assert(bars.size()==2&&bars[0]==960&&bars[1]==1020);std::cout<<"read_only_blocked_distinct_bar_identities=2\n";}
'''
        result,_=run(code)
        self.assertIn('bar_identities=2',result)

if __name__=='__main__':unittest.main(verbosity=2)
