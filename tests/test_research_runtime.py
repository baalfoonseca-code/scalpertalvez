"""Execute the actual isolated research core/collector/sink, terminal APIs adapted."""
from pathlib import Path
import csv
import json
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

def run(code):
    return run_program(f'#include "{ROOT}/tests/research_host_support.hpp"\n'+code)

def run_program(program):
    with tempfile.TemporaryDirectory(prefix='research-host-') as td:
        path=Path(td);(path/'fixture.cpp').write_text('#define BOOK_RISK_HOST\n'+program)
        built=subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra',str(path/'fixture.cpp'),'-o',str(path/'fixture')],capture_output=True,text=True)
        if built.returncode:raise AssertionError(built.stderr)
        result=subprocess.run([str(path/'fixture')],cwd=path,capture_output=True,text=True)
        if result.returncode:raise AssertionError(result.stdout+result.stderr)
        files={p.name:p.read_text() for p in path.glob('Research_*') if p.is_file()}
        return result.stdout,files

class ResearchRuntimeTests(unittest.TestCase):
    def test_core_positive_negative_barriers_and_causal_first_quote(self):
        out,_=run(r'''
int main(){int complete=0;
 for(string asset:{"WINZ26","WDOX26"})for(int d:{-1,1})for(bool cont:{false,true})for(int result=0;result<4;result++){
  auto c=research_candidate("c",d,cont);c.symbol=asset;
  BookResearchTrack t;BookResearchTrackReset(t);
  auto x=research_sample(1000000,1,5500,d);BookResearchStep(c,x,t);assert(t.stage2_demonstrated);
  x=research_sample(1000001,2,5500+d*.5,d);BookResearchStep(c,x,t);
  assert(t.entry_reference_available&&t.dispatch_eligible_observed&&t.entry_msc==1000001);
  double entry=t.entry;assert(entry==(d==1?x.ask:x.bid));
  if(result<2){x=research_sample(1001000,3,entry+d*(result==0?11:-6),d);
   if(d==-1)x.ask=entry+d*(result==0?11:-6);BookResearchStep(c,x,t);
   assert(t.barrier==(result==0?"TP_QUOTE_TOUCH_FIRST":"SL_QUOTE_TOUCH_FIRST"));}
  if(result==2){x=research_sample(1900002,3,entry,d);BookResearchStep(c,x,t);assert(t.barrier=="NO_BARRIER_OBSERVED");}
  if(result==3){x=research_sample(1000500,3,entry,d);x.path_complete=false;BookResearchStep(c,x,t);
   x=research_sample(1001000,4,entry+d*11,d);if(d==-1)x.ask=entry-11;BookResearchStep(c,x,t);assert(t.barrier=="AMBIGUOUS_PATH");}
  complete++;
 }assert(complete==32);std::cout<<"core_routes_assets_dirs_paths="<<complete<<"\n";
}''')
        self.assertIn('=32',out)

    def test_never_stage2_spread_overshoot_timeout_hard_and_financial_collision(self):
        out,_=run(r'''
int main(){for(int k=0;k<6;k++){
 auto c=research_candidate();BookResearchTrack t;BookResearchTrackReset(t);auto x=research_sample(1000000,1);
 if(k==0)x.live_wave_direction=-1;
 if(k==1)x.ask=x.bid+2;
 if(k==2)x.last=x.bid=x.ask=5600;
 if(k==3){x.server_sec=1090;x.now_msc=1090000;}
 if(k==4){x.new_signal_bar=true;x.hard_snapshot_valid=true;x.hard_contradiction=true;}
 if(k==5)x.financial_possible=false;
 BookResearchStep(c,x,t);
 if(k==5){x.ordinal++;x.now_msc++;BookResearchStep(c,x,t);assert(t.original_ended);}
 else assert(!t.entry_reference_available);
 if(k==2||k==3||k==4)assert(t.original_ended);
 }std::cout<<"original_cancel_wait_and_collision=6\n";
}''')
        self.assertIn('=6',out)

    def test_overlapping_trade_queries_preserve_identical_millisecond_ordinals(self):
        out,_=run(r'''
int main(){research_init();std::vector<MqlTick> rows={research_tick(1000000,5500),research_tick(1000000,5500)};
 BookResearchRuntimeIngest(1000000,1000000,rows.data(),2);assert(gBookResearchTradeCount==2);
 rows.push_back(rows.back());BookResearchRuntimeIngest(1000000,1000000,rows.data(),3);
 assert(gBookResearchTradeCount==3&&gBookResearchTailCount==3);
 BookResearchRuntimeIngest(1000000,1000000,rows.data(),3);assert(gBookResearchTradeCount==3);
 rows[0].volume=11;BookResearchRuntimeIngest(1000000,1000000,rows.data(),3);assert(gBookResearchTradeFault);
 std::cout<<"distinct=3 double_count=0 changed_prefix_fault=1\n";
}''')
        self.assertIn('double_count=0',out)

    def test_actual_runtime_candidate_stage2_and_tp_csv_roundtrip(self):
        out,files=run(r'''
int main(){research_init();auto c=research_candidate();
 BookResearchRuntimeCandidate(c,"STALL_STRICT","ORIGINAL_ELIGIBLE","SELECTED_BEFORE_APPLY","{\"fixture\":true}",true);
 BookDecisionEvidence e{};e.now_msc=1000000;BookDecisionVerdict v{};v.result=DECISION_DADOS_INSUFICIENTES;v.reason="ABS_COMPARABLE_REFERENCES_INSUFFICIENT";
 BookResearchRuntimeEvidence(c.id,e,v,1,false,false,false,"ACTUAL_OPERATIONAL_APPLY");
 std::vector<MqlTick> quotes;
 for(int j=0;j<3;j++){
  long msc=1000000+j;auto q=research_tick(msc,j<2?5500:5512);auto x=research_sample(msc,j+1,q.bid);
  quotes.push_back(q);BookResearchRuntimeSample(x);
  BookResearchQuoteBatch(1000000,msc,quotes.data(),static_cast<int>(quotes.size()),true);
  assert(!gBookResearchQuoteFault);BookResearchProcessSamples();
 }
 quotes.push_back(research_tick(1000003,5512));BookResearchQuoteBatch(1000000,1000003,quotes.data(),static_cast<int>(quotes.size()),true);BookResearchProcessSamples();
 assert(gBookResearchOpportunities[0].track.entry_reference_available);
 assert(gBookResearchOpportunities[0].track.barrier=="TP_QUOTE_TOUCH_FIRST");
 for(int n=0;n<8;n++)BookResearchFlush();
 std::cout<<"runtime_hypothetical_tp=1 actual_order_calls=0\n";
}''')
        self.assertIn('actual_order_calls=0',out)
        for name,text in files.items():
            if name.endswith('.csv'):
                rows=list(csv.DictReader(text.splitlines()))
                self.assertTrue(rows)
                self.assertTrue(all(None not in r and all(v is not None for v in r.values()) for r in rows),name)
        outcomes=[r for n,t in files.items() if n.endswith('Outcomes.csv') for r in csv.DictReader(t.splitlines())]
        self.assertTrue(any(r['status']=='TP_FIRST' and r['pnl_confirmed']=='0' for r in outcomes))

    def test_off_no_collectors_or_files_and_queue_failure_is_research_only(self):
        out,files=run(r'''
int main(){Inp_ResearchEnable=false;BookDecisionConfig c;BookDecisionConfigDefaults(c);
 BookResearchRuntimeInit("off","","","1","2","",DECISION_APLICAR,c);
 BookResearchRuntimeTimer();assert(research_copy_calls==0&&!gBookResearchReady);
 research_init();int preserved_financial=42;
 for(int i=0;i<BOOK_RESEARCH_QUEUE_CAP+2;i++)BookResearchHealth("X","X","");
 assert(gBookResearchSuspended && preserved_financial==42 && gBookResearchDropped>0);
 std::cout<<"off_no_io=1 queue_failure_local=1\n";
}''')
        self.assertIn('off_no_io=1',out)
        self.assertFalse(any('off_' in n for n in files))

    def test_restart_marker_and_write_failure_preserve_old_research(self):
        out,files=run(r'''
int main(){research_init("old");BookResearchHealth("X","X","");BookResearchFlush();
 BookResearchRuntimeCandidate(research_candidate(),"STALL_STRICT","ORIGINAL_ELIGIBLE","TEST","{}",true);
 BookResearchWriteMarker("OPEN");research_init("new");BookResearchFlush();
 gBookResearchPrefix="missing/directory/Research_";BookResearchHealth("X","X","");BookResearchFlush();
 assert(gBookResearchSuspended&&gBookResearchIOErrors>0);std::cout<<"restart_explicit=1 write_failure_local=1\n";
}''')
        self.assertIn('write_failure_local=1',out)
        self.assertTrue(any('old' in n for n in files))
        self.assertTrue(any('PRIOR_TRACKS_NOT_RESUMED' in t for n,t in files.items() if 'new' in n))

    def test_independent_original_mode_apply_assessment_can_validate_both_routes(self):
        out,files=run(r'''
int main(){int approved=0;
 for(bool cont:{false,true}){
  research_init(cont?"independent-cont":"independent-abs");gBookResearchActualMode=DECISION_ORIGINAL;
  auto c=research_candidate("independent",1,cont);BookResearchRuntimeCandidate(c,"DIVERGENCE","ORIGINAL_ELIGIBLE","TEST","{}",true);
  std::vector<MqlTick> rows;double anchor=5500;int pressure=cont?1:-1;
  for(int w=0;w<17;w++){
   for(int j=0;j<10;j++){
    double price=w<16?anchor+pressure*(j*.5): (cont?anchor+1+j:anchor);
    auto q=research_tick(1000000+w*5000+j*500,price,pressure);q.volume=w==16?15:10;rows.push_back(q);
   }anchor=rows.back().last;
  }
  long to=1085000;
  if(!cont)for(int j=0;j<5;j++){auto q=research_tick(to+j*250,anchor+1+j*.5,-1);rows.push_back(q);}
  long end=cont?to:to+1000;
  BookResearchRuntimeIngest(1000000,end,rows.data(),static_cast<int>(rows.size()));assert(!gBookResearchTradeFault);
  BookResearchShadowEvidence(0,end);
  assert(gBookResearchOpportunities[0].last_result.find("VALIDAR")!=string::npos);
  assert(gBookResearchHistory.count>=34);approved++;
  for(int j=0;j<8;j++)BookResearchFlush();
 }assert(approved==2);std::cout<<"independent_ORIGINAL_shadow_APPLY_valid_ABS_CONT=2\n";
}
''')
        self.assertIn('ABS_CONT=2',out)
        self.assertTrue(any('INDEPENDENT_RESEARCH_APPLY' in text for name,text in files.items() if 'Decisions' in name))

    def test_quote_prefix_corruption_marks_ambiguous_and_suspends_only_research(self):
        out,files=run(r'''
int main(){research_init();auto c=research_candidate();BookResearchRuntimeCandidate(c,"DIVERGENCE","ORIGINAL_ELIGIBLE","TEST","{}",true);
 for(int j=0;j<2;j++){
  auto x=research_sample(1000000+j,j+1);BookResearchStep(c,x,gBookResearchOpportunities[0].track);
 }assert(gBookResearchOpportunities[0].track.entry_reference_available);
 auto q=research_tick(1000000,5500);BookResearchQuoteBatch(1000000,1000000,&q,1,true);
 q.ask+=1;BookResearchQuoteBatch(1000000,1000000,&q,1,true);assert(gBookResearchQuoteFault);
 BookResearchRuntimeTimer();assert(gBookResearchSuspended&&gBookResearchOpportunities[0].track.barrier=="AMBIGUOUS_PATH");
 for(int j=0;j<8;j++)BookResearchFlush();std::cout<<"gap_ambiguous_and_research_suspended=1\n";
}
''')
        self.assertIn('gap_ambiguous',out)
        self.assertTrue(any('AMBIGUOUS_PATH' in t for n,t in files.items() if 'Outcomes' in n))

    def test_end_of_session_partial_horizons_and_no_entry_timeout_are_explicit(self):
        out,files=run(r'''
int main(){research_init();auto c=research_candidate();BookResearchRuntimeCandidate(c,"DIVERGENCE","ORIGINAL_ELIGIBLE","TEST","{}",true);
 auto x=research_sample(1000000,1);x.live_wave_direction=-1;BookResearchStep(c,x,gBookResearchOpportunities[0].track);
 x.ordinal++;x.now_msc=1090000;x.server_sec=1090;BookResearchStep(c,x,gBookResearchOpportunities[0].track);
 assert(gBookResearchOpportunities[0].track.original_reason=="TIMEOUT_ARMED"&&!gBookResearchOpportunities[0].track.entry_reference_available);
 BookResearchRuntimeEndSession("EOD_INCOMPLETE");BookResearchFlush();assert(gBookResearchOpportunities[0].track.stage==RESEARCH_FINISHED);
 assert(!gBookResearchOpportunities[0].track.horizon_done[2]);std::cout<<"timeout_no_entry_eod_partial=1\n";
}
''')
        self.assertIn('timeout_no_entry',out)

    def test_minute_vwap_aggregate_preserves_evicted_trades_and_excludes_future(self):
        out,_=run(r'''
int main(){research_clock=1020000;BookDecisionConfig cfg;BookDecisionConfigDefaults(cfg);cfg.tick_size=.5;
 BookResearchRuntimeInit("vwap","preset","","1","2","code",DECISION_APLICAR,cfg);
 std::vector<MqlTick> rows;
 for(int i=0;i<8200;i++)rows.push_back(research_tick(1020000+i,5500));
 BookResearchRuntimeIngest(1020000,1027999,rows.data(),8000);
 BookResearchRuntimeIngest(rows[7999].time_msc,1028199,rows.data()+7999,201);
 assert(!gBookResearchTradeFault&&gBookResearchTradeCount==8192);
 double value=0;assert(BookResearchRuntimeLiveVwap(5500*100,100,1020000,1028100,value));assert(value==5500);
 auto future=research_tick(1028200,6500);std::vector<MqlTick> suffix={rows.back(),future};
 BookResearchRuntimeIngest(1028199,1028200,suffix.data(),2);
 assert(BookResearchRuntimeLiveVwap(5500*100,100,1020000,1028100,value));assert(value==5500);
 assert(BookResearchRuntimeLiveVwap(5500*100,100,1020000,1028200,value));assert(value>5500);
 std::cout<<"vwap_raw_eviction_preserved=1 future_excluded=1\n";
}
''')
        self.assertIn('future_excluded=1',out)

    def test_terminal_cancellation_timeout_and_session_cannot_be_resurrected(self):
        out,_=run(r'''
int main(){for(int k=0;k<3;k++){
 research_init();auto c=research_candidate();
 if(k==2){c.created_msc=900000;c.armed_at_sec=900;c.stop_entry_hhmm=16;}
 BookResearchRuntimeCandidate(c,"DIVERGENCE","ORIGINAL_ELIGIBLE","TEST","{}",true);
 auto x=research_sample(c.created_msc,1);x.server_sec=c.armed_at_sec;x.hhmm=k==2?15:16;
 BookResearchStep(c,x,gBookResearchOpportunities[0].track);assert(gBookResearchOpportunities[0].track.stage==RESEARCH_STAGE2_READY);
 if(k==0){x.ordinal=2;x.now_msc++;x.new_signal_bar=true;x.hard_snapshot_valid=true;x.hard_contradiction=true;
  BookResearchStep(c,x,gBookResearchOpportunities[0].track);assert(gBookResearchOpportunities[0].track.original_ended);}
 BookResearchQuoteRecord r{};r.ordinal=3;r.tick=research_tick(k==1?1090000:(k==2?960000:1000002),5500);
 BookResearchQuoteOnly(r);auto t=gBookResearchOpportunities[0].track;
 assert(t.original_ended&&!t.entry_reference_available);
 }std::cout<<"cancel_timeout_session_never_resurrect=3\n";
}''')
        self.assertIn('never_resurrect=3',out)

    def test_same_millisecond_context_ambiguity_preserves_ordered_barrier_path(self):
        out,_=run(r'''
int main(){research_init();auto c=research_candidate();BookResearchRuntimeCandidate(c,"DIVERGENCE","ORIGINAL_ELIGIBLE","TEST","{}",true);
 std::vector<MqlTick> quotes={research_tick(1000000,5500),research_tick(1000001,5500),research_tick(1000002,5512),research_tick(1000002,5513),research_tick(1000003,5513)};
 for(int j=0;j<3;j++)BookResearchRuntimeSample(research_sample(1000000+j,j+1,j<2?5500:5513));
 BookResearchQuoteBatch(1000000,1000003,quotes.data(),static_cast<int>(quotes.size()),true);BookResearchProcessSamples();
 auto t=gBookResearchOpportunities[0].track;assert(t.entry_reference_available && !t.path_ambiguous && t.barrier=="TP_QUOTE_TOUCH_FIRST");
 assert(t.tp_touch_msc==1000002);std::cout<<"ordered_duplicate_ms_path_not_erased=1\n";
}''')
        self.assertIn('not_erased=1',out)

    def test_appendable_timestamp_group_does_not_invent_callback_ordinal(self):
        out,_=run(r'''
int main(){research_init();auto c=research_candidate();BookResearchRuntimeCandidate(c,"DIVERGENCE","ORIGINAL_ELIGIBLE","TEST","{}",true);
 auto q=research_tick(1000000,5500);BookResearchRuntimeSample(research_sample(1000000,1));
 BookResearchQuoteBatch(1000000,1000000,&q,1,true);BookResearchProcessSamples();assert(!gBookResearchOpportunities[0].track.stage2_demonstrated);
 std::vector<MqlTick> rows={q,q,research_tick(1000001,5501)};BookResearchQuoteBatch(1000000,1000001,rows.data(),3,true);BookResearchProcessSamples();
 auto t=gBookResearchOpportunities[0].track;assert(!t.stage2_demonstrated&&t.context_incomplete&&!t.path_ambiguous);
 assert(gBookResearchQuoteOrdinal==3);std::cout<<"open_group_ordinal_not_invented=1 distinct_quotes=3\n";
}''')
        self.assertIn('distinct_quotes=3',out)

    def test_backlog_horizon_waits_for_quotes_and_preserves_late_processed_tp(self):
        out,_=run(r'''
int main(){research_init();auto c=research_candidate();BookResearchRuntimeCandidate(c,"DIVERGENCE","ORIGINAL_ELIGIBLE","TEST","{}",true);
 std::vector<MqlTick> initial={research_tick(1000000,5500),research_tick(1000001,5500),research_tick(1000002,5500)};
 for(int j=0;j<2;j++)BookResearchRuntimeSample(research_sample(1000000+j,j+1));
 BookResearchQuoteBatch(1000000,1000002,initial.data(),3,true);BookResearchProcessSamples();assert(gBookResearchOpportunities[0].track.entry_reference_available);
 for(int j=0;j<2060;j++)research_quotes.push_back(research_tick(1000000+j,5500));
 research_quotes.push_back(research_tick(1899999,5512));research_quotes.push_back(research_tick(1901000,5500));research_clock=1901000;
 BookResearchRuntimeTimer();assert(gBookResearchOpportunities[0].track.stage==RESEARCH_TRACKING);
 assert(gBookResearchOpportunities[0].track.tp_touch_msc==0);
 BookResearchRuntimeTimer();auto t=gBookResearchOpportunities[0].track;
 assert(t.tp_touch_msc==1899999&&t.barrier=="TP_QUOTE_TOUCH_FIRST"&&t.stage==RESEARCH_FINISHED);
 std::cout<<"horizon_does_not_outrun_backlog=1 TP_preserved=1\n";
}''')
        self.assertIn('TP_preserved=1',out)

    def test_sigma_stop_uses_exact_native_kernel_at_near_tick_boundaries(self):
        out,_=run(r'''
int main(){int cases=0;for(int d:{-1,1})for(double sigma:{4.9999996,5.0000004,9.9999996,10.0000004}){
 auto c=research_candidate("sigma",d);c.risk_parameters_frozen=true;c.sigma_stop=true;c.frozen_sigma=sigma;
 c.sl_multiplier=1;c.sl_cap=10;c.tick_size=1;c.price_digits=6;c.tp_distance=10;
 double expected,raw,distance;bool capped;assert(BRSigmaStop(d,100,sigma,1,10,1,expected,raw,distance,capped));
 double sl,tp;assert(BookResearchStops(c,100,sl,tp));assert(sl==expected&&d*(100-sl)<=10);cases++;
 }assert(cases==8);std::cout<<"native_sigma_boundary_parity=8\n";
}''')
        self.assertIn('parity=8',out)

    def test_reference_membership_and_shortage_reasons_are_separate(self):
        out,_=run(r'''
BookDecisionWindow ref_window(long from,int bucket,int pressure,ulong amount=10){
 auto cfg=gBookResearchConfig;BookDecisionWindow w;BookDecisionWindowReset(w,from,from+4999,5490,.5,from-1,5480,true,cfg.source,bucket,gBookResearchTradeEpoch);
 for(int j=0;j<10;j++)BookDecisionWindowTick(w,5500+j*.5,amount,from+j*500,pressure);w.complete=true;return w;
}
int main(){research_init();for(int j=0;j<16;j++)BookDecisionHistoryInsert(gBookResearchConfig,gBookResearchHistory,ref_window(1000000+j*5000,0,1));
 BookResearchRuntimeReferenceContext(gBookResearchHistory,true,7,gBookResearchTradeEpoch,123,1105000);
 auto w=ref_window(1100000,0,1);BookDecisionRanks r;BookDecisionCompare(gBookResearchConfig,gBookResearchHistory,w,1,r);
 assert(r.available&&r.count==16);BookResearchArchiveWindow(w,gBookResearchHistory,true);
 string shortage,cells;BookResearchReferenceCells(w,r,1,true,"CURRENT",shortage,cells);assert(shortage=="SUFFICIENT");assert(cells.find("EXACT_WINDOW_CLOSE_SNAPSHOT")!=string::npos);
 w=ref_window(1800000,1,1);BookResearchReferenceCells(w,r,1,true,"CURRENT",shortage,cells);assert(shortage=="NEW_BUCKET_NO_PRIOR_REFERENCES");
 w=ref_window(1100000,0,-1);BookResearchReferenceCells(w,r,1,true,"CURRENT",shortage,cells);assert(shortage=="MINORITY_PRESSURE_REFERENCE_SHORTAGE");
 w=ref_window(1100000,0,1,1000);BookResearchReferenceCells(w,r,1,true,"CURRENT",shortage,cells);assert(shortage=="EFFORT_NOT_COMPARABLE");
 w.ambiguous=1;BookResearchReferenceCells(w,r,1,true,"CURRENT",shortage,cells);assert(shortage=="AGGRESSOR_FLAGS_AMBIGUOUS");
 std::cout<<"reference_causes_and_membership=5 signal_generation=7 data_version=123\n";
}''')
        self.assertIn('membership=5',out)

    def test_actual_dispatch_witness_prevents_own_position_collision_before_queue_drain(self):
        out,files=run(r'''
int main(){research_init();gBookResearchActualMode=DECISION_ORIGINAL;
 auto c=research_candidate("already-dispatched");
 BookResearchMarkActualDispatch(c.id,1000000,1000000); // Capture exists before candidate serialization.
 BookResearchRuntimeCandidate(c,"DIVERGENCE","ORIGINAL_ELIGIBLE","TEST","{}",true);
 assert(gBookResearchOpportunities[0].actual_dispatch&&gBookResearchOpportunities[0].track.original_ended);
 auto x=research_sample(1000000,1);x.financial_possible=false;
 BookResearchStep(c,x,gBookResearchOpportunities[0].track);
 assert(!gBookResearchOpportunities[0].track.entry_reference_available&&gBookResearchOpportunities[0].track.stage2_demonstrated);
 assert(gBookResearchOpportunities[0].track.original_reason=="ACTUAL_DISPATCH_ALREADY_OBSERVED");
 research_quotes={research_tick(1000000,5500),research_tick(1000001,5500)};research_clock=1000001;
 BookResearchRuntimeTimer();for(int j=0;j<8;j++)BookResearchFlush();
 assert(gBookResearchOpportunities[0].dispatch_assessed&&!gBookResearchOpportunities[0].track.entry_reference_available);
 std::cout<<"actual_dispatch_not_a_second_hypothetical_order=1\n";
}''')
        self.assertIn('second_hypothetical_order=1',out)
        self.assertTrue(any('EXACT_DISPATCH_MARKET_CLOCK_NOT_CAPTURED' in text for name,text in files.items() if 'Decisions' in name))

    def test_missing_new_bar_hard_context_cannot_disappear_next_callback(self):
        out,_=run(r'''
int main(){auto c=research_candidate();BookResearchTrack t;BookResearchTrackReset(t);
 auto x=research_sample(1000000,1);x.live_wave_direction=-1;BookResearchStep(c,x,t);
 x=research_sample(1020000,2);x.signal_bar=1020;x.new_signal_bar=true;x.hard_snapshot_valid=false;BookResearchStep(c,x,t);
 assert(t.hard_context_pending&&!t.stage2_demonstrated);
 x.ordinal++;x.now_msc++;x.new_signal_bar=false;BookResearchStep(c,x,t);assert(!t.stage2_demonstrated);
 x.ordinal++;x.now_msc++;x.hard_snapshot_valid=true;BookResearchStep(c,x,t);
 x.ordinal++;x.now_msc++;BookResearchStep(c,x,t);
 assert(t.entry_reference_available&&!t.dispatch_eligible_observed&&t.context_incomplete);
 std::cout<<"missing_HDC_context_stays_unproved=1 later_reference_conditional=1\n";
}''')
        self.assertIn('stays_unproved=1',out)

    def test_new_bucket_unknown_ambiguous_flags_and_history_warmup(self):
        out,_=run(r'''
int main(){research_init();auto cfg=gBookResearchConfig;BookDecisionHistory h;BookDecisionHistoryReset(h);
 for(int window=0;window<17;window++){
  BookDecisionWindow w;long from=1000000+window*5000;
  BookDecisionWindowReset(w,from,from+4999,5490,.5,from-1,5480,true,cfg.source,0,1);
  for(int j=0;j<10;j++)BookDecisionWindowTick(w,5500+j*.5,10,from+j*500,1);
  w.complete=true;BookDecisionRanks ranks;BookDecisionCompare(cfg,h,w,1,ranks);
  if(window==15)assert(!ranks.available);if(window==16)assert(ranks.available&&ranks.conditional_count==16);
  BookDecisionHistoryInsert(cfg,h,w);
 }
 BookDecisionWindow w;BookDecisionWindowReset(w,1100000,1104999,5490,.5,1099999,5480,true,cfg.source,1,1);
 for(int j=0;j<10;j++)BookDecisionWindowTick(w,5500+j*.5,10,1100000+j*500,1);w.complete=true;
 BookDecisionRanks ranks;BookDecisionCompare(cfg,h,w,1,ranks);assert(!ranks.available&&ranks.count==0);
 BookMicroMetrics m;w.ambiguous=1;assert(!BookDecisionWindowQuality(cfg,w,m,1));
 w.ambiguous=0;w.vu=w.vb;w.vb=0;assert(!BookDecisionWindowQuality(cfg,w,m,1));
 std::cout<<"warmup_end=16 new_bucket_unavailable=1 ambiguous_unknown_fail=1\n";
}''')
        self.assertIn('warmup_end=16',out)

if __name__=='__main__':unittest.main(verbosity=2)
