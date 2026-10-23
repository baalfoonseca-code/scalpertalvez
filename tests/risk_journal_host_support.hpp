// Narrow ASCII/value shim for compiling production MQL serialization/validation
// functions. This supplies types and pure terminal conversions, no broker API.
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <type_traits>
#include <vector>
using uint=std::uint32_t;
using ushort=std::uint16_t;
using datetime=long;
struct MqlString : std::string {
   using std::string::string;
   MqlString()=default;
   MqlString(const std::string& s):std::string(s){}
   template<typename T, typename std::enable_if<std::is_arithmetic<T>::value,int>::type=0>
   MqlString(T value):std::string(std::to_string(value)){}
};
using string=MqlString;
inline string operator+(const string& a,const string& b) { return string(static_cast<const std::string&>(a)+static_cast<const std::string&>(b)); }
inline string operator+(const char* a,const string& b) { return string(a)+b; }
inline string operator+(const string& a,const char* b) { return a+string(b); }
inline int StringLen(const string& s) { return static_cast<int>(s.size()); }
inline ushort StringGetCharacter(const string& s,int i) { return static_cast<unsigned char>(s.at(i)); }
inline string StringSubstr(const string& s,int from,int len=-1) { return s.substr(from,len<0?std::string::npos:static_cast<std::size_t>(len)); }
inline string ShortToString(ushort code) { return string(1,static_cast<char>(code)); }
inline int StringSplit(const string& s,char delimiter,std::vector<string>& fields) {
   fields.clear(); std::size_t begin=0;
   for(std::size_t i=0;i<s.size();++i) if(s[i]==delimiter) { fields.push_back(s.substr(begin,i-begin)); begin=i+1; }
   fields.push_back(s.substr(begin)); return static_cast<int>(fields.size());
}
inline double StringToDouble(const string& s) { try { return std::stod(s); } catch(...) { return std::numeric_limits<double>::quiet_NaN(); } }
inline bool MathIsValidNumber(double x) { return std::isfinite(x); }
inline double MathAbs(double x) { return std::fabs(x); }
inline string DoubleToString(double x,int precision) { std::ostringstream o; o<<std::fixed<<std::setprecision(precision)<<x; return o.str(); }
template<typename... A> string StringFormat(const char* format,A... a) { char b[256]; std::snprintf(b,sizeof(b),format,a...); return b; }
template<typename... A> void Print(A...) {}
#define ZeroMemory(value) value={}
const int ACCOUNT_LOGIN=0;
long testAccount=1234567;
int gMagicCore=60002;
string testSymbol="WDOX26";
long AccountInfoInteger(int) { return testAccount; }
string Symbol() { return testSymbol; }
bool BEPriceEqual(double a,double b) { return std::isfinite(a) && std::isfinite(b) && std::fabs(a-b)<0.0000005; }
const uint TRADE_RETCODE_DONE=10009;
