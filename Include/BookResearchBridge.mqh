#ifndef BOOK_RESEARCH_BRIDGE_MQH
#define BOOK_RESEARCH_BRIDGE_MQH
// Read-only boundary. Original value snapshots are copied here; every mutable
// queue, identity, hypothetical ARMED and file belongs solely to research.
#define BOOK_RESEARCH_CAPTURE_CAP 32
struct BookResearchCapture
{
   BookResearchCandidate candidate;MatrixSnapshot snapshot;MacroContext macro;
   string eligibility,reason,subtype;double region_high,region_low;
   bool possible;long context_bar;bool open_position,pending,accounting,daily_block;
   int quota;double free_margin,equity,sigma,d1,h1,l1;
};
struct BookResearchEvidenceCapture
{
   string id;BookDecisionEvidence evidence;BookDecisionVerdict verdict;
   int direction;bool cont,bound,available,dispatch;
   long signal_generation,collector_epoch,data_version,covered;
};
BookResearchCapture gBookResearchCaptures[BOOK_RESEARCH_CAPTURE_CAP];
BookResearchEvidenceCapture gBookResearchEvidenceCaptures[BOOK_RESEARCH_CAPTURE_CAP];
BookDecisionHistory gBookResearchReferenceCaptures[BOOK_RESEARCH_CAPTURE_CAP];bool gBookResearchReferenceAvailable[BOOK_RESEARCH_CAPTURE_CAP];
int gBookResearchCaptureHead=0,gBookResearchCaptureCount=0,gBookResearchEvidenceHead=0,gBookResearchEvidenceCount=0;
string gBookResearchCandidateID="",gBookResearchArmedID="";
long gBookResearchBridgeOrdinal=0,gBookResearchBridgeBar=0;
ulong gBookResearchCallbackCalls=0,gBookResearchCallbackUS=0,gBookResearchCallbackMaxUS=0;
ulong gBookResearchBorrowCalls=0,gBookResearchBorrowUS=0,gBookResearchBorrowMaxUS=0;
ulong gBookResearchLastContextUS=0;string gBookResearchLastContextID="",gBookResearchEvidenceStamp="";
BookResearchEvidenceCapture gBookResearchLastOperational;
string gBookResearchAfterSendStamp="",gBookResearchGuardStamp="";ulong gBookResearchDispatchSequence=0,gBookResearchLastAfterDispatchSequence=0;
struct BookResearchDispatchCapture
{MqlTradeResult result;ArmedSignal original;string id;double price,lots,sl,tp;bool sent;uint retcode;long now,pricing_quote_msc;};
BookResearchDispatchCapture gBookResearchDispatches[BOOK_RESEARCH_CAPTURE_CAP];int gBookResearchDispatchHead=0,gBookResearchDispatchCount=0;
struct BookResearchRealLink {string id;ulong order,deal,position;};
BookResearchRealLink gBookResearchLinks[BOOK_RESEARCH_TRACK_CAP];int gBookResearchLinkNext=0;

string BookResearchJson(string value)
{
   StringReplace(value,"\\","\\\\");StringReplace(value,"\"","\\\"");
   StringReplace(value,"\r","\\r");StringReplace(value,"\n","\\n");StringReplace(value,"\t","\\t");
   return "\""+value+"\"";
}
// Local position reader avoids changing the strategy's posInfo object/cache.
bool BookResearchPositionKnown(bool &open)
{
   open=false;int n=PositionsTotal();if(n<0 || n>256)return false;
   CPositionInfo observation;
   for(int i=0;i<n;i++)
   {
      if(!observation.SelectByIndex(i))return false;
      if(observation.Symbol()==Symbol() && (gNetting || observation.Magic()==(long)gMagicCore))open=true;
   }
   return true;
}
bool BookResearchPendingKnown(bool &pending)
{
   pending=gPendingExec.active || gPendingExit.active || gOrderObligationScanUnresolved ||
      gRequestJournalUnresolved || gRequestJournalWritePending || gEntryJournalCleanupPending ||
      gExitJournalCleanupPending || gEntryJournalInvalid || gExitJournalInvalid ||
      gPendingOrderClassificationUnresolved;
   int n=OrdersTotal();if(n<0 || n>256)return false;
   // OrderSelect state is terminal read selection, not an EA financial variable.
   for(int i=0;i<n;i++)
   {
      ulong ticket=OrderGetTicket(i);if(ticket==0)return false;
      if(OrderGetString(ORDER_SYMBOL)==Symbol() && OrderGetInteger(ORDER_MAGIC)==(long)gMagicCore)pending=true;
   }
   for(int i=0;i<gTradeRecordCount;i++)
      if(gTradeRecords[i].positionID>0 && !gTradeRecords[i].closed && gTradeRecords[i].totalVolumeIn>0)pending=true;
   for(int i=0;i<ArraySize(gUnresolvedOrders);i++)
      if(gUnresolvedOrders[i].active && (gUnresolvedOrders[i].classificationPending || gUnresolvedOrders[i].persistencePending))pending=true;
   return true;
}
string BookResearchIdentity(const long bar,const int direction,const string route,const string mode,const double trigger)
{
   return gBookRunID+"|"+(string)bar+"|"+route+"|"+(string)direction+"|"+mode+"|"+StringFormat("%.17g",trigger);
}
void BookResearchQueueCandidate(const MatrixSnapshot &snapshot,const int direction,const bool cont,
   const string mode,const double high,const double low,const bool eligible,const string eligibility,const string reason,const long captured_signal_bar=0)
{
   if(!BookResearchEnabled())return;
   if(gBookResearchCaptureCount>=BOOK_RESEARCH_CAPTURE_CAP){gBookResearchDropped++;BookResearchSuspend("CANDIDATE_CAPTURE_CAPACITY");return;}
   BookResearchCapture capture;ZeroMemory(capture);
   BookResearchCandidate c;ZeroMemory(c);
   MqlTick tick;bool have=SymbolInfoTick(Symbol(),tick);
   c.created_msc=have?tick.time_msc:(long)TimeTradeServer()*1000;c.armed_at_sec=(long)TimeTradeServer();
   c.signal_bar=captured_signal_bar>0?captured_signal_bar:(long)gCachedMicroBar;c.symbol=Symbol();c.direction=direction;
   c.route=eligible?(cont?"CONT":"ABS"):(snapshot.absValid&&snapshot.contValid?"CONFLICT":(snapshot.absValid?"ABS":(snapshot.contValid?"CONT":"NONE")));c.mode=mode;
   c.trigger=eligible?ComputeTrigger(direction,high,low):0;c.region_high=high;c.region_low=low;
   c.id=BookResearchIdentity(c.signal_bar,direction,eligible?c.route:eligibility,mode,c.trigger);
   if(eligible)gBookResearchCandidateID=c.id;
   c.timeout_sec=Inp_ArmedTimeoutSec;c.stop_entry_hhmm=Inp_StopEntryHHMM;
   c.max_spread=gSpreadMaxPts;c.max_overshoot=gMaxOvershoot;c.tick_size=gTickSize;
   c.effort_min=cont?Inp_CONT_BreakoutEffort:Inp_ABS_BreakoutEffort;
   c.sl_distance=gSL_Pts;c.tp_distance=gTP_Pts;c.inner_pct=Inp_VWAP_Inner_Pct;c.outer_pct=Inp_VWAP_Outer_Pct;
   c.late_direction_block=Inp_EnableLateDirectionBlock;c.original_eligible=eligible;
   c.risk_parameters_frozen=true;c.sigma_stop=Inp_SL_Mode==SL_SIGMA_COM_TETO;c.frozen_sigma=SigmaD1;
   c.sl_multiplier=Inp_Mult_SL;c.sl_cap=gIsDollarFamily?Inp_Max_SL_Pts_WDO:Inp_Max_SL_Pts_WIN;
   c.tp_by_r=Inp_TP_Mode==TP_MODE_BY_ROUTE_R;c.tp_multiplier=(mode=="TURBO" || mode=="TURBO_CONT")?TP_TURBO_R:TP_BASE_R;
   c.price_digits=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS);
   capture.candidate=c;capture.snapshot=snapshot;capture.macro=gMacro;capture.context_bar=(long)gMacro.barTime;
   capture.eligibility=eligibility;capture.reason=reason;
   capture.subtype=cont?"CONT":(snapshot.absDivergence?"DIVERGENCE":(snapshot.absFollowingReaction?"FOLLOWING_REACTION":"STALL_STRICT"));
   capture.region_high=high;capture.region_low=low;
   // Selection hook copies existing guards only; no position/order scan or
   // history query is inserted before the original candidate veto/arming.
   bool open=gOpenPos.active,pending=gPendingExec.active || gPendingExit.active || gRequestJournalUnresolved ||
      gOrderObligationScanUnresolved || gPendingOrderClassificationUnresolved;
   capture.open_position=open;capture.pending=pending;capture.accounting=gAccountingUnresolved;
   capture.daily_block=dailyRiskBlocked;capture.quota=ordersEnteredToday;
   capture.sigma=SigmaD1;capture.d1=VWAP_D1;capture.h1=H1;capture.l1=L1;
   capture.free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);capture.equity=AccountInfoDouble(ACCOUNT_EQUITY);
   capture.possible=!open && !pending && !gAccountingUnresolved &&
      !dailyRiskBlocked && ordersEnteredToday<Inp_MaxTradesDay;
   int slot=(gBookResearchCaptureHead+gBookResearchCaptureCount)%BOOK_RESEARCH_CAPTURE_CAP;
   gBookResearchCaptures[slot]=capture;gBookResearchCaptureCount++;
}
void BookResearchCaptureCandidate(const MatrixSnapshot &snapshot,const int direction,const bool cont,
   const string mode,const double high,const double low)
{BookResearchQueueCandidate(snapshot,direction,cont,mode,high,low,true,"ORIGINAL_ELIGIBLE","SELECTED_BEFORE_APPLY");}
void BookResearchObserveMatrix(const MatrixSnapshot &snapshot,const ENUM_MSS status)
{
   if(!BookResearchEnabled())return;
   string reason="";
   if(status!=MSS_OK)reason="MATRIX_"+MssStr(status);
   else if(snapshot.absValid && snapshot.contValid)reason="ROUTE_CONFLICT_BLOCK";
   else if(!snapshot.absValid && !snapshot.contValid)reason="NO_CONFLUENCE";
   if(reason!="")BookResearchQueueCandidate(snapshot,0,false,"NONE",0,0,false,reason,reason);
}
void BookResearchRegionInvalid(const MatrixSnapshot &snapshot,const int direction,const bool cont,const string mode)
{BookResearchQueueCandidate(snapshot,direction,cont,mode,0,0,false,"REGION_INVALID","REGION_INVALID");}
void BookResearchObserveBlockedMatrix(const MatrixSnapshot &snapshot,const datetime signal_bar)
{BookResearchQueueCandidate(snapshot,0,false,"NONE",0,0,false,"FINANCIAL_BLOCKED_SNAPSHOT","ACCOUNTING_UNRESOLVED_READ_ONLY_SNAPSHOT",(long)signal_bar);}
void BookResearchCaptureArmed()
{if(BookResearchEnabled())gBookResearchArmedID=gBookResearchCandidateID;}
void BookResearchQueueEvidence(const BookDecisionEvidence &e,const BookDecisionVerdict &v,const int direction,
   const bool cont,const bool bound,const bool available)
{
   if(!BookResearchEnabled())return;
   string stamp=(bound?gBookResearchArmedID:gBookResearchCandidateID)+"|"+(string)(int)v.result+"|"+v.reason+"|"+
      (string)(available && e.have_current?e.current.flow.from_msc:0)+"|"+(bound?"ARMED":"CANDIDATE");
   BookResearchEvidenceCapture latest;latest.id=bound?gBookResearchArmedID:gBookResearchCandidateID;
   latest.evidence=e;latest.verdict=v;latest.direction=direction;latest.cont=cont;latest.bound=bound;latest.available=available;latest.dispatch=false;
   latest.signal_generation=gBookDecisionSignalGeneration;latest.collector_epoch=gBookDecisionEpoch;
   latest.data_version=gBookDecisionDataVersion;latest.covered=gBookDecisionCoveredMSC;
   gBookResearchLastOperational=latest;
   if(stamp==gBookResearchEvidenceStamp)return;gBookResearchEvidenceStamp=stamp;
   if(gBookResearchEvidenceCount>=BOOK_RESEARCH_CAPTURE_CAP){gBookResearchDropped++;BookResearchSuspend("EVIDENCE_CAPTURE_CAPACITY");return;}
   BookResearchEvidenceCapture capture;capture.id=bound?gBookResearchArmedID:gBookResearchCandidateID;
   capture=latest;
   int slot=(gBookResearchEvidenceHead+gBookResearchEvidenceCount)%BOOK_RESEARCH_CAPTURE_CAP;
   gBookResearchEvidenceCaptures[slot]=capture;gBookResearchReferenceAvailable[slot]=available;
   if(available)gBookResearchReferenceCaptures[slot]=gBookDecisionHistory;
   gBookResearchEvidenceCount++;
}
void BookResearchOperationalEvidence(const BookDecisionEvidence &e,const BookDecisionVerdict &v,
   const int direction,const bool cont,const bool bound)
{BookResearchQueueEvidence(e,v,direction,cont,bound,true);}
void BookResearchOperationalUnavailable(const BookDecisionVerdict &v,const int direction,const bool cont,const bool bound)
{
   if(!BookResearchEnabled())return;
   BookDecisionEvidence e;ZeroMemory(e);e.now_msc=(long)TimeTradeServer()*1000;
   BookResearchQueueEvidence(e,v,direction,cont,bound,false);
}
// Called only AFTER the sole entry API and CompletePendingExec have run.
// Copy exact native result/terms once, without I/O, computation or order calls.
void BookResearchRecordDispatch(const MqlTradeResult &result,const ArmedSignal &original,const double price,
   const double lots,const double sl,const double tp,const bool sent,const uint retcode,const long pricing_quote_msc)
{
   if(!BookResearchEnabled())return;
   gBookResearchDispatchSequence++;
   BookResearchMarkActualDispatch(gBookResearchArmedID,pricing_quote_msc,(long)TimeTradeServer()*1000);
   if(gBookResearchDispatchCount>=BOOK_RESEARCH_CAPTURE_CAP){gBookResearchDropped++;BookResearchSuspend("DISPATCH_CAPTURE_CAPACITY");return;}
   BookResearchDispatchCapture c;c.result=result;c.original=original;c.id=gBookResearchArmedID;
   c.price=price;c.lots=lots;c.sl=sl;c.tp=tp;c.sent=sent;c.retcode=retcode;c.now=(long)TimeTradeServer()*1000;c.pricing_quote_msc=pricing_quote_msc;
   int slot=(gBookResearchDispatchHead+gBookResearchDispatchCount)%BOOK_RESEARCH_CAPTURE_CAP;
   gBookResearchDispatches[slot]=c;gBookResearchDispatchCount++;
   int link=gBookResearchLinkNext;gBookResearchLinkNext=(link+1)%BOOK_RESEARCH_TRACK_CAP;
   gBookResearchLinks[link].id=c.id;gBookResearchLinks[link].order=result.order;gBookResearchLinks[link].deal=result.deal;gBookResearchLinks[link].position=0;
}
void BookResearchAfterSend(const ENUM_SEND_OUTCOME outcome)
{
   if(!BookResearchEnabled())return;
   // Repeated WAIT is a state, not one research record per incoming tick.
   string stamp=gBookResearchArmedID+"|"+(string)(int)outcome+"|"+gBookDecisionReason+"|"+
      BookResearchBool(gPendingExec.active)+"|"+(string)(int)gPendingExec.dispatchPhase+"|"+
      (string)gPendingExec.orderTicket+"|"+(string)gPendingExec.resultDeal+"|"+(string)gBookResearchDispatchSequence;
   if(stamp==gBookResearchAfterSendStamp)return;gBookResearchAfterSendStamp=stamp;
   bool dispatched=gBookResearchDispatchSequence!=gBookResearchLastAfterDispatchSequence;
   gBookResearchLastAfterDispatchSequence=gBookResearchDispatchSequence;
   // This hook is AFTER SendOrder returns, outside every financial critical path.
   if(dispatched && gBookResearchEvidenceCount<BOOK_RESEARCH_CAPTURE_CAP && gBookResearchLastOperational.id==gBookResearchArmedID)
   {int item=(gBookResearchEvidenceHead+gBookResearchEvidenceCount)%BOOK_RESEARCH_CAPTURE_CAP;
    gBookResearchEvidenceCaptures[item]=gBookResearchLastOperational;gBookResearchEvidenceCaptures[item].dispatch=true;
    gBookResearchReferenceAvailable[item]=gBookResearchLastOperational.available && gBookResearchLastOperational.collector_epoch==gBookDecisionEpoch &&
       gBookResearchLastOperational.data_version==gBookDecisionDataVersion;
    if(gBookResearchReferenceAvailable[item])gBookResearchReferenceCaptures[item]=gBookDecisionHistory;
    gBookResearchEvidenceCount++;}
   BookResearchRuntimeReal(gBookResearchArmedID,"REAL_SEND_RETURN",(long)TimeTradeServer()*1000,Symbol(),"",
      (string)gPendingExec.orderTicket,(string)gPendingExec.resultDeal,gPendingExec.requestPrice,0,gPendingExec.slPrice,gPendingExec.tpPrice,
      0,0,0,0,0,0,0,false,"",false,false,"send_outcome="+(string)(int)outcome+"; request_id="+(string)gPendingExec.requestID+
      "; pending_active="+BookResearchBool(gPendingExec.active)+"; result is not a fill or reconciled PnL");
}
string BookResearchLinkFor(const ulong position,const ulong order,const ulong deal)
{
   for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++)
      if((position>0 && gBookResearchLinks[i].position==position) || (order>0 && gBookResearchLinks[i].order==order) ||
         (deal>0 && gBookResearchLinks[i].deal==deal))return gBookResearchLinks[i].id;
   return ""; // never guess a recovered trade's original candidate or preset
}
void BookResearchCaptureTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(!BookResearchEnabled() || trans.symbol!=Symbol())return;

   // A transaction's position field is a POSITION TICKET, not necessarily its
   // stable POSITION_IDENTIFIER. Link stable IDs only from confirmed deal data.
   ulong pid=0;
   if(trans.deal>0)pid=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
   if(pid==0 && trans.position>0)
   {CPositionInfo observation;if(observation.SelectByTicket(trans.position))pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);}
   string id=BookResearchLinkFor(pid,trans.order,trans.deal);if(id=="")return;
   for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++)if(gBookResearchLinks[i].id==id && pid>0)gBookResearchLinks[i].position=pid;
   BookResearchRuntimeReal(id,trans.type==TRADE_TRANSACTION_POSITION?"REAL_STOP_CHANGE_OBSERVED":"REAL_TRANSACTION_OBSERVED",(long)TimeTradeServer()*1000,Symbol(),pid>0?(string)pid:"",
      (string)trans.order,(string)trans.deal,request.price,trans.price,trans.price_sl,trans.price_tp,0,0,0,0,0,0,0,false,"",false,false,
      "transaction_type="+(string)(int)trans.type+";request_id="+(string)result.request_id+";retcode="+(string)result.retcode);
}
void BookResearchCaptureTrade(const TradeRecord &record)
{
   if(!BookResearchEnabled())return;
   string id=BookResearchLinkFor(record.positionID,record.entryOrderTicket,0);
   BookResearchRuntimeReal(id,"REAL_RECONCILED",record.exitTimeMSC,Symbol(),(string)record.positionID,
      (string)record.entryOrderTicket,(string)record.lastExitDealTicket,record.requestPriceAvailable?record.requestPrice:0,
      record.weightedEntryPrice,record.slPrice,record.tpPrice,record.MAE,record.MFE,record.grossProfit,record.commission,
      record.fee,record.swap,record.netProfit,record.maeMfePartialAfterRestart,record.exitReason,record.accountingResolved,
      record.accountingResolved && record.volumeClosedComplete && !record.inoutCostsUnresolved,
      "duration_seconds="+(string)record.holdSeconds+";entry_time="+(string)(long)record.entryTime+";exit_time="+(string)(long)record.exitTime+
      ";link_scope="+(id==""?"HISTORICAL_ORIGIN_NOT_PROVEN":"EXACT_ORDER_OR_POSITION_ID"),record.holdSeconds);
}
// Local terminal calculations are read-only. This mirror never calls the
// original sizing helper (which writes audits) or freezes the real risk state.
// Failed APIs mean UNKNOWN; a measured stop/margin rejection means INVALID.
void BookResearchReadTerms(const int direction,const string mode,const MqlTick &tick,bool &known,bool &valid)
{
   known=false;valid=false;
   double entry=direction==1?tick.ask:tick.bid;if(entry<=0)return;
   BookResearchCandidate c;ZeroMemory(c);c.direction=direction;c.mode=mode;c.sl_distance=gSL_Pts;c.tp_distance=gTP_Pts;
   c.tick_size=gTickSize;c.price_digits=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS);c.risk_parameters_frozen=true;
   c.sigma_stop=Inp_SL_Mode==SL_SIGMA_COM_TETO;c.frozen_sigma=SigmaD1;c.sl_multiplier=Inp_Mult_SL;
   c.sl_cap=gIsDollarFamily?Inp_Max_SL_Pts_WDO:Inp_Max_SL_Pts_WIN;
   c.tp_by_r=Inp_TP_Mode==TP_MODE_BY_ROUTE_R;c.tp_multiplier=mode=="TURBO"?TP_TURBO_R:TP_BASE_R;
   double sl,tp;if(!BookResearchStops(c,entry,sl,tp)){known=true;return;}
   double lots=Inp_FixedLots;ENUM_ORDER_TYPE type=direction==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   if(Inp_SizingMode!=SIZING_FIXED)
   {
      double profit=0;if(!OrderCalcProfit(type,Symbol(),1.0,entry,sl,profit) || !MathIsValidNumber(profit) || profit>=0)return;
      double cash=AccountInfoDouble(ACCOUNT_EQUITY)*Inp_RiskPerTradePct/100.0;
      double step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
      if(!MathIsValidNumber(cash) || cash<=0 || step<=0)return;
      double cap=MathMin(Inp_MaxLots,SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX));
      double raw=MathMin(cash/MathAbs(profit),cap);lots=NormalizeDouble(MathFloor(raw/step)*step,8);
      if(lots>raw+1e-10)lots=NormalizeDouble(lots-step,8);
      if(lots<SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN)-1e-10){known=true;return;}
   }
   double minimum=(double)SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL)*SymbolInfoDouble(Symbol(),SYMBOL_POINT);
   double closing=direction==1?tick.bid:tick.ask;
   if(lots<=0 || direction*(entry-sl)<minimum || direction*(tp-entry)<minimum ||
      direction*(closing-sl)<minimum || direction*(tp-closing)<minimum){known=true;return;}
   double margin=0;if(!OrderCalcMargin(type,Symbol(),lots,entry,margin) || !MathIsValidNumber(margin) || margin<0)return;
   known=true;valid=AccountInfoDouble(ACCOUNT_MARGIN_FREE)>=margin;
}
void BookResearchAfterTick()
{
   if(!BookResearchEnabled())return;
   // Context snapshots <=10Hz plus every new candidate. Raw quote history is
   // acquired separately on the timer. Missing intermediate Stage2 context is
   // explicitly not reconstructable, never filled with a later bar's values.
   ulong local=GetMicrosecondCount();
   if(gBookResearchLastContextID==gBookResearchCandidateID && gBookResearchLastContextUS>0 &&
      local>=gBookResearchLastContextUS && local-gBookResearchLastContextUS<100000)return;
   gBookResearchLastContextUS=local;gBookResearchLastContextID=gBookResearchCandidateID;
   BookResearchMarketSample x;ZeroMemory(x);MqlTick tick;
   if(!SymbolInfoTick(Symbol(),tick))return;
   x.now_msc=tick.time_msc;x.server_sec=(long)TimeTradeServer();x.ordinal=++gBookResearchBridgeOrdinal;
   MqlDateTime dt;TimeToStruct((datetime)x.server_sec,dt);x.hhmm=dt.hour*100+dt.min;
   x.signal_bar=(long)iTime(Symbol(),Inp_SignalTF,0);x.new_signal_bar=x.signal_bar!=gBookResearchBridgeBar;gBookResearchBridgeBar=x.signal_bar;
   x.raw_identity_available=true;x.raw_volume=tick.volume;x.raw_volume_real=tick.volume_real;x.raw_flags=tick.flags;x.raw_time_sec=(long)tick.time;
   x.bid=tick.bid;x.ask=tick.ask;x.last=tick.last;x.quote_available=tick.bid>0 && tick.ask>=tick.bid;
   x.real_trade=(tick.flags&(TICK_FLAG_LAST|TICK_FLAG_VOLUME|TICK_FLAG_BUY|TICK_FLAG_SELL))!=0;
   x.weis_valid=wwValid;
   double current_volume=wwUseReal?(double)iRealVolume(Symbol(),Inp_SignalTF,0):(double)iVolume(Symbol(),Inp_SignalTF,0);
   double close=iClose(Symbol(),Inp_SignalTF,0),volume,average;
   BookResearchLiveWave(current_volume,close,wwCloseRef,wwDirClosed,wwAccumClosed,wwAvgClosed,wwAvgIfFlip,
      x.live_effort,volume,average,x.live_wave_direction);
   x.context_causal=x.signal_bar>0 && x.server_sec>=x.signal_bar && iTime(Symbol(),Inp_SignalTF,0)==(datetime)x.signal_bar && close>0;
   x.sigma=SigmaD1;x.band_multiplier=BandMultiplier;
   x.vwap_base_pv=vwapSumPV;x.vwap_base_volume=vwapSumVol;x.vwap_from=(long)vwapNextFromMsc;
   x.vwap_base_valid=vwapReady && vwapSumVol>0 && vwapNextFromMsc>0;
   // No hidden history read: the research timer qualifies the local trade suffix.
   x.vwap_valid=false;x.path_complete=false;
   x.hard_snapshot_valid=gLastTelemetryMatrixValid && (long)gLastTelemetrySignalBar==x.signal_bar;
   if(x.hard_snapshot_valid)
   {x.hard_abs_valid=gLastTelemetryMatrix.absValid;x.hard_cont_valid=gLastTelemetryMatrix.contValid;
    x.hard_abs_direction=gLastTelemetryMatrix.dir;x.hard_cont_direction=gLastTelemetryMatrix.dirCont;}
   bool open=false,pending=false;bool position_known=BookResearchPositionKnown(open),pending_known=BookResearchPendingKnown(pending);
   x.financial_known=position_known && pending_known;
   x.financial_possible=!open && !pending && !dailyRiskBlocked && !gAccountingUnresolved && ordersEnteredToday<Inp_MaxTradesDay;
   string guard=(string)x.signal_bar+"|"+BookResearchBool(open)+BookResearchBool(pending)+BookResearchBool(gAccountingUnresolved)+
      BookResearchBool(dailyRiskBlocked)+BookResearchBool(d1Ready)+BookResearchBool(wwValid);
   if(guard!=gBookResearchGuardStamp)
   {
      gBookResearchGuardStamp=guard;
      if(!x.financial_possible || !d1Ready || !wwValid)
         BookResearchHealth("ORIGINAL_NOT_EVALUATED",!d1Ready || !wwValid?"ORIGINAL_DATA_GUARD":"ORIGINAL_FINANCIAL_OR_POSITION_GUARD",
            "No valid current matrix opportunity is invented; open="+BookResearchBool(open)+";pending="+BookResearchBool(pending)+
            ";accounting="+BookResearchBool(gAccountingUnresolved)+";quota="+(string)ordersEnteredToday);
   }

   // Replay cannot reconstruct historical broker margin/sizing solely from a
   // quote. Stage2 market eligibility and conditional barriers remain separate.
   x.execution_terms_known=false;x.execution_terms_valid=false;x.route_terms=true;
   for(int k=0;k<4;k++)BookResearchReadTerms(k<2?1:-1,k%2==0?"BASE":"TURBO",tick,x.terms_known[k],x.terms_valid[k]);
   x.book_required=Inp_DOM_TradeGateEnable;x.book_known=false;x.book_confirmed=false;
   MqlTick after_context;
   if(!SymbolInfoTick(Symbol(),after_context) || after_context.time_msc!=tick.time_msc ||
      after_context.bid!=tick.bid || after_context.ask!=tick.ask || after_context.last!=tick.last ||
      after_context.volume!=tick.volume || after_context.volume_real!=tick.volume_real || after_context.flags!=tick.flags)x.context_causal=false;
   BookResearchRuntimeSample(x);
   ulong elapsed=GetMicrosecondCount()-local;gBookResearchCallbackCalls++;gBookResearchCallbackUS+=elapsed;
   if(elapsed>gBookResearchCallbackMaxUS)gBookResearchCallbackMaxUS=elapsed;
}
void BookResearchInit()
{
   if(!Inp_ResearchEnable)return;
   gBookResearchCaptureHead=0;gBookResearchEvidenceHead=0;gBookResearchCaptureCount=0;gBookResearchEvidenceCount=0;gBookResearchCandidateID="";gBookResearchArmedID="";
   gBookResearchLinkNext=0;for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++)ZeroMemory(gBookResearchLinks[i]);
   ZeroMemory(gBookResearchLastOperational);gBookResearchAfterSendStamp="";gBookResearchGuardStamp="";gBookResearchDispatchSequence=0;gBookResearchLastAfterDispatchSequence=0;gBookResearchDispatchHead=0;gBookResearchDispatchCount=0;
   gBookResearchCallbackCalls=0;gBookResearchCallbackUS=0;gBookResearchCallbackMaxUS=0;gBookResearchBorrowCalls=0;gBookResearchBorrowUS=0;gBookResearchBorrowMaxUS=0;
   gBookResearchBridgeOrdinal=0;gBookResearchBridgeBar=0;gBookResearchLastContextUS=0;gBookResearchLastContextID="";gBookResearchEvidenceStamp="";
   string trading_hash="UNAVAILABLE";
   string name="Inp_ResearchEnable",value=Inp_ResearchEnable?"1":"0";
   string suffix="4:bool"+(string)StringLen(name)+":"+name+"1:"+value+"\n";
   int length=StringLen(gBookCanonicalInputs)-StringLen(suffix);
   if(length>=0 && StringSubstr(gBookCanonicalInputs,length)==suffix)
      BookIdentityHash("BOOK_INPUT_CANONICAL_V1\n"+StringSubstr(gBookCanonicalInputs,0,length),trading_hash);
   BookResearchRuntimeInit(gBookRunID,gBookConfigHash,gBookCanonicalInputs,(string)AccountInfoInteger(ACCOUNT_LOGIN),
      (string)gMagicCore,BOOK_SOURCE_BUNDLE_SHA256,(int)Inp_DecisionMode,gBookDecisionConfig,AccountInfoString(ACCOUNT_SERVER),trading_hash);
}
// Exact legacy diagnostic serialization with all four external geometry values frozen.
void BookResearchMatrixRow(string &line,const MatrixSnapshot &s,bool available,datetime signalBar,
   const double captured_sigma,const double captured_d1,const double captured_h1,const double captured_l1)
{
  string route = s.absValid && s.contValid ? "CONFLICT" :
      (s.absValid ? "ABS" : (s.contValid ? "CONT" : "NONE"));
  string mode = s.absValid && s.contValid ? "CONFLICT" :
     (s.absValid ? (s.turboAbs ? "TURBO" : "BASE") :
      (s.contValid ? (s.turboCont ? "TURBO" : "BASE") : "NONE"));
  int direction = s.absValid && !s.contValid ? s.dir :
       (s.contValid && !s.absValid ? s.dirCont : 0);
// These four formulas are executable diagnostics in canonical v2.44.
// They remain telemetry and cannot change ABS/CONT or execution.
string flowRegime = !s.c1_effort_ok ? "FLOW_WEAK" :
     (!s.displacementOk ? "FLOW_STALL" :
      (s.moveDir == s.dir ? "FLOW_REACTION" :
       (s.moveDir == -s.dir ? "FLOW_EXTENSION" : "FLOW_NA")));
CsvAdd(line,BStr(available)); // MATRIX_SNAPSHOT_AVAILABLE
CsvAdd(line,CsvTime(signalBar)); // SIGNAL_BAR
CsvAdd(line,available ? (EnumToString(s.status)) : ""); // MATRIX_STATUS
CsvAdd(line,available ? (route) : ""); // ROUTE
CsvAdd(line,available ? (mode) : ""); // MODE
CsvAdd(line,available ? (DirStr(direction)) : ""); // DIR
CsvAdd(line,available ? (CsvD(s.price)) : ""); // PRICE
CsvAdd(line,available ? (CsvD(s.open1)) : ""); // OPEN
CsvAdd(line,available ? (CsvD(s.candleBody)) : ""); // CANDLE_BODY
CsvAdd(line,available ? (IntegerToString(s.candleDir)) : ""); // CANDLE_DIR
CsvAdd(line,available ? (CsvD(s.posRel)) : ""); // POSREL
CsvAdd(line,available ? (CsvD(s.posRange)) : ""); // POS_RANGE
CsvAdd(line,available ? (BStr(s.glass)) : ""); // GLASS
CsvAdd(line,available ? (CsvD(s.distAbs)) : ""); // DIST_VWAP_D1
CsvAdd(line,available ? (CsvD(s.vwapVig)) : ""); // VWAP_VIG
CsvAdd(line,available ? (CsvD(s.upper)) : ""); // UPPER_BAND
CsvAdd(line,available ? (CsvD(s.lower)) : ""); // LOWER_BAND
CsvAdd(line,available ? (CsvD(s.bandRange)) : ""); // BAND_RANGE
CsvAdd(line,available ? (CsvD(captured_sigma)) : ""); // SIGMA_D1
CsvAdd(line,available ? (CsvD(captured_d1)) : ""); // captured_d1
CsvAdd(line,available ? (CsvD(captured_h1)) : ""); // captured_h1
CsvAdd(line,available ? (CsvD(captured_l1)) : ""); // captured_l1
CsvAdd(line,available ? (DirStr(s.dir)) : ""); // ABS_DIR
CsvAdd(line,available ? (DirStr(s.dirCont)) : ""); // CONT_DIR
CsvAdd(line,available ? (BStr(s.c1)) : ""); // C1
CsvAdd(line,available ? (BStr(s.c2)) : ""); // C2
CsvAdd(line,available ? (BStr(s.c3)) : ""); // C3
CsvAdd(line,available ? (BStr(s.c4)) : ""); // C4
CsvAdd(line,available ? (BStr(s.c5AbsOk)) : ""); // C5
CsvAdd(line,available ? (BStr(s.c23)) : ""); // C23
CsvAdd(line,available ? (BStr(s.baseAbs)) : ""); // BASE
CsvAdd(line,available ? (BStr(s.turboAbs)) : ""); // TURBO
CsvAdd(line,available ? (BStr(s.c1Cont)) : ""); // CONT_C1
CsvAdd(line,available ? (BStr(s.c2Cont)) : ""); // CONT_C2
CsvAdd(line,available ? (BStr(s.c3Cont)) : ""); // CONT_C3
CsvAdd(line,available ? (BStr(s.c4Cont)) : ""); // CONT_C4
CsvAdd(line,available ? (BStr(s.c5ContOk)) : ""); // CONT_C5
CsvAdd(line,available ? (BStr(s.c23Cont)) : ""); // CONT_C23
CsvAdd(line,available ? (BStr(s.baseCont)) : ""); // CONT_BASE
CsvAdd(line,available ? (BStr(s.turboCont)) : ""); // CONT_TURBO
CsvAdd(line,available ? (IntegerToString(s.scoreEff)) : ""); // ABS_SCORE
CsvAdd(line,available ? (IntegerToString(s.scoreContEff)) : ""); // CONT_SCORE
  CsvAdd(line,available ? (BStr(s.absValid)) : ""); // ABS_VALID
  CsvAdd(line,available ? (BStr(s.contValid)) : ""); // CONT_VALID
  CsvAdd(line,available ? (BStr(s.macroAbsCompatible)) : ""); //
// MACRO_ABS_COMPATIBLE
  CsvAdd(line,available ? (BStr(s.macroContCompatible)) : ""); //
// MACRO_CONT_COMPATIBLE
  CsvAdd(line,available ? (BStr(s.wwok)) : ""); // WW_VALID
  CsvAdd(line,available ? (CsvD(s.effort)) : ""); // WW_EFFORT
  CsvAdd(line,available ? (IntegerToString(s.waveDir)) : ""); // WW_DIR
  CsvAdd(line,available ? (s.wwok ? IntegerToString(s.wwWaveBars) : "") : ""); //
// WW_WAVE_BARS
  CsvAdd(line,available ? (s.wwok && s.wwWaveAgeAvailable ?
IntegerToString(s.wwWaveAgeSec) : "") : ""); // WW_WAVE_AGE_SEC
  CsvAdd(line,available ? (s.wwok ? CsvD(s.wwAccumVolume) : "") : ""); //
// WW_ACCUM_VOLUME
 CsvAdd(line,available ? (s.wwok ? CsvD(s.wwDistancePts) : "") : ""); //
// WW_DISTANCE_PTS
 CsvAdd(line,available ? (BStr(s.windowsValid)) : ""); // WINDOWS_VALID
 CsvAdd(line,available ? (PocStateStr(s.pocState)) : ""); // ABS_POC_STATE
 CsvAdd(line,available ? (PocStateStr(s.contPocState)) : ""); // CONT_POC_STATE
 CsvAdd(line,available ? (CsvD(s.minDispl)) : ""); // ABS_MIN_MOVE
 CsvAdd(line,available ? (CsvD(s.maxBody)) : ""); // ABS_MAX_BODY
 CsvAdd(line,available ? (CsvD(s.contMinDispl)) : ""); // CONT_MIN_MOVE
 CsvAdd(line,available ? (BStr(s.displacementOk)) : ""); // ABS_DISPLACEMENT_OK
 CsvAdd(line,available ? (BStr(s.contDisplacementOk)) : ""); //
// CONT_DISPLACEMENT_OK
 CsvAdd(line,available ? (BStr(s.absDivergence)) : ""); // ABS_DIVERGENCE
 CsvAdd(line,available ? (BStr(s.absStallStrict)) : ""); // ABS_STALL_STRICT
 CsvAdd(line,available ? (BStr(s.c1_body_ok)) : ""); // ABS_BODY_OK
 CsvAdd(line,available ? (BStr(s.absFollowingReaction)) : ""); //
// ABS_FOLLOWING_REACTION
 CsvAdd(line,available ? (BStr(s.absFollowingExtension)) : ""); //
// ABS_FOLLOWING_EXTENSION
 CsvAdd(line,available ? (BStr(s.c1_effort_ok)) : ""); // ABS_EFFORT_OK
 CsvAdd(line,available ? (BStr(s.cont_effort_ok)) : ""); // CONT_EFFORT_OK
 CsvAdd(line,available ? (BStr(s.cont_poc_ok)) : ""); // CONT_POC_OK
 CsvAdd(line,available ? (BStr(s.cont_movedir_ok)) : ""); // CONT_MOVE_DIR_OK
 CsvAdd(line,available ? (BStr(s.cont_wavedir_ok)) : ""); // CONT_WAVE_DIR_OK
 CsvAdd(line,available ? (BStr(s.cont_candle_dir_ok)) : ""); // CONT_CANDLE_DIR_OK
 CsvAdd(line,available ? (CsvD(s.priceMove)) : ""); // PRICE_MOVE
 CsvAdd(line,available ? (CsvD(s.pocMove)) : ""); // POC_MOVE
 CsvAdd(line,available ? (IntegerToString(s.moveDir)) : ""); // MOVE_DIR
 CsvAdd(line,available ? (IntegerToString(s.contMoveDir)) : ""); // CONT_MOVE_DIR
 CsvAdd(line,available ? (CsvD(s.pocNow.poc)) : ""); // POC_NOW
 CsvAdd(line,available ? (CsvD(s.pocNow.totalVolume)) : ""); // POC_NOW_VOLUME
 CsvAdd(line,available ? (s.pocNow.ok ? "VALID" : "INVALID") : ""); //
// POC_NOW_WINDOW_STATE
 CsvAdd(line,available ? (BStr(s.pocNow.hasTie)) : ""); // POC_NOW_TIE
 CsvAdd(line,available ? (IntegerToString(s.pocNow.tradeCount)) : ""); //
// POC_NOW_TRADE_COUNT
 CsvAdd(line,available ? (IntegerToString(s.pocNow.levels)) : ""); // POC_NOW_LEVELS
 CsvAdd(line,available ? (CsvD(s.pocNow.lastValidPrice)) : ""); // POC_NOW_LAST_PRICE
 CsvAdd(line,available ? (CsvD(s.pocNow.top1Price)) : ""); // POC_NOW_TOP1_PRICE
 CsvAdd(line,available ? (CsvD(s.pocNow.top1Vol)) : ""); // POC_NOW_TOP1_VOL
 CsvAdd(line,available ? (s.pocNow.levels >= 2 ? CsvD(s.pocNow.top2Price) : "") : ""); //
// POC_NOW_TOP2_PRICE
 CsvAdd(line,available ? (s.pocNow.levels >= 2 ? CsvD(s.pocNow.top2Vol) : "") : ""); //
// POC_NOW_TOP2_VOL
 CsvAdd(line,available ? (CsvD(s.pocNow.dominance)) : ""); // POC_NOW_DOMINANCE
 CsvAdd(line,available ? (CsvD(s.pocNow.buyVol)) : ""); // AGG_BUY_NOW
 CsvAdd(line,available ? (CsvD(s.pocNow.sellVol)) : ""); // AGG_SELL_NOW
 CsvAdd(line,available ? (CsvD(s.pocNow.unkVol)) : ""); // AGG_UNKNOWN_NOW
   CsvAdd(line,available ? (CsvD(s.pocNow.buyVol - s.pocNow.sellVol)) : ""); //
// AGG_DELTA_NOW
   CsvAdd(line,available ? ((s.pocNow.buyVol + s.pocNow.sellVol > 0.0) ?
CsvD((s.pocNow.buyVol - s.pocNow.sellVol)/(s.pocNow.buyVol + s.pocNow.sellVol)) : "") : "");
// AGG_IMBALANCE_NOW
   CsvAdd(line,available ? ((s.pocNow.buyVol + s.pocNow.sellVol + s.pocNow.unkVol > 0.0) ?
CsvD((s.pocNow.buyVol + s.pocNow.sellVol)/(s.pocNow.buyVol + s.pocNow.sellVol +
s.pocNow.unkVol)) : "") : ""); // AGG_KNOWN_PCT_NOW
   CsvAdd(line,available ? (CsvD(s.pocPrev.poc)) : ""); // POC_PREV
   CsvAdd(line,available ? (CsvD(s.pocPrev.totalVolume)) : ""); // POC_PREV_VOLUME
   CsvAdd(line,available ? (s.pocPrev.ok ? "VALID" : "INVALID") : ""); //
// POC_PREV_WINDOW_STATE
   CsvAdd(line,available ? (BStr(s.pocPrev.hasTie)) : ""); // POC_PREV_TIE
   CsvAdd(line,available ? (IntegerToString(s.pocPrev.tradeCount)) : ""); //
// POC_PREV_TRADE_COUNT
   CsvAdd(line,available ? (IntegerToString(s.pocPrev.levels)) : ""); // POC_PREV_LEVELS
   CsvAdd(line,available ? (CsvD(s.pocPrev.lastValidPrice)) : ""); //
// POC_PREV_LAST_PRICE
   CsvAdd(line,available ? (CsvD(s.pocPrev.top1Price)) : ""); // POC_PREV_TOP1_PRICE
   CsvAdd(line,available ? (CsvD(s.pocPrev.top1Vol)) : ""); // POC_PREV_TOP1_VOL
   CsvAdd(line,available ? (s.pocPrev.levels >= 2 ? CsvD(s.pocPrev.top2Price) : "") : ""); //
// POC_PREV_TOP2_PRICE
   CsvAdd(line,available ? (s.pocPrev.levels >= 2 ? CsvD(s.pocPrev.top2Vol) : "") : ""); //
// POC_PREV_TOP2_VOL
   CsvAdd(line,available ? (CsvD(s.pocPrev.dominance)) : ""); // POC_PREV_DOMINANCE
   CsvAdd(line,available ? (CsvD(s.pocPrev.buyVol)) : ""); // AGG_BUY_PREV
   CsvAdd(line,available ? (CsvD(s.pocPrev.sellVol)) : ""); // AGG_SELL_PREV
   CsvAdd(line,available ? (CsvD(s.pocPrev.unkVol)) : ""); // AGG_UNKNOWN_PREV
   CsvAdd(line,available ? (CsvD(s.pocPrev.buyVol - s.pocPrev.sellVol)) : ""); //
// AGG_DELTA_PREV
   CsvAdd(line,available ? ((s.pocPrev.buyVol + s.pocPrev.sellVol > 0.0) ?
CsvD((s.pocPrev.buyVol - s.pocPrev.sellVol)/(s.pocPrev.buyVol + s.pocPrev.sellVol)) : "") :
""); // AGG_IMBALANCE_PREV
   CsvAdd(line,available ? ((s.pocPrev.buyVol + s.pocPrev.sellVol + s.pocPrev.unkVol > 0.0) ?
CsvD((s.pocPrev.buyVol + s.pocPrev.sellVol)/(s.pocPrev.buyVol + s.pocPrev.sellVol +
s.pocPrev.unkVol)) : "") : ""); // AGG_KNOWN_PCT_PREV
   CsvAdd(line,available ? (flowRegime) : ""); // FLOW_REGIME
   CsvAdd(line,available ? (CsvD(s.pocPrev.totalVolume > 0.0 ?
s.pocNow.totalVolume/s.pocPrev.totalVolume : 0.0)) : ""); // VOL_RATIO
   CsvAdd(line,available ? (CsvD(s.minDispl > 0.0 ? MathAbs(s.priceMove)/s.minDispl : 0.0))
: ""); // PRICE_EFFICIENCY
  CsvAdd(line,available ? (CsvD(MathAbs(s.priceMove) > 0.0 ?
MathAbs(s.pocMove)/MathAbs(s.priceMove) : 0.0)) : ""); // POC_RESPONSE
}
void BookResearchTimer()
{
   if(!Inp_ResearchEnable || !gBookResearchReady)return;
   ulong began=GetMicrosecondCount();
   int n=0;
   while(BookResearchEnabled() && gBookResearchCaptureCount>0 && n++<8 && GetMicrosecondCount()-began<BOOK_RESEARCH_TIMER_US)
   {
      BookResearchCapture c=gBookResearchCaptures[gBookResearchCaptureHead];
      gBookResearchCaptureHead=(gBookResearchCaptureHead+1)%BOOK_RESEARCH_CAPTURE_CAP;gBookResearchCaptureCount--;
      string header="",values="",macro="";
      CsvMatrixHeader(header);BookResearchMatrixRow(values,c.snapshot,true,(datetime)c.candidate.signal_bar,c.sigma,c.d1,c.h1,c.l1);
      // Serialize the FROZEN macro object, not current mutable macro globals.
      macro="{\"status\":"+(string)(int)c.macro.status+",\"bar\":"+(string)(long)c.macro.barTime+
         ",\"price\":"+BookResearchDecimal(c.macro.closedPrice)+",\"vwap\":"+BookResearchDecimal(c.macro.vwap)+
         ",\"sigma\":"+BookResearchDecimal(c.macro.SigmaD1)+",\"posrel\":"+BookResearchDecimal(c.macro.posRel)+
         ",\"abs_dir\":"+(string)c.macro.macroAbsDir+",\"cont_dir\":"+(string)c.macro.macroContDir+"}";
      string context="{\"declared_version\":\"1.125\",\"build_id\":"+BookResearchJson(BOOK_BUILD_ID)+
         ",\"revision_at_generation\":"+BookResearchJson(BOOK_REVISION_AT_GENERATION)+",\"matrix_csv_header\":"+BookResearchJson(header)+",\"matrix_csv_row\":"+BookResearchJson(values)+
         ",\"macro\":"+macro+",\"region_high\":"+BookResearchDecimal(c.region_high)+",\"region_low\":"+BookResearchDecimal(c.region_low)+
         ",\"preset_hash\":"+BookResearchJson(gBookConfigHash)+",\"accounting_unresolved\":"+BookResearchBool(c.accounting)+
         ",\"open_position\":"+BookResearchBool(c.open_position)+",\"pending\":"+BookResearchBool(c.pending)+
         ",\"daily_block\":"+BookResearchBool(c.daily_block)+",\"quota\":"+(string)c.quota+
         ",\"free_margin\":"+BookResearchDecimal(c.free_margin)+",\"equity\":"+BookResearchDecimal(c.equity)+"}";
      BookResearchRuntimeCandidate(c.candidate,c.subtype,c.eligibility,c.reason,context,c.possible);
   }
   n=0;
   while(BookResearchEnabled() && gBookResearchCaptureCount==0 && gBookResearchEvidenceCount>0 && n++<8 && GetMicrosecondCount()-began<BOOK_RESEARCH_TIMER_US)
   {
      BookResearchEvidenceCapture e=gBookResearchEvidenceCaptures[gBookResearchEvidenceHead];
      BookResearchRuntimeReferenceContext(gBookResearchReferenceCaptures[gBookResearchEvidenceHead],gBookResearchReferenceAvailable[gBookResearchEvidenceHead],
         e.signal_generation,e.collector_epoch,e.data_version,e.covered);
      gBookResearchEvidenceHead=(gBookResearchEvidenceHead+1)%BOOK_RESEARCH_CAPTURE_CAP;gBookResearchEvidenceCount--;
      BookResearchRuntimeEvidence(e.id,e.evidence,e.verdict,e.direction,e.cont,e.bound,e.available,e.dispatch?"ACTUAL_OPERATIONAL_APPLY_DISPATCH":"ACTUAL_OPERATIONAL_APPLY_STATE");
   }
   n=0;
   while(BookResearchEnabled() && gBookResearchCaptureCount==0 && gBookResearchDispatchCount>0 && n++<8 && GetMicrosecondCount()-began<BOOK_RESEARCH_TIMER_US)
   {
      BookResearchDispatchCapture d=gBookResearchDispatches[gBookResearchDispatchHead];
      gBookResearchDispatchHead=(gBookResearchDispatchHead+1)%BOOK_RESEARCH_CAPTURE_CAP;gBookResearchDispatchCount--;
      BookResearchRuntimeReal(d.id,"REAL_ENTRY_API_RESULT",d.now,Symbol(),"",(string)d.result.order,(string)d.result.deal,
         d.price,d.result.price,d.sl,d.tp,0,0,0,0,0,0,0,false,"",false,false,
         "request_id="+(string)d.result.request_id+";retcode="+(string)d.retcode+";sent="+BookResearchBool(d.sent)+
         ";requested_lots="+BookResearchDecimal(d.lots)+";pricing_quote_msc="+(string)d.pricing_quote_msc+";API result is not reconciled financial PnL",-1,d.pricing_quote_msc);
   }
   BookResearchRuntimeTimer();
   MqlDateTime dt;TimeToStruct(TimeTradeServer(),dt);
   if(dt.hour*100+dt.min>=Inp_EOD_CloseHHMM)BookResearchRuntimeEndSession("EOD_INCOMPLETE");
}
void BookResearchDeinit(const int reason)
{
   if(!Inp_ResearchEnable)return;
   BookResearchHealth("COST","LOCAL_MEASUREMENTS",
      "callback_calls="+(string)gBookResearchCallbackCalls+";callback_total_us="+(string)gBookResearchCallbackUS+
      ";callback_max_us="+(string)gBookResearchCallbackMaxUS+";borrow_calls="+(string)gBookResearchBorrowCalls+
      ";borrow_total_us="+(string)gBookResearchBorrowUS+";borrow_max_us="+(string)gBookResearchBorrowMaxUS+
      ";capture_discarded="+(string)gBookResearchDropped+";mql_memory_used_mb="+(string)MQLInfoInteger(MQL_MEMORY_USED)+";not_a_proven_MT5_latency_bound");
   BookResearchRuntimeDeinit(reason);
}
#ifdef __cplusplus
void BookResearchBorrowedTicks(ulong from,ulong to,const MqlTick ticks[],int count)
#else
void BookResearchBorrowedTicks(ulong from,ulong to,const MqlTick &ticks[],int count)
#endif
{
   if(!BookResearchEnabled())return;
   ulong began=GetMicrosecondCount();BookResearchRuntimeBorrow(from,to,ticks,count);
   ulong elapsed=GetMicrosecondCount()-began;gBookResearchBorrowCalls++;gBookResearchBorrowUS+=elapsed;
   if(elapsed>gBookResearchBorrowMaxUS)gBookResearchBorrowMaxUS=elapsed;
}
#endif
