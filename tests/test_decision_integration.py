"""Actual entry-function host fixtures; not native MT5 or financial evidence."""
from pathlib import Path
import json
import subprocess
import tempfile
import unittest
from test_compatibility import function, declaration

ROOT=Path(__file__).resolve().parents[1]
CONTROL="815077efec40adf1897bcf64640756bb46c4c118"


def control_source():
    return subprocess.check_output(["git","show",CONTROL+":scalpertalvez.mq5"],cwd=ROOT,text=True)


def compile_run(text: str) -> str:
    with tempfile.TemporaryDirectory(prefix="decision-entry-") as td:
        cpp=Path(td)/"entry.cpp";exe=Path(td)/"entry"
        # Only the observer API boundary is adapted for the preexisting isolated
        # operational fixtures. Dedicated research integration opts into reality.
        if '#define BOOK_RESEARCH_INTEGRATION_HOST' not in text:
            text=f'#include "{ROOT}/tests/research_noop_hooks.hpp"\n'+text
        cpp.write_text(text)
        built=subprocess.run(["g++","-std=c++17","-O2","-Wall","-Wextra",str(cpp),"-o",str(exe)],capture_output=True,text=True)
        if built.returncode:
            raise AssertionError(built.stderr)
        run=subprocess.run([str(exe)],capture_output=True,text=True)
        if run.returncode:
            raise AssertionError(run.stdout+run.stderr)
        return run.stdout


def decision_adapter_original_only() -> str:
    """Adapters must not run in ORIGINAL; counters prove bypass, not a fake pass."""
    return f'''
#define input
#include "{ROOT}/Include/BookDecisionInputs.mqh"
#include "{ROOT}/Include/BookMicroMath.mqh"
#include "{ROOT}/Include/BookDecisionCore.mqh"
#undef input
ENUM_BOOK_DECISION_RESULT gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;
int fixture_decision_calls=0;
ENUM_BOOK_DECISION_RESULT BookDecisionEvaluateArmed(){{fixture_decision_calls++;return DECISION_DADOS_INSUFICIENTES;}}
bool BookDecisionDispatchValid(const ArmedSignal&){{fixture_decision_calls++;return false;}}
'''


def decision_adapter_policy() -> str:
    """Real core, constructed causal windows, controlled runtime acquisition.

    Runtime ingestion/identity/cursor is tested separately. This adapter runs
    actual BookDecisionAssess and exposes its result to the actual entry code.
    Explicit forced verdicts exist ONLY in this test fixture for the requested
    causality experiment; there is no production override input or branch.
    """
    return f'''
#define input
#include "{ROOT}/Include/BookDecisionInputs.mqh"
#include "{ROOT}/Include/BookMicroMath.mqh"
#include "{ROOT}/Include/BookDecisionCore.mqh"
#include "{ROOT}/tests/decision_policy_cases.hpp"
#undef input
BookDecisionVerdict fixture_verdict;
BookDecisionConfig fixture_config;
BookDecisionEvidence fixture_evidence;
ENUM_BOOK_DECISION_RESULT gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;
int fixture_decision_calls=0,fixture_policy=0,fixture_policy_after=0,fixture_change_stage=99;
int fixture_force_verdict=-1,fixture_stale_stage=99;
bool DOMGateIdentityCurrent(const ArmedSignal&);
void decision_reset(int direction,bool cont,int policy,double unit){{
 fixture_config=DecisionTestConfig(unit);fixture_policy=fixture_policy_after=policy;
 fixture_change_stage=fixture_stale_stage=99;fixture_force_verdict=-1;fixture_decision_calls=0;
 gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;fixture_verdict=BookDecisionVerdict{{}};
 Inp_DecisionMode=DECISION_APLICAR;Inp_ResponseMode=RESPONSE_ORIGINAL;
 fixture_evidence=cont?DecisionTestCONT(fixture_config,direction,false):DecisionTestABS(fixture_config,direction,true);
}}
ENUM_BOOK_DECISION_RESULT BookDecisionEvaluateArmed(){{
 fixture_decision_calls++;
 if(!armed.active){{gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;return gBookDecisionResult;}}
 bool cont=armed.route=="CONT";int kind=fixture_stage>=fixture_change_stage?fixture_policy_after:fixture_policy;
 fixture_evidence=cont?DecisionTestCONT(fixture_config,armed.dir,kind==1):DecisionTestABS(fixture_config,armed.dir,kind!=2);
 if(!cont && kind==1){{
  fixture_evidence.current=DecisionTestWindow(fixture_config,fixture_evidence.test.flow.to_msc+1,-armed.dir,-armed.dir,2);
  fixture_evidence.now_msc=fixture_evidence.current.flow.to_msc;
 }}
 if(cont && kind==2){{
  auto prior=fixture_evidence.forward;long from=prior.flow.to_msc+1;
  BookDecisionWindowReset(fixture_evidence.current,from,from+999,prior.flow.last,fixture_config.tick_size,
    from-1,prior.pv/(prior.vb+prior.vs),true,fixture_config.source,prior.bucket,prior.generation);
  for(int j=0;j<4;j++)BookDecisionWindowTick(fixture_evidence.current,prior.flow.last,20,from+j*300,j%2?1:-1);
  fixture_evidence.current.complete=true;fixture_evidence.now_msc=from+999;
  BookDecisionRanksReset(fixture_evidence.current_ranks);
 }}
 if(kind==3)fixture_evidence.current.invalid=1;
 BookDecisionAssess(fixture_config,fixture_evidence,armed.dir,cont,true,fixture_verdict);
 if(fixture_force_verdict>=0)fixture_verdict.result=(ENUM_BOOK_DECISION_RESULT)fixture_force_verdict;
 gBookDecisionResult=fixture_verdict.result;return gBookDecisionResult;
}}
bool BookDecisionDispatchValid(const ArmedSignal &original){{
 return DOMGateIdentityCurrent(original) && fixture_stage<fixture_stale_stage && gBookDecisionResult==DECISION_VALIDAR;
}}
'''


def execution_fixture(source: str, extra: str="", main: str="", full_guards: bool=False,
                      operational: bool=False, wrapper: bool=False) -> str:
    definitions="\n".join(declaration(source,"enum",name) for name in
        ("ENUM_APS","ENUM_SEND_OUTCOME","ENUM_REQUEST_DISPATCH_PHASE","ENUM_BOOK_CONFLUENCE"))
    definitions+="\n"+"\n".join(declaration(source,"struct",name) for name in ("ArmedSignal","PendingExecContext"))
    support=(ROOT/"tests/decision_execution_support.hpp").read_text()
    adapters=r'''
ArmedSignal armed{};PendingExecContext gPendingExec{};
struct DOMSnapshot {int ignored=0;};
struct BookGateDecision {DOMSnapshot snapshot;ENUM_BOOK_CONFLUENCE state=BOOK_UNAVAILABLE;double pctBid=60,pctAsk=40;ulong beginUS=0,apiUS=0,aggregationUS=0;datetime signalClock=0,contextClock=0;int apiError=0;string reason;};
bool HasExecutionInFlight(){return fixture_pending || gPendingExec.active;}
void DOMClearSnapshot(DOMSnapshot &s){s=DOMSnapshot{};}
bool DOMGateIdentityCurrent(const ArmedSignal &old){return armed.active && old.active && armed.dir==old.dir && armed.armedAt==old.armedAt && armed.regionEndTime==old.regionEndTime && armed.route==old.route;}
bool DOMGateDecisionCurrent(BookGateDecision &decision,const MqlTick&,const ArmedSignal &,bool,const PendingExecContext &,ENUM_APS &ready,double &effort,double &trigger,double &last,double,double,double,double){
 fixture_book_calls++;decision.beginUS=GetMicrosecondCount();ready=APS_ENTRY_READY;effort=2;trigger=10000;last=10001;return fixture_book;
}
ENUM_SEND_OUTCOME DOMGateDefer(const BookGateDecision&,string){return SEND_WAIT_ARMED;}
ENUM_SEND_OUTCOME DOMGateRejectPrepared(const BookGateDecision&,string,const ArmedSignal&,const PendingExecContext&,bool,const ENUM_APS){return SEND_FINANCIAL_UNRESOLVED;}
bool DOMGateLogAllowed(){return fixture_logs;}
bool PreparePendingExec(int dir,string route,string mode,double price,double lots,double sl,double tp){
 fixture_prepare_calls++;fixture_stage=1;
 if(!fixture_prepare)return false;
 gPendingExec.active=true;gPendingExec.dispatchPhase=REQUEST_PREPARED;gPendingExec.direction=dir;gPendingExec.route=route;gPendingExec.mode=mode;
 gPendingExec.requestPrice=price;gPendingExec.requestedLots=lots;gPendingExec.slPrice=sl;gPendingExec.tpPrice=tp;gPendingExec.sentAt=1000;
 fixture_phase_action(fixture_after_prepare_action);
 return true;
}
bool BookRiskPrepareEntry(){return fixture_risk_prepare;}
bool ReleasePreparedRequest(bool){fixture_release_calls++;if(!fixture_release)return false;gPendingExec=PendingExecContext{};return true;}
bool MarkRequestDispatchPossible(bool){fixture_mark_calls++;fixture_stage=2;if(fixture_mark)gPendingExec.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;fixture_phase_action(fixture_after_mark_action);return fixture_mark;}
void ResetPendingExec(bool=true){gPendingExec=PendingExecContext{};}
void CompletePendingExec(bool sent,uint,ulong,ulong,uint){gPendingExec.active=!sent;}
void ResetArmedSignal(){armed.active=false;}
double ComputeTrigger(int,double,double){return 10000;}
void ComputeLiveWaveO1(double &effort,double &volume,double &average,int &direction){effort=2;volume=100;average=50;direction=armed.dir;}
void fixture_phase_action(int action){
 if(action==1)fixture_time=1090;
 if(action==2){fixture_hour=15;fixture_minute=30;}
 if(action==3)fixture_resolve=false;
 if(action==4)gOrderObligationScanUnresolved=true;
 if(action==5)gEntryJournalInvalid=true;
 if(action==6)fixture_journal_error=999;
 if(action==7)gPendingExec.requestID=88;
}
void fixture_reset(int direction,bool cont,bool book,double unit){
 armed=ArmedSignal{};armed.active=true;armed.dir=direction;armed.route=cont?"CONT":"ABS";armed.mode=cont?"BASE_CONT":"BASE";armed.armedAt=1000;armed.regionEndTime=960;
 armed.activeSL_Pts=10*unit;armed.activeTP_Pts=20*unit;armed.regionHigh=10000;armed.regionLow=9990;
 gPendingExec=PendingExecContext{};trade.calls=0;fixture_dispatched=false;fixture_stage=0;fixture_quote_index=0;fixture_audits.clear();
 Inp_DOM_TradeGateEnable=book;fixture_prepare_calls=fixture_mark_calls=fixture_release_calls=fixture_book_calls=0;
 fixture_open=fixture_pending=dailyRiskBlocked=gAccountingUnresolved=gEntryJournalInvalid=gExitJournalInvalid=false;
 fixture_prepare=fixture_risk_prepare=fixture_mark=fixture_release=fixture_margin=fixture_book=true;
 fixture_uncertain=fixture_risk=false;fixture_risk_terms=true;fixture_logs=true;
 fixture_time=1000;fixture_hour=9;fixture_minute=30;fixture_resolve=true;fixture_journal_exists=false;fixture_journal_error=0;
 fixture_after_prepare_action=fixture_after_mark_action=0;
 gEntryJournalCleanupPending=gExitJournalCleanupPending=gRequestJournalUnresolved=gRequestJournalWritePending=gEntryJournalWritePending=gPendingOrderClassificationUnresolved=gOrderObligationScanUnresolved=false;
 gPendingExit.active=false;gUnresolvedOrders.clear();gTradeRecords.clear();gTradeRecordCount=0;
 gBookGateSymbol=unit<1?"WDO":"WIN";gMagicCore=unit<1?60002:60001;
 gSpreadMaxPts=5*unit;gMaxOvershoot=25*unit;gLastBreakoutPrice=10000+direction*unit;
 MqlTick tick{};tick.last=10000+direction*unit;tick.ask=direction>0?tick.last:tick.last+unit;tick.bid=tick.ask-unit;
 fixture_quotes={tick,tick,tick,tick};
}
ENUM_SEND_OUTCOME fixture_send(){return SendOrder(armed.dir,0,armed.mode,armed.activeSL_Pts,armed.activeTP_Pts,0.5,0,2,10000);}
'''
    # Forward declaration is needed only by the fixture convenience wrapper.
    prototype="ENUM_SEND_OUTCOME SendOrder(int,double,string,double,double,double,double,double,double);\n"
    guards=""
    if full_guards:
        # The authoritative readiness, quote, identity and DOM orchestration
        # bodies are extracted verbatim; only terminal/depth acquisition is a
        # controlled adapter. In particular, tests do not duplicate the gate.
        for name in ("DOMGateIdentityCurrent","DOMGateDecisionCurrent","DOMGateDefer","DOMGateRejectPrepared"):
            stub=function(adapters,name)
            adapters=adapters.replace(stub,"")
        guards="\n".join(function(source,name) for name in
            ("DOMFinite","CheckArmedMarketReady","CheckArmedEntryReady","DOMGateIdentityCurrent",
             "DOMGateIntentMatches","DOMGateOwnUndispatchedIntent","DOMGateFinalTickReady",
             "DOMGateOriginalOvershoot","DOMGateTermsCurrent","DOMGateDecisionCurrent",
             "DOMGateDefer","DOMGateRejectPrepared"))
        # These prototypes only resolve C++ ordering; MQL accepts forward uses.
        adapters+='''
bool DOMGateRead(int,BookGateDecision &d){fixture_book_calls++;d.beginUS=GetMicrosecondCount();d.signalClock=960;d.contextClock=960;return fixture_book;}
void DOMGateReport(const BookGateDecision&,bool){}
ENUM_APS CheckArmedMarketReady(double&,double&,double&,MqlTick&);
ENUM_APS CheckArmedEntryReady(double&,double&,double&,MqlTick&);
bool DOMGateIdentityCurrent(const ArmedSignal&);
'''
    helpers=""
    if operational:
        helpers="\n".join(function(source,name) for name in
            ("BookDecisionArmedGate","BookDecisionRejectUnprepared","BookDecisionRevalidateNoBook","BookDecisionRejectPrepared"))
    bodies=helpers+function(source,"SendOrder")
    if wrapper:
        bodies+="\n"+function(source,"ResponseBaseProcessArmedSignal")
    return support+definitions+prototype+adapters+extra+guards+bodies+main


class DecisionExecutionIntegration(unittest.TestCase):
    def test_control_actual_sendorder_baseline_fixture(self):
        main=r'''
int main(){int valid=0,blocked=0;
 for(int direction:{-1,1})for(bool cont:{false,true})for(bool book:{false,true})for(double unit:{0.5,5.0}){
  fixture_reset(direction,cont,book,unit);auto outcome=fixture_send();assert(outcome==SEND_ACCEPTED);assert(trade.calls==1);valid++;
  fixture_reset(direction,cont,book,unit);fixture_margin=false;outcome=fixture_send();assert(outcome==SEND_FINAL_FAILURE);assert(trade.calls==0);blocked++;
 }
 std::cout<<"actual_control_SendOrder valid="<<valid<<" no_margin="<<blocked<<"\n";
}
'''
        out=compile_run(execution_fixture(control_source(),main=main,full_guards=True))
        self.assertIn("valid=16 no_margin=16",out)

    def test_original_mode_exact_actual_entry_control(self):
        main=r'''
int main(){Inp_DecisionMode=DECISION_ORIGINAL;int cases=0;
 for(int direction:{-1,1})for(bool cont:{false,true})for(bool book:{false,true})for(double unit:{0.5,5.0})for(int scenario=0;scenario<12;scenario++){
  fixture_reset(direction,cont,book,unit);
  switch(scenario){
   case 1:fixture_margin=false;break;
   case 2:fixture_open=true;break;
   case 3:fixture_pending=true;break;
   case 4:fixture_book=false;break;
   case 5:fixture_uncertain=true;break;
   case 6:fixture_prepare=false;break;
   case 7:fixture_risk_prepare=false;break;
   case 8:fixture_risk_prepare=false;fixture_release=false;break;
   case 9:fixture_mark=false;break;
   case 10:fixture_quotes[0].ask=fixture_quotes[0].bid=10000-direction*unit;break;
   case 11:fixture_quotes[1].ask=fixture_quotes[1].bid=10000-direction*unit;break;
  }
  auto outcome=fixture_send();
  std::cout<<direction<<cont<<book<<unit<<":"<<scenario<<":"<<outcome<<","<<trade.calls<<","<<fixture_prepare_calls<<","<<fixture_mark_calls<<","<<fixture_release_calls<<","<<fixture_book_calls<<","<<gPendingExec.active<<","<<armed.active<<"\n";
  cases++;
 }
 assert(fixture_decision_calls==0);
 std::cout<<"ORIGINAL_actual_SendOrder_cases="<<cases<<" new_decision_calls="<<fixture_decision_calls<<"\n";
}
'''
        extra=decision_adapter_original_only()
        expected=compile_run(execution_fixture(control_source(),extra,main,full_guards=True))
        actual=compile_run(execution_fixture((ROOT/"scalpertalvez.mq5").read_text(),extra,main,
                                            full_guards=True,operational=True))
        self.assertEqual(actual,expected)
        self.assertIn("ORIGINAL_actual_SendOrder_cases=192 new_decision_calls=0",actual)
        print("DECISION ORIGINAL: 192 actual SendOrder scenarios exactly equal control; new decision calls=0")

    def test_actual_policy_controls_the_only_entry_api_for_abs_and_cont(self):
        main=r'''
int main(){int valid=0,blocked=0;Inp_ResponseMode=RESPONSE_ORIGINAL;
 for(int direction:{-1,1})for(bool cont:{false,true})for(bool book:{false,true})for(double unit:{0.5,5.0}){
  fixture_reset(direction,cont,book,unit);decision_reset(direction,cont,0,unit);
  auto outcome=fixture_send();assert(outcome==SEND_ACCEPTED);assert(trade.calls==1);assert(fixture_decision_calls>0);valid++;
  std::cout<<"POLICY_VALID route="<<(cont?"CONT":"ABS")<<" dir="<<direction<<" tick="<<unit<<" book="<<book<<" result="<<fixture_verdict.result<<" reason="<<fixture_verdict.reason<<" net_ticks="<<fixture_verdict.net_progress<<" max_ticks="<<fixture_verdict.max_progress<<" resistance="<<fixture_verdict.resistance<<" vol_accept="<<fixture_verdict.volume_acceptance<<" time_accept="<<fixture_verdict.time_acceptance<<" API="<<trade.calls<<"\n";
  fixture_reset(direction,cont,book,unit);decision_reset(direction,cont,1,unit);
  outcome=fixture_send();assert(outcome!=SEND_ACCEPTED);assert(trade.calls==0);assert(fixture_prepare_calls==0);blocked++;
  assert(fixture_verdict.result==DECISION_INVALIDAR_ARMED);
  std::cout<<"POLICY_BLOCK route="<<(cont?"CONT":"ABS")<<" dir="<<direction<<" tick="<<unit<<" book="<<book<<" result="<<fixture_verdict.result<<" reason="<<fixture_verdict.reason<<" net_ticks="<<fixture_verdict.net_progress<<" pressure_share="<<fixture_verdict.pressure_share<<" coverage="<<fixture_verdict.coverage<<" vol_accept="<<fixture_verdict.volume_acceptance<<" time_accept="<<fixture_verdict.time_acceptance<<" API="<<trade.calls<<"\n";
 }
 std::cout<<"actual_policy_to_PositionOpen valid="<<valid<<" blocked="<<blocked<<" observer=OFF\n";
}
'''
        out=compile_run(execution_fixture((ROOT/"scalpertalvez.mq5").read_text(),decision_adapter_policy(),main,
                                         full_guards=True,operational=True))
        self.assertIn("actual_policy_to_PositionOpen valid=16 blocked=16 observer=OFF",out)
        self.assertIn("ABS_ACCEPTED_OPPOSITE_CONTINUATION",out)
        self.assertIn("CONT_ACCEPTED_OPPOSITE_REJECTION",out)
        print(out.strip())

    def test_actual_entry_verdict_injection_changes_api_logs_do_not(self):
        main=r'''
int main(){int pairs=0;
 for(int direction:{-1,1})for(bool cont:{false,true})for(bool book:{false,true})for(bool logs:{false,true}){
  fixture_reset(direction,cont,book,1);decision_reset(direction,cont,0,1);fixture_logs=logs;
  fixture_force_verdict=DECISION_VALIDAR;auto result=fixture_send();assert(result==SEND_ACCEPTED && trade.calls==1);
  fixture_reset(direction,cont,book,1);decision_reset(direction,cont,0,1);fixture_logs=logs;
  fixture_force_verdict=DECISION_VETAR_CANDIDATO;result=fixture_send();assert(result==SEND_WAIT_ARMED && trade.calls==0 && armed.active);pairs++;
 }
 std::cout<<"fixture_only_verdict_injection pairs="<<pairs<<" VALIDAR_API=1 VETAR_API=0 logs_have_no_effect\n";
}
'''
        out=compile_run(execution_fixture((ROOT/"scalpertalvez.mq5").read_text(),decision_adapter_policy(),main,
                                         full_guards=True,operational=True))
        self.assertIn("pairs=16 VALIDAR_API=1 VETAR_API=0 logs_have_no_effect",out)
        print(out.strip())

    def test_post_prepare_and_dispatch_journal_rejection_cleanup_and_uncertainty(self):
        main=r'''
int main(){int clean=0,uncertain=0;
 for(int direction:{-1,1})for(bool cont:{false,true})for(bool book:{false,true})for(int phase:{1,2}){
  fixture_reset(direction,cont,book,1);decision_reset(direction,cont,0,1);
  fixture_change_stage=phase;fixture_policy_after=3;
  auto outcome=fixture_send();assert(outcome==SEND_WAIT_ARMED && trade.calls==0 && armed.active && !gPendingExec.active);
  assert(fixture_prepare_calls==1);assert(fixture_mark_calls==(phase==2?1:0));clean++;
  fixture_reset(direction,cont,book,1);decision_reset(direction,cont,0,1);
  fixture_change_stage=phase;fixture_policy_after=3;
  if(phase==1)fixture_after_prepare_action=3;else fixture_after_mark_action=3;
  outcome=fixture_send();assert(outcome==SEND_FINANCIAL_UNRESOLVED && trade.calls==0 && gPendingExec.active);
  auto retained_phase=gPendingExec.dispatchPhase;
  assert(retained_phase==(phase==1?REQUEST_PREPARED:REQUEST_MAY_HAVE_DISPATCHED));
  auto again=fixture_send();assert(trade.calls==0 && gPendingExec.active && gPendingExec.dispatchPhase==retained_phase);(void)again;uncertain++;
 }
 std::cout<<"post_journal actual_entry clean_wait="<<clean<<" unresolved_retained="<<uncertain<<" no_dispatch_or_resend\n";
}
'''
        out=compile_run(execution_fixture((ROOT/"scalpertalvez.mq5").read_text(),decision_adapter_policy(),main,
                                         full_guards=True,operational=True))
        self.assertIn("clean_wait=16 unresolved_retained=16 no_dispatch_or_resend",out)
        print(out.strip())


if __name__=="__main__":
    unittest.main(verbosity=2)
