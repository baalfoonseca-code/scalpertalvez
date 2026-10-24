// Controlled terminal/journal adapters for actual SendOrder body extraction.
// This is a host integration fixture, never a MetaEditor or broker emulator.
#include <cassert>
#include <cmath>
#include <cfloat>
const double EMPTY_VALUE=DBL_MAX;
#include <cstdint>
#include <iostream>
#include <map>
#include <string>
#include <vector>
#include <algorithm>
using string=std::string;
using datetime=long long;
using uint=unsigned int;
using ulong=unsigned long;
struct MqlTick { long long time_msc=1000000; double bid=100,ask=101,last=101; uint flags=60; ulong volume=1; double volume_real=1; };
struct MqlTradeResult { uint request_id=1; ulong order=1,deal=1; uint retcode=10009; };
struct MqlDateTime {int year=2026,day_of_year=296,hour=9,min=30;};
enum ENUM_ORDER_TYPE { ORDER_TYPE_BUY,ORDER_TYPE_SELL };
enum { ORDER_FILLING_FOK=0,SYMBOL_TRADE_STOPS_LEVEL=1,SYMBOL_POINT=2,ACCOUNT_MARGIN_FREE=3,
       TRADE_RETCODE_DONE=10009,TRADE_RETCODE_PLACED=10008,TRADE_RETCODE_DONE_PARTIAL=10010,
       TICK_FLAG_LAST=4,TICK_FLAG_VOLUME=8,TICK_FLAG_BUY=16,TICK_FLAG_SELL=32,TERMINAL_CONNECTED=20,
       RESPONSE_ORIGINAL=0,RESPONSE_OBSERVAR=1,BD_DATA=0,BD_BREAKOUT=1,BD_WAVE_DIRECTION=2,
       BD_WAVE_EFFORT=3,BD_OTHER=4,BD_SPREAD=5,ERR_FILE_NOT_EXIST=5004 };
constexpr ulong BOOK_GATE_DECISION_BUDGET_US=50000;
int Inp_MaxTradesDay=10,ordersEnteredToday=0;
int Inp_SignalTF=1,Inp_ContextTF=3,gMagicCore=60001;
int Inp_ArmedTimeoutSec=90,Inp_StopEntryHHMM=1530,Inp_ResponseMode=RESPONSE_ORIGINAL;
bool Inp_DOM_TradeGateEnable=false,dailyRiskBlocked=false,gAccountingUnresolved=false;
bool Inp_EnableLateDirectionBlock=false,wwValid=true,gLiveDirectionTelemetryValid=false,
     gLateDirectionMismatch=false,gLateMismatchLogged=false,gSpreadHoldLogged=false;
int gLiveDirAbs=0,gLiveDirCont=0;
double Inp_VWAP_Inner_Pct=0.6,Inp_VWAP_Outer_Pct=1.5,SigmaD1=1000,BandMultiplier=1;
bool gEntryJournalInvalid=false,gExitJournalInvalid=false;
bool gEntryJournalCleanupPending=false,gExitJournalCleanupPending=false,gRequestJournalUnresolved=false,
     gRequestJournalWritePending=false,gEntryJournalWritePending=false,gPendingOrderClassificationUnresolved=false,
     gOrderObligationScanUnresolved=false;
struct FixtureUnresolved {bool active=false,classificationPending=false,persistencePending=false;};
struct FixtureTradeRecord {ulong positionID=0;bool closed=false;double totalVolumeIn=0;};
struct FixturePendingExit {bool active=false;}gPendingExit;
std::vector<FixtureUnresolved> gUnresolvedOrders;
std::vector<FixtureTradeRecord> gTradeRecords;
int gTradeRecordCount=0;
bool fixture_open=false,fixture_pending=false,fixture_margin=true,fixture_book=true;
bool fixture_prepare=true,fixture_risk_prepare=true,fixture_mark=true,fixture_release=true;
bool fixture_risk=false,fixture_risk_terms=true,fixture_logs=true;
bool fixture_uncertain=false,fixture_dispatched=false;
bool fixture_journal_exists=false,fixture_resolve=true;
int fixture_journal_error=0,fixture_hour=9,fixture_minute=30;
datetime fixture_time=1000;
int fixture_after_prepare_action=0,fixture_after_mark_action=0;
void fixture_phase_action(int action);
int fixture_prepare_calls=0,fixture_mark_calls=0,fixture_release_calls=0,fixture_book_calls=0;
int fixture_stage=0,fixture_quote_index=0;
double gSpreadMaxPts=5,gMaxOvershoot=25,gLastBreakoutPrice=101;
string gBookGateSymbol="TEST";
bool gBookGateWaiting=false;
bool gBookGateSubscriptionOwned=true;
ulong gBookGatePrepareCalls=0,gBookGatePrepareMaxUS=0,gBookGateJournalCalls=0,gBookGateJournalMaxUS=0,
      gBookGateDispatchMaxUS=0,gBookGateReleased=0,gBookGateDecisionBudgetBlocks=0,gBookGateDecisionMaxUS=0,
      gBookGateQuoteDeferrals=0,gBookGateRevalidationMaxUS=0,gBookGateRevalidations=0,gBookGateLateDeferrals=0;
double gBookGatePrepareSumUS=0,gBookGateJournalSumUS=0;
double gBookGateRevalidationSumUS=0;
std::vector<MqlTick> fixture_quotes;
std::vector<string> fixture_audits;
string Symbol(){return gBookGateSymbol;}
string BStr(bool x){return x?"true":"false";}
string DirStr(int x){return x>0?"BUY":"SELL";}
double MathAbs(double x){return std::abs(x);}
double MathMax(double a,double b){return std::max(a,b);}
bool MathIsValidNumber(double x){return std::isfinite(x);}
int StringFind(const string &s,const string &part){auto p=s.find(part);return p==string::npos?-1:(int)p;}
ulong GetMicrosecondCount(){static ulong clock=100;return ++clock;}
datetime TimeTradeServer(){return fixture_time;}
void TimeToStruct(datetime,MqlDateTime &dt){dt.hour=fixture_hour;dt.min=fixture_minute;}
datetime iTime(string,int,int){return 960;}
long SymbolInfoInteger(string,int){return 0;}
double SymbolInfoDouble(string,int){return 1;}
double AccountInfoDouble(int){return 1000000;}
void ResetLastError(){}
int GetLastError(){return fixture_journal_error;}
bool TerminalInfoInteger(int){return true;}
template<class... A>void Print(const A&...){ }
template<class... A>void PrintFormat(const A&...){ }
template<class... A>void WriteAuditRow(const string &event,const A&...){fixture_audits.push_back(event);}
template<class T>void ZeroMemory(T &x){x=T{};}
template<class T>int ArraySize(const std::vector<T>& x){return (int)x.size();}
bool SymbolInfoTick(string,MqlTick &tick){
 if(fixture_quotes.empty())return false;
 tick=fixture_quotes[std::min(fixture_quote_index++,(int)fixture_quotes.size()-1)];return true;
}
bool HasOpenPosition(){return fixture_open;}
bool HasOwnPendingOrder(){return fixture_pending;}
double NormEntrySL(int,double p){return p;}
double NormEntryTP(int,double p){return p;}
double ComputeLotsForEntry(int,double,double){return 1;}
bool BookRiskEnabled(){return fixture_risk;}
bool BookRiskResolveTerms(int,double,string,double,double,bool,double&,double&){return fixture_risk_terms;}
bool OrderCalcMargin(ENUM_ORDER_TYPE,string,double,double,double &margin){margin=100;return fixture_margin;}
void BookDiagDispatch(const MqlTradeResult&){}
void BookDiagSendOutcome(int){}
template<class...A>void BookDiagBeginEvaluation(const A&...){}
template<class...A>void BookDiagWait(const A&...){}
template<class...A>void BookDiagPass(const A&...){}
template<class...A>void BookDiagFinish(const A&...){}
template<class...A>void BookDiagTick(const A&...){}
template<class...A>void BookDiagOvershoot(const A&...){}
template<class...A>void BookDiagLive(const A&...){}
template<class...A>void BookDiagLiveBands(const A&...){}
template<class...A>void ResponseStageSample(const A&...){}
bool GetLiveVwapSnapshot(ulong,double &vwap){vwap=10000;return true;}
bool SpreadOk(){return true;}
bool FileIsExist(string){return fixture_journal_exists;}
string RequestJournalPath(bool){return "controlled-entry-journal";}
bool ResolveRequestJournal(bool){if(!fixture_resolve)return false;fixture_journal_exists=false;return true;}
struct FixtureTrade {
 int calls=0;
 void SetExpertMagicNumber(int){}
 void SetTypeFilling(int){}
 bool PositionOpen(string,ENUM_ORDER_TYPE,double,double,double,double,string){calls++;fixture_dispatched=true;return !fixture_uncertain;}
 uint ResultRetcode(){return fixture_uncertain?10012:TRADE_RETCODE_DONE;}
 void Result(MqlTradeResult &r){r.request_id=1;r.retcode=ResultRetcode();}
 ulong ResultOrder(){return fixture_uncertain?0:1;}
 ulong ResultDeal(){return fixture_uncertain?0:1;}
}trade;
