// Observational arithmetic shared by MQL5 and the native C++ test harness.
// No strategy state, order API, tick retrieval, wall clock or I/O.
#ifndef REMORA_BOOK_MICRO_MATH_V1
#define REMORA_BOOK_MICRO_MATH_V1
#ifdef __cplusplus
#include <cmath>
bool BookMicroFinite(const double x) { return std::isfinite(x); }
double BookMicroAbs(const double x) { return std::fabs(x); }
#else
bool BookMicroFinite(const double x) { return MathIsValidNumber(x) && x!=EMPTY_VALUE; }
double BookMicroAbs(const double x) { return MathAbs(x); }
#endif

struct BookMicroFlow
{
   bool enabled,level_available;
   long from_msc,to_msc,reference_msc,count,first_msc,last_msc,last_second;
   long occupied_seconds,observed_msc,above_msc,below_msc,zone_msc;
   long consecutive_msc,max_consecutive_msc,crossings,touch_msc;
   int last_side,last_nonzero_side;
   double level,tolerance,first,last,high,low,path;
   double above_volume,below_volume,zone_volume;
};
struct BookMicroMetrics
{
   bool available,ratio_available,er_available,delta_interval_excludes_zero;
   bool pressure_robust,level_available,time_available;
   int pressure_direction;
   double volume,delta,known_coverage,known_imbalance,delta_low,delta_high;
   double net_ticks,max_ticks,total_path_ticks,efficiency,small_delta_scale;
   double temporal_coverage,acceptance_volume_ratio,acceptance_time_ratio;
   double max_excursion_ticks,return_depth_ticks;
};
void BookMicroFlowReset(BookMicroFlow &f,const long from_msc,const long to_msc,
   const double level,const double tolerance,const long reference_msc)
{
   f.enabled=true; f.from_msc=from_msc; f.to_msc=to_msc;
   f.reference_msc=reference_msc; f.level=level; f.tolerance=tolerance;
   f.level_available=BookMicroFinite(level) && level>0 &&
      BookMicroFinite(tolerance) && tolerance>=0 && reference_msc>0 && reference_msc<from_msc;
   f.count=0; f.first_msc=0; f.last_msc=0; f.last_second=-1;
   f.occupied_seconds=0; f.observed_msc=0; f.above_msc=0; f.below_msc=0; f.zone_msc=0;
   f.consecutive_msc=0; f.max_consecutive_msc=0; f.crossings=0; f.touch_msc=0;
   f.last_side=0; f.last_nonzero_side=0;
   f.first=0; f.last=0; f.high=0; f.low=0; f.path=0;
   f.above_volume=0; f.below_volume=0; f.zone_volume=0;
}
int BookMicroSide(const double price,const double level,const double tolerance)
{
   if(price>level+tolerance) return 1;
   if(price<level-tolerance) return -1;
   return 0;
}
void BookMicroFlowTick(BookMicroFlow &f,const double price,const double volume,const long msc)
{
   if(!f.enabled || !BookMicroFinite(price) || !BookMicroFinite(volume) ||
      price<=0 || volume<=0 || msc<f.from_msc || msc>f.to_msc ||
      (f.count>0 && msc<f.last_msc)) return;
   int side=f.level_available?BookMicroSide(price,f.level,f.tolerance):0;
   if(f.count==0) { f.first=price; f.first_msc=msc; f.high=price; f.low=price; }
   else
   {
      f.path+=BookMicroAbs(price-f.last);
      if(price>f.high) f.high=price;
      if(price<f.low) f.low=price;
      long gap=msc-f.last_msc;
      // Only adjacent traded observations <=1s apart support dwell. Silence
      // is explicitly uncovered, never automatically accepted trading time.
      if(gap>=0 && gap<=1000)
      {
         f.observed_msc+=gap;
         if(f.level_available && side==f.last_side)
         {
            if(side>0) f.above_msc+=gap;
            else if(side<0) f.below_msc+=gap;
            else f.zone_msc+=gap;
            f.consecutive_msc+=gap;
            if(f.consecutive_msc>f.max_consecutive_msc)
               f.max_consecutive_msc=f.consecutive_msc;
         }
         else f.consecutive_msc=0;
      }
      else f.consecutive_msc=0;
   }
   if(msc/1000!=f.last_second) { f.occupied_seconds++; f.last_second=msc/1000; }
   if(f.level_available)
   {
      if(side>0) f.above_volume+=volume;
      else if(side<0) f.below_volume+=volume;
      else f.zone_volume+=volume;
      if(side!=0 && f.last_nonzero_side!=0 && side!=f.last_nonzero_side)
      { f.crossings++; if(f.touch_msc==0) f.touch_msc=msc; }
      if(side==0 && f.touch_msc==0) f.touch_msc=msc;
      if(side!=0) f.last_nonzero_side=side;
   }
   f.last_side=side; f.last=price; f.last_msc=msc; f.count++;
}
void BookMicroCompute(const BookMicroFlow &f,const double vb,const double vs,const double vu,
   const bool complete,const long invalid,const double tick_size,const int direction,
   const bool flags_trusted,BookMicroMetrics &m)
{
   m.available=false; m.ratio_available=false; m.er_available=false;
   m.delta_interval_excludes_zero=false; m.pressure_robust=false;
   m.level_available=false; m.time_available=false; m.pressure_direction=0;
   m.volume=0; m.delta=0; m.known_coverage=0; m.known_imbalance=0;
   m.delta_low=0; m.delta_high=0; m.net_ticks=0; m.max_ticks=0;
   m.total_path_ticks=0; m.efficiency=0; m.small_delta_scale=0;
   m.temporal_coverage=0; m.acceptance_volume_ratio=0; m.acceptance_time_ratio=0;
   m.max_excursion_ticks=0; m.return_depth_ticks=0;
   if(!f.enabled || !complete || invalid>0 || f.count<=0 ||
      !BookMicroFinite(tick_size) || tick_size<=0 ||
      !BookMicroFinite(vb) || !BookMicroFinite(vs) || !BookMicroFinite(vu) ||
      vb<0 || vs<0 || vu<0 || !BookMicroFinite(f.path) || f.path<0) return;
   m.volume=vb+vs+vu; m.delta=vb-vs;
   if(!BookMicroFinite(m.volume) || m.volume<=0 || !BookMicroFinite(m.delta)) return;
   m.available=true; m.known_coverage=(vb+vs)/m.volume;
   if(vb+vs>0) { m.known_imbalance=m.delta/(vb+vs); m.ratio_available=true; }
   m.delta_low=m.delta-vu; m.delta_high=m.delta+vu;
   m.delta_interval_excludes_zero=m.delta_low>0 || m.delta_high<0;
   m.pressure_direction=m.delta_low>0?1:(m.delta_high<0?-1:0);
   m.pressure_robust=m.delta_interval_excludes_zero && flags_trusted;
   m.small_delta_scale=BookMicroAbs(m.delta)/m.volume;
   int d=direction==1 || direction==-1?direction:m.pressure_direction;
   if(d==0) d=1; // Direction used for geometry is separately exported by runtime.
   m.net_ticks=d*(f.last-f.first)/tick_size;
   m.max_ticks=(d>0?f.high-f.first:f.first-f.low)/tick_size;
   m.total_path_ticks=f.path/tick_size;
   if(f.path>0)
   {
      m.efficiency=BookMicroAbs(f.last-f.first)/f.path;
      if(m.efficiency<0) m.efficiency=0;
      if(m.efficiency>1 && m.efficiency<1+1e-12) m.efficiency=1;
      m.er_available=BookMicroFinite(m.efficiency) && m.efficiency<=1;
   }
   long duration=f.to_msc-f.from_msc+1;
   if(duration>0)
   {
      m.temporal_coverage=(double)f.occupied_seconds/((double)duration/1000.0);
      if(m.temporal_coverage>1) m.temporal_coverage=1;
   }
   m.level_available=f.level_available;
   if(f.level_available)
   {
      m.acceptance_volume_ratio=(d>0?f.above_volume:f.below_volume)/m.volume;
      if(f.observed_msc>0)
      {
         m.acceptance_time_ratio=(double)(d>0?f.above_msc:f.below_msc)/(double)f.observed_msc;
         m.time_available=true;
      }
      m.max_excursion_ticks=(d>0?f.high-f.level:f.level-f.low)/tick_size;
      if(m.max_excursion_ticks<0) m.max_excursion_ticks=0;
      m.return_depth_ticks=(d>0?f.high-f.last:f.last-f.low)/tick_size;
   }
}

// Percentile rank: ties receive midpoint rank. Caller supplies ONLY prior,
// comparable observations. These descriptive ranks never authorize trades.
#ifdef __cplusplus
double BookMicroRank(const double value,const double sample[],const int count)
#else
double BookMicroRank(const double value,const double &sample[],const int count)
#endif
{
   if(count<=0) return -1;
   double less=0,equal=0;
   for(int i=0;i<count;i++)
   { if(sample[i]<value) less++; else if(sample[i]==value) equal++; }
   return (less+0.5*equal)/(double)count;
}
#ifdef __cplusplus
bool BookMicroER11(const double closes[],const int count,double &er,double &direction)
#else
bool BookMicroER11(const double &closes[],const int count,double &er,double &direction)
#endif
{
   er=0; direction=0;
   if(count!=11) return false;
   double path=0;
   for(int i=0;i<11;i++)
   {
      if(!BookMicroFinite(closes[i]) || closes[i]<=0) return false;
      if(i>0) path+=BookMicroAbs(closes[i]-closes[i-1]);
   }
   if(path<=0) return false;
   double net=closes[0]-closes[10];
   direction=net>0?1:(net<0?-1:0); er=BookMicroAbs(net)/path;
   return BookMicroFinite(er) && er>=0 && er<=1;
}

struct BookMicroC1
{
   bool available,abs_c1,cont_c1,divergence,stall,reaction,extension;
   int abs_poc_state,cont_poc_state;
   double abs_min,abs_body,cont_min;
};
void BookMicroC1Parallel(const bool windows,const double sigma,const double abs_mult,
   const double body_mult,const double cont_mult,const double move,const double poc_move,
   const double body,const int abs_dir,const int cont_dir,const int wave_dir,
   const bool abs_effort,const bool cont_effort,const bool candle_direction,
   const double follow_ratio,BookMicroC1 &a)
{
   a.available=false; a.abs_c1=false; a.cont_c1=false;
   a.divergence=false; a.stall=false; a.reaction=false; a.extension=false;
   a.abs_poc_state=0; a.cont_poc_state=0; a.abs_min=0; a.abs_body=0; a.cont_min=0;
   // Zero means explicitly unconfigured, not a hidden calibrated threshold.
   if(!windows || !BookMicroFinite(sigma) || sigma<=0 ||
      !BookMicroFinite(abs_mult) || abs_mult<=0 || !BookMicroFinite(body_mult) || body_mult<=0 ||
      !BookMicroFinite(cont_mult) || cont_mult<=0 || !BookMicroFinite(move) ||
      !BookMicroFinite(poc_move) || !BookMicroFinite(body) || body<0 ||
      !BookMicroFinite(follow_ratio) || follow_ratio<0) return;
   a.abs_min=sigma*abs_mult; a.abs_body=sigma*body_mult; a.cont_min=sigma*cont_mult;
   if(!BookMicroFinite(a.abs_min) || !BookMicroFinite(a.abs_body) ||
      !BookMicroFinite(a.cont_min)) return;
   a.available=true;
   bool follows=poc_move*move>0 && BookMicroAbs(poc_move)>=BookMicroAbs(move)*follow_ratio;
   bool abs_displaced=BookMicroAbs(move)>=a.abs_min;
   bool cont_displaced=BookMicroAbs(move)>=a.cont_min;
   int move_dir=move>0?1:-1;
   // 1 NO_DISPLACEMENT, 2 FOLLOWING, 3 DIVERGENT match existing enum.
   a.abs_poc_state=abs_displaced?(follows?2:3):1;
   a.cont_poc_state=cont_displaced?(follows?2:3):1;
   a.divergence=a.abs_poc_state==3;
   a.stall=a.abs_poc_state==1 && body<=a.abs_body;
   a.reaction=a.abs_poc_state==2 && abs_displaced && move_dir==abs_dir;
   a.extension=a.abs_poc_state==2 && abs_displaced && move_dir==-abs_dir;
   a.abs_c1=abs_effort && (a.divergence || a.stall || a.reaction);
   a.cont_c1=cont_effort && cont_displaced && a.cont_poc_state==2 &&
      move_dir==cont_dir && wave_dir==cont_dir && candle_direction;
}

struct BookMicroSnapshot
{
   bool captured,suspended,matrix_available,history_available,conditional_available,er_m1_available;
   bool poc_migration_available,reaction_er_available,reaction_time_available,reaction_poc_available;
   bool wave_path_available,wave_age_available,wave_reference_available;
   bool opposite_snapshot_available,opposite_candidate,reference_available;
   int geometry_direction,regime,test_status,reaction_status,history_count,conditional_count;
   int activity_label,pressure_label,wave_history_count;
   long test_start,test_end,reaction_start,reference_msc;
   long observer_last_us,observer_count,observer_total_us,observer_max_us,observer_discarded;
   double p_volume,p_pressure,p_y,p_m,resistance,deterioration;
   double er_m1_10,er_m1_direction,poc_migration;
   double reaction_recovery_ticks,reaction_efficiency,reaction_volume_ratio,reaction_time_ratio;
   double reaction_net_delta,reaction_poc_migration;
   double wave_volume_per_second,wave_path_ticks,wave_volume_per_point,wave_relative_intensity;
   double sigma_reference,original_abs_min,original_abs_body,original_cont_min;
   bool original_abs_c1,original_cont_c1;
   int original_abs_poc_state,original_cont_poc_state;
   BookMicroFlow flow;
   BookMicroMetrics metrics;
   BookMicroC1 c1;
};
#endif
