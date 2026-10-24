"""Actual pure MQL-shared policy compiled under C++17; not native MetaEditor.

Finite predicates/units are specified before implementation in
Include/BookDecisionCore.mqh and before operands in decision_policy_cases.hpp.
These tests do not replace the entry-dispatch integration fixtures.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

CPP = r'''
#include <cassert>
#include <cmath>
#include <iostream>
#include <limits>
#include <string>
using string=std::string;
#define input
#include "Include/BookDecisionInputs.mqh"
#include "Include/BookMicroMath.mqh"
#include "Include/BookDecisionCore.mqh"
#include "tests/decision_policy_cases.hpp"
void abs_valid(){
 for(double ts:{0.5,5.0})for(int d:{-1,1})for(int subtype:{0,1,2}){
  auto c=DecisionTestConfig(ts);auto e=DecisionTestABS(c,d,true);e.original_subtype=subtype;
  BookDecisionVerdict v;BookDecisionAssess(c,e,d,false,true,v);
  assert(v.result==DECISION_VALIDAR);assert(v.resistance==1.0);
  assert(v.net_progress==6);assert(v.pressure_share==1);assert(v.coverage==1);
  assert(v.volume_acceptance==1&&v.time_acceptance==1);
  BookMicroMetrics m;assert(BookDecisionWindowQuality(c,e.reaction,m,d));
  assert(m.pressure_direction==-d); // No universal delta-inversion requirement.
 }
 auto c=DecisionTestConfig();auto e=DecisionTestABS(c,1,false);BookDecisionVerdict v;
 BookDecisionAssess(c,e,1,false,true,v);assert(v.result==DECISION_AGUARDAR);
 std::cout<<"ABS valid: T resistance=1, R net=6ticks, acceptance(volume,time)=1,1; opposite delta retained\n";
}
void abs_opposite(){
 for(int d:{-1,1}){auto c=DecisionTestConfig();auto e=DecisionTestABS(c,d,true);
  e.current=DecisionTestWindow(c,e.test.flow.to_msc+1,-d,-d,2);e.now_msc=e.current.flow.to_msc;
  BookDecisionVerdict v;BookDecisionAssess(c,e,d,false,false,v);assert(v.result==DECISION_VETAR_CANDIDATO);
  BookDecisionAssess(c,e,d,false,true,v);assert(v.result==DECISION_INVALIDAR_ARMED);
  assert(v.net_progress==-10&&v.pressure_share==1);
 }
 std::cout<<"ABS blocked: opposite progress=10ticks, opposite acceptance(volume,time)=1,1 -> candidate veto/armed invalidation\n";
}
void inactive_bilateral(){
 auto c=DecisionTestConfig();BookDecisionEvidence e{};e.have_current=true;e.original_subtype=0;
 BookDecisionWindowReset(e.current,1000000,1004999,100,1,999999,100,true,c.source,0,1);
 e.current.complete=true;e.now_msc=1004999;BookDecisionVerdict v;
 BookDecisionAssess(c,e,1,false,false,v);assert(v.result==DECISION_VETAR_CANDIDATO);
 for(int i=0;i<6;i++)BookDecisionWindowTick(e.current,100+(i%2),20,1000000+(i==5?4999:i*1000),i%2?1:-1);
 BookDecisionAssess(c,e,1,false,false,v);assert(v.result==DECISION_VETAR_CANDIDATO);
 assert(v.pressure_share==0);std::cout<<"No absorption fabricated from inactivity or bilateral rotation\n";
}
void cont_valid(){
 for(double ts:{0.5,5.0})for(int d:{-1,1}){auto c=DecisionTestConfig(ts);auto e=DecisionTestCONT(c,d);
  BookDecisionVerdict v;BookDecisionAssess(c,e,d,true,true,v);assert(v.result==DECISION_VALIDAR);
  assert(v.net_progress==10&&v.volume_acceptance==1&&v.time_acceptance==1);
 }
 std::cout<<"CONT valid: net=10ticks, acceptance(volume,time)=1,1, positive prior-VWAP migration; no extra wait\n";
}
void cont_rejection(){
 for(int d:{-1,1}){auto c=DecisionTestConfig();auto e=DecisionTestCONT(c,d,true);BookDecisionVerdict v;
  BookDecisionAssess(c,e,d,true,false,v);assert(v.result==DECISION_VETAR_CANDIDATO);
  BookDecisionAssess(c,e,d,true,true,v);assert(v.result==DECISION_INVALIDAR_ARMED);
  assert(v.net_progress<0);
 }
 std::cout<<"CONT blocked by produced opposite progress+accepted volume/time beyond frozen context\n";
}
void pause(){
 auto c=DecisionTestConfig();auto e=DecisionTestCONT(c,1);long from=e.forward.flow.to_msc+1;
 BookDecisionWindowReset(e.current,from,from+999,e.forward.flow.last,1,from-1,
  e.forward.pv/(e.forward.vb+e.forward.vs),true,c.source,0,1);
 for(int i=0;i<4;i++)BookDecisionWindowTick(e.current,e.forward.flow.last,1,from+i*300,i%2?1:-1);
 e.current.complete=true;e.now_msc=e.current.flow.to_msc;BookDecisionRanksReset(e.current_ranks);
 BookDecisionVerdict v;BookDecisionAssess(c,e,1,true,true,v);assert(v.result==DECISION_AGUARDAR);
 assert(v.reason=="CONT_NORMAL_PAUSE_WITHOUT_CURRENT_PROGRESS");
 assert(v.net_progress==0&&v.pressure_share==0);
 // Opposite delta by itself, while price still retains accepted context, cannot cancel.
 e.current.vb=0;e.current.vs=4;BookDecisionAssess(c,e,1,true,true,v);assert(v.result==DECISION_AGUARDAR);
 e.now_msc=e.forward.flow.to_msc+c.window_sec*2000+1;
 BookDecisionAssess(c,e,1,true,true,v);assert(v.result!=DECISION_INVALIDAR_ARMED&&v.result!=DECISION_VALIDAR);
 std::cout<<"Efficient trend small pause retained; expired evidence waits/unavailable, never trend-ended by ER/volume alone\n";
}
void bad_data(){
 auto c=DecisionTestConfig();auto good=DecisionTestCONT(c,1);BookDecisionVerdict v;
 for(int kind=0;kind<10;kind++){
  auto e=good;e.have_forward=false;
  if(kind==0){e.current.vb=61;e.current.vs=59;BookDecisionRanksReset(e.current_ranks);}
  if(kind==1)e.current.ambiguous=1;
  if(kind==2){e.current.vu=e.current.vb;e.current.vb=0;}
  if(kind==3)e.current.flow.observed_msc=0;
  if(kind==4)e.current.ordered=false;
  if(kind==5)e.current.source_ok=false;
  if(kind==6)e.current.complete=false;
  if(kind==7){e.have_forward=true;e.forward.generation++;}
  if(kind==8)e.current.flow.to_msc=e.now_msc+1;
  if(kind==9)e.current.generation=0;
  BookDecisionAssess(c,e,1,true,true,v);assert(v.result==(kind==0?DECISION_AGUARDAR:DECISION_DADOS_INSUFICIENTES));
 }
 c.source=DECISION_FLAGS_UNVERIFIED;BookDecisionAssess(c,good,1,true,true,v);
 assert(v.result==DECISION_DADOS_INSUFICIENTES&&v.reason=="AGGRESSOR_SOURCE_UNVERIFIED");
 std::cout<<"Smalldelta, ambiguous flags, unknownvolume, gap, unordered, invalidsource, incompleteprefix fail closed\n";
}
void warmup(){
 auto c=DecisionTestConfig();BookDecisionHistory h;BookDecisionHistoryReset(h);
 auto target=DecisionTestWindow(c,1100000,1,1,2);BookDecisionRanks r;
 for(int i=0;i<c.min_refs;i++){
  BookDecisionCompare(c,h,target,1,r);assert(!r.available);
  auto sample=DecisionTestWindow(c,1000000+i*5000,1,1,.5);BookDecisionHistoryInsert(c,h,sample);
 }
 BookDecisionCompare(c,h,target,1,r);assert(r.available&&r.count==16&&r.conditional_count==16);
 assert(h.count==32);
 // Inserting current cannot enter its own reference comparison.
 BookDecisionHistoryInsert(c,h,target);BookDecisionCompare(c,h,target,1,r);assert(r.count==16);
 // Future and incompatible bucket/source/duration must not contaminate authorization.
 auto future=DecisionTestWindow(c,1200000,1,1,.5);BookDecisionHistoryInsert(c,h,future);
 BookDecisionCompare(c,h,target,1,r);assert(r.count==16);
 target.bucket=1;BookDecisionCompare(c,h,target,1,r);assert(!r.available&&r.count==0);
  target.bucket=0;target.generation=2;BookDecisionCompare(c,h,target,1,r);assert(!r.available&&r.count==0);
 std::cout<<"Warmup ends exactly at16 comparable prior windows; self/future/bucket excluded\n";
}
void capacity(){
 auto c=DecisionTestConfig();BookDecisionHistory h;BookDecisionHistoryReset(h);
 for(int i=0;i<500;i++){auto s=DecisionTestWindow(c,1000000+i*5000,1,1,.5);BookDecisionHistoryInsert(c,h,s);}
 assert(h.count==BOOK_DECISION_HISTORY_CAP&&h.next>=0&&h.next<BOOK_DECISION_HISTORY_CAP);
 auto target=DecisionTestWindow(c,4000000,1,1,2);BookDecisionRanks r;
 BookDecisionCompare(c,h,target,1,r);assert(r.available&&r.count==192);
 // This is bounded rolling reference replacement, not saturation of a data
 // acquisition buffer. Missing acquisition rows are source_ok=false (bad_data).
 std::cout<<"384sample reference ring remains bounded and warms; no impossible minimum\n";
}
void sensitivity(){
 auto c=DecisionTestConfig();auto e=DecisionTestABS(c,1,true);
 long from=e.reaction.flow.from_msc;
 BookDecisionWindowReset(e.reaction,from,from+999,100,1,e.test.flow.to_msc,100,true,c.source,0,1);
 for(int i=0;i<4;i++)BookDecisionWindowTick(e.reaction,100+2*i,20,from+300*i,-1);
 e.reaction.complete=true;e.current=e.reaction;BookDecisionVerdict v;
 c.acceptance=.60;BookDecisionAssess(c,e,1,false,true,v);assert(v.result==DECISION_VALIDAR);
 c.acceptance=.70;BookDecisionAssess(c,e,1,false,true,v);assert(v.result==DECISION_AGUARDAR);
 for(double effort:{.70,.80,.90})for(double result:{.10,.20,.30}){
  c=DecisionTestConfig();c.effort_q=effort;c.result_q=result;auto good=DecisionTestABS(c,1,true);
  BookDecisionAssess(c,good,1,false,true,v);assert(v.result==DECISION_VALIDAR);
 }
 std::cout<<"Acceptance sensitivity .60passes/.70waits on measuredtime=.6667; P70/80/90 and P10/20/30 finite sweep\n";
}
void arithmetic(){
 auto c=DecisionTestConfig();auto w=DecisionTestWindow(c,1000000,1,1,2);
 w.vb=80;w.vs=30;w.vu=10;BookMicroMetrics m;
 assert(BookDecisionWindowQuality(c,w,m,1));
 assert(m.volume==120&&m.delta==50&&m.delta_low==40&&m.delta_high==60);
 assert(m.known_coverage==110.0/120.0&&m.known_imbalance==50.0/110.0);
 assert(m.net_ticks==10&&m.max_ticks==10&&m.total_path_ticks==10&&m.efficiency==1);
 auto partial=w;partial.flow.to_msc=partial.flow.from_msc+999;partial.flow.observed_msc=900;
 // Quality uses observed elapsed milliseconds, not occupied-second counts.
 assert(BookDecisionWindowQuality(c,partial,m,1)&&m.temporal_coverage==.9);
 w.flow.reference_msc=w.flow.from_msc;w.flow.level_available=false;
 BookDecisionWindowQuality(c,w,m,1);assert(!BookDecisionAcceptance(c,m));
 c.tick_size=0;assert(!BookDecisionConfigValid(c));
 c=DecisionTestConfig();c.min_refs=65;assert(!BookDecisionConfigValid(c));
 std::cout<<"V/delta/coverage/interval/Net/Max/path/ER exact; no epsilon and no futurelevel\n";
}
int main(int argc,char**argv){
 assert(argc==2);string name=argv[1];
 if(name=="abs_valid")abs_valid();else if(name=="abs_opposite")abs_opposite();
 else if(name=="inactive_bilateral")inactive_bilateral();else if(name=="cont_valid")cont_valid();
 else if(name=="cont_rejection")cont_rejection();else if(name=="pause")pause();
 else if(name=="bad_data")bad_data();else if(name=="warmup")warmup();
 else if(name=="capacity")capacity();else if(name=="sensitivity")sensitivity();
 else if(name=="arithmetic")arithmetic();else return 2;
}
'''


class DecisionCoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='book-decision-core-')
        cpp = Path(cls.temp.name)/'core.cpp'
        cls.binary = cpp.with_suffix('')
        cpp.write_text(CPP)
        built = subprocess.run(['g++','-std=c++17','-O2','-Wall','-Wextra','-Werror','-pedantic',
                                '-I',str(ROOT),str(cpp),'-o',str(cls.binary)],text=True,capture_output=True)
        if built.returncode:
            cls.temp.cleanup()
            raise AssertionError(built.stderr)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def run_case(self,name):
        result = subprocess.run([str(self.binary),name],text=True,capture_output=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        print(result.stdout.strip())

    def test_abs_valid_with_effective_reaction_and_opposite_delta(self): self.run_case('abs_valid')
    def test_abs_accepted_opposite_continuation_vetoes(self): self.run_case('abs_opposite')
    def test_stall_inactivity_and_bilateral_flow_never_fabricate_absorption(self): self.run_case('inactive_bilateral')
    def test_cont_progress_acceptance_value_migration_pass_without_fixed_delay(self): self.run_case('cont_valid')
    def test_cont_produced_rejection_vetoes_or_invalidates(self): self.run_case('cont_rejection')
    def test_small_pause_and_opposite_delta_do_not_end_trend(self): self.run_case('pause')
    def test_feed_quality_unknown_ambiguous_small_delta_gap_fail_closed(self): self.run_case('bad_data')
    def test_warmup_terminates_at_minimum_and_excludes_current_future(self): self.run_case('warmup')
    def test_reference_capacity_and_minimum_are_compatible(self): self.run_case('capacity')
    def test_threshold_sensitivity_changes_acceptance_without_statistical_claim(self): self.run_case('sensitivity')
    def test_operational_math_and_causal_level_units(self): self.run_case('arithmetic')


if __name__=='__main__': unittest.main(verbosity=2)
