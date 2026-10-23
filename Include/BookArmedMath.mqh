#ifndef BOOK_ARMED_MATH_V1
#define BOOK_ARMED_MATH_V1
// Shared by MQL5 and the native deterministic diagnostic harness.
#ifdef __cplusplus
#include <cmath>
bool BookArmedFinite(double x) { return std::isfinite(x); }
#else
bool BookArmedFinite(double x) { return MathIsValidNumber(x) && x!=EMPTY_VALUE; }
#endif
enum BOOK_DIAG_GATE
{
   BD_BREAKOUT=1, BD_WAVE_DIRECTION=2, BD_WAVE_EFFORT=4,
   BD_BOOK=8, BD_SPREAD=16, BD_DATA=32, BD_OTHER=64,
   BD_ALL=127
};
struct BookArmedTrace
{
   int direction,evaluated,blocked,ever_blocked,first_blocked,last_blocked;
   long armed_msc,first_touch_observed_msc,last_tick_msc,samples,evaluations;
   double trigger,best,worst;
   bool price_available,touched;
};
void BookArmedResetTrace(BookArmedTrace &t,int direction,long armed_msc,double trigger)
{
   t.direction=direction; t.evaluated=0; t.blocked=0; t.ever_blocked=0;
   t.first_blocked=0; t.last_blocked=0; t.armed_msc=armed_msc;
   t.first_touch_observed_msc=0; t.last_tick_msc=0; t.samples=0; t.evaluations=0;
   t.trigger=trigger; t.best=0; t.worst=0; t.price_available=false; t.touched=false;
}
void BookArmedBeginEvaluation(BookArmedTrace &t)
{ t.evaluated=0; t.blocked=0; t.evaluations++; }
void BookArmedPass(BookArmedTrace &t,int mask) { t.evaluated|=mask; }
void BookArmedBlock(BookArmedTrace &t,int mask)
{
   t.evaluated|=mask; t.blocked|=mask; t.ever_blocked|=mask;
   if(t.first_blocked==0) t.first_blocked=mask;
   t.last_blocked=mask;
}
void BookArmedObserveTrade(BookArmedTrace &t,double price,long tick_msc,long observed_msc)
{
   if((t.direction!=1 && t.direction!=-1) || !BookArmedFinite(price) || price<=0 ||
      !BookArmedFinite(t.trigger) || t.trigger<=0 || tick_msc<=0) return;
   // Callback observations are samples, not an exhaustive exchange tick stream.
   if(!t.price_available)
   { t.best=price; t.worst=price; t.price_available=true; }
   else
   {
      if(t.direction*(price-t.best)>0) t.best=price;
      if(t.direction*(price-t.worst)<0) t.worst=price;
   }
   t.samples++; t.last_tick_msc=tick_msc;
   if(!t.touched && t.direction*(price-t.trigger)>=0)
   { t.touched=true; t.first_touch_observed_msc=observed_msc; }
}
int BookArmedNotEvaluated(const BookArmedTrace &t) { return BD_ALL & ~t.evaluated; }
// 1 = no observed breakout; 2 = trigger observed, later execution blocked.
int BookArmedTimeoutClass(const BookArmedTrace &t) { return t.touched?2:1; }
#endif
