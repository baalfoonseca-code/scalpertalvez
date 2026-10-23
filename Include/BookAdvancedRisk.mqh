#ifndef BOOK_ADVANCED_RISK_MQH
#define BOOK_ADVANCED_RISK_MQH
#include "BookRiskCore.mqh"
// Optional financial layer. Never reads book dominance. Legacy TradeRecord,
// SL/TP provenance, economic accounting and SCALPER_BE1 remain authoritative.
struct BookRiskState
{
   ulong pid,ticket;
   int direction,slMode,tpMode,stage,operation,step,closedLockStep;
   string route,mode;
   datetime sentAt,nextTry;
   double requestEntry,requestSL,initialTP,requestedLots;
   double sigma,multiplier,cap,raw,normalized,tpMultiplier;
   double entry,initialSL,initialR,volume,targetSL,targetTP,serverSL,serverTP,realizedNet;
   uint requestID,retcode;
   long requestMSC,confirmedMSC;
   bool loaded,durable,unavailableLogged,noJournal;
};
BookRiskState gBookRisk[];
BookRiskState gBookRiskCandidate;

bool BookRiskEnabled()
{ return Inp_SL_Mode!=SL_ORIGINAL_PONTOS || Inp_TP_Mode!=TP_MODE_ORIGINAL || EnableProfitLocks; }
bool BookRiskInputsValid()
{
   bool ok=(Inp_SL_Mode==SL_ORIGINAL_PONTOS || Inp_SL_Mode==SL_SIGMA_COM_TETO) &&
      (Inp_TP_Mode==TP_MODE_ORIGINAL || Inp_TP_Mode==TP_MODE_BY_ROUTE_R) &&
      BRPositive(BE_Trigger_R) && BRPositive(Inp_Mult_SL) &&
      BRPositive(Inp_Max_SL_Pts_WIN) && BRPositive(Inp_Max_SL_Pts_WDO) &&
      BRPositive(TP_BASE_R) && BRPositive(TP_TURBO_R);
   // Inactive experimental numbers are still checked; no silent substitutions.
   if(!BRPositive(Lock1_Trigger_R) || !BRPositive(Lock1_Protected_R) ||
      !BRPositive(Lock2_Trigger_R) || !BRPositive(Lock2_Protected_R)) ok=false;
   if(EnableProfitLocks && !BRActiveLadderValid(Inp_EnableBreakEven,BE_Trigger_R,
      Lock1_Trigger_R,Lock1_Protected_R,Lock2_Trigger_R,Lock2_Protected_R)) ok=false;
   if(!ok) Print("[BOOK_RISK][INVALID_INPUTS] finite positive values required; active ladder requires BE < Lock1 < Lock2 and increasing protections below triggers; no defaults substituted");
   if(ok && EnableProfitLocks && Inp_TP_Mode==TP_MODE_BY_ROUTE_R)
   {
      if(TP_BASE_R<Lock1_Trigger_R || TP_BASE_R<Lock2_Trigger_R)
         Print("[BOOK_RISK][UNREACHABLE_LOCK] BASE TP_R below a lock trigger");
      if(TP_TURBO_R<Lock1_Trigger_R || TP_TURBO_R<Lock2_Trigger_R)
         Print("[BOOK_RISK][UNREACHABLE_LOCK] TURBO TP_R below a lock trigger");
   }
   return ok;
}
string BookRiskD(double value) { return DoubleToString(value,16); }
string BookRiskRow(const BookRiskState &s)
{
   string v="SCALPER_RISK1|"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+RJEncode(Symbol())+
      "|"+(string)gMagicCore+"|"+(string)s.pid+"|"+(string)s.direction+"|"+s.route+"|"+s.mode+
      "|"+(string)s.sentAt+"|"+BookRiskD(s.requestEntry)+"|"+BookRiskD(s.requestSL)+
      "|"+BookRiskD(s.initialTP)+"|"+BookRiskD(s.requestedLots)+"|"+BookRiskD(s.sigma)+
      "|"+BookRiskD(s.multiplier)+"|"+BookRiskD(s.cap)+"|"+BookRiskD(s.raw)+
      "|"+BookRiskD(s.normalized)+"|"+(string)s.slMode+"|"+(string)s.tpMode+
      "|"+BookRiskD(s.tpMultiplier)+"|"+(string)s.stage+"|"+(string)s.ticket+
      "|"+BookRiskD(s.entry)+"|"+BookRiskD(s.initialSL)+"|"+BookRiskD(s.initialR)+
      "|"+BookRiskD(s.volume)+"|"+(string)s.operation+"|"+(string)s.step+
      "|"+BookRiskD(s.targetSL)+"|"+BookRiskD(s.targetTP)+"|"+(string)s.requestID+
      "|"+(string)s.retcode+"|"+(string)s.requestMSC+"|"+(string)s.confirmedMSC+
      "|"+BookRiskD(s.serverSL)+"|"+BookRiskD(s.serverTP)+"|"+BookRiskD(s.realizedNet)+
      "|"+(string)s.closedLockStep;
   return v+"|"+RJChecksum(v)+"|COMPLETE_RISK1";
}
// Only realized net PnL is signed; price/risk/reference fields retain the
// legacy nonnegative grammar. Do not reinterpret old SCALPER_BE1 records.
bool BookRiskSignedDouble(string text,double &value)
{
   bool negative=(StringLen(text)>0 && StringGetCharacter(text,0)==45);
   string magnitude=negative?StringSubstr(text,1):text;
   if(!RJDouble(magnitude,value)) return false;
   if(negative) value=-value;
   return BRFinite(value);
}
bool BookRiskParse(string row,ulong pid,BookRiskState &s)
{
   string f[],symbol;
   if(StringSplit(row,'|',f)!=41 || f[0]!="SCALPER_RISK1" || f[40]!="COMPLETE_RISK1") return false;
   string prefix=f[0]; for(int k=1;k<39;k++) prefix+="|"+f[k];
   if(RJChecksum(prefix)!=f[39] || !RJDecode(f[2],symbol) || symbol!=Symbol() ||
      f[1]!=(string)AccountInfoInteger(ACCOUNT_LOGIN) || f[3]!=(string)gMagicCore ||
      f[4]!=(string)pid || (f[5]!="1" && f[5]!="-1") || !RJRoute(f[6],f[7])) return false;
   ulong u[15]; int idx[15]={8,18,19,21,22,27,28,31,32,33,34,38,1,3,4};
   for(int i=0;i<15;i++) if(!RJUnsigned(f[idx[i]],u[i])) return false;
   if(u[0]==0 || u[0]>9223372036854775807 || u[1]>1 || u[2]>1 || u[3]>BR_CLOSED ||
      u[5]>3 || u[6]>2 || u[7]>4294967295 || u[8]>4294967295 ||
      u[9]>9223372036854775807 || u[10]>9223372036854775807 || u[11]>2) return false;
   double x[20]; int di[20]={9,10,11,12,13,14,15,16,17,20,23,24,25,26,29,30,35,36,37,13};
   for(int i=0;i<20;i++)
      if(!(di[i]==37?BookRiskSignedDouble(f[di[i]],x[i]):RJDouble(f[di[i]],x[i])) || !BRFinite(x[i])) return false;
   ZeroMemory(s); s.pid=pid; s.direction=(f[5]=="1"?1:-1); s.route=f[6]; s.mode=f[7];
   s.sentAt=(datetime)u[0]; s.slMode=(int)u[1]; s.tpMode=(int)u[2]; s.stage=(int)u[3];
   s.ticket=u[4]; s.operation=(int)u[5]; s.step=(int)u[6]; s.requestID=(uint)u[7];
   s.retcode=(uint)u[8]; s.requestMSC=(long)u[9]; s.confirmedMSC=(long)u[10]; s.closedLockStep=(int)u[11];
   s.requestEntry=x[0]; s.requestSL=x[1]; s.initialTP=x[2]; s.requestedLots=x[3];
   s.sigma=x[4]; s.multiplier=x[5]; s.cap=x[6]; s.raw=x[7]; s.normalized=x[8];
   s.tpMultiplier=x[9]; s.entry=x[10]; s.initialSL=x[11]; s.initialR=x[12]; s.volume=x[13];
   s.targetSL=x[14]; s.targetTP=x[15]; s.serverSL=x[16]; s.serverTP=x[17]; s.realizedNet=x[18];
   if(!BRPositive(s.requestEntry) || !BRPositive(s.requestSL) || !BRPositive(s.initialTP) ||
      !BRPositive(s.requestedLots) || s.direction*(s.requestEntry-s.requestSL)<=0 ||
      !BRPositive(s.multiplier) || !BRPositive(s.cap) || !BRPositive(s.normalized) ||
      !BRPositive(s.tpMultiplier) || s.sigma<0 || s.raw<0) return false;
   if(s.slMode==SL_SIGMA_COM_TETO && (!BRPositive(s.sigma) || !BRPositive(s.raw) || s.normalized>s.cap)) return false;
   if(s.stage!=BR_WAIT_FILL && (!BRPositive(s.entry) || !BRPositive(s.initialSL) ||
      !BRPositive(s.initialR) || !BRPositive(s.volume) ||
      !BEPriceEqual(s.initialR,MathAbs(s.entry-s.initialSL)) ||
      s.direction*(s.entry-s.initialSL)<=0)) return false;
   if((s.stage==BR_PENDING || s.stage==BR_ACK || s.stage==BR_UNCERTAIN || s.stage==BR_CONFIRMED) &&
      (s.operation<1 || s.ticket==0 || s.requestMSC<=0 || !BRPositive(s.targetSL) || !BRPositive(s.targetTP))) return false;
   if((s.stage==BR_ACK || s.stage==BR_CONFIRMED) && s.retcode!=TRADE_RETCODE_DONE) return false;
   s.loaded=true; s.durable=true; return true;
}
// Exact binary reads prevent accepting an earlier valid prefix after a later
// I/O failure. A clean byte count, stable size and successful close are required.
bool BookRiskReadPayload(string path,string &payload,bool &exists)
{
   payload="";
   ResetLastError(); exists=FileIsExist(path); int error=GetLastError();
   if(!exists || error!=0) return false;
   ResetLastError();
   int h=FileOpen(path,FILE_READ|FILE_BIN|FILE_SHARE_READ);
   if(h==INVALID_HANDLE || GetLastError()!=0) { if(h!=INVALID_HANDLE) FileClose(h); return false; }
   ResetLastError(); ulong size=FileSize(h);
   bool ok=(GetLastError()==0 && size>0 && size<=1048576);
   uchar bytes[];
   if(ok) ok=(ArrayResize(bytes,(int)size)==(int)size);
   if(ok)
   {
      ResetLastError(); uint read=FileReadArray(h,bytes,0,(int)size);
      ok=(read==(uint)size && GetLastError()==0);
      ResetLastError(); ulong at=FileTell(h); if(GetLastError()!=0 || at!=size) ok=false;
      ResetLastError(); ulong after=FileSize(h); if(GetLastError()!=0 || after!=size) ok=false;
   }
   ResetLastError(); FileClose(h); if(GetLastError()!=0) ok=false;
   if(!ok) return false;
   payload=CharArrayToString(bytes,0,(int)size,CP_UTF8);
   return StringLen(payload)>0 && StringGetCharacter(payload,StringLen(payload)-1)=='\n';
}
bool BookRiskRead(string path,ulong pid,BookRiskState &s,bool &exists)
{
   string payload;
   if(!BookRiskReadPayload(path,payload,exists)) return false;
   string rows[]; int n=StringSplit(payload,'\n',rows); bool found=false;
   for(int i=0;i<n;i++)
   {
      string row=rows[i];
      int len=StringLen(row);
      if(len>0 && StringGetCharacter(row,len-1)=='\r') row=StringSubstr(row,0,len-1);
      if(row=="") continue;
      BookRiskState candidate;
      if(!BookRiskParse(row,pid,candidate)) return false;
      s=candidate; found=true;
   }
   return found;
}
bool BookRiskAppend(string path,BookRiskState &s)
{
   string row=BookRiskRow(s),payload="\r\n"+row+"\r\n";
   int h=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   bool ok=false;
   if(h!=INVALID_HANDLE)
   {
      if(FileSeek(h,0,SEEK_END))
      {
         ResetLastError(); uint written=FileWriteString(h,payload);
         ok=(written==(uint)StringLen(payload) && GetLastError()==0);
         ResetLastError(); FileFlush(h); if(GetLastError()!=0) ok=false;
      }
      FileClose(h);
   }
   BookRiskState proof; bool exists=false;
   if(ok) ok=BookRiskRead(path,s.pid,proof,exists) && BookRiskRow(proof)==row;
   s.durable=ok;
   if(!ok) PrintFormat("[BOOK_RISK][PERSISTENCE_UNCONFIRMED] pid=%I64u stage=%d; no optional dispatch permitted",s.pid,s.stage);
   return ok;
}
// A distinct leading namespace is essential: EMRInspectFiles intentionally
// rejects unknown suffixes beneath EconomicMarkerPrefix(). Legacy files and
// legacy proof rules remain unchanged; no existing financial file is renamed.
string BookRiskPath(ulong pid) { return "BOOK_RISK1_"+TradeMetaPath(pid)+".journal"; }
string BookRiskPendingIdentity()
{
   return (string)gPendingExec.sentAt+"|"+(string)gPendingExec.direction+"|"+gPendingExec.route+
      "|"+gPendingExec.mode+"|"+BookRiskD(gPendingExec.requestPrice)+"|"+
      BookRiskD(gPendingExec.requestedLots)+"|"+BookRiskD(gPendingExec.slPrice)+"|"+BookRiskD(gPendingExec.tpPrice);
}
string BookRiskPendingPath()
{ return "BOOK_RISK1_"+RequestJournalPath(false)+".frozen."+RJChecksum(BookRiskPendingIdentity()); }
bool BookRiskPendingMatches(const BookRiskState &s)
{
   return s.pid==0 && s.direction==gPendingExec.direction && s.sentAt==gPendingExec.sentAt &&
      s.route==gPendingExec.route && s.mode==gPendingExec.mode &&
      s.requestEntry==gPendingExec.requestPrice && s.requestSL==gPendingExec.slPrice &&
      s.initialTP==gPendingExec.tpPrice && s.requestedLots==gPendingExec.requestedLots;
}
// freeze=true is called once for the final pricing attempt. Later quote checks
// reuse that raw SigmaD1; they never change VWAP/C5 SigmaD1 or widen an open SL.
bool BookRiskResolveTerms(int direction,double price,string mode,double slPts,double tpPts,
                         bool freeze,double &sl,double &tp)
{
   if(freeze)
   {
      ZeroMemory(gBookRiskCandidate);
      gBookRiskCandidate.direction=direction; gBookRiskCandidate.route=armed.route;
      gBookRiskCandidate.mode=mode; gBookRiskCandidate.slMode=(int)Inp_SL_Mode;
      gBookRiskCandidate.tpMode=(int)Inp_TP_Mode;
      gBookRiskCandidate.sigma=(d1Ready && BRPositive(SigmaD1)?SigmaD1:0.0);
      gBookRiskCandidate.multiplier=Inp_Mult_SL;
      gBookRiskCandidate.cap=(gIsDollarFamily?Inp_Max_SL_Pts_WDO:Inp_Max_SL_Pts_WIN);
      gBookRiskCandidate.tpMultiplier=(mode=="TURBO" || mode=="TURBO_CONT"?TP_TURBO_R:TP_BASE_R);
   }
   if(Inp_SL_Mode==SL_ORIGINAL_PONTOS) sl=NormEntrySL(direction,price-direction*slPts);
   else
   {
      double raw,distance; bool capped;
      if(!BRSigmaStop(direction,price,gBookRiskCandidate.sigma,Inp_Mult_SL,gBookRiskCandidate.cap,
                      gTickSize,sl,raw,distance,capped))
      { Print("[BOOK_RISK][SIGMA_STOP_INVALID] raw sigma/tick/cap invalid; no fallback"); return false; }
      sl=NormPriceDigits(sl);
      if(direction*(price-sl)>gBookRiskCandidate.cap || direction*(price-sl)<=0) return false;
   }
   tp=NormEntryTP(direction,price+direction*tpPts);
   if(Inp_TP_Mode==TP_MODE_BY_ROUTE_R)
      tp=NormEntryTP(direction,price+direction*MathAbs(price-sl)*gBookRiskCandidate.tpMultiplier);
   return BRPositive(sl) && BRPositive(tp);
}
bool BookRiskPrepareEntry()
{
   if(!BookRiskEnabled()) return true;
   BookRiskState s=gBookRiskCandidate;
   s.pid=0; s.sentAt=gPendingExec.sentAt; s.stage=BR_WAIT_FILL;
   s.requestEntry=gPendingExec.requestPrice; s.requestSL=gPendingExec.slPrice;
   s.initialTP=gPendingExec.tpPrice; s.requestedLots=gPendingExec.requestedLots;
   s.normalized=MathAbs(s.requestEntry-s.requestSL);
   s.raw=(s.sigma>0?s.sigma*s.multiplier:0);
   if(!BookRiskPendingMatches(s)) return false;
   return BookRiskAppend(BookRiskPendingPath(),s);
}
// Called before the original request guard is released. On restart this reads
// frozen request provenance; never substitutes today's sigma for a lost value.
bool BookRiskAttachEntry(const TradeRecord &r)
{
   BookRiskState s; bool exists=false;
   if(!BookRiskRead(BookRiskPendingPath(),0,s,exists))
   {
      if(exists || BookRiskEnabled())
      {
         PrintFormat("[BOOK_RISK][ENTRY_PROVENANCE_UNAVAILABLE] pid=%I64u; existing SL/TP kept; new optional management suspended",r.positionID);
         // Proven original entry is still accounted. No invented risk reference.
      }
      return true;
   }
   if(!BookRiskPendingMatches(s)) return false;
   s.pid=r.positionID;
   BookRiskState old; bool oldExists=false;
   if(BookRiskRead(BookRiskPath(s.pid),s.pid,old,oldExists))
   {
      bool match=(old.requestEntry==s.requestEntry && old.requestSL==s.requestSL && old.sentAt==s.sentAt);
      if(match) for(int i=0;i<ArraySize(gBookRisk);i++) if(gBookRisk[i].pid==s.pid) gBookRisk[i]=old;
      return match;
   }
   if(oldExists) return false;
   bool ok=BookRiskAppend(BookRiskPath(s.pid),s);
   if(ok) for(int i=0;i<ArraySize(gBookRisk);i++) if(gBookRisk[i].pid==s.pid) gBookRisk[i]=s;
   return ok;
}
int BookRiskIndex(ulong pid)
{
   for(int i=0;i<ArraySize(gBookRisk);i++) if(gBookRisk[i].pid==pid) return i;
   int n=ArraySize(gBookRisk),slot=n;
   if(n>=MAX_TRADE_RECORDS)
   {
      slot=-1;
      for(int i=0;i<n;i++)
         if(((gBookRisk[i].stage==BR_CLOSED && gBookRisk[i].durable) || gBookRisk[i].noJournal) &&
            FindTrackedTrade(gBookRisk[i].pid)<0) { slot=i; break; }
      if(slot<0)
      {
         static datetime nextCapacityLog=0;
         if(TimeTradeServer()>=nextCapacityLog)
         { Print("[BOOK_RISK][CAPACITY_UNRESOLVED] no releasable durable closed cache slot; optional management suspended"); nextCapacityLog=TimeTradeServer()+10; }
         return -1;
      }
   }
   else if(ArrayResize(gBookRisk,n+1)!=n+1) return -1;
   n=slot;
   ZeroMemory(gBookRisk[n]); gBookRisk[n].pid=pid;
   bool exists=false; BookRiskState loaded;
   if(BookRiskRead(BookRiskPath(pid),pid,loaded,exists)) gBookRisk[n]=loaded;
   else
   {
      int error=GetLastError();
      gBookRisk[n].stage=BR_CORRUPT; gBookRisk[n].loaded=true;
      gBookRisk[n].noJournal=(!exists && (error==0 || error==ERR_FILE_NOT_EXIST));
   }
   return n;
}
bool BookRiskBlocksBE(ulong pid)
{
   int idx=BookRiskIndex(pid);
   if(idx<0) return BookRiskEnabled();
   // Missing legacy references do not disable legacy BE. A real pending/new
   // uncertain financial request does prevent a conflicting BE modification.
   if(gBookRisk[idx].stage==BR_CORRUPT)
   {
      // Absence was established by a read-only probe on loading this PID;
      // attachment of our own proven entry journal refreshes this cache.
      return !gBookRisk[idx].noJournal;
   }
   return BRPending(gBookRisk[idx].stage);
}
bool BookRiskStopsValid(const TradeRecord &r,const MqlTick &tick,double targetSL,double targetTP,double liveSL,double liveTP,bool tpOnly)
{
   double point=SymbolInfoDouble(Symbol(),SYMBOL_POINT);
   long stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL),freeze=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_FREEZE_LEVEL);
   if(!BRPositive(point) || stops<0 || freeze<0 || !OnPriceGrid(targetSL) || !OnPriceGrid(targetTP) ||
      !BRPositive(tick.bid) || !BRPositive(tick.ask) || tick.ask<tick.bid || !BRPositive(liveSL)) return false;
   if(tpOnly ? !BEPriceEqual(targetSL,liveSL) : !BRImproves(r.direction,targetSL,liveSL,gTickSize)) return false;
   return BRBrokerDistances(r.direction,tick.bid,tick.ask,point,(int)stops,(int)freeze,
                            targetSL,targetTP,liveSL,liveTP);
}
void BookRiskAccept(BookRiskState &s,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(!BRPending(s.stage) || s.stage==BR_CORRUPT || request.action!=TRADE_ACTION_SLTP ||
      request.position!=s.ticket || request.position_by!=0 || request.symbol!=Symbol() ||
      request.magic!=(ulong)gMagicCore || !BEPriceEqual(request.sl,s.targetSL) ||
      !BEPriceEqual(request.tp,s.targetTP) || (s.requestID>0 && result.request_id!=s.requestID)) return;
   if(result.request_id>0) s.requestID=result.request_id;
   s.retcode=result.retcode;
   if(result.retcode==TRADE_RETCODE_DONE) s.stage=BR_ACK;
   else if(IsFinalRejectedRetcode(result.retcode) || result.retcode==TRADE_RETCODE_NO_CHANGES)
   { s.stage=BR_REJECTED; s.nextTry=TimeTradeServer()+1; }
   else s.stage=BR_UNCERTAIN;
   BookRiskAppend(BookRiskPath(s.pid),s);
}
void BookRiskTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(trans.type!=TRADE_TRANSACTION_REQUEST || request.action!=TRADE_ACTION_SLTP) return;
   for(int i=0;i<ArraySize(gBookRisk);i++)
      if(gBookRisk[i].requestID>0 && result.request_id==gBookRisk[i].requestID)
         BookRiskAccept(gBookRisk[i],request,result);
}
void BookRiskConfirm(BookRiskState &s,const TradeRecord &r)
{
   if(s.stage!=BR_ACK || !s.durable || !OwnPositionSafe(s.pid)) return;
   ulong ticket=0;
   if(!BESelectOwn(s.pid,ticket,s.direction)) return;
   double sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
   bool slProof=BEPriceEqual(sl,s.targetSL) || BRImproves(s.direction,sl,s.targetSL,gTickSize);
   if(!BRServerProof(s.stage,s.retcode==TRADE_RETCODE_DONE,slProof,BEPriceEqual(tp,s.targetTP))) return;
   s.serverSL=sl; s.serverTP=tp; s.confirmedMSC=(long)TimeTradeServer()*1000;
   s.stage=BR_CONFIRMED;
   if(!BookRiskAppend(BookRiskPath(s.pid),s)) { s.stage=BR_ACK; return; }
   PrintFormat("[BOOK_RISK][SERVER_PROTECTION_CONFIRMED] pid=%I64u op=%d step=%d request=%u ret=%u SL=%.16f TP=%.16f; price protection, not a net-profit guarantee",
      s.pid,s.operation,s.step,s.requestID,s.retcode,s.serverSL,s.serverTP);
}
// Read the independent lock certificate from append-only history. Later TP
// recalibration/no-op ticks cannot erase an earlier confirmed lock's identity.
bool BookRiskLastLockProof(ulong pid,BookRiskState &proof)
{
   string payload; bool exists=false;
   if(!BookRiskReadPayload(BookRiskPath(pid),payload,exists)) return false;
   string rows[]; int n=StringSplit(payload,'\n',rows); bool found=false;
   for(int i=0;i<n;i++)
   {
      string row=rows[i]; int len=StringLen(row);
      if(len>0 && StringGetCharacter(row,len-1)=='\r') row=StringSubstr(row,0,len-1);
      if(row=="") continue;
      BookRiskState candidate;
      if(!BookRiskParse(row,pid,candidate)) return false;
      if(candidate.operation==2 && candidate.step>0 && candidate.retcode==TRADE_RETCODE_DONE &&
         (candidate.stage==BR_ACK || candidate.stage==BR_CONFIRMED))
      { proof=candidate; found=true; }
   }
   return found;
}
void BookRiskClosed(BookRiskState &s,const TradeRecord &r)
{
   if((s.stage==BR_CLOSED && s.durable) || !r.volumeClosedComplete || !r.accountingResolved ||
      !BRFinite(r.netProfit)) return;
   if(TimeTradeServer()<s.nextTry) return;
   if(s.stage==BR_CLOSED && !s.durable)
   { s.nextTry=TimeTradeServer()+1; BookRiskAppend(BookRiskPath(s.pid),s); return; }
   if(s.stage==BR_WAIT_FILL)
   {
      if(!r.initialStopsProven || !r.riskValid || !BEEntryComplete(r)) return;
      s.entry=r.weightedEntryPrice; s.initialSL=r.slPrice;
      s.initialR=MathAbs(s.entry-s.initialSL); s.volume=r.totalVolumeIn;
      if(!BRPositive(s.initialR)) return;
   }
   s.closedLockStep=0;
   // A lock exit is not BE-neutral. Require exact deal-side original stop proof,
   // independent DONE acknowledgement and all own exit components at that lock.
   BookRiskState lock;
   bool all=(BookRiskLastLockProof(s.pid,lock) && BEPriceEqual(lock.entry,s.entry) &&
      BEPriceEqual(lock.initialSL,s.initialSL) && HistorySelectByPosition(s.pid));
   int count=0;
   if(all) for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY && entry!=DEAL_ENTRY_INOUT) continue;
      count++;
      if(HistoryDealGetInteger(deal,DEAL_REASON)!=DEAL_REASON_SL ||
         HistoryDealGetInteger(deal,DEAL_TIME_MSC)<lock.requestMSC ||
         !BEPriceEqual(HistoryDealGetDouble(deal,DEAL_SL),lock.targetSL)) all=false;
   }
   if(all && count>0) s.closedLockStep=lock.step;
   s.realizedNet=r.netProfit; s.stage=BR_CLOSED; s.nextTry=TimeTradeServer()+1;
   if(BookRiskAppend(BookRiskPath(s.pid),s))
      PrintFormat("[BOOK_RISK][CLOSED] pid=%I64u lock_exit_step=%d net=%.16f initialR=%.16f legacy_accounting_unchanged=1",s.pid,s.closedLockStep,s.realizedNet,s.initialR);
}
void BookRiskManage(bool dispatch=true)
{
   for(int i=0;i<gTradeRecordCount;i++)
   {
      TradeRecord r=gTradeRecords[i]; if(r.positionID==0) continue;
      int idx=BookRiskIndex(r.positionID); if(idx<0) continue;
      BookRiskState s=gBookRisk[idx];
      if(s.stage==BR_CORRUPT)
      {
         if(BookRiskEnabled() && !s.unavailableLogged)
         { PrintFormat("[BOOK_RISK][NO_VERIFIABLE_REFERENCE] pid=%I64u; optional locks/TP suspended; existing protections retained",r.positionID); s.unavailableLogged=true; }
         gBookRisk[idx]=s; continue;
      }
      if(r.volumeClosedComplete) { BookRiskClosed(s,r); gBookRisk[idx]=s; continue; }
      BookRiskConfirm(s,r);
      // A persisted uncertain dispatch never becomes retryable merely through
      // elapsed time or a live price. The exact request result must reconcile.
      if(!dispatch || (!BRMayDispatch(s.stage) && s.stage!=BR_WAIT_FILL))
      { gBookRisk[idx]=s; continue; }
      if(r.closed || r.historyRefreshPending || !r.accountingResolved || !r.initialStopsProven || !r.riskValid ||
         !BRPositive(r.weightedEntryPrice) || !BRPositive(r.slPrice) ||
         r.direction*(r.weightedEntryPrice-r.slPrice)<=0 || gPendingExec.active || gPendingExit.active ||
         gLiveOwnershipUnresolved || gPendingOrderClassificationUnresolved || gMultipleOwnOrdersActive ||
         gOrderRegistryUnavailable || gOrderObligationScanUnresolved || HasOwnPendingOrder() ||
         r.be.stage==BE_REQUEST_PENDING || r.be.stage==BE_ACKNOWLEDGED || r.be.stage==BE_UNRESOLVED)
      { gBookRisk[idx]=s; continue; }
      MqlDateTime now; TimeToStruct(TimeTradeServer(),now);
      if(now.hour*100+now.min>=Inp_EOD_CloseHHMM || TimeTradeServer()<s.nextTry)
      { gBookRisk[idx]=s; continue; }
      ulong ticket=0;
      if(!BESelectOwn(s.pid,ticket,r.direction) || !BEEntryComplete(r) || !OwnPositionSafe(s.pid) ||
         !PositionSelectByTicket(ticket) ||
         !BEPriceEqual(PositionGetDouble(POSITION_PRICE_OPEN),r.weightedEntryPrice) ||
         MathAbs(PositionGetDouble(POSITION_VOLUME)-(r.totalVolumeIn-r.totalVolumeOut))>AccountingVolumeTolerance())
      { gBookRisk[idx]=s; continue; }
      double liveSL=PositionGetDouble(POSITION_SL),liveTP=PositionGetDouble(POSITION_TP);
      if(s.stage==BR_WAIT_FILL)
      {
         s.entry=r.weightedEntryPrice; s.initialSL=r.slPrice;
         s.initialR=MathAbs(s.entry-s.initialSL); s.volume=r.totalVolumeIn; s.ticket=ticket; s.stage=BR_IDLE;
         if(!BookRiskAppend(BookRiskPath(s.pid),s)) { s.stage=BR_WAIT_FILL; gBookRisk[idx]=s; continue; }
         // Known entry costs are disclosed separately; unknown exit costs and
         // slippage/gaps mean this is an estimate, never a maximum realized loss.
         double knownCosts=MathMax(0,-r.commission)+MathMax(0,-r.fee)+MathMax(0,-r.swap);
         PrintFormat("[BOOK_RISK][INITIAL_REFERENCE] pid=%I64u route=%s mode=%s SIGMA_RISK_REFERENCE=%.16f SL_MULTIPLIER=%.16f SL_CAP_PTS=%.16f SL_RAW_PTS=%.16f SL_NORMALIZED_PTS=%.16f SL_CAP_ACTIVE=%d SL_INITIAL_PRICE=%.16f SL_INITIAL_RISK_MONEY=%.16f SL_EFFECTIVE_RISK_AFTER_FILL=%.16f KNOWN_COSTS=%.16f COST_INCLUSIVE_ESTIMATE=%.16f",
            s.pid,s.route,s.mode,s.sigma,s.multiplier,s.cap,s.raw,s.normalized,(int)(s.slMode==SL_SIGMA_COM_TETO && s.raw>s.cap),s.initialSL,
            CalcInitialRiskMoney(s.direction,s.requestEntry,s.requestSL,s.requestedLots),r.initialRiskMoney,knownCosts,r.initialRiskMoney+knownCosts);
         if(s.slMode==SL_SIGMA_COM_TETO && s.initialR>s.cap)
            PrintFormat("[BOOK_RISK][SL_EFFECTIVE_CAP_EXCEEDED] pid=%I64u requested_distance=%.16f effective_fill_distance=%.16f cap=%.16f; slippage changed risk; original protective SL retained, never widened",s.pid,s.normalized,s.initialR,s.cap);
         double tpR=s.direction*(liveTP-s.entry)/s.initialR;
         if(EnableProfitLocks && (tpR<Lock1_Trigger_R || tpR<Lock2_Trigger_R))
            PrintFormat("[BOOK_RISK][UNREACHABLE_LOCK] pid=%I64u current TP_R=%.8f below lock trigger",s.pid,tpR);
      }
      // Refuse partial-fill/reference drift instead of recalculating initial R
      // from an already moved live SL. Finalized entry must remain identical.
      if(!BEPriceEqual(s.entry,r.weightedEntryPrice) || !BEPriceEqual(s.initialSL,r.slPrice) ||
         MathAbs(s.volume-r.totalVolumeIn)>AccountingVolumeTolerance())
      { s.stage=BR_CORRUPT; gBookRisk[idx]=s; continue; }
      MqlTick tick;
      if(!SymbolInfoTick(Symbol(),tick) || !BRPositive(tick.bid) || !BRPositive(tick.ask) || tick.ask<tick.bid)
      { gBookRisk[idx]=s; continue; }
      int operation=0; double targetSL=liveSL,targetTP=liveTP; int step=0;
      // Calibrate TP first from confirmed entry and original proven SL; live SL
      // is preserved verbatim, never reset to its original risk-bearing level.
      if(s.tpMode==TP_MODE_BY_ROUTE_R && Inp_TP_Mode==TP_MODE_BY_ROUTE_R)
      {
         double expected=NormEntryTP(s.direction,s.entry+s.direction*s.initialR*s.tpMultiplier);
         if(!BEPriceEqual(liveTP,expected)) { operation=3; targetTP=expected; }
      }
      if(operation==0 && EnableProfitLocks)
      {
         double progress=s.direction*((s.direction==1?tick.bid:tick.ask)-s.entry)/s.initialR;
         step=BRHighestLock(progress,Lock1_Trigger_R,Lock2_Trigger_R);
         if(step>0)
         {
            double protectedR=(step==2?Lock2_Protected_R:Lock1_Protected_R);
            // Rounding toward entry avoids claiming more protection than an
            // off-grid requested rung. The actual rounded price is journaled.
            if(!BRLockPrice(s.direction,s.entry,s.initialR,protectedR,gTickSize,targetSL))
            { gBookRisk[idx]=s; continue; }
            targetSL=NormPriceDigits(targetSL);
            if(BRImproves(s.direction,targetSL,liveSL,gTickSize)) operation=2;
         }
      }
      if(operation==0 || !BookRiskStopsValid(r,tick,targetSL,targetTP,liveSL,liveTP,operation==3))
      { s.nextTry=TimeTradeServer()+1; gBookRisk[idx]=s; continue; }
      s.operation=operation; s.ticket=ticket; s.step=step; s.targetSL=targetSL; s.targetTP=targetTP;
      s.requestID=0; s.retcode=0; s.requestMSC=(tick.time_msc>0?tick.time_msc:(long)TimeTradeServer()*1000);
      s.confirmedMSC=0; s.stage=BR_PENDING;
      // Durable MAY_HAVE_DISPATCHED barrier precedes the only financial API.
      // A crash after this point leaves an uncertain request, never a safe retry.
      if(!BookRiskAppend(BookRiskPath(s.pid),s)) { s.stage=BR_UNCERTAIN; gBookRisk[idx]=s; continue; }
      gBookRisk[idx]=s;
      trade.SetExpertMagicNumber(gMagicCore);
      bool sent=trade.PositionModify(ticket,targetSL,targetTP);
      MqlTradeRequest request; MqlTradeResult result; trade.Request(request); trade.Result(result);
      if(!sent && result.retcode==TRADE_RETCODE_DONE) result.retcode=TRADE_RETCODE_ERROR;
      BookRiskAccept(gBookRisk[idx],request,result);
      BookRiskConfirm(gBookRisk[idx],r);
   }
}
#endif
