"""Complete actual tick collector -> policy -> entry controller -> API fixture.

Only terminal, quote/depth and durable-file APIs are deterministic adapters.
The collector, history, evidence, verdict, original readiness, decision gates,
cleanup and complete SendOrder bodies are the delivered code. Not an MT5 test.
"""
from pathlib import Path
import unittest
from test_compatibility import function
from test_decision_integration import execution_fixture, compile_run
from test_decision_runtime import CASES

ROOT = Path(__file__).resolve().parents[1]


def pipeline_fixture(main):
    extra = f'''
#define input
#include "{ROOT}/Include/BookDecisionInputs.mqh"
#undef input
#include "{ROOT}/Include/BookMicroMath.mqh"
struct MatrixSnapshot {{ int status=1;bool absValid=false,contValid=false;
 bool absDivergence=false,absFollowingReaction=false;int dir=0,dirCont=0; }};
constexpr int MSS_OK=1,COPY_TICKS_TRADE=1,MQL_MEMORY_USED=1;
bool Inp_EnableArmedDiagnostics=false;
void BookDiagBeforeReset(){{}}
int Inp_StartHHMM=0;
double gTickSize=1,gBreakoutMargin=0;
ulong pipeline_local=1;
ulong GetTickCount64(){{return pipeline_local;}}
int PeriodSeconds(int timeframe){{return timeframe*60;}}
long MQLInfoInteger(int){{return 1;}}
template<class T>void ArrayFree(std::vector<T>& x){{x.clear();}}
int CopyTicks(string,std::vector<MqlTick>& ticks,int,ulong,uint){{ticks.clear();return 0;}}
#include "{ROOT}/Include/BookDecisionRuntime.mqh"
MqlTick bd_tick(long msc,double price=100,ulong volume=10,int direction=1){{
 MqlTick t{{}};t.time=msc/1000;t.time_msc=msc;t.bid=price;t.ask=price+gTickSize;t.last=price;
 t.volume=volume;t.volume_real=(double)volume;t.flags=TICK_FLAG_LAST|TICK_FLAG_VOLUME;
 if(direction==1||direction==2)t.flags|=TICK_FLAG_BUY;
 if(direction==-1||direction==2)t.flags|=TICK_FLAG_SELL;
 return t;
}}
void bd_now(long msc){{fixture_time=msc/1000;}}
void bd_init(double tick_size,string symbol){{
 fixture_reset(1,false,false,tick_size);gBookGateSymbol=symbol;gTickSize=tick_size;
 Inp_DecisionMode=DECISION_APLICAR;Inp_DecisionAggressorSource=DECISION_FLAGS_PROVIDER_ASSERTED;
 fixture_time=1000;assert(BookDecisionInit());
}}
void bd_feed(long from,long to,const std::vector<MqlTick>& ticks){{
 bd_now(to);BookDecisionIngestBatch((ulong)from,(ulong)to,ticks.data(),(int)ticks.size());
}}
'''
    extra += function(CASES, 'bind_stream') + '\n' + function(CASES, 'stream_setup')
    source = (ROOT / 'scalpertalvez.mq5').read_text()
    code = execution_fixture(source, extra, main, full_guards=True, operational=True)
    code = code.replace('struct MqlTick { long long time_msc=', 'struct MqlTick { long long time=0,time_msc=')
    code = code.replace('datetime iTime(string,int,int){return 960;}',
                        'datetime iTime(string,int tf,int shift){return (fixture_time/(tf*60))*(tf*60)-shift*tf*60;}')
    code = code.replace('vwap=10000;', 'vwap=fixture_quotes.back().last;')
    code = code.replace('d.signalClock=960;d.contextClock=960;',
                        'd.signalClock=iTime(Symbol(),Inp_SignalTF,0);d.contextClock=iTime(Symbol(),Inp_ContextTF,0);')
    rounding = ('extern double gTickSize,gBreakoutMargin;\n'
                'double MathRound(double x){return std::round(x);}\n'
                'double MathCeil(double x){return std::ceil(x);}\n'
                'double MathFloor(double x){return std::floor(x);}\n'
                'double NormPriceDigits(double x){return x;}\n'
                + function(source, 'RoundUpTick') + '\n' + function(source, 'RoundDownTick') + '\n')
    code = code.replace(function(code, 'ComputeTrigger'), rounding + function(source, 'ComputeTrigger'))
    code = code.replace('0.5,0,2,10000);', '0.5,0,2,ComputeTrigger(armed.dir,armed.regionHigh,armed.regionLow));')
    code = code.replace(function(code, 'ResetArmedSignal'), 'void ResetArmedSignal();')
    code = code.replace('int main(){', function(source, 'ResetArmedSignal') + '\nint main(){')
    return code


class DecisionCompletePipelineTests(unittest.TestCase):
    def test_actual_collector_history_evidence_and_sendorder_abs_cont(self):
        main = r'''
int main(){int valid=0,blocked=0;
 for(bool dollar:{false,true})for(int d:{-1,1})for(bool cont:{false,true})for(bool book:{false,true})
 for(bool reject:{false,true}){
  double unit=dollar?.5:5;stream_setup(d,cont,unit,dollar);
  Inp_DOM_TradeGateEnable=book;Inp_ResponseMode=RESPONSE_ORIGINAL;Inp_EnableArmedDiagnostics=false;
  long from=gBookDecisionWindow.flow.from_msc;
  auto tail=gBookDecisionTail[gBookDecisionTailCount-1];
  if(!cont || reject){
   double level=cont?tail.last:gBookDecisionFrozenTest.flow.level;
   std::vector<MqlTick> ticks{tail};
   for(int j=0;j<4;j++)ticks.push_back(bd_tick(from+j*300,level+(reject?-d:d)*(2+(cont?4.5:2)*j)*unit,20,-d));
   bd_feed(tail.time_msc,from+999,ticks);
  }
  auto last=gBookDecisionTail[gBookDecisionTailCount-1];
  armed.regionHigh=d==1?last.last-unit:last.last+10*unit;
  armed.regionLow=d==1?last.last-10*unit:last.last+unit;
  armed.activeSL_Pts=10*unit;armed.activeTP_Pts=20*unit;
  BookDecisionBind();
  fixture_quotes={last,last,last,last};fixture_quote_index=0;
  auto result=fixture_send();
  BookDecisionWindow observed=gBookDecisionWindow;
  observed.flow.to_msc=gBookDecisionCoveredMSC;observed.complete=true;
  BookMicroMetrics opposed;BookDecisionWindowQuality(gBookDecisionConfig,observed,opposed,-d);
  if(reject){assert(trade.calls==0&&fixture_prepare_calls==0);blocked++;}
  else{assert(result==SEND_ACCEPTED&&trade.calls==1);valid++;}
  std::cout<<"FULL_PIPELINE route="<<(cont?"CONT":"ABS")<<" symbol="<<Symbol()<<" d="<<d
   <<" book="<<book<<" refs="<<gBookDecisionVerdict.conditional_count
   <<" result="<<gBookDecisionVerdict.result<<" reason="<<gBookDecisionVerdict.reason
   <<" net_ticks="<<gBookDecisionVerdict.net_progress<<" resistance="<<gBookDecisionVerdict.resistance
   <<" volume_acceptance="<<gBookDecisionVerdict.volume_acceptance
   <<" time_acceptance="<<gBookDecisionVerdict.time_acceptance
   <<" opposite_volume_acceptance="<<opposed.acceptance_volume_ratio
   <<" opposite_time_acceptance="<<opposed.acceptance_time_ratio<<" API="<<trade.calls<<"\n";
 }
 assert(valid==16&&blocked==16);
 std::cout<<"ACTUAL_COLLECTOR_TO_PositionOpen valid=16 blocked=16 observer=off csv=off logs=off\n";
}
'''
        result = compile_run(pipeline_fixture(main))
        self.assertIn('ACTUAL_COLLECTOR_TO_PositionOpen valid=16 blocked=16', result)
        print(result.strip())


if __name__ == '__main__':
    unittest.main(verbosity=2)
