#include <cassert>
#include <iostream>
#include <limits>
#include "../Include/BookArmedMath.mqh"

int main()
{
    int cases=0;
    BookArmedTrace t;
    BookArmedResetTrace(t,1,100000,100);
    assert(!t.touched && t.samples==0 && BookArmedTimeoutClass(t)==1); ++cases;
    BookArmedBeginEvaluation(t);
    BookArmedObserveTrade(t,98,100100,101000);
    BookArmedBlock(t,BD_BREAKOUT);
    assert(t.best==98 && t.worst==98 && t.first_blocked==BD_BREAKOUT); ++cases;
    assert((BookArmedNotEvaluated(t)&BD_BOOK)!=0); ++cases;
    assert(BookArmedTimeoutClass(t)==1); ++cases;
    BookArmedBeginEvaluation(t);
    BookArmedObserveTrade(t,100,102000,102000);
    BookArmedPass(t,BD_DATA|BD_BREAKOUT);
    BookArmedBlock(t,BD_WAVE_DIRECTION);
    assert(t.touched && t.first_touch_observed_msc-t.armed_msc==2000); ++cases;
    assert(t.first_blocked==BD_BREAKOUT && t.last_blocked==BD_WAVE_DIRECTION); ++cases;
    assert((t.ever_blocked&(BD_BREAKOUT|BD_WAVE_DIRECTION))==(BD_BREAKOUT|BD_WAVE_DIRECTION)); ++cases;
    assert(t.blocked==BD_WAVE_DIRECTION && BookArmedTimeoutClass(t)==2); ++cases;
    assert((BookArmedNotEvaluated(t)&BD_WAVE_EFFORT)!=0); ++cases;
    assert((BookArmedNotEvaluated(t)&BD_BOOK)!=0); ++cases;
    BookArmedBeginEvaluation(t);
    BookArmedObserveTrade(t,99,103000,103000);
    BookArmedBlock(t,BD_BREAKOUT);
    assert(t.touched && BookArmedTimeoutClass(t)==2); ++cases; // Retraction never erases touch.
    assert(t.best==100 && t.worst==98); ++cases;
    BookArmedBeginEvaluation(t);
    BookArmedPass(t,BD_DATA|BD_BREAKOUT|BD_WAVE_DIRECTION);
    BookArmedBlock(t,BD_WAVE_EFFORT);
    assert((BookArmedNotEvaluated(t)&BD_SPREAD)!=0); ++cases;
    BookArmedBeginEvaluation(t);
    BookArmedPass(t,BD_DATA|BD_BREAKOUT|BD_WAVE_DIRECTION|BD_WAVE_EFFORT);
    BookArmedBlock(t,BD_SPREAD);
    assert(t.last_blocked==BD_SPREAD && (BookArmedNotEvaluated(t)&BD_BOOK)); ++cases;
    BookArmedBeginEvaluation(t);
    BookArmedPass(t,BD_DATA|BD_BREAKOUT|BD_WAVE_DIRECTION|BD_WAVE_EFFORT|BD_SPREAD);
    BookArmedBlock(t,BD_BOOK);
    assert(t.blocked==BD_BOOK && (BookArmedNotEvaluated(t)&BD_BOOK)==0); ++cases;
    BookArmedBeginEvaluation(t);
    assert(t.blocked==0 && t.evaluated==0 && t.last_blocked==BD_BOOK); ++cases;
    // A failed read is data unavailability; book remains explicitly not evaluated.
    BookArmedBlock(t,BD_DATA);
    assert((BookArmedNotEvaluated(t)&BD_BOOK)!=0 && !(t.blocked&BD_BOOK)); ++cases;
    BookArmedResetTrace(t,-1,200000,100);
    BookArmedObserveTrade(t,102,201000,201000);
    BookArmedObserveTrade(t,99,202000,202000);
    BookArmedObserveTrade(t,103,203000,203000);
    assert(t.best==99 && t.worst==103 && t.first_touch_observed_msc==202000); ++cases;
    assert(t.samples==3 && t.last_tick_msc==203000 && BookArmedTimeoutClass(t)==2); ++cases;
    auto previous=t.samples;
    BookArmedObserveTrade(t,0,204000,204000);
    BookArmedObserveTrade(t,-1,204000,204000);
    BookArmedObserveTrade(t,std::numeric_limits<double>::infinity(),204000,204000);
    BookArmedObserveTrade(t,std::numeric_limits<double>::quiet_NaN(),204000,204000);
    BookArmedObserveTrade(t,100,0,204000);
    assert(t.samples==previous && t.best==99 && t.worst==103); ++cases;
    BookArmedResetTrace(t,1,300000,100);
    assert(t.first_blocked==0 && t.last_blocked==0 && t.ever_blocked==0 && !t.touched); ++cases;
    BookArmedObserveTrade(t,101,299000,301000);
    // Exchange time retained separately; touch lag is the actual server observation,
    // never an invented precise exchange-arrival clock.
    assert(t.first_touch_observed_msc==301000 && t.last_tick_msc==299000); ++cases;
    BookArmedResetTrace(t,0,300000,100);
    BookArmedObserveTrade(t,101,301000,301000);
    assert(t.samples==0); ++cases;
    std::cout << "armed_trace_harness: " << cases << " deterministic cases passed\n";
}
