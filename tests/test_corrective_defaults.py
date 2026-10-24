"""Exact delivered defaults and irregular trade-stream entry integration.

The production collector, causal references, decision core, original readiness,
neutral journal cleanup and sole PositionOpen call are used by pipeline_fixture.
The only adapters are terminal/market/depth/file APIs. These deterministic paths
are not external feed certification, MetaEditor compilation or market replay.
"""
from pathlib import Path
import re
import unittest

from test_compatibility import function
from test_decision_integration import compile_run
from test_decision_pipeline import pipeline_fixture

ROOT = Path(__file__).resolve().parents[1]


DEFAULT_INITIALIZATION = r'''
void bd_init(double tick_size,string symbol){
 // No decision input is assigned here: these must be the declarations shipped
 // in BookDecisionInputs.mqh, including the operational source default.
 assert(Inp_DecisionMode==DECISION_APLICAR);
 assert(Inp_DecisionAggressorSource==DECISION_FLAGS_RUNTIME_QUALIFIED);
 assert(Inp_DecisionWindowSec==5 && Inp_DecisionMinReferences==16);
 assert(Inp_DecisionEffortQuantile==.80 && Inp_DecisionResultQuantile==.20);
 assert(Inp_DecisionMinCoverage==.80 && Inp_DecisionMinDirectionalShare==.20);
 assert(Inp_DecisionMinAcceptance==.60 && Inp_DecisionMinObservedCoverage==.50);
 assert(Inp_DecisionMinProgressTicks==1 && Inp_DecisionComparableEffortFactor==2);
 fixture_reset(1,false,false,tick_size);gBookGateSymbol=symbol;gTickSize=tick_size;
 gBreakoutMargin=tick_size;gSpreadMaxPts=tick_size;gMaxOvershoot=tick_size<1?1.0:25.0;
 fixture_time=34200;assert(BookDecisionInit());
 assert(gBookDecisionReady && gBookDecisionHistory.count==0);
 // Empty history is a successful collector initialization, not invalid setup.
 assert(!BookDecisionSourceFresh());
}
'''

IRREGULAR_STREAM = r'''
void stream_setup(int d,bool cont,double tick_size,bool dollar){
 bd_init(tick_size,dollar?"WDO_IRREGULAR":"WIN_IRREGULAR");
 Inp_EnableArmedDiagnostics=false;Inp_ResponseMode=RESPONSE_ORIGINAL;
 long s=gBookDecisionStartMSC;double anchor=dollar?5500:135000;
 const long offsets[10]={0,137,137,802,1451,2103,3011,3927,4600,4999};
 const ulong volumes[10]={18,21,21,17,10,25,16,23,19,20};
 std::vector<MqlTick> tape;int pressure=cont?d:-d;
 for(int w=0;w<16;w++){
  for(int j=0;j<10;j++){
   if(j==2){tape.push_back(tape.back());continue;} // Distinct identical trade.
   int flags=(j==4||j==7)?0:pressure; // Approximately17%unknown volume.
   double price=anchor+pressure*(2+j/3)*tick_size;
   ulong amount=(ulong)((long)volumes[j]+w%3-1);
   tape.push_back(bd_tick(s+w*5000+offsets[j],price,amount,flags));
  }
  anchor=tape.back().last;
 }
 for(int j=0;j<10;j++){
  if(j==2){tape.push_back(tape.back());continue;}
  double price=cont?anchor+d*(2+j)*tick_size:anchor;
  ulong amount=cont?volumes[j]:volumes[j]*3/2;
  tape.push_back(bd_tick(s+16*5000+offsets[j],price,amount,(j==4||j==7)?0:pressure));
 }
 bd_feed(s,s+17*5000,tape);
 assert(!gBookDecisionFault && gBookDecisionHistory.count>=34);
 assert(gBookDecisionLastTradeMSC==s+17*5000-1);
 bind_stream(d,cont);
}
void irregular_follow(int d,bool cont,bool reject,int quality=0){
 long from=gBookDecisionWindow.flow.from_msc;
 auto tail=gBookDecisionTail[gBookDecisionTailCount-1];
 double level=cont?tail.last:gBookDecisionFrozenTest.flow.level;
 const long at[5]={0,137,137,593,999};
 const int step[5]={0,1,1,2,3};
 const ulong volume[5]={18,21,21,17,10};
 std::vector<MqlTick> ticks{tail};
 for(int j=0;j<5;j++){
  if(j==2){ticks.push_back(ticks.back());continue;}
  int aggressor=j==4?0:-d;
  if(quality==1)aggressor=2; // BUY+SELL ambiguous: never classify as known.
  if(quality==2)aggressor=0;
  double price=level+(reject?-d:d)*(2+(cont?4:2)*step[j])*gTickSize;
  ticks.push_back(bd_tick(from+at[j],price,volume[j],aggressor));
 }
 bd_feed(tail.time_msc,from+999,ticks);
}
void align_entry(int d,double unit){
 auto last=gBookDecisionTail[gBookDecisionTailCount-1];
 armed.regionHigh=d==1?last.last-2*unit:last.last+10*unit;
 armed.regionLow=d==1?last.last-10*unit:last.last+2*unit;
 // Preserve the shipped historical entry defaults rather than a convenient
 // test stop/target: WIN150/300points and WDO5/12.5points.
 armed.activeSL_Pts=unit<1?5.0:150.0;armed.activeTP_Pts=unit<1?12.5:300.0;
 BookDecisionBind();fixture_quotes={last,last,last,last};fixture_quote_index=0;
}
void roll_with_benign_partial(int d,bool cont){
 if(!cont){
  long from=gBookDecisionWindow.flow.from_msc;
  auto tail=gBookDecisionTail[gBookDecisionTailCount-1];
  double level=gBookDecisionFrozenTest.flow.level;
  const long at[6]={1593,2257,2961,3705,4301,4999};
  std::vector<MqlTick> fill{tail};
  for(int j=0;j<6;j++)fill.push_back(bd_tick(from+at[j],level+d*(9+j)*gTickSize,18+j,-d));
  bd_feed(tail.time_msc,from+5000,fill);
 }
 auto tail=gBookDecisionTail[gBookDecisionTailCount-1];
 long from=gBookDecisionWindow.flow.from_msc;
 // This prefix has only50ms of observed time over151ms: it is deliberately
 // below0.50 temporalcoverage, while earlier complete evidence is still fresh.
 std::vector<MqlTick> partial{tail,bd_tick(from,tail.last+d*2*gTickSize,12,d),
   bd_tick(from+50,tail.last+d*3*gTickSize,11,d)};
 bd_feed(tail.time_msc,from+150,partial);
}
'''


def default_pipeline(main):
    code = pipeline_fixture(main)
    code = code.replace('int Inp_StartHHMM=0;', 'int Inp_StartHHMM=900;')
    code = code.replace(function(code, 'bd_init'), DEFAULT_INITIALIZATION)
    code = code.replace(function(code, 'stream_setup'), IRREGULAR_STREAM)
    return code


class CorrectiveDefaultTests(unittest.TestCase):
    def test_exact_defaults_irregular_ticks_can_approve_and_prevent_actual_entries(self):
        main = r'''
int main(){int approved=0,rejected=0;
 for(bool dollar:{false,true})for(int d:{-1,1})for(bool cont:{false,true})
 for(bool book:{false,true})for(bool reject:{false,true}){
  double unit=dollar?.5:5;stream_setup(d,cont,unit,dollar);
  Inp_DOM_TradeGateEnable=book;
  if(!cont || reject)irregular_follow(d,cont,reject);
  align_entry(d,unit);
  auto result=fixture_send();
  if(reject){assert(trade.calls==0 && fixture_prepare_calls==0);rejected++;}
  else{assert(result==SEND_ACCEPTED && trade.calls==1);approved++;}
  std::cout<<"DEFAULT_IRREGULAR route="<<(cont?"CONT":"ABS")<<" symbol="<<Symbol()
   <<" d="<<d<<" book="<<book<<" source="<<Inp_DecisionAggressorSource
   <<" result="<<gBookDecisionVerdict.result<<" reason="<<gBookDecisionVerdict.reason
   <<" coverage="<<gBookDecisionVerdict.coverage<<" refs="<<gBookDecisionVerdict.conditional_count
   <<" API="<<trade.calls<<"\n";
 }
 assert(approved==16&&rejected==16);
 std::cout<<"EXACT_DEFAULTS_TO_API valid=16 rejected=16 irregular_times unknown_rows identical_ms observer=off logs=off\n";
}
'''
        out = compile_run(default_pipeline(main))
        self.assertIn('EXACT_DEFAULTS_TO_API valid=16 rejected=16', out)
        print(out.strip())

    def test_runtime_qualified_contract_does_not_accept_ambiguous_or_unknown_pressure(self):
        main = r'''
int main(){int blocked=0;
 for(bool cont:{false,true})for(int quality:{1,2}){
  stream_setup(1,cont,1,false);
  irregular_follow(1,cont,false,quality);
  align_entry(1,1);auto result=fixture_send();
  assert(result!=SEND_ACCEPTED&&trade.calls==0);blocked++;
 }
 std::cout<<"DEFAULT_SOURCE_CONTRACT ambiguous_or_unknown blocked="<<blocked<<" API=0\n";
}
'''
        out = compile_run(default_pipeline(main))
        self.assertIn('ambiguous_or_unknown blocked=4 API=0', out)
        print(out.strip())

    def test_complete_evidence_survives_new_low_activity_partial_without_fixed_wait(self):
        main = r'''
int main(){int approved=0;
 for(bool cont:{false,true})for(int d:{-1,1})for(bool book:{false,true}){
  stream_setup(d,cont,1,false);Inp_DOM_TradeGateEnable=book;
  if(!cont)irregular_follow(d,false,false);
  assert(BookDecisionEvaluateArmed()==DECISION_VALIDAR);
  roll_with_benign_partial(d,cont);
  align_entry(d,1);
  auto result=fixture_send();
  if(result!=SEND_ACCEPTED)std::cerr<<"PARTIAL_EVIDENCE route="<<(cont?"CONT":"ABS")
   <<" d="<<d<<" book="<<book<<" result="<<result<<" verdict="<<gBookDecisionVerdict.result
   <<" reason="<<gBookDecisionVerdict.reason<<" known_through="<<gBookDecisionCoveredMSC<<"\n";
  assert(result==SEND_ACCEPTED&&trade.calls==1);approved++;
 }
 std::cout<<"COMPLETE_EVIDENCE_NEW_PARTIAL preserved="<<approved<<" API=1 each no_fixed_wait\n";
}
'''
        out = compile_run(default_pipeline(main))
        self.assertIn('COMPLETE_EVIDENCE_NEW_PARTIAL preserved=8 API=1 each no_fixed_wait', out)
        print(out.strip())

    def test_proven_reaction_quiet_tail_is_not_an_artificial_wait_or_stale_permission(self):
        main = r'''
int main(){int preserved=0,stale=0;
 for(int d:{-1,1})for(bool expired:{false,true}){
  stream_setup(d,false,5,false);irregular_follow(d,false,false);align_entry(d,5);
  assert(BookDecisionEvaluateArmed()==DECISION_VALIDAR);
  auto tail=gBookDecisionTail[gBookDecisionTailCount-1];
  long quiet_until=gBookDecisionCoveredMSC+(expired?4000:1250);
  bd_feed(tail.time_msc,quiet_until,{tail});
  auto result=fixture_send();
  if(expired){assert(result!=SEND_ACCEPTED&&trade.calls==0);stale++;}
  else{assert(result==SEND_ACCEPTED&&trade.calls==1);preserved++;}
 }
 std::cout<<"PROVEN_REACTION_QUIET_TAIL preserved="<<preserved<<" stale_blocked="<<stale<<" source_age_enforced\n";
}
'''
        out = compile_run(default_pipeline(main))
        self.assertIn('PROVEN_REACTION_QUIET_TAIL preserved=2 stale_blocked=2 source_age_enforced', out)
        print(out.strip())

    def test_expired_test_can_be_replaced_causally_without_restarting_armed(self):
        main = r'''
int main(){int preserved=0;
 for(int d:{-1,1}){
  stream_setup(d,false,5,false);
  double level=gBookDecisionFrozenTest.flow.level;
  // Original region/trigger are frozen before the following trades. They are
  // intentionally above/below the flat test, not reconstructed from future R.
  armed.regionHigh=level+(d==1?6:20)*gTickSize;
  armed.regionLow=level-(d==-1?6:20)*gTickSize;
  armed.activeSL_Pts=150;armed.activeTP_Pts=300;
  BookDecisionBind();
  long old_test=gBookDecisionFrozenTest.flow.to_msc;
  datetime armed_at=armed.armedAt;
  long from=gBookDecisionWindow.flow.from_msc;
  auto tail=gBookDecisionTail[gBookDecisionTailCount-1];
  std::vector<MqlTick> flat{tail};
  const long at[6]={0,713,1591,2501,3407,4999};
  for(int w=0;w<2;w++)for(int j=0;j<6;j++)
   flat.push_back(bd_tick(from+w*5000+at[j],level,40,-d));
  bd_feed(tail.time_msc,from+10000,flat);
  auto waiting=BookDecisionEvaluateArmed();
  assert(waiting!=DECISION_INVALIDAR_ARMED && armed.active);
  assert(gBookDecisionFrozenTest.flow.to_msc>old_test);
  assert(armed.armedAt==armed_at);
  irregular_follow(d,false,false);
  auto last=gBookDecisionTail[gBookDecisionTailCount-1];
  fixture_quotes={last,last,last,last};fixture_quote_index=0;
  auto result=fixture_send();
  if(result!=SEND_ACCEPTED)std::cerr<<"REPLACED_T d="<<d<<" verdict="<<gBookDecisionVerdict.result
   <<" reason="<<gBookDecisionVerdict.reason<<" outcome="<<result<<"\n";
  assert(result==SEND_ACCEPTED&&trade.calls==1);preserved++;
 }
 std::cout<<"EXPIRED_T_CAUSAL_REPLACEMENT preserved="<<preserved<<" same_original_armedAt no_timeout_extension\n";
}
'''
        out = compile_run(default_pipeline(main))
        self.assertIn('EXPIRED_T_CAUSAL_REPLACEMENT preserved=2 same_original_armedAt no_timeout_extension', out)
        print(out.strip())

    def test_structural_setup_errors_fail_but_default_warmup_initializes(self):
        main = r'''
int main(){
 bd_init(5,"WIN_INITIALIZATION");assert(gBookDecisionReady);
 assert(gBookDecisionHistory.count==0 && !BookDecisionSourceFresh());
 Inp_DecisionWindowSec=0;assert(!BookDecisionInit()&&!gBookDecisionReady);Inp_DecisionWindowSec=5;
 Inp_DecisionMinReferences=385;assert(!BookDecisionInit()&&!gBookDecisionReady);Inp_DecisionMinReferences=16;
 Inp_DecisionAggressorSource=(ENUM_BOOK_DECISION_SOURCE)99;
 assert(!BookDecisionInit()&&!gBookDecisionReady);
 Inp_DecisionAggressorSource=DECISION_FLAGS_RUNTIME_QUALIFIED;
 assert(BookDecisionInit()&&gBookDecisionReady&&!BookDecisionSourceFresh());
 std::cout<<"DEFAULT_INITIALIZATION invalid_structure=failed normal_warmup=initialized\n";
}
'''
        out = compile_run(default_pipeline(main))
        self.assertIn('invalid_structure=failed normal_warmup=initialized', out)
        print(out.strip())
        source = (ROOT / 'scalpertalvez.mq5').read_text()
        init = function(source, 'OnInit')
        self.assertRegex(init, r'if\s*\(\s*!BookDecisionInit\(\)\s*\)')
        begin = re.search(r'if\s*\(\s*!BookDecisionInit\(\)\s*\)', init).end()
        self.assertIn('INIT_PARAMETERS_INCORRECT', init[begin:begin+350])


if __name__ == '__main__':
    unittest.main(verbosity=2)
