#ifndef BOOK_ARMED_DIAGNOSTICS_V1
#define BOOK_ARMED_DIAGNOSTICS_V1
#include "BookArmedMath.mqh"
// Diagnostics never return authorization, query depth/history or modify an order.
// Hook after existing predicates only. ALL excludes no original financial gate:
// OTHER denotes a named original gate; absence means NOT_EVALUATED, never PASS.
#define BOOK_DIAG_QUEUE_CAP 128
#define BOOK_DIAG_PENDING_CAP 8
#define BOOK_DIAG_DAILY_BYTES 16777216
#define BOOK_DIAG_CALLBACK_BUDGET_US 2000
struct BookArmedDiagnostic
{
   bool active,matrix_available,live_available,book_consulted;
   string id,route,mode,subtype,first_reason,last_reason,terminal;
   datetime signal_bar,armed_at;
   double high,low,margin,effort_min,live_effort,live_volume,live_average;
   int live_direction,book_state;
   double spread,overshoot,live_vwap,live_lower,live_upper,live_posrel;
   double bid_pct,ask_pct,sigma,vwap_d1,d1_high,d1_low;
   int sigma_days;
   ulong book_sequence;
   MatrixSnapshot matrix;
   BookArmedTrace trace;
};
struct BookArmedEvent
{
   string event,reason;
   long observed_msc;
   BookArmedDiagnostic state;
   ulong order,deal,position;
   uint request_id,retcode;
   double confirmed_volume,confirmed_entry;
};
struct BookArmedAwaiting
{
   bool used;
   uint request_id;
   ulong order,deal;
   BookArmedDiagnostic state;
};
BookArmedDiagnostic gBookDiagState;
BookArmedEvent gBookDiagQueue[BOOK_DIAG_QUEUE_CAP];
BookArmedAwaiting gBookDiagAwaiting[BOOK_DIAG_PENDING_CAP];
int gBookDiagHead=0,gBookDiagCount=0,gBookSigmaValidDays=0;
bool gBookDiagReady=false,gBookDiagSuspended=false,gBookDiagHealthPrinted=false;
ulong gBookDiagSequence=0,gBookDiagDropped=0,gBookDiagOverwrites=0,gBookDiagBytes=0;
ulong gBookDiagIOErrors=0,gBookDiagDeduplicated=0,gBookDiagTimerUS=0;
ulong gBookDiagHookCount=0,gBookDiagHookTotalUS=0,gBookDiagHookMaxUS=0;
string gBookDiagRun="",gBookDiagExecutionContext="",gBookDiagDay="",gBookDiagSuspension="";
int gBookDiagFile=INVALID_HANDLE;
long gBookDiagLastEventMSC=0;
string gBookDiagLastEvent="",gBookDiagLastReason="";
double gBookDiagLastSigma=-1,gBookDiagLastD1=-1,gBookDiagLastH1=-1,gBookDiagLastL1=-1;

bool BookDiagEnabled()
{ return Inp_EnableArmedDiagnostics && gBookDiagReady && !gBookDiagSuspended; }
void BookDiagAccountCost(ulong start)
{
   ulong elapsed=GetMicrosecondCount()-start;
   gBookDiagHookCount++; gBookDiagHookTotalUS+=elapsed;
   if(elapsed>gBookDiagHookMaxUS) gBookDiagHookMaxUS=elapsed;
   if(elapsed>BOOK_DIAG_CALLBACK_BUDGET_US)
   { gBookDiagSuspended=true; gBookDiagSuspension="CALLBACK_BUDGET"; }
}
void BookDiagEnqueue(BookArmedEvent &e,bool force=false)
{
   if(!BookDiagEnabled()) return;
   // Repeated holds: at most one row per second; transition/terminal rows bypass dedup.
   e.observed_msc=(long)TimeTradeServer()*1000;
   if(!force && e.event==gBookDiagLastEvent && e.reason==gBookDiagLastReason &&
      e.observed_msc-gBookDiagLastEventMSC<1000)
   { gBookDiagDeduplicated++; return; }
   if(gBookDiagCount>=BOOK_DIAG_QUEUE_CAP)
   {
      gBookDiagDropped++;
      gBookDiagSuspended=true; gBookDiagSuspension="QUEUE_CAPACITY"; return;
   }
   gBookDiagLastEvent=e.event; gBookDiagLastReason=e.reason;
   gBookDiagLastEventMSC=e.observed_msc;
   gBookDiagQueue[(gBookDiagHead+gBookDiagCount)%BOOK_DIAG_QUEUE_CAP]=e;
   gBookDiagCount++;
}
void BookDiagEmit(string event,string reason,bool force=false)
{
   BookArmedEvent e; ZeroMemory(e);
   e.event=event; e.reason=reason; e.state=gBookDiagState;
   BookDiagEnqueue(e,force);
}
string BookDiagSubtype(const MatrixSnapshot &s)
{
   if(s.absDivergence) return "DIVERGENCE";
   if(s.absStallStrict) return "STALL_STRICT";
   if(s.absFollowingReaction) return "FOLLOWING_REACTION";
   if(s.absFollowingExtension) return "FOLLOWING_EXTENSION";
   return "NONE";
}
void BookDiagSelected(const MatrixSnapshot &s,const ArmedSignal &a,double trigger)
{
   if(!BookDiagEnabled()) return;
   ulong begin=GetMicrosecondCount();
   if(gBookDiagState.active) BookDiagEmit("IDENTITY_REPLACED","ORIGINAL_REPLACEMENT",true);
   ZeroMemory(gBookDiagState);
   gBookDiagState.active=true;
   gBookDiagState.id=gBookDiagRun+"_"+(string)(++gBookDiagSequence);
   gBookDiagState.route=a.route; gBookDiagState.mode=a.mode;
   gBookDiagState.subtype=BookDiagSubtype(s);
   gBookDiagState.signal_bar=a.regionEndTime; gBookDiagState.armed_at=a.armedAt;
   gBookDiagState.high=a.regionHigh; gBookDiagState.low=a.regionLow;
   gBookDiagState.margin=gBreakoutMargin; gBookDiagState.effort_min=a.breakoutEffortMin;
   gBookDiagState.matrix=s; gBookDiagState.matrix_available=true;
   gBookDiagState.sigma=SigmaD1; gBookDiagState.sigma_days=gBookSigmaValidDays;
   gBookDiagState.vwap_d1=VWAP_D1; gBookDiagState.d1_high=H1; gBookDiagState.d1_low=L1;
   BookArmedResetTrace(gBookDiagState.trace,a.dir,(long)a.armedAt*1000,trigger);
   BookDiagEmit("ARMED","ORIGINAL_MATRIX_SELECTION",true);
   BookDiagAccountCost(begin);
}
void BookDiagBeginEvaluation()
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   BookArmedBeginEvaluation(gBookDiagState.trace);
   // Live/book values are unavailable until their original computations run.
   gBookDiagState.live_available=false; gBookDiagState.book_consulted=false;
   gBookDiagState.spread=EMPTY_VALUE; gBookDiagState.overshoot=EMPTY_VALUE;
   gBookDiagState.live_vwap=EMPTY_VALUE; gBookDiagState.live_lower=EMPTY_VALUE;
   gBookDiagState.live_upper=EMPTY_VALUE; gBookDiagState.live_posrel=EMPTY_VALUE;
}
void BookDiagPass(int mask)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   BookArmedPass(gBookDiagState.trace,mask);
}
void BookDiagWait(int mask,string reason)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   ulong begin=GetMicrosecondCount();
   BookArmedBlock(gBookDiagState.trace,mask);
   if(gBookDiagState.first_reason=="") gBookDiagState.first_reason=reason;
   gBookDiagState.last_reason=reason;
   BookDiagAccountCost(begin);
}
void BookDiagAfterEvaluation()
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   if(gBookDiagState.trace.blocked!=0) BookDiagEmit("WAIT",gBookDiagState.last_reason);
}
void BookDiagTick(const MqlTick &tick,double trigger)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   // Called only after the inherited real-trade predicate and positive last.
   gBookDiagState.trace.trigger=trigger;
   BookArmedObserveTrade(gBookDiagState.trace,tick.last,tick.time_msc,
      (long)TimeTradeServer()*1000);
   if(tick.bid>0 && tick.ask>=tick.bid)
      gBookDiagState.spread=tick.ask-tick.bid;
}
void BookDiagOvershoot(double overshoot)
{
   if(BookDiagEnabled() && gBookDiagState.active) gBookDiagState.overshoot=overshoot;
}
void BookDiagLive(double effort,double volume,double average,int direction)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   gBookDiagState.live_available=true; gBookDiagState.live_effort=effort;
   gBookDiagState.live_volume=volume; gBookDiagState.live_average=average;
   gBookDiagState.live_direction=direction;
}
void BookDiagLiveBands(double vwap,double lower,double upper,double posrel)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   gBookDiagState.live_vwap=vwap; gBookDiagState.live_lower=lower;
   gBookDiagState.live_upper=upper; gBookDiagState.live_posrel=posrel;
}
void BookDiagSpread(const MqlTick &tick)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   if(tick.bid>0 && tick.ask>=tick.bid) gBookDiagState.spread=tick.ask-tick.bid;
}
void BookDiagBook(const BookGateDecision &decision,bool confirmed)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   // A local intent rejection is NOT a fresh book observation. Only a completed
   // MarketBookGet path carries a raw snapshot, including an API-failure quality.
   if(decision.state==BOOK_ENTRY_BLOCKED) return;
   if(!gBookDiagState.book_consulted)
   { BookDiagWait(BD_DATA,"WAIT_DATA:BOOK_NOT_CONSULTED"); return; }
   gBookDiagState.book_state=(int)decision.state;
   gBookDiagState.bid_pct=decision.pctBid; gBookDiagState.ask_pct=decision.pctAsk;
   gBookDiagState.book_sequence=decision.snapshot.sequence;
   if(confirmed) BookDiagPass(BD_BOOK);
   else BookDiagWait(BD_BOOK,"WAIT_BOOK_CONFIRMATION");
}
void BookDiagBookReadBegin()
{
   if(BookDiagEnabled() && gBookDiagState.active) gBookDiagState.book_consulted=false;
}
void BookDiagBookAttempt()
{
   if(BookDiagEnabled() && gBookDiagState.active) gBookDiagState.book_consulted=true;
}
void BookDiagFinish(string reason)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   gBookDiagState.terminal=reason;
   BookDiagEmit("TERMINAL",reason,true);
   gBookDiagState.active=false;
}
void BookDiagAudit(string status)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   if(status=="TIMEOUT_ARMED")
      BookDiagFinish(BookArmedTimeoutClass(gBookDiagState.trace)==1?
         "TIMEOUT_NO_BREAKOUT":"TIMEOUT_TRIGGER_REACHED_BUT_BLOCKED");
   else if(status=="ABORT_SESSION_END" || status=="ABORT_EOD")
      BookDiagFinish("CANCEL_SESSION_END:"+status);
   else if(status=="ARMED_CANCEL_HARD") BookDiagFinish("CANCEL_HARD_CONTRADICTION");
   else if(status=="OVERSHOOT_BLOCK" || status=="LATE_OVERSHOOT_BLOCK")
      BookDiagFinish("CANCEL_OVERSHOOT");
   else if(status=="LATE_VWAP_INVALID") BookDiagFinish("CANCEL_DATA:LIVE_VWAP");
   else if(status=="LATE_DIRECTION_BLOCK" || status=="LATE_GLASS_BLOCK" ||
      status=="DAILY_RISK_BLOCK" || status=="STOPS_LEVEL_BLOCK" ||
      status=="NO_MARGIN" || status=="LATE_POSITION_BLOCK" ||
      status=="LATE_QUOTA_BLOCK" || status=="LATE_DAILY_RISK_BLOCK" ||
      status=="LATE_PENDING_BLOCK")
   { BookDiagWait(BD_OTHER,"WAIT_OTHER_GATE:"+status); BookDiagFinish("ORIGINAL_GATE:"+status); }
}
void BookDiagBeforeReset()
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   MqlDateTime now; TimeToStruct(TimeTradeServer(),now);
   int hhmm=now.hour*100+now.min;
   if(hhmm>=Inp_StopEntryHHMM) BookDiagFinish("CANCEL_SESSION_END");
   else if(armed.armedAt>0 && (TimeTradeServer()/86400)!=(armed.armedAt/86400))
      BookDiagFinish("CANCEL_DAY_CHANGE");
   else BookDiagFinish("ORIGINAL_RESET_CAUSE_UNAVAILABLE");
}
void BookDiagSendOutcome(ENUM_SEND_OUTCOME outcome)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   if(outcome==SEND_WAIT_ARMED) return;
   if(outcome==SEND_ACCEPTED) BookDiagFinish("ORDER_ACCEPTED_WITHOUT_OBSERVER_DISPATCH_CORRELATION");
   else if(outcome==SEND_FINANCIAL_UNRESOLVED)
      BookDiagFinish("ORIGINAL_FINANCIAL_RESULT_UNCERTAIN");
   else if(outcome==SEND_FINAL_FAILURE)
      BookDiagFinish("ORDER_FAILED_BEFORE_API_OR_UNAVAILABLE_CAUSE");
   else BookDiagFinish("ORIGINAL_SEND_TERMINAL:"+(string)(int)outcome);
}
void BookDiagDispatch(const MqlTradeResult &result)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   BookArmedEvent e; ZeroMemory(e); e.event="ORDER_SENT";
   e.reason="API_CALLED_NOT_FILL_PROOF"; e.state=gBookDiagState;
   e.order=result.order; e.deal=result.deal; e.request_id=result.request_id;
   e.retcode=result.retcode; BookDiagEnqueue(e,true);
   int slot=-1;
   for(int i=0;i<BOOK_DIAG_PENDING_CAP;i++)
      if(!gBookDiagAwaiting[i].used) { slot=i; break; }
   if(slot>=0)
   {
      gBookDiagAwaiting[slot].used=true; gBookDiagAwaiting[slot].state=gBookDiagState;
      gBookDiagAwaiting[slot].request_id=result.request_id;
      gBookDiagAwaiting[slot].order=result.order; gBookDiagAwaiting[slot].deal=result.deal;
   }
   else gBookDiagOverwrites++; // Never overwrite an unresolved diagnostic identity.
   if(IsFinalRejectedRetcode(result.retcode) && result.order==0 && result.deal==0)
   {
      e.event="ORDER_FAILED"; e.reason="FINAL_REJECTED_RETCODE";
      BookDiagEnqueue(e,true);
      if(slot>=0) gBookDiagAwaiting[slot].used=false;
   }
   BookDiagFinish("ORDER_SENT_AWAITING_SERVER_PROOF");
}
void BookDiagRequestResult(const MqlTradeResult &result)
{
   if(!BookDiagEnabled() || result.request_id==0) return;
   // Caller invokes only after original exact ownEntryRequest matches.
   for(int i=0;i<BOOK_DIAG_PENDING_CAP;i++)
   {
      if(!gBookDiagAwaiting[i].used ||
         gBookDiagAwaiting[i].request_id!=result.request_id) continue;
      if(result.order>0) gBookDiagAwaiting[i].order=result.order;
      if(result.deal>0) gBookDiagAwaiting[i].deal=result.deal;
      if(IsFinalRejectedRetcode(result.retcode) &&
         gBookDiagAwaiting[i].order==0 && gBookDiagAwaiting[i].deal==0)
      {
         BookArmedEvent e; ZeroMemory(e); e.event="ORDER_FAILED";
         e.reason="MATCHED_FINAL_REJECTED_REQUEST";
         e.state=gBookDiagAwaiting[i].state;
         e.request_id=result.request_id; e.retcode=result.retcode;
         BookDiagEnqueue(e,true); gBookDiagAwaiting[i].used=false;
      }
   }
}
void BookDiagConfirmed(const TradeRecord &r)
{
   if(!BookDiagEnabled() || !r.accountingResolved || r.historyRefreshPending ||
      r.positionID==0 || r.entryOrderTicket==0 || r.totalVolumeIn<=0 ||
      r.weightedEntryPrice<=0) return;
   for(int i=0;i<BOOK_DIAG_PENDING_CAP;i++)
   {
      if(!gBookDiagAwaiting[i].used || gBookDiagAwaiting[i].order==0 ||
         gBookDiagAwaiting[i].order!=r.entryOrderTicket ||
         gBookDiagAwaiting[i].state.trace.direction!=r.direction ||
         gBookDiagAwaiting[i].state.route!=r.route ||
         gBookDiagAwaiting[i].state.mode!=r.mode) continue;
      BookArmedEvent e; ZeroMemory(e); e.event="ORDER_CONFIRMED";
      e.reason="AUTHORITATIVE_ENTRY_DEALS_NOT_FULL_FILL_GUARANTEE";
      e.state=gBookDiagAwaiting[i].state; e.order=r.entryOrderTicket;
      e.position=r.positionID; e.request_id=gBookDiagAwaiting[i].request_id;
      e.confirmed_volume=r.totalVolumeIn; e.confirmed_entry=r.weightedEntryPrice;
      BookDiagEnqueue(e,true); gBookDiagAwaiting[i].used=false;
   }
}
void BookDiagMatrix(const MatrixSnapshot &s,datetime live_bar)
{
   if(!BookDiagEnabled() || s.status!=MSS_OK) return;
   BookArmedEvent e; ZeroMemory(e);
   e.event=gBookDiagState.active?"ARMED_MATRIX_OPPORTUNITY":"BANDS_REFERENCE";
   e.reason="ORIGINAL_SNAPSHOT_ONLY_NO_NEW_EVALUATION";
   if(gBookDiagState.active) e.state=gBookDiagState;
   e.state.matrix=s; e.state.matrix_available=true;
   e.state.signal_bar=live_bar;
   e.state.sigma=SigmaD1; e.state.sigma_days=gBookSigmaValidDays;
   e.state.vwap_d1=VWAP_D1; e.state.d1_high=H1; e.state.d1_low=L1;
   BookDiagEnqueue(e,true);
   // Initial valid snapshot and actual D1/sigma-reference changes only.
   if(SigmaD1!=gBookDiagLastSigma || VWAP_D1!=gBookDiagLastD1 ||
      H1!=gBookDiagLastH1 || L1!=gBookDiagLastL1)
   {
      PrintFormat("[BOOK_BANDS] SIGMA_D1=%.8f SIGMA_VALID_DAYS=%d BAND_MULTIPLIER=%.8f VWAP_CURRENT=%.8f LOWER_BAND=%.8f UPPER_BAND=%.8f BAND_RANGE=%.8f VWAP_TO_LOWER_DISTANCE=%.8f VWAP_TO_UPPER_DISTANCE=%.8f VWAP_D1=%.8f D1_HIGH=%.8f D1_LOW=%.8f PRICE_POSITION_RELATIVE=%.8f; D1_OPEN/CURRENT_SESSION_OPEN=UNAVAILABLE; original snapshot only",
         SigmaD1,gBookSigmaValidDays,BandMultiplier,s.vwapVig,s.lower,s.upper,
         s.upper-s.lower,s.vwapVig-s.lower,s.upper-s.vwapVig,VWAP_D1,H1,L1,s.posRel);
      gBookDiagLastSigma=SigmaD1; gBookDiagLastD1=VWAP_D1;
      gBookDiagLastH1=H1; gBookDiagLastL1=L1;
   }
}
string BookDiagNumber(double value,bool available=true)
{ return available && BookArmedFinite(value)?StringFormat("%.17g",value):""; }
void BookDiagCell(string &row,string value)
{
   StringReplace(value,"\"","\"\"");
   if(row!="") row+=";";
   row+="\""+value+"\"";
}
string BookDiagOriginalMatrix(const MatrixSnapshot &s)
{
   string row="";
   BookDiagCell(row,"matrix.status="+(string)(int)s.status);
   BookDiagCell(row,"matrix.vwapVig="+BookDiagNumber(s.vwapVig));
   BookDiagCell(row,"matrix.upper="+BookDiagNumber(s.upper));
   BookDiagCell(row,"matrix.lower="+BookDiagNumber(s.lower));
   BookDiagCell(row,"matrix.bandRange="+BookDiagNumber(s.bandRange));
   BookDiagCell(row,"matrix.price="+BookDiagNumber(s.price));
   BookDiagCell(row,"matrix.open1="+BookDiagNumber(s.open1));
   BookDiagCell(row,"matrix.candleBody="+BookDiagNumber(s.candleBody));
   BookDiagCell(row,"matrix.posRel="+BookDiagNumber(s.posRel));
   BookDiagCell(row,"matrix.glass="+(string)(int)s.glass);
   BookDiagCell(row,"matrix.dir="+(string)(int)s.dir);
   BookDiagCell(row,"matrix.dirCont="+(string)(int)s.dirCont);
   BookDiagCell(row,"matrix.c5AbsOk="+(string)(int)s.c5AbsOk);
   BookDiagCell(row,"matrix.c5ContOk="+(string)(int)s.c5ContOk);
   BookDiagCell(row,"matrix.distAbs="+BookDiagNumber(s.distAbs));
   BookDiagCell(row,"matrix.minDispl="+BookDiagNumber(s.minDispl));
   BookDiagCell(row,"matrix.maxBody="+BookDiagNumber(s.maxBody));
   BookDiagCell(row,"matrix.contMinDispl="+BookDiagNumber(s.contMinDispl));
   BookDiagCell(row,"matrix.c2="+(string)(int)s.c2);
   BookDiagCell(row,"matrix.c3="+(string)(int)s.c3);
   BookDiagCell(row,"matrix.c23="+(string)(int)s.c23);
   BookDiagCell(row,"matrix.c4="+(string)(int)s.c4);
   BookDiagCell(row,"matrix.c2Cont="+(string)(int)s.c2Cont);
   BookDiagCell(row,"matrix.c3Cont="+(string)(int)s.c3Cont);
   BookDiagCell(row,"matrix.c23Cont="+(string)(int)s.c23Cont);
   BookDiagCell(row,"matrix.c4Cont="+(string)(int)s.c4Cont);
   BookDiagCell(row,"matrix.posRange="+BookDiagNumber(s.posRange));
   BookDiagCell(row,"matrix.windowsValid="+(string)(int)s.windowsValid);
   BookDiagCell(row,"matrix.priceMove="+BookDiagNumber(s.priceMove));
   BookDiagCell(row,"matrix.pocMove="+BookDiagNumber(s.pocMove));
   BookDiagCell(row,"matrix.displacementOk="+(string)(int)s.displacementOk);
   BookDiagCell(row,"matrix.moveDir="+(string)(int)s.moveDir);
   BookDiagCell(row,"matrix.pocState="+(string)(int)s.pocState);
   BookDiagCell(row,"matrix.contDisplacementOk="+(string)(int)s.contDisplacementOk);
   BookDiagCell(row,"matrix.contMoveDir="+(string)(int)s.contMoveDir);
   BookDiagCell(row,"matrix.contPocState="+(string)(int)s.contPocState);
   BookDiagCell(row,"matrix.wwok="+(string)(int)s.wwok);
   BookDiagCell(row,"matrix.effort="+BookDiagNumber(s.effort));
   BookDiagCell(row,"matrix.waveDir="+(string)(int)s.waveDir);
   BookDiagCell(row,"matrix.wwWaveBars="+(string)(int)s.wwWaveBars);
   BookDiagCell(row,"matrix.wwWaveAgeSec="+(string)s.wwWaveAgeSec);
   BookDiagCell(row,"matrix.wwWaveAgeAvailable="+(string)(int)s.wwWaveAgeAvailable);
   BookDiagCell(row,"matrix.wwAccumVolume="+BookDiagNumber(s.wwAccumVolume));
   BookDiagCell(row,"matrix.wwDistancePts="+BookDiagNumber(s.wwDistancePts));
   BookDiagCell(row,"matrix.c1_effort_ok="+(string)(int)s.c1_effort_ok);
   BookDiagCell(row,"matrix.c1_body_ok="+(string)(int)s.c1_body_ok);
   BookDiagCell(row,"matrix.c1_displacement_ok="+(string)(int)s.c1_displacement_ok);
   BookDiagCell(row,"matrix.c1_movedir_ok="+(string)(int)s.c1_movedir_ok);
   BookDiagCell(row,"matrix.c1_wavedir_ok="+(string)(int)s.c1_wavedir_ok);
   BookDiagCell(row,"matrix.absDivergence="+(string)(int)s.absDivergence);
   BookDiagCell(row,"matrix.absStallStrict="+(string)(int)s.absStallStrict);
   BookDiagCell(row,"matrix.absFollowingReaction="+(string)(int)s.absFollowingReaction);
   BookDiagCell(row,"matrix.absFollowingExtension="+(string)(int)s.absFollowingExtension);
   BookDiagCell(row,"matrix.absPocContextOk="+(string)(int)s.absPocContextOk);
   BookDiagCell(row,"matrix.c1="+(string)(int)s.c1);
   BookDiagCell(row,"matrix.cont_effort_ok="+(string)(int)s.cont_effort_ok);
   BookDiagCell(row,"matrix.cont_displacement_ok="+(string)(int)s.cont_displacement_ok);
   BookDiagCell(row,"matrix.cont_poc_ok="+(string)(int)s.cont_poc_ok);
   BookDiagCell(row,"matrix.cont_movedir_ok="+(string)(int)s.cont_movedir_ok);
   BookDiagCell(row,"matrix.cont_wavedir_ok="+(string)(int)s.cont_wavedir_ok);
   BookDiagCell(row,"matrix.cont_candle_dir_ok="+(string)(int)s.cont_candle_dir_ok);
   BookDiagCell(row,"matrix.c1Cont="+(string)(int)s.c1Cont);
   BookDiagCell(row,"matrix.turboAbs="+(string)(int)s.turboAbs);
   BookDiagCell(row,"matrix.baseAbs="+(string)(int)s.baseAbs);
   BookDiagCell(row,"matrix.turboCont="+(string)(int)s.turboCont);
   BookDiagCell(row,"matrix.baseCont="+(string)(int)s.baseCont);
   BookDiagCell(row,"matrix.scoreEff="+(string)(int)s.scoreEff);
   BookDiagCell(row,"matrix.scoreContEff="+(string)(int)s.scoreContEff);
   BookDiagCell(row,"matrix.absValid="+(string)(int)s.absValid);
   BookDiagCell(row,"matrix.contValid="+(string)(int)s.contValid);
   BookDiagCell(row,"matrix.candleDir="+(string)(int)s.candleDir);
   BookDiagCell(row,"matrix.macroAbsCompatible="+(string)(int)s.macroAbsCompatible);
   BookDiagCell(row,"matrix.macroContCompatible="+(string)(int)s.macroContCompatible);
   BookDiagCell(row,"pocNow.ok="+(string)(int)s.pocNow.ok);
   BookDiagCell(row,"pocNow.poc="+BookDiagNumber(s.pocNow.poc));
   BookDiagCell(row,"pocNow.totalVolume="+BookDiagNumber(s.pocNow.totalVolume));
   BookDiagCell(row,"pocNow.lastValidPrice="+BookDiagNumber(s.pocNow.lastValidPrice));
   BookDiagCell(row,"pocNow.tradeCount="+(string)(int)s.pocNow.tradeCount);
   BookDiagCell(row,"pocNow.levels="+(string)(int)s.pocNow.levels);
   BookDiagCell(row,"pocNow.hasTie="+(string)(int)s.pocNow.hasTie);
   BookDiagCell(row,"pocNow.top1Price="+BookDiagNumber(s.pocNow.top1Price));
   BookDiagCell(row,"pocNow.top1Vol="+BookDiagNumber(s.pocNow.top1Vol));
   BookDiagCell(row,"pocNow.top2Price="+BookDiagNumber(s.pocNow.top2Price));
   BookDiagCell(row,"pocNow.top2Vol="+BookDiagNumber(s.pocNow.top2Vol));
   BookDiagCell(row,"pocNow.dominance="+BookDiagNumber(s.pocNow.dominance));
   BookDiagCell(row,"pocNow.buyVol="+BookDiagNumber(s.pocNow.buyVol));
   BookDiagCell(row,"pocNow.sellVol="+BookDiagNumber(s.pocNow.sellVol));
   BookDiagCell(row,"pocNow.unkVol="+BookDiagNumber(s.pocNow.unkVol));
   BookDiagCell(row,"pocPrev.ok="+(string)(int)s.pocPrev.ok);
   BookDiagCell(row,"pocPrev.poc="+BookDiagNumber(s.pocPrev.poc));
   BookDiagCell(row,"pocPrev.totalVolume="+BookDiagNumber(s.pocPrev.totalVolume));
   BookDiagCell(row,"pocPrev.lastValidPrice="+BookDiagNumber(s.pocPrev.lastValidPrice));
   BookDiagCell(row,"pocPrev.tradeCount="+(string)(int)s.pocPrev.tradeCount);
   BookDiagCell(row,"pocPrev.levels="+(string)(int)s.pocPrev.levels);
   BookDiagCell(row,"pocPrev.hasTie="+(string)(int)s.pocPrev.hasTie);
   BookDiagCell(row,"pocPrev.top1Price="+BookDiagNumber(s.pocPrev.top1Price));
   BookDiagCell(row,"pocPrev.top1Vol="+BookDiagNumber(s.pocPrev.top1Vol));
   BookDiagCell(row,"pocPrev.top2Price="+BookDiagNumber(s.pocPrev.top2Price));
   BookDiagCell(row,"pocPrev.top2Vol="+BookDiagNumber(s.pocPrev.top2Vol));
   BookDiagCell(row,"pocPrev.dominance="+BookDiagNumber(s.pocPrev.dominance));
   BookDiagCell(row,"pocPrev.buyVol="+BookDiagNumber(s.pocPrev.buyVol));
   BookDiagCell(row,"pocPrev.sellVol="+BookDiagNumber(s.pocPrev.sellVol));
   BookDiagCell(row,"pocPrev.unkVol="+BookDiagNumber(s.pocPrev.unkVol));
   return row;
}
string BookDiagFormat(const BookArmedEvent &e)
{
   BookArmedDiagnostic s=e.state;
   bool identity=s.id!="";
   string row="";
   BookDiagCell(row,"BOOK_ARMED_V1"); BookDiagCell(row,gBookDiagRun);
   BookDiagCell(row,gBookDiagExecutionContext); BookDiagCell(row,s.id);
   BookDiagCell(row,(string)e.observed_msc); BookDiagCell(row,e.event);
   BookDiagCell(row,e.reason); BookDiagCell(row,s.route); BookDiagCell(row,s.mode);
   BookDiagCell(row,identity?(string)s.trace.direction:""); BookDiagCell(row,s.subtype);
   BookDiagCell(row,(string)s.signal_bar); BookDiagCell(row,identity?(string)s.armed_at:"");
   BookDiagCell(row,BookDiagNumber(s.high,identity)); BookDiagCell(row,BookDiagNumber(s.low,identity));
   BookDiagCell(row,BookDiagNumber(s.margin,identity)); BookDiagCell(row,BookDiagNumber(s.trace.trigger,identity));
   BookDiagCell(row,(string)Inp_ArmedTimeoutSec);
   BookDiagCell(row,BookDiagNumber(s.trace.best,s.trace.price_available));
   BookDiagCell(row,BookDiagNumber(s.trace.worst,s.trace.price_available));
   BookDiagCell(row,identity?(s.trace.touched?"1":"0"):"");
   BookDiagCell(row,s.trace.touched?(string)(s.trace.first_touch_observed_msc-s.trace.armed_msc):"");
   BookDiagCell(row,"CALLBACK_REAL_TRADE_SAMPLES_SERVER_SECOND_RESOLUTION");
   BookDiagCell(row,s.first_reason); BookDiagCell(row,s.last_reason);
   BookDiagCell(row,(string)s.trace.first_blocked); BookDiagCell(row,(string)s.trace.last_blocked);
   BookDiagCell(row,(string)s.trace.blocked); BookDiagCell(row,(string)s.trace.ever_blocked);
   BookDiagCell(row,(string)s.trace.evaluated); BookDiagCell(row,(string)BookArmedNotEvaluated(s.trace));
   BookDiagCell(row,(string)s.trace.samples); BookDiagCell(row,(string)s.trace.last_tick_msc);
   BookDiagCell(row,(string)s.trace.evaluations);
   BookDiagCell(row,s.live_available?"PARTIAL_LIVE_WAVE":"NOT_EVALUATED");
   BookDiagCell(row,s.live_available?(string)s.live_direction:"");
   BookDiagCell(row,BookDiagNumber(s.live_effort,s.live_available));
   BookDiagCell(row,BookDiagNumber(s.live_volume,s.live_available));
   BookDiagCell(row,BookDiagNumber(s.live_average,s.live_available));
   BookDiagCell(row,BookDiagNumber(s.effort_min,identity));
   BookDiagCell(row,BookDiagNumber(s.spread,identity)); BookDiagCell(row,BookDiagNumber(s.overshoot,identity));
   BookDiagCell(row,BookDiagNumber(s.live_vwap,identity)); BookDiagCell(row,BookDiagNumber(s.live_lower,identity));
   BookDiagCell(row,BookDiagNumber(s.live_upper,identity)); BookDiagCell(row,BookDiagNumber(s.live_posrel,identity));
   BookDiagCell(row,s.book_consulted?"CONSULTED":"NOT_EVALUATED");
   BookDiagCell(row,s.book_consulted?(string)s.book_state:"");
   BookDiagCell(row,BookDiagNumber(s.bid_pct,s.book_consulted));
   BookDiagCell(row,BookDiagNumber(s.ask_pct,s.book_consulted));
   BookDiagCell(row,s.book_consulted?(string)s.book_sequence:"");
   BookDiagCell(row,s.terminal); BookDiagCell(row,e.order>0?(string)e.order:"");
   BookDiagCell(row,e.deal>0?(string)e.deal:""); BookDiagCell(row,e.position>0?(string)e.position:"");
   BookDiagCell(row,e.request_id>0?(string)e.request_id:""); BookDiagCell(row,(string)e.retcode);
   BookDiagCell(row,BookDiagNumber(e.confirmed_volume,e.position>0));
   BookDiagCell(row,BookDiagNumber(e.confirmed_entry,e.position>0));
   BookDiagCell(row,BookDiagNumber(s.sigma,s.matrix_available));
   BookDiagCell(row,s.matrix_available?(string)s.sigma_days:"");
   BookDiagCell(row,BookDiagNumber(BandMultiplier));
   BookDiagCell(row,BookDiagNumber(s.matrix.vwapVig,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.matrix.lower,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.matrix.upper,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.matrix.upper-s.matrix.lower,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.matrix.vwapVig-s.matrix.lower,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.matrix.upper-s.matrix.vwapVig,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.vwap_d1,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.d1_high,s.matrix_available)); BookDiagCell(row,BookDiagNumber(s.d1_low,s.matrix_available));
   BookDiagCell(row,"UNAVAILABLE"); BookDiagCell(row,"UNAVAILABLE");
   BookDiagCell(row,BookDiagNumber(s.matrix.posRel,s.matrix_available));
   BookDiagCell(row,(string)gBookDiagDropped); BookDiagCell(row,(string)gBookDiagOverwrites);
   BookDiagCell(row,(string)gBookDiagDeduplicated); BookDiagCell(row,(string)gBookDiagIOErrors);
   BookDiagCell(row,(string)gBookDiagHookCount); BookDiagCell(row,(string)gBookDiagHookTotalUS);
   BookDiagCell(row,(string)gBookDiagHookMaxUS); BookDiagCell(row,(string)gBookDiagTimerUS);
   // All original matrix fields retained as ONE quoted CSV cell, formatted only
   // on timer from frozen scalars. Sigma/previous-day references are separate.
   string matrix=s.matrix_available?BookDiagOriginalMatrix(s.matrix):"";
   BookDiagCell(row,matrix);
   return row+"\r\n";
}
string BookDiagHeader()
{
   return "schema;run_id;execution_context;signal_id;observed_msc;event;reason;route;mode;direction;abs_subtype;signal_bar;armed_at;region_high;region_low;breakout_margin;trigger;timeout_sec;best_favorable_price;worst_adverse_price;trigger_touched;time_to_touch_observed_ms;trajectory_coverage;first_wait;last_wait;first_blocked_mask;last_blocked_mask;current_blocked_mask;ever_blocked_mask;evaluated_mask;not_evaluated_mask;samples;last_trade_tick_msc;evaluations;live_wave_state;live_wave_direction;live_effort;live_volume;live_reference;required_effort;spread;overshoot;live_vwap;live_lower;live_upper;live_posrel;book_consultation;book_state;bid_pct;ask_pct;book_sequence;terminal;order;deal;position;request_id;retcode;confirmed_entry_volume;confirmed_entry_price;SIGMA_D1;SIGMA_VALID_DAYS;BAND_MULTIPLIER;VWAP_CURRENT;LOWER_BAND;UPPER_BAND;BAND_RANGE;VWAP_TO_LOWER_DISTANCE;VWAP_TO_UPPER_DISTANCE;VWAP_D1;D1_HIGH;D1_LOW;D1_OPEN;CURRENT_SESSION_OPEN;PRICE_POSITION_RELATIVE;queue_dropped;unresolved_identity_capacity;deduplicated;io_errors;hook_count;hook_total_us;hook_max_us;timer_last_us;original_matrix_csv";
}
bool BookDiagWrite(string row)
{
   uchar bytes[];
   int expected=StringToCharArray(row,bytes,0,WHOLE_ARRAY,CP_UTF8)-1;
   if(expected<=0 || expected>32768 || gBookDiagBytes+(ulong)expected>BOOK_DIAG_DAILY_BYTES)
   { gBookDiagSuspended=true; gBookDiagSuspension="DAILY_OR_ROW_BYTE_LIMIT"; return false; }
   ResetLastError(); uint written=FileWriteString(gBookDiagFile,row);
   if(written!=(uint)expected || GetLastError()!=0)
   { gBookDiagIOErrors++; gBookDiagSuspended=true; gBookDiagSuspension="WRITE_IO_ERROR"; return false; }
   gBookDiagBytes+=written;
   return true;
}
bool BookDiagOpen()
{
   if(gBookDiagFile!=INVALID_HANDLE) return true;
   string path="BookArmed_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"_"+
      ResponseComponent(Symbol())+"_"+(string)gMagicCore+"_"+gBookDiagRun+"_"+gBookDiagDay+".csv";
   StringReplace(path,".","_"); path+=".log.csv";
   ResetLastError(); bool exists=FileIsExist(path); int probe=GetLastError();
   if(exists || (probe!=0 && probe!=ERR_FILE_NOT_EXIST) || StringLen(path)>240)
   { gBookDiagIOErrors++; gBookDiagSuspended=true; gBookDiagSuspension="PATH_EXISTING_OR_UNAVAILABLE"; return false; }
   gBookDiagFile=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ,0,CP_UTF8);
   if(gBookDiagFile==INVALID_HANDLE || FileSize(gBookDiagFile)!=0)
   { gBookDiagIOErrors++; gBookDiagSuspended=true; gBookDiagSuspension="OPEN_IO_ERROR"; return false; }
   return BookDiagWrite(BookDiagHeader()+"\r\n");
}
void BookDiagTimer()
{
   if(!Inp_EnableArmedDiagnostics || !gBookDiagReady) return;
   ulong begin=GetMicrosecondCount();
   string day=TimeToString(TimeTradeServer(),TIME_DATE); StringReplace(day,".","_");
   if(day!=gBookDiagDay)
   {
      if(gBookDiagFile!=INVALID_HANDLE) FileClose(gBookDiagFile);
      gBookDiagFile=INVALID_HANDLE; gBookDiagDay=day; gBookDiagBytes=0;
      if(gBookDiagIOErrors==0 && gBookDiagSuspension=="DAILY_OR_ROW_BYTE_LIMIT")
      { gBookDiagSuspended=false; gBookDiagSuspension=""; gBookDiagHealthPrinted=false; }
   }
   if(!gBookDiagSuspended && gBookDiagCount>0 && BookDiagOpen())
   {
      for(int i=0;i<8 && gBookDiagCount>0;i++)
      {
         if(!BookDiagWrite(BookDiagFormat(gBookDiagQueue[gBookDiagHead]))) break;
         ZeroMemory(gBookDiagQueue[gBookDiagHead]);
         gBookDiagHead=(gBookDiagHead+1)%BOOK_DIAG_QUEUE_CAP; gBookDiagCount--;
      }
      ResetLastError(); FileFlush(gBookDiagFile);
      if(GetLastError()!=0)
      { gBookDiagIOErrors++; gBookDiagSuspended=true; gBookDiagSuspension="FLUSH_IO_ERROR"; }
   }
   if(gBookDiagSuspended && !gBookDiagHealthPrinted)
   {
      gBookDiagHealthPrinted=true;
      PrintFormat("[BOOK_ARMED][DIAGNOSTICS_SUSPENDED] reason=%s queued=%d dropped=%I64u io_errors=%I64u; original strategy untouched, diagnostic coverage incomplete",
         gBookDiagSuspension,gBookDiagCount,gBookDiagDropped,gBookDiagIOErrors);
   }
   gBookDiagTimerUS=GetMicrosecondCount()-begin;
}
void BookDiagInit(string executionContext="")
{
   if(!Inp_EnableArmedDiagnostics) return;
   ZeroMemory(gBookDiagState);
   for(int i=0;i<BOOK_DIAG_QUEUE_CAP;i++) ZeroMemory(gBookDiagQueue[i]);
   for(int i=0;i<BOOK_DIAG_PENDING_CAP;i++) ZeroMemory(gBookDiagAwaiting[i]);
   gBookDiagHead=0; gBookDiagCount=0; gBookDiagSequence=0;
   gBookDiagDropped=0; gBookDiagOverwrites=0; gBookDiagBytes=0;
   gBookDiagIOErrors=0; gBookDiagDeduplicated=0; gBookDiagTimerUS=0;
   gBookDiagHookCount=0; gBookDiagHookTotalUS=0; gBookDiagHookMaxUS=0;
   gBookDiagSuspended=false; gBookDiagHealthPrinted=false; gBookDiagSuspension="";
   gBookDiagLastEventMSC=0; gBookDiagLastEvent=""; gBookDiagLastReason="";
   gBookDiagLastSigma=-1; gBookDiagLastD1=-1; gBookDiagLastH1=-1; gBookDiagLastL1=-1;
   gBookDiagExecutionContext=executionContext;
   gBookDiagRun=(string)TimeTradeServer()+"_"+(string)ChartID()+"_"+(string)GetMicrosecondCount();
   gBookDiagDay=TimeToString(TimeTradeServer(),TIME_DATE); StringReplace(gBookDiagDay,".","_");
   gBookDiagReady=true;
   BookDiagEmit("INIT","DIAGNOSTICS_ONLY",true);
}
void BookDiagDeinit()
{
   if(!Inp_EnableArmedDiagnostics || !gBookDiagReady) return;
   BookDiagFinish("CANCEL_DEINITIALIZATION");
   for(int i=0;i<BOOK_DIAG_PENDING_CAP;i++)
   {
      if(!gBookDiagAwaiting[i].used) continue;
      BookArmedEvent e; ZeroMemory(e); e.event="ORDER_EXECUTION_UNCONFIRMED_AT_DEINIT";
      e.reason="NO_DURABLE_OBSERVER_CORRELATION_RESTORED_NEXT_RUN";
      e.state=gBookDiagAwaiting[i].state; e.order=gBookDiagAwaiting[i].order;
      e.deal=gBookDiagAwaiting[i].deal; e.request_id=gBookDiagAwaiting[i].request_id;
      BookDiagEnqueue(e,true);
   }
   // Bounded final drain, no waiting and no changes to financial journals.
   BookDiagTimer();
   if(gBookDiagFile!=INVALID_HANDLE) { FileClose(gBookDiagFile); gBookDiagFile=INVALID_HANDLE; }
   PrintFormat("[BOOK_ARMED][SUMMARY] pending_rows=%d dropped=%I64u capacity_unresolved=%I64u dedup=%I64u bytes=%I64u hook_mean_us=%.3f hook_max_us=%I64u timer_last_us=%I64u; observation coverage is sampled, no homology claim",
      gBookDiagCount,gBookDiagDropped,gBookDiagOverwrites,gBookDiagDeduplicated,gBookDiagBytes,
      gBookDiagHookCount>0?(double)gBookDiagHookTotalUS/(double)gBookDiagHookCount:0,
      gBookDiagHookMaxUS,gBookDiagTimerUS);
   gBookDiagReady=false;
}
#endif
