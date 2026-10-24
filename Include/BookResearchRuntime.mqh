#ifndef BOOK_RESEARCH_RUNTIME_MQH
#define BOOK_RESEARCH_RUNTIME_MQH
#include "BookResearchCore.mqh"
#include "BookDecisionCore.mqh"
// Research owns every mutable object below. The bridge supplies value snapshots;
// no result is returned to an execution/financial predicate. Research failure
// suspends only research. Disk I/O and quote acquisition occur ONLY on Timer.
#ifdef __cplusplus
#include <fstream>
#include <sstream>
#include <iomanip>
#include <cstdio>
#include <vector>
#endif
#define BOOK_RESEARCH_TRACK_CAP 32
#define BOOK_RESEARCH_QUEUE_CAP 128
#define BOOK_RESEARCH_SAMPLE_CAP 256
#define BOOK_RESEARCH_ROW_BYTES 65536
#define BOOK_RESEARCH_TIMER_US 3000
#define BOOK_RESEARCH_ROWS_PER_TIMER 16
#define BOOK_RESEARCH_QUOTE_CAP 2048
#define BOOK_RESEARCH_TRADE_CAP 8192
#define BOOK_RESEARCH_MAX_FILE_BYTES 67108864
#define BOOK_RESEARCH_SCHEMA "REMORA_RESEARCH_V1"
struct BookResearchEnvelope { int file;string line; };
struct BookResearchOpportunity
{
   bool used;BookResearchCandidate candidate;BookResearchTrack track;
   string subtype,eligibility,last_result,last_reason,last_track_key;
   bool operational_possible,collision,have_frozen_test,have_proven_reaction,actual_dispatch,dispatch_assessed;long pricing_quote_msc;
   BookDecisionWindow frozen_test,proven_reaction;BookDecisionRanks frozen_test_ranks;long frozen_epoch;
};
BookResearchEnvelope gBookResearchQueue[BOOK_RESEARCH_QUEUE_CAP];
BookResearchOpportunity gBookResearchOpportunities[BOOK_RESEARCH_TRACK_CAP];
struct BookResearchPendingDispatch {string id;long pricing_quote_msc,server_msc;bool used;};
BookResearchPendingDispatch gBookResearchPendingDispatches[BOOK_RESEARCH_TRACK_CAP];
BookResearchMarketSample gBookResearchSamples[BOOK_RESEARCH_SAMPLE_CAP];
MqlTick gBookResearchTrades[BOOK_RESEARCH_TRADE_CAP];
MqlTick gBookResearchTradeTail[BOOK_RESEARCH_QUOTE_CAP];
int gBookResearchQueueHead=0,gBookResearchQueueCount=0,gBookResearchSampleHead=0,gBookResearchSampleCount=0;
int gBookResearchTradeHead=0,gBookResearchTradeCount=0,gBookResearchTailCount=0;
long gBookResearchTradeFrom=0,gBookResearchCovered=0,gBookResearchCursor=0;
long gBookResearchCollectionStart=0;
struct BookResearchVwapMinute {long from_msc;double pv,volume;};
BookResearchVwapMinute gBookResearchVwapMinutes[32];
long gBookResearchReplayMSC=0,gBookResearchReplayOrdinal=0,gBookResearchTradeEpoch=0;
int gBookResearchReplayAtMSC=0;
bool gBookResearchReady=false,gBookResearchSuspended=false,gBookResearchTradeFault=false;
string gBookResearchRun="",gBookResearchPreset="",gBookResearchCode="",gBookResearchAccount="",gBookResearchMagic="",gBookResearchServer="",gBookResearchTradingPreset="";
string gBookResearchPrefix="",gBookResearchSuspendReason="",gBookResearchStateFile="";
bool gBookResearchSuspensionReported=false,gBookResearchTradeFaultReported=false;
int gBookResearchActualMode=0;
BookDecisionConfig gBookResearchConfig;
BookDecisionHistory gBookResearchHistory,gBookResearchReferenceContext;
bool gBookResearchReferenceContextAvailable=false;
long gBookResearchContextSignalGeneration=0,gBookResearchContextEpoch=0,gBookResearchContextVersion=0,gBookResearchContextCovered=0;
long gBookResearchDataVersion=0;
bool gBookResearchReferenceActual=true;
struct BookResearchReferenceArchive {BookDecisionHistory history;long from,to,epoch;bool actual,used;};
BookResearchReferenceArchive gBookResearchReferenceArchives[32];int gBookResearchArchiveNext=0;
void BookResearchArchiveWindow(const BookDecisionWindow &window,const BookDecisionHistory &history,const bool actual)
{
   if(!Inp_ResearchEnable || !gBookResearchReady || gBookResearchSuspended)return;
   int slot=gBookResearchArchiveNext;gBookResearchArchiveNext=(slot+1)%32;
   gBookResearchReferenceArchives[slot].history=history;gBookResearchReferenceArchives[slot].from=window.flow.from_msc;
   gBookResearchReferenceArchives[slot].to=window.flow.to_msc;gBookResearchReferenceArchives[slot].epoch=window.generation;
   gBookResearchReferenceArchives[slot].actual=actual;gBookResearchReferenceArchives[slot].used=true;
}
void BookResearchArchiveOperationalWindow(const BookDecisionWindow &window,const BookDecisionHistory &history)
{BookResearchArchiveWindow(window,history,true);}

BookDecisionWindow gBookResearchWindow;
struct BookResearchClosedWindow {BookDecisionWindow window;BookDecisionRanks buy_ranks,sell_ranks;};
BookResearchClosedWindow gBookResearchClosed[16];
int gBookResearchClosedHead=0,gBookResearchClosedCount=0;
bool gBookResearchWindowOpen=false;
ulong gBookResearchSequence=0,gBookResearchDropped=0,gBookResearchWritten=0,gBookResearchIOErrors=0;
ulong gBookResearchTimerUS=0,gBookResearchTimerMaxUS=0,gBookResearchAcquisitionCalls=0,gBookResearchAcquisitionRows=0;
long gBookResearchCandidateCount=0,gBookResearchRejectedCount=0,gBookResearchEligibleCount=0,gBookResearchOutcomeCount=0;
long gBookResearchDay=-1,gBookResearchLastNow=0;

string BookResearchNumber(const long value)
{
#ifdef __cplusplus
   return std::to_string(value);
#else
   return (string)value;
#endif
}
string BookResearchDecimal(const double value)
{
   if(!BookResearchFinite(value)) return "";
#ifdef __cplusplus
   std::ostringstream out;out<<std::setprecision(17)<<value;return out.str();
#else
   return StringFormat("%.17g",value);
#endif
}
string BookResearchCell(string value)
{
#ifdef __cplusplus
   size_t at=0;while((at=value.find('"',at))!=string::npos){value.insert(at,1,'"');at+=2;}
#else
   StringReplace(value,"\"","\"\"");
#endif
   return "\""+value+"\"";
}
string BookResearchBool(const bool value) { return value?"1":"0"; }
void BookResearchAdd(string &row,const string value) { row+=","+BookResearchCell(value); }
string BookResearchNames(const int file)
{
   if(file==0) return "Candidates";
   if(file==1) return "Decisions";
   if(file==2) return "Outcomes";
   if(file==3) return "Health";
   return "DailySummary";
}
string BookResearchHeader(const int file)
{
   string head="schema,event_id,run_id,candidate_id,observed_msc,symbol,account,server,magic,preset_hash,trading_preset_hash,code_hash";
   if(file==0) return head+",eligibility,reason,route,subtype,direction,mode,signal_bar,armed_at,trigger,region_high,region_low,sl_distance,tp_distance,operational_possible,collision,context_json";
   if(file==1) return head+",assessment_id,actual_mode,result,reason,evaluation_scope,phase,from_msc,to_msc,vbuy,vsell,vunknown,delta,directional_share,known_coverage,temporal_coverage,effort,effort_rank,net_rank,max_rank,resistance,eligible_refs,comparable_refs,bucket,net_ticks,max_ticks,acceptance_volume,acceptance_time,vwap_migration,evidence_age,window_epoch,signal_generation,integrity,source,batch_complete,ordered,invalid_count,ambiguous_count,known_imbalance,delta_low,delta_high,er,reference_msc,level,tolerance,first_price,last_price,total_path,observed_dwell_msc,reference_shortage,collector_epoch,data_version,acquired_through_msc,prior_history_count,same_bucket_count,matching_pressure_count,effort_comparable_count,prior_ref_min_msc,prior_ref_max_msc,prior_reference_members,reference_membership_status,operation_direction,measurement_direction,tick_size,total_path_ticks,pressure_direction";
   if(file==2) return head+",status,reason,entry_msc,entry_price,sl,tp,sl_distance,tp_distance,mae,mfe,first_touch,touch_msc,horizon_sec,market_eligible,operational_possible,collision,position_id,order_id,deal_id,request_price,actual_price,gross,commission,fee,swap,net,mae_mfe_partial,exit_reason,accounting_resolved,pnl_confirmed,details,origin_mae,origin_mfe,h60_mae,h60_mfe,h60_complete,h300_mae,h300_mfe,h300_complete,h900_mae,h900_mfe,h900_complete,sl_touch_msc,tp_touch_msc,duration_seconds,dispatch_eligible_observed,reference_kind";
   if(file==3) return head+",status,reason,queued,dropped,written,io_errors,timer_us,timer_max_us,acquisition_calls,acquisition_rows,memory_bound_bytes,details";
   return head+",day,candidates,original_eligible,matrix_rejected,outcome_events,dropped,coverage,warning";
}
bool BookResearchEnabled() { return Inp_ResearchEnable && gBookResearchReady && !gBookResearchSuspended; }
void BookResearchSuspend(const string reason)
{
   gBookResearchSuspended=true;gBookResearchSuspendReason=reason;
   // No financial error code, execution retentative, Print spam or journal call.
}
string BookResearchBase(const string candidate_id,const string symbol,const long observed_msc)
{
   string row=BOOK_RESEARCH_SCHEMA;
   BookResearchAdd(row,gBookResearchRun+"_"+BookResearchNumber((long)++gBookResearchSequence));
   BookResearchAdd(row,gBookResearchRun);BookResearchAdd(row,candidate_id);
   BookResearchAdd(row,BookResearchNumber(observed_msc));BookResearchAdd(row,symbol);
   BookResearchAdd(row,gBookResearchAccount);BookResearchAdd(row,gBookResearchServer);BookResearchAdd(row,gBookResearchMagic);
   BookResearchAdd(row,gBookResearchPreset);BookResearchAdd(row,gBookResearchTradingPreset);BookResearchAdd(row,gBookResearchCode);return row;
}
void BookResearchEnqueue(const int file,const string row)
{
   if(!BookResearchEnabled()) return;
#ifdef __cplusplus
   long size=(long)row.size();
#else
   long size=StringLen(row)*3;
#endif
   if(size>BOOK_RESEARCH_ROW_BYTES || gBookResearchQueueCount>=BOOK_RESEARCH_QUEUE_CAP)
   { gBookResearchDropped++;BookResearchSuspend(size>BOOK_RESEARCH_ROW_BYTES?"ROW_CAPACITY":"QUEUE_CAPACITY");return; }
   int slot=(gBookResearchQueueHead+gBookResearchQueueCount)%BOOK_RESEARCH_QUEUE_CAP;
   gBookResearchQueue[slot].file=file;gBookResearchQueue[slot].line=row+"\r\n";gBookResearchQueueCount++;
}
bool BookResearchWrite(const string path,const string row,const string header)
{
#ifdef __cplusplus
   std::ifstream check(path,std::ios::binary|std::ios::ate);
   long bytes=check.good()?(long)check.tellg():0;check.close();
   if(bytes>BOOK_RESEARCH_MAX_FILE_BYTES) return false;
   std::ofstream out(path,std::ios::binary|std::ios::app);if(!out) return false;
   if(bytes==0 && !header.empty())out<<header<<"\r\n";
   out<<row;out.flush();bool good=out.good();out.close();return good;
#else
   ResetLastError();int handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_BIN|FILE_SHARE_READ);
   if(handle==INVALID_HANDLE) return false;
   ulong size=FileSize(handle);bool ok=GetLastError()==0 && size<=BOOK_RESEARCH_MAX_FILE_BYTES;
   string payload=(size==0 && header!=""?header+"\r\n":"")+row;
   uchar encoded[];int count=StringToCharArray(payload,encoded,0,WHOLE_ARRAY,CP_UTF8)-1;
   if(count<=0 || !FileSeek(handle,0,SEEK_END)) ok=false;
   if(ok){ResetLastError();uint written=FileWriteArray(handle,encoded,0,count);ok=written==(uint)count && GetLastError()==0;}
   ResetLastError();FileFlush(handle);if(GetLastError()!=0)ok=false;
   ResetLastError();FileClose(handle);if(GetLastError()!=0)ok=false;return ok;
#endif
}
void BookResearchHealth(const string status,const string reason,const string details)
{
   string row=BookResearchBase("","",gBookResearchLastNow);
   BookResearchAdd(row,status);BookResearchAdd(row,reason);
   BookResearchAdd(row,BookResearchNumber(gBookResearchQueueCount));BookResearchAdd(row,BookResearchNumber((long)gBookResearchDropped));
   BookResearchAdd(row,BookResearchNumber((long)gBookResearchWritten));BookResearchAdd(row,BookResearchNumber((long)gBookResearchIOErrors));
   BookResearchAdd(row,BookResearchNumber((long)gBookResearchTimerUS));BookResearchAdd(row,BookResearchNumber((long)gBookResearchTimerMaxUS));
   BookResearchAdd(row,BookResearchNumber((long)gBookResearchAcquisitionCalls));BookResearchAdd(row,BookResearchNumber((long)gBookResearchAcquisitionRows));
   BookResearchAdd(row,"16777216");BookResearchAdd(row,details);BookResearchEnqueue(3,row);
}
void BookResearchDaily(const long day)
{
   string row=BookResearchBase("","",gBookResearchLastNow);BookResearchAdd(row,BookResearchNumber(day));
   BookResearchAdd(row,BookResearchNumber(gBookResearchCandidateCount));BookResearchAdd(row,BookResearchNumber(gBookResearchEligibleCount));
   BookResearchAdd(row,BookResearchNumber(gBookResearchRejectedCount));BookResearchAdd(row,BookResearchNumber(gBookResearchOutcomeCount));
   BookResearchAdd(row,BookResearchNumber((long)gBookResearchDropped));
   BookResearchAdd(row,gBookResearchDropped>0?"INCOMPLETE":"OBSERVED_CALLBACKS_AND_VERIFIED_QUOTE_SEGMENTS");
   BookResearchAdd(row,"Descriptive only; quote barriers are not fills or portfolio returns; use offline denominators and explicit costs");
   BookResearchEnqueue(4,row);
}

// Prefix verification uses ordinal positions, never equality as identity. Two
// identical rows at one millisecond remain two trades. Bounds cannot certify a
// full timestamp group when the query has hit its capacity.
bool BookResearchSameTick(const MqlTick &a,const MqlTick &b)
{
   return a.time==b.time && a.time_msc==b.time_msc && a.bid==b.bid && a.ask==b.ask &&
      a.last==b.last && a.volume==b.volume && a.volume_real==b.volume_real && a.flags==b.flags;
}
void BookResearchOpenWindow(const long from,const double level,const long reference,
   const double previous,const bool previous_available)
{
   long width=(long)gBookResearchConfig.window_sec*1000;
   BookDecisionWindowReset(gBookResearchWindow,from,from+width-1,level,gBookResearchConfig.tick_size,
      reference,previous,previous_available,gBookResearchConfig.source,(int)((from/1800000)%48),gBookResearchTradeEpoch);
   gBookResearchWindowOpen=true;
}
void BookResearchCloseWindow()
{
   BookResearchClosedWindow item;item.window=gBookResearchWindow;item.window.complete=true;
   BookDecisionCompare(gBookResearchConfig,gBookResearchHistory,item.window,1,item.buy_ranks);
   BookDecisionCompare(gBookResearchConfig,gBookResearchHistory,item.window,-1,item.sell_ranks);
   int slot=(gBookResearchClosedHead+gBookResearchClosedCount)%16;
   if(gBookResearchClosedCount==16){slot=gBookResearchClosedHead;gBookResearchClosedHead=(slot+1)%16;}
   else gBookResearchClosedCount++;
   gBookResearchClosed[slot]=item;
   // CURRENT sample is compared before entering the historical reference set.
   BookResearchArchiveWindow(item.window,gBookResearchHistory,false);
   BookDecisionHistoryInsert(gBookResearchConfig,gBookResearchHistory,item.window);
   double volume=item.window.vb+item.window.vs+item.window.vu;
   BookResearchOpenWindow(item.window.flow.to_msc+1,item.window.flow.last,item.window.flow.last_msc,
      volume>0?item.window.pv/volume:0,volume>0);
}
bool BookResearchAdvance(const long through)
{
   int count=0;
   while(gBookResearchWindowOpen && through>gBookResearchWindow.flow.to_msc)
   {
      if(++count>64){gBookResearchTradeFault=true;BookResearchHealth("DATA_GAP","REGULAR_WINDOW_GAP","");return false;}
      BookResearchCloseWindow();
   }
   return true;
}
#ifdef __cplusplus
void BookResearchRuntimeIngest(ulong from,ulong to,const MqlTick ticks[],int copied)
#else
void BookResearchRuntimeIngest(ulong from,ulong to,const MqlTick &ticks[],int copied)
#endif
{
   if(!BookResearchEnabled() || gBookResearchTradeFault || (long)to<gBookResearchCovered) return;
   if(copied<0 || copied>BOOK_RESEARCH_TRADE_CAP || to<from ||
      (long)from>gBookResearchCovered+1){gBookResearchTradeFault=true;return;}
   int seen=0;long previous=-1;
   for(int i=0;i<copied;i++)
   {
      const MqlTick q=ticks[i];
      if(q.time_msc<(long)from || q.time_msc>(long)to || q.time_msc<previous ||
         q.time!=q.time_msc/1000 || !BookResearchFinite(q.last) || q.last<=0 || q.volume==0 ||
         q.volume>9007199254740992 || !BookResearchFinite(q.volume_real) || q.volume_real<0 ||
         (q.flags&(TICK_FLAG_LAST|TICK_FLAG_VOLUME|TICK_FLAG_BUY|TICK_FLAG_SELL))==0)
      {gBookResearchTradeFault=true;return;}
      previous=q.time_msc;
      if(q.time_msc==gBookResearchCursor)
      {
         if(seen<gBookResearchTailCount && !BookResearchSameTick(q,gBookResearchTradeTail[seen]))
         {gBookResearchTradeFault=true;return;}
         seen++;
      }
   }
   if(gBookResearchTailCount>0 && (long)from<=gBookResearchCursor && (long)to>=gBookResearchCursor && seen<gBookResearchTailCount)
   {gBookResearchTradeFault=true;return;}
   int ordinal=0;long group=-1;
   for(int i=0;i<copied;i++)
   {
      const MqlTick q=ticks[i];
      if(q.time_msc<gBookResearchCursor || q.time_msc<gBookResearchTradeFrom) continue;
      if(q.time_msc!=group){group=q.time_msc;ordinal=0;}ordinal++;
      if(q.time_msc==gBookResearchCursor && ordinal<=gBookResearchTailCount)continue;
      if(q.time_msc<gBookResearchCovered || !BookResearchAdvance(q.time_msc))
      {gBookResearchTradeFault=true;return;}
      if(q.time_msc!=gBookResearchCursor){gBookResearchCursor=q.time_msc;gBookResearchTailCount=0;}
      if(gBookResearchTailCount>=BOOK_RESEARCH_QUOTE_CAP){gBookResearchTradeFault=true;return;}
      gBookResearchTradeTail[gBookResearchTailCount++]=q;
      int slot=(gBookResearchTradeHead+gBookResearchTradeCount)%BOOK_RESEARCH_TRADE_CAP;
      if(gBookResearchTradeCount==BOOK_RESEARCH_TRADE_CAP)
      {slot=gBookResearchTradeHead;gBookResearchTradeFrom=gBookResearchTrades[slot].time_msc+1;gBookResearchTradeHead=(slot+1)%BOOK_RESEARCH_TRADE_CAP;}
      else gBookResearchTradeCount++;
      gBookResearchTrades[slot]=q;gBookResearchDataVersion++;
      long minute=(q.time_msc/60000)*60000;int minute_slot=(int)((minute/60000)%32);
      if(gBookResearchVwapMinutes[minute_slot].from_msc!=minute)
      {gBookResearchVwapMinutes[minute_slot].from_msc=minute;gBookResearchVwapMinutes[minute_slot].pv=0;gBookResearchVwapMinutes[minute_slot].volume=0;}
      gBookResearchVwapMinutes[minute_slot].pv+=q.last*(double)q.volume;
      gBookResearchVwapMinutes[minute_slot].volume+=(double)q.volume;
      bool buy=(q.flags&TICK_FLAG_BUY)!=0,sell=(q.flags&TICK_FLAG_SELL)!=0;
      BookDecisionWindowTick(gBookResearchWindow,q.last,(double)q.volume,q.time_msc,buy?(sell?2:1):(sell?-1:0));
   }
   if((long)to>gBookResearchCovered)gBookResearchDataVersion++;
   gBookResearchCovered=(long)to;BookResearchAdvance(gBookResearchCovered);
}
// Borrowed batches are copied, then processed by the timer. Oversized borrowed
// windows are skipped explicitly; the bounded incremental cursor fills suffixes.
MqlTick gBookResearchBorrowed[BOOK_RESEARCH_QUOTE_CAP];
int gBookResearchBorrowedCount=0;ulong gBookResearchBorrowedFrom=0,gBookResearchBorrowedTo=0;
#ifdef __cplusplus
void BookResearchRuntimeBorrow(ulong from,ulong to,const MqlTick ticks[],int copied)
#else
void BookResearchRuntimeBorrow(ulong from,ulong to,const MqlTick &ticks[],int copied)
#endif
{
   if(!BookResearchEnabled())return;
   if(copied<0 || copied>BOOK_RESEARCH_QUOTE_CAP || gBookResearchBorrowedCount>0)return;
   for(int i=0;i<copied;i++)gBookResearchBorrowed[i]=ticks[i];
   gBookResearchBorrowedCount=copied;gBookResearchBorrowedFrom=from;gBookResearchBorrowedTo=to;
}
bool BookResearchRuntimeLiveVwap(const double base_pv,const double base_volume,
   const long from,const long through,double &value)
{
   value=0;
   if(!BookResearchEnabled() || gBookResearchTradeFault || from<gBookResearchCollectionStart ||
      through>gBookResearchCovered || from<=0 || base_volume<=0 || through<gBookResearchTradeFrom)return false;
   double pv=base_pv,volume=base_volume;
   // Closed-cache VWAP bases are M1 boundaries. Minute aggregates retain the
   // exact ordinal-ingested suffix even after old raw trades leave the tape.
   if(from%60000==0)
   {
      long last_minute=(through/60000)*60000;
      if(last_minute-from>=32*60000)return false;
      for(int k=0;k<32;k++)
      {BookResearchVwapMinute bucket=gBookResearchVwapMinutes[k];
       if(bucket.from_msc>=from && bucket.from_msc<=last_minute){pv+=bucket.pv;volume+=bucket.volume;}}
      // Data acquired later is subtracted using retained raw rows; never use
      // its price/volume to reconstruct an earlier callback's live VWAP.
      for(int i=0;i<gBookResearchTradeCount;i++)
      {MqlTick q=gBookResearchTrades[(gBookResearchTradeHead+i)%BOOK_RESEARCH_TRADE_CAP];
       if(q.time_msc>through && q.time_msc<last_minute+60000){pv-=q.last*(double)q.volume;volume-=(double)q.volume;}}
   }
   else
   {
      if(from<gBookResearchTradeFrom)return false;
      for(int i=0;i<gBookResearchTradeCount;i++)
      {MqlTick q=gBookResearchTrades[(gBookResearchTradeHead+i)%BOOK_RESEARCH_TRADE_CAP];
       if(q.time_msc<from || q.time_msc>through)continue;pv+=q.last*(double)q.volume;volume+=(double)q.volume;}
   }
   if(volume<=0 || !BookResearchFinite(pv) || !BookResearchFinite(volume))return false;
   value=pv/volume;return value>0;
}
int BookResearchFind(const string id)
{
   for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++)if(gBookResearchOpportunities[i].used &&
      gBookResearchOpportunities[i].candidate.id==id)return i;
   return -1;
}
// Immediate memory-only witness prevents a delayed disk queue from treating
// the candidate's own just-dispatched position as a competing hypothetical.
void BookResearchMarkActualDispatch(const string id,const long pricing_quote_msc,const long server_msc)
{
   if(!BookResearchEnabled())return;
   int index=BookResearchFind(id);
   if(index>=0)
   {
      gBookResearchOpportunities[index].actual_dispatch=true;
      gBookResearchOpportunities[index].pricing_quote_msc=pricing_quote_msc;
      gBookResearchOpportunities[index].track.stage2_demonstrated=true;
      gBookResearchOpportunities[index].track.original_ended=true;
      gBookResearchOpportunities[index].track.original_reason="ACTUAL_DISPATCH_ALREADY_OBSERVED";
      gBookResearchOpportunities[index].track.reason="ACTUAL_DISPATCH_ALREADY_OBSERVED";return;
   }
   for(int k=0;k<BOOK_RESEARCH_TRACK_CAP;k++)
      if(!gBookResearchPendingDispatches[k].used || gBookResearchPendingDispatches[k].id==id)
      {gBookResearchPendingDispatches[k].used=true;gBookResearchPendingDispatches[k].id=id;
       gBookResearchPendingDispatches[k].pricing_quote_msc=pricing_quote_msc;gBookResearchPendingDispatches[k].server_msc=server_msc;return;}
   gBookResearchDropped++;BookResearchSuspend("PENDING_DISPATCH_ID_CAPACITY");
}
void BookResearchRuntimeCandidate(const BookResearchCandidate &candidate,const string subtype,
   const string eligibility,const string reason,const string frozen_context,const bool operational_possible)
{
   if(!BookResearchEnabled() || BookResearchFind(candidate.id)>=0)return;
   int slot=-1;bool collision=false;
   for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++)
   {
      if(!gBookResearchOpportunities[i].used || gBookResearchOpportunities[i].track.stage==RESEARCH_FINISHED)
      {if(slot<0)slot=i;}
      else if(gBookResearchOpportunities[i].track.entry_reference_available)collision=true;
   }
   if(slot<0){gBookResearchDropped++;BookResearchSuspend("TRACK_CAPACITY");return;}
   BookResearchOpportunity o;ZeroMemory(o);o.used=true;o.candidate=candidate;o.subtype=subtype;o.eligibility=eligibility;
   o.operational_possible=operational_possible;o.collision=collision;o.last_result="";o.last_reason="";o.last_track_key="";
   BookResearchTrackReset(o.track);o.have_frozen_test=false;o.have_proven_reaction=false;o.frozen_epoch=0;gBookResearchOpportunities[slot]=o;
   for(int k=0;k<BOOK_RESEARCH_TRACK_CAP;k++)if(gBookResearchPendingDispatches[k].used && gBookResearchPendingDispatches[k].id==candidate.id)
   {BookResearchMarkActualDispatch(candidate.id,gBookResearchPendingDispatches[k].pricing_quote_msc,gBookResearchPendingDispatches[k].server_msc);gBookResearchPendingDispatches[k].used=false;break;}

   gBookResearchCandidateCount++;
   if(candidate.original_eligible)gBookResearchEligibleCount++;else gBookResearchRejectedCount++;
   string row=BookResearchBase(candidate.id,candidate.symbol,candidate.created_msc);
   BookResearchAdd(row,eligibility);BookResearchAdd(row,reason);BookResearchAdd(row,candidate.route);
   BookResearchAdd(row,subtype);BookResearchAdd(row,BookResearchNumber(candidate.direction));BookResearchAdd(row,candidate.mode);
   BookResearchAdd(row,BookResearchNumber(candidate.signal_bar));BookResearchAdd(row,BookResearchNumber(candidate.armed_at_sec));
   BookResearchAdd(row,candidate.original_eligible?BookResearchDecimal(candidate.trigger):"");BookResearchAdd(row,candidate.original_eligible?BookResearchDecimal(candidate.region_high):"");BookResearchAdd(row,candidate.original_eligible?BookResearchDecimal(candidate.region_low):"");
   BookResearchAdd(row,BookResearchDecimal(candidate.sl_distance));BookResearchAdd(row,BookResearchDecimal(candidate.tp_distance));
   BookResearchAdd(row,BookResearchBool(operational_possible));BookResearchAdd(row,BookResearchBool(collision));
   BookResearchAdd(row,frozen_context);BookResearchEnqueue(0,row);
   if(!candidate.original_eligible)
   {gBookResearchOpportunities[slot].track.original_ended=true;gBookResearchOpportunities[slot].track.original_reason=reason;}
}
string BookResearchResult(const ENUM_BOOK_DECISION_RESULT result)
{
   if((int)result<0)return "NOT_EVALUATED";
   if(result==DECISION_VALIDAR)return "VALIDAR";if(result==DECISION_AGUARDAR)return "AGUARDAR";
   if(result==DECISION_VETAR_CANDIDATO)return "VETAR_CANDIDATO";if(result==DECISION_INVALIDAR_ARMED)return "INVALIDAR_ARMED";
   return "DADOS_INSUFICIENTES";
}
// Read-only copied reference membership is attached on Timer, never by the
// operational predicate or dispatch. An unavailable membership stays unknown.
void BookResearchRuntimeReferenceContext(const BookDecisionHistory &history,const bool available,
   const long signal_generation,const long epoch,const long data_version,const long covered,const bool actual=true)
{
   if(!BookResearchEnabled())return;
   gBookResearchReferenceContextAvailable=available;gBookResearchReferenceActual=actual;
   if(available)gBookResearchReferenceContext=history;
   gBookResearchContextSignalGeneration=signal_generation;gBookResearchContextEpoch=epoch;
   gBookResearchContextVersion=data_version;gBookResearchContextCovered=covered;
}
void BookResearchReferenceCells(const BookDecisionWindow &w,const BookDecisionRanks &r,const int direction,
   const bool have,const string phase,string &shortage,string &cells)
{
   shortage="REFERENCE_MEMBERSHIP_UNAVAILABLE";cells="";
   int prior=0,bucket=0,pressure=0,comparable=0;long oldest=0,newest=0;string members="";
   BookDecisionHistory membership;bool have_membership=gBookResearchReferenceContextAvailable;string membership_status="ASSESSMENT_SNAPSHOT";
   if(have_membership)membership=gBookResearchReferenceContext;
   for(int k=0;k<32;k++)if(gBookResearchReferenceArchives[k].used && gBookResearchReferenceArchives[k].actual==gBookResearchReferenceActual &&
      gBookResearchReferenceArchives[k].from==w.flow.from_msc && gBookResearchReferenceArchives[k].to==w.flow.to_msc &&
      gBookResearchReferenceArchives[k].epoch==w.generation)
   {membership=gBookResearchReferenceArchives[k].history;have_membership=true;membership_status="EXACT_WINDOW_CLOSE_SNAPSHOT";break;}

   BookMicroMetrics m;ZeroMemory(m);int geometry=phase=="T"?-direction:direction;
   bool quality=have && BookDecisionWindowQuality(gBookResearchConfig,w,m,geometry);
   if(have && have_membership && phase!="R")
   {
      double effort=BookResearchAbs(w.vb-w.vs),low=effort/gBookResearchConfig.effort_factor,high=effort*gBookResearchConfig.effort_factor;
      for(int k=0;k<membership.count;k++)
      {
         BookDecisionReference item=membership.samples[k];
         if(item.to_msc>=w.flow.from_msc || item.generation!=w.generation || item.source!=w.source ||
            item.tick_size!=gBookResearchConfig.tick_size || item.duration!=(long)gBookResearchConfig.window_sec*1000 || item.direction!=geometry)continue;
         prior++;if(item.bucket!=w.bucket)continue;bucket++;
         if(item.pressure_direction!=m.pressure_direction)continue;pressure++;
         if(item.effort<low || item.effort>high)continue;comparable++;
         if(oldest==0 || item.from_msc<oldest)oldest=item.from_msc;if(item.to_msc>newest)newest=item.to_msc;
         if(members!="")members+=";";
         members+=BookResearchNumber(item.from_msc)+":"+BookResearchNumber(item.to_msc)+":"+BookResearchNumber(item.source)+":"+
            BookResearchNumber(item.bucket)+":"+BookResearchNumber(item.direction)+":"+BookResearchNumber(item.pressure_direction)+":"+
            BookResearchDecimal(item.tick_size)+":"+BookResearchDecimal(item.effort)+":"+BookResearchDecimal(item.net_progress)+":"+
            BookResearchDecimal(item.max_progress)+":"+BookResearchNumber(item.generation);
      }
      if(!quality)shortage=w.ambiguous>0?"AGGRESSOR_FLAGS_AMBIGUOUS":(w.invalid>0 || !w.ordered || !w.source_ok?"INVALID_DATA":"COVERAGE_INSUFFICIENT");
      else if(!BookDecisionMaterial(gBookResearchConfig,m))shortage="IMMATERIAL_DIRECTIONAL_PRESSURE";
      else if(prior==0)shortage="NO_PRIOR_HISTORY";
      else if(bucket==0)shortage="NEW_BUCKET_NO_PRIOR_REFERENCES";
      else if(pressure<gBookResearchConfig.min_refs && bucket>=gBookResearchConfig.min_refs)shortage="MINORITY_PRESSURE_REFERENCE_SHORTAGE";
      else if(pressure<gBookResearchConfig.min_refs)shortage="PRIOR_HISTORY_REFERENCE_SHORTAGE";
      else if(comparable<gBookResearchConfig.min_refs)shortage="EFFORT_NOT_COMPARABLE";
      else shortage="SUFFICIENT";
   }
   if(!have)shortage="NO_WINDOW";else if(phase=="R")shortage="NOT_APPLICABLE_REACTION";
   BookResearchAdd(cells,gBookResearchContextEpoch>0?BookResearchNumber(gBookResearchContextEpoch):"");
   BookResearchAdd(cells,gBookResearchContextVersion>0?BookResearchNumber(gBookResearchContextVersion):"");
   BookResearchAdd(cells,gBookResearchContextCovered>0?BookResearchNumber(gBookResearchContextCovered):"");
   BookResearchAdd(cells,have && have_membership && phase!="R"?BookResearchNumber(prior):"");
   BookResearchAdd(cells,have && have_membership && phase!="R"?BookResearchNumber(bucket):"");
   BookResearchAdd(cells,have && have_membership && phase!="R"?BookResearchNumber(pressure):"");
   BookResearchAdd(cells,have && have_membership && phase!="R"?BookResearchNumber(comparable):"");
   BookResearchAdd(cells,oldest>0?BookResearchNumber(oldest):"");BookResearchAdd(cells,newest>0?BookResearchNumber(newest):"");BookResearchAdd(cells,members);
   BookResearchAdd(cells,!have || phase=="R"?"NOT_APPLICABLE":(!have_membership?"MEMBERSHIP_UNAVAILABLE":
      (r.available && (r.count!=pressure || r.conditional_count!=comparable)?"MEMBERSHIP_DOES_NOT_RECONSTRUCT_STORED_RANKS":membership_status)));
   BookResearchAdd(cells,BookResearchNumber(direction));BookResearchAdd(cells,BookResearchNumber(geometry));
   BookResearchAdd(cells,BookResearchDecimal(gBookResearchConfig.tick_size));
   BookResearchAdd(cells,have && gBookResearchConfig.tick_size>0?BookResearchDecimal(w.flow.path/gBookResearchConfig.tick_size):"");
   BookResearchAdd(cells,have && m.available?BookResearchNumber(m.pressure_direction):"");
}
void BookResearchDecisionRow(const string id,const string symbol,const BookDecisionEvidence &e,
   const BookDecisionVerdict &v,const int direction,const string scope,const string phase,
   const bool have,const BookDecisionWindow &w,const BookDecisionRanks &r,const string assessment)
{
   string row=BookResearchBase(id,symbol,e.now_msc);BookResearchAdd(row,assessment);
   BookResearchAdd(row,gBookResearchActualMode==DECISION_ORIGINAL?"ORIGINAL":"APLICAR");
   BookResearchAdd(row,BookResearchResult(v.result));BookResearchAdd(row,v.reason);BookResearchAdd(row,scope);BookResearchAdd(row,phase);
   BookMicroMetrics m;ZeroMemory(m);bool quality=false;
   int geometry=phase=="T"?-direction:direction;
   if(have)quality=BookDecisionWindowQuality(gBookResearchConfig,w,m,geometry);
   BookResearchAdd(row,have?BookResearchNumber(w.flow.from_msc):"");BookResearchAdd(row,have?BookResearchNumber(w.flow.to_msc):"");
   BookResearchAdd(row,have?BookResearchDecimal(w.vb):"");BookResearchAdd(row,have?BookResearchDecimal(w.vs):"");
   BookResearchAdd(row,have?BookResearchDecimal(w.vu):"");BookResearchAdd(row,have?BookResearchDecimal(w.vb-w.vs):"");
   BookResearchAdd(row,have && m.available?BookResearchDecimal(m.small_delta_scale):"");
   BookResearchAdd(row,have && m.ratio_available?BookResearchDecimal(m.known_coverage):"");
   BookResearchAdd(row,have && m.available?BookResearchDecimal(m.temporal_coverage):"");
   BookResearchAdd(row,have?BookResearchDecimal(BookResearchAbs(w.vb-w.vs)):"");
   BookResearchAdd(row,r.available?BookResearchDecimal(r.effort_rank):"");BookResearchAdd(row,r.available?BookResearchDecimal(r.net_rank):"");
   BookResearchAdd(row,r.available?BookResearchDecimal(r.max_rank):"");BookResearchAdd(row,r.available?BookResearchDecimal(r.resistance):"");
   BookResearchAdd(row,have && phase!="R"?BookResearchNumber(r.count):"");BookResearchAdd(row,have && phase!="R"?BookResearchNumber(r.conditional_count):"");
   BookResearchAdd(row,have?BookResearchNumber(w.bucket):"");BookResearchAdd(row,quality?BookResearchDecimal(m.net_ticks):"");
   BookResearchAdd(row,quality?BookResearchDecimal(m.max_ticks):"");BookResearchAdd(row,quality && m.level_available?BookResearchDecimal(m.acceptance_volume_ratio):"");
   BookResearchAdd(row,quality && m.time_available?BookResearchDecimal(m.acceptance_time_ratio):"");
   double total=w.vb+w.vs+w.vu;
   BookResearchAdd(row,quality && w.previous_available && total>0?BookResearchDecimal(geometry*(w.pv/total-w.previous_vwap)/gBookResearchConfig.tick_size):"");
   BookResearchAdd(row,have?BookResearchNumber(e.now_msc-w.flow.to_msc):"");BookResearchAdd(row,have?BookResearchNumber(w.generation):"");
   BookResearchAdd(row,gBookResearchContextSignalGeneration>0?BookResearchNumber(gBookResearchContextSignalGeneration):"");
   BookResearchAdd(row,!have?"UNAVAILABLE":(quality?"QUALIFIED_RUNTIME_HYPOTHESIS":"INVALID_OR_INSUFFICIENT"));
   BookResearchAdd(row,have?BookResearchNumber(w.source):"");
   BookResearchAdd(row,have?BookResearchBool(w.complete):"");BookResearchAdd(row,have?BookResearchBool(w.ordered):"");
   BookResearchAdd(row,have?BookResearchNumber(w.invalid):"");BookResearchAdd(row,have?BookResearchNumber(w.ambiguous):"");
   double known=w.vb+w.vs;BookResearchAdd(row,have && known>0?BookResearchDecimal((w.vb-w.vs)/known):"");
   BookResearchAdd(row,have?BookResearchDecimal(w.vb-w.vs-w.vu):"");BookResearchAdd(row,have?BookResearchDecimal(w.vb-w.vs+w.vu):"");
   BookResearchAdd(row,have && m.er_available?BookResearchDecimal(m.efficiency):"");
   BookResearchAdd(row,have?BookResearchNumber(w.flow.reference_msc):"");BookResearchAdd(row,have && w.flow.level_available?BookResearchDecimal(w.flow.level):"");
   BookResearchAdd(row,have?BookResearchDecimal(w.flow.tolerance):"");
   BookResearchAdd(row,have && w.flow.count>0?BookResearchDecimal(w.flow.first):"");BookResearchAdd(row,have && w.flow.count>0?BookResearchDecimal(w.flow.last):"");
   BookResearchAdd(row,have?BookResearchDecimal(w.flow.path):"");BookResearchAdd(row,have?BookResearchNumber(w.flow.observed_msc):"");
   string shortage,cells;BookResearchReferenceCells(w,r,direction,have,phase,shortage,cells);
   BookResearchAdd(row,shortage);row+=cells;
   BookResearchEnqueue(1,row);
}
void BookResearchRuntimeEvidence(const string id,const BookDecisionEvidence &e,const BookDecisionVerdict &v,
   const int direction,const bool cont,const bool bound,const bool available,const string scope)
{
   if(!BookResearchEnabled())return;
   int index=BookResearchFind(id);if(index<0)return;
   // State changes or causal evidence identity changes only; repeated financial
   // revalidation does not produce an unbounded duplicate diagnostic stream.
   string stamp=BookResearchResult(v.result)+"|"+v.reason+"|"+
      BookResearchNumber(available && e.have_current?e.current.flow.from_msc:0)+"|"+scope;
   if(gBookResearchOpportunities[index].last_result==stamp)return;
   gBookResearchOpportunities[index].last_result=stamp;gBookResearchOpportunities[index].last_reason=v.reason;
   string assessment=gBookResearchRun+"_assessment_"+BookResearchNumber((long)gBookResearchSequence+1);
   string staged_scope=scope+(bound?":ARMED":":CANDIDATE");
   BookDecisionWindow empty;ZeroMemory(empty);BookDecisionRanks ranks;BookDecisionRanksReset(ranks);
   if(!available)
   {BookResearchDecisionRow(id,gBookResearchOpportunities[index].candidate.symbol,e,v,direction,staged_scope,"UNAVAILABLE",false,empty,ranks,assessment);return;}
   BookResearchDecisionRow(id,gBookResearchOpportunities[index].candidate.symbol,e,v,direction,staged_scope,"CURRENT",e.have_current,e.current,e.current_ranks,assessment);
   if(cont)BookResearchDecisionRow(id,gBookResearchOpportunities[index].candidate.symbol,e,v,direction,staged_scope,"FORWARD",e.have_forward,e.forward,e.forward_ranks,assessment);
   else
   {
      BookResearchDecisionRow(id,gBookResearchOpportunities[index].candidate.symbol,e,v,direction,staged_scope,"T",e.have_test,e.test,e.test_ranks,assessment);
      BookResearchDecisionRow(id,gBookResearchOpportunities[index].candidate.symbol,e,v,direction,staged_scope,"R",e.have_reaction,e.reaction,ranks,assessment);
   }
}
// Independent, conservative APPLY evaluation. It shares pure arithmetic, not the
// operational collector or its frozen T/cache/proofs. Missing causal reaction
// context is reported, never filled from the operational mutable ARMED.
void BookResearchShadowEvidence(const int index,const long now,const bool at_pricing_quote=false)
{
   BookResearchOpportunity o=gBookResearchOpportunities[index];
   if(!o.candidate.original_eligible || o.track.stage==RESEARCH_FINISHED ||
      (!at_pricing_quote && (o.track.original_ended || now/1000-o.candidate.armed_at_sec>=o.candidate.timeout_sec)))return;
   BookDecisionEvidence e;ZeroMemory(e);e.now_msc=now;
   e.original_subtype=o.subtype=="DIVERGENCE"?1:(o.subtype=="FOLLOWING_REACTION"?2:0);
   long width=(long)gBookResearchConfig.window_sec*1000;
   for(int k=gBookResearchClosedCount-1;k>=0;k--)
   {
      BookResearchClosedWindow item=gBookResearchClosed[(gBookResearchClosedHead+k)%16];
      if(item.window.flow.to_msc>now || now-item.window.flow.to_msc>2*width)continue;
      BookDecisionRanks ranks=o.candidate.direction==1?item.buy_ranks:item.sell_ranks;
      if(!e.have_current){e.current=item.window;e.current_ranks=ranks;e.have_current=true;}
      if(o.candidate.route=="CONT" && !e.have_forward && BookDecisionForwardPredicate(gBookResearchConfig,item.window,ranks,o.candidate.direction))
      {e.forward=item.window;e.forward_ranks=ranks;e.have_forward=true;}
      if(o.candidate.route=="ABS" && !e.have_test)
      {
         BookDecisionRanks opposite=o.candidate.direction==-1?item.buy_ranks:item.sell_ranks;
         if(BookDecisionTestPredicate(gBookResearchConfig,item.window,opposite,o.candidate.direction))
         {e.test=item.window;e.test_ranks=opposite;e.have_test=true;}
      }
   }
   if(o.have_frozen_test && o.frozen_epoch==gBookResearchTradeEpoch && BookDecisionFresh(gBookResearchConfig,o.frozen_test,now))
   {e.test=o.frozen_test;e.test_ranks=o.frozen_test_ranks;e.have_test=true;}
   else
   {
      o.have_frozen_test=false;o.have_proven_reaction=false;
      if(e.have_test){o.have_frozen_test=true;o.frozen_test=e.test;o.frozen_test_ranks=e.test_ranks;o.frozen_epoch=gBookResearchTradeEpoch;}
   }
   // Reconstruct R solely from rows after causal T, bounded by the known clock.
   if(e.have_test && e.test.flow.to_msc+1>=gBookResearchTradeFrom)
   {
      long end=0;
      for(int k=0;k<gBookResearchTradeCount;k++)
      {MqlTick q=gBookResearchTrades[(gBookResearchTradeHead+k)%BOOK_RESEARCH_TRADE_CAP];if(q.time_msc>e.test.flow.to_msc && q.time_msc<=now)end=q.time_msc;}
      if(end>e.test.flow.to_msc)
      {
         BookDecisionWindowReset(e.reaction,e.test.flow.to_msc+1,end,e.test.flow.level,gBookResearchConfig.tick_size,
            e.test.flow.to_msc,e.test.previous_vwap,e.test.previous_available,gBookResearchConfig.source,e.test.bucket,e.test.generation);
         for(int k=0;k<gBookResearchTradeCount;k++)
         {MqlTick q=gBookResearchTrades[(gBookResearchTradeHead+k)%BOOK_RESEARCH_TRADE_CAP];
          if(q.time_msc>e.test.flow.to_msc && q.time_msc<=end){bool b=(q.flags&TICK_FLAG_BUY)!=0,s=(q.flags&TICK_FLAG_SELL)!=0;
          BookDecisionWindowTick(e.reaction,q.last,(double)q.volume,q.time_msc,b?(s?2:1):(s?-1:0));}}
         e.reaction.complete=!gBookResearchTradeFault && end<=gBookResearchCovered;e.have_reaction=true;
      }
   }
   if(e.have_reaction)
   {
      if(BookDecisionReactionPredicate(gBookResearchConfig,e.test,e.reaction,o.candidate.direction))
      {o.have_proven_reaction=true;o.proven_reaction=e.reaction;}
      else if(o.have_proven_reaction && BookDecisionFresh(gBookResearchConfig,o.proven_reaction,now) &&
         e.reaction.invalid==0 && e.reaction.ambiguous==0 && e.reaction.ordered && e.reaction.source_ok &&
         (e.reaction.vb+e.reaction.vs+e.reaction.vu==0 ||
          (e.reaction.vb+e.reaction.vs)/(e.reaction.vb+e.reaction.vs+e.reaction.vu)>=gBookResearchConfig.coverage) &&
         o.candidate.direction*(e.reaction.flow.last-e.test.flow.level)/gBookResearchConfig.tick_size>=gBookResearchConfig.progress_ticks)
         e.reaction=o.proven_reaction;
   }
   // Current known prefix is reconstructed AS OF this callback. A later
   // acquired row cannot enter its window. Deficient flags cannot be hidden
   // behind a retained closed-window approval.
   long live_from=(now/width)*width;BookDecisionWindow live;
   double level=0,previous=0;long reference=0;bool previous_available=false;
   for(int k=gBookResearchClosedCount-1;k>=0;k--)
   {BookResearchClosedWindow item=gBookResearchClosed[(gBookResearchClosedHead+k)%16];
    if(item.window.flow.to_msc<live_from){double volume=item.window.vb+item.window.vs+item.window.vu;
     level=item.window.flow.last;reference=item.window.flow.last_msc;previous=volume>0?item.window.pv/volume:0;previous_available=volume>0;break;}}
   BookDecisionWindowReset(live,live_from,now,level,gBookResearchConfig.tick_size,reference,previous,previous_available,
      gBookResearchConfig.source,(int)((live_from/1800000)%48),gBookResearchTradeEpoch);
   long last_trade=0;
   for(int k=0;k<gBookResearchTradeCount;k++)
   {MqlTick q=gBookResearchTrades[(gBookResearchTradeHead+k)%BOOK_RESEARCH_TRADE_CAP];if(q.time_msc>now)continue;last_trade=q.time_msc;
    if(q.time_msc<live_from)continue;bool b=(q.flags&TICK_FLAG_BUY)!=0,sell=(q.flags&TICK_FLAG_SELL)!=0;
    BookDecisionWindowTick(live,q.last,(double)q.volume,q.time_msc,b?(sell?2:1):(sell?-1:0));}
   live.complete=!gBookResearchTradeFault && live_from>=gBookResearchTradeFrom && now<=gBookResearchCovered;
   if(live.flow.count>0)
   {
      BookMicroMetrics metrics;bool quality=BookDecisionWindowQuality(gBookResearchConfig,live,metrics,o.candidate.direction);
      double total=live.vb+live.vs+live.vu;
      bool prefix=live.complete && live.ordered && live.source_ok && live.invalid==0 && live.ambiguous==0 &&
         (total==0 || (live.vb+live.vs)/total>=gBookResearchConfig.coverage);
      if(quality || !prefix || !e.have_current)
      {e.current=live;e.have_current=true;BookDecisionCompare(gBookResearchConfig,gBookResearchHistory,live,o.candidate.direction,e.current_ranks);}
   }
   if(o.candidate.route=="ABS" && e.have_reaction && e.have_current)
   {
      BookMicroMetrics metrics;double total=e.current.vb+e.current.vs+e.current.vu;
      bool prefix=e.current.complete && e.current.ordered && e.current.source_ok && e.current.invalid==0 && e.current.ambiguous==0 &&
         (total==0 || (e.current.vb+e.current.vs)/total>=gBookResearchConfig.coverage);
      if(!BookDecisionWindowQuality(gBookResearchConfig,e.current,metrics,o.candidate.direction) && prefix &&
         BookDecisionReactionPredicate(gBookResearchConfig,e.test,e.reaction,o.candidate.direction) &&
         o.candidate.direction*(e.current.flow.last-e.test.flow.level)/gBookResearchConfig.tick_size>=gBookResearchConfig.progress_ticks)
      {e.current=e.reaction;BookDecisionRanksReset(e.current_ranks);}
   }
   gBookResearchOpportunities[index].have_frozen_test=o.have_frozen_test;
   gBookResearchOpportunities[index].have_proven_reaction=o.have_proven_reaction;
   gBookResearchOpportunities[index].frozen_test=o.frozen_test;gBookResearchOpportunities[index].frozen_test_ranks=o.frozen_test_ranks;
   gBookResearchOpportunities[index].proven_reaction=o.proven_reaction;gBookResearchOpportunities[index].frozen_epoch=o.frozen_epoch;
   BookDecisionVerdict v;BookDecisionAssess(gBookResearchConfig,e,o.candidate.direction,o.candidate.route=="CONT",true,v);
   if(gBookResearchTradeFault || now>gBookResearchCovered || last_trade<=0 || now-last_trade>2000)
   {v.result=DECISION_DADOS_INSUFICIENTES;v.reason=gBookResearchTradeFault?"RESEARCH_TRADE_INTEGRITY_FAULT":"RESEARCH_COLLECTION_BACKLOG";}
   BookResearchRuntimeReferenceContext(gBookResearchHistory,true,index+1,gBookResearchTradeEpoch,gBookResearchDataVersion,gBookResearchCovered,false);
   BookResearchRuntimeEvidence(o.candidate.id,e,v,o.candidate.direction,o.candidate.route=="CONT",true,true,at_pricing_quote?"INDEPENDENT_RESEARCH_APPLY_AT_PRICING_QUOTE_NOT_DISPATCH":"INDEPENDENT_RESEARCH_APPLY");
}
void BookResearchOutcome(const int index,const string status,const string detail)
{
   BookResearchOpportunity o=gBookResearchOpportunities[index];BookResearchTrack t=o.track;
   string row=BookResearchBase(o.candidate.id,o.candidate.symbol,t.finished_msc>0?t.finished_msc:(t.last_msc>0?t.last_msc:gBookResearchLastNow));
   BookResearchAdd(row,status);BookResearchAdd(row,t.reason);
   BookResearchAdd(row,t.entry_reference_available?BookResearchNumber(t.entry_msc):"");
   BookResearchAdd(row,t.entry_reference_available?BookResearchDecimal(t.entry):"");
   BookResearchAdd(row,t.entry_reference_available?BookResearchDecimal(t.sl):"");BookResearchAdd(row,t.entry_reference_available?BookResearchDecimal(t.tp):"");
   BookResearchAdd(row,BookResearchDecimal(t.entry_reference_available?BookResearchAbs(t.entry-t.sl):o.candidate.sl_distance));BookResearchAdd(row,BookResearchDecimal(t.entry_reference_available?BookResearchAbs(t.tp-t.entry):o.candidate.tp_distance));
   BookResearchAdd(row,t.samples>0?BookResearchDecimal(t.entry_reference_available?t.mae:t.origin_mae):"");
   BookResearchAdd(row,t.samples>0?BookResearchDecimal(t.entry_reference_available?t.mfe:t.origin_mfe):"");
   string first=t.barrier=="TP_QUOTE_TOUCH_FIRST"?"TP":(t.barrier=="SL_QUOTE_TOUCH_FIRST"?"SL":"");
   BookResearchAdd(row,first);BookResearchAdd(row,first=="TP"?BookResearchNumber(t.tp_touch_msc):(first=="SL"?BookResearchNumber(t.sl_touch_msc):""));
   BookResearchAdd(row,"900");BookResearchAdd(row,BookResearchBool(t.stage2_demonstrated));
   BookResearchAdd(row,BookResearchBool(t.dispatch_eligible_observed));BookResearchAdd(row,BookResearchBool(o.collision));
   // Real-account identifiers/economic fields remain unavailable for hypotheses.
   for(int f=0;f<12;f++)BookResearchAdd(row,"");
   BookResearchAdd(row,"0");BookResearchAdd(row,"0");
   BookResearchAdd(row,detail+";possibility="+t.possibility+";original_reason="+t.original_reason+
      ";dispatch_eligible_observed="+BookResearchBool(t.dispatch_eligible_observed)+
      ";samples="+BookResearchNumber(t.samples)+";first_sl_msc="+BookResearchNumber(t.sl_touch_msc)+
      ";first_tp_msc="+BookResearchNumber(t.tp_touch_msc));
   BookResearchAdd(row,t.samples>0?BookResearchDecimal(t.origin_mae):"");BookResearchAdd(row,t.samples>0?BookResearchDecimal(t.origin_mfe):"");
   for(int h=0;h<3;h++){BookResearchAdd(row,t.samples>0?BookResearchDecimal(t.horizon_mae[h]):"");
      BookResearchAdd(row,t.samples>0?BookResearchDecimal(t.horizon_mfe[h]):"");BookResearchAdd(row,BookResearchBool(t.horizon_done[h]));}
   BookResearchAdd(row,t.sl_touch_msc>0?BookResearchNumber(t.sl_touch_msc):"");BookResearchAdd(row,t.tp_touch_msc>0?BookResearchNumber(t.tp_touch_msc):"");
   BookResearchAdd(row,t.entry_reference_available?BookResearchDecimal((double)((t.finished_msc>0?t.finished_msc:gBookResearchLastNow)-t.entry_msc)/1000.0):"");
   BookResearchAdd(row,BookResearchBool(t.dispatch_eligible_observed));
   BookResearchAdd(row,t.entry_reference_available?(t.dispatch_eligible_observed?"HYPOTHETICAL_EXECUTABLE_QUOTE_NOT_A_FILL":"CONDITIONAL_MARKET_REFERENCE"):"NO_ENTRY_REFERENCE");
   BookResearchEnqueue(2,row);gBookResearchOutcomeCount++;
}
void BookResearchTrackChanged(const int index)
{
   BookResearchTrack t=gBookResearchOpportunities[index].track;
   string key=BookResearchNumber((long)t.stage)+"|"+t.reason+"|"+t.barrier;
   if(key==gBookResearchOpportunities[index].last_track_key)return;
   gBookResearchOpportunities[index].last_track_key=key;
   if(t.entry_reference_available)for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++)
      if(i!=index && gBookResearchOpportunities[i].used && gBookResearchOpportunities[i].track.entry_reference_available &&
         gBookResearchOpportunities[i].track.stage!=RESEARCH_FINISHED)
      {gBookResearchOpportunities[index].collision=true;gBookResearchOpportunities[i].collision=true;}
   string status=t.original_ended?t.original_reason:t.reason;
   if(t.barrier=="TP_QUOTE_TOUCH_FIRST")status="TP_FIRST";
   else if(t.barrier=="SL_QUOTE_TOUCH_FIRST")status="SL_FIRST";
   else if(t.barrier=="AMBIGUOUS_PATH")status="AMBIGUOUS_PATH";
   else if(t.stage==RESEARCH_FINISHED && t.barrier=="NO_BARRIER_OBSERVED")status="HORIZON_NO_BARRIER";
   else if(t.stage==RESEARCH_FINISHED)status=t.reason;
   BookResearchOutcome(index,status,"Quote touch only; latency/slippage/fill unproven; no financial PnL; conditional references excluded from executable ORIGINAL count");
}
void BookResearchRuntimeReal(const string candidate_id,const string status,const long now,
   const string symbol,const string position_id,const string order_id,const string deal_id,
   const double request_price,const double actual_price,const double sl,const double tp,
   const double mae,const double mfe,const double gross,const double commission,const double fee,
   const double swap,const double net,const bool partial,const string exit_reason,
   const bool accounting_resolved,const bool confirmed,const string details,const long duration_sec=-1,const long pricing_quote_msc=0)
{
   if(!BookResearchEnabled())return;
   if(status=="REAL_ENTRY_API_RESULT")BookResearchMarkActualDispatch(candidate_id,pricing_quote_msc,now);
   string row=BookResearchBase(candidate_id,symbol,now);BookResearchAdd(row,status);BookResearchAdd(row,exit_reason);
   BookResearchAdd(row,"");BookResearchAdd(row,"");BookResearchAdd(row,sl>0?BookResearchDecimal(sl):"");BookResearchAdd(row,tp>0?BookResearchDecimal(tp):"");
   BookResearchAdd(row,"");BookResearchAdd(row,"");BookResearchAdd(row,status=="REAL_RECONCILED"?BookResearchDecimal(mae):"");BookResearchAdd(row,status=="REAL_RECONCILED"?BookResearchDecimal(mfe):"");
   BookResearchAdd(row,"");BookResearchAdd(row,"");BookResearchAdd(row,"");
   BookResearchAdd(row,status=="REAL_ENTRY_API_RESULT"?"1":"");BookResearchAdd(row,status=="REAL_ENTRY_API_RESULT"?"1":"");BookResearchAdd(row,"");
   BookResearchAdd(row,position_id);BookResearchAdd(row,order_id);BookResearchAdd(row,deal_id);
   BookResearchAdd(row,request_price>0?BookResearchDecimal(request_price):"");BookResearchAdd(row,actual_price>0?BookResearchDecimal(actual_price):"");
   BookResearchAdd(row,confirmed?BookResearchDecimal(gross):"");BookResearchAdd(row,confirmed?BookResearchDecimal(commission):"");
   BookResearchAdd(row,confirmed?BookResearchDecimal(fee):"");BookResearchAdd(row,confirmed?BookResearchDecimal(swap):"");BookResearchAdd(row,confirmed?BookResearchDecimal(net):"");
   BookResearchAdd(row,BookResearchBool(partial));BookResearchAdd(row,exit_reason);
   BookResearchAdd(row,BookResearchBool(accounting_resolved));BookResearchAdd(row,BookResearchBool(confirmed));BookResearchAdd(row,details);
   for(int h=0;h<13;h++)BookResearchAdd(row,"");
   BookResearchAdd(row,duration_sec>=0?BookResearchNumber(duration_sec):"");BookResearchAdd(row,"");BookResearchAdd(row,"ACTUAL_OBSERVATION");
   BookResearchEnqueue(2,row);
}
void BookResearchRuntimeSample(const BookResearchMarketSample &sample)
{
   if(!BookResearchEnabled())return;
   if(gBookResearchSampleCount>=BOOK_RESEARCH_SAMPLE_CAP){gBookResearchDropped++;BookResearchSuspend("CONTEXT_QUEUE_CAPACITY");return;}
   int slot=(gBookResearchSampleHead+gBookResearchSampleCount)%BOOK_RESEARCH_SAMPLE_CAP;
   gBookResearchSamples[slot]=sample;gBookResearchSampleCount++;
}
struct BookResearchQuoteRecord {MqlTick tick;long ordinal;int ordinal_at_msc;};
BookResearchQuoteRecord gBookResearchQuotes[BOOK_RESEARCH_TRADE_CAP];
MqlTick gBookResearchQuoteTail[BOOK_RESEARCH_QUOTE_CAP];
int gBookResearchQuoteHead=0,gBookResearchQuoteCount=0,gBookResearchQuoteTailCount=0;
long gBookResearchQuoteCursor=0,gBookResearchQuoteCovered=0,gBookResearchQuoteOrdinal=0;
bool gBookResearchQuoteFault=false;
#ifdef __cplusplus
void BookResearchQuoteBatch(const long from,const long through,const MqlTick quotes[],const int count,const bool complete)
#else
void BookResearchQuoteBatch(const long from,const long through,const MqlTick &quotes[],const int count,const bool complete)
#endif
{
   if(!BookResearchEnabled() || gBookResearchQuoteFault)return;
   if(from>gBookResearchQuoteCovered+1 || count<0 || count>BOOK_RESEARCH_QUOTE_CAP || through<from)
   {gBookResearchQuoteFault=true;return;}
   int seen=0;long previous=-1;
   for(int k=0;k<count;k++)
   {
      MqlTick q=quotes[k];
      if(q.time_msc<from || q.time_msc>through || q.time_msc<previous || q.time!=q.time_msc/1000)
      {gBookResearchQuoteFault=true;return;}previous=q.time_msc;
      if(q.time_msc==gBookResearchQuoteCursor)
      {
         if(seen<gBookResearchQuoteTailCount && !BookResearchSameTick(q,gBookResearchQuoteTail[seen]))
         {gBookResearchQuoteFault=true;return;}seen++;
      }
   }
   if(gBookResearchQuoteTailCount>0 && from<=gBookResearchQuoteCursor && seen<gBookResearchQuoteTailCount)
   {gBookResearchQuoteFault=true;return;}
   long group=-1;int ordinal=0;
   for(int k=0;k<count;k++)
   {
      MqlTick q=quotes[k];if(q.time_msc<gBookResearchQuoteCursor)continue;
      if(q.time_msc!=group){group=q.time_msc;ordinal=0;}ordinal++;
      if(q.time_msc==gBookResearchQuoteCursor && ordinal<=gBookResearchQuoteTailCount)continue;
      if(q.time_msc<gBookResearchQuoteCovered){gBookResearchQuoteFault=true;return;}
      if(q.time_msc!=gBookResearchQuoteCursor){gBookResearchQuoteCursor=q.time_msc;gBookResearchQuoteTailCount=0;}
      if(gBookResearchQuoteTailCount>=BOOK_RESEARCH_QUOTE_CAP || gBookResearchQuoteCount>=BOOK_RESEARCH_TRADE_CAP)
      {gBookResearchQuoteFault=true;return;}
      gBookResearchQuoteTail[gBookResearchQuoteTailCount++]=q;
      int slot=(gBookResearchQuoteHead+gBookResearchQuoteCount)%BOOK_RESEARCH_TRADE_CAP;
      gBookResearchQuotes[slot].tick=q;gBookResearchQuotes[slot].ordinal=++gBookResearchQuoteOrdinal;gBookResearchQuotes[slot].ordinal_at_msc=gBookResearchQuoteTailCount;gBookResearchQuoteCount++;
   }
   gBookResearchQuoteCovered=complete?through:(count>0?quotes[count-1].time_msc-1:gBookResearchQuoteCovered);
}
void BookResearchQuoteOnly(const BookResearchQuoteRecord &record)
{
   BookResearchMarketSample x;ZeroMemory(x);x.now_msc=record.tick.time_msc;x.ordinal=record.ordinal;
   x.bid=record.tick.bid;x.ask=record.tick.ask;x.last=record.tick.last;
   x.quote_available=x.bid>0 && x.ask>=x.bid;x.path_complete=!gBookResearchQuoteFault;
   for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++)
   {
      if(!gBookResearchOpportunities[i].used)continue;
      BookResearchCandidate c=gBookResearchOpportunities[i].candidate;
      BookResearchTrack t=gBookResearchOpportunities[i].track;
      if(x.now_msc>=c.created_msc && t.stage==RESEARCH_WAIT_STAGE2 && c.original_eligible &&
         ((record.tick.flags&(TICK_FLAG_LAST|TICK_FLAG_VOLUME|TICK_FLAG_BUY|TICK_FLAG_SELL))!=0) &&
         record.tick.last>0 && c.direction*(record.tick.last-c.trigger)>=0)t.context_incomplete=true;
      // First later raw quote has no archived live-Weis/VWAP/financial context.
      // Preserve that FIRST price as a conditional path reference, never wait
      // for a later better price and pretend ORIGINAL dispatch was proved.
      // A cancellation is terminal for the hypothetical thesis. Quotes still
      // update candidate excursions, never resurrect a timed-out/cancelled ARMED.
      if(!t.original_ended && (t.stage==RESEARCH_WAIT_STAGE2 || t.stage==RESEARCH_STAGE2_READY) && x.now_msc>=c.created_msc)
      {
         long seconds=x.now_msc/1000;int hhmm=(int)((seconds/3600)%24)*100+(int)((seconds/60)%60);
         if(c.armed_at_sec>0 && seconds-c.armed_at_sec>=c.timeout_sec)
         {t.original_ended=true;t.original_reason="TIMEOUT_ARMED";t.reason=t.original_reason;}
         else if(hhmm>=c.stop_entry_hhmm)
         {t.original_ended=true;t.original_reason="ABORT_SESSION_END";t.reason=t.original_reason;}
      }
      if(!t.original_ended && t.stage==RESEARCH_STAGE2_READY && x.ordinal>t.stage2_ordinal && x.now_msc>=t.stage2_msc &&
         x.quote_available && x.ask-x.bid<=c.max_spread && c.sl_distance>0 && c.tp_distance>0)
      {
         double executable=c.direction==1?x.ask:x.bid;
         if(c.direction*(executable-c.trigger)>=0 && c.direction*(executable-c.trigger)<=c.max_overshoot)
         {
            t.entry=executable;t.entry_msc=x.now_msc;t.entry_ordinal=x.ordinal;
            double sl,tp;if(!BookResearchStops(c,executable,sl,tp))continue;
            t.sl=sl;t.tp=tp;
            t.entry_reference_available=true;t.dispatch_eligible_observed=false;t.eligibility_reconstructable=false;
            t.possibility="ORIGINAL_ENTRY_NOT_RECONSTRUCTABLE";
            t.reason="CONDITIONAL_FIRST_QUOTE_MISSING_ARCHIVED_STAGE2_CONTEXT";t.stage=RESEARCH_TRACKING;t.barrier="PENDING";
         }
         else {t.original_ended=true;t.original_reason="FIRST_QUOTE_BREAKOUT_OR_OVERSHOOT_UNRESOLVED";t.reason=t.original_reason;}
      }
      BookResearchObserveQuote(c,x,t);gBookResearchOpportunities[i].track=t;BookResearchTrackChanged(i);
   }
}
void BookResearchProcessSamples()
{
   int budget=0;ulong began=GetMicrosecondCount();
   while(gBookResearchSampleCount>0 && budget++<16 && GetMicrosecondCount()-began<BOOK_RESEARCH_TIMER_US)
   {
      BookResearchMarketSample x=gBookResearchSamples[gBookResearchSampleHead];
      if(x.now_msc>=gBookResearchQuoteCovered && !gBookResearchQuoteFault)break;
      gBookResearchSampleHead=(gBookResearchSampleHead+1)%BOOK_RESEARCH_SAMPLE_CAP;gBookResearchSampleCount--;
      while(gBookResearchQuoteCount>0 && gBookResearchQuotes[gBookResearchQuoteHead].tick.time_msc<x.now_msc)
      {
         BookResearchQuoteOnly(gBookResearchQuotes[gBookResearchQuoteHead]);
         gBookResearchQuoteHead=(gBookResearchQuoteHead+1)%BOOK_RESEARCH_TRADE_CAP;gBookResearchQuoteCount--;
      }
      int at_stamp=0;BookResearchQuoteRecord match;ZeroMemory(match);
      for(int k=0;k<gBookResearchQuoteCount;k++)
      {BookResearchQuoteRecord r=gBookResearchQuotes[(gBookResearchQuoteHead+k)%BOOK_RESEARCH_TRADE_CAP];
       if(r.tick.time_msc!=x.now_msc)break;at_stamp++;match=r;}
      // A coalesced callback cannot identify its ordinal amongst several rows
      // at one ms, even if price/size are equal. Do not invent that identity.
      bool exact=at_stamp==1 && match.ordinal_at_msc==1 && match.tick.bid==x.bid && match.tick.ask==x.ask && match.tick.last==x.last &&
         x.raw_identity_available && match.tick.time==x.raw_time_sec && match.tick.volume==x.raw_volume &&
         match.tick.volume_real==x.raw_volume_real && match.tick.flags==x.raw_flags;
      x.context_causal=x.context_causal && exact;
      x.path_complete=exact && !gBookResearchQuoteFault;
      x.ordinal=exact?match.ordinal:0;
      if(x.vwap_base_valid)
         x.vwap_valid=BookResearchRuntimeLiveVwap(x.vwap_base_pv,x.vwap_base_volume,x.vwap_from,x.now_msc,x.live_vwap);
      if(!x.vwap_valid)x.context_causal=false;
      for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++)
      {
         if(!gBookResearchOpportunities[i].used)continue;
         if(exact)BookResearchStep(gBookResearchOpportunities[i].candidate,x,gBookResearchOpportunities[i].track);
         else if(x.now_msc>=gBookResearchOpportunities[i].candidate.created_msc &&
            (gBookResearchOpportunities[i].track.stage==RESEARCH_WAIT_STAGE2 || gBookResearchOpportunities[i].track.stage==RESEARCH_STAGE2_READY))
         {
            // Raw quote ordinals remain verified. Only the callback's Stage2
            // context identity is unknown; do not erase an ordered barrier path.
            gBookResearchOpportunities[i].track.context_incomplete=true;
            gBookResearchOpportunities[i].track.eligibility_reconstructable=false;
            gBookResearchOpportunities[i].track.reason="ORIGINAL_ENTRY_NOT_RECONSTRUCTABLE";
         }
         BookResearchTrackChanged(i);
         if(gBookResearchActualMode==DECISION_ORIGINAL)BookResearchShadowEvidence(i,x.now_msc);
      }
      if(exact){gBookResearchQuoteHead=(gBookResearchQuoteHead+1)%BOOK_RESEARCH_TRADE_CAP;gBookResearchQuoteCount--;}
   }
   while(gBookResearchSampleCount==0 && gBookResearchQuoteCount>0 && gBookResearchQuotes[gBookResearchQuoteHead].tick.time_msc<gBookResearchQuoteCovered && GetMicrosecondCount()-began<BOOK_RESEARCH_TIMER_US)
   {
      BookResearchQuoteOnly(gBookResearchQuotes[gBookResearchQuoteHead]);
      gBookResearchQuoteHead=(gBookResearchQuoteHead+1)%BOOK_RESEARCH_TRADE_CAP;gBookResearchQuoteCount--;
   }
}
void BookResearchAcquire()
{
   MqlTick latest;if(!SymbolInfoTick(Symbol(),latest) || latest.time_msc<=0)return;
   long goal=latest.time_msc;
#ifdef __cplusplus
   std::vector<MqlTick> batch;
#else
   MqlTick batch[];
#endif
   if(gBookResearchBorrowedCount>0)
   {
      if((long)gBookResearchBorrowedFrom<=gBookResearchCovered+1 && (long)gBookResearchBorrowedTo>=gBookResearchCovered)
         BookResearchRuntimeIngest(gBookResearchBorrowedFrom,gBookResearchBorrowedTo,gBookResearchBorrowed,gBookResearchBorrowedCount);
      gBookResearchBorrowedCount=0;
   }
   if(!gBookResearchTradeFault && goal>=gBookResearchCovered)
   {
      long from=gBookResearchCursor>0?gBookResearchCursor:gBookResearchTradeFrom;
      ResetLastError();int n=CopyTicks(Symbol(),batch,COPY_TICKS_TRADE,(ulong)from,BOOK_RESEARCH_QUOTE_CAP);gBookResearchAcquisitionCalls++;
      if(n<0 || GetLastError()!=0)gBookResearchTradeFault=true;
      else
      {
         gBookResearchAcquisitionRows+=(ulong)n;long through=n==BOOK_RESEARCH_QUOTE_CAP?batch[n-1].time_msc:goal;
         if(n>0 && batch[n-1].time_msc>through)through=batch[n-1].time_msc;
#ifdef __cplusplus
         BookResearchRuntimeIngest((ulong)from,(ulong)through,batch.data(),n);
#else
         BookResearchRuntimeIngest((ulong)from,(ulong)through,batch,n);
#endif
         if(n==BOOK_RESEARCH_QUOTE_CAP){gBookResearchCovered=through-1;if(batch[n-1].time_msc==from)gBookResearchTradeFault=true;}
      }
   }
   if(!gBookResearchQuoteFault && goal>=gBookResearchQuoteCovered)
   {
      long from=gBookResearchQuoteCursor>0?gBookResearchQuoteCursor:gBookResearchReplayMSC;
      ResetLastError();int n=CopyTicks(Symbol(),batch,COPY_TICKS_ALL,(ulong)from,BOOK_RESEARCH_QUOTE_CAP);gBookResearchAcquisitionCalls++;
      if(n<0 || GetLastError()!=0)gBookResearchQuoteFault=true;
      else
      {
         gBookResearchAcquisitionRows+=(ulong)n;long through=n==BOOK_RESEARCH_QUOTE_CAP?batch[n-1].time_msc:goal;
         if(n==BOOK_RESEARCH_QUOTE_CAP && batch[n-1].time_msc==from){gBookResearchQuoteFault=true;return;}
         if(n<BOOK_RESEARCH_QUOTE_CAP && (n<=0 || batch[n-1].time_msc<goal))
         {gBookResearchQuoteFault=true;return;} // latest observed quote absent from supposedly complete ALL history

         if(n>0 && batch[n-1].time_msc>through)through=batch[n-1].time_msc;
#ifdef __cplusplus
         BookResearchQuoteBatch(from,through,batch.data(),n,n<BOOK_RESEARCH_QUOTE_CAP);
#else
         BookResearchQuoteBatch(from,through,batch,n,n<BOOK_RESEARCH_QUOTE_CAP);
#endif
      }
   }
   ArrayFree(batch);
}
string BookResearchMarkerPayload(const string status)
{
   string payload=BOOK_RESEARCH_SCHEMA;payload+="\n"+gBookResearchRun+"\n"+status+"\n";
   if(status=="OPEN")for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++)
      if(gBookResearchOpportunities[i].used && gBookResearchOpportunities[i].track.stage!=RESEARCH_FINISHED)
         payload+=gBookResearchOpportunities[i].candidate.id+"\n";
   return payload;
}
bool BookResearchWriteMarker(const string status)
{
#ifdef __cplusplus
   std::ofstream out(gBookResearchStateFile,std::ios::binary|std::ios::trunc);if(!out)return false;
   out<<BookResearchMarkerPayload(status);out.flush();return out.good();
#else
   ResetLastError();int h=FileOpen(gBookResearchStateFile,FILE_WRITE|FILE_BIN|FILE_SHARE_READ);if(h==INVALID_HANDLE)return false;
   string text=BookResearchMarkerPayload(status);uchar bytes[];int n=StringToCharArray(text,bytes,0,WHOLE_ARRAY,CP_UTF8)-1;
   bool ok=n>0 && FileWriteArray(h,bytes,0,n)==(uint)n && GetLastError()==0;
   ResetLastError();FileFlush(h);if(GetLastError()!=0)ok=false;FileClose(h);return ok;
#endif
}
void BookResearchReadInterruption()
{
   string previous="",status="",schema="";
#ifdef __cplusplus
   std::ifstream in(gBookResearchStateFile);if(!in)return;
   std::getline(in,schema);std::getline(in,previous);std::getline(in,status);
#else
   if(!FileIsExist(gBookResearchStateFile))return;
   int h=FileOpen(gBookResearchStateFile,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ,0,CP_UTF8);
   if(h==INVALID_HANDLE){BookResearchHealth("RESTART_INTERRUPTED","PRIOR_MARKER_UNREADABLE","");return;}
   schema=FileReadString(h);previous=FileReadString(h);status=FileReadString(h);
#endif
   if(schema!=BOOK_RESEARCH_SCHEMA || status!="CLOSED")
      BookResearchHealth("RESTART_INTERRUPTED","PRIOR_TRACKS_NOT_RESUMED",previous+"; prior run interrupted or marker incomplete; no continuous MAE/MFE or barrier-order claim");
   if(schema==BOOK_RESEARCH_SCHEMA && status=="OPEN" && previous!="")
   {
      for(int n=0;n<BOOK_RESEARCH_TRACK_CAP;n++)
      {
         string id="";
#ifdef __cplusplus
         if(!std::getline(in,id))break;
#else
         if(FileIsEnding(h))break;id=FileReadString(h);
#endif
         if(id=="")continue;
         string row=BOOK_RESEARCH_SCHEMA;
         BookResearchAdd(row,gBookResearchRun+"_interrupted_"+BookResearchNumber(++gBookResearchSequence));
         BookResearchAdd(row,previous);BookResearchAdd(row,id);BookResearchAdd(row,BookResearchNumber(gBookResearchLastNow));
         BookResearchAdd(row,Symbol());BookResearchAdd(row,gBookResearchAccount);BookResearchAdd(row,gBookResearchServer);BookResearchAdd(row,gBookResearchMagic);
         BookResearchAdd(row,"");BookResearchAdd(row,"");BookResearchAdd(row,"");
         BookResearchAdd(row,"RESTART_INTERRUPTED");BookResearchAdd(row,"CONTINUITY_NOT_RECOVERED");
         for(int f=0;f<28;f++)BookResearchAdd(row,"");
         BookResearchAdd(row,"Closed by next instance; no future price, invented fill, continuous MAE/MFE or PnL");
         for(int f=0;f<16;f++)BookResearchAdd(row,"");
         BookResearchEnqueue(2,row);
      }
   }

#ifndef __cplusplus
   FileClose(h);
#endif
}
void BookResearchRuntimeInit(const string run_id,const string preset_hash,const string canonical_inputs,
   const string account,const string magic,const string code_hash,const int actual_mode,const BookDecisionConfig &config,const string server="",const string trading_hash="")
{
   if(!Inp_ResearchEnable)return;
   if(!BookDecisionConfigValid(config)){gBookResearchReady=false;gBookResearchSuspended=true;gBookResearchSuspendReason="RESEARCH_CONFIG_INVALID";return;}
   gBookResearchRun=run_id;gBookResearchPreset=preset_hash;gBookResearchAccount=account;gBookResearchMagic=magic;gBookResearchServer=server;gBookResearchTradingPreset=trading_hash;
   gBookResearchCode=code_hash;gBookResearchActualMode=actual_mode;gBookResearchConfig=config;
   gBookResearchPrefix="Research_"+account+"_"+Symbol()+"_"+magic+"_"+run_id+"_";
   gBookResearchStateFile="Research_"+account+"_"+Symbol()+"_"+magic+"_State.txt";
   gBookResearchReady=true;gBookResearchSuspended=false;gBookResearchSuspendReason="";gBookResearchSuspensionReported=false;gBookResearchTradeFaultReported=false;
   gBookResearchQueueHead=0;gBookResearchQueueCount=0;gBookResearchSampleHead=0;gBookResearchSampleCount=0;
   gBookResearchBorrowedCount=0;gBookResearchBorrowedFrom=0;gBookResearchBorrowedTo=0;
   gBookResearchTradeHead=0;gBookResearchTradeCount=0;gBookResearchTailCount=0;gBookResearchTradeFault=false;
   gBookResearchQuoteHead=0;gBookResearchQuoteCount=0;gBookResearchQuoteTailCount=0;gBookResearchQuoteFault=false;
   gBookResearchClosedHead=0;gBookResearchClosedCount=0;gBookResearchQuoteOrdinal=0;gBookResearchDataVersion=0;gBookResearchReferenceContextAvailable=false;
   gBookResearchContextSignalGeneration=0;gBookResearchContextEpoch=0;gBookResearchContextVersion=0;gBookResearchContextCovered=0;
   gBookResearchSequence=0;gBookResearchDropped=0;gBookResearchWritten=0;gBookResearchIOErrors=0;
   gBookResearchTimerUS=0;gBookResearchTimerMaxUS=0;gBookResearchAcquisitionCalls=0;gBookResearchAcquisitionRows=0;
   gBookResearchCandidateCount=0;gBookResearchEligibleCount=0;gBookResearchRejectedCount=0;gBookResearchOutcomeCount=0;
   for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++){gBookResearchOpportunities[i].used=false;gBookResearchPendingDispatches[i].used=false;}
   gBookResearchArchiveNext=0;for(int k=0;k<32;k++)gBookResearchReferenceArchives[k].used=false;
   MqlTick tick;long start=SymbolInfoTick(Symbol(),tick)?tick.time_msc:(long)TimeTradeServer()*1000;
   long width=(long)config.window_sec*1000;
   gBookResearchTradeEpoch++;gBookResearchTradeFrom=(start/width)*width;
   gBookResearchCovered=gBookResearchTradeFrom-1;gBookResearchCursor=0;gBookResearchCollectionStart=gBookResearchTradeFrom;
   for(int k=0;k<32;k++){gBookResearchVwapMinutes[k].from_msc=0;gBookResearchVwapMinutes[k].pv=0;gBookResearchVwapMinutes[k].volume=0;}
   gBookResearchReplayMSC=start;gBookResearchQuoteCursor=0;gBookResearchQuoteCovered=start-1;
   gBookResearchLastNow=start;gBookResearchDay=start/86400000;
   BookDecisionHistoryReset(gBookResearchHistory);BookResearchOpenWindow(gBookResearchTradeFrom,0,0,0,false);
   BookResearchReadInterruption();
   BookResearchHealth("CONFIGURATION","OBSERVATION_ONLY",canonical_inputs);
   if(!BookResearchWriteMarker("OPEN")){gBookResearchIOErrors++;BookResearchSuspend("STATE_MARKER_WRITE_FAILED");}
}
void BookResearchFlush()
{
   if(gBookResearchIOErrors>0)return; // uncertain/partial research writes are never retried
   int written=0;ulong begin=GetMicrosecondCount();
   while(gBookResearchQueueCount>0 && written<BOOK_RESEARCH_ROWS_PER_TIMER && GetMicrosecondCount()-begin<BOOK_RESEARCH_TIMER_US)
   {
      BookResearchEnvelope item=gBookResearchQueue[gBookResearchQueueHead];
      if(!BookResearchWrite(gBookResearchPrefix+BookResearchNames(item.file)+".csv",item.line,BookResearchHeader(item.file)))
      {gBookResearchIOErrors++;BookResearchSuspend("RESEARCH_WRITE_FAILED_PARTIAL_ROW_POSSIBLE");return;}
      gBookResearchQueueHead=(gBookResearchQueueHead+1)%BOOK_RESEARCH_QUEUE_CAP;gBookResearchQueueCount--;gBookResearchWritten++;written++;
   }
}
void BookResearchRuntimeTimer()
{
   if(!Inp_ResearchEnable || !gBookResearchReady)return;
   ulong begin=GetMicrosecondCount();gBookResearchLastNow=(long)TimeTradeServer()*1000;
   if(!gBookResearchSuspended)
   {
      BookResearchAcquire();
      for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++)if(gBookResearchOpportunities[i].used &&
         gBookResearchOpportunities[i].actual_dispatch && !gBookResearchOpportunities[i].dispatch_assessed)
      {
         if(gBookResearchActualMode==DECISION_ORIGINAL)
         {
            BookResearchShadowEvidence(i,gBookResearchOpportunities[i].pricing_quote_msc,true);
            // Pricing time is not the final market clock at the API. Do not
            // silently turn that qualified earlier view into dispatch approval.
            BookDecisionEvidence unavailable;ZeroMemory(unavailable);unavailable.now_msc=gBookResearchLastNow;
            BookDecisionVerdict verdict;BookDecisionVerdictReset(verdict);verdict.result=(ENUM_BOOK_DECISION_RESULT)-1;
            verdict.reason="EXACT_DISPATCH_MARKET_CLOCK_NOT_CAPTURED";
            BookResearchRuntimeEvidence(gBookResearchOpportunities[i].candidate.id,unavailable,verdict,
               gBookResearchOpportunities[i].candidate.direction,gBookResearchOpportunities[i].candidate.route=="CONT",true,false,"INDEPENDENT_APPLY_AT_ACTUAL_DISPATCH");
         }
         gBookResearchOpportunities[i].dispatch_assessed=true;
      }
      BookResearchProcessSamples();
      if(gBookResearchTradeFault && !gBookResearchTradeFaultReported)
      {gBookResearchTradeFaultReported=true;BookResearchHealth("DATA_UNAVAILABLE","RESEARCH_TRADE_IDENTITY_ORDER_COMPLETENESS_FAULT","Independent APPLY evidence unavailable; existing quote trajectories remain labelled separately");}
      if(gBookResearchQuoteFault)
      {
         for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++)if(gBookResearchOpportunities[i].used && gBookResearchOpportunities[i].track.stage!=RESEARCH_FINISHED)
         {gBookResearchOpportunities[i].track.path_ambiguous=true;BookResearchFinish(gBookResearchOpportunities[i].track,gBookResearchLastNow,"INSUFFICIENT_MARKET_DATA");BookResearchTrackChanged(i);}
         BookResearchHealth("DATA_UNAVAILABLE","RESEARCH_QUOTE_IDENTITY_ORDER_COMPLETENESS_FAULT","Barrier order cannot be certified");
         BookResearchSuspend("QUOTE_HISTORY_INTEGRITY_FAULT");
      }
      long day=gBookResearchLastNow/86400000;
      if(day!=gBookResearchDay)
      {BookResearchDaily(gBookResearchDay);gBookResearchDay=day;gBookResearchCandidateCount=0;gBookResearchEligibleCount=0;gBookResearchRejectedCount=0;gBookResearchOutcomeCount=0;}
      for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++)
      {
         if(!gBookResearchOpportunities[i].used || gBookResearchOpportunities[i].track.stage==RESEARCH_FINISHED)continue;
         BookResearchTrack t=gBookResearchOpportunities[i].track;BookResearchCandidate c=gBookResearchOpportunities[i].candidate;
         long origin=t.entry_reference_available?t.entry_msc:c.created_msc;
         long boundary=origin+900000;
         bool drained=(gBookResearchQuoteCount==0 || gBookResearchQuotes[gBookResearchQuoteHead].tick.time_msc>boundary) &&
            (gBookResearchSampleCount==0 || gBookResearchSamples[gBookResearchSampleHead].now_msc>boundary);
         if(gBookResearchLastNow>=boundary && gBookResearchQuoteCovered>=boundary && !gBookResearchQuoteFault && drained)
         {BookResearchFinish(t,boundary,"HORIZON_NO_BARRIER");gBookResearchOpportunities[i].track=t;BookResearchTrackChanged(i);}
         else if(gBookResearchLastNow-boundary>=30000)
         {t.path_ambiguous=true;BookResearchFinish(t,boundary,"INSUFFICIENT_MARKET_DATA");gBookResearchOpportunities[i].track=t;BookResearchTrackChanged(i);}
      }
   }
   if(gBookResearchIOErrors==0)BookResearchFlush();
   if(gBookResearchSuspended && !gBookResearchSuspensionReported)
   {
      gBookResearchSuspensionReported=true;
      string row=BookResearchBase("",Symbol(),gBookResearchLastNow);BookResearchAdd(row,"SUSPENDED");BookResearchAdd(row,gBookResearchSuspendReason);
      BookResearchAdd(row,BookResearchNumber(gBookResearchQueueCount));BookResearchAdd(row,BookResearchNumber((long)gBookResearchDropped));
      BookResearchAdd(row,BookResearchNumber((long)gBookResearchWritten));BookResearchAdd(row,BookResearchNumber((long)gBookResearchIOErrors));
      BookResearchAdd(row,BookResearchNumber((long)gBookResearchTimerUS));BookResearchAdd(row,BookResearchNumber((long)gBookResearchTimerMaxUS));
      BookResearchAdd(row,BookResearchNumber((long)gBookResearchAcquisitionCalls));BookResearchAdd(row,BookResearchNumber((long)gBookResearchAcquisitionRows));
      BookResearchAdd(row,"16777216");BookResearchAdd(row,"Research only; financial execution and protection unaffected; failure may prevent this row being persisted");
      BookResearchWrite(gBookResearchPrefix+"Health.csv",row+"\r\n",BookResearchHeader(3));
#ifndef __cplusplus
      PrintFormat("[RESEARCH][SUSPENDED] reason=%s dropped=%I64u; financial execution/protection unchanged",gBookResearchSuspendReason,gBookResearchDropped);
#endif
   }
   if(!gBookResearchSuspended && !BookResearchWriteMarker("OPEN"))
   {gBookResearchIOErrors++;BookResearchSuspend("STATE_MARKER_WRITE_FAILED");}
   ulong elapsed=GetMicrosecondCount()-begin;gBookResearchTimerUS+=elapsed;if(elapsed>gBookResearchTimerMaxUS)gBookResearchTimerMaxUS=elapsed;
}
void BookResearchRuntimeEndSession(const string reason)
{
   if(!BookResearchEnabled())return;
   for(int i=0;i<BOOK_RESEARCH_TRACK_CAP;i++)if(gBookResearchOpportunities[i].used && gBookResearchOpportunities[i].track.stage!=RESEARCH_FINISHED)
   {BookResearchFinish(gBookResearchOpportunities[i].track,gBookResearchLastNow,reason);BookResearchTrackChanged(i);}
}
void BookResearchRuntimeDeinit(const int reason)
{
   if(!Inp_ResearchEnable || !gBookResearchReady)return;
   gBookResearchLastNow=(long)TimeTradeServer()*1000;
   BookResearchRuntimeEndSession("DEINIT_INCOMPLETE");BookResearchDaily(gBookResearchDay);
   BookResearchHealth("SHUTDOWN",gBookResearchSuspended?gBookResearchSuspendReason:"CLEAN_DEINIT",BookResearchNumber(reason));
   BookResearchFlush();
   // A nonempty queue is an interrupted research delivery, never a financial
   // obligation. Keep marker OPEN so the next instance reports the gap.
   if(!gBookResearchSuspended && gBookResearchQueueCount==0)BookResearchWriteMarker("CLOSED");
   gBookResearchReady=false;
}
#endif
