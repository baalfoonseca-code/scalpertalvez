"""Actual Stage 1/Stage 2/entry cancellation and route-accounting fixtures."""
from pathlib import Path
import unittest
from test_compatibility import function, declaration
from test_decision_integration import execution_fixture, decision_adapter_policy, compile_run

ROOT = Path(__file__).resolve().parents[1]


class DecisionLifecycleTests(unittest.TestCase):
    def test_route_counts_original_cancellations_and_live_wait(self):
        main = r'''
int main(){
 for(bool cont:{false,true}){
  int identified=0,approved=0,waiting=0,vetoed=0,timeouts=0,overshoots=0,preserved=0;
  for(int d:{-1,1})for(bool book:{false,true})for(int scenario=0;scenario<5;scenario++){
   fixture_reset(d,cont,book,1);decision_reset(d,cont,scenario==1?2:(scenario==2?1:0),1);
   if(scenario==3)fixture_time=1090;
   if(scenario==4)for(auto &q:fixture_quotes){q.last=10000+d*100;q.bid=q.ask=q.last;}
   identified++;auto outcome=ResponseBaseProcessArmedSignal();
   if(scenario==0){assert(trade.calls==1&&outcome==APS_TRADE_OR_POSITION);approved++;preserved++;}
   if(scenario==1){assert(trade.calls==0&&armed.active&&outcome==APS_STILL_ARMED);waiting++;}
   if(scenario==2){assert(trade.calls==0&&!armed.active);vetoed++;}
   if(scenario==3){assert(trade.calls==0&&!armed.active&&outcome==APS_ENDED_REEVAL_ALLOWED);timeouts++;}
   if(scenario==4){assert(trade.calls==0&&!armed.active&&outcome==APS_ENDED_FAIL_CLOSED);overshoots++;}
  }
  std::cout<<"REGRESSION_ROUTE="<<(cont?"CONT":"ABS")<<" identified="<<identified<<" approved="<<approved
   <<" waiting="<<waiting<<" vetoed="<<vetoed<<" timeout="<<timeouts<<" overshoot="<<overshoots
   <<" valid_entries_preserved="<<preserved<<" (deterministic fixtures, not market statistics)\n";
 }
}
'''
        source = (ROOT / 'scalpertalvez.mq5').read_text()
        out = compile_run(execution_fixture(source, decision_adapter_policy(), main,
                                           full_guards=True, operational=True, wrapper=True))
        self.assertIn('REGRESSION_ROUTE=ABS identified=20 approved=4 waiting=4 vetoed=4 timeout=4 overshoot=4', out)
        self.assertIn('REGRESSION_ROUTE=CONT identified=20 approved=4 waiting=4 vetoed=4 timeout=4 overshoot=4', out)
        print(out.strip())

    def test_original_terminal_terms_and_post_journal_precedence(self):
        main = r'''
int main(){int terminal=0,uncertain=0;
 for(bool cont:{false,true})for(int d:{-1,1})for(bool book:{false,true}){
  // A veto must not turn an original terminal no-margin rejection into WAIT.
  fixture_reset(d,cont,book,1);decision_reset(d,cont,2,1);fixture_margin=false;
  auto result=ResponseBaseProcessArmedSignal();assert(!armed.active&&trade.calls==0&&fixture_decision_calls==0);terminal++;
  // Original glass, before the new decision, remains terminal for both routes.
  fixture_reset(d,cont,book,1);decision_reset(d,cont,0,1);SigmaD1=1;
  for(auto &q:fixture_quotes){q.last=10000+d*10;q.bid=q.ask=q.last;}
  result=ResponseBaseProcessArmedSignal();assert(!armed.active&&trade.calls==0&&fixture_decision_calls==0);SigmaD1=1000;terminal++;
  for(int phase:{1,2})for(int action:{1,2,4,5,6,7}){
   fixture_reset(d,cont,book,1);decision_reset(d,cont,0,1);
   if(phase==1)fixture_after_prepare_action=action;else fixture_after_mark_action=action;
   if(action==6){fixture_change_stage=phase;fixture_policy_after=3;}
   auto outcome=fixture_send();assert(trade.calls==0);
   if(action>=4){assert(outcome==SEND_FINANCIAL_UNRESOLVED&&gPendingExec.active);uncertain++;}
   else{assert(!armed.active&&!gPendingExec.active);terminal++;}
  }
  fixture_reset(d,cont,book,1);decision_reset(d,cont,0,1);fixture_uncertain=true;
  auto sent=fixture_send();assert(sent==SEND_FINANCIAL_UNRESOLVED&&trade.calls==1&&gPendingExec.active);
  auto retried=fixture_send();assert(trade.calls==1&&gPendingExec.active);(void)retried;uncertain++;
 }
 std::cout<<"ORIGINAL_TERMINAL_PRECEDENCE cases="<<terminal<<" uncertain_intents_retained="<<uncertain<<" API=0\n";
}
'''
        source = (ROOT / 'scalpertalvez.mq5').read_text()
        out = compile_run(execution_fixture(source, decision_adapter_policy(), main,
                                           full_guards=True, operational=True, wrapper=True))
        self.assertIn('ORIGINAL_TERMINAL_PRECEDENCE cases=48 uncertain_intents_retained=72 API=0', out)
        print(out.strip())

    def test_original_matrix_conflict_glass_and_ineligible_cannot_be_recovered(self):
        source = (ROOT / 'scalpertalvez.mq5').read_text()
        extra = decision_adapter_policy()
        extra += '\n'.join(declaration(source, 'enum', name) for name in ['ENUM_MSS', 'ENUM_POC_STATE'])
        extra += declaration(source, 'struct', 'POCResult') + '\n' + declaration(source, 'struct', 'MatrixSnapshot')
        extra += r'''
struct MqlRates{double high=10010,low=9990;};
int candidate_calls=0,Inp_Region_Candles=2;bool Inp_EnableAbsorption=true;
double UpperBand1=0,LowerBand1=0,gSL_Pts=10,gTP_Pts=20,Inp_CONT_BreakoutEffort=1.5,Inp_ABS_BreakoutEffort=1.5;
datetime gCachedMicroBar=960;struct FixtureMacro{int macroAbsDir=1,macroContDir=1;double posRel=.5;}gMacro;
MatrixSnapshot selected;
ENUM_MSS SnapshotForSignal(MatrixSnapshot &s){s=selected;return s.status;}
int CopyRates(string,int,int,int count,std::vector<MqlRates> &out){out.assign(count,MqlRates{});return count;}
string PocStateStr(ENUM_POC_STATE){return "KNOWN";}
template<class... A>void WriteShadowRow(const A&...){}
template<class... A>void BookDiagSelected(const A&...){}
template<class... A>void ResponseSelected(const A&...){}
bool BookDecisionCandidate(const MatrixSnapshot&,int,bool,datetime){candidate_calls++;return false;}
void BookDecisionBind(){}
'''
        body = function(source, 'EvaluateMatrix').replace('MqlRates regionRates[];', 'std::vector<MqlRates> regionRates;')
        main = r'''
int main(){for(int kind=0;kind<4;kind++){
 fixture_reset(1,false,true,1);decision_reset(1,false,0,1);armed.active=false;selected=MatrixSnapshot{};
 selected.status=MSS_OK;selected.dir=1;selected.dirCont=-1;selected.absValid=true;
 if(kind==0)selected.contValid=true;
 if(kind==1)selected.status=MSS_STOP_KAMIKAZE_CONT_ONLY;
 if(kind==2)selected.absValid=false;
 candidate_calls=0;EvaluateMatrix();assert(!armed.active&&trade.calls==0);
 assert(candidate_calls==(kind==3?1:0));
}
std::cout<<"ACTUAL_EvaluateMatrix conflict/glass/ineligible never reach candidate; eligible veto cannot arm; API=0\n";
}
'''
        out = compile_run(execution_fixture(source, extra, body + main,
                                           full_guards=True, operational=True))
        self.assertIn('ACTUAL_EvaluateMatrix conflict/glass/ineligible', out)
        print(out.strip())


if __name__ == '__main__':
    unittest.main(verbosity=2)
