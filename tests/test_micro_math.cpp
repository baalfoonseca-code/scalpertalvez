#include <cassert>
#include <chrono>
#include <iostream>
#include <limits>
#include "../Include/BookMicroMath.mqh"

static int checks=0;
static void check(bool x) { ++checks; assert(x); }
static bool close(double a,double b) { return std::fabs(a-b)<1e-10; }
static BookMicroMetrics compute(BookMicroFlow &f,double buy,double sell,double unknown,
                               int direction=-1,bool trust=true,bool complete=true,int invalid=0)
{
    BookMicroMetrics m;
    BookMicroCompute(f,buy,sell,unknown,complete,invalid,0.5,direction,trust,m);
    return m;
}
int main()
{
    BookMicroFlow f;
    BookMicroFlowReset(f,1000,5999,100.0,0.0,999);
    for(int i=0;i<5;i++) BookMicroFlowTick(f,100.0-0.5*i,20,1000+i*1000);
    auto m=compute(f,0,100,0);
    check(m.available && m.pressure_robust && m.pressure_direction==-1);
    check(close(m.net_ticks,4) && close(m.max_ticks,4));
    check(m.er_available && close(m.efficiency,1));
    check(close(m.total_path_ticks,4) && close(m.known_coverage,1));
    check(close(m.acceptance_volume_ratio,0.8));
    check(close(m.temporal_coverage,1));
    check(m.time_available && close(m.acceptance_time_ratio,0.75));
    std::cout << "PASS efficient sell aggression and lower-price acceptance\n";

    BookMicroFlowReset(f,1000,5999,100,0,999);
    for(int i=0;i<5;i++) BookMicroFlowTick(f,100,100,1000+i*1000);
    m=compute(f,0,500,0);
    check(m.pressure_robust && close(m.net_ticks,0) && close(m.max_ticks,0));
    check(!m.er_available && m.level_available && f.touch_msc==1000);
    std::cout << "PASS sell aggression with no price progress; ER unavailable\n";

    m=compute(f,500,500,0);
    check(close(m.delta,0) && !m.delta_interval_excludes_zero && !m.pressure_robust);
    check(m.ratio_available && close(m.known_imbalance,0));
    m=compute(f,0,0,1000);
    check(close(m.known_coverage,0) && !m.ratio_available && !m.pressure_robust);
    check(close(m.delta_low,-1000) && close(m.delta_high,1000));
    m=compute(f,501,500,0);
    check(close(m.small_delta_scale,1.0/1001.0));
    m=compute(f,0,500,0,-1,false);
    check(m.delta_interval_excludes_zero && !m.pressure_robust);
    m=compute(f,1,2,10);
    check(m.delta_low<=0 && m.delta_high>=0 && !m.delta_interval_excludes_zero);
    std::cout << "PASS bilateral flow, unknown delta, tiny delta and untrusted flags\n";

    BookMicroFlowReset(f,1000,5999,100,0,999);
    double rebound[]={100,99,98,99,101};
    for(int i=0;i<5;i++) BookMicroFlowTick(f,rebound[i],10,1000+i*1000);
    m=compute(f,0,50,0);
    check(close(m.net_ticks,-2) && close(m.max_ticks,4));
    check(close(m.total_path_ticks,10) && close(m.efficiency,0.2));
    check(close(m.return_depth_ticks,6));
    check(f.crossings==1 && f.touch_msc==1000);
    m=compute(f,50,0,0,1);
    check(close(m.acceptance_volume_ratio,0.2));
    check(close(m.acceptance_time_ratio,0));
    std::cout << "PASS fall and recovery, false breakout and recovered-side rejection\n";

    BookMicroFlowReset(f,1000,60999,100,0,999);
    BookMicroFlowTick(f,101,10,1000);
    BookMicroFlowTick(f,101,10,60000);
    m=compute(f,20,0,0,1);
    check(m.available && !m.time_available && f.observed_msc==0);
    check(close(m.temporal_coverage,2.0/60.0));
    check(!m.er_available);
    BookMicroFlowReset(f,1000,5999,100,0,999);
    m=compute(f,0,0,0);
    check(!m.available && !m.time_available);
    std::cout << "PASS silent market is uncovered; no-trade volume is not invented\n";

    BookMicroFlowReset(f,1000,5999,100,0,1000);
    check(!f.level_available); // reference not known strictly before window
    BookMicroFlowTick(f,101,10,2000);
    long count=f.count;
    BookMicroFlowTick(f,99,10,1500); // delayed/out of order
    BookMicroFlowTick(f,99,10,999); // outside requested window
    BookMicroFlowTick(f,std::numeric_limits<double>::quiet_NaN(),10,2500);
    check(f.count==count);
    m=compute(f,10,0,0,1,true,false);
    check(!m.available);
    m=compute(f,10,0,0,1,true,true,1);
    check(!m.available);
    m=compute(f,10,0,0,1);
    check(m.available && !m.level_available);
    std::cout << "PASS causal level, late data and incomplete windows\n";

    double closes[11]={110,109,108,107,106,105,104,103,102,101,100};
    double er=0,direction=0;
    check(BookMicroER11(closes,11,er,direction) && close(er,1) && close(direction,1));
    check(!BookMicroER11(closes,10,er,direction));
    for(double &v:closes) v=100;
    check(!BookMicroER11(closes,11,er,direction));
    double sample[4]={1,2,2,4};
    check(close(BookMicroRank(2,sample,4),0.5));
    check(BookMicroRank(2,sample,0)==-1);
    std::cout << "PASS exactly eleven closed M1 prices and rank tie semantics\n";

    BookMicroC1 original_threshold,larger_threshold,unconfigured;
    BookMicroC1Parallel(true,100,0.6,0.6,0.5,80,50,20,-1,1,1,true,true,true,0.5,original_threshold);
    check(original_threshold.available && original_threshold.extension && !original_threshold.abs_c1);
    BookMicroC1Parallel(true,100,1.0,0.6,0.5,80,50,20,-1,1,1,true,true,true,0.5,larger_threshold);
    check(larger_threshold.available && larger_threshold.stall && larger_threshold.abs_c1);
    BookMicroC1Parallel(true,100,0,0,0,80,50,20,-1,1,1,true,true,true,0.5,unconfigured);
    check(!unconfigured.available);
    BookMicroC1Parallel(true,std::numeric_limits<double>::infinity(),1,1,1,80,50,20,-1,1,1,true,true,true,0.5,unconfigured);
    check(!unconfigured.available);
    std::cout << "PASS C1 extension-to-stall is not monotonically restrictive; unconfigured sigma stays NA\n";

    // Exhaustively exercise finite market geometry. The expected formula below
    // is transcribed from existing ComputeMatrixSnapshot, independently of the
    // new helper's implementation. Equal thresholds must reproduce its C1s.
    for(int move=-200;move<=200;move+=10)
    for(int poc=-200;poc<=200;poc+=20)
    for(int body=0;body<=100;body+=20)
    for(int absdir=-1;absdir<=1;absdir+=2)
    for(int wavedir=-1;wavedir<=1;wavedir+=2)
    {
        BookMicroC1 a;
        BookMicroC1Parallel(true,100,0.6,0.6,0.5,move,poc,body,absdir,-absdir,wavedir,true,true,true,0.5,a);
        bool follows=poc*move>0 && std::abs(poc)>=std::abs(move)*0.5;
        bool displaced=std::abs(move)>=60;
        int md=displaced?(move>0?1:-1):0;
        bool abs_expected=(displaced && !follows) || (!displaced && body<=60) ||
            (displaced && follows && md==absdir);
        bool cont_expected=std::abs(move)>=50 && follows && (move>0?1:-1)==-absdir && wavedir==-absdir;
        check(a.abs_c1==abs_expected && a.cont_c1==cont_expected);
    }
    std::cout << "PASS C1 threshold-equivalence lattice (20,664 controlled snapshots)\n";

    const int ticks=1000000;
    auto start=std::chrono::steady_clock::now();
    double sum=0;
    for(int i=0;i<ticks/100;i++)
    {
        BookMicroFlowReset(f,1000,100999,100,0.5,999);
        for(int j=0;j<100;j++) BookMicroFlowTick(f,100+(j%7)*0.5,1,1000+j*1000);
        sum+=compute(f,40,60,0).total_path_ticks;
    }
    double us=std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now()-start).count();
    check(sum>0);
    std::cout << "PASS " << checks << " assertions; native arithmetic benchmark ticks=" << ticks
              << " total_us=" << us << " mean_us_per_tick=" << us/ticks
              << " sizeof_flow=" << sizeof(BookMicroFlow) << " sizeof_snapshot=" << sizeof(BookMicroSnapshot)
              << " (C++ arithmetic only; not MT5 OnTick latency)\n";
}
