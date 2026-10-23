// Deterministic host adapter for executing the ACTUAL observer collection code.
// This is not an MT5 broker simulator or a native MQL5 compiler.
#include <string>
#include <type_traits>
#include <cmath>
#include <cstdint>
#include <cassert>
#include <iostream>
class string: public std::string {
public:
    using std::string::string;
    string() = default;
    string(const std::string& x):std::string(x){}
    template<class N, typename std::enable_if<std::is_arithmetic<N>::value, int>::type = 0>
    string(N x):std::string(std::to_string(x)){}
};
using ulong=unsigned long;
using uint=unsigned int;
using uchar=unsigned char;
using datetime=long;
using ENUM_MSS=int;
using ENUM_POC_STATE=int;
enum {MSS_OK=1,BOOK_ENTRY_BLOCKED=8,BD_STUB_UNUSED=999};
enum ENUM_SEND_OUTCOME {SEND_FINAL_FAILURE=0,SEND_ACCEPTED,SEND_WAIT_ARMED,
 SEND_CANCEL_REEVAL,SEND_TRADE_OR_POSITION,SEND_FINANCIAL_UNRESOLVED,SEND_ORIGINAL_CANCEL};
struct MqlDateTime { int hour=0,min=0; };
struct MqlTick { double last=0,bid=0,ask=0; long time_msc=0; };
struct MqlTradeResult { ulong order=0,deal=0; uint request_id=0,retcode=0; };
struct BookGateDecision { int state=0; double pctBid=0,pctAsk=0; string reason;
 struct { ulong sequence=0; } snapshot; };
struct ArmedSignal { string route,mode; datetime regionEndTime=0,armedAt=0;
 int dir=0; double regionHigh=0,regionLow=0,breakoutEffortMin=0; };
struct TradeRecord { bool accountingResolved=false,historyRefreshPending=false;
 ulong positionID=0,entryOrderTicket=0; double totalVolumeIn=0,weightedEntryPrice=0;
 int direction=0; string route,mode; };
ArmedSignal armed;
bool Inp_EnableArmedDiagnostics=true;
long clock_sec=1000;
ulong clock_us=1;
int gMagicCore=60001,Inp_ArmedTimeoutSec=90,Inp_StopEntryHHMM=1530;
double gBreakoutMargin=5,SigmaD1=200,VWAP_D1=100,H1=110,L1=90,BandMultiplier=1;
constexpr int INVALID_HANDLE=-1,EMPTY_VALUE=2147483647,CP_UTF8=65001,WHOLE_ARRAY=-1;
constexpr int ERR_FILE_NOT_EXIST=5019,TIME_DATE=1,ACCOUNT_LOGIN=1;
constexpr int FILE_READ=1,FILE_WRITE=2,FILE_TXT=4,FILE_ANSI=8,FILE_SHARE_READ=16;
template<class T> void ZeroMemory(T &v) { v=T{}; }
long TimeTradeServer() { return clock_sec; }
ulong GetMicrosecondCount() { return clock_us++; }
void TimeToStruct(long time,MqlDateTime &dt) { dt.hour=(time/3600)%24; dt.min=(time/60)%60; }
long AccountInfoInteger(int) { return 123; }
long ChartID() { return 456; }
string Symbol() { return "WIN"; }
int StringLen(const string &s) { return static_cast<int>(s.size()); }
void StringReplace(string &s,const string &a,const string &b) {
 std::size_t p=0;
 while((p=s.find(a,p))!=std::string::npos) { s.replace(p,a.size(),b); p+=b.size(); }
}
template<class... A> string StringFormat(const char *f,const A&...) { return f; }
template<class... A> void PrintFormat(const char*,const A&...) {}
bool IsFinalRejectedRetcode(uint retcode) { return retcode==10006; }
string ResponseComponent(const string &s) { return s; }
void ResetLastError() {}
int GetLastError() { return 0; }
bool FileIsExist(const string&) { return false; }
template<class... A> int FileOpen(const string&,A...) { return 1; }
ulong FileSize(int) { return 0; }
void FileClose(int) {}
void FileFlush(int) {}
uint FileWriteString(int,const string&s) { return static_cast<uint>(s.size()); }
string TimeToString(long,int) { return "2026.10.23"; }
// MQL5 dynamic array parameter is translated to a vector by the host generator.
#include <vector>
int StringToCharArray(const string&s,std::vector<uchar>&b,int,int,int) {
 b.assign(s.begin(),s.end()); b.push_back(0); return static_cast<int>(b.size());
}
