// Include after ResponseRecord and observer globals. Observational, bounded,
// causal snapshots only. No return value is consumed by the financial path.
#ifndef REMORA_BOOK_MICRO_RUNTIME_V1
#define REMORA_BOOK_MICRO_RUNTIME_V1
#define BOOK_MICRO_HISTORY_CAP 512
#define BOOK_MICRO_WAVE_CAP 256
#define BOOK_MICRO_MIN_HISTORY 8
struct BookMicroHistorical
{
   bool used;
   long end_msc,duration;
   int bucket,direction;
   double volume,pressure,net_ticks,max_ticks;
};
struct BookMicroWaveHistorical
{
   bool used,real_volume;
   long wave_start,end_msc,age;
   int direction,bucket;
   double intensity;
};
BookMicroHistorical gBookMicroHistory[BOOK_MICRO_HISTORY_CAP];
BookMicroWaveHistorical gBookMicroWaves[BOOK_MICRO_WAVE_CAP];
int gBookMicroHistoryNext=0,gBookMicroWaveNext=0;
long gBookMicroLastWindowTo=0,gBookMicroReferenceMSC=0;
double gBookMicroReference=0,gBookMicroTolerance=0;
long gBookMicroPriorReferenceMSC=0;
double gBookMicroPriorReference=0,gBookMicroPriorTolerance=0;
bool gBookMicroSuspended=false;
long gBookMicroCount=0,gBookMicroTotalUS=0,gBookMicroMaxUS=0,gBookMicroLastUS=0,gBookMicroDiscarded=0;
double gBookMicroDeterioration=0;
long gBookMicroTestStart=0,gBookMicroTestEnd=0,gBookMicroReactionStart=0;
double gBookMicroTestLevel=0,gBookMicroTestTolerance=0,gBookMicroTestExtreme=0,gBookMicroTestPOC=0;
int gBookMicroTestDirection=0,gBookMicroReactionState=0;
long gBookMicroTestReferenceMSC=0,gBookMicroTestLastWindow=0,gBookMicroTestRecognizedMSC=0;
BookMicroSnapshot gBookMicroLastSnapshot;

bool BookMicroEnabled()
{ return Inp_ResponseMode==RESPONSE_OBSERVAR && Inp_ObserveMicrostructure; }

void BookMicroInit()
{
   for(int i=0;i<BOOK_MICRO_HISTORY_CAP;i++) ZeroMemory(gBookMicroHistory[i]);
   for(int i=0;i<BOOK_MICRO_WAVE_CAP;i++) ZeroMemory(gBookMicroWaves[i]);
   ZeroMemory(gBookMicroLastSnapshot);
   gBookMicroHistoryNext=0; gBookMicroWaveNext=0; gBookMicroLastWindowTo=0;
   gBookMicroReferenceMSC=0; gBookMicroReference=0; gBookMicroTolerance=0;
   gBookMicroPriorReferenceMSC=0; gBookMicroPriorReference=0; gBookMicroPriorTolerance=0;
   gBookMicroSuspended=false; gBookMicroCount=0; gBookMicroTotalUS=0;
   gBookMicroMaxUS=0; gBookMicroLastUS=0; gBookMicroDiscarded=0;
   gBookMicroDeterioration=0; gBookMicroTestStart=0; gBookMicroTestEnd=0;
   gBookMicroReactionStart=0; gBookMicroReactionState=0; gBookMicroTestLastWindow=0; gBookMicroTestRecognizedMSC=0;
}
int BookMicroBucket(const long msc)
{
   MqlDateTime t; TimeToStruct((datetime)(msc/1000),t);
   return t.hour*2+t.min/30;
}
bool BookMicroSameDay(const long a,const long b)
{
   if(a<=0 || b<=0) return false;
   MqlDateTime x,y; TimeToStruct((datetime)(a/1000),x); TimeToStruct((datetime)(b/1000),y);
   return x.year==y.year && x.mon==y.mon && x.day==y.day;
}
void BookMicroFreezeWindow(BookMicroFlow &f)
{
   if(!BookMicroEnabled() || gBookMicroSuspended) { f.enabled=false; return; }
   // A test level was known strictly BEFORE this original POC window began.
   double level=gBookMicroReference,tolerance=gBookMicroTolerance;
   long reference=gBookMicroReferenceMSC;
   if(reference>=f.from_msc)
   { level=gBookMicroPriorReference; tolerance=gBookMicroPriorTolerance; reference=gBookMicroPriorReferenceMSC; }
   // During an independent reaction the test's frozen reference is retained.
   if(gBookMicroReactionState==1 && f.from_msc>gBookMicroTestEnd)
   { level=gBookMicroTestLevel; tolerance=gBookMicroTestTolerance; reference=gBookMicroTestReferenceMSC; }
   if(!BookMicroSameDay(reference,f.from_msc)) { level=0; reference=0; }
   BookMicroFlowReset(f,f.from_msc,f.to_msc,level,tolerance,reference);
}

void BookMicroRanks(const ResponseFlow &f,BookMicroSnapshot &o)
{
   double volumes[BOOK_MICRO_HISTORY_CAP],pressures[BOOK_MICRO_HISTORY_CAP];
   double progress[BOOK_MICRO_HISTORY_CAP],excursion[BOOK_MICRO_HISTORY_CAP];
   int count=0,conditional=0,bucket=BookMicroBucket(f.from_msc);
   long duration=f.to_msc-f.from_msc+1;
   for(int i=0;i<BOOK_MICRO_HISTORY_CAP;i++)
   {
      BookMicroHistorical h=gBookMicroHistory[i];
      if(!h.used || h.end_msc>=f.from_msc || h.duration!=duration || h.bucket!=bucket) continue;
      // Instance namespace is exact symbol; source is the same integer trade
      // tick volume consumed by ResponseFlowTick. Never pool real/tick bars.
      volumes[count]=h.volume; pressures[count]=h.pressure; count++;
      if(o.metrics.pressure_robust && h.direction==o.geometry_direction &&
         h.pressure>0 && h.pressure>=BookMicroAbs(o.metrics.delta)*0.5 &&
         h.pressure<=BookMicroAbs(o.metrics.delta)*2.0)
      { progress[conditional]=h.net_ticks; excursion[conditional]=h.max_ticks; conditional++; }
   }
   o.history_count=count; o.conditional_count=conditional;
   o.history_available=count>=BOOK_MICRO_MIN_HISTORY;
   o.conditional_available=conditional>=BOOK_MICRO_MIN_HISTORY;
   if(o.history_available)
   {
      o.p_volume=BookMicroRank(o.metrics.volume,volumes,count);
      o.p_pressure=BookMicroRank(BookMicroAbs(o.metrics.delta),pressures,count);
      o.activity_label=o.p_volume>=0.8?1:(o.p_volume<=0.2?-1:0);
      o.pressure_label=o.metrics.pressure_robust && o.metrics.known_coverage>=0.8 &&
         o.p_pressure>=0.8?1:0;
   }
   if(o.conditional_available)
   {
      o.p_y=BookMicroRank(o.metrics.net_ticks,progress,conditional);
      o.p_m=BookMicroRank(o.metrics.max_ticks,excursion,conditional);
      o.resistance=1.0-MathMax(o.p_y,o.p_m);
      // Experimental descriptive CUSUM, kappa=0.05. No decision consumer.
      gBookMicroDeterioration=MathMax(0.0,gBookMicroDeterioration+0.5-o.p_y-0.05);
      o.deterioration=gBookMicroDeterioration;
   }
   // No overlapping, future, duplicate or bad-quality windows enter history.
   if(f.from_msc>gBookMicroLastWindowTo && o.metrics.temporal_coverage>=0.5)
   {
      BookMicroHistorical h; ZeroMemory(h); h.used=true; h.end_msc=f.to_msc;
      h.duration=duration; h.bucket=bucket; h.direction=o.geometry_direction;
      h.volume=o.metrics.volume; h.pressure=BookMicroAbs(o.metrics.delta);
      h.net_ticks=o.metrics.net_ticks; h.max_ticks=o.metrics.max_ticks;
      // An untrusted/ambiguous direction may still support total activity,
      // but cannot become a conditional directional reference later.
      if(!o.metrics.pressure_robust || o.metrics.known_coverage<0.8) h.direction=0;
      gBookMicroHistory[gBookMicroHistoryNext]=h;
      gBookMicroHistoryNext=(gBookMicroHistoryNext+1)%BOOK_MICRO_HISTORY_CAP;
   }
}

void BookMicroERAndWave(const ResponseRecord &r,BookMicroSnapshot &o)
{
   if(!r.have_snapshot || Inp_SignalTF!=PERIOD_M1) return;
   const MatrixSnapshot s=r.snapshot;
   int need=11;
   if(s.wwok && s.wwWaveBars>0 && s.wwWaveBars<150) need=MathMax(need,s.wwWaveBars+1);
   double closes[]; ArraySetAsSeries(closes,true);
   int copied=CopyClose(Symbol(),PERIOD_M1,1,need,closes);
   if(copied<11 || iTime(Symbol(),PERIOD_M1,0)!=r.live_bar) return;
   double er_closes[11]; for(int i=0;i<11;i++) er_closes[i]=closes[i];
   o.er_m1_available=BookMicroER11(er_closes,11,o.er_m1_10,o.er_m1_direction);
   if(!s.wwok || !s.wwWaveAgeAvailable || s.wwWaveAgeSec<=0 ||
      !BookMicroFinite(s.wwAccumVolume) || s.wwAccumVolume<0) return;
   o.wave_age_available=true;
   o.wave_volume_per_second=s.wwAccumVolume/(double)s.wwWaveAgeSec;
   double vpp=0;
   if(ResponseVolumePerPoint(s.wwAccumVolume,s.wwDistancePts,r.tick_size,vpp))
      o.wave_volume_per_point=vpp;
   if(s.wwWaveBars>0 && s.wwWaveBars<150 && copied>=s.wwWaveBars+1)
   {
      double path=0;
      for(int i=0;i<s.wwWaveBars;i++) path+=BookMicroAbs(closes[i]-closes[i+1]);
      if(BookMicroFinite(path) && r.tick_size>0)
      { o.wave_path_available=true; o.wave_path_ticks=path/r.tick_size; }
   }
   long wave_start=(long)r.live_bar*1000-s.wwWaveAgeSec*1000;
   double comparable[BOOK_MICRO_WAVE_CAP],age_error[BOOK_MICRO_WAVE_CAP];
   long distinct_wave[BOOK_MICRO_WAVE_CAP]; int count=0;
   int bucket=BookMicroBucket((long)r.live_bar*1000);
   for(int i=0;i<BOOK_MICRO_WAVE_CAP;i++)
   {
      BookMicroWaveHistorical h=gBookMicroWaves[i];
      if(!h.used || h.end_msc>=(long)r.live_bar*1000 || h.wave_start==wave_start ||
         h.real_volume!=r.wave_real || h.direction!=s.waveDir || h.bucket!=bucket ||
         BookMicroAbs((double)h.age-(double)s.wwWaveAgeSec)>MathMax(60.0,s.wwWaveAgeSec*0.2)) continue;
      // One nearest-age sample per distinct historical wave. A long wave's
      // many partial snapshots must not masquerade as independent waves.
      double error=BookMicroAbs((double)h.age-(double)s.wwWaveAgeSec);
      int slot=-1;
      for(int j=0;j<count;j++) if(distinct_wave[j]==h.wave_start) { slot=j; break; }
      if(slot<0)
      { distinct_wave[count]=h.wave_start; age_error[count]=error; comparable[count++]=h.intensity; }
      else if(error<age_error[slot])
      { age_error[slot]=error; comparable[slot]=h.intensity; }
   }
   o.wave_history_count=count;
   if(count>=BOOK_MICRO_MIN_HISTORY)
   {
      double average=0;
      for(int i=0;i<count;i++) average+=comparable[i]; average/=count;
      if(average>0)
      { o.wave_reference_available=true; o.wave_relative_intensity=o.wave_volume_per_second/average; }
   }
   BookMicroWaveHistorical h; ZeroMemory(h); h.used=true;
   h.real_volume=r.wave_real; h.wave_start=wave_start; h.end_msc=(long)r.live_bar*1000;
   h.age=s.wwWaveAgeSec; h.direction=s.waveDir; h.bucket=bucket; h.intensity=o.wave_volume_per_second;
   gBookMicroWaves[gBookMicroWaveNext]=h; gBookMicroWaveNext=(gBookMicroWaveNext+1)%BOOK_MICRO_WAVE_CAP;
}

void BookMicroTestReaction(const ResponseRecord &r,BookMicroSnapshot &o)
{
   const ResponseFlow f=r.now;
   // Reaction is evaluated only in a strictly later, independent window.
   bool active=gBookMicroReactionState==1 && f.from_msc>gBookMicroTestEnd;
   if(active)
   {
      o.test_start=gBookMicroTestStart; o.test_end=gBookMicroTestEnd;
      // Delayed callbacks cannot retrospectively turn already traded prices
      // into a reaction known after detection. Wait only in observation for a
      // complete original window whose start is after actual recognition.
      if(f.from_msc<=gBookMicroTestRecognizedMSC)
      {
         o.reaction_status=7; // WAIT_CAUSAL_FUTURE_WINDOW, no execution delay
         gBookMicroTestLastWindow=f.to_msc;
         return;
      }
      if(gBookMicroReactionStart==0) gBookMicroReactionStart=f.first_msc;
      o.reaction_start=gBookMicroReactionStart; o.reaction_status=1;
      bool same_level=o.flow.level_available && o.flow.level==gBookMicroTestLevel &&
         o.flow.reference_msc==gBookMicroTestReferenceMSC;
      if(!same_level || !BookMicroSameDay(f.from_msc,gBookMicroTestEnd) ||
         f.from_msc!=gBookMicroTestLastWindow+1)
      { o.reaction_status=5; gBookMicroReactionState=5; return; } // gap/unknown
      int reaction_dir=-gBookMicroTestDirection;
      BookMicroMetrics reaction;
      BookMicroCompute(o.flow,f.vb,f.vs,f.vu,f.complete,f.invalid,r.tick_size,
         reaction_dir,Inp_Obs_TrustAggressorFlags,reaction);
      o.reaction_recovery_ticks=reaction_dir*(f.last_price-gBookMicroTestExtreme)/r.tick_size;
      o.reaction_efficiency=reaction.efficiency;
      o.reaction_er_available=reaction.er_available;
      o.reaction_volume_ratio=reaction.acceptance_volume_ratio;
      o.reaction_time_ratio=reaction.acceptance_time_ratio;
      o.reaction_time_available=reaction.time_available;
      o.reaction_net_delta=reaction_dir*reaction.delta;
      if(r.snapshot.pocNow.ok)
      { o.reaction_poc_available=true; o.reaction_poc_migration=
         reaction_dir*(r.snapshot.pocNow.poc-gBookMicroTestPOC)/r.tick_size; }
      bool recovered=reaction_dir*(f.last_price-gBookMicroTestLevel)>gBookMicroTestTolerance;
      if(recovered && o.reaction_recovery_ticks>0) o.reaction_status=2; // initiated
      if(recovered && reaction.available && reaction.er_available && reaction.efficiency>=0.5 &&
         reaction.acceptance_volume_ratio>=0.6 && reaction.time_available &&
         reaction.acceptance_time_ratio>=0.6 && reaction.temporal_coverage>=0.5 &&
         r.snapshot.pocNow.ok && o.reaction_poc_migration>0)
      { o.reaction_status=3; gBookMicroReactionState=3; o.regime=5; }
      double continuation_volume_ratio=(gBookMicroTestDirection>0?o.flow.above_volume:o.flow.below_volume)/o.metrics.volume;
      bool invalidated=gBookMicroTestDirection*(f.last_price-gBookMicroTestLevel)>gBookMicroTestTolerance &&
         o.metrics.level_available && continuation_volume_ratio>=0.6 &&
         o.metrics.temporal_coverage>=0.5;
      if(invalidated) { o.reaction_status=4; gBookMicroReactionState=4; }
      // Objective horizon: three complete original windows, never execution delay.
      if(f.to_msc-gBookMicroTestEnd>=3*(f.to_msc-f.from_msc+1) && gBookMicroReactionState==1)
      { o.reaction_status=6; gBookMicroReactionState=6; }
      gBookMicroTestLastWindow=f.to_msc;
      return;
   }
   if(o.flow.level_available && o.flow.touch_msc>0)
   {
      o.test_start=o.flow.touch_msc; o.test_end=f.to_msc; o.test_status=1;
      if(o.flow.touch_msc!=o.flow.first_msc) o.test_status=3; // full-window screening only
      // Recognition at the end of a CLOSED window, not at a future extreme.
      // Full-window effort/path may be attributed to a structural test ONLY
      // when its first eligible trade already reached the frozen level. Later
      // touches remain screening diagnostics; pre-touch pressure is excluded
      // from candidacy instead of retroactively resegmenting historical ticks.
      bool candidate=o.flow.touch_msc==o.flow.first_msc &&
         o.metrics.pressure_robust && o.pressure_label==1 &&
         o.conditional_available && o.resistance>=0.8 &&
         o.metrics.temporal_coverage>=0.5 && o.metrics.acceptance_volume_ratio<0.6;
      if(candidate)
      {
         o.test_status=2; o.regime=3;
         gBookMicroTestStart=o.test_start; gBookMicroTestEnd=o.test_end;
         gBookMicroTestRecognizedMSC=MathMax(r.event_msc,f.to_msc+1);
         gBookMicroTestLevel=o.flow.level; gBookMicroTestTolerance=o.flow.tolerance;
         gBookMicroTestReferenceMSC=o.flow.reference_msc;
         gBookMicroTestDirection=o.geometry_direction;
         gBookMicroTestExtreme=o.geometry_direction>0?o.flow.high:o.flow.low;
         gBookMicroTestPOC=r.snapshot.pocNow.ok?r.snapshot.pocNow.poc:o.flow.level;
         gBookMicroReactionStart=0; gBookMicroReactionState=1;
         gBookMicroTestLastWindow=f.to_msc;
         o.reaction_start=0; o.reaction_status=1; // pending first traded reaction observation
      }
   }
}

void BookMicroCapture(ResponseRecord &r)
{
   if(!BookMicroEnabled()) return;
   if(gBookMicroSuspended)
   {
      gBookMicroDiscarded++; ZeroMemory(r.micro); r.micro.captured=true; r.micro.suspended=true;
      r.micro.observer_last_us=gBookMicroLastUS; r.micro.observer_count=gBookMicroCount;
      r.micro.observer_total_us=gBookMicroTotalUS; r.micro.observer_max_us=gBookMicroMaxUS;
      r.micro.observer_discarded=gBookMicroDiscarded; return;
   }
   ulong begin=GetMicrosecondCount();
   BookMicroSnapshot o; ZeroMemory(o); o.captured=true; o.matrix_available=r.have_snapshot;
   if(r.have_now)
   {
      ResponseFlow f=r.now; o.flow=f.micro;
      BookMicroMetrics preliminary;
      BookMicroCompute(o.flow,f.vb,f.vs,f.vu,f.complete,f.invalid,r.tick_size,0,
         Inp_Obs_TrustAggressorFlags,preliminary);
      o.geometry_direction=preliminary.pressure_direction;
      if(o.geometry_direction==0) o.geometry_direction=f.last_price>=f.first_price?1:-1;
      BookMicroCompute(o.flow,f.vb,f.vs,f.vu,f.complete,f.invalid,r.tick_size,
         o.geometry_direction,Inp_Obs_TrustAggressorFlags,o.metrics);
      bool fresh=f.to_msc>gBookMicroLastWindowTo;
      if(o.metrics.available && fresh)
      {
         BookMicroRanks(f,o);
         BookMicroERAndWave(r,o);
         if(r.snapshot.pocNow.ok && r.snapshot.pocPrev.ok)
         { o.poc_migration_available=true;
           o.poc_migration=o.geometry_direction*(r.snapshot.pocNow.poc-r.snapshot.pocPrev.poc)/r.tick_size; }
         // Experimental regime labels: insufficient, efficient, deterioration,
         // absorption, reaction initiated, observable reversal, equilibrium.
         if(o.er_m1_available && o.metrics.er_available && o.metrics.temporal_coverage>=0.5)
         {
            if(o.er_m1_10>=0.6 && o.metrics.efficiency>=0.6 &&
               o.metrics.level_available && o.metrics.acceptance_volume_ratio>=0.6 &&
               o.poc_migration>0 && o.metrics.net_ticks>0) o.regime=1;
            else if(o.conditional_available && o.deterioration>=1.0) o.regime=2;
            else if(o.er_m1_10<0.2 && o.metrics.efficiency<0.2 && o.flow.crossings>=2) o.regime=6;
         }
         BookMicroTestReaction(r,o);
         if(o.reaction_status==2) o.regime=4;
      }
      if(fresh)
      {
         gBookMicroLastWindowTo=f.to_msc;
         // Structural reference for FUTURE windows only. This POC never labels
         // the current historical test retrospectively.
         gBookMicroPriorReference=gBookMicroReference;
         gBookMicroPriorReferenceMSC=gBookMicroReferenceMSC;
         gBookMicroPriorTolerance=gBookMicroTolerance;
         if(r.have_snapshot && r.snapshot.pocNow.ok && r.snapshot.pocNow.poc>0 && o.metrics.available)
         { gBookMicroReference=r.snapshot.pocNow.poc;
           // Actual callback knowledge time, not historical source-bar end.
           gBookMicroReferenceMSC=MathMax(r.event_msc,f.to_msc+1);
           gBookMicroTolerance=r.tick_size; }
         else { gBookMicroReference=0; gBookMicroReferenceMSC=0; }
      }
   }
   if(r.have_snapshot)
   {
      MatrixSnapshot s=r.snapshot;
      o.sigma_reference=SigmaD1;
      o.original_abs_min=s.minDispl; o.original_abs_body=s.maxBody; o.original_cont_min=s.contMinDispl;
      o.original_abs_c1=s.c1; o.original_cont_c1=s.c1Cont;
      o.original_abs_poc_state=(int)s.pocState; o.original_cont_poc_state=(int)s.contPocState;
      BookMicroC1Parallel(s.windowsValid,SigmaD1,Inp_Obs_Min_Displ_Sigma,
         Inp_Obs_Max_Body_Sigma,Inp_Obs_Cont_Min_Displ_Sigma,s.priceMove,s.pocMove,
         s.candleBody,s.dir,s.dirCont,s.waveDir,s.c1_effort_ok,s.cont_effort_ok,
         s.cont_candle_dir_ok,Inp_POC_FollowRatio,o.c1);
      // Only compare snapshots already produced by original logic. No new
      // evaluation clock is consumed and no hypothetical order is asserted.
      if(armed.active && s.status==MSS_OK)
      {
         o.opposite_snapshot_available=true;
         o.opposite_candidate=armed.route=="ABS"?(s.contValid && s.dirCont==-armed.dir):
            (s.absValid && s.dir==-armed.dir);
      }
   }
   gBookMicroLastUS=(long)(GetMicrosecondCount()-begin);
   gBookMicroCount++; gBookMicroTotalUS+=gBookMicroLastUS;
   if(gBookMicroLastUS>gBookMicroMaxUS) gBookMicroMaxUS=gBookMicroLastUS;
   o.observer_last_us=gBookMicroLastUS; o.observer_count=gBookMicroCount;
   o.observer_total_us=gBookMicroTotalUS; o.observer_max_us=gBookMicroMaxUS;
   o.observer_discarded=gBookMicroDiscarded;
   if(Inp_Obs_WindowBudgetUS<=0 || gBookMicroLastUS>Inp_Obs_WindowBudgetUS)
   {
      gBookMicroSuspended=true;
      o.suspended=true;
      PrintFormat("[BOOK_OBSERVER][SUSPENDED_BUDGET] last_us=%I64d budget_us=%d; financial path unchanged",
         gBookMicroLastUS,Inp_Obs_WindowBudgetUS);
   }
   r.micro=o; gBookMicroLastSnapshot=o;
}

string BookMicroHeader()
{
   return "micro_schema;micro_state;micro_window_from_msc;micro_window_to_msc;geometry_direction;known_coverage;known_imbalance;delta_low;delta_high;delta_interval_excludes_zero;aggressor_flags_trusted;pressure_robust;small_delta_scale;net_progress_ticks;max_progress_ticks;total_path_ticks;efficiency_ratio;frozen_level;level_reference_msc;level_tolerance;acceptance_volume_ratio;acceptance_time_ratio;temporal_coverage;observed_adjacent_msc;consecutive_dwell_msc;crossing_count;max_excursion_ticks;return_depth_ticks;historical_count;conditional_count;p_activity;p_pressure;p_y;p_m;resistance_t;deterioration_experimental;activity_label;pressure_label;regime_experimental;test_start;test_end;test_status;reaction_start;reaction_status;reaction_recovery_ticks;reaction_er;reaction_volume_ratio;reaction_time_ratio;reaction_delta;reaction_poc_migration;er_m1_10;er_m1_direction;poc_migration_ticks;wave_volume_per_second;wave_path_ticks;wave_volume_per_point;wave_reference_count;wave_relative_intensity;wave_reference_status;sigma_c1_reference;original_abs_min_pts;original_abs_max_body_pts;original_cont_min_pts;sigma_abs_min_pts;sigma_abs_max_body_pts;sigma_cont_min_pts;original_abs_poc_state;sigma_abs_poc_state;original_cont_poc_state;sigma_cont_poc_state;original_abs_c1;sigma_abs_c1;original_cont_c1;sigma_cont_c1;c1_comparison_status;opposite_snapshot_available;opposite_candidate_not_order;micro_last_us;micro_count;micro_total_us;micro_max_us;micro_discarded";
}
string BookMicroNumber(const double value,const bool available)
{ return available && BookMicroFinite(value)?StringFormat("%.17g",value):""; }
void BookMicroCell(string &row,string value)
{
   StringReplace(value,"\"","\"\""); row+=";\""+value+"\"";
}
void BookMicroCells(string &row,const BookMicroSnapshot &o)
{
   bool a=o.captured && o.metrics.available,l=a && o.metrics.level_available;
   bool h=a && o.history_available,c=a && o.conditional_available;
   BookMicroCell(row,"1");
   BookMicroCell(row,!BookMicroEnabled()?"DISABLED":(!o.captured?"UNAVAILABLE":
      (o.suspended?"SUSPENDED_BUDGET":(o.metrics.available?"OBSERVATIONAL_ONLY":"INSUFFICIENT_DATA"))));
   BookMicroCell(row,a?(string)o.flow.from_msc:""); BookMicroCell(row,a?(string)o.flow.to_msc:"");
   BookMicroCell(row,a?(string)o.geometry_direction:"");
   BookMicroCell(row,BookMicroNumber(o.metrics.known_coverage,a));
   BookMicroCell(row,BookMicroNumber(o.metrics.known_imbalance,a && o.metrics.ratio_available));
   BookMicroCell(row,BookMicroNumber(o.metrics.delta_low,a)); BookMicroCell(row,BookMicroNumber(o.metrics.delta_high,a));
   BookMicroCell(row,a?(o.metrics.delta_interval_excludes_zero?"1":"0"):"");
   BookMicroCell(row,Inp_Obs_TrustAggressorFlags?"1":"0");
   BookMicroCell(row,a?(o.metrics.pressure_robust?"1":"0"):"");
   BookMicroCell(row,BookMicroNumber(o.metrics.small_delta_scale,a));
   BookMicroCell(row,BookMicroNumber(o.metrics.net_ticks,a)); BookMicroCell(row,BookMicroNumber(o.metrics.max_ticks,a));
   BookMicroCell(row,BookMicroNumber(o.metrics.total_path_ticks,a));
   BookMicroCell(row,BookMicroNumber(o.metrics.efficiency,a && o.metrics.er_available));
   BookMicroCell(row,BookMicroNumber(o.flow.level,l)); BookMicroCell(row,l?(string)o.flow.reference_msc:"");
   BookMicroCell(row,BookMicroNumber(o.flow.tolerance,l));
   BookMicroCell(row,BookMicroNumber(o.metrics.acceptance_volume_ratio,l));
   BookMicroCell(row,BookMicroNumber(o.metrics.acceptance_time_ratio,l && o.metrics.time_available));
   BookMicroCell(row,BookMicroNumber(o.metrics.temporal_coverage,a));
   BookMicroCell(row,a?(string)o.flow.observed_msc:"");
   BookMicroCell(row,l?(string)o.flow.max_consecutive_msc:""); BookMicroCell(row,l?(string)o.flow.crossings:"");
   BookMicroCell(row,BookMicroNumber(o.metrics.max_excursion_ticks,l)); BookMicroCell(row,BookMicroNumber(o.metrics.return_depth_ticks,l));
   BookMicroCell(row,o.captured?(string)o.history_count:""); BookMicroCell(row,o.captured?(string)o.conditional_count:"");
   BookMicroCell(row,BookMicroNumber(o.p_volume,h)); BookMicroCell(row,BookMicroNumber(o.p_pressure,h));
   BookMicroCell(row,BookMicroNumber(o.p_y,c)); BookMicroCell(row,BookMicroNumber(o.p_m,c));
   BookMicroCell(row,BookMicroNumber(o.resistance,c)); BookMicroCell(row,BookMicroNumber(o.deterioration,c));
   BookMicroCell(row,h?(string)o.activity_label:""); BookMicroCell(row,h?(string)o.pressure_label:"");
   BookMicroCell(row,o.captured?(string)o.regime:"");
   BookMicroCell(row,o.test_start>0?(string)o.test_start:""); BookMicroCell(row,o.test_end>0?(string)o.test_end:"");
   BookMicroCell(row,o.test_start>0?(string)o.test_status:"");
   BookMicroCell(row,o.reaction_start>0?(string)o.reaction_start:""); BookMicroCell(row,o.reaction_start>0?(string)o.reaction_status:"");
   bool reaction=o.reaction_start>0 && o.reaction_status>=2 && o.reaction_status<=4;
   BookMicroCell(row,BookMicroNumber(o.reaction_recovery_ticks,reaction)); BookMicroCell(row,BookMicroNumber(o.reaction_efficiency,reaction && o.reaction_er_available));
   BookMicroCell(row,BookMicroNumber(o.reaction_volume_ratio,reaction)); BookMicroCell(row,BookMicroNumber(o.reaction_time_ratio,reaction && o.reaction_time_available));
   BookMicroCell(row,BookMicroNumber(o.reaction_net_delta,reaction)); BookMicroCell(row,BookMicroNumber(o.reaction_poc_migration,reaction && o.reaction_poc_available));
   BookMicroCell(row,BookMicroNumber(o.er_m1_10,o.er_m1_available)); BookMicroCell(row,BookMicroNumber(o.er_m1_direction,o.er_m1_available));
   BookMicroCell(row,BookMicroNumber(o.poc_migration,a && o.poc_migration_available));
   BookMicroCell(row,BookMicroNumber(o.wave_volume_per_second,o.wave_age_available)); BookMicroCell(row,BookMicroNumber(o.wave_path_ticks,o.wave_path_available));
   BookMicroCell(row,BookMicroNumber(o.wave_volume_per_point,o.wave_age_available && o.wave_volume_per_point>0));
   BookMicroCell(row,o.wave_age_available?(string)o.wave_history_count:"");
   BookMicroCell(row,BookMicroNumber(o.wave_relative_intensity,o.wave_reference_available));
   BookMicroCell(row,o.wave_reference_available?"SAME_DIRECTION_AGE_SOURCE_TIME_BUCKET":"INSUFFICIENT_COMPARABLE_WAVES");
   BookMicroCell(row,BookMicroNumber(o.sigma_reference,o.captured && o.sigma_reference>0));
   BookMicroCell(row,BookMicroNumber(o.original_abs_min,o.matrix_available)); BookMicroCell(row,BookMicroNumber(o.original_abs_body,o.matrix_available));
   BookMicroCell(row,BookMicroNumber(o.original_cont_min,o.matrix_available));
   BookMicroCell(row,BookMicroNumber(o.c1.abs_min,o.c1.available)); BookMicroCell(row,BookMicroNumber(o.c1.abs_body,o.c1.available));
   BookMicroCell(row,BookMicroNumber(o.c1.cont_min,o.c1.available));
   BookMicroCell(row,o.matrix_available?(string)o.original_abs_poc_state:""); BookMicroCell(row,o.c1.available?(string)o.c1.abs_poc_state:"");
   BookMicroCell(row,o.matrix_available?(string)o.original_cont_poc_state:""); BookMicroCell(row,o.c1.available?(string)o.c1.cont_poc_state:"");
   BookMicroCell(row,o.matrix_available?(o.original_abs_c1?"1":"0"):""); BookMicroCell(row,o.c1.available?(o.c1.abs_c1?"1":"0"):"");
   BookMicroCell(row,o.matrix_available?(o.original_cont_c1?"1":"0"):""); BookMicroCell(row,o.c1.available?(o.c1.cont_c1?"1":"0"):"");
   BookMicroCell(row,!o.c1.available?"UNCONFIGURED_OR_INVALID":
      ((o.c1.abs_c1!=o.original_abs_c1 || o.c1.cont_c1!=o.original_cont_c1)?"DIFFERENT_NOT_MORE_RESTRICTIVE":"SAME_C1"));
   BookMicroCell(row,o.opposite_snapshot_available?"1":"0");
   BookMicroCell(row,o.opposite_snapshot_available?(o.opposite_candidate?"1":"0"):"");
   BookMicroCell(row,o.captured?(string)o.observer_last_us:""); BookMicroCell(row,o.captured?(string)o.observer_count:"");
   BookMicroCell(row,o.captured?(string)o.observer_total_us:""); BookMicroCell(row,o.captured?(string)o.observer_max_us:"");
   BookMicroCell(row,o.captured?(string)o.observer_discarded:"");
}
#endif
