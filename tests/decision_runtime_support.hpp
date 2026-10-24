// API adapters for ACTUAL BookDecisionRuntime. Not a broker/MetaEditor test.
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>
using string=std::string;
using ulong=unsigned long;
using uint=unsigned int;
using datetime=long;
constexpr int TICK_FLAG_LAST=8,TICK_FLAG_VOLUME=16,TICK_FLAG_BUY=32,TICK_FLAG_SELL=64;
constexpr int COPY_TICKS_TRADE=1,MQL_MEMORY_USED=1,MSS_OK=1;
int Inp_SignalTF=60,Inp_ContextTF=180;
int Inp_ArmedTimeoutSec=90,Inp_StartHHMM=0,Inp_StopEntryHHMM=2359;
struct MqlDateTime {int hour=0,min=0;};
struct MqlTick {
 long time=0,time_msc=0;double bid=0,ask=0,last=0;
 ulong volume=0;uint flags=0;double volume_real=0;
};
struct ArmedSignal {
 bool active=false;int dir=0;double regionHigh=0,regionLow=0;
 double activeSL_Pts=0,activeTP_Pts=0;datetime regionEndTime=0;
 string mode;double lots=0;string route;double breakoutEffortMin=0;
 datetime armedAt=0;bool sameSideGlassLogged=false;
};
struct MatrixSnapshot {
 int status=MSS_OK;bool absValid=false,contValid=false;
 bool absDivergence=false,absFollowingReaction=false;int dir=0,dirCont=0;
};
ArmedSignal armed;
long bd_clock_sec=1000;
ulong bd_clock_local=1,bd_clock_us=1;
int bd_last_error=0,bd_copy_error=0,bd_copy_calls=0,bd_prints=0;
uint bd_max_requested=0;
string bd_symbol="WIN_TEST";
MqlTick bd_quote;
std::vector<MqlTick> bd_provider;
bool Inp_EnableArmedDiagnostics=true;
int Inp_ResponseMode=0;
double gTickSize=1;
string Symbol(){return bd_symbol;}
long TimeTradeServer(){return bd_clock_sec;}
datetime iTime(const string&,int timeframe,int shift){return (bd_clock_sec/timeframe)*timeframe-shift*timeframe;}
int PeriodSeconds(int timeframe){return timeframe;}
void TimeToStruct(long value,MqlDateTime &clock){clock.hour=(value/3600)%24;clock.min=(value/60)%60;}
ulong GetTickCount64(){return bd_clock_local;}
ulong GetMicrosecondCount(){return ++bd_clock_us;}
long MQLInfoInteger(int){return 1;}
void ResetLastError(){bd_last_error=0;}
int GetLastError(){return bd_last_error;}
template<class... T>void PrintFormat(const char*,T...){bd_prints++;}
template<class T>void ZeroMemory(T &x){x=T{};}
template<class T>void ArrayFree(std::vector<T> &x){x.clear();}
bool SymbolInfoTick(const string&,MqlTick &tick){tick=bd_quote;return tick.time_msc>0;}
int CopyTicks(const string&,std::vector<MqlTick> &out,int,ulong from,uint count){
 bd_copy_calls++;bd_max_requested=std::max(bd_max_requested,count);
 if(bd_copy_error){bd_last_error=bd_copy_error;return -1;}
 out.clear();for(const auto &x:bd_provider){
  if(x.time_msc>=static_cast<long>(from)){out.push_back(x);if(out.size()==count)break;}
 }return static_cast<int>(out.size());
}
#define input
#include "../Include/BookDecisionInputs.mqh"
#undef input
#include "../Include/BookMicroMath.mqh"
#include "../Include/BookDecisionRuntime.mqh"
MqlTick bd_tick(long msc,double price=100,ulong volume=10,int direction=1){
 MqlTick t{};t.time=msc/1000;t.time_msc=msc;t.bid=price;t.ask=price+1;t.last=price;
 t.volume=volume;t.volume_real=static_cast<double>(volume);t.flags=TICK_FLAG_LAST|TICK_FLAG_VOLUME;
 if(direction==1||direction==2)t.flags|=TICK_FLAG_BUY;
 if(direction==-1||direction==2)t.flags|=TICK_FLAG_SELL;
 return t;
}
void bd_now(long msc){bd_clock_sec=msc/1000;bd_quote=bd_tick(msc);}
void bd_init(double tick_size=1,const string &symbol="WIN_TEST"){
 Inp_DecisionMode=DECISION_APLICAR;Inp_DecisionAggressorSource=DECISION_FLAGS_PROVIDER_ASSERTED;
 Inp_DecisionWindowSec=5;Inp_DecisionMinReferences=16;Inp_DecisionEffortQuantile=.8;
 Inp_DecisionResultQuantile=.2;Inp_DecisionMinCoverage=.8;Inp_DecisionMinDirectionalShare=.2;
 Inp_DecisionMinAcceptance=.6;Inp_DecisionMinObservedCoverage=.5;
 Inp_DecisionMinProgressTicks=1;Inp_DecisionComparableEffortFactor=2;
 armed=ArmedSignal{};bd_symbol=symbol;gTickSize=tick_size;bd_now(1000000);bd_clock_local=1;
 bd_provider.clear();bd_copy_error=0;assert(BookDecisionInit());
}
void bd_feed(long from,long to,const std::vector<MqlTick> &ticks){
 bd_now(to);BookDecisionIngestBatch(static_cast<ulong>(from),static_cast<ulong>(to),
 ticks.data(),static_cast<int>(ticks.size()));
}
