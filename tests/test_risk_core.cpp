#define BOOK_RISK_HOST
#include "../Include/BookRiskCore.mqh"
#include <iostream>
#include <limits>
#include <cstdlib>

static int checked=0;
void check(bool pass,const char* message) {
   ++checked;
   if(!pass) { std::cerr << "FAIL " << message << '\n'; std::exit(1); }
}
void near(double actual,double expected,const char* message) {
   check(std::fabs(actual-expected)<1e-8,message);
}
int main() {
   struct Asset { double price,tick,cap; } assets[]={{130000,5,150},{5500,0.5,5}};
   for(const auto& a:assets) for(int dir:{-1,1}) {
      for(double factor:{0.5,1.0,2.0}) {
         double sl,raw,distance; bool capped;
         check(BRSigmaStop(dir,a.price,a.cap*factor,1,a.cap,a.tick,sl,raw,distance,capped),"valid sigma stop");
         near(distance,std::min(a.cap*factor,a.cap),"below/exact/above cap distance");
         near(sl,a.price-dir*distance,"stop direction");
         check(capped==(factor>1),"cap-active telemetry");
         near(sl/a.tick,std::round(sl/a.tick),"absolute tick grid");
         check(distance<=a.cap,"never exceed cap");
      }
      double sl,raw,distance; bool capped;
      check(BRSigmaStop(dir,a.price,a.cap*0.933,1,a.cap,a.tick,sl,raw,distance,capped),"off-grid distance accepted inward");
      check(distance<=raw && distance<=a.cap,"off-grid normalization never widens");
      check(!BRSigmaStop(dir,a.price,a.tick*0.4,1,a.cap,a.tick,sl,raw,distance,capped),"sub-tick stop rejected");
      double lock1,lock2;
      check(BRLockPrice(dir,a.price,a.cap,1,a.tick,lock1),"lock1 valid");
      check(BRLockPrice(dir,a.price,a.cap,2,a.tick,lock2),"lock2 valid");
      check(BRImproves(dir,lock2,lock1,a.tick),"lock2 improves lock1");
      check(!BRImproves(dir,lock1,lock2,a.tick),"never widen existing protector");
      check(!BRImproves(dir,lock2,lock2,a.tick),"no repeat identical modification");
      // Entry slippage changes the effective immutable R; moved live SL never
      // supplies a replacement risk reference to this pure price function.
      const double confirmedEntry=a.price+dir*a.tick;
      const double provenInitialSL=a.price-dir*a.cap;
      const double initialR=std::fabs(confirmedEntry-provenInitialSL);
      double afterSlip;
      check(BRLockPrice(dir,confirmedEntry,initialR,1,a.tick,afterSlip),"confirmed fill lock");
      near(afterSlip,confirmedEntry+dir*initialR,"fill R derived from proven initial stop");
      check(initialR>a.cap,"adverse slippage can exceed requested cap without SL change");
   }
   double sl,raw,dist; bool capped;
   const double nan=std::numeric_limits<double>::quiet_NaN(),inf=std::numeric_limits<double>::infinity();
   for(double sigma:{0.0,-1.0,nan,inf})
      check(!BRSigmaStop(1,5500,sigma,1,5,.5,sl,raw,dist,capped),"invalid sigma has no fallback");
   check(!BRSigmaStop(0,5500,5,1,5,.5,sl,raw,dist,capped),"invalid side");
   check(!BRSigmaStop(1,5500,5,-1,5,.5,sl,raw,dist,capped),"invalid multiplier");
   check(!BRSigmaStop(1,5500,5,1,0,.5,sl,raw,dist,capped),"invalid cap");
   check(!BRSigmaStop(1,5500,5,1,5,0,sl,raw,dist,capped),"invalid tick");
   check(!BRSigmaStop(1,5500,1e308,1e308,5,.5,sl,raw,dist,capped),"overflow sigma product");
   check(BRLadderValid(1,2,1,3,2),"baseline lock ladder");
   check(!BRLadderValid(0,2,1,3,2),"zero BE invalid");
   check(!BRLadderValid(3,2,1,3,2),"active BE after first lock invalid");
   check(!BRLadderValid(1,2,2,3,2),"protection must be below trigger");
   check(!BRLadderValid(1,3,1,2,1.5),"triggers must increase");
   check(!BRLadderValid(1,2,1.5,3,1),"protection must increase");
   check(!BRLadderValid(1,2,1,3,nan),"nonfinite ladder rejected");
   check(BRHighestLock(1.99,2,3)==0,"below locks");
   check(BRHighestLock(2,2,3)==1,"at first lock");
   check(BRHighestLock(3,2,3)==2,"at second lock");
   check(BRHighestLock(8,2,3)==2,"jump selects highest rung");
   check(BRHighestLock(nan,2,3)==0,"nonfinite progress unavailable");
   for(int dir:{-1,1}) {
      double bid=1000,ask=1001,quote=(dir==1?bid:ask);
      double targetSL=quote-dir*5,targetTP=quote+dir*20,liveSL=quote-dir*10,liveTP=targetTP;
      check(BRBrokerDistances(dir,bid,ask,1,5,0,targetSL,targetTP,liveSL,liveTP),"stops exact distance allowed");
      check(!BRBrokerDistances(dir,bid,ask,1,6,0,targetSL,targetTP,liveSL,liveTP),"stops min violated");
      check(!BRBrokerDistances(dir,bid,ask,1,0,5,targetSL,targetTP,liveSL,liveTP),"freeze exact boundary blocks");
      check(BRBrokerDistances(dir,bid,ask,1,0,4,targetSL,targetTP,liveSL,liveTP),"outside freeze allowed");
      check(!BRBrokerDistances(dir,bid,ask,1,0,5,targetSL,targetTP,quote-dir*4,liveTP),"old SL frozen blocks");
      check(!BRBrokerDistances(dir,bid,ask,1,0,5,targetSL,targetTP,liveSL,quote+dir*4),"old TP frozen blocks");
      check(!BRBrokerDistances(dir,bid,ask,1,0,0,quote,targetTP,liveSL,liveTP),"SL on quote rejected");
      check(!BRBrokerDistances(dir,bid,ask,1,0,0,targetSL,quote,liveSL,liveTP),"TP on quote rejected");
   }
   check(!BRBrokerDistances(1,1001,1000,1,0,0,990,1010,980,1010),"crossed quotes rejected");
   check(!BRBrokerDistances(1,1000,1001,1,-1,0,990,1010,980,1010),"negative broker level rejected");
   for(int stage=BR_WAIT_FILL;stage<=BR_CORRUPT;stage++) {
      const bool expected=(stage==BR_IDLE || stage==BR_CONFIRMED || stage==BR_REJECTED);
      check(BRMayDispatch(stage)==expected,"only definitely resolved state dispatches");
      if(stage==BR_PENDING || stage==BR_UNCERTAIN || stage==BR_ACK || stage==BR_CORRUPT)
         check(BRPending(stage),"uncertain pending state stays blocked after restart");
      for(int bits=0;bits<8;bits++) {
         bool done=bits&1,slProof=bits&2,tpProof=bits&4;
         bool expectedProof=(stage==BR_ACK || stage==BR_PENDING || stage==BR_UNCERTAIN) && done && slProof && tpProof;
         check(BRServerProof(stage,done,slProof,tpProof)==expectedProof,"ack and both actual server levels required");
      }
   }
   // Deterministic broad grid: no rounded sigma SL can exceed its chosen cap.
   for(int dir:{-1,1}) for(int j=1;j<=500;j++) {
      const double cap=j*0.037;
      bool valid=BRSigmaStop(dir,5500.25,cap*1.21,1,cap,0.5,sl,raw,dist,capped);
      if(valid) {
         check(dist>0 && dist<=cap,"cap property on off-grid entry");
         near(sl/.5,std::round(sl/.5),"stop absolute grid property");
      }
   }
   std::cout << "risk core: " << checked << " assertions passed (host kernel only; no MT5/API execution)\n";
}
