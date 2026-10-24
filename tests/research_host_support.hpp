// Deterministic terminal adapters for the actual research module, not MT5.
#include <algorithm>
#include <cassert>
#include <cmath>
#include <iostream>
#include <string>
#include <vector>
#include <filesystem>
using string=std::string;using ulong=unsigned long;using uint=unsigned int;
using datetime=long;
constexpr int TICK_FLAG_LAST=8,TICK_FLAG_VOLUME=16,TICK_FLAG_BUY=32,TICK_FLAG_SELL=64;
constexpr int COPY_TICKS_TRADE=1,COPY_TICKS_ALL=3;
struct MqlTick{long time=0,time_msc=0;double bid=0,ask=0,last=0;ulong volume=0;uint flags=0;double volume_real=0;};
bool Inp_ResearchEnable=true;
long research_clock=1000000;ulong research_us=0;int research_error=0,research_copy_error=0,research_copy_calls=0;
std::vector<MqlTick> research_trades,research_quotes;
string research_symbol="WDOX26";
long TimeTradeServer(){return research_clock/1000;}
string Symbol(){return research_symbol;}
ulong GetMicrosecondCount(){return ++research_us;}
void ResetLastError(){research_error=0;}
int GetLastError(){return research_error;}
template<class T>void ZeroMemory(T &x){x=T{};}
template<class T>void ArrayFree(std::vector<T> &x){x.clear();}
bool SymbolInfoTick(const string&,MqlTick &q){
 q=MqlTick{};q.time_msc=research_clock;q.time=research_clock/1000;q.bid=5500;q.ask=5500.5;q.last=5500;return true;
}
int CopyTicks(const string&,std::vector<MqlTick>&out,int kind,ulong from,uint count){
 research_copy_calls++;if(research_copy_error){research_error=1;return -1;}
 out.clear();for(auto &q:(kind==COPY_TICKS_TRADE?research_trades:research_quotes))
  if(q.time_msc>=static_cast<long>(from)){out.push_back(q);if(out.size()==count)break;}
 return static_cast<int>(out.size());
}
#define input
#include "../Include/BookDecisionInputs.mqh"
#undef input
#include "../Include/BookMicroMath.mqh"
#include "../Include/BookDecisionCore.mqh"
#include "../Include/BookResearchRuntime.mqh"
MqlTick research_tick(long msc,double price,int direction=1){
 MqlTick q{};q.time_msc=msc;q.time=msc/1000;q.bid=price;q.ask=price+.5;q.last=price;
 q.volume=10;q.volume_real=10;q.flags=TICK_FLAG_LAST|TICK_FLAG_VOLUME;
 if(direction==1||direction==2)q.flags|=TICK_FLAG_BUY;
 if(direction==-1||direction==2)q.flags|=TICK_FLAG_SELL;
 return q;
}
BookResearchCandidate research_candidate(string id="candidate",int direction=1,bool cont=false){
 BookResearchCandidate c{};c.id=id;c.symbol=research_symbol;c.route=cont?"CONT":"ABS";c.mode="BASE";
 c.direction=direction;c.created_msc=1000000;c.armed_at_sec=1000;c.signal_bar=960;
 c.timeout_sec=90;c.stop_entry_hhmm=2359;c.trigger=5500;c.sl_distance=5;c.tp_distance=10;
 c.tick_size=.5;c.max_spread=1;c.max_overshoot=20;c.effort_min=1.2;c.inner_pct=.6;c.outer_pct=.9;c.original_eligible=true;return c;
}
BookResearchMarketSample research_sample(long msc,long ordinal,double price=5500,int direction=1){
 BookResearchMarketSample x{};x.now_msc=msc;x.server_sec=msc/1000;x.ordinal=ordinal;x.signal_bar=960;
 x.raw_identity_available=true;x.raw_time_sec=msc/1000;x.raw_volume=10;x.raw_volume_real=10;x.raw_flags=TICK_FLAG_LAST|TICK_FLAG_VOLUME|TICK_FLAG_BUY;
 x.bid=price;x.ask=price+.5;x.last=price;x.quote_available=true;x.real_trade=true;x.path_complete=true;
 x.weis_valid=true;x.live_wave_direction=direction;x.live_effort=2;x.vwap_valid=true;x.live_vwap=5500;x.sigma=100;x.band_multiplier=1;
 x.context_causal=true;x.financial_known=true;x.financial_possible=true;x.execution_terms_known=true;x.execution_terms_valid=true;return x;
}
void research_init(const string &run="fixture"){
 Inp_ResearchEnable=true;research_clock=1000000;research_us=0;research_copy_error=0;
 research_trades.clear();research_quotes.clear();
 BookDecisionConfig config;BookDecisionConfigDefaults(config);config.tick_size=.5;
 BookResearchRuntimeInit(run,"fixture-preset","103 historical bindings plus research bool","123","60002","fixture-code",DECISION_APLICAR,config);
}
