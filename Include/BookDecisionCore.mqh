#ifndef BOOK_DECISION_CORE_MQH
#define BOOK_DECISION_CORE_MQH
// Prerequisites: BookDecisionInputs and BookMicroMath. Pure shared arithmetic:
// no terminal API, logger, CSV queue, strategy mutation or financial dispatch.
// Units: price progress/path/reclaim in asset ticks; effort in original integer
// TRADE-volume units; timestamps/dwell in milliseconds; ranks/fractions unitless.
// PREDICATES (also exercised in tests/decision_policy_cases.hpp):
// Q: asserted TRADE flags AND ordered, complete known segment AND no invalid or
// ambiguous rows AND KnownCoverage>=coverage AND observed_ms/duration>=observed.
// Material: Q AND robust DeltaInterval AND abs(Delta)/V>=directional_share.
// HighT: Material in -entry_direction AND effort_upper_ECDF>=effort_q.
// Resistance_T = 1-max(midrank(NetProgress),midrank(MaxProgress)); require
// Resistance_T>=1-result_q, using >=min_refs PRIOR same-duration/source/bucket/
// direction/pressure-direction/tick-size samples within effort/factor..effort*factor.
// Accept(d): Q AND causal frozen level AND observed_ms>0 AND both traded-volume
// fraction and observed-dwell fraction beyond level+tolerance >=acceptance.
// R: Accept(entry_d) AND NetProgress>=progress_ticks AND reclaim>=progress_ticks.
// No low-progress requirement is applied to R, and its delta need not invert.
// CONT forward: Material AND Accept(d) AND NetProgress>=progress_ticks AND
// d*(window_VWAP-prior_window_VWAP)/tick_size>=progress_ticks AND conditional
// net-result rank>result_q. High volume/ER alone never satisfies this predicate.
// Rejection: Material in -d AND Accept(-d) AND opposite NetProgress>=progress_ticks
// AND last beyond the ORIGINAL forward context level by progress_ticks. A pause
// or opposite delta without these produced-price/acceptance terms cannot cancel.
// Fresh: 0<=now-window_end<=2*window_sec*1000ms. Evidence epochs must match and
// no evidence end can be in the future. These never extend the original timeout.
#define BOOK_DECISION_HISTORY_CAP 384

enum ENUM_BOOK_DECISION_ABS_SUBTYPE
{
   DECISION_ABS_STALL_STRICT=0,
   DECISION_ABS_DIVERGENCE=1,
   DECISION_ABS_FOLLOWING_REACTION=2
};
struct BookDecisionConfig
{
   int source,window_sec,min_refs;
   double effort_q,result_q,coverage,directional_share,acceptance;
   double observed_coverage,progress_ticks,effort_factor,tick_size;
};
struct BookDecisionWindow
{
   BookMicroFlow flow;
   double vb,vs,vu,pv,previous_vwap;
   long invalid,ambiguous,generation;
   int source,bucket;
   bool complete,ordered,source_ok,previous_available;
};
struct BookDecisionRanks
{
   bool available;
   int count,conditional_count;
   double effort_rank,net_rank,max_rank,resistance;
};
struct BookDecisionReference
{
   long from_msc,to_msc,duration,generation;
   int source,bucket,direction,pressure_direction;
   double tick_size,effort,net_progress,max_progress;
};
struct BookDecisionHistory
{
   BookDecisionReference samples[BOOK_DECISION_HISTORY_CAP];
   int count,next;
   long last_insert_to_msc;
};
struct BookDecisionEvidence
{
   bool have_test,have_reaction,have_forward,have_current;
   BookDecisionWindow test,reaction,forward,current;
   BookDecisionRanks test_ranks,forward_ranks,current_ranks;
   long now_msc;
   int original_subtype;
};
struct BookDecisionVerdict
{
   ENUM_BOOK_DECISION_RESULT result;
   string reason;
   double resistance,net_progress,max_progress,er;
   double volume_acceptance,time_acceptance,pressure_share,coverage;
   int conditional_count;
};

double BookDecisionMax(const double a,const double b) { return a>b?a:b; }
double BookDecisionMin(const double a,const double b) { return a<b?a:b; }
void BookDecisionConfigDefaults(BookDecisionConfig &c)
{
   c.source=DECISION_FLAGS_UNVERIFIED;c.window_sec=5;c.min_refs=16;
   c.effort_q=0.80;c.result_q=0.20;c.coverage=0.80;
   c.directional_share=0.20;c.acceptance=0.60;c.observed_coverage=0.50;
   c.progress_ticks=1.0;c.effort_factor=2.0;c.tick_size=1.0;
}
bool BookDecisionConfigValid(const BookDecisionConfig &c)
{
   return (c.source==DECISION_FLAGS_UNVERIFIED || c.source==DECISION_FLAGS_PROVIDER_ASSERTED) &&
      c.window_sec>=1 && c.window_sec<=10 && c.min_refs>=4 && c.min_refs<=64 &&
      BookMicroFinite(c.effort_q) && c.effort_q>0 && c.effort_q<1 &&
      BookMicroFinite(c.result_q) && c.result_q>0 && c.result_q<1 &&
      c.result_q<c.effort_q &&
      BookMicroFinite(c.coverage) && c.coverage>0 && c.coverage<=1 &&
      BookMicroFinite(c.directional_share) && c.directional_share>0 && c.directional_share<=1 &&
      BookMicroFinite(c.acceptance) && c.acceptance>0.5 && c.acceptance<=1 &&
      BookMicroFinite(c.observed_coverage) && c.observed_coverage>0 && c.observed_coverage<=1 &&
      BookMicroFinite(c.progress_ticks) && c.progress_ticks>0 &&
      BookMicroFinite(c.effort_factor) && c.effort_factor>=1 && c.effort_factor<=4 &&
      BookMicroFinite(c.tick_size) && c.tick_size>0;
}
void BookDecisionRanksReset(BookDecisionRanks &r)
{
   r.available=false;r.count=0;r.conditional_count=0;
   r.effort_rank=-1;r.net_rank=-1;r.max_rank=-1;r.resistance=-1;
}
void BookDecisionWindowReset(BookDecisionWindow &w,const long from_msc,const long to_msc,
   const double level,const double tolerance,const long reference_msc,
   const double previous_vwap,const bool previous_available,const int source,
   const int bucket,const long generation)
{
   BookMicroFlowReset(w.flow,from_msc,to_msc,level,tolerance,reference_msc);
   w.vb=0;w.vs=0;w.vu=0;w.pv=0;w.previous_vwap=previous_vwap;
   w.invalid=0;w.ambiguous=0;w.generation=generation;w.source=source;w.bucket=bucket;
   w.complete=false;w.ordered=true;w.source_ok=true;w.previous_available=previous_available;
}
void BookDecisionWindowTick(BookDecisionWindow &w,const double price,const double volume,
   const long msc,const int aggressor)
{
   if(!BookMicroFinite(price) || !BookMicroFinite(volume) || price<=0 || volume<=0 ||
      msc<w.flow.from_msc || msc>w.flow.to_msc)
   { w.invalid++;return; }
   if(w.flow.count>0 && msc<w.flow.last_msc)
   { w.invalid++;w.ordered=false;return; }
   if(aggressor!=1 && aggressor!=-1 && aggressor!=0 && aggressor!=2)
   { w.invalid++;w.source_ok=false;return; }
   // Identical prints, including identical millisecond, are distinct rows.
   // Ordinal de-duplication belongs to the shared acquisition cursor, not price.
   BookMicroFlowTick(w.flow,price,volume,msc);
   if(aggressor==1) w.vb+=volume;
   else if(aggressor==-1) w.vs+=volume;
   else { w.vu+=volume;if(aggressor==2) w.ambiguous++; }
   w.pv+=price*volume;
   if(!BookMicroFinite(w.vb) || !BookMicroFinite(w.vs) || !BookMicroFinite(w.vu) ||
      !BookMicroFinite(w.pv)) w.invalid++;
}
bool BookDecisionWindowQuality(const BookDecisionConfig &c,const BookDecisionWindow &w,
   BookMicroMetrics &m,const int direction)
{
   BookMicroCompute(w.flow,w.vb,w.vs,w.vu,w.complete,w.invalid,c.tick_size,direction,
      c.source==DECISION_FLAGS_PROVIDER_ASSERTED,m);
   // Keep the inherited raw/observational implementation untouched. This
   // operational copy uses the exact path ratio, without its roundoff clamp.
   m.efficiency=0;m.er_available=false;
   if(w.flow.path>0)
   {
      m.efficiency=BookMicroAbs(w.flow.last-w.flow.first)/w.flow.path;
      m.er_available=BookMicroFinite(m.efficiency) && m.efficiency>=0 && m.efficiency<=1;
   }
   long duration=w.flow.to_msc-w.flow.from_msc+1;
   // Operational coverage is observed adjacent traded time, never the count of
   // occupied seconds. No trade and silence cannot manufacture dwell.
   if(duration>0)
      m.temporal_coverage=(double)w.flow.observed_msc/(double)duration;
   return BookDecisionConfigValid(c) && c.source==DECISION_FLAGS_PROVIDER_ASSERTED &&
      w.source==c.source && w.source_ok && w.ordered && w.complete &&
      w.invalid==0 && w.ambiguous==0 && w.flow.count>=2 && duration>0 &&
      w.flow.from_msc>0 &&
      m.available && m.ratio_available && m.known_coverage>=c.coverage &&
      m.temporal_coverage>=c.observed_coverage && m.temporal_coverage<=1;
}
bool BookDecisionMaterial(const BookDecisionConfig &c,const BookMicroMetrics &m)
{
   return m.available && m.ratio_available && m.pressure_robust &&
      m.delta_interval_excludes_zero && m.small_delta_scale>=c.directional_share;
}
bool BookDecisionAcceptance(const BookDecisionConfig &c,const BookMicroMetrics &m)
{
   return m.level_available && m.time_available &&
      m.acceptance_volume_ratio>=c.acceptance && m.acceptance_time_ratio>=c.acceptance;
}
void BookDecisionHistoryReset(BookDecisionHistory &h)
{ h.count=0;h.next=0;h.last_insert_to_msc=0; }
void BookDecisionHistoryInsert(const BookDecisionConfig &c,BookDecisionHistory &h,
   const BookDecisionWindow &w)
{
   if(w.flow.to_msc<=h.last_insert_to_msc ||
      w.flow.to_msc-w.flow.from_msc+1!=(long)c.window_sec*1000) return;
   BookMicroMetrics m;
   if(!BookDecisionWindowQuality(c,w,m,1) || !BookDecisionMaterial(c,m)) return;
   for(int d=-1;d<=1;d+=2)
   {
      BookMicroCompute(w.flow,w.vb,w.vs,w.vu,true,0,c.tick_size,d,true,m);
      BookDecisionReference s;
      s.from_msc=w.flow.from_msc;s.to_msc=w.flow.to_msc;
      s.duration=w.flow.to_msc-w.flow.from_msc+1;s.generation=w.generation;
      s.source=w.source;s.bucket=w.bucket;s.direction=d;
      s.pressure_direction=m.pressure_direction;s.tick_size=c.tick_size;
      s.effort=BookMicroAbs(m.delta);s.net_progress=m.net_ticks;s.max_progress=m.max_ticks;
      h.samples[h.next]=s;h.next=(h.next+1)%BOOK_DECISION_HISTORY_CAP;
      if(h.count<BOOK_DECISION_HISTORY_CAP) h.count++;
   }
   h.last_insert_to_msc=w.flow.to_msc;
}
void BookDecisionCompare(const BookDecisionConfig &c,const BookDecisionHistory &h,
   const BookDecisionWindow &w,const int direction,BookDecisionRanks &r)
{
   BookDecisionRanksReset(r);
   BookMicroMetrics m;
   if(!BookDecisionWindowQuality(c,w,m,direction) || !BookDecisionMaterial(c,m) ||
      w.flow.to_msc-w.flow.from_msc+1!=(long)c.window_sec*1000) return;
   double nets[BOOK_DECISION_HISTORY_CAP],maxs[BOOK_DECISION_HISTORY_CAP];
   double effort=BookMicroAbs(m.delta),upper=effort*c.effort_factor;
   double lower=effort/c.effort_factor;
   if(!BookMicroFinite(upper) || !BookMicroFinite(lower)) return;
   int less_or_equal=0;
   for(int i=0;i<h.count;i++)
   {
      BookDecisionReference s=h.samples[i];
      if(s.to_msc>=w.flow.from_msc || s.duration!=(long)c.window_sec*1000 ||
         s.source!=w.source || s.bucket!=w.bucket || s.generation!=w.generation || s.direction!=direction ||
         s.pressure_direction!=m.pressure_direction || s.tick_size!=c.tick_size) continue;
      if(s.effort<=effort) less_or_equal++;
      r.count++;
      if(s.effort>=lower && s.effort<=upper)
      {
         nets[r.conditional_count]=s.net_progress;
         maxs[r.conditional_count]=s.max_progress;r.conditional_count++;
      }
   }
   if(r.count<c.min_refs || r.conditional_count<c.min_refs) return;
   // Upper empirical CDF expresses >= the configured effort quantile and lets
   // a constant historical effort reach that empirical quantile without epsilon.
   r.effort_rank=(double)less_or_equal/(double)r.count;
   r.net_rank=BookMicroRank(m.net_ticks,nets,r.conditional_count);
   r.max_rank=BookMicroRank(m.max_ticks,maxs,r.conditional_count);
   r.resistance=1.0-BookDecisionMax(r.net_rank,r.max_rank);
   r.available=true;
}
bool BookDecisionTestPredicate(const BookDecisionConfig &c,const BookDecisionWindow &w,
   const BookDecisionRanks &r,const int entry_direction)
{
   BookMicroMetrics m;
   return (entry_direction==1 || entry_direction==-1) &&
      BookDecisionWindowQuality(c,w,m,-entry_direction) && BookDecisionMaterial(c,m) &&
      m.pressure_direction==-entry_direction && w.flow.level_available &&
      r.available && r.count>=c.min_refs && r.conditional_count>=c.min_refs &&
      r.effort_rank>=c.effort_q && r.resistance>=1.0-c.result_q;
}
bool BookDecisionForwardPredicate(const BookDecisionConfig &c,const BookDecisionWindow &w,
   const BookDecisionRanks &r,const int direction)
{
   BookMicroMetrics m;
   if((direction!=1 && direction!=-1) || !BookDecisionWindowQuality(c,w,m,direction) ||
      !BookDecisionMaterial(c,m) || !BookDecisionAcceptance(c,m) ||
      !w.previous_available || !BookMicroFinite(w.previous_vwap) || w.previous_vwap<=0 ||
      !r.available || r.conditional_count<c.min_refs || r.net_rank<=c.result_q) return false;
   double current_vwap=w.pv/m.volume;
   double migration=direction*(current_vwap-w.previous_vwap)/c.tick_size;
   return BookMicroFinite(current_vwap) && BookMicroFinite(migration) &&
      m.net_ticks>=c.progress_ticks && m.max_ticks>=c.progress_ticks &&
      direction*(w.flow.last-w.flow.level)/c.tick_size>=c.progress_ticks &&
      migration>=c.progress_ticks;
}
bool BookDecisionReactionPredicate(const BookDecisionConfig &c,const BookDecisionWindow &test,
   const BookDecisionWindow &reaction,const int direction)
{
   BookMicroMetrics m;
   return reaction.flow.from_msc>test.flow.to_msc &&
      reaction.flow.reference_msc==test.flow.to_msc &&
      reaction.flow.level==test.flow.level &&
      BookDecisionWindowQuality(c,reaction,m,direction) && BookDecisionAcceptance(c,m) &&
      m.net_ticks>=c.progress_ticks &&
      direction*(reaction.flow.last-test.flow.level)/c.tick_size>=c.progress_ticks;
}
bool BookDecisionOppositePredicate(const BookDecisionConfig &c,const BookDecisionWindow &w,
   const int entry_direction,const double frozen_context)
{
   BookMicroMetrics opposite;
   return BookDecisionWindowQuality(c,w,opposite,-entry_direction) &&
      BookDecisionMaterial(c,opposite) && opposite.pressure_direction==-entry_direction &&
      BookDecisionAcceptance(c,opposite) && opposite.net_ticks>=c.progress_ticks &&
      BookMicroFinite(frozen_context) && frozen_context>0 &&
      entry_direction*(w.flow.last-frozen_context)/c.tick_size<=-c.progress_ticks;
}
void BookDecisionVerdictReset(BookDecisionVerdict &v)
{
   v.result=DECISION_DADOS_INSUFICIENTES;v.reason="UNAVAILABLE";
   v.resistance=-1;v.net_progress=0;v.max_progress=0;v.er=0;
   v.volume_acceptance=0;v.time_acceptance=0;v.pressure_share=0;v.coverage=0;
   v.conditional_count=0;
}
void BookDecisionVerdictMetrics(const BookDecisionConfig &c,const BookDecisionWindow &w,
   const int d,BookDecisionVerdict &v)
{
   BookMicroMetrics m;
   BookDecisionWindowQuality(c,w,m,d);
   v.net_progress=m.net_ticks;v.max_progress=m.max_ticks;v.er=m.efficiency;
   v.volume_acceptance=m.acceptance_volume_ratio;v.time_acceptance=m.acceptance_time_ratio;
   v.pressure_share=m.small_delta_scale;v.coverage=m.known_coverage;
}
bool BookDecisionFresh(const BookDecisionConfig &c,const BookDecisionWindow &w,const long now_msc)
{
   return now_msc>=w.flow.to_msc &&
      now_msc-w.flow.to_msc<=(long)c.window_sec*2000;
}
void BookDecisionAssess(const BookDecisionConfig &c,const BookDecisionEvidence &e,
   const int direction,const bool route_cont,const bool armed,BookDecisionVerdict &v)
{
   BookDecisionVerdictReset(v);
   if(!BookDecisionConfigValid(c)) { v.reason="CONFIG_INVALID";return; }
   if(direction!=1 && direction!=-1) { v.reason="DIRECTION_INVALID";return; }
   if(c.source!=DECISION_FLAGS_PROVIDER_ASSERTED)
   { v.reason="AGGRESSOR_SOURCE_UNVERIFIED";return; }
   if(!e.have_current) { v.reason="COLLECTION_NO_CURRENT_SEGMENT";return; }
   if(e.current.generation<=0 || e.current.flow.to_msc>e.now_msc ||
      (e.have_test && (e.test.generation!=e.current.generation || e.test.flow.to_msc>e.now_msc)) ||
      (e.have_reaction && (e.reaction.generation!=e.current.generation || e.reaction.flow.to_msc>e.now_msc)) ||
      (e.have_forward && (e.forward.generation!=e.current.generation || e.forward.flow.to_msc>e.now_msc)))
   { v.reason="EVIDENCE_GENERATION_OR_TIME_MISMATCH";return; }
   BookDecisionVerdictMetrics(c,e.current,direction,v);
   BookMicroMetrics current;
   if(!BookDecisionWindowQuality(c,e.current,current,direction))
   {
      if(e.current.invalid>0 || !e.current.ordered || !e.current.source_ok)
         v.reason="COLLECTION_INTEGRITY";
      else if(e.current.ambiguous>0) v.reason="AGGRESSOR_FLAGS_AMBIGUOUS";
      else if(current.volume<=0) v.reason="NO_TRADED_ACTIVITY";
      else v.reason="COVERAGE_OR_KNOWN_SEGMENT_INSUFFICIENT";
      // Inactivity may refute an original strict stall, but absent/invalid data
      // never masquerades as measured inactivity and never cancels an ARMED.
      if(!route_cont && e.original_subtype==DECISION_ABS_STALL_STRICT &&
         e.current.complete && e.current.source_ok && e.current.ordered &&
         e.current.invalid==0 && e.current.ambiguous==0 && e.current.flow.count==0)
      { v.result=DECISION_VETAR_CANDIDATO;v.reason="ABS_STALL_NO_TRADED_ACTIVITY"; }
      return;
   }
   if(!BookDecisionFresh(c,e.current,e.now_msc))
   { v.reason="CURRENT_SEGMENT_STALE";return; }
   double context=e.current.flow.level;
   if(route_cont && e.have_forward) context=e.forward.flow.level;
   if(BookDecisionOppositePredicate(c,e.current,direction,context))
   {
      v.result=armed?DECISION_INVALIDAR_ARMED:DECISION_VETAR_CANDIDATO;
      v.reason=route_cont?"CONT_ACCEPTED_OPPOSITE_REJECTION":"ABS_ACCEPTED_OPPOSITE_CONTINUATION";
      return;
   }
   if(route_cont)
   {
      if(BookDecisionForwardPredicate(c,e.current,e.current_ranks,direction))
      {
         v.result=DECISION_VALIDAR;v.reason="CONT_PROGRESS_ACCEPTANCE_VALUE_MIGRATION";
         v.conditional_count=e.current_ranks.conditional_count;return;
      }
      // Retained causal continuation evidence survives a small traded pause.
      // It expires by evidence age, never extends original ARMED's timeout.
      if(e.have_forward && BookDecisionFresh(c,e.forward,e.now_msc) &&
         BookDecisionForwardPredicate(c,e.forward,e.forward_ranks,direction) &&
         direction*(e.current.flow.last-e.forward.flow.level)>=-e.forward.flow.tolerance)
      {
         // A normal pause preserves the thesis, but equilibrium is not a new
         // entry authorization. No fixed delay and no trend-end inference.
         if(current.net_ticks<c.progress_ticks)
         { v.result=DECISION_AGUARDAR;v.reason="CONT_NORMAL_PAUSE_WITHOUT_CURRENT_PROGRESS"; }
         else
         { v.result=DECISION_VALIDAR;v.reason="CONT_RETAINED_CONTEXT_CURRENT_PROGRESS"; }
         v.conditional_count=e.forward_ranks.conditional_count;return;
      }
      if(!BookDecisionMaterial(c,current))
      { v.result=DECISION_AGUARDAR;v.reason="CONT_BALANCED_OR_IMMATERIAL_PRESSURE";return; }
      if(!e.current_ranks.available)
      { v.result=DECISION_DADOS_INSUFICIENTES;v.reason="CONT_COMPARABLE_REFERENCES_INSUFFICIENT";return; }
      v.result=DECISION_AGUARDAR;v.reason="CONT_PROGRESS_OR_ACCEPTANCE_UNDEFINED";return;
   }
   if(!e.have_test || !BookDecisionTestPredicate(c,e.test,e.test_ranks,direction) ||
      !BookDecisionFresh(c,e.test,e.now_msc))
   {
      if(e.original_subtype==DECISION_ABS_STALL_STRICT && !BookDecisionMaterial(c,current))
      { v.result=DECISION_VETAR_CANDIDATO;v.reason="ABS_STALL_NO_MATERIAL_DIRECTIONAL_PRESSURE";return; }
      if(e.have_test && !e.test_ranks.available)
      { v.reason="ABS_COMPARABLE_REFERENCES_INSUFFICIENT";return; }
      v.result=DECISION_AGUARDAR;v.reason="ABS_CAUSAL_RESISTANCE_TEST_NOT_PROVEN";return;
   }
   v.resistance=e.test_ranks.resistance;v.conditional_count=e.test_ranks.conditional_count;
   if(!e.have_reaction || !BookDecisionReactionPredicate(c,e.test,e.reaction,direction))
   { v.result=DECISION_AGUARDAR;v.reason="ABS_RESISTANCE_AWAITING_REACTION";return; }
   BookDecisionVerdictMetrics(c,e.reaction,direction,v);
   v.result=DECISION_VALIDAR;
   if(e.original_subtype==DECISION_ABS_DIVERGENCE) v.reason="ABS_DIVERGENCE_TEST_AND_REACTION";
   else if(e.original_subtype==DECISION_ABS_FOLLOWING_REACTION) v.reason="ABS_FOLLOWING_REACTION_PROVEN_TEST";
   else v.reason="ABS_STALL_STRICT_TEST_AND_REACTION";
}
#endif
