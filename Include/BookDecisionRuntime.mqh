#ifndef BOOK_DECISION_RUNTIME_MQH
#define BOOK_DECISION_RUNTIME_MQH
#include "BookDecisionCore.mqh"
#ifdef __cplusplus
#include <vector>
#endif

// Operational data, never an observer/CSV queue. Integer trade volume and
// provider BUY/SELL flags are the explicitly selected source. Every tick in an
// inclusive timestamp group has an ordinal, including byte-identical trades.
#define BOOK_DECISION_TAPE_CAP 8192
#define BOOK_DECISION_WINDOW_CAP 16
#define BOOK_DECISION_SOURCE_AGE_MS 2000
#define BOOK_DECISION_PROOF_AGE_MS 2000
#define BOOK_DECISION_MIN_POLL_MS 10
struct BookDecisionClosedWindow
{
   BookDecisionWindow window;
   BookDecisionRanks buy_ranks,sell_ranks;
};
BookDecisionConfig gBookDecisionConfig;
BookDecisionHistory gBookDecisionHistory;
BookDecisionWindow gBookDecisionWindow;
BookDecisionClosedWindow gBookDecisionClosed[BOOK_DECISION_WINDOW_CAP];
MqlTick gBookDecisionTape[BOOK_DECISION_TAPE_CAP];
MqlTick gBookDecisionTail[BOOK_DECISION_TAPE_CAP];
int gBookDecisionTapeHead=0,gBookDecisionTapeCount=0;
int gBookDecisionClosedHead=0,gBookDecisionClosedCount=0,gBookDecisionTailCount=0;
long gBookDecisionStartMSC=0,gBookDecisionCoveredMSC=0,gBookDecisionCursorMSC=0;
long gBookDecisionTapeFromMSC=0,gBookDecisionLastTradeMSC=0,gBookDecisionFaultMSC=0;
long gBookDecisionEpoch=0,gBookDecisionDataVersion=0,gBookDecisionSignalGeneration=0;
bool gBookDecisionReady=false,gBookDecisionFault=false;
bool gBookDecisionAcquisitionIncomplete=false;
string gBookDecisionSymbol="",gBookDecisionFaultReason="";
ENUM_BOOK_DECISION_RESULT gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;
string gBookDecisionReason="NOT_INITIALIZED";
BookDecisionVerdict gBookDecisionVerdict;
ArmedSignal gBookDecisionBound;
bool gBookDecisionBoundActive=false,gBookDecisionHaveFrozenTest=false;
BookDecisionWindow gBookDecisionFrozenTest;
BookDecisionRanks gBookDecisionFrozenTestRanks;
int gBookDecisionSubtype=0,gBookDecisionCandidateSubtype=0;
long gBookDecisionBoundEpoch=0,gBookDecisionProofGeneration=0,gBookDecisionProofEpoch=0;
long gBookDecisionProofVersion=0;
ulong gBookDecisionProofLocalMS=0;
datetime gBookDecisionProofSignalBar=0,gBookDecisionProofContextBar=0;
int gBookDecisionProofSignalSeconds=0,gBookDecisionProofContextSeconds=0;
ulong gBookDecisionLastPollLocalMS=0;
BookDecisionWindow gBookDecisionReactionCache;
bool gBookDecisionReactionCached=false,gBookDecisionReactionAvailable=false;
long gBookDecisionReactionTestTo=0,gBookDecisionReactionEpoch=0,gBookDecisionReactionVersion=0;
ENUM_BOOK_DECISION_RESULT gBookDecisionLastLogResult=DECISION_DADOS_INSUFICIENTES;
string gBookDecisionLastLogReason="";
ulong gBookDecisionLastLogMS=0;
ulong gBookDecisionIngestCalls=0,gBookDecisionIngestUS=0,gBookDecisionIngestMaxUS=0;
ulong gBookDecisionCoreCalls=0,gBookDecisionCoreUS=0,gBookDecisionCoreMaxUS=0;
ulong gBookDecisionPollCalls=0,gBookDecisionPollUS=0,gBookDecisionPollMaxUS=0;
ulong gBookDecisionTapeDrops=0,gBookDecisionBorrowedOversize=0,gBookDecisionDataErrors=0;
ulong gBookDecisionReactionRebuilds=0,gBookDecisionReactionRows=0;

void BookDecisionConfigure()
{
   BookDecisionConfigDefaults(gBookDecisionConfig);
   gBookDecisionConfig.source=(int)Inp_DecisionAggressorSource;
   gBookDecisionConfig.window_sec=Inp_DecisionWindowSec;
   gBookDecisionConfig.min_refs=Inp_DecisionMinReferences;
   gBookDecisionConfig.effort_q=Inp_DecisionEffortQuantile;
   gBookDecisionConfig.result_q=Inp_DecisionResultQuantile;
   gBookDecisionConfig.coverage=Inp_DecisionMinCoverage;
   gBookDecisionConfig.directional_share=Inp_DecisionMinDirectionalShare;
   gBookDecisionConfig.acceptance=Inp_DecisionMinAcceptance;
   gBookDecisionConfig.observed_coverage=Inp_DecisionMinObservedCoverage;
   gBookDecisionConfig.progress_ticks=Inp_DecisionMinProgressTicks;
   gBookDecisionConfig.effort_factor=Inp_DecisionComparableEffortFactor;
   gBookDecisionConfig.tick_size=gTickSize;
}
void BookDecisionAccountCost(const ulong began,const int kind)
{
   ulong elapsed=GetMicrosecondCount()-began;
   if(kind==0)
   { gBookDecisionIngestCalls++; gBookDecisionIngestUS+=elapsed;
     if(elapsed>gBookDecisionIngestMaxUS) gBookDecisionIngestMaxUS=elapsed; }
   else if(kind==1)
   { gBookDecisionCoreCalls++; gBookDecisionCoreUS+=elapsed;
     if(elapsed>gBookDecisionCoreMaxUS) gBookDecisionCoreMaxUS=elapsed; }
   else
   { gBookDecisionPollCalls++; gBookDecisionPollUS+=elapsed;
     if(elapsed>gBookDecisionPollMaxUS) gBookDecisionPollMaxUS=elapsed; }
}
void BookDecisionReport()
{
   if(!Inp_EnableArmedDiagnostics) return;
   if(gBookDecisionResult==gBookDecisionLastLogResult &&
      gBookDecisionReason==gBookDecisionLastLogReason) return;
   ulong now=GetTickCount64();
   if(gBookDecisionLastLogMS>0 && now-gBookDecisionLastLogMS<1000) return;
   PrintFormat("[BOOK_DECISION] result=%d reason=%s symbol=%s route=%s dir=%d bar=%I64d armed=%I64d generation=%I64d epoch=%I64d refs=%d; experimental thresholds",
      (int)gBookDecisionResult,gBookDecisionReason,gBookDecisionSymbol,
      armed.route,armed.dir,(long)armed.regionEndTime,(long)armed.armedAt,
      gBookDecisionSignalGeneration,gBookDecisionEpoch,gBookDecisionVerdict.conditional_count);
   gBookDecisionLastLogResult=gBookDecisionResult;
   gBookDecisionLastLogReason=gBookDecisionReason; gBookDecisionLastLogMS=now;
}
void BookDecisionResetSignal()
{
   gBookDecisionSignalGeneration++;
   gBookDecisionBoundActive=false; gBookDecisionHaveFrozenTest=false;
   gBookDecisionProofGeneration=0; gBookDecisionProofEpoch=0;
   gBookDecisionProofVersion=0; gBookDecisionProofLocalMS=0;
   gBookDecisionProofSignalBar=0; gBookDecisionProofContextBar=0;
   gBookDecisionReactionCached=false;
   gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;
   gBookDecisionReason="NO_BOUND_SIGNAL";
}
bool BookDecisionIdentityCurrent(const ArmedSignal &original)
{
   return gBookDecisionBoundActive && armed.active && original.active &&
      armed.dir==original.dir && armed.route==original.route && armed.mode==original.mode &&
      armed.armedAt==original.armedAt && armed.regionEndTime==original.regionEndTime &&
      armed.regionHigh==original.regionHigh && armed.regionLow==original.regionLow &&
      armed.activeSL_Pts==original.activeSL_Pts && armed.activeTP_Pts==original.activeTP_Pts &&
      armed.breakoutEffortMin==original.breakoutEffortMin &&
      original.dir==gBookDecisionBound.dir && original.route==gBookDecisionBound.route &&
      original.mode==gBookDecisionBound.mode && original.armedAt==gBookDecisionBound.armedAt &&
      original.regionEndTime==gBookDecisionBound.regionEndTime &&
      original.regionHigh==gBookDecisionBound.regionHigh &&
      original.regionLow==gBookDecisionBound.regionLow &&
      original.activeSL_Pts==gBookDecisionBound.activeSL_Pts &&
      original.activeTP_Pts==gBookDecisionBound.activeTP_Pts &&
      original.breakoutEffortMin==gBookDecisionBound.breakoutEffortMin;
}
int BookDecisionBucket(const long from_msc)
{ return (int)((from_msc/1800000)%48); }
void BookDecisionOpenWindow(const long from_msc,const double level,const long reference_msc,
                            const double previous_vwap,const bool previous_available)
{
   long duration=(long)gBookDecisionConfig.window_sec*1000;
   BookDecisionWindowReset(gBookDecisionWindow,from_msc,from_msc+duration-1,
      level,gBookDecisionConfig.tick_size,reference_msc,previous_vwap,previous_available,
      gBookDecisionConfig.source,BookDecisionBucket(from_msc),gBookDecisionEpoch);
   gBookDecisionWindow.source_ok=true;
}
void BookDecisionDataReset(const long now_msc)
{
   gBookDecisionEpoch++; gBookDecisionDataVersion++;
   BookDecisionHistoryReset(gBookDecisionHistory);
   gBookDecisionTapeHead=0; gBookDecisionTapeCount=0;
   gBookDecisionClosedHead=0; gBookDecisionClosedCount=0;
   gBookDecisionTailCount=0; gBookDecisionCursorMSC=0;
   long duration=(long)gBookDecisionConfig.window_sec*1000;
   gBookDecisionStartMSC=(now_msc/duration)*duration;
   gBookDecisionCoveredMSC=gBookDecisionStartMSC-1;
   gBookDecisionTapeFromMSC=gBookDecisionStartMSC;
   gBookDecisionLastTradeMSC=0;
   gBookDecisionFault=false; gBookDecisionFaultReason="";
   gBookDecisionAcquisitionIncomplete=false;
   gBookDecisionReactionCached=false; gBookDecisionLastPollLocalMS=0;
   gBookDecisionHaveFrozenTest=false;
   gBookDecisionProofGeneration=0; gBookDecisionProofEpoch=0;
   BookDecisionOpenWindow(gBookDecisionStartMSC,0,0,0,false);
}
void BookDecisionDataFailure(const string reason)
{
   gBookDecisionFault=true; gBookDecisionFaultReason=reason;
   gBookDecisionFaultMSC=gBookDecisionCoveredMSC;
   gBookDecisionDataErrors++; gBookDecisionDataVersion++;
   gBookDecisionProofGeneration=0; gBookDecisionProofEpoch=0;
   gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;
   gBookDecisionReason=reason; BookDecisionReport();
}
bool BookDecisionInit()
{
   BookDecisionResetSignal(); BookDecisionConfigure();
   gBookDecisionSymbol=Symbol();
   gBookDecisionReady=false;
   if(Inp_DecisionMode==DECISION_ORIGINAL) return true;
   if(Inp_DecisionMode!=DECISION_APLICAR)
   { gBookDecisionReason="INVALID_DECISION_MODE"; BookDecisionReport(); return false; }
   if(!BookDecisionConfigValid(gBookDecisionConfig))
   { gBookDecisionReason="INVALID_DECISION_CONFIGURATION"; BookDecisionReport(); return false; }
   BookDecisionDataReset((long)TimeTradeServer()*1000);
   gBookDecisionReady=true;
   PrintFormat("[BOOK_DECISION][CONFIG] mode=APLICAR source=%d volume=MqlTick.volume window_sec=%d min_refs=%d P_effort=%.3f P_result=%.3f coverage=%.3f directional_share=%.3f acceptance_volume_and_time=%.3f observed_coverage=%.3f progress_ticks=%.3f effort_factor=%.3f; feed setting is an assumption, not provider validation; source 0 blocks entries",
      gBookDecisionConfig.source,gBookDecisionConfig.window_sec,gBookDecisionConfig.min_refs,
      gBookDecisionConfig.effort_q,gBookDecisionConfig.result_q,gBookDecisionConfig.coverage,
      gBookDecisionConfig.directional_share,gBookDecisionConfig.acceptance,
      gBookDecisionConfig.observed_coverage,gBookDecisionConfig.progress_ticks,
      gBookDecisionConfig.effort_factor);
   return true;
}
void BookDecisionCloseCurrent()
{
   gBookDecisionWindow.complete=true;
   BookDecisionClosedWindow closed;
   closed.window=gBookDecisionWindow;
   // Compare BOTH directions against strictly prior windows, BEFORE insertion.
   BookDecisionCompare(gBookDecisionConfig,gBookDecisionHistory,closed.window,1,closed.buy_ranks);
   BookDecisionCompare(gBookDecisionConfig,gBookDecisionHistory,closed.window,-1,closed.sell_ranks);
   int slot=(gBookDecisionClosedHead+gBookDecisionClosedCount)%BOOK_DECISION_WINDOW_CAP;
   if(gBookDecisionClosedCount==BOOK_DECISION_WINDOW_CAP)
   { slot=gBookDecisionClosedHead; gBookDecisionClosedHead=(gBookDecisionClosedHead+1)%BOOK_DECISION_WINDOW_CAP; }
   else gBookDecisionClosedCount++;
   gBookDecisionClosed[slot]=closed;
   BookDecisionHistoryInsert(gBookDecisionConfig,gBookDecisionHistory,closed.window);
   double level=closed.window.flow.count>0?closed.window.flow.last:0;
   long reference=closed.window.flow.last_msc;
   double volume=closed.window.vb+closed.window.vs+closed.window.vu;
   double previous_vwap=volume>0?closed.window.pv/volume:0;
   BookDecisionOpenWindow(closed.window.flow.to_msc+1,level,reference,
      previous_vwap,closed.window.flow.count>0 && volume>0);
}
bool BookDecisionAdvanceWindows(const long known_through_msc)
{
   int count=0;
   // The current timestamp group remains appendable. Close only strictly older
   // windows; their complete inclusive batches cannot acquire another ordinal.
   while(known_through_msc>gBookDecisionWindow.flow.to_msc)
   {
      if(++count>BOOK_DECISION_WINDOW_CAP*4)
      { BookDecisionDataFailure("REGULAR_WINDOW_GAP"); return false; }
      BookDecisionCloseCurrent();
   }
   return true;
}
bool BookDecisionSameTick(const MqlTick &a,const MqlTick &b)
{
   return a.time==b.time && a.time_msc==b.time_msc && a.bid==b.bid && a.ask==b.ask &&
      a.last==b.last && a.volume==b.volume && a.volume_real==b.volume_real && a.flags==b.flags;
}
void BookDecisionAppendTrade(const MqlTick &tick)
{
   int slot=(gBookDecisionTapeHead+gBookDecisionTapeCount)%BOOK_DECISION_TAPE_CAP;
   if(gBookDecisionTapeCount==BOOK_DECISION_TAPE_CAP)
   {
      slot=gBookDecisionTapeHead;
      long lost=gBookDecisionTape[slot].time_msc;
      if(lost+1>gBookDecisionTapeFromMSC) gBookDecisionTapeFromMSC=lost+1;
      gBookDecisionTapeHead=(gBookDecisionTapeHead+1)%BOOK_DECISION_TAPE_CAP;
      gBookDecisionTapeDrops++;
   }
   else gBookDecisionTapeCount++;
   gBookDecisionTape[slot]=tick;
   int aggressor=0;
   bool buy=(tick.flags&TICK_FLAG_BUY)!=0,sell=(tick.flags&TICK_FLAG_SELL)!=0;
   if(buy && sell) aggressor=2; else if(buy) aggressor=1; else if(sell) aggressor=-1;
   BookDecisionWindowTick(gBookDecisionWindow,tick.last,(double)tick.volume,tick.time_msc,aggressor);
   gBookDecisionLastTradeMSC=tick.time_msc; gBookDecisionDataVersion++;
}
#ifdef __cplusplus
void BookDecisionIngestBatch(ulong from_msc,ulong to_msc,const MqlTick ticks[],int copied)
#else
void BookDecisionIngestBatch(ulong from_msc,ulong to_msc,const MqlTick &ticks[],int copied)
#endif
{
   if(Inp_DecisionMode==DECISION_ORIGINAL || !gBookDecisionReady || gBookDecisionFault) return;
   ulong began=GetMicrosecondCount();
   if(to_msc<(ulong)gBookDecisionStartMSC || to_msc<(ulong)gBookDecisionCoveredMSC)
   { BookDecisionAccountCost(began,0); return; }
   // Borrowed full-day/M1 arrays are never rescanned without a bound. The own
   // incremental cursor fills only the missing suffix, with at most 8192 rows.
   if(copied>BOOK_DECISION_TAPE_CAP)
   { gBookDecisionBorrowedOversize++; BookDecisionAccountCost(began,0); return; }
   if(copied<0 || to_msc<from_msc || Symbol()!=gBookDecisionSymbol ||
      (long)to_msc>(long)TimeTradeServer()*1000+1000)
   { BookDecisionDataFailure("INVALID_BATCH_OR_SYMBOL"); BookDecisionAccountCost(began,0); return; }
   if(from_msc>(ulong)(gBookDecisionCoveredMSC+1))
   { BookDecisionDataFailure("UNCOVERED_BATCH_INTERVAL"); BookDecisionAccountCost(began,0); return; }
   long previous=-1;
   int tail_seen=0;
   // Validate the entire bounded batch before mutating any accumulator.
   for(int i=0;i<copied;i++)
   {
      const MqlTick tick=ticks[i];
      if(tick.time_msc<(long)from_msc || tick.time_msc>(long)to_msc ||
         tick.time_msc<previous || tick.time!=(datetime)(tick.time_msc/1000) ||
         !BookMicroFinite(tick.last) || tick.last<=0 || tick.volume==0 ||
         tick.volume>9007199254740992 || !BookMicroFinite(tick.volume_real) || tick.volume_real<0 ||
         ((tick.flags&(TICK_FLAG_LAST|TICK_FLAG_VOLUME|TICK_FLAG_BUY|TICK_FLAG_SELL))==0))
      { BookDecisionDataFailure("MALFORMED_OR_UNORDERED_TRADE_BATCH"); BookDecisionAccountCost(began,0); return; }
      previous=tick.time_msc;
      if(tick.time_msc==gBookDecisionCursorMSC)
      {
         if(tail_seen<gBookDecisionTailCount &&
            !BookDecisionSameTick(tick,gBookDecisionTail[tail_seen]))
         { BookDecisionDataFailure("OVERLAP_PREFIX_CHANGED"); BookDecisionAccountCost(began,0); return; }
         tail_seen++;
      }
   }
   if(gBookDecisionTailCount>0 && from_msc<=(ulong)gBookDecisionCursorMSC &&
      to_msc>=(ulong)gBookDecisionCursorMSC && tail_seen<gBookDecisionTailCount)
   { BookDecisionDataFailure("OVERLAP_PREFIX_INCOMPLETE"); BookDecisionAccountCost(began,0); return; }
   int ordinal=0;
   long observed_msc=-1;
   for(int i=0;i<copied;i++)
   {
      const MqlTick tick=ticks[i];
      if(tick.time_msc<gBookDecisionStartMSC || tick.time_msc<gBookDecisionCursorMSC) continue;
      if(observed_msc!=tick.time_msc) { observed_msc=tick.time_msc; ordinal=0; }
      ordinal++;
      if(tick.time_msc==gBookDecisionCursorMSC && ordinal<=gBookDecisionTailCount) continue;
      if(tick.time_msc<gBookDecisionCoveredMSC ||
         tick.time_msc<gBookDecisionWindow.flow.from_msc)
      { BookDecisionDataFailure("LATE_TRADE_BEHIND_WATERMARK"); break; }
      if(!BookDecisionAdvanceWindows(tick.time_msc)) break;
      if(tick.time_msc!=gBookDecisionCursorMSC)
      { gBookDecisionCursorMSC=tick.time_msc; gBookDecisionTailCount=0; }
      if(gBookDecisionTailCount>=BOOK_DECISION_TAPE_CAP)
      { BookDecisionDataFailure("TIMESTAMP_ORDINAL_CAPACITY"); break; }
      gBookDecisionTail[gBookDecisionTailCount++]=tick;
      BookDecisionAppendTrade(tick);
   }
   if(!gBookDecisionFault)
   {
      if((long)to_msc>gBookDecisionCoveredMSC)
      { gBookDecisionCoveredMSC=(long)to_msc; gBookDecisionDataVersion++; }
      BookDecisionAdvanceWindows(gBookDecisionCoveredMSC);
      gBookDecisionAcquisitionIncomplete=false;
   }
   BookDecisionAccountCost(began,0);
}
void BookDecisionPump()
{
   if(Inp_DecisionMode==DECISION_ORIGINAL || !gBookDecisionReady) return;
   MqlTick quote;
   if(!SymbolInfoTick(Symbol(),quote) || quote.time_msc<=0)
   { BookDecisionDataFailure("MARKET_CLOCK_UNAVAILABLE"); return; }
   long goal=quote.time_msc;
   if(gBookDecisionFault)
   {
      if(goal<=gBookDecisionFaultMSC+(long)gBookDecisionConfig.window_sec*1000) return;
      // Lost continuity never reuses old references/approvals. Bounded recovery
      // starts a new epoch and must warm the same causal history again.
      BookDecisionDataReset(goal);
   }
   ulong local_now=GetTickCount64();
   if(gBookDecisionLastPollLocalMS>0 && local_now>=gBookDecisionLastPollLocalMS &&
      local_now-gBookDecisionLastPollLocalMS<BOOK_DECISION_MIN_POLL_MS)
   {
      // A skipped acquisition is not evidence of one trade per OnTick. Keep the
      // ARMED clocks but do not authorize an unknown append at the same ms.
      gBookDecisionAcquisitionIncomplete=true; return;
   }
   gBookDecisionLastPollLocalMS=local_now;
   long from=gBookDecisionCursorMSC>0?gBookDecisionCursorMSC:gBookDecisionStartMSC;
   if(goal<from) { BookDecisionDataFailure("MARKET_CLOCK_REVERSED"); return; }
   ulong began=GetMicrosecondCount();
#ifdef __cplusplus
   std::vector<MqlTick> ticks;
#else
   MqlTick ticks[];
#endif
   ResetLastError();
   int copied=CopyTicks(Symbol(),ticks,COPY_TICKS_TRADE,(ulong)from,BOOK_DECISION_TAPE_CAP);
   int error=GetLastError();
   if(copied<0 || error!=0)
      BookDecisionDataFailure("INCREMENTAL_TRADE_COPY_FAILED");
   else
   {
      long through=goal;
      if(copied>0)
      {
         long last=ticks[copied-1].time_msc;
         if(copied==BOOK_DECISION_TAPE_CAP) through=last;
         else if(last>through) through=last;
         if(copied==BOOK_DECISION_TAPE_CAP && last==from)
            BookDecisionDataFailure("TIMESTAMP_ORDINAL_CAPACITY");
      }
      if(!gBookDecisionFault)
      {
#ifdef __cplusplus
         BookDecisionIngestBatch((ulong)from,(ulong)through,ticks.data(),copied);
#else
         BookDecisionIngestBatch((ulong)from,(ulong)through,ticks,copied);
#endif
         // A full bounded CopyTicks result does not prove its suffix complete.
         // The next incremental query must catch up before any authorization.
         if(copied==BOOK_DECISION_TAPE_CAP) gBookDecisionAcquisitionIncomplete=true;
      }
   }
   ArrayFree(ticks);
   BookDecisionAccountCost(began,2);
}
bool BookDecisionSourceFresh()
{
   if(!gBookDecisionReady || gBookDecisionFault || gBookDecisionAcquisitionIncomplete || gBookDecisionLastTradeMSC<=0 ||
      Symbol()!=gBookDecisionSymbol) return false;
   long now=(long)TimeTradeServer()*1000;
   return now-gBookDecisionLastTradeMSC<=BOOK_DECISION_SOURCE_AGE_MS &&
      gBookDecisionLastTradeMSC-now<=1000 &&
      now-gBookDecisionCoveredMSC<=BOOK_DECISION_SOURCE_AGE_MS;
}
bool BookDecisionReaction(const BookDecisionWindow &test,BookDecisionWindow &reaction)
{
   if(gBookDecisionReactionCached && gBookDecisionReactionTestTo==test.flow.to_msc &&
      gBookDecisionReactionEpoch==gBookDecisionEpoch &&
      gBookDecisionReactionVersion==gBookDecisionDataVersion)
   { reaction=gBookDecisionReactionCache; return gBookDecisionReactionAvailable; }
   gBookDecisionReactionCached=true;
   gBookDecisionReactionTestTo=test.flow.to_msc;
   gBookDecisionReactionEpoch=gBookDecisionEpoch;
   gBookDecisionReactionVersion=gBookDecisionDataVersion;
   gBookDecisionReactionAvailable=false; gBookDecisionReactionRebuilds++;
   long from=test.flow.to_msc+1,to=gBookDecisionCoveredMSC;
   if(from>to || from<gBookDecisionTapeFromMSC ||
      to-test.flow.to_msc>(long)gBookDecisionConfig.window_sec*2000) return false;
   BookDecisionWindowReset(reaction,from,to,test.flow.level,gBookDecisionConfig.tick_size,
      test.flow.to_msc,test.previous_vwap,test.previous_available,
      gBookDecisionConfig.source,test.bucket,gBookDecisionEpoch);
   reaction.source_ok=true;
   for(int i=0;i<gBookDecisionTapeCount;i++)
   {
      MqlTick tick=gBookDecisionTape[(gBookDecisionTapeHead+i)%BOOK_DECISION_TAPE_CAP];
      gBookDecisionReactionRows++;
      if(tick.time_msc<from || tick.time_msc>to) continue;
      int direction=0;
      bool buy=(tick.flags&TICK_FLAG_BUY)!=0,sell=(tick.flags&TICK_FLAG_SELL)!=0;
      if(buy && sell) direction=2; else if(buy) direction=1; else if(sell) direction=-1;
      BookDecisionWindowTick(reaction,tick.last,(double)tick.volume,tick.time_msc,direction);
   }
   reaction.complete=true; // complete KNOWN prefix, not a completed future window
   gBookDecisionReactionCache=reaction;
   gBookDecisionReactionAvailable=reaction.flow.count>0;
   return gBookDecisionReactionAvailable;
}
void BookDecisionEvidenceFor(const int direction,const bool cont,const bool bound,
                            BookDecisionEvidence &evidence)
{
   ZeroMemory(evidence);
   evidence.now_msc=gBookDecisionCoveredMSC;
   evidence.original_subtype=bound?gBookDecisionSubtype:gBookDecisionCandidateSubtype;
   long max_age=(long)gBookDecisionConfig.window_sec*2000;
   for(int i=gBookDecisionClosedCount-1;i>=0;i--)
   {
      BookDecisionClosedWindow closed=gBookDecisionClosed[(gBookDecisionClosedHead+i)%BOOK_DECISION_WINDOW_CAP];
      if(gBookDecisionCoveredMSC-closed.window.flow.to_msc>max_age) break;
      BookDecisionRanks forward,reverse;
      if(direction==1) { forward=closed.buy_ranks; reverse=closed.sell_ranks; }
      else { forward=closed.sell_ranks; reverse=closed.buy_ranks; }
      if(!evidence.have_current)
      { evidence.have_current=true; evidence.current=closed.window; evidence.current_ranks=forward; }
      if(!evidence.have_forward && BookDecisionForwardPredicate(gBookDecisionConfig,closed.window,forward,direction))
      { evidence.have_forward=true; evidence.forward=closed.window; evidence.forward_ranks=forward; }
      if(!evidence.have_test && !cont &&
         BookDecisionTestPredicate(gBookDecisionConfig,closed.window,reverse,direction))
      { evidence.have_test=true; evidence.test=closed.window; evidence.test_ranks=reverse; }
   }
   if(bound && gBookDecisionHaveFrozenTest)
   {
      evidence.have_test=true; evidence.test=gBookDecisionFrozenTest;
      evidence.test_ranks=gBookDecisionFrozenTestRanks;
   }
   else if(bound && evidence.have_test)
   {
      gBookDecisionFrozenTest=evidence.test; gBookDecisionFrozenTestRanks=evidence.test_ranks;
      gBookDecisionHaveFrozenTest=true;
   }
   if(evidence.have_test)
      evidence.have_reaction=BookDecisionReaction(evidence.test,evidence.reaction);
   // A known live prefix can demonstrate rejection immediately; it need not
   // wait for another regular close. With fewer than two trades retain the
   // already completed evidence instead of manufacturing an observed interval.
   if(gBookDecisionWindow.flow.count>=2 &&
      gBookDecisionCoveredMSC>=gBookDecisionWindow.flow.from_msc)
   {
      evidence.have_current=true; evidence.current=gBookDecisionWindow;
      evidence.current.flow.to_msc=gBookDecisionCoveredMSC;
      evidence.current.complete=true;
      BookDecisionCompare(gBookDecisionConfig,gBookDecisionHistory,evidence.current,
         direction,evidence.current_ranks);
   }
}
void BookDecisionAssessCurrent(const int direction,const bool cont,const bool bound)
{
   ulong began=GetMicrosecondCount();
   if(!BookDecisionSourceFresh())
   {
      ZeroMemory(gBookDecisionVerdict);
      gBookDecisionVerdict.result=DECISION_DADOS_INSUFICIENTES;
      if(!gBookDecisionReady) gBookDecisionVerdict.reason="DECISION_COLLECTOR_NOT_READY";
      else if(gBookDecisionFault) gBookDecisionVerdict.reason=gBookDecisionFaultReason;
      else if(gBookDecisionAcquisitionIncomplete) gBookDecisionVerdict.reason="COLLECTION_BACKLOG_OR_THROTTLED";
      else gBookDecisionVerdict.reason="TRADED_DATA_STALE_OR_UNAVAILABLE";
   }
   else
   {
      BookDecisionEvidence evidence;
      BookDecisionEvidenceFor(direction,cont,bound,evidence);
      BookDecisionAssess(gBookDecisionConfig,evidence,direction,cont,bound,gBookDecisionVerdict);
   }
   gBookDecisionResult=gBookDecisionVerdict.result;
   gBookDecisionReason=gBookDecisionVerdict.reason;
   BookDecisionAccountCost(began,1);
}
bool BookDecisionCandidate(const MatrixSnapshot &snapshot,const int direction,
                           const bool cont,const datetime signal_bar)
{
   if(Inp_DecisionMode==DECISION_ORIGINAL) return true;
   gBookDecisionCandidateSubtype=snapshot.absDivergence?1:(snapshot.absFollowingReaction?2:0);
   bool eligible=snapshot.status==MSS_OK && !(snapshot.absValid && snapshot.contValid) &&
      (cont?snapshot.contValid:snapshot.absValid) && signal_bar>0 &&
      direction==(cont?snapshot.dirCont:snapshot.dir);
   if(!eligible)
   {
      gBookDecisionResult=DECISION_VETAR_CANDIDATO;
      gBookDecisionReason="ORIGINAL_CANDIDATE_INELIGIBLE"; BookDecisionReport(); return false;
   }
   BookDecisionAssessCurrent(direction,cont,false); BookDecisionReport();
   return gBookDecisionResult!=DECISION_VETAR_CANDIDATO &&
          gBookDecisionResult!=DECISION_INVALIDAR_ARMED;
}
void BookDecisionBind()
{
   if(Inp_DecisionMode==DECISION_ORIGINAL) return;
   gBookDecisionSignalGeneration++;
   gBookDecisionBound=armed; gBookDecisionBoundActive=armed.active;
   gBookDecisionBoundEpoch=gBookDecisionEpoch;
   gBookDecisionHaveFrozenTest=false; gBookDecisionSubtype=gBookDecisionCandidateSubtype;
   gBookDecisionProofGeneration=0;
   BookDecisionEvidence evidence;
   BookDecisionEvidenceFor(armed.dir,armed.route=="CONT",true,evidence);
}
ENUM_BOOK_DECISION_RESULT BookDecisionEvaluateArmed()
{
   if(Inp_DecisionMode==DECISION_ORIGINAL)
   { gBookDecisionResult=DECISION_VALIDAR; gBookDecisionReason="ORIGINAL_COMPATIBILITY"; return gBookDecisionResult; }
   gBookDecisionProofGeneration=0;
   if(!BookDecisionIdentityCurrent(gBookDecisionBound))
   {
      gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;
      gBookDecisionReason="ARMED_IDENTITY_NOT_BOUND"; BookDecisionReport(); return gBookDecisionResult;
   }
   if(gBookDecisionBoundEpoch!=gBookDecisionEpoch)
   {
      // A recovered collector may warm again, but cannot inherit its old T/R.
      gBookDecisionBoundEpoch=gBookDecisionEpoch; gBookDecisionHaveFrozenTest=false;
   }
   BookDecisionAssessCurrent(armed.dir,armed.route=="CONT",true);
   if(gBookDecisionResult==DECISION_VALIDAR)
   {
      gBookDecisionProofSignalBar=iTime(Symbol(),Inp_SignalTF,0);
      gBookDecisionProofContextBar=iTime(Symbol(),Inp_ContextTF,0);
      gBookDecisionProofSignalSeconds=PeriodSeconds(Inp_SignalTF);
      gBookDecisionProofContextSeconds=PeriodSeconds(Inp_ContextTF);
      datetime now=TimeTradeServer();
      if(gBookDecisionProofSignalBar<=0 || gBookDecisionProofContextBar<=0 ||
         gBookDecisionProofSignalSeconds<=0 || gBookDecisionProofContextSeconds<=0 ||
         now<gBookDecisionProofSignalBar || now<gBookDecisionProofContextBar ||
         now>=gBookDecisionProofSignalBar+gBookDecisionProofSignalSeconds ||
         now>=gBookDecisionProofContextBar+gBookDecisionProofContextSeconds)
      { gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;gBookDecisionReason="PROOF_BAR_CLOCK_UNAVAILABLE"; }
      else
      {
         gBookDecisionProofGeneration=gBookDecisionSignalGeneration;
         gBookDecisionProofEpoch=gBookDecisionEpoch;
         gBookDecisionProofVersion=gBookDecisionDataVersion;
         gBookDecisionProofLocalMS=GetTickCount64();
      }
   }
   BookDecisionReport(); return gBookDecisionResult;
}
bool BookDecisionDispatchValid(const ArmedSignal &original)
{
   if(Inp_DecisionMode==DECISION_ORIGINAL) return true;
   if(gBookDecisionResult!=DECISION_VALIDAR || !BookDecisionIdentityCurrent(original) ||
      gBookDecisionProofGeneration!=gBookDecisionSignalGeneration ||
      gBookDecisionProofEpoch!=gBookDecisionEpoch ||
      gBookDecisionProofVersion!=gBookDecisionDataVersion || !BookDecisionSourceFresh()) return false;
   datetime server_now=TimeTradeServer();
   if(original.armedAt<=0 || server_now<original.armedAt ||
      server_now-original.armedAt>=(datetime)Inp_ArmedTimeoutSec ||
      gBookDecisionProofSignalBar<=0 || gBookDecisionProofContextBar<=0 ||
      server_now<gBookDecisionProofSignalBar || server_now<gBookDecisionProofContextBar ||
      server_now>=gBookDecisionProofSignalBar+gBookDecisionProofSignalSeconds ||
      server_now>=gBookDecisionProofContextBar+gBookDecisionProofContextSeconds) return false;
   MqlDateTime clock; TimeToStruct(server_now,clock);
   int hhmm=clock.hour*100+clock.min;
   if(hhmm<Inp_StartHHMM || hhmm>=Inp_StopEntryHHMM) return false;
   ulong now=GetTickCount64();
   return now>=gBookDecisionProofLocalMS && now-gBookDecisionProofLocalMS<=BOOK_DECISION_PROOF_AGE_MS;
}
void BookDecisionDeinit()
{
   if(Inp_DecisionMode==DECISION_ORIGINAL) return;
   PrintFormat("[BOOK_DECISION][COST] core_calls=%I64u core_total_us=%I64u core_max_us=%I64u ingest_calls=%I64u ingest_total_us=%I64u ingest_max_us=%I64u incremental_queries=%I64u incremental_total_us=%I64u incremental_max_us=%I64u tape_drops=%I64u borrowed_oversize=%I64u data_errors=%I64u reaction_rebuilds=%I64u reaction_scanned_rows=%I64u process_memory_mb=%I64d; local measurements, not proven MT5 latency",
      gBookDecisionCoreCalls,gBookDecisionCoreUS,gBookDecisionCoreMaxUS,
      gBookDecisionIngestCalls,gBookDecisionIngestUS,gBookDecisionIngestMaxUS,
      gBookDecisionPollCalls,gBookDecisionPollUS,gBookDecisionPollMaxUS,
      gBookDecisionTapeDrops,gBookDecisionBorrowedOversize,gBookDecisionDataErrors,
      gBookDecisionReactionRebuilds,gBookDecisionReactionRows,
      MQLInfoInteger(MQL_MEMORY_USED));
}
#endif
