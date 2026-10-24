"""Integrated source-body/observational-core fixtures, not native MT5 tests.

The tests execute the delivered original readiness/dispatch functions and the
same pure research core embedded in the EA. Terminal quote/depth/journal APIs
are deterministic adapters; no result is evidence of a broker fill or profit.
"""
from pathlib import Path
import subprocess
import unittest

from test_compatibility import function
from test_decision_integration import (
    compile_run, execution_fixture, decision_adapter_original_only,
)

ROOT = Path(__file__).resolve().parents[1]
BASELINE = "94fddd73f0455c63a6cd238d6cb9f8924e9a497a"


def baseline_source():
    return subprocess.check_output(
        ["git", "show", BASELINE + ":scalpertalvez.mq5"], cwd=ROOT, text=True
    )


CORE = f'\n#define BOOK_RISK_HOST\n#include "{ROOT}/Include/BookResearchCore.mqh"\n'


def research_pipeline(main):
    """Actual matrix/decision/dispatch + isolated research; terminal snapshots adapted."""
    from test_compatibility import declaration
    from test_decision_pipeline import pipeline_fixture
    source=(ROOT/'scalpertalvez.mq5').read_text()
    code=pipeline_fixture(main)
    start=code.index('struct MatrixSnapshot { int status=1;')
    end=code.index('};',start)+2
    complete='\n'.join(declaration(source,'enum',name) for name in ['ENUM_MACRO_STATUS','ENUM_MSS','ENUM_POC_STATE'])
    complete+='\n'+declaration(source,'struct','POCResult')+'\n'+declaration(source,'struct','MatrixSnapshot')
    code=code[:start]+complete+code[end:]
    code=code.replace('constexpr int MSS_OK=1,COPY_TICKS_TRADE=1,MQL_MEMORY_USED=1;',
                      'constexpr int COPY_TICKS_TRADE=1,COPY_TICKS_ALL=3,MQL_MEMORY_USED=1;')
    before=f'#include "{ROOT}/Include/BookDecisionRuntime.mqh"'
    declarations=f'''#include "{ROOT}/Include/BookDecisionCore.mqh"
bool Inp_ResearchEnable=false;
void BookResearchOperationalEvidence(const BookDecisionEvidence&,const BookDecisionVerdict&,int,bool,bool);
void BookResearchOperationalUnavailable(const BookDecisionVerdict&,int,bool,bool);
'''
    code=code.replace(before,declarations+before)
    research=f'''
#include "{ROOT}/Include/BookResearchRuntime.mqh"
string research_id="matrix-selected";
void BookResearchOperationalEvidence(const BookDecisionEvidence &e,const BookDecisionVerdict &v,int d,bool cont,bool bound){{
 BookResearchRuntimeEvidence(research_id,e,v,d,cont,bound,true,"ACTUAL_OPERATIONAL_APPLY");
}}
void BookResearchOperationalUnavailable(const BookDecisionVerdict &v,int d,bool cont,bool bound){{
 BookDecisionEvidence e{{}};e.now_msc=fixture_time*1000;
 BookResearchRuntimeEvidence(research_id,e,v,d,cont,bound,false,"ACTUAL_OPERATIONAL_APPLY");
}}
struct MqlRates{{double high=9999,low=9990;}};
int Inp_Region_Candles=2;bool Inp_EnableAbsorption=true;
double UpperBand1=0,LowerBand1=0,gSL_Pts=10,gTP_Pts=20,Inp_CONT_BreakoutEffort=1.5,Inp_ABS_BreakoutEffort=1.5;
datetime gCachedMicroBar=960;
MatrixSnapshot selected;
ENUM_MSS SnapshotForSignal(MatrixSnapshot &s);
int CopyRates(string,int,int,int count,std::vector<MqlRates> &out){{out.assign(count,MqlRates{{}});return count;}}
string PocStateStr(ENUM_POC_STATE){{return "KNOWN";}}
template<class... A>void WriteShadowRow(const A&...){{}}
template<class... A>void BookDiagSelected(const A&...){{}}
template<class... A>void ResponseSelected(const A&...){{}}
void BookResearchCaptureCandidate(const MatrixSnapshot &snapshot,int d,bool cont,string mode,double high,double low){{
 BookResearchCandidate c{{}};c.id=research_id;c.direction=d;c.route=cont?"CONT":"ABS";c.mode=mode;c.symbol=Symbol();
 c.created_msc=fixture_time*1000;c.armed_at_sec=fixture_time;c.signal_bar=gCachedMicroBar;
 c.timeout_sec=Inp_ArmedTimeoutSec;c.stop_entry_hhmm=Inp_StopEntryHHMM;c.trigger=ComputeTrigger(d,high,low);c.region_high=high;c.region_low=low;
 c.sl_distance=gSL_Pts;c.tp_distance=gTP_Pts;c.tick_size=gTickSize;c.max_spread=gSpreadMaxPts;c.max_overshoot=gMaxOvershoot;
 c.effort_min=cont?Inp_CONT_BreakoutEffort:Inp_ABS_BreakoutEffort;c.inner_pct=Inp_VWAP_Inner_Pct;c.outer_pct=Inp_VWAP_Outer_Pct;c.original_eligible=true;
 BookResearchRuntimeCandidate(c,cont?"CONT":(snapshot.absDivergence?"DIVERGENCE":(snapshot.absFollowingReaction?"FOLLOWING_REACTION":"STALL_STRICT")),"ORIGINAL_ELIGIBLE","SELECTED_BEFORE_APPLY","{{}}",true);
}}
'''
    # Native M3 context, C1--C5 matrix and live-wave arithmetic. Only terminal
    # OHLC/volume and already-aggregated POC inputs are deterministic adapters.
    native=declaration(source,'struct','MacroContext')+r'''
MacroContext gMacro;
bool Inp_EnableMacroDirectionGate=true,Inp_EnableContinuation=true,VWAP_D1_Official=true,gVwapOk=true;
bool Inp_RejectPOCTies=false,Inp_Cont_RequireCandleDirection=true,wwUseReal=true;
double VWAP_D1=10040,H1=10200,L1=9900,gVwapValue=10050,gC2=20,gC3Min=10,gC3Max=60;
double gABS_MinDisplPts=1,gABS_MaxBodyPts=1,gCONT_MinDisplPts=1,Inp_Rule_40_60=.4;
double Inp_ABS_Effort=1.5,Inp_CONT_Effort=1.5,Inp_POC_FollowRatio=.5;
bool research_cont_matrix=false,research_live_rejected=false;
int Inp_POC_WindowSec=60,wwWaveDirClosed=-1,wwCurrentWaveBars=3,wwDirClosed=1;
double wwEffortClosed=2,wwAccumClosed=50,wwWaveStartPrice=9999,wwCloseRef=9999,wwAvgClosed=50,wwAvgIfFlip=50;
double iClose(string,int,int shift){return shift==0 && research_live_rejected?9998:10000;}
double iOpen(string,int,int){return 9999.5;}
long iRealVolume(string,int,int){return 50;}
long iVolume(string,int,int){return 50;}
void ResponseSnapshotBegin(){}
template<class... T>void ResponseLiveWave(const T&...){}
'''
    native+='\n'+function(source,'ResetPOCResult')
    native+=r'''
bool BookMeasuredPOC(ulong from,ulong,POCResult &p){ResetPOCResult(p);p.ok=true;p.poc=research_cont_matrix && from<900000?9998:10000;p.lastValidPrice=p.poc;p.totalVolume=100;p.tradeCount=10;return true;}
'''
    native+='\n'+'\n'.join(function(source,name) for name in ['ResetMatrixSnapshot','ResetMacroContext','ComputeMacroContext','ComputeMatrixSnapshot','ComputeLiveWaveO1'])
    native+=r'''
ENUM_MSS SnapshotForSignal(MatrixSnapshot &s){ComputeMacroContext();auto result=ComputeMatrixSnapshot(s);selected=s;return result;}
'''
    code=code.replace(function(code,'ComputeLiveWaveO1'),'void ComputeLiveWaveO1(double&,double&,double&,int&);')
    body=function(source,'EvaluateMatrix').replace('MqlRates regionRates[];','std::vector<MqlRates> regionRates;')
    code=code.replace('int main(){',research+'\n'+native+'\n'+body+'\n'+function(source,'ResponseBaseProcessArmedSignal')+'\nint main(){')
    return f'#include "{ROOT}/tests/research_noop_hooks.hpp"\n'+code


def research_acceptance_program(cont=False, ending="TP"):
    main=r'''
int main(){
 fixture_reset(1,false,false,1);gBreakoutMargin=1;gTickSize=1;assert(BookDecisionInit());
 armed.active=false;SigmaD1=100;
 research_cont_matrix=CONT_FIXTURE;
 if(research_cont_matrix){gVwapValue=9950;VWAP_D1=9960;H1=10100;L1=9800;wwWaveDirClosed=1;
  std::vector<MqlTick> feed;for(int j=0;j<10;j++)feed.push_back(bd_tick(1000000+j*500,10000+j*.1,10,1));
  bd_feed(1000000,1005000,feed);auto q=bd_tick(1005000,10001,10,1);fixture_quotes={q,q,q,q};fixture_quote_index=0;}
 long candidate_clock=fixture_time*1000;
 Inp_ResearchEnable=true;
 BookResearchRuntimeInit("acceptance","actual-loaded-fixture","fixture defaults; no market performance","123","60001","fixture-source",DECISION_APLICAR,gBookDecisionConfig);
 EvaluateMatrix();
 if(research_cont_matrix)assert(!selected.absValid && selected.contValid && selected.c1Cont && selected.c2Cont && selected.c4Cont && selected.c5ContOk);
 else assert(selected.absValid && !selected.contValid && selected.c1 && selected.c2 && selected.c4 && selected.c5AbsOk);
 assert(gMacro.status==MACRO_OK && armed.active && gBookResearchCandidateCount==1);
 auto original_identity=armed.armedAt;
 ACTUAL_PATH
 assert(trade.calls==0 && fixture_prepare_calls==0 && armed.active && armed.armedAt==original_identity);
 assert(result==SEND_WAIT_ARMED && gBookDecisionResult==DECISION_DADOS_INSUFICIENTES);
 if(research_cont_matrix)assert(gBookDecisionReason=="CONT_COMPARABLE_REFERENCES_INSUFFICIENT");
 assert(gBookResearchOpportunities[0].candidate.original_eligible);
 std::vector<MqlTick> quotes;
 for(int j=0;j<3;j++){
  long msc=candidate_clock+j;MqlTick q=bd_tick(msc,j<2?10001:ENDING_PRICE,10,1);quotes.push_back(q);
  BookResearchMarketSample x{};x.now_msc=msc;x.ordinal=j+1;x.server_sec=fixture_time;x.signal_bar=960;
  x.raw_identity_available=true;x.raw_time_sec=q.time;x.raw_volume=q.volume;x.raw_volume_real=q.volume_real;x.raw_flags=q.flags;
  x.bid=q.bid;x.ask=q.ask;x.last=q.last;x.quote_available=true;x.real_trade=true;x.path_complete=true;
  x.context_causal=true;x.weis_valid=true;x.live_wave_direction=HYPOTHETICAL_DIRECTION;x.live_effort=2;x.vwap_valid=true;x.live_vwap=10000;x.sigma=1000;x.band_multiplier=1;
  // Deterministic adapter: identical original market readiness/financial terms
  // are proven by the actual SendOrder above, before its new decision gate.
  x.financial_known=true;x.financial_possible=true;x.execution_terms_known=true;x.execution_terms_valid=true;
  BookResearchRuntimeSample(x);BookResearchQuoteBatch(candidate_clock,msc,quotes.data(),static_cast<int>(quotes.size()),true);
  assert(!gBookResearchQuoteFault);BookResearchProcessSamples();
 }
 quotes.push_back(bd_tick(candidate_clock+3,ENDING_PRICE,10,1));BookResearchQuoteBatch(candidate_clock,candidate_clock+3,quotes.data(),static_cast<int>(quotes.size()),true);BookResearchProcessSamples();
 auto t=gBookResearchOpportunities[0].track;
 FINAL_ASSERTIONS
 assert(trade.calls==0 && fixture_prepare_calls==0 && armed.armedAt==original_identity);
 for(int j=0;j<16;j++)BookResearchFlush();
 std::cout<<"ACCEPTANCE matrix=1 actual_APPLY_insufficient=1 API=0 original_stage2="<<t.stage2_demonstrated<<" first_reference_msc="<<t.entry_msc
  <<" reference="<<t.entry<<" SL="<<t.sl<<" TP="<<t.tp<<" outcome="<<t.barrier<<" real_PnL=UNAVAILABLE\n";
}
'''
    main=main.replace('CONT_FIXTURE',str(cont).lower()).replace('ENDING_PRICE','9989' if ending=='SL' else '10024')
    if ending=='NO_STAGE2':
        actual='research_live_rejected=true;auto readiness=ResponseBaseProcessArmedSignal();assert(readiness==APS_STILL_ARMED);auto result=SEND_WAIT_ARMED;'
        final='assert(!t.stage2_demonstrated && !t.entry_reference_available && t.barrier=="NOT_ENTERED");'
    else:
        actual='auto result=fixture_send();'
        barrier='TP_QUOTE_TOUCH_FIRST' if ending=='TP' else 'SL_QUOTE_TOUCH_FIRST'
        final='assert(t.stage2_demonstrated && t.entry_reference_available && t.entry_msc==candidate_clock+1);assert(t.dispatch_eligible_observed && t.barrier=="'+barrier+'");'
    main=main.replace('ACTUAL_PATH',actual).replace('HYPOTHETICAL_DIRECTION','-1' if ending=='NO_STAGE2' else '1').replace('FINAL_ASSERTIONS',final)
    return research_pipeline(main)


class ResearchIntegrationTests(unittest.TestCase):
    def test_actual_matrix_apply_wait_independent_original_stage2_to_tp(self):
        from test_research_runtime import run_program
        import csv
        result,files=run_program(research_acceptance_program())
        self.assertIn('ACCEPTANCE matrix=1 actual_APPLY_insufficient=1 API=0 original_stage2=1',result)
        for name,text in files.items():
            if name.endswith('.csv'):
                for row in csv.DictReader(text.splitlines()):
                    self.assertNotIn(None,row,name)
                    self.assertTrue(all(value is not None for value in row.values()),name)
        print(result.strip())

    def test_references_insufficient_cont_tp_sl_and_no_original_stage2(self):
        from test_research_runtime import run_program
        import csv
        for ending in ('TP','SL','NO_STAGE2'):
            result,files=run_program(research_acceptance_program(cont=True,ending=ending))
            self.assertIn('API=0',result)
            outcomes=[row for name,text in files.items() if name.endswith('Outcomes.csv') for row in csv.DictReader(text.splitlines())]
            decisions=[row for name,text in files.items() if name.endswith('Decisions.csv') for row in csv.DictReader(text.splitlines())]
            self.assertTrue(any(row['reason']=='CONT_COMPARABLE_REFERENCES_INSUFFICIENT' for row in decisions))
            if ending=='NO_STAGE2':
                self.assertFalse(any(row['status'] in {'TP_FIRST','SL_FIRST'} for row in outcomes))
                self.assertIn('original_stage2=0',result)
            else:self.assertTrue(any(row['status']==ending+'_FIRST' and row['pnl_confirmed']=='0' for row in outcomes))
            print(ending+' '+result.strip())

    def test_reference_vs_research_off_on_identical_actual_dispatch_financial_traces(self):
        from test_decision_integration import decision_adapter_policy
        from test_research_runtime import run_program
        main=r'''
int main(){int cases=0;
 for(int mode:{DECISION_ORIGINAL,DECISION_APLICAR})
 for(int d:{-1,1})for(bool cont:{false,true})for(bool book:{false,true})for(double unit:{.5,5.0})for(int scenario=0;scenario<12;scenario++){
  fixture_reset(d,cont,book,unit);decision_reset(d,cont,scenario%3,unit);Inp_DecisionMode=(ENUM_BOOK_DECISION_MODE)mode;
  switch(scenario){case 1:fixture_margin=false;break;case 2:fixture_open=true;break;case 3:fixture_pending=true;break;
   case 4:fixture_book=false;break;case 5:fixture_uncertain=true;break;case 6:fixture_prepare=false;break;
   case 7:fixture_risk_prepare=false;break;case 8:fixture_risk_prepare=false;fixture_release=false;break;
   case 9:fixture_mark=false;break;case 10:fixture_quotes[0].ask=fixture_quotes[0].bid=10000-d*unit;break;
   case 11:fixture_quotes[1].ask=fixture_quotes[1].bid=10000-d*unit;break;}
  RESEARCH_SETUP
  auto outcome=fixture_send();
  std::cout<<mode<<d<<cont<<book<<unit<<":"<<scenario<<":"<<outcome<<","<<trade.calls<<","<<fixture_prepare_calls
   <<","<<fixture_mark_calls<<","<<fixture_release_calls<<","<<fixture_book_calls<<","<<gPendingExec.active<<","<<armed.active
   <<","<<ordersEnteredToday<<","<<dailyRiskBlocked<<","<<gAccountingUnresolved<<"\n";
  RESEARCH_AFTER
  cases++;
 }assert(cases==384);
}
'''
        baseline=baseline_source();current=(ROOT/'scalpertalvez.mq5').read_text()
        expected=compile_run(execution_fixture(baseline,decision_adapter_policy(),main.replace('RESEARCH_SETUP','').replace('RESEARCH_AFTER',''),full_guards=True,operational=True))
        for enabled in (False,True):
            extra=decision_adapter_policy()+f'''
bool Inp_ResearchEnable={str(enabled).lower()};
constexpr int COPY_TICKS_TRADE=1,COPY_TICKS_ALL=3;
template<class T>void ArrayFree(std::vector<T> &x){{x.clear();}}
int CopyTicks(string,std::vector<MqlTick>&out,int,ulong,uint){{out.clear();return 0;}}
// Research reads are snapshots of a clock-controlled market, not advancing
// the operational adapter's intentional race sequence merely by reading it.
bool BookResearchHostReadQuote(string,MqlTick &q){{if(fixture_quotes.empty())return false;q=fixture_quotes[std::min(fixture_quote_index,(int)fixture_quotes.size()-1)];return true;}}
#define SymbolInfoTick BookResearchHostReadQuote
#include "{ROOT}/Include/BookResearchRuntime.mqh"
#undef SymbolInfoTick
'''
            setup=r'''BookDecisionConfig config;BookDecisionConfigDefaults(config);config.tick_size=unit;
 BookResearchRuntimeInit("trace","preset","fixture","123","60001","source",mode,config);
 BookResearchCandidate c{};c.id="trace-candidate";c.symbol=Symbol();c.direction=d;c.route=cont?"CONT":"ABS";c.mode=armed.mode;
 c.created_msc=1000000;c.armed_at_sec=1000;c.timeout_sec=90;c.trigger=10000;c.sl_distance=10*unit;c.tp_distance=20*unit;
 c.original_eligible=true;c.inner_pct=.6;c.outer_pct=.9;c.max_spread=gSpreadMaxPts;c.max_overshoot=gMaxOvershoot;c.effort_min=1.5;
 BookResearchRuntimeCandidate(c,"DIVERGENCE","ORIGINAL_ELIGIBLE","FIXTURE","{}",true);'''
            after=r'''BookResearchMarketSample x{};x.now_msc=1000000;x.ordinal=1;x.bid=10000;x.ask=10001;
 BookResearchRuntimeSample(x);BookResearchRuntimeTimer();'''
            program=execution_fixture(current,extra,main.replace('RESEARCH_SETUP',setup).replace('RESEARCH_AFTER',after),full_guards=True,operational=True)
            program=program.replace('struct MqlTick { long long time_msc=', 'struct MqlTick { long long time=0,time_msc=')
            actual,_=run_program(f'#include "{ROOT}/tests/research_noop_hooks.hpp"\n'+program)
            self.assertEqual(actual,expected, f'research_enabled={enabled}')
        print('REFERENCE_94f_OFF_ON_DISPATCH_FINANCIAL_PARITY 384 traces per arm; ORIGINAL and APLICAR; API/journals/quota/risk unchanged')

    def test_pure_shadow_stage2_matches_actual_original_readiness(self):
        """No effectful readiness function is reused by the actual observer.

        This fixture compares the extracted effectful original against the pure
        projection on identical frozen operands. Session/timeout order, both
        directions/routes, assets, breakout, overshoot, live bands and missing
        trade flags are tested independently of the decision mode.
        """
        main = r'''
int main(){
 int compared=0,ready=0,wait=0,cancel=0;
 Inp_DecisionMode=DECISION_ORIGINAL;
 for(double unit:{.5,5.0})for(int d:{-1,1})for(bool cont:{false,true})
 for(int scenario=0;scenario<14;scenario++){
  fixture_reset(d,cont,false,unit);
  wwValid=true;Inp_EnableLateDirectionBlock=false;SigmaD1=1000;
  switch(scenario){
   case 1:fixture_time=1090;break;
   case 2:fixture_hour=15;fixture_minute=30;break;
   case 3:fixture_quotes.clear();break;
   case 4:for(auto &q:fixture_quotes)q.flags=0;break;
   case 5:for(auto &q:fixture_quotes)q.last=0;break;
   case 6:for(auto &q:fixture_quotes)q.last=10000-d*unit;break;
   case 7:for(auto &q:fixture_quotes){q.last=10000+d*30*unit;q.ask=q.bid=q.last;}break;
   case 8:wwValid=false;break;
   case 9:armed.dir=-d;break;
   case 10:armed.breakoutEffortMin=3;break;
   case 11:SigmaD1=0;break;
   case 12:Inp_EnableLateDirectionBlock=true;break;
   case 13:SigmaD1=unit;for(auto&q:fixture_quotes){q.last=10000+d*10*unit;q.bid=q.ask=q.last;}break;
  }
  BookResearchCandidate c{};
  c.id="comparison";c.direction=armed.dir;c.original_eligible=true;
  c.route=armed.route;c.trigger=10000;c.timeout_sec=Inp_ArmedTimeoutSec;
  c.armed_at_sec=armed.armedAt;c.stop_entry_hhmm=Inp_StopEntryHHMM;
  c.max_overshoot=gMaxOvershoot;c.max_spread=gSpreadMaxPts;
  c.effort_min=armed.breakoutEffortMin;c.inner_pct=Inp_VWAP_Inner_Pct;
  c.outer_pct=Inp_VWAP_Outer_Pct;c.late_direction_block=Inp_EnableLateDirectionBlock;
  BookResearchMarketSample x{};
  x.server_sec=fixture_time;x.hhmm=fixture_hour*100+fixture_minute;
  x.quote_available=!fixture_quotes.empty();
  if(x.quote_available){auto&q=fixture_quotes[0];x.bid=q.bid;x.ask=q.ask;x.last=q.last;
   x.real_trade=(q.flags&(TICK_FLAG_LAST|TICK_FLAG_VOLUME|TICK_FLAG_BUY|TICK_FLAG_SELL))!=0;}
  x.weis_valid=wwValid;x.live_wave_direction=armed.dir;x.live_effort=2;
  x.vwap_valid=true;x.live_vwap=10000;x.sigma=SigmaD1;x.band_multiplier=BandMultiplier;
  x.context_causal=true;
  string reason;int hypothetical=BookResearchOriginalMarket(c,x,reason);
  double effort=0,trigger=0,last=0;MqlTick validated{};
  auto actual=CheckArmedMarketReady(effort,trigger,last,validated);
  int normalized=actual==APS_ENTRY_READY?1:(actual==APS_STILL_ARMED?0:-1);
  if(normalized!=hypothetical)std::cerr<<"mismatch scenario="<<scenario<<" direction="<<c.direction
   <<" route="<<c.route<<" actual="<<actual<<" hypothetical="<<hypothetical<<" reason="<<reason<<"\n";
  assert(normalized==hypothetical);
  if(normalized==1)ready++;else if(normalized==0)wait++;else cancel++;
  compared++;
 }
 assert(compared==112&&ready>0&&wait>0&&cancel>0);
 std::cout<<"ORIGINAL_STAGE2_PARITY cases="<<compared<<" ready="<<ready<<" wait="<<wait
  <<" cancelled="<<cancel<<" pure observer has no real armed access\n";
}
'''
        source = (ROOT / "scalpertalvez.mq5").read_text()
        result = compile_run(execution_fixture(
            source, decision_adapter_original_only() + CORE, main,
            full_guards=True, operational=True,
        ))
        self.assertIn("ORIGINAL_STAGE2_PARITY cases=112", result)
        print(result.strip())


if __name__ == "__main__":
    unittest.main(verbosity=2)
