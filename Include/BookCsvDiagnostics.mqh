#ifndef BOOK_CSV_DIAGNOSTICS_MQH
#define BOOK_CSV_DIAGNOSTICS_MQH
// Financial CSV validation only. Never modifies, truncates or repairs source bytes.
// Include in place of InitializeTradeCsvIndex, after the legacy CSV helpers.
bool gTradeCsvInfrastructureUnresolved=true;
string gBookCsvLastDiagnostic="";
ulong gBookCsvVerifiedSize=0;
bool gBookCsvObservedEver=false;
bool gBookCsvSentinelWarning=false;

// A durable path-seen marker survives restart even after old trade records have
// aged out of the current accounting window. This is evidence of prior presence,
// never a backup or a replacement for the financial CSV.
bool BookCsvSentinelIdentity(string &path,string &payload)
{
   string identity=AccountInfoString(ACCOUNT_SERVER)+"|"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+
      "|"+Symbol()+"|"+(string)gMagicCore+"|"+gTradeCsvFileName;
   uchar bytes[],key[],digest[];
   int count=StringToCharArray(identity,bytes,0,WHOLE_ARRAY,CP_UTF8);
   if(count<=1 || ArrayResize(bytes,count-1)!=count-1) return false;
   ResetLastError();
   if(CryptEncode(CRYPT_HASH_SHA256,bytes,key,digest)!=32 || GetLastError()!=0 || ArraySize(digest)!=32)
      return false;
   string hash=""; for(int i=0;i<32;i++) hash+=StringFormat("%02x",(uint)digest[i]);
   path="BOOK_CSV_SEEN_"+hash+".state";
   payload="BOOK_CSV_SEEN_V1\n"+hash+"\n";
   return true;
}

// Return 0 only for positively absent metadata, 1 for valid prior presence,
// -1 for uncertain/corrupt metadata. Never reinterpret uncertainty as absence.
int BookCsvSentinelStatus()
{
   string path,payload;
   if(!BookCsvSentinelIdentity(path,payload)) return -1;
   ResetLastError(); bool exists=FileIsExist(path); int probeError=GetLastError();
   if(!exists) return (probeError==0 || probeError==ERR_FILE_NOT_EXIST)?0:-1;
   ResetLastError(); int h=FileOpen(path,FILE_READ|FILE_BIN|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return -1;
   ResetLastError(); ulong size=FileSize(h); int sizeError=GetLastError();
   if(sizeError!=0 || size==0 || size>256) { FileClose(h); return -1; }
   uchar bytes[];
   if(ArrayResize(bytes,(int)size)!=(int)size) { FileClose(h); return -1; }
   ResetLastError(); uint read=FileReadArray(h,bytes,0,(int)size); int readError=GetLastError();
   ResetLastError(); FileClose(h); int closeError=GetLastError();
   if(read!=(uint)size || readError!=0 || closeError!=0) return -1;
   return CharArrayToString(bytes,0,(int)size,CP_UTF8)==payload?1:-1;
}

void BookCsvEnsureSentinel()
{
   int status=BookCsvSentinelStatus();
   if(status==1) return;
   string path,payload;
   if(status==0 && BookCsvSentinelIdentity(path,payload))
   {
      // Existing/corrupt markers are preserved. Only positively absent metadata
      // is created, followed by durable flush and a separate readback.
      ResetLastError(); int h=FileOpen(path,FILE_WRITE|FILE_BIN);
      if(h!=INVALID_HANDLE)
      {
         uchar encoded[]; int count=StringToCharArray(payload,encoded,0,WHOLE_ARRAY,CP_UTF8);
         ResetLastError(); uint written=(count>1)?FileWriteArray(h,encoded,0,count-1):0;
         int writeError=GetLastError();
         ResetLastError(); FileFlush(h); int flushError=GetLastError();
         ResetLastError(); FileClose(h); int closeError=GetLastError();
         if(count>1 && written==(uint)(count-1) && writeError==0 && flushError==0 && closeError==0 &&
            BookCsvSentinelStatus()==1) return;
      }
   }
   if(!gBookCsvSentinelWarning)
      Print("[BOOK][CSV_PRESENCE_SENTINEL_UNVERIFIED] valid CSV retained; cross-restart missing-file proof unavailable; existing marker never overwritten");
   gBookCsvSentinelWarning=true;
}

bool BookCsvCanCreateMissing(const bool previouslySeen,const bool markerKnownAbsent,
                             const bool financialEvidence)
{
   return !previouslySeen && markerKnownAbsent && !financialEvidence;
}

bool BookCsvReject(const string fileName,const long logicalRow,const int expected,
                   const int received,const string reason,const long offset=-1)
{
   gTradeCsvIndexLoaded=false;
   gTradeCsvAppendSafe=false;
   gTradeCsvInfrastructureUnresolved=true;
   string detail=fileName+"|"+(string)logicalRow+"|"+(string)expected+"|"+
      (string)received+"|"+reason+"|"+(string)offset;
   if(detail!=gBookCsvLastDiagnostic)
      PrintFormat("[BOOK][TRADE_CSV_INVALID] file=%s logical_row=%I64d expected_columns=%d received_columns=%d cause=%s character_offset=%I64d; ORIGINAL_PRESERVED; entries require reconciliation",
                  fileName,logicalRow,expected,received,reason,offset);
   gBookCsvLastDiagnostic=detail;
   return false;
}

// Parser exposes a precise syntactic cause. Column count includes an empty tail.
bool BookCsvParse(const string record,string &fields[],string &reason,int &offset)
{
   ArrayResize(fields,0); reason=""; offset=-1;
   string value=""; bool quoted=false,afterQuote=false;
   for(int i=0;i<StringLen(record);i++)
   {
      ushort c=StringGetCharacter(record,i);
      if(quoted)
      {
         if(c==34)
         {
            if(i+1<StringLen(record) && StringGetCharacter(record,i+1)==34)
            { value+="\""; i++; }
            else { quoted=false; afterQuote=true; }
         }
         else value+=StringSubstr(record,i,1);
      }
      else if(c==44)
      {
         int n=ArraySize(fields);
         if(ArrayResize(fields,n+1)!=n+1) { reason="MEMORY_FAILURE"; offset=i; return false; }
         fields[n]=value; value=""; afterQuote=false;
      }
      else if(c==34)
      {
         if(StringLen(value)>0 || afterQuote) { reason="QUOTE_IN_UNQUOTED_FIELD"; offset=i; return false; }
         quoted=true;
      }
      else
      {
         if(afterQuote || c==10 || c==13)
         { reason=afterQuote?"CHARACTER_AFTER_CLOSING_QUOTE":"UNQUOTED_LINE_BREAK"; offset=i; return false; }
         value+=StringSubstr(record,i,1);
      }
   }
   if(quoted) { reason="UNTERMINATED_QUOTED_FIELD"; offset=StringLen(record); return false; }
   int n=ArraySize(fields);
   if(ArrayResize(fields,n+1)!=n+1) { reason="MEMORY_FAILURE"; return false; }
   fields[n]=value;
   return true;
}

bool InitializeTradeCsvIndex(string fileName)
{
   // Prefix IDs remain available for diagnosis but are never authoritative until
   // the ENTIRE file validates. Interrupted recovery cannot bless a partial scan.
   ArrayResize(gTradeCsvWrittenPIDs,0);
   gTradeCsvIndexLoaded=false; gTradeCsvAppendSafe=false;
   gTradeCsvInfrastructureUnresolved=true; gBookCsvVerifiedSize=0;
   ResetLastError();
   int h=FileOpen(fileName,FILE_READ|FILE_BIN|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h==INVALID_HANDLE) return BookCsvReject(fileName,0,0,0,"OPEN_ERROR_"+(string)GetLastError());
   gBookCsvObservedEver=true;
   ResetLastError(); ulong size=FileSize(h); int sizeError=GetLastError();
   if(sizeError!=0 || size==0 || size>67108864)
   { FileClose(h); return BookCsvReject(fileName,0,0,0,size>67108864?"SCAN_LIMIT_64_MIB":"EMPTY_OR_SIZE_QUERY_FAILED"); }
   uchar bytes[];
   if(ArrayResize(bytes,(int)size)!=(int)size)
   { FileClose(h); return BookCsvReject(fileName,0,0,0,"ALLOCATION_FAILED"); }
   ResetLastError(); uint read=FileReadArray(h,bytes,0,(int)size); int readError=GetLastError();
   ResetLastError(); ulong after=FileSize(h); int afterError=GetLastError();
   ResetLastError(); FileClose(h); int closeError=GetLastError();
   if(read!=(uint)size || readError!=0 || afterError!=0 || after!=size || closeError!=0)
      return BookCsvReject(fileName,0,0,0,"READ_FAILED_OR_CONCURRENT_SIZE_CHANGE");
   if(size>=2 && ((bytes[0]==255 && bytes[1]==254) || (bytes[0]==254 && bytes[1]==255)))
      return BookCsvReject(fileName,0,0,0,"UTF16_ENCODING_REQUIRES_EXPLICIT_MIGRATION");
   for(int i=0;i<(int)size;i++)
      if(bytes[i]==0) return BookCsvReject(fileName,0,0,0,"EMBEDDED_NUL",i);
   // UTF-8 BOM is metadata, not part of SCHEMA_VERSION; no source rewrite.
   int begin=(size>=3 && bytes[0]==239 && bytes[1]==187 && bytes[2]==191)?3:0;
   string content=CharArrayToString(bytes,begin,(int)size-begin,begin==3?CP_UTF8:CP_ACP);
   ArrayFree(bytes);
   string expectedLine=""; CsvConfigHeader(expectedLine); CsvTradeHeader(expectedLine);
   string expected[],headers[],reason=""; int errorOffset=-1;
   if(!BookCsvParse(expectedLine,expected,reason,errorOffset))
      return BookCsvReject(fileName,0,0,0,"INTERNAL_SCHEMA_"+reason,errorOffset);
   int expectedColumns=ArraySize(expected);
   int schema=-1,symbol=-1,magic=-1,pid=-1,closed=-1,accounting=-1;
   bool haveHeader=false,inQuote=false;
   long positionRows[];
   int recordStart=0,len=StringLen(content); long logicalRow=0;
   for(int i=0;i<len;i++)
   {
      ushort c=StringGetCharacter(content,i);
      if(c==34)
      {
         if(inQuote && i+1<len && StringGetCharacter(content,i+1)==34) i++;
         else inQuote=!inQuote;
      }
      if((c!=10 && c!=13) || inQuote) continue;
      string record=StringSubstr(content,recordStart,i-recordStart);
      int start=recordStart;
      if(c==13 && i+1<len && StringGetCharacter(content,i+1)==10) i++;
      recordStart=i+1; logicalRow++;
      string fields[];
      if(!BookCsvParse(record,fields,reason,errorOffset))
         return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields)+1,reason,start+errorOffset);
      if(!haveHeader)
      {
         if(ArraySize(fields)!=expectedColumns)
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"HEADER_COLUMN_COUNT",start);
         for(int k=0;k<expectedColumns;k++)
            if(fields[k]!=expected[k])
               return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"HEADER_FIELD_"+(string)(k+1)+"_EXPECTED_"+expected[k],start);
         ArrayCopy(headers,fields);
         schema=CsvColumnIndex(headers,"SCHEMA_VERSION"); symbol=CsvColumnIndex(headers,"SYMBOL");
         magic=CsvColumnIndex(headers,"MAGIC"); pid=CsvColumnIndex(headers,"POSITION_ID");
         closed=CsvColumnIndex(headers,"CLOSED"); accounting=CsvColumnIndex(headers,"ACCOUNTING_RESOLVED");
         if(schema<0 || symbol<0 || magic<0 || pid<0 || closed<0 || accounting<0)
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"INTERNAL_REQUIRED_COLUMN_MISSING",start);
         haveHeader=true;
      }
      else if(StringLen(record)>0)
      {
         if(ArraySize(fields)!=expectedColumns)
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"ROW_COLUMN_COUNT",start);
         if(fields[schema]!="RC1" || fields[symbol]!=Symbol() || fields[magic]!=IntegerToString(gMagicCore))
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"ROW_SCHEMA_OR_OWNERSHIP_MISMATCH",start);
         if(fields[closed]!="1" || (fields[accounting]!="0" && fields[accounting]!="1"))
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"INVALID_FINALIZATION_FLAGS",start);
         ulong positionID=0;
         if(!CsvParsePID(fields[pid],positionID))
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"INVALID_OR_OVERFLOW_POSITION_ID",start);
         // Amortized append; a sorted copy below detects duplicates in O(n log n)
         // instead of repeatedly scanning an entire historical ledger.
         int count=ArraySize(gTradeCsvWrittenPIDs);
         if(ArrayResize(gTradeCsvWrittenPIDs,count+1,1024)!=count+1 ||
            ArrayResize(positionRows,count+1,1024)!=count+1)
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"PID_INDEX_ALLOCATION_FAILED",start);
         gTradeCsvWrittenPIDs[count]=positionID; positionRows[count]=logicalRow;
         if(fields[accounting]=="0")
         {
            if(!PersistEconomicMarker(positionID)) gEconomicMarkerScanUnresolved=true;
            RememberDeferredAccountingPID(positionID);
         }
      }
   }
   if(!haveHeader || inQuote || recordStart!=len)
   {
      string tail=StringSubstr(content,recordStart); string fields[];
      bool parsed=BookCsvParse(tail,fields,reason,errorOffset);
      return BookCsvReject(fileName,logicalRow+1,expectedColumns,ArraySize(fields)+(parsed?0:1),
            inQuote?"UNTERMINATED_QUOTED_TAIL":"UNTERMINATED_RECORD",recordStart);
   }
   ulong sorted[];
   int count=ArraySize(gTradeCsvWrittenPIDs);
   if(count>0 && (ArrayCopy(sorted,gTradeCsvWrittenPIDs)!=count || !ArraySort(sorted)))
      return BookCsvReject(fileName,0,expectedColumns,expectedColumns,"DUPLICATE_VALIDATION_ALLOCATION_FAILED");
   for(int i=1;i<count;i++)
      if(sorted[i]==sorted[i-1])
      {
         bool first=false; long duplicateRow=0;
         for(int k=0;k<count;k++)
            if(gTradeCsvWrittenPIDs[k]==sorted[i])
            { if(first) { duplicateRow=positionRows[k]; break; } first=true; }
         return BookCsvReject(fileName,duplicateRow,expectedColumns,expectedColumns,"DUPLICATE_POSITION_ID_"+(string)sorted[i]);
      }
   gTradeCsvIndexLoaded=true; gTradeCsvAppendSafe=true;
   gTradeCsvInfrastructureUnresolved=false; gBookCsvVerifiedSize=size;
   BookCsvEnsureSentinel();
   if(gBookCsvLastDiagnostic!="")
      PrintFormat("[BOOK][TRADE_CSV_RECOVERED] file=%s logical_rows=%I64d positions=%d; external repair verified without rewriting",fileName,logicalRow,ArraySize(gTradeCsvWrittenPIDs));
   gBookCsvLastDiagnostic="";
   return true;
}

// Detect external append/truncation before our next write. This protects against
// accidental second instances; concurrent writers still require operator isolation.
bool BookCsvBeforeAppend()
{
   if(csvTradeHandle==INVALID_HANDLE || !gTradeCsvAppendSafe || !gTradeCsvIndexLoaded)
      return BookCsvReject(gTradeCsvFileName,0,0,0,"APPEND_WITHOUT_VERIFIED_INDEX");
   if(!FileIsExist(gTradeCsvFileName))
      return BookCsvReject(gTradeCsvFileName,0,0,0,"PREVIOUS_FINANCIAL_FILE_MISSING");
   ResetLastError(); ulong size=FileSize(csvTradeHandle); int error=GetLastError();
   if(error!=0 || size!=gBookCsvVerifiedSize || !FileSeek(csvTradeHandle,0,SEEK_END))
      return BookCsvReject(gTradeCsvFileName,0,0,0,"FILE_CHANGED_SINCE_VERIFIED_SCAN");
   return true;
}

bool BookCsvRecoveryPathAllowed()
{
   ResetLastError(); bool exists=FileIsExist(gTradeCsvFileName); int error=GetLastError();
   bool evidence=(gTradeRecordCount>0 || ordersEnteredToday>0 ||
      gPendingExec.active || gPendingExit.active || gOpenPos.active);
   if(!exists && ((error!=0 && error!=ERR_FILE_NOT_EXIST) ||
      !BookCsvCanCreateMissing(gBookCsvObservedEver,BookCsvSentinelStatus()==0,evidence)))
      return BookCsvReject(gTradeCsvFileName,0,0,0,"PREVIOUS_FINANCIAL_FILE_MISSING_OR_PROBE_UNCERTAIN");
   return true;
}

int BookCsvOpenInitialFile()
{
   ResetLastError(); bool exists=FileIsExist(gTradeCsvFileName); int probeError=GetLastError();
   if(!exists && probeError!=0 && probeError!=ERR_FILE_NOT_EXIST)
   { BookCsvReject(gTradeCsvFileName,0,0,0,"INITIAL_PATH_PROBE_UNCERTAIN"); return INVALID_HANDLE; }
   // A missing trade file alongside recovered trade/request evidence is loss of
   // evidence, never an invitation to recreate an empty historical ledger.
   bool evidence=(gTradeRecordCount>0 || ordersEnteredToday>0 ||
      gPendingExec.active || gPendingExit.active || gOpenPos.active);
   if(!exists && !BookCsvCanCreateMissing(gBookCsvObservedEver,BookCsvSentinelStatus()==0,evidence))
   { BookCsvReject(gTradeCsvFileName,0,0,0,"MISSING_FILE_WITH_RECOVERED_FINANCIAL_EVIDENCE"); return INVALID_HANDLE; }
   ResetLastError();
   int h=FileOpen(gTradeCsvFileName,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h==INVALID_HANDLE)
   { BookCsvReject(gTradeCsvFileName,0,0,0,"INITIAL_OPEN_FAILED"); return INVALID_HANDLE; }
   ResetLastError(); ulong size=FileSize(h); int sizeError=GetLastError();
   if(sizeError!=0 || (exists && size==0))
   {
      FileClose(h); gBookCsvObservedEver=exists;
      BookCsvReject(gTradeCsvFileName,0,0,0,sizeError!=0?"INITIAL_SIZE_UNVERIFIED":"EXISTING_EMPTY_FILE_PRESERVED");
      return INVALID_HANDLE;
   }
   gBookCsvObservedEver=true;
   return h;
}
#endif
