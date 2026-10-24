#ifndef BOOK_RESEARCH_CORE_MQH
#define BOOK_RESEARCH_CORE_MQH
#include "BookRiskCore.mqh"
// Pure observational model. The caller owns EVERY value below; no access to
// strategy globals, terminal state, journals, execution functions or files.
// Price units match the native source (not cash); clocks are ms and seconds.
enum ENUM_BOOK_RESEARCH_STAGE
{
   RESEARCH_WAIT_STAGE2=0, RESEARCH_STAGE2_READY=1, RESEARCH_TRACKING=2,
   RESEARCH_FINISHED=3
};
struct BookResearchCandidate
{
   string id,symbol,route,mode;
   int direction,timeout_sec,stop_entry_hhmm;
   long created_msc,armed_at_sec,signal_bar;
   double trigger,sl_distance,tp_distance,tick_size,max_spread,max_overshoot,region_high,region_low;
   double effort_min,inner_pct,outer_pct;
   bool late_direction_block,original_eligible;
   bool risk_parameters_frozen,sigma_stop,tp_by_r;
   double frozen_sigma,sl_multiplier,sl_cap,tp_multiplier;int price_digits;
};
struct BookResearchMarketSample
{
   long now_msc,server_sec,ordinal,signal_bar;
   int hhmm;
   double bid,ask,last,live_effort,live_vwap,sigma,band_multiplier;
   int live_wave_direction;
   bool quote_available,real_trade,weis_valid,vwap_valid,context_causal;
   bool new_signal_bar,hard_snapshot_valid,hard_contradiction;
   // Completeness is evidence, never inferred from quote equality or timestamps.
   bool path_complete;
   bool financial_known,financial_possible,execution_terms_known,execution_terms_valid;
   bool book_required,book_known,book_confirmed;
   bool directional_terms,buy_terms_known,buy_terms_valid,sell_terms_known,sell_terms_valid;
   bool route_terms;bool terms_known[4],terms_valid[4];
   bool raw_identity_available;ulong raw_volume;uint raw_flags;double raw_volume_real;long raw_time_sec;
   bool hard_abs_valid,hard_cont_valid;int hard_abs_direction,hard_cont_direction;
   // Read-only closed-cache base captured at this callback, never a future bar.
   double vwap_base_pv,vwap_base_volume;long vwap_from;bool vwap_base_valid;
};
struct BookResearchTrack
{
   ENUM_BOOK_RESEARCH_STAGE stage;
   string reason,barrier,possibility,original_reason;
   bool stage2_demonstrated,entry_reference_available,path_ambiguous,dispatch_eligible_observed;
   bool eligibility_reconstructable,financial_possible,original_ended,context_incomplete,hard_context_pending;long last_signal_bar;
   long last_msc,last_ordinal,stage2_msc,stage2_ordinal,entry_msc,entry_ordinal;
   long sl_touch_msc,tp_touch_msc,finished_msc;
   double entry,sl,tp,mfe,mae,origin_mfe,origin_mae;
   double origin_price,last_exit_quote;
   long samples;
   double horizon_mfe[3],horizon_mae[3];
   bool horizon_done[3];
};

bool BookResearchFinite(const double x)
{
#ifdef __cplusplus
   return std::isfinite(x);
#else
   return MathIsValidNumber(x) && x!=EMPTY_VALUE;
#endif
}
double BookResearchAbs(const double x) { return x<0?-x:x; }
double BookResearchMax(const double x,const double y) { return x>y?x:y; }
// Exact arithmetic of ComputeLiveWaveO1 without ResponseLiveWave side effects.
void BookResearchLiveWave(const double current_volume,const double current_close,
   const double close_ref,const int closed_direction,const double accumulated_closed,
   const double average_closed,const double average_flip,
   double &effort,double &volume,double &average,int &direction)
{
   int current_direction=current_close>close_ref?1:(current_close<close_ref?-1:closed_direction);
   if(current_direction==0) current_direction=closed_direction;
   if(current_direction==closed_direction)
   { volume=accumulated_closed+current_volume;direction=closed_direction;average=average_closed; }
   else { volume=current_volume;direction=current_direction;average=average_flip; }
   effort=average>0?volume/average:0;
}
// Same tick-grid arithmetic as the native normalization helpers; financial
// state is never read or frozen through the operational risk candidate.
double BookResearchRoundGrid(const double price,const double tick,const bool up,const int digits)
{
   if(!BookResearchFinite(price) || tick<=0)return 0;
   double ratio=price/tick;
#ifdef __cplusplus
   double nearest=std::round(ratio);
   double n=BookResearchAbs(ratio-nearest)<1e-6?nearest:(up?std::ceil(ratio):std::floor(ratio));
   double scale=std::pow(10.0,digits);return std::round(n*tick*scale)/scale;
#else
   double nearest=MathRound(ratio);
   double n=BookResearchAbs(ratio-nearest)<1e-6?nearest:(up?MathCeil(ratio):MathFloor(ratio));
   return NormalizeDouble(n*tick,digits);
#endif
}
bool BookResearchStops(const BookResearchCandidate &c,const double entry,double &sl,double &tp)
{
   sl=entry-c.direction*c.sl_distance;tp=entry+c.direction*c.tp_distance;
   if(!c.risk_parameters_frozen)return sl>0 && tp>0;
   if(c.tick_size<=0)return false;
   if(c.sigma_stop)
   {
      // Exact native pure sigma kernel: STRICT ceil/floor, without the legacy
      // point-mode near-grid tolerance. Never mutate BookRiskCandidate.
      double raw,distance;bool capped;
      if(!BRSigmaStop(c.direction,entry,c.frozen_sigma,c.sl_multiplier,c.sl_cap,c.tick_size,sl,raw,distance,capped))return false;
#ifdef __cplusplus
      double scale=std::pow(10.0,c.price_digits);sl=std::round(sl*scale)/scale;
#else
      sl=NormalizeDouble(sl,c.price_digits);
#endif
      if(c.direction*(entry-sl)>c.sl_cap || c.direction*(entry-sl)<=0)return false;
   }
   else sl=BookResearchRoundGrid(sl,c.tick_size,c.direction==-1,c.price_digits);
   double distance=BookResearchAbs(entry-sl);
   if(c.tp_by_r)tp=entry+c.direction*distance*c.tp_multiplier;
   tp=BookResearchRoundGrid(tp,c.tick_size,c.direction==1,c.price_digits);
   return BookResearchFinite(sl) && BookResearchFinite(tp) && sl>0 && tp>0 &&
      c.direction*(entry-sl)>0 && c.direction*(tp-entry)>0;
}
void BookResearchTrackReset(BookResearchTrack &t)
{
   t.stage=RESEARCH_WAIT_STAGE2;t.reason="WAIT_STAGE2";t.barrier="NOT_ENTERED";
   t.possibility="NOT_EVALUATED";t.original_reason="";t.stage2_demonstrated=false;t.entry_reference_available=false;t.dispatch_eligible_observed=false;
   t.path_ambiguous=false;t.eligibility_reconstructable=true;t.financial_possible=false;t.original_ended=false;t.context_incomplete=false;t.hard_context_pending=false;t.last_signal_bar=0;
   t.last_msc=0;t.last_ordinal=0;t.stage2_msc=0;t.stage2_ordinal=0;t.entry_msc=0;
   t.entry_ordinal=0;t.sl_touch_msc=0;t.tp_touch_msc=0;t.finished_msc=0;
   t.entry=0;t.sl=0;t.tp=0;t.mfe=0;t.mae=0;t.origin_mfe=0;t.origin_mae=0;
   t.origin_price=0;t.last_exit_quote=0;t.samples=0;
   for(int i=0;i<3;i++) { t.horizon_mfe[i]=0;t.horizon_mae[i]=0;t.horizon_done[i]=false; }
}

// Research horizons are fixed descriptive choices, never trading thresholds.
int BookResearchHorizonSec(const int index)
{ return index==0?60:(index==1?300:900); }
void BookResearchFinish(BookResearchTrack &t,const long now_msc,const string reason)
{
   if(t.stage==RESEARCH_FINISHED) return;
   t.stage=RESEARCH_FINISHED;t.finished_msc=now_msc;t.reason=reason;
   if(!t.entry_reference_available)
      t.barrier=t.path_ambiguous?"INSUFFICIENT_MARKET_DATA":"NOT_ENTERED";
   else if(t.path_ambiguous) t.barrier="AMBIGUOUS_PATH";
   else if(t.sl_touch_msc==0 && t.tp_touch_msc==0)
   {
      long origin=t.entry_reference_available?t.entry_msc:0;
      t.barrier=origin>0 && now_msc-origin>=900000 && reason!="EOD_INCOMPLETE" && reason!="DEINIT_INCOMPLETE" && reason!="INSUFFICIENT_MARKET_DATA"?
         "NO_BARRIER_OBSERVED":"HORIZON_INCOMPLETE";
   }
}
// Exact inherited Stage2 price/Weis/VWAP/glass predicates. Outputs are purely
// descriptive: -1 original terminal cancellation; 0 waiting; 1 market-ready.
// Original temporal/session cancellation precedes tick-data waits. Hard snapshot
// applies only on an observed new M1 bar, as in ResponseBaseOnTick.
int BookResearchOriginalMarket(const BookResearchCandidate &c,
   const BookResearchMarketSample &x,string &reason)
{
   if(!c.original_eligible || (c.direction!=1 && c.direction!=-1))
   { reason="ORIGINAL_MATRIX_INELIGIBLE";return -1; }
   if(x.new_signal_bar && x.hard_snapshot_valid && (x.hard_contradiction ||
      (x.hard_abs_valid && x.hard_abs_direction==-c.direction) ||
      (x.hard_cont_valid && x.hard_cont_direction==-c.direction)))
   { reason="ARMED_CANCEL_HARD";return -1; }
   if(c.armed_at_sec>0 && x.server_sec-c.armed_at_sec>=c.timeout_sec)
   { reason="TIMEOUT_ARMED";return -1; }
   if(x.hhmm>=c.stop_entry_hhmm)
   { reason="ABORT_SESSION_END";return -1; }
   if(!x.context_causal || (x.new_signal_bar && !x.hard_snapshot_valid))
   { reason="ORIGINAL_ENTRY_NOT_RECONSTRUCTABLE";return 0; }
   if(!x.quote_available || !x.real_trade || !BookResearchFinite(x.last) || x.last<=0)
   { reason="INSUFFICIENT_MARKET_DATA";return 0; }
   if(c.direction*(x.last-c.trigger)<0) { reason="WAIT_BREAKOUT";return 0; }
   double executable=c.direction==1?x.ask:x.bid;
   if(!BookResearchFinite(executable) || executable<=0)
   { reason="INSUFFICIENT_MARKET_DATA";return 0; }
   double overshoot=BookResearchMax(c.direction*(x.last-c.trigger),c.direction*(executable-c.trigger));
   if(overshoot>c.max_overshoot) { reason="OVERSHOOT_BLOCK";return -1; }
   if(!x.weis_valid) { reason="WAIT_DATA:WEIS_CACHE";return 0; }
   if(x.live_wave_direction!=c.direction) { reason="WAIT_LIVE_WAVE_DIRECTION";return 0; }
   if(!BookResearchFinite(x.live_effort))
   { reason="ORIGINAL_ENTRY_NOT_RECONSTRUCTABLE";return 0; }
   if(x.live_effort<c.effort_min) { reason="WAIT_LIVE_WAVE_EFFORT";return 0; }
   if(!x.vwap_valid || !BookResearchFinite(x.live_vwap) || x.live_vwap<=0 ||
      !BookResearchFinite(x.sigma) || !BookResearchFinite(x.band_multiplier))
   { reason="LATE_VWAP_INVALID";return -1; }
   double upper=x.live_vwap+x.sigma*x.band_multiplier;
   double lower=x.live_vwap-x.sigma*x.band_multiplier;
   double range=upper-lower;
   if(!BookResearchFinite(range) || range<=0) { reason="LATE_VWAP_INVALID";return -1; }
   double pos=(x.last-lower)/range;
   int abs_dir=pos>=c.inner_pct?-1:(pos<=1.0-c.inner_pct?1:0);
   int cont_dir=abs_dir==0?0:-abs_dir;
   bool mismatch=(c.route=="ABS"?abs_dir:cont_dir)!=c.direction;
   if(c.late_direction_block && mismatch) { reason="LATE_DIRECTION_BLOCK";return -1; }
   bool glass=pos>c.outer_pct || pos<1.0-c.outer_pct;
   bool opposite_abs=(c.direction==-1 && pos<1.0-c.outer_pct) ||
                     (c.direction==1 && pos>c.outer_pct);
   if(c.route=="ABS"?opposite_abs:glass) { reason="LATE_GLASS_BLOCK";return -1; }
   // Financial guards remain SEPARATE from this market proof.
   reason="ORIGINAL_STAGE2_MARKET_READY";return 1;
}
void BookResearchPossibility(const BookResearchMarketSample &x,BookResearchTrack &t)
{
   t.financial_possible=x.financial_known && x.financial_possible;
   if(!x.financial_known) t.possibility="FINANCIAL_STATE_NOT_RECONSTRUCTABLE";
   else if(!x.financial_possible) t.possibility="REAL_STATE_OR_CAPITAL_COLLISION";
   else if(!x.execution_terms_known) t.possibility="ORIGINAL_ENTRY_NOT_RECONSTRUCTABLE";
   else if(!x.execution_terms_valid) t.possibility="ORIGINAL_SIZING_STOPS_MARGIN_BLOCK";
   else if(x.book_required && !x.book_known) t.possibility="BOOK_NOT_RECONSTRUCTABLE";
   else if(x.book_required && !x.book_confirmed) t.possibility="ORIGINAL_BOOK_NOT_CONFIRMED";
   else t.possibility="ORIGINAL_DISPATCH_ELIGIBLE_OBSERVED";
   t.eligibility_reconstructable=x.financial_known && x.execution_terms_known &&
      (!x.book_required || x.book_known);
}
// A candidate and a possible executable quote are DIFFERENT observations.
// The first eligible Stage2 quote freezes a causal trigger witness. Only the
// next observed ordinal can supply an executable-price reference, after the
// original predicates have been revalidated. No best-price search is performed.
// Slippage/latency/costs/fill are unknown; a barrier is a QUOTE TOUCH, never PnL.
void BookResearchObserveQuote(const BookResearchCandidate &c,const BookResearchMarketSample &x,
   BookResearchTrack &t)
{
   if(t.stage==RESEARCH_FINISHED || x.now_msc<c.created_msc) return;
   if(t.last_ordinal>0 && x.ordinal<=t.last_ordinal)
   {
      if(x.ordinal<t.last_ordinal || x.now_msc<t.last_msc) t.path_ambiguous=true;
      return; // repeated callback identity, not equal price/time de-duplication
   }
   if(t.last_msc>0 && x.now_msc<t.last_msc) { t.path_ambiguous=true;return; }
   if(!x.path_complete) t.path_ambiguous=true;
   t.last_msc=x.now_msc;t.last_ordinal=x.ordinal;t.samples++;
   bool quote=x.quote_available && BookResearchFinite(x.bid) && BookResearchFinite(x.ask) &&
      x.bid>0 && x.ask>0 && x.ask>=x.bid;
   if(!quote)t.path_ambiguous=true;
   double exit_quote=c.direction==1?x.bid:x.ask;
   if(quote)
   {
      if(t.origin_price<=0) t.origin_price=c.direction==1?x.ask:x.bid;
      double move=c.direction*(exit_quote-t.origin_price);
      if(move>t.origin_mfe) t.origin_mfe=move;
      if(-move>t.origin_mae) t.origin_mae=-move;
      for(int h=0;h<3;h++)
      {
         if(t.horizon_done[h]) continue;
         // An event after a boundary cannot retroactively enter that horizon.
         if(x.now_msc-c.created_msc<=BookResearchHorizonSec(h)*1000)
         {
            if(move>t.horizon_mfe[h]) t.horizon_mfe[h]=move;
            if(-move>t.horizon_mae[h]) t.horizon_mae[h]=-move;
         }
         if(x.now_msc-c.created_msc>=BookResearchHorizonSec(h)*1000) t.horizon_done[h]=true;
      }
   }
   if(t.stage==RESEARCH_TRACKING)
   {
      if(quote && x.now_msc-t.entry_msc<=900000)
      {
         double move=c.direction*(exit_quote-t.entry);
         if(move>t.mfe) t.mfe=move;
         if(-move>t.mae) t.mae=-move;
         bool hit_sl=c.direction*(exit_quote-t.sl)<=0;
         bool hit_tp=c.direction*(exit_quote-t.tp)>=0;
         if(hit_sl && t.sl_touch_msc==0) t.sl_touch_msc=x.now_msc;
         if(hit_tp && t.tp_touch_msc==0) t.tp_touch_msc=x.now_msc;
         if(t.barrier=="PENDING")
         {
            if(hit_sl && hit_tp) { t.path_ambiguous=true;t.barrier="AMBIGUOUS_PATH"; }
            else if(hit_sl) t.barrier=t.path_ambiguous?"AMBIGUOUS_PATH":"SL_QUOTE_TOUCH_FIRST";
            else if(hit_tp) t.barrier=t.path_ambiguous?"AMBIGUOUS_PATH":"TP_QUOTE_TOUCH_FIRST";
         }
         t.last_exit_quote=exit_quote;
      }
      if(x.now_msc-t.entry_msc>=900000) BookResearchFinish(t,x.now_msc,"ENTRY_HORIZON_END");
      return;
   }
   if(x.now_msc-c.created_msc>=900000)
   { BookResearchFinish(t,x.now_msc,"CANDIDATE_HORIZON_END");return; }
}
void BookResearchStep(const BookResearchCandidate &c,const BookResearchMarketSample &x,
   BookResearchTrack &t)
{
   long before=t.samples;
   BookResearchObserveQuote(c,x,t);
   if(t.samples==before || t.stage==RESEARCH_FINISHED || t.stage==RESEARCH_TRACKING) return;
   bool quote=x.quote_available && BookResearchFinite(x.bid) && BookResearchFinite(x.ask) &&
      x.bid>0 && x.ask>0 && x.ask>=x.bid;
   if(t.original_ended) return; // trajectory still measured above after cancellation
   if(!x.context_causal && c.original_eligible && x.real_trade && x.last>0 && c.direction*(x.last-c.trigger)>=0)t.context_incomplete=true;
   BookResearchMarketSample evaluated=x;
   bool crossed=t.last_signal_bar>0 && x.signal_bar>0 && x.signal_bar!=t.last_signal_bar;
   evaluated.new_signal_bar=x.new_signal_bar || crossed || t.hard_context_pending;
   if(evaluated.new_signal_bar && !x.hard_snapshot_valid){t.hard_context_pending=true;t.context_incomplete=true;}
   else if(evaluated.new_signal_bar && x.hard_snapshot_valid)t.hard_context_pending=false;
   if(x.signal_bar>0)t.last_signal_bar=x.signal_bar;
   string original_reason;
   int readiness=BookResearchOriginalMarket(c,evaluated,original_reason);
   if(readiness<0)
   { t.original_ended=true;t.reason=original_reason;t.original_reason=original_reason;return; }
   if(readiness==0) { t.reason=original_reason;return; }
   BookResearchMarketSample terms=x;
   if(x.directional_terms)
   {terms.execution_terms_known=c.direction==1?x.buy_terms_known:x.sell_terms_known;
    terms.execution_terms_valid=c.direction==1?x.buy_terms_valid:x.sell_terms_valid;}
   if(x.route_terms)
   {int term_index=(c.direction==1?0:2)+((c.mode=="TURBO" || c.mode=="TURBO_CONT")?1:0);
    terms.execution_terms_known=x.terms_known[term_index];terms.execution_terms_valid=x.terms_valid[term_index];}
   BookResearchPossibility(terms,t);
   if(!quote || x.ask-x.bid>c.max_spread) { t.reason="WAIT_SPREAD";return; }
   if(t.stage==RESEARCH_WAIT_STAGE2)
   {
      t.stage=RESEARCH_STAGE2_READY;t.stage2_demonstrated=true;
      t.stage2_msc=x.now_msc;t.stage2_ordinal=x.ordinal;
      t.reason="ORIGINAL_STAGE2_MARKET_READY";return;
   }
   if(x.ordinal<=t.stage2_ordinal || x.now_msc<t.stage2_msc) return;
   // Unknown financial/terms/book evidence cannot prove dispatch. A separately
   // labelled MARKET reference can still measure the quoted path under frozen
   // distance assumptions; it is excluded from executable-ORIGINAL statistics.
   if(x.financial_known && !x.financial_possible)
   { t.original_ended=true;t.reason=t.possibility;t.original_reason=t.reason;return; }
   if(terms.execution_terms_known && !terms.execution_terms_valid)
   { t.original_ended=true;t.reason=t.possibility;t.original_reason=t.reason;return; }
   if(x.book_required && x.book_known && !x.book_confirmed)
   { t.reason=t.possibility;return; }
   double executable=c.direction==1?x.ask:x.bid;
   // Preserve the two final dispatch guards descriptively, without journal use.
   if(c.direction*(executable-c.trigger)<0)
   { t.original_ended=true;t.reason="LATE_BREAKOUT_LOST";t.original_reason=t.reason;return; }
   if(c.direction*(executable-c.trigger)>c.max_overshoot)
   { t.original_ended=true;t.reason="LATE_OVERSHOOT_BLOCK";t.original_reason=t.reason;return; }
   if(!BookResearchFinite(c.sl_distance) || !BookResearchFinite(c.tp_distance) ||
      c.sl_distance<=0 || c.tp_distance<=0)
   { t.reason="ORIGINAL_ENTRY_NOT_RECONSTRUCTABLE";return; }
   double sl,tp;if(!BookResearchStops(c,executable,sl,tp))
   {t.original_ended=true;t.reason="ORIGINAL_STOPS_UNRECONSTRUCTABLE";t.original_reason=t.reason;return;}
   t.entry=executable;t.sl=sl;t.tp=tp;t.entry_msc=x.now_msc;t.entry_ordinal=x.ordinal;
   t.entry_reference_available=true;t.stage=RESEARCH_TRACKING;t.barrier="PENDING";
   t.dispatch_eligible_observed=!t.context_incomplete && t.eligibility_reconstructable && t.financial_possible &&
      terms.execution_terms_valid && (!x.book_required || x.book_confirmed);
   t.reason=t.dispatch_eligible_observed?"HYPOTHETICAL_EXECUTABLE_REFERENCE_NOT_A_FILL":
      "CONDITIONAL_MARKET_REFERENCE_ORIGINAL_ENTRY_NOT_RECONSTRUCTABLE";
}
#endif
