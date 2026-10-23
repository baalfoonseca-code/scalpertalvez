#ifndef BOOK_IDENTITY_MQH
#define BOOK_IDENTITY_MQH
#include "BookBuildIdentity.mqh"
// Identity is telemetry only: failure never authorizes or changes an order.
string gBookConfigHash="UNAVAILABLE",gBookRunID="UNAVAILABLE";
string gBookCanonicalInputs="";
int gBookLoadedInputCount=0;
datetime gBookRunServerTime=0;
bool gBookIdentityReady=false;

void BookIdentityAdd(string &canonical,const string type,const string name,const string value)
{
   // Lengths are UTF-16 code units (MQL5 StringLen), payload hashes UTF-8 bytes.
   canonical+=(string)StringLen(type)+":"+type+(string)StringLen(name)+":"+name+
      (string)StringLen(value)+":"+value+"\n";
   gBookLoadedInputCount++;
}

bool BookIdentityHash(const string payload,string &hash)
{
   hash="UNAVAILABLE"; uchar bytes[],key[],digest[];
   int count=StringToCharArray(payload,bytes,0,WHOLE_ARRAY,CP_UTF8);
   if(count<1 || ArrayResize(bytes,count-1)!=count-1) return false;
   ResetLastError();
   if(CryptEncode(CRYPT_HASH_SHA256,bytes,key,digest)!=32 || GetLastError()!=0 || ArraySize(digest)!=32)
      return false;
   hash="";
   for(int i=0;i<32;i++) hash+=StringFormat("%02x",(uint)digest[i]);
   return true;
}

#include "BookInputSnapshot.mqh"

string BookIdentityField(string value)
{
   StringReplace(value,"\"","\"\"");
   return "\""+value+"\"";
}

void BookIdentityInit()
{
   gBookIdentityReady=false;
   gBookRunServerTime=TimeTradeServer();
   // Cryptographic service failure must never merge all failed runs under one
   // filename. This non-secret fallback is a namespace, not a configuration hash.
   gBookRunID="UNHASHED_"+(string)(long)TimeLocal()+"_"+(string)ChartID()+"_"+
      (string)GetMicrosecondCount()+"_"+(string)GetTickCount64();
   gBookLoadedInputCount=0; gBookCanonicalInputs="";
   BookCollectInputIdentity(gBookCanonicalInputs);
   if(!BookIdentityHash("BOOK_INPUT_CANONICAL_V1\n"+gBookCanonicalInputs,gBookConfigHash))
      Print("[BOOK][IDENTITY_HASH_UNAVAILABLE] unique run namespace retained; no configuration equivalence claim possible");
   string context=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
      AccountInfoString(ACCOUNT_SERVER)+"|"+Symbol()+"|"+(string)gMagicCore+"|"+
      gBookConfigHash+"|"+(string)(long)gBookRunServerTime+"|"+(string)ChartID()+"|"+
      (string)GetMicrosecondCount()+"|"+(string)GetTickCount64();
   string hashedRun="";
   if(BookIdentityHash(context,hashedRun)) gBookRunID=hashedRun;
   // Unique run/context namespace: old Audit/Shadow financial schemas unchanged.
   string path="BOOK_1125_CONTEXT_"+gBookRunID+".csv";
   string baseRun=gBookRunID;
   for(int retry=0;FileIsExist(path) && retry<16;retry++)
   {
      gBookRunID=baseRun+"_"+(string)(retry+1);
      path="BOOK_1125_CONTEXT_"+gBookRunID+".csv";
   }
   if(FileIsExist(path))
   { Print("[BOOK][IDENTITY_COLLISION] existing contexts preserved; run telemetry suspended: ",path); return; }
   ResetLastError();
   int h=FileOpen(path,FILE_WRITE|FILE_BIN);
   if(h==INVALID_HANDLE)
   { Print("[BOOK][IDENTITY_WRITE_FAILED] error=",GetLastError()); return; }
   string line="schema,run_id,config_hash,declared_version,baseline_revision,revision_at_generation,build_id,source_bundle_sha256,symbol,account,server,magic,server_time,historical_inputs,total_inputs,volumes,canonical_inputs\r\n";
   line+="BOOK_CONTEXT_V1,"+gBookRunID+","+gBookConfigHash+",1.125,"+
      BOOK_BASELINE_REVISION+","+BOOK_REVISION_AT_GENERATION+","+BOOK_BUILD_ID+","+
      BOOK_SOURCE_BUNDLE_SHA256+","+BookIdentityField(Symbol())+","+
      (string)AccountInfoInteger(ACCOUNT_LOGIN)+","+BookIdentityField(AccountInfoString(ACCOUNT_SERVER))+","+
      (string)gMagicCore+","+(string)(long)gBookRunServerTime+",71,"+
      (string)gBookLoadedInputCount+","+
      BookIdentityField("POC/VWAP ticks=MqlTick.volume integer; flags buy/sell/unknown; Weis/D1=real_volume when available else tick_count, source observed per snapshot; units not interchangeable")+","+
      BookIdentityField(gBookCanonicalInputs)+"\r\n";
   uchar encoded[]; int count=StringToCharArray(line,encoded,0,WHOLE_ARRAY,CP_UTF8);
   ResetLastError();
   uint written=(count>1)?FileWriteArray(h,encoded,0,count-1):0;
   int error=GetLastError();
   ResetLastError(); FileFlush(h); int flushError=GetLastError();
   ResetLastError(); FileClose(h); int closeError=GetLastError();
   if(count<=1 || written!=(uint)(count-1) || error!=0 || flushError!=0 || closeError!=0)
   { Print("[BOOK][IDENTITY_WRITE_FAILED] partial context retained; run telemetry suspended: ",path); return; }
   gBookIdentityReady=true;
   PrintFormat("[BOOK][RUN_CONTEXT] declared_version=1.125 baseline=%s build=%s loaded_inputs=%d historical_inputs=71 config_sha256=%s run_id=%s context=%s; experimental, native compilation pending",
               BOOK_BASELINE_REVISION,BOOK_BUILD_ID,gBookLoadedInputCount,gBookConfigHash,gBookRunID,path);
}

// New telemetry files include these fields; old RC1 trade schema remains legible.
void BookIdentityAppendContext(string &line)
{
   CsvAdd(line,gBookRunID); CsvAdd(line,gBookConfigHash);
}

void BookIdentityAuditHeader(string &line)
{
   CsvAdd(line,"OBSERVED_RUN_ID"); CsvAdd(line,"OBSERVED_CONFIG_SHA256");
   CsvAdd(line,"OBSERVED_POSITION_ID"); CsvAdd(line,"PENDING_ENTRY_ORDER");
   CsvAdd(line,"PENDING_ENTRY_DEAL"); CsvAdd(line,"PENDING_ENTRY_REQUEST_ID");
   CsvAdd(line,"PENDING_EXIT_POSITION_ID"); CsvAdd(line,"PENDING_EXIT_ORDER");
   CsvAdd(line,"PENDING_EXIT_REQUEST_ID");
   CsvAdd(line,"IDENTITY_SCOPE");
}

void BookIdentityAuditRow(string &line)
{
   BookIdentityAppendContext(line);
   CsvAdd(line,gOpenPos.active?(string)gOpenPos.positionID:"");
   CsvAdd(line,gPendingExec.active?(string)gPendingExec.orderTicket:"");
   CsvAdd(line,gPendingExec.active?(string)gPendingExec.resultDeal:"");
   CsvAdd(line,gPendingExec.active?(string)gPendingExec.requestID:"");
   CsvAdd(line,gPendingExit.active?(string)gPendingExit.positionID:"");
   CsvAdd(line,gPendingExit.active?(string)gPendingExit.orderTicket:"");
   CsvAdd(line,gPendingExit.active?(string)gPendingExit.requestID:"");
   CsvAdd(line,"OBSERVED_CONTEXT_NOT_HISTORICAL_ORIGIN_PROOF");
}

void BookIdentityCorrelateTrade(const TradeRecord &record)
{
   if(!gBookIdentityReady) return;
   // Exact record identifiers only. A recovered record does not acquire this
   // run's configuration retrospectively; historical origin remains unproven.
   string path="BOOK_1125_"+gBookRunID+"_TradeContexts.csv";
   ResetLastError();
   int h=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) { Print("[BOOK][TRADE_CONTEXT_WRITE_FAILED]",GetLastError()); return; }
   string row="";
   if(FileSize(h)==0)
      row="observed_run_id,observed_config_sha256,position_id,entry_order,last_exit_deal,route,mode,entry_time,exit_time,server_time,identity_scope\r\n";
   string fields="";
   BookIdentityAppendContext(fields);
   CsvAdd(fields,(string)record.positionID); CsvAdd(fields,(string)record.entryOrderTicket);
   CsvAdd(fields,(string)record.lastExitDealTicket); CsvAdd(fields,record.route); CsvAdd(fields,record.mode);
   CsvAdd(fields,(string)(long)record.entryTime); CsvAdd(fields,(string)(long)record.exitTime);
   CsvAdd(fields,(string)(long)TimeTradeServer());
   CsvAdd(fields,"FINALIZATION_OBSERVED_HERE_ORIGINAL_PRESET_UNPROVEN_IF_RECOVERED");
   row+=fields+"\r\n";
   bool seek=FileSeek(h,0,SEEK_END);
   ResetLastError();
   uint written=seek?FileWriteString(h,row):0;
   int error=GetLastError();
   FileFlush(h); int flushError=GetLastError(); FileClose(h);
   if(!seek || written==0 || error!=0 || flushError!=0)
      Print("[BOOK][TRADE_CONTEXT_WRITE_FAILED] partial telemetry retained; financial row unaffected");
}
#endif
