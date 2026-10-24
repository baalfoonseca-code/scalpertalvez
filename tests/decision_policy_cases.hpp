// Deterministic PURE-POLICY evidence. Includes no broker/financial simulation.
// Caller includes BookDecisionInputs, BookMicroMath and BookDecisionCore first.
#ifndef BOOK_DECISION_POLICY_CASES_HPP
#define BOOK_DECISION_POLICY_CASES_HPP
BookDecisionConfig DecisionTestConfig(double tick_size=1.0)
{
   BookDecisionConfig c;BookDecisionConfigDefaults(c);
   c.source=DECISION_FLAGS_PROVIDER_ASSERTED;c.tick_size=tick_size;return c;
}
BookDecisionWindow DecisionTestWindow(const BookDecisionConfig &c,long from,
   int geometry_direction,int pressure_direction,double step_ticks,
   double volume_per_row=20.0,double anchor=100.0,double first_ticks=2.0)
{
   BookDecisionWindow w;
   BookDecisionWindowReset(w,from,from+c.window_sec*1000-1,anchor,c.tick_size,
      from-1,anchor,true,c.source,0,1);
   for(int i=0;i<6;i++)
   {
      long offset=i==5?c.window_sec*1000-1:i*c.window_sec*200;
      BookDecisionWindowTick(w,anchor+geometry_direction*(first_ticks+step_ticks*i)*c.tick_size,
         volume_per_row,from+offset,pressure_direction);
   }
   w.complete=true;return w;
}
void DecisionTestReferences(const BookDecisionConfig &c,BookDecisionHistory &h,
   int pressure_direction,int count=-1)
{
   BookDecisionHistoryReset(h);if(count<0)count=c.min_refs;
   for(int i=0;i<count;i++)
   {
      BookDecisionWindow sample=DecisionTestWindow(c,1000000+i*c.window_sec*1000,
         pressure_direction,pressure_direction,0.5);
      BookDecisionHistoryInsert(c,h,sample);
   }
}
BookDecisionEvidence DecisionTestABS(const BookDecisionConfig &c,int direction,bool with_reaction=true)
{
   BookDecisionHistory h;DecisionTestReferences(c,h,-direction);
   long from=1000000+(c.min_refs+1)*c.window_sec*1000;
   BookDecisionEvidence e{};e.have_test=true;e.have_current=true;
   e.original_subtype=DECISION_ABS_STALL_STRICT;
   // T: 240 integer-volume units of opposite aggression; zero ticks of net
   // progress AND excursion, versus prior120-unit references with2.5 ticks.
   e.test=DecisionTestWindow(c,from,-direction,-direction,0,40,100,0);
   BookDecisionCompare(c,h,e.test,-direction,e.test_ranks);
   e.current=e.test;e.now_msc=e.test.flow.to_msc;
   if(with_reaction)
   {
      e.have_reaction=true;
      long start=e.test.flow.to_msc+1;
      BookDecisionWindowReset(e.reaction,start,start+999,e.test.flow.level,c.tick_size,
         e.test.flow.to_msc,100,true,c.source,0,1);
      // R is already progressing:6ticks net,8ticks reclaimed,90% observed
      // duration,100% accepted volume/time. Its delta stays opposite to entry.
      for(int i=0;i<4;i++)
         BookDecisionWindowTick(e.reaction,100+direction*(2+2*i)*c.tick_size,20,start+i*300,-direction);
      e.reaction.complete=true;e.current=e.reaction;e.now_msc=e.reaction.flow.to_msc;
   }
   return e;
}
BookDecisionEvidence DecisionTestABS(int direction,bool with_reaction=true)
{ return DecisionTestABS(DecisionTestConfig(),direction,with_reaction); }
BookDecisionEvidence DecisionTestCONT(const BookDecisionConfig &c,int direction,bool reject=false)
{
   BookDecisionHistory h;DecisionTestReferences(c,h,direction);
   long from=1000000+(c.min_refs+1)*c.window_sec*1000;
   BookDecisionEvidence e{};e.have_current=true;e.have_forward=true;
   e.forward=DecisionTestWindow(c,from,direction,direction,2);
   BookDecisionCompare(c,h,e.forward,direction,e.forward_ranks);
   e.current=e.forward;e.current_ranks=e.forward_ranks;e.now_msc=e.current.flow.to_msc;
   if(reject)
   {
      e.current=DecisionTestWindow(c,e.forward.flow.to_msc+1,-direction,-direction,3.5,
         20,e.forward.flow.last,2);
      e.now_msc=e.current.flow.to_msc;
      BookDecisionRanksReset(e.current_ranks);
   }
   return e;
}
BookDecisionEvidence DecisionTestCONT(int direction,bool reject=false)
{ return DecisionTestCONT(DecisionTestConfig(),direction,reject); }
#endif
