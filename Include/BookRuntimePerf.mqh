#ifndef BOOK_RUNTIME_PERF_V1
#define BOOK_RUNTIME_PERF_V1
// Timings are this process' elapsed microseconds; they are not exchange latency.
PerfStat gBookTickPerf,gBookTimerPerf,gBookPOCPerf;
ulong gBookPerfNextMS=0;
bool BookPerfEnabled()
{ return Inp_EnableArmedDiagnostics || Inp_ResponseMode==RESPONSE_OBSERVAR; }
void BookPerfTick(const ulong began)
{ if(BookPerfEnabled()) RecordPerf(gBookTickPerf,(double)(GetMicrosecondCount()-began)); }
void BookPerfTimer(const ulong began)
{
   if(!BookPerfEnabled()) return;
   RecordPerf(gBookTimerPerf,(double)(GetMicrosecondCount()-began));
   ulong now=GetTickCount64();
   if(now<gBookPerfNextMS) return;
   gBookPerfNextMS=now+60000;
   PrintFormat("[BOOK_PERF] tick_count=%I64d tick_mean_us=%.3f tick_max_us=%.3f timer_count=%I64d timer_mean_us=%.3f timer_max_us=%.3f poc_count=%I64d poc_mean_us=%.3f poc_max_us=%.3f memory_mb=%I64d; local elapsed time, native workload validation required",
      gBookTickPerf.count,gBookTickPerf.count>0?gBookTickPerf.sumUs/gBookTickPerf.count:0,gBookTickPerf.maxUs,
      gBookTimerPerf.count,gBookTimerPerf.count>0?gBookTimerPerf.sumUs/gBookTimerPerf.count:0,gBookTimerPerf.maxUs,
      gBookPOCPerf.count,gBookPOCPerf.count>0?gBookPOCPerf.sumUs/gBookPOCPerf.count:0,gBookPOCPerf.maxUs,
      MQLInfoInteger(MQL_MEMORY_USED));
}
bool BookMeasuredPOC(ulong from_msc,ulong to_msc,POCResult &result)
{
   if(!BookPerfEnabled()) return ComputePOCWithTie(from_msc,to_msc,result);
   ulong began=GetMicrosecondCount();
   bool ok=ComputePOCWithTie(from_msc,to_msc,result);
   RecordPerf(gBookPOCPerf,(double)(GetMicrosecondCount()-began));
   return ok;
}
#endif
