#ifndef BOOK_RISK_CORE_MQH
#define BOOK_RISK_CORE_MQH
// The same numerical/state kernel is compiled by host tests and MQL5.
#ifdef BOOK_RISK_HOST
#include <cmath>
bool BRFinite(double x) { return std::isfinite(x); }
double BRFloor(double x) { return std::floor(x); }
double BRCeil(double x) { return std::ceil(x); }
double BRAbs(double x) { return std::fabs(x); }
#else
bool BRFinite(double x) { return MathIsValidNumber(x) && x!=EMPTY_VALUE; }
double BRFloor(double x) { return MathFloor(x); }
double BRCeil(double x) { return MathCeil(x); }
double BRAbs(double x) { return MathAbs(x); }
#endif
bool BRPositive(double x) { return BRFinite(x) && x>0.0; }
bool BRActiveLadderValid(bool enableBE,double be,double t1,double p1,double t2,double p2)
{
   return BRPositive(be) && BRPositive(t1) && BRPositive(p1) &&
      BRPositive(t2) && BRPositive(p2) && (!enableBE || be<t1) && t1<t2 &&
      p1<t1 && p2<t2 && p1<p2;
}
bool BRLadderValid(double be,double t1,double p1,double t2,double p2)
{ return BRActiveLadderValid(true,be,t1,p1,t2,p2); }
// Returns an absolute tick-grid stop INSIDE the capped distance. Never rounds
// an outward SL past the cap. A sub-tick/invalid/stops-level result is rejected.
bool BRSigmaStop(int dir,double entry,double sigma,double multiplier,double cap,
                 double tick,double &sl,double &raw,double &distance,bool &capped)
{
   sl=0; raw=0; distance=0; capped=false;
   if((dir!=1 && dir!=-1) || !BRPositive(entry) || !BRPositive(sigma) ||
      !BRPositive(multiplier) || !BRPositive(cap) || !BRPositive(tick)) return false;
   raw=sigma*multiplier;
   if(!BRPositive(raw)) return false;
   capped=raw>cap;
   double target=raw<cap?raw:cap;
   double unrounded=entry-dir*target;
   sl=(dir==1?BRCeil(unrounded/tick):BRFloor(unrounded/tick))*tick;
   distance=dir*(entry-sl);
   // No epsilon can authorize exceeding the cap. Input arithmetic may reject
   // a borderline price rather than silently increase financial risk.
   return BRPositive(sl) && BRPositive(distance) && distance<=target && distance<=cap;
}
int BRHighestLock(double progressR,double t1,double t2)
{
   if(!BRFinite(progressR)) return 0;
   if(progressR>=t2) return 2;
   if(progressR>=t1) return 1;
   return 0;
}
bool BRImproves(int dir,double candidate,double liveSL,double tick)
{
   return (dir==1 || dir==-1) && BRPositive(candidate) && BRPositive(liveSL) &&
      BRPositive(tick) && dir*(candidate-liveSL)>tick*0.000001;
}
bool BRBrokerDistances(int dir,double bid,double ask,double point,int stops,int freeze,
                       double targetSL,double targetTP,double liveSL,double liveTP)
{
   if((dir!=1 && dir!=-1) || !BRPositive(bid) || !BRPositive(ask) || ask<bid ||
      !BRPositive(point) || stops<0 || freeze<0 || !BRPositive(targetSL) ||
      !BRPositive(targetTP) || !BRPositive(liveSL) || !BRFinite(liveTP) || liveTP<0) return false;
   double quote=(dir==1?bid:ask);
   double dSL=dir*(quote-targetSL),dTP=dir*(targetTP-quote);
   if(dSL<=0 || dTP<=0 || dSL<stops*point || dTP<stops*point) return false;
   if(freeze>0 && (dSL<=freeze*point || dTP<=freeze*point ||
      dir*(quote-liveSL)<=freeze*point || (liveTP>0 && dir*(liveTP-quote)<=freeze*point))) return false;
   return true;
}
bool BRLockPrice(int dir,double entry,double initialR,double protectedR,double tick,double &price)
{
   price=0;
   if((dir!=1 && dir!=-1) || !BRPositive(entry) || !BRPositive(initialR) ||
      !BRPositive(protectedR) || !BRPositive(tick)) return false;
   double raw=entry+dir*protectedR*initialR;
   if(!BRPositive(raw)) return false;
   price=(dir==1?BRFloor(raw/tick):BRCeil(raw/tick))*tick;
   return BRPositive(price) && dir*(price-entry)>=0;
}
// States intentionally distinct from SCALPER_BE1. PENDING and UNCERTAIN never
// authorize retransmission; a definitive rejection or confirmed server proof
// is required before a subsequent request.
enum ENUM_BR_STAGE
{
   BR_WAIT_FILL=0, BR_IDLE=1, BR_PENDING=2, BR_ACK=3,
   BR_CONFIRMED=4, BR_REJECTED=5, BR_UNCERTAIN=6, BR_CLOSED=7, BR_CORRUPT=8
};
bool BRMayDispatch(int stage)
{ return stage==BR_IDLE || stage==BR_CONFIRMED || stage==BR_REJECTED; }
bool BRPending(int stage)
{ return stage==BR_PENDING || stage==BR_ACK || stage==BR_UNCERTAIN || stage==BR_CORRUPT; }
// Exact requested SL/TP corroboration is separate from request acceptance.
bool BRServerProof(int stage,bool done,bool slProof,bool tpProof)
{ return (stage==BR_ACK || stage==BR_PENDING || stage==BR_UNCERTAIN) && done && slProof && tpProof; }
#endif
