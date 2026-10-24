// Host file/terminal adapters for actual production CSV/index/recovery functions.
// These are deterministic fixtures, not MT5 durability or Windows locking proof.
#include "risk_journal_host_support.hpp"
#include <map>
#include <set>
#include <cstdlib>
#include <cassert>
using ulong=unsigned long;
using uchar=unsigned char;
const int INVALID_HANDLE=-1,ERR_FILE_NOT_EXIST=5004;
const int FILE_READ=1,FILE_WRITE=2,FILE_BIN=4,FILE_TXT=8,FILE_ANSI=16;
const int FILE_SHARE_READ=32,FILE_SHARE_WRITE=64,WHOLE_ARRAY=-1;
const double EMPTY_VALUE=std::numeric_limits<double>::max();
const int CP_UTF8=65001,CP_ACP=0,TIME_DATE=1,TIME_SECONDS=2;

// CSV_PRODUCTION_TYPES

std::vector<ulong> gTradeCsvWrittenPIDs,gDeferredAccountingPIDs,gDeferredDeals;
bool gTradeCsvIndexLoaded=false,gTradeCsvAppendSafe=false;
string gTradeCsvFileName="Scalper01_RC1_WDOX26_60002_Trades.csv";
int csvTradeHandle=INVALID_HANDLE;
datetime gNextTradeCsvRecovery=0,csvNow=1000;
bool gEconomicMarkerScanUnresolved=false,gAccountingUnresolved=false;
bool gAccountingCapacityUnresolved=false,gDeferredRegistryUnavailable=false;
bool gPendingOrderClassificationUnresolved=false,gQuotaHistoryValid=true;
bool gLiveOwnershipUnresolved=false,gMultipleOwnOrdersActive=false;
bool gOrderRegistryUnavailable=false,gOrderObligationScanUnresolved=false;
bool gDeferredDealOverflow=false,gDailyEconomicsValid=true,gIdentityLossUnresolved=false;
bool gRequestJournalUnresolved=false,gRequestJournalWritePending=false;
bool gEntryJournalCleanupPending=false,gExitJournalCleanupPending=false;
int gDeferredDealFallbackCount=0,gTradeRecordCount=0;
struct FixtureUnresolvedOrder {bool active=false,classificationPending=false,persistencePending=false;};
std::vector<FixtureUnresolvedOrder> gUnresolvedOrders;
std::vector<TradeRecord> gTradeRecords;
struct FixtureActivity {bool active=false;} gPendingExec,gPendingExit,gOpenPos;
bool Inp_EnableMacroDirectionGate=true,Inp_EnableLateDirectionBlock=false,Inp_RejectPOCTies=false;
bool Inp_DOM_Enable=false,gDailyPnLRValid=true,dailyRiskBlocked=false;
double dailyNetPnL=17.5,dailyPnLR=.7;
int consecutiveLosses=0,requestsAcceptedToday=1,ordersEnteredToday=1;
int hardFlipsPerDay=0,armedCancelHard=0,oppositeRearmAfterHard=0;

std::map<std::string,string> csvFiles;
struct CsvHandle {string path;int flags;std::size_t offset=0;};
std::map<int,CsvHandle> csvHandles;
int csvError=0,csvNextHandle=10,csvWrites=0,csvCreates=0,csvReadCalls=0,csvFlushes=0;
int csvMarkerCalls=0,csvDeferredCalls=0,csvCorrelations=0,csvSentinelCalls=0;
bool csvPartialRead=false,csvPartialWrite=false,csvFlushFailure=false,csvMarkerFailure=false;
bool csvPublicationFailure=false;
int csvAllocationFailure=-1;
std::set<ulong> csvMarkers;

inline int StringFind(const string& value,const string& part) {
 auto pos=value.find(part);return pos==std::string::npos?-1:(int)pos;
}
inline int StringReplace(string& value,const string& before,const string& after) {
 int count=0;std::size_t pos=0;
 while((pos=value.find(before,pos))!=std::string::npos){value.replace(pos,before.size(),after);pos+=after.size();count++;}
 return count;
}
inline string IntegerToString(long value){return std::to_string(value);}
inline string StringFormat(const char* format,ulong value) {
 if(std::string(format)=="%I64u")return std::to_string(value);
 char buf[256];std::snprintf(buf,sizeof(buf),format,value);return buf;
}
inline string TimeToString(datetime,int){return "2026.10.21 10:00:00";}
inline datetime TimeTradeServer(){return csvNow;}
inline datetime AccountingDayStart(){return 0;}
inline void ResetLastError(){csvError=0;}
inline int GetLastError(){return csvError;}
template<class... A> void PrintFormat(const A&...){ }
template<class T> int ArraySize(const std::vector<T>& value){return (int)value.size();}
template<class T> int ArrayResize(std::vector<T>& value,int size,int=0){
 if(size>0&&csvAllocationFailure>0&&--csvAllocationFailure==0)return -1;
 value.resize((std::size_t)size);return size;
}
template<class T> int ArrayCopy(std::vector<T>& out,const std::vector<T>& in){
 if(csvPublicationFailure&&(const void*)&out==(const void*)&gTradeCsvWrittenPIDs)return -1;
 out=in;return (int)in.size();
}
template<class T> bool ArraySort(std::vector<T>& value){std::sort(value.begin(),value.end());return true;}
template<class T> void ArrayFree(std::vector<T>& value){value.clear();}
inline int StringToCharArray(const string& value,std::vector<uchar>& out,int,int,int){
 out.assign(value.begin(),value.end());out.push_back(0);return (int)out.size();
}
inline string CharArrayToString(const std::vector<uchar>& in,int start,int count,int){
 return std::string(in.begin()+start,in.begin()+start+count);
}
inline bool FileIsExist(const string& path){return csvFiles.count(path)>0;}
inline int FileOpen(const string& path,int flags){
 for(const auto& item:csvHandles){const auto& old=item.second;if(old.path!=path)continue;
  if(((flags&FILE_READ)&&!(old.flags&FILE_SHARE_READ)) ||
     ((flags&FILE_WRITE)&&!(old.flags&FILE_SHARE_WRITE)) ||
     ((old.flags&FILE_READ)&&!(flags&FILE_SHARE_READ)) ||
     ((old.flags&FILE_WRITE)&&!(flags&FILE_SHARE_WRITE))){csvError=5003;return INVALID_HANDLE;}
 }
 if(!FileIsExist(path)){
  if(!(flags&FILE_WRITE)){csvError=ERR_FILE_NOT_EXIST;return INVALID_HANDLE;}
  csvFiles[path]="";csvCreates++;
 }
 int result=csvNextHandle++;csvHandles[result]={path,flags,0};return result;
}
inline ulong FileSize(int handle){
 auto it=csvHandles.find(handle);if(it==csvHandles.end()){csvError=5018;return 0;}
 return (ulong)csvFiles[it->second.path].size();
}
inline uint FileReadArray(int handle,std::vector<uchar>& value,int start,int count){
 auto it=csvHandles.find(handle);if(it==csvHandles.end()){csvError=5018;return 0;}
 auto& file=it->second;const auto& bytes=csvFiles[file.path];
 int actual=(int)std::min<std::size_t>((std::size_t)count,bytes.size()-file.offset);
 if(csvPartialRead&&actual>0)actual--;
 for(int i=0;i<actual;i++)value.at((std::size_t)start+i)=(uchar)bytes[file.offset+i];
 file.offset+=actual;csvReadCalls++;return (uint)actual;
}
inline void FileClose(int handle){csvHandles.erase(handle);}
inline bool FileSeek(int handle,long offset,int){
 auto it=csvHandles.find(handle);if(it==csvHandles.end()){csvError=5018;return false;}
 it->second.offset=csvFiles[it->second.path].size()+offset;return true;
}
inline uint FileWriteString(int handle,const string& value){
 auto it=csvHandles.find(handle);if(it==csvHandles.end()||!(it->second.flags&FILE_WRITE)){csvError=5018;return 0;}
 auto& file=it->second;auto& bytes=csvFiles[file.path];int count=(int)value.size();
 if(csvPartialWrite&&count>0)count=std::max(0,count-5);
 bytes.replace(file.offset,std::min<std::size_t>(count,bytes.size()-file.offset),value.substr(0,count));
 file.offset+=count;csvWrites++;return (uint)count;
}
inline void FileFlush(int){csvFlushes++;if(csvFlushFailure)csvError=5010;}
inline void BookCsvEnsureSentinel(){csvSentinelCalls++;}
inline int BookCsvSentinelStatus(){return 0;}
inline bool PersistEconomicMarker(ulong pid){csvMarkerCalls++;if(csvMarkerFailure)return false;csvMarkers.insert(pid);return true;}
inline void RememberDeferredAccountingPID(ulong pid){
 csvDeferredCalls++;
 if(std::find(gDeferredAccountingPIDs.begin(),gDeferredAccountingPIDs.end(),pid)==gDeferredAccountingPIDs.end())
  gDeferredAccountingPIDs.push_back(pid);
}
inline void BookIdentityCorrelateTrade(const TradeRecord&){csvCorrelations++;}
inline void DOMObserveTrade(const TradeRecord&){ }
