"""Actual operational collector, cursor, proof and warm-up tests under host APIs.

No MetaEditor compilation, broker replay or financial performance is asserted.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

CASES = r'''
#include "decision_runtime_support.hpp"
void same_ms(){
 bd_init();long s=gBookDecisionStartMSC;
 std::vector<MqlTick> a{bd_tick(s+500),bd_tick(s+500),bd_tick(s+1000)};
 bd_feed(s,s+1000,a);assert(!gBookDecisionFault);
 assert(gBookDecisionWindow.flow.count==3&&gBookDecisionWindow.vb==30);
 auto version=gBookDecisionDataVersion;
 bd_feed(s,s+1000,a);assert(gBookDecisionWindow.flow.count==3);
 assert(gBookDecisionDataVersion==version);
 a.push_back(bd_tick(s+1000));bd_feed(s,s+1000,a);
 assert(gBookDecisionWindow.flow.count==4&&gBookDecisionTailCount==2);
 bd_feed(s,s+1000,a);assert(gBookDecisionWindow.flow.count==4);
 std::vector<MqlTick> b{a[2],a[3],bd_tick(s+1500)};
 bd_feed(s+1000,s+1500,b);assert(!gBookDecisionFault);
 assert(gBookDecisionWindow.flow.count==5&&gBookDecisionWindow.vb==50);
 assert(gBookDecisionCursorMSC==s+1500&&gBookDecisionTailCount==1);
 std::cout<<"ordinal cursor: five distinct rows, two identical pairs retained, overlaps idempotent\n";
}
void faults(){
 bd_init();long s=gBookDecisionStartMSC;
 std::vector<MqlTick> a{bd_tick(s+100),bd_tick(s+500)};
 bd_feed(s,s+500,a);a[1].last=101;bd_feed(s,s+500,a);
 assert(gBookDecisionFault&&gBookDecisionFaultReason=="OVERLAP_PREFIX_CHANGED");
 bd_init();s=gBookDecisionStartMSC;
 bd_feed(s+1,s+500,{});assert(gBookDecisionFaultReason=="UNCOVERED_BATCH_INTERVAL");
 bd_init();s=gBookDecisionStartMSC;
 bd_feed(s,s+500,{bd_tick(s+500),bd_tick(s+100)});
 assert(gBookDecisionFaultReason=="MALFORMED_OR_UNORDERED_TRADE_BATCH");
 bd_init();s=gBookDecisionStartMSC;
 bd_feed(s,s+500,{bd_tick(s+100,100,10,2),bd_tick(s+500,100,10,2)});
 assert(!gBookDecisionFault&&gBookDecisionWindow.ambiguous==2);
 BookMicroMetrics m;gBookDecisionWindow.complete=true;
 assert(!BookDecisionWindowQuality(gBookDecisionConfig,gBookDecisionWindow,m,1));
 bd_init();s=gBookDecisionStartMSC;
 bd_provider.assign(BOOK_DECISION_TAPE_CAP,bd_tick(s));bd_now(s+500);BookDecisionPump();
 assert(gBookDecisionFaultReason=="TIMESTAMP_ORDINAL_CAPACITY");
 bd_init();s=gBookDecisionStartMSC;bd_copy_error=4401;bd_now(s+500);BookDecisionPump();
 assert(gBookDecisionFaultReason=="INCREMENTAL_TRADE_COPY_FAILED");
 bd_init();s=gBookDecisionStartMSC;auto bad=bd_tick(s+100);bad.time++;
 bd_feed(s,s+500,{bad});assert(gBookDecisionFaultReason=="MALFORMED_OR_UNORDERED_TRADE_BATCH");
 bd_init();s=gBookDecisionStartMSC;bad=bd_tick(s+100);bad.volume=9007199254740993UL;
 bd_feed(s,s+500,{bad});assert(gBookDecisionFaultReason=="MALFORMED_OR_UNORDERED_TRADE_BATCH");
 std::cout<<"changed prefix, uncovered interval, ordering, time identity, exact-volume capacity, ambiguous flags, saturated ms and API error fail closed\n";
}
void bounded(){
 bd_init();long s=gBookDecisionStartMSC;
 for(int i=0;i<BOOK_DECISION_TAPE_CAP+20;i++)bd_provider.push_back(bd_tick(s+i));
 bd_now(s+BOOK_DECISION_TAPE_CAP+20);BookDecisionPump();
 assert(bd_max_requested==BOOK_DECISION_TAPE_CAP&&!gBookDecisionFault);
 assert(gBookDecisionAcquisitionIncomplete&&!BookDecisionSourceFresh());
 auto before=gBookDecisionTapeCount;bd_clock_local+=10;BookDecisionPump();
 assert(!gBookDecisionFault&&!gBookDecisionAcquisitionIncomplete);
 assert(gBookDecisionLastTradeMSC==s+BOOK_DECISION_TAPE_CAP+19);
 assert(gBookDecisionTapeCount==BOOK_DECISION_TAPE_CAP&&before==BOOK_DECISION_TAPE_CAP);
 assert(gBookDecisionTapeDrops==20);
 auto queries=bd_copy_calls;BookDecisionPump();
 assert(bd_copy_calls==queries&&gBookDecisionAcquisitionIncomplete);
 bd_clock_local+=10;BookDecisionPump();assert(!gBookDecisionAcquisitionIncomplete);
 std::cout<<"bounded 8192-row incremental catch-up, ten-ms query throttle and capacity accounting\n";
}
void warmup(){
 bd_init();long s=gBookDecisionStartMSC;
 std::vector<MqlTick> a;
 for(int w=0;w<16;w++)for(int j=0;j<10;j++)
  a.push_back(bd_tick(s+w*5000+j*500,100+w+j,10,1));
 bd_feed(s,s+16*5000,a);assert(!gBookDecisionFault);
 assert(gBookDecisionHistory.count==32);
 auto last=gBookDecisionClosed[(gBookDecisionClosedHead+gBookDecisionClosedCount-1)%BOOK_DECISION_WINDOW_CAP];
 assert(!last.buy_ranks.available&&last.buy_ranks.count==15);
 std::vector<MqlTick> b{a.back()};
 for(int j=0;j<10;j++)b.push_back(bd_tick(s+16*5000+j*500,116+j,10,1));
 bd_feed(a.back().time_msc,s+17*5000,b);assert(!gBookDecisionFault);
 last=gBookDecisionClosed[(gBookDecisionClosedHead+gBookDecisionClosedCount-1)%BOOK_DECISION_WINDOW_CAP];
 assert(last.buy_ranks.available&&last.buy_ranks.count==16&&last.buy_ranks.conditional_count==16);
 assert(gBookDecisionHistory.count==34);
 std::cout<<"actual regular-window warm-up: prior 15 insufficient, prior 16 available; compare before insert\n";
}
void proof(){
 bd_init();long s=gBookDecisionStartMSC;
 bd_feed(s,s+1000,{bd_tick(s),bd_tick(s+500),bd_tick(s+1000)});
 armed.active=true;armed.dir=1;armed.route="CONT";armed.mode="BASE_CONT";
 armed.regionEndTime=960;armed.armedAt=1000;armed.regionHigh=100;armed.regionLow=90;
 armed.activeSL_Pts=10;armed.activeTP_Pts=20;armed.breakoutEffortMin=1.5;
 BookDecisionBind();gBookDecisionResult=DECISION_VALIDAR;
 gBookDecisionProofGeneration=gBookDecisionSignalGeneration;
 gBookDecisionProofEpoch=gBookDecisionEpoch;gBookDecisionProofVersion=gBookDecisionDataVersion;
 gBookDecisionProofLocalMS=bd_clock_local;
 gBookDecisionProofSignalBar=iTime(Symbol(),Inp_SignalTF,0);
 gBookDecisionProofContextBar=iTime(Symbol(),Inp_ContextTF,0);
 gBookDecisionProofSignalSeconds=60;gBookDecisionProofContextSeconds=180;
 auto original=armed;assert(BookDecisionDispatchValid(original));
 bd_quote.bid+=1;bd_quote.ask+=1;assert(BookDecisionDispatchValid(original));
 armed.dir=-1;assert(!BookDecisionDispatchValid(original));armed=original;
 gBookDecisionDataVersion++;assert(!BookDecisionDispatchValid(original));gBookDecisionDataVersion--;
 bd_clock_local+=2001;assert(!BookDecisionDispatchValid(original));bd_clock_local-=2001;
 gBookDecisionProofSignalBar=bd_clock_sec-60;assert(!BookDecisionDispatchValid(original));
 gBookDecisionProofSignalBar=iTime(Symbol(),Inp_SignalTF,0);
 Inp_ArmedTimeoutSec=1;assert(!BookDecisionDispatchValid(original));Inp_ArmedTimeoutSec=90;
 Inp_StopEntryHHMM=0;assert(!BookDecisionDispatchValid(original));Inp_StopEntryHHMM=2359;
 BookDecisionResetSignal();assert(!BookDecisionDispatchValid(original));
 assert(armed.armedAt==1000&&armed.active);
 std::cout<<"proof identity/epoch/version/age/bar/timeout/session invalidation; BID/ASK alone not a cancellation\n";
}
void disabled(){
 bd_init();long s=gBookDecisionStartMSC;Inp_EnableArmedDiagnostics=false;Inp_ResponseMode=0;
 bd_feed(s,s+1000,{bd_tick(s),bd_tick(s+500),bd_tick(s+1000)});
 auto volume=gBookDecisionWindow.vb;assert(volume==30);
 MatrixSnapshot candidate;candidate.absValid=true;candidate.dir=1;
 assert(BookDecisionCandidate(candidate,1,false,960));
 auto result=gBookDecisionResult;Inp_EnableArmedDiagnostics=true;Inp_ResponseMode=1;
 assert(BookDecisionCandidate(candidate,1,false,960));assert(gBookDecisionResult==result);
 Inp_DecisionAggressorSource=DECISION_FLAGS_UNVERIFIED;assert(BookDecisionInit());
 s=gBookDecisionStartMSC;bd_feed(s,s+1000,{bd_tick(s),bd_tick(s+500),bd_tick(s+1000)});
 BookDecisionCandidate(candidate,1,false,960);assert(gBookDecisionResult!=DECISION_VALIDAR);
 Inp_DecisionMode=(ENUM_BOOK_DECISION_MODE)2;assert(!BookDecisionInit());
 assert(BookDecisionEvaluateArmed()!=DECISION_VALIDAR && !BookDecisionDispatchValid(armed));
 Inp_DecisionMode=DECISION_ORIGINAL;auto calls=bd_copy_calls;BookDecisionPump();
 assert(bd_copy_calls==calls&&BookDecisionCandidate(candidate,1,false,960));
 assert(BookDecisionEvaluateArmed()==DECISION_VALIDAR&&BookDecisionDispatchValid(armed));
 std::cout<<"CSV/observer/log switches do not control collection or verdict; ORIGINAL bypass and unverified feed guarded\n";
}
void reaction_capacity(){
 bd_init();long s=gBookDecisionStartMSC;
 std::vector<MqlTick> a;for(int i=0;i<5000;i++)a.push_back(bd_tick(s+i,100+i%4));
 bd_feed(s,s+5000,a);
 BookDecisionWindow test;BookDecisionWindowReset(test,s-5000,s-1,99,1,s-5001,99,true,1,0,gBookDecisionEpoch);
 BookDecisionWindow reaction;assert(BookDecisionReaction(test,reaction));
 auto scans=gBookDecisionReactionRows;assert(BookDecisionReaction(test,reaction));
 assert(gBookDecisionReactionRows==scans);
 std::vector<MqlTick> b{a.back()};for(int i=5000;i<10000;i++)b.push_back(bd_tick(s+i,100+i%4));
 bd_feed(a.back().time_msc,s+10000,b);assert(!gBookDecisionFault&&gBookDecisionTapeDrops>0);
 assert(!BookDecisionReaction(test,reaction));
 std::cout<<"reaction rebuilding cached by epoch/test/data version; overwritten needed prefix stays unavailable\n";
}
void bind_stream(int d,bool cont){
 MatrixSnapshot candidate;candidate.absValid=!cont;candidate.contValid=cont;
 candidate.dir=d;candidate.dirCont=d;
 assert(BookDecisionCandidate(candidate,d,cont,iTime(Symbol(),Inp_SignalTF,1)));
 armed.active=true;armed.dir=d;armed.route=cont?"CONT":"ABS";
 armed.mode=cont?"BASE_CONT":"BASE";
 armed.armedAt=TimeTradeServer();armed.regionEndTime=iTime(Symbol(),Inp_SignalTF,1);
 armed.regionHigh=135010;armed.regionLow=134990;armed.activeSL_Pts=10;
 armed.activeTP_Pts=20;armed.breakoutEffortMin=1.5;
 BookDecisionBind();
}
void stream_setup(int d,bool cont,double tick_size,bool dollar){
 bd_init(tick_size,dollar?"WDO_TEST":"WIN_TEST");
 Inp_EnableArmedDiagnostics=false;Inp_ResponseMode=0;
 long s=gBookDecisionStartMSC;double anchor=dollar?5500:135000;
 std::vector<MqlTick> tape;int pressure=cont?d:-d;
 // Sixteen regular comparable windows collected WITHOUT selected signals.
 for(int w=0;w<16;w++){
  for(int j=0;j<6;j++){
   long offset=j==5?4999:j*1000;
   tape.push_back(bd_tick(s+w*5000+offset,anchor+pressure*(2+.5*j)*tick_size,20,pressure));
  }
  anchor=tape.back().last;
 }
 // T: material doubled pressure with zero produced progress; CONT: progress,
 // acceptance and value migration, all before candidate selection.
 for(int j=0;j<6;j++){
  long offset=j==5?4999:j*1000;
  double price=cont?anchor+d*(2+2*j)*tick_size:anchor;
  tape.push_back(bd_tick(s+16*5000+offset,price,cont?20:40,pressure));
 }
 bd_feed(s,s+17*5000,tape);assert(!gBookDecisionFault);
 bind_stream(d,cont);
}
void stream_abs(){
 for(bool dollar:{false,true})for(int d:{-1,1}){
  double tick_size=dollar?.5:5;
  stream_setup(d,false,tick_size,dollar);
  assert(gBookDecisionHaveFrozenTest);
  long from=gBookDecisionFrozenTest.flow.to_msc+1;
  double level=gBookDecisionFrozenTest.flow.level;
  MqlTick tail=gBookDecisionTail[gBookDecisionTailCount-1];
  std::vector<MqlTick> reaction{tail};
  for(int i=0;i<4;i++)reaction.push_back(bd_tick(from+i*300,level+d*(2+2*i)*tick_size,20,-d));
  bd_feed(tail.time_msc,from+999,reaction);
  assert(BookDecisionEvaluateArmed()==DECISION_VALIDAR);
  assert(BookDecisionDispatchValid(armed));
  std::cout<<"STREAM ABS VALID "<<(dollar?"WDO":"WIN")<<" d="<<d
   <<" resistance="<<gBookDecisionVerdict.resistance<<" R_net_ticks="<<gBookDecisionVerdict.net_progress
   <<" accepted_volume="<<gBookDecisionVerdict.volume_acceptance<<" accepted_time="<<gBookDecisionVerdict.time_acceptance
   <<" refs="<<gBookDecisionVerdict.conditional_count<<" proof=1 observer=off logs=off\n";
  stream_setup(d,false,tick_size,dollar);
  from=gBookDecisionFrozenTest.flow.to_msc+1;level=gBookDecisionFrozenTest.flow.level;
  tail=gBookDecisionTail[gBookDecisionTailCount-1];reaction={tail};
  for(int i=0;i<4;i++)reaction.push_back(bd_tick(from+i*300,level-d*(2+2*i)*tick_size,20,-d));
  bd_feed(tail.time_msc,from+999,reaction);
  assert(BookDecisionEvaluateArmed()==DECISION_INVALIDAR_ARMED);
  assert(!BookDecisionDispatchValid(armed));
  std::cout<<"STREAM ABS BLOCK "<<(dollar?"WDO":"WIN")<<" d="<<d
   <<" entry_net_ticks="<<gBookDecisionVerdict.net_progress<<" pressure_share="<<gBookDecisionVerdict.pressure_share
   <<" reason="<<gBookDecisionReason<<" proof=0\n";
 }
}
void stream_cont(){
 for(bool dollar:{false,true})for(int d:{-1,1}){
  double tick_size=dollar?.5:5;stream_setup(d,true,tick_size,dollar);
  assert(BookDecisionEvaluateArmed()==DECISION_VALIDAR);
  assert(BookDecisionDispatchValid(armed));
  std::cout<<"STREAM CONT VALID "<<(dollar?"WDO":"WIN")<<" d="<<d
   <<" net_ticks="<<gBookDecisionVerdict.net_progress<<" accepted_volume="<<gBookDecisionVerdict.volume_acceptance
   <<" accepted_time="<<gBookDecisionVerdict.time_acceptance<<" refs="<<gBookDecisionVerdict.conditional_count
   <<" proof=1 observer=off logs=off no_extra_wait\n";
  long from=gBookDecisionWindow.flow.from_msc;
  MqlTick tail=gBookDecisionTail[gBookDecisionTailCount-1];double last=tail.last;
  std::vector<MqlTick> pause{tail,bd_tick(from,last-d*.25*tick_size,20,d),
    bd_tick(from+500,last-d*.5*tick_size,20,-d)};
  bd_feed(tail.time_msc,from+500,pause);
  assert(BookDecisionEvaluateArmed()==DECISION_AGUARDAR&&!BookDecisionDispatchValid(armed));
  assert(armed.active && gBookDecisionReason=="CONT_NORMAL_PAUSE_WITHOUT_CURRENT_PROGRESS");
  std::cout<<"STREAM CONT PAUSE preserved d="<<d<<" signed_net=-0.25tick bilateral_delta=0 waits_without_cancelling=1\n";
  stream_setup(d,true,tick_size,dollar);
  from=gBookDecisionWindow.flow.from_msc;tail=gBookDecisionTail[gBookDecisionTailCount-1];last=tail.last;
  std::vector<MqlTick> rejection{tail};
  for(int i=0;i<4;i++)rejection.push_back(bd_tick(from+i*300,last-d*(2+4.5*i)*tick_size,20,-d));
  bd_feed(tail.time_msc,from+999,rejection);
  assert(BookDecisionEvaluateArmed()==DECISION_INVALIDAR_ARMED);
  assert(!BookDecisionDispatchValid(armed));
  std::cout<<"STREAM CONT BLOCK "<<(dollar?"WDO":"WIN")<<" d="<<d
   <<" entry_net_ticks="<<gBookDecisionVerdict.net_progress<<" pressure_share="<<gBookDecisionVerdict.pressure_share
   <<" reason="<<gBookDecisionReason<<" proof=0\n";
 }
}
int main(int argc,char **argv){assert(argc==2);string c=argv[1];
 if(c=="same_ms")same_ms();else if(c=="faults")faults();else if(c=="bounded")bounded();
 else if(c=="warmup")warmup();else if(c=="proof")proof();else if(c=="disabled")disabled();
 else if(c=="reaction_capacity")reaction_capacity();else if(c=="stream_abs")stream_abs();
 else if(c=="stream_cont")stream_cont();else return 3;
}
'''


class DecisionRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="decision-runtime-")
        source = Path(cls.temporary.name) / "runtime.cpp"
        cls.binary = source.with_suffix("")
        source.write_text(CASES)
        built = subprocess.run(["g++", "-std=c++17", "-O2", "-Wall", "-Wextra", "-Werror",
                                "-I", str(ROOT / "tests"), str(source), "-o", str(cls.binary)],
                               capture_output=True, text=True)
        if built.returncode:
            raise AssertionError(built.stderr)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def run_case(self, name):
        completed = subprocess.run([str(self.binary), name], capture_output=True, text=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        print("DECISION_RUNTIME " + completed.stdout.strip())

    def test_overlapping_queries_and_identical_same_ms_trades(self):
        self.run_case("same_ms")

    def test_quality_gaps_prefix_order_flags_capacity_and_api_failure(self):
        self.run_case("faults")

    def test_bounded_incremental_catchup_and_resource_accounting(self):
        self.run_case("bounded")

    def test_actual_regular_window_warmup_terminates(self):
        self.run_case("warmup")

    def test_final_proof_identity_freshness_and_original_clocks(self):
        self.run_case("proof")

    def test_observer_csv_logs_independent_and_original_bypass(self):
        self.run_case("disabled")

    def test_reaction_cache_and_saturated_required_history(self):
        self.run_case("reaction_capacity")

    def test_actual_trade_stream_to_abs_verdict_and_proof_win_wdo_both_directions(self):
        self.run_case("stream_abs")

    def test_actual_trade_stream_to_cont_verdict_pause_rejection_win_wdo_both_directions(self):
        self.run_case("stream_cont")


if __name__ == "__main__":
    unittest.main(verbosity=2)
