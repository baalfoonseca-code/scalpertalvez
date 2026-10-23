"""Compatibility checks against the immutable BOOK candidate.

The C++ fixture executes extracted MQL function bodies, with deterministic market
API substitutes. It is NOT a MetaEditor compile, MT5 backtest or broker test.
"""
from __future__ import annotations

import hashlib
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / "scalpertalvez"
UPDATED = ROOT / "scalpertalvez.mq5"
ORIGINAL_SHA256 = "c6e601429bea933ea937a3e985a2031a89b08bc42b199215dc5e8adfec2dd2a9"


def lexical_mask(text: str, strings: bool = False) -> str:
    """Mask comments, optionally literals, keeping offsets/newlines intact."""
    token = re.compile(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
    def repl(match: re.Match) -> str:
        value = match.group()
        if value.startswith(("//", "/*")) or strings:
            return "".join("\n" if c == "\n" else " " for c in value)
        return value
    return token.sub(repl, text)


def function(text: str, name: str) -> str:
    mask = lexical_mask(text, True)
    match = re.search(r"(?m)^[A-Za-z_][\w]*\s+" + re.escape(name) + r"\s*\(", mask)
    if not match:
        raise AssertionError(f"Missing function {name}")
    opening = mask.find("{", match.end())
    if ";" in mask[match.end():opening]:
        raise AssertionError(f"Declaration instead of body: {name}")
    level = 1
    end = opening + 1
    while level and end < len(mask):
        level += (mask[end] == "{") - (mask[end] == "}")
        end += 1
    if level:
        raise AssertionError(f"Unbalanced body {name}")
    return text[match.start():end]


def declaration(text: str, kind: str, name: str) -> str:
    mask = lexical_mask(text, True)
    match = re.search(r"\b" + kind + r"\s+" + re.escape(name) + r"\s*\{", mask)
    if not match:
        raise AssertionError(f"Missing {kind} {name}")
    end = mask.index("};", match.end()) + 2
    return text[match.start():end]


def remove_observer_calls(text: str) -> str:
    """Erase ONLY standalone void diagnostic calls, never conditions/results."""
    # This sole renamed call is a measured, one-call wrapper around the exact
    # original POC implementation. It does not change arguments or results.
    text = text.replace("BookMeasuredPOC(", "ComputePOCWithTie(")
    while True:
        mask = lexical_mask(text, True)
        match = re.search(r"\bBookDiag\w*\s*\(", mask)
        if not match:
            return text
        # Standalone hook must begin after a statement or open block/newline.
        prefix = mask[:match.start()].rstrip()
        if prefix and prefix[-1] not in ";{}":
            raise AssertionError("Diagnostic result used in an expression")
        depth, end = 1, match.end()
        while depth and end < len(mask):
            depth += (mask[end] == "(") - (mask[end] == ")")
            end += 1
        while end < len(mask) and mask[end].isspace():
            end += 1
        if end >= len(mask) or mask[end] != ";":
            raise AssertionError("Observer hook is not a void statement")
        text = text[:match.start()] + text[end + 1:]


def tokens(text: str) -> list[str]:
    return re.findall(r'"(?:\\.|[^"\\])*"|[A-Za-z_]\w*|\d+(?:\.\d*)?|[^\s]', lexical_mask(text))


def decision_tokens(text: str) -> list[str]:
    """Canonicalize diagnostic-only braces around a single return statement.

    A block containing exactly a return has the same scope/control flow as that
    return; no declarations, nested conditions or executable calls are removed.
    """
    text = remove_observer_calls(text)
    text = re.sub(r"\{\s*(return\b[^;{}]*;)\s*\}", r"\1", lexical_mask(text))
    return tokens(text)


def inputs(text: str) -> list[tuple[str, str, str]]:
    return [(m.group(1), m.group(2), " ".join(tokens(m.group(3))))
            for m in re.finditer(r"(?m)^input\s+(\w+)\s+(\w+)\s*=\s*([^;]+);", lexical_mask(text))]


def expanded_inputs(path: pathlib.Path, seen: set[pathlib.Path] | None = None) -> str:
    """Expand repository quoted includes in source order for input auditing.

    Standard-library <...> includes do not declare EA inputs and remain external.
    A repeated local guarded include is visited once, like the preprocessor.
    """
    seen = set() if seen is None else seen
    path = path.resolve()
    if path in seen:
        return ""
    seen.add(path)
    source = path.read_text(encoding="utf-8")
    def include(match):
        target = (path.parent / match.group(1).replace("\\", "/")).resolve()
        if not target.is_relative_to(ROOT):
            raise AssertionError(f"Include escapes checkout: {target}")
        if not target.exists():
            raise AssertionError(f"Missing include: {target}")
        return expanded_inputs(target, seen)
    return re.sub(r'(?m)^\s*#include\s+"([^"\n]+)"[^\n]*', include, source)


# These bodies must retain decisions and arithmetic. Standalone BookDiag* calls
# are the sole allowed instrumentation difference in this list.
PROTECTED = (
    "ComputeMacroContext", "ComputeMatrixSnapshot", "HasHardDirectionalContradiction",
    "ComputePOCWithTie", "RebuildWeisCache", "ComputeLiveWaveO1", "DOMGateClassify",
    "ComputeLotsForEntry", "ComputeTrigger", "NormEntrySL", "NormEntryTP",
    "CheckArmedMarketReady", "CheckArmedEntryReady", "RecomputeDailyRiskBlock",
    "CountTodayTrades", "RestoreDailyEconomicsFromHistory", "ResetAccountingDay",
    "ParseScalperComment", "CalcInitialRiskMoney", "IsAcceptedRetcode", "IsUncertainRetcode",
    "ProcessEOD", "HasExecutionInFlight", "PreparePendingExec", "ReconcilePendingExecution",
    "ReconcilePendingExitIntent", "TryFinalizeTrackedTrade", "IsTrackedVolumeCycleComplete",
    "OwnPositionSafe", "BEConfirm", "BEAcceptResult", "BEEntryComplete", "BEReferenceValid",
    "BEStopsValid", "RebuildTrackedHistory", "ReconstructOpenPosition", "RestoreDailyPersistence",
    "SyncOpenPositionFromRecord",
)


class CompatibilityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = ORIGINAL.read_text(encoding="utf-8")
        cls.new = UPDATED.read_text(encoding="utf-8")

    def test_original_reference_bytes_unchanged(self):
        self.assertEqual(hashlib.sha256(ORIGINAL.read_bytes()).hexdigest(), ORIGINAL_SHA256)

    def test_historical_71_input_types_order_names_and_defaults(self):
        old, new = inputs(self.old), inputs(expanded_inputs(UPDATED))
        self.assertEqual(len(old), 71)
        self.assertEqual(new[:71], old)
        self.assertEqual(len({name for _, name, _ in new}), len(new))

    def test_protected_strategy_function_bodies(self):
        for name in PROTECTED:
            with self.subTest(function=name):
                self.assertEqual(decision_tokens(function(self.new, name)),
                                 decision_tokens(function(self.old, name)), name)

    def test_observational_modules_cannot_dispatch_or_write_strategy_state(self):
        files = sorted((ROOT / "Include").glob("BookArmed*.mqh"))
        files += sorted((ROOT / "Include").glob("BookMicro*.mqh"))
        self.assertTrue(files, "Observation modules missing")
        forbidden_calls = ("OrderSend", "OrderSendAsync", "SendOrder", "EvaluateMatrix",
                           "ResetArmedSignal", "PreparePendingExec", "MarkRequestDispatchPossible",
                           "ResolveRequestJournal", "BeginExitIntent", "ProcessEOD", "ManageBreakEven")
        authoritative = ("armed", "gPendingExec", "gPendingExit", "gTradeRecords", "gMacro",
                         "gCachedMicroSnapshot", "gCachedMicroReady", "dailyRiskBlocked",
                         "ordersEnteredToday", "lastSignalBarTime", "lastContextBarTime",
                         "gLastMatrixEvalBar")
        for path in files:
            code = lexical_mask(path.read_text(encoding="utf-8"), strings=True)
            with self.subTest(module=path.name):
                self.assertNotRegex(code, r"\b(?:" + "|".join(forbidden_calls) + r")\s*\(")
                self.assertNotRegex(code, r"\btrade\s*\.\s*(?:PositionOpen|Buy|Sell|PositionModify|PositionClose|OrderDelete)\s*\(")
                for variable in authoritative:
                    self.assertNotRegex(code, r"\b" + variable + r"\b(?:\[[^\]]*\])?(?:\s*\.\s*\w+)*\s*(?:\+\+|--|[+*/-]?=(?!=))")

    def test_legacy_financial_journal_schemas(self):
        # Avoid changing the meaning/shape of existing BE, request, order and
        # accounting durable evidence. New management uses its own schema.
        for name in ("BEJournalRow", "BEParseRow", "RJRow", "RJParse",
                     "OrderObligationSnapshot", "ParseOrderObligationSnapshot",
                     "SaveTradeMetadata", "LoadTradeMetadata", "CsvTradeHeader", "CsvTradeRow"):
            with self.subTest(function=name):
                self.assertEqual(tokens(function(self.old, name)), tokens(function(self.new, name)))

    @unittest.skipUnless(shutil.which("g++"), "g++ unavailable; portable compatibility fixture unrun")
    def test_extracted_strategy_on_controlled_market_data(self):
        with tempfile.TemporaryDirectory(prefix="book-compat-") as temporary:
            runs = []
            for label, text in (("original", self.old), ("updated", self.new)):
                path = pathlib.Path(temporary) / (label + ".cpp")
                path.write_text(build_fixture(text), encoding="utf-8")
                executable = path.with_suffix("")
                compile_result = subprocess.run(["g++", "-std=c++17", "-O2", "-Wall", "-Wextra",
                                                 str(path), "-o", str(executable)],
                                                text=True, capture_output=True)
                self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
                run = subprocess.run([str(executable)], text=True, capture_output=True)
                self.assertEqual(run.returncode, 0, run.stderr)
                runs.append(run.stdout)
            self.assertEqual(runs[0], runs[1], "Actual original/new decision outputs differ")
            self.assertIn("matrix=12000", runs[0])
            self.assertIn("stage2=4096", runs[0])

    @unittest.skipUnless(shutil.which("g++"), "g++ unavailable; POC/Weis fixture unrun")
    def test_extracted_poc_and_weis_on_controlled_ticks_and_bars(self):
        with tempfile.TemporaryDirectory(prefix="book-poc-weis-") as temporary:
            runs = []
            for label, text in (("original", self.old), ("updated", self.new)):
                path = pathlib.Path(temporary) / (label + ".cpp")
                path.write_text(build_poc_fixture(text), encoding="utf-8")
                executable = path.with_suffix("")
                result = subprocess.run(["g++", "-std=c++17", "-O2", "-Wall", "-Wextra",
                                         str(path), "-o", str(executable)], text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                run = subprocess.run([str(executable)], text=True, capture_output=True)
                self.assertEqual(run.returncode, 0, run.stderr)
                runs.append(run.stdout)
            self.assertEqual(runs[0], runs[1])
            self.assertIn("poc=514 weis=128", runs[0])

    @unittest.skipUnless(shutil.which("g++"), "g++ unavailable; actual CSV parser fixture unrun")
    def test_actual_csv_parser_and_legacy_pid_overflow(self):
        module = ROOT / "Include" / "BookCsvDiagnostics.mqh"
        self.assertTrue(module.exists(), "CSV module missing")
        parser = function(module.read_text(encoding="utf-8"), "BookCsvParse")
        parser = parser.replace("string &fields[]", "std::vector<string> &fields")
        missing_policy = function(module.read_text(encoding="utf-8"), "BookCsvCanCreateMissing")
        code = CSV_PRELUDE + parser + missing_policy + function(self.new, "CsvParsePID") + CSV_MAIN
        with tempfile.TemporaryDirectory(prefix="book-csv-parser-") as temporary:
            path = pathlib.Path(temporary) / "parser.cpp"
            path.write_text(code, encoding="utf-8")
            executable = path.with_suffix("")
            result = subprocess.run(["g++", "-std=c++17", "-O2", "-Wall", "-Wextra",
                                     str(path), "-o", str(executable)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            run = subprocess.run([str(executable)], text=True, capture_output=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(run.stdout.strip(), "csv_parser=12 pid=9 memory_failure=1 missing_file_policy=8")


def build_fixture(source: str) -> str:
    definitions = [declaration(source, "enum", name) for name in
                   ("ENUM_MACRO_STATUS", "ENUM_MSS", "ENUM_APS", "ENUM_POC_STATE",
                    "ENUM_DOM_QUALITY", "ENUM_BOOK_CONFLUENCE")]
    definitions += [declaration(source, "struct", name) for name in
                    ("MacroContext", "POCResult", "MatrixSnapshot", "ArmedSignal", "DOMSnapshot")]
    names = ("DOMFinite", "DirStr", "NormPriceDigits", "RoundUpTick", "RoundDownTick",
             "NormEntrySL", "NormEntryTP", "ComputeTrigger", "ResetPOCResult", "ResetMatrixSnapshot",
             "ResetMacroContext", "ResetArmedSignal", "ComputeLiveWaveO1", "ComputeMacroContext",
             "ComputeMatrixSnapshot", "HasHardDirectionalContradiction", "DOMGateClassify",
             "CheckArmedMarketReady", "CheckArmedEntryReady")
    bodies = "\n".join(remove_observer_calls(function(source, name)) for name in names)
    return PRELUDE + "\n".join(definitions) + FIXTURE_GLOBALS + bodies + FIXTURE_MAIN


def build_poc_fixture(source: str) -> str:
    bodies = "\n".join(function(source, name) for name in (
        "ResetPOCResult", "ComputePOCWithTie", "RebuildWeisCache", "ComputeLiveWaveO1"))
    # Mechanical array declaration adapter only; numerical bodies are extracted
    # from the delivered source every run (no reimplemented POC/Weis model).
    for mql, cpp in (
        ("MqlTick t[];", "std::vector<MqlTick> t;"),
        ("double vol[];", "std::vector<double> vol;"),
        ("double close[]; long rvol[],tvol[];", "std::vector<double> close; std::vector<long> rvol,tvol;"),
        ("double waves[];", "std::vector<double> waves;"),
    ):
        bodies = bodies.replace(mql, cpp)
    return PRELUDE + "#include <vector>\n" + declaration(source, "struct", "POCResult") + POC_GLOBALS + bodies + POC_MAIN


PRELUDE = r'''
#include <algorithm>
#include <cmath>
#include <cfloat>
#include <cstdint>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <random>
#include <string>
using string=std::string;
using datetime=long;
const double EMPTY_VALUE=DBL_MAX;
double MathAbs(double x){return std::abs(x);}
double MathRound(double x){return std::round(x);}
double MathCeil(double x){return std::ceil(x);}
double MathFloor(double x){return std::floor(x);}
double MathMax(double a,double b){return std::max(a,b);}
bool MathIsValidNumber(double x){return std::isfinite(x);}
double NormalizeDouble(double x,int n){double m=std::pow(10,n);return std::round(x*m)/m;}
string Symbol(){return "CONTROLLED";}
enum { SYMBOL_DIGITS=1, TICK_FLAG_LAST=8,TICK_FLAG_VOLUME=16,TICK_FLAG_BUY=32,TICK_FLAG_SELL=64,
       RESPONSE_ORIGINAL=0,RESPONSE_OBSERVAR=1 };
struct MqlTick {long time=0,time_msc=0;double bid=0,ask=0,last=0;ulong volume=0;uint flags=0;double volume_real=0;};
struct MqlDateTime {int hour=0,min=0;};
int fixture_digits=2;
long SymbolInfoInteger(string,int){return fixture_digits;}
template<class... T> void PrintFormat(T...){ }
template<class... T> void Print(T...){ }
template<class... T> void WriteAuditRow(T...){ }
template<class... T> void ResponseLiveWave(T...){ }
template<class... T> void ResponseStageSample(T...){ }
void ResponseSnapshotBegin(){ }
'''

FIXTURE_GLOBALS = r'''
MacroContext gMacro;
ArmedSignal armed;
int Inp_ContextTF=3,Inp_SignalTF=1,Inp_ResponseMode=RESPONSE_ORIGINAL;
bool Inp_EnableMacroDirectionGate=true,Inp_EnableAbsorption=true,Inp_EnableContinuation=true;
bool Inp_RejectPOCTies=false,Inp_Cont_RequireCandleDirection=true,Inp_EnableLateDirectionBlock=false;
double Inp_VWAP_Inner_Pct=.60,Inp_VWAP_Outer_Pct=1.5,Inp_Rule_40_60=.4;
double Inp_POC_FollowRatio=.5,Inp_ABS_Effort=1.5,Inp_CONT_Effort=1.25;
int Inp_POC_WindowSec=60,Inp_ArmedTimeoutSec=90,Inp_StopEntryHHMM=1530,Inp_MaxTradesDay=10;
double VWAP_D1=1000,SigmaD1=100,H1=1300,L1=700,BandMultiplier=1,gVwapValue=1000;
bool VWAP_D1_Official=true,gVwapOk=true,wwValid=true,wwUseReal=true;
double gTickSize=5,gBreakoutMargin=5,gMaxOvershoot=25;
double gABS_MinDisplPts=60,gABS_MaxBodyPts=60,gCONT_MinDisplPts=50;
double gC2=700,gC3Min=125,gC3Max=400;
double wwEffortClosed=1.6,wwAccumClosed=100,wwWaveStartPrice=950;
int wwWaveDirClosed=1,wwCurrentWaveBars=3,wwDirClosed=1;
double wwAvgClosed=100,wwAvgIfFlip=50,wwCloseRef=1000;
bool gLiveDirectionTelemetryValid=false,gLateDirectionMismatch=false,gLateMismatchLogged=false,gSpreadHoldLogged=false;
int gLiveDirAbs=0,gLiveDirCont=0,ordersEnteredToday=0;
bool dailyRiskBlocked=false,fixture_inflight=false,fixture_position=false,fixture_spreadok=true;
bool fixture_tickok=true,fixture_vwapok=true;
double fixture_close=1000,fixture_open=995,fixture_macroclose=1000,fixture_liveclose=1010,fixture_livevol=100;
double fixture_livevwap=1000;
long fixture_clock=100000,fixture_server=100000;
int fixture_hour=10,fixture_min=0;
MqlTick fixture_tick;
POCResult fixture_poc[2];
int fixture_poc_calls=0;
double iClose(string,int tf,int shift){return shift==0?fixture_liveclose:(tf==3?fixture_macroclose:fixture_close);}
double iOpen(string,int,int){return fixture_open;}
long iTime(string,int tf,int shift){return fixture_clock-shift*tf*60;}
long iRealVolume(string,int,int){return (long)fixture_livevol;}
long iVolume(string,int,int){return (long)fixture_livevol;}
bool ComputePOCWithTie(ulong,ulong,POCResult &r){r=fixture_poc[fixture_poc_calls++%2];return r.ok;}
bool SymbolInfoTick(string,MqlTick &r){r=fixture_tick;return fixture_tickok;}
long TimeTradeServer(){return fixture_server;}
void TimeToStruct(long,MqlDateTime &r){r.hour=fixture_hour;r.min=fixture_min;}
bool GetLiveVwapSnapshot(ulong,double &r){r=fixture_livevwap;return fixture_vwapok;}
bool HasExecutionInFlight(){return fixture_inflight;}
bool HasOpenPosition(){return fixture_position;}
bool SpreadOk(){return fixture_spreadok;}
'''

FIXTURE_MAIN = r'''
uint64_t digest=1469598103934665603ULL;
void emit(double x){uint64_t bits=0;std::memcpy(&bits,&x,8);digest^=bits;digest*=1099511628211ULL;}
void emit_matrix(const MatrixSnapshot &s){
 emit(s.status);emit(s.dir);emit(s.dirCont);emit(s.posRel);emit(s.glass);
 emit(s.c1);emit(s.c2);emit(s.c3);emit(s.c4);emit(s.c5AbsOk);emit(s.c5ContOk);
 emit(s.c1Cont);emit(s.c2Cont);emit(s.c3Cont);emit(s.c4Cont);
 emit(s.absValid);emit(s.contValid);emit(s.turboAbs);emit(s.baseAbs);emit(s.turboCont);emit(s.baseCont);
 emit(s.pocState);emit(s.contPocState);emit(s.absDivergence);emit(s.absStallStrict);
 emit(s.absFollowingReaction);emit(s.absFollowingExtension);emit(s.cont_poc_ok);
 emit(s.macroAbsCompatible);emit(s.macroContCompatible);emit(s.priceMove);emit(s.pocMove);
}
void reset_stage(){
 ResetArmedSignal();armed.active=true;armed.dir=1;armed.regionHigh=1000;armed.regionLow=990;
 armed.armedAt=fixture_server-1;armed.breakoutEffortMin=1.5;armed.route="ABS";
 armed.mode="BASE";fixture_tickok=true;fixture_vwapok=true;fixture_spreadok=true;
 fixture_tick={};fixture_tick.time_msc=fixture_server*1000;fixture_tick.last=1005;
 fixture_tick.bid=1005;fixture_tick.ask=1010;fixture_tick.flags=TICK_FLAG_LAST;
 fixture_inflight=false;fixture_position=false;dailyRiskBlocked=false;ordersEnteredToday=0;
 wwValid=true;wwDirClosed=1;wwCloseRef=1000;wwAvgClosed=100;wwAvgIfFlip=50;
 wwAccumClosed=100;fixture_livevol=100;fixture_liveclose=1010;fixture_livevwap=1000;
 Inp_EnableLateDirectionBlock=false;Inp_ResponseMode=RESPONSE_ORIGINAL;
 fixture_hour=10;fixture_min=0;gSpreadHoldLogged=false;gLateMismatchLogged=false;
}
int main(){
 std::mt19937 random(1125);
 int abs_seen=0,cont_seen=0,conflicts=0,base=0,turbo=0;
 for(int k=0;k<12000;k++){
  bool dollar=(k%2)!=0;
  gTickSize=dollar?.5:5;gBreakoutMargin=gTickSize;
  SigmaD1=dollar?10:200;gVwapValue=dollar?5000:130000;VWAP_D1=gVwapValue;
  H1=gVwapValue+SigmaD1*3;L1=gVwapValue-SigmaD1*3;
  gABS_MinDisplPts=dollar?2:60;gABS_MaxBodyPts=dollar?2:60;gCONT_MinDisplPts=dollar?1.5:50;
  gC2=dollar?25:700;gC3Min=dollar?5:125;gC3Max=dollar?15:400;
  fixture_close=gVwapValue+((int)(random()%500)-250)*gTickSize;
  fixture_open=fixture_close+((int)(random()%30)-15)*gTickSize;
  fixture_macroclose=gVwapValue+((int)(random()%500)-250)*gTickSize;
  fixture_poc[0]={};fixture_poc[1]={};fixture_poc_calls=0;
  fixture_poc[0].ok=fixture_poc[1].ok=(random()%30)!=0;
  fixture_poc[1].lastValidPrice=gVwapValue;
  fixture_poc[0].lastValidPrice=gVwapValue+((int)(random()%70)-35)*gTickSize;
  fixture_poc[1].poc=gVwapValue;
  fixture_poc[0].poc=gVwapValue+((int)(random()%70)-35)*gTickSize;
  fixture_poc[0].hasTie=(random()%3)==0;
  Inp_RejectPOCTies=(k%5)==0;Inp_Cont_RequireCandleDirection=(k%3)!=0;
  Inp_EnableMacroDirectionGate=(k%2)==0;
  Inp_EnableAbsorption=(k%13)!=0;Inp_EnableContinuation=(k%11)!=0;
  Inp_ResponseMode=k%2;
  wwValid=k%17!=0;wwEffortClosed=(random()%350)/100.0;wwWaveDirClosed=(random()%2)?1:-1;
  wwWaveStartPrice=gVwapValue;wwAccumClosed=100+random()%1000;
  gVwapOk=true;VWAP_D1_Official=true;
  ComputeMacroContext();
  if(k%97==0) VWAP_D1_Official=false;
  if(k%101==0) SigmaD1=0;
  MatrixSnapshot s{};ComputeMatrixSnapshot(s);emit_matrix(s);
  emit(HasHardDirectionalContradiction(s,1));emit(HasHardDirectionalContradiction(s,-1));
  abs_seen+=s.absValid;cont_seen+=s.contValid;conflicts+=s.absValid&&s.contValid;
  base+=s.baseAbs+s.baseCont;turbo+=s.turboAbs+s.turboCont;
 }
 if(abs_seen==0||cont_seen==0||base==0||turbo==0){std::cerr<<"Insufficient matrix case coverage";return 1;}
 // Strict boundary checks for real five-distinct-level DOM snapshots.
 int dom_cases=0;
 for(int dir:{-1,1})for(int depth:{4,5,6})for(double bid:{45.,55.,100.,0.})for(double threshold:{54.,55.,60.,100.}){
  DOMSnapshot d{};d.bookValid=true;d.quality=DOM_QUALITY_OK;d.bidLevels=depth;d.askLevels=depth;
  d.bidVolume5=bid;d.askVolume5=100-bid;double bp=0,ap=0;
  auto state=DOMGateClassify(d,dir,threshold,bp,ap);emit(state);emit(bp);emit(ap);dom_cases++;
  if((depth<5||threshold<55||bid==0||bid==100)&&state!=BOOK_UNAVAILABLE) return 2;
  if(depth>=5&&threshold==55&&bid==55&&dir==1&&state!=BOOK_CONFIRM_BUY) return 3;
 }
 // Original Stage2 boundaries: timeout/session precedence, data, breakout,
 // overshoot, live direction/effort, glass, spread and operational guards.
 gTickSize=5;gBreakoutMargin=5;gMaxOvershoot=25;SigmaD1=100;BandMultiplier=1;
 int waits=0,ready=0,ended=0;
 for(int k=0;k<4096;k++){
  reset_stage();
  armed.dir=(k%2)?1:-1;armed.route=(k%4<2)?"ABS":"CONT";
  int dir=armed.dir;double trigger=ComputeTrigger(dir,armed.regionHigh,armed.regionLow);
  fixture_tick.last=trigger+dir*((int)(random()%10)-3)*5;
  fixture_tick.bid=fixture_tick.last-2.5;fixture_tick.ask=fixture_tick.last+2.5;
  fixture_liveclose=1000+dir*10;wwDirClosed=dir;wwAccumClosed=random()%250;
  if(k%19==0) armed.armedAt=fixture_server-Inp_ArmedTimeoutSec;
  if(k%23==0) fixture_hour=16;
  if(k%29==0) fixture_tick.flags=0;
  if(k%31==0) fixture_tickok=false;
  if(k%37==0) wwValid=false;
  if(k%41==0) fixture_liveclose=1000-dir*10;
  if(k%43==0) fixture_vwapok=false;
  if(k%47==0) fixture_livevwap=2000;
  if(k%13==0) fixture_spreadok=false;
  if(k%53==0) fixture_inflight=true;
  if(k%59==0) fixture_position=true;
  if(k%61==0) dailyRiskBlocked=true;
  if(k%67==0) ordersEnteredToday=Inp_MaxTradesDay;
  if(k%71==0) Inp_EnableLateDirectionBlock=true;
  Inp_ResponseMode=k%2;
  double effort=0,tr=0,last=0;MqlTick tick{};
  auto result=CheckArmedEntryReady(effort,tr,last,tick);
  emit(result);emit(armed.active);emit(effort);emit(tr);emit(last);
  waits+=result==APS_STILL_ARMED;ready+=result==APS_ENTRY_READY;
  ended+=result==APS_ENDED_FAIL_CLOSED||result==APS_ENDED_REEVAL_ALLOWED;
  if(k%19==0&&result!=APS_ENDED_REEVAL_ALLOWED){std::cerr<<"Timeout precedence broken";return 4;}
 }
 if(waits==0||ready==0||ended==0){std::cerr<<"Insufficient Stage2 coverage";return 5;}
 for(double tick:{.5,5.})for(int dir:{-1,1})for(double price:{995.1,1000.,1002.49,1005.1}){
  gTickSize=tick;gBreakoutMargin=tick;emit(NormEntrySL(dir,price));emit(NormEntryTP(dir,price));
  emit(ComputeTrigger(dir,price+10,price-10));
 }
 std::cout<<"matrix=12000 abs="<<abs_seen<<" cont="<<cont_seen<<" conflicts="<<conflicts
          <<" base="<<base<<" turbo="<<turbo<<" dom="<<dom_cases<<" stage2=4096 ready="<<ready
          <<" wait="<<waits<<" ended="<<ended<<" digest="<<std::hex<<digest<<"\n";
}
'''


POC_GLOBALS = r'''
double fixture_ticksize=5;
enum {SYMBOL_TRADE_TICK_SIZE=10,SYMBOL_POINT=11};
double SymbolInfoDouble(string,int){return fixture_ticksize;}
double MathMin(double a,double b){return std::min(a,b);}
template<class T> int ArrayResize(std::vector<T>& a,int n){a.resize(n);return n;}
template<class T> void ArrayInitialize(std::vector<T>& a,double v){std::fill(a.begin(),a.end(),v);}
template<class T> void ArraySetAsSeries(std::vector<T>&,bool){ }
int Inp_ResponseMode=RESPONSE_ORIGINAL,Inp_SignalTF=1;
template<class... T> void ResponseWindowBegin(T...){ }
template<class... T> void ResponseWindowTick(T...){ }
template<class... T> void ResponseWindowFinish(T...){ }
std::vector<MqlTick> fixture_ticks;
std::vector<double> fixture_closes;
std::vector<long> fixture_real,fixture_tickvol;
bool fixture_real_available=true;
int CopyTradeTicksStrict(ulong from,ulong to,std::vector<MqlTick> &ticks){
 ticks.clear();for(auto &t:fixture_ticks)if((ulong)t.time_msc>=from&&(ulong)t.time_msc<=to)ticks.push_back(t);
 return (int)ticks.size();
}
int CopyClose(string,int,int,int,std::vector<double>& a){a=fixture_closes;return (int)a.size();}
int CopyRealVolume(string,int,int,int,std::vector<long>& a){a=fixture_real;return fixture_real_available?(int)a.size():-1;}
int CopyTickVolume(string,int,int,int,std::vector<long>& a){a=fixture_tickvol;return (int)a.size();}
bool wwValid=false,wwUseReal=false;
int wwDirClosed=0,wwWaveDirClosed=0,wwCurrentWaveBars=0;
double wwAccumClosed=0,wwAvgClosed=0,wwAvgIfFlip=0,wwCloseRef=0,wwEffortClosed=0,wwWaveStartPrice=0;
long iRealVolume(string,int,int i){return fixture_real.at(i);}
long iVolume(string,int,int i){return fixture_tickvol.at(i);}
double iClose(string,int,int i){return fixture_closes.at(i);}
'''

POC_MAIN = r'''
uint64_t digest=1469598103934665603ULL;
void emit(double x){uint64_t bits=0;std::memcpy(&bits,&x,8);digest^=bits;digest*=1099511628211ULL;}
void tick(double price,ulong volume,int flags,long msc){
 MqlTick t{};t.last=price;t.volume=volume;t.flags=flags;t.time_msc=msc;t.volume_real=(double)volume;
 fixture_ticks.push_back(t);
}
int main(){
 POCResult r{};
 // Exactly equal volumes must retain original ascending-price canonical POC.
 tick(1000,10,TICK_FLAG_BUY,1000);tick(1005,10,TICK_FLAG_SELL,1100);
 if(!ComputePOCWithTie(1000,1200,r)||!r.hasTie||r.poc!=1000||r.top2Price!=1005||r.lastValidPrice!=1005)return 1;
 fixture_ticks.clear();
 if(ComputePOCWithTie(1000,1200,r)||r.ok)return 2;
 std::mt19937 random(1125);
 for(int k=0;k<512;k++){
  fixture_ticksize=(k%2)?.5:5.;fixture_ticks.clear();Inp_ResponseMode=k%2;
  for(int j=0;j<50;j++){
   double price=1000+(random()%20)*fixture_ticksize;
   ulong volume=random()%15;
   int flags=(j%3==0)?TICK_FLAG_BUY:((j%3==1)?TICK_FLAG_SELL:0);
   tick(price,volume,flags,1000+j*10);
  }
  bool ok=ComputePOCWithTie(1000,2000,r);emit(ok);emit(r.ok);emit(r.poc);emit(r.totalVolume);emit(r.hasTie);
  emit(r.top1Vol);emit(r.top2Vol);emit(r.buyVol);emit(r.sellVol);emit(r.unkVol);emit(r.levels);emit(r.lastValidPrice);
  if(!ok||r.totalVolume!=r.buyVol+r.sellVol+r.unkVol)return 3;
 }
 int fallback=0,live_flips=0;
 for(int k=0;k<128;k++){
  fixture_closes.clear();fixture_real.clear();fixture_tickvol.clear();
  fixture_real_available=(k%2)==0;
  for(int j=0;j<150;j++){
   fixture_closes.push_back(1000+(int)(random()%90));
   fixture_real.push_back(1+random()%100);fixture_tickvol.push_back(1+random()%50);
  }
  RebuildWeisCache();if(!wwValid||wwUseReal!=fixture_real_available)return 4;
  fallback+=!wwUseReal;
  emit(wwUseReal);emit(wwDirClosed);emit(wwAccumClosed);emit(wwAvgClosed);emit(wwAvgIfFlip);
  emit(wwCloseRef);emit(wwEffortClosed);emit(wwCurrentWaveBars);emit(wwWaveStartPrice);
  double effort=0,volume=0,average=0;int direction=0;
  ComputeLiveWaveO1(effort,volume,average,direction);
  live_flips+=direction!=wwDirClosed;
  emit(effort);emit(volume);emit(average);emit(direction);
  if(average>0&&std::abs(effort-volume/average)>1e-12)return 5;
 }
 if(fallback!=64||live_flips==0)return 6;
 std::cout<<"poc=514 weis=128 fallback="<<fallback<<" live_flips="<<live_flips<<" digest="<<std::hex<<digest<<"\n";
}
'''


CSV_PRELUDE = r'''
#include <iostream>
#include <string>
#include <vector>
using string=std::string;
using ushort=unsigned short;
using ulong=unsigned long;
bool allocation_fail=false;
int StringLen(const string &s){return (int)s.size();}
ushort StringGetCharacter(const string &s,int n){return (unsigned char)s.at(n);}
string StringSubstr(const string &s,int pos,int n){return s.substr(pos,n);}
int ArraySize(const std::vector<string>& a){return (int)a.size();}
int ArrayResize(std::vector<string>& a,int n){if(n>0&&allocation_fail)return -1;a.resize(n);return n;}
'''

CSV_MAIN = r'''
int main(){
 struct Case {string record;bool ok;int count;string reason;};
 std::vector<Case> cases={
  {"a,b,c",true,3,""}, {"a,b,",true,3,""}, {"",true,1,""},
  {"\"one,two\",three",true,2,""}, {"\"a\"\"b\",c",true,2,""},
  {"\"line1\r\nline2\",x",true,2,""}, {",,",true,3,""},
  {"a\"b,c",false,0,"QUOTE_IN_UNQUOTED_FIELD"},
  {"\"a\"x,b",false,0,"CHARACTER_AFTER_CLOSING_QUOTE"},
  {"\"a,b",false,0,"UNTERMINATED_QUOTED_FIELD"},
  {"a\nb,c",false,0,"UNQUOTED_LINE_BREAK"},
  {"\"a\"\"",false,0,"UNTERMINATED_QUOTED_FIELD"}
 };
 for(auto &c:cases){
  std::vector<string> fields;string reason;int offset=-1;
  bool ok=BookCsvParse(c.record,fields,reason,offset);
  if(ok!=c.ok||reason!=c.reason||(ok&&(int)fields.size()!=c.count)){
    std::cerr<<"CSV mismatch record="<<c.record<<" reason="<<reason;return 1;}
  if(c.record=="\"a\"\"b\",c"&&fields[0]!="a\"b")return 2;
  if(c.record=="\"line1\r\nline2\",x"&&fields[0]!="line1\r\nline2")return 3;
 }
 struct PID {string value;bool ok;};
 for(auto c:std::vector<PID>{{"1",true},{"18446744073709551615",true},{"18446744073709551616",false},
     {"999999999999999999999",false},{"0",false},{"",false},{"-1",false},{"1.0",false},{"001",true}}){
  ulong value=0;bool ok=CsvParsePID(c.value,value);if(ok!=c.ok){std::cerr<<"PID mismatch "<<c.value;return 4;}
 }
 allocation_fail=true;std::vector<string> fields;string reason;int offset=-1;
 if(BookCsvParse("a,b",fields,reason,offset)||reason!="MEMORY_FAILURE")return 5;
 for(int bits=0;bits<8;bits++){
  bool seen=(bits&1)!=0,absent=(bits&2)!=0,evidence=(bits&4)!=0;
  if(BookCsvCanCreateMissing(seen,absent,evidence)!=(bits==2))return 6;
 }
 std::cout<<"csv_parser=12 pid=9 memory_failure=1 missing_file_policy=8\n";
}
'''


if __name__ == "__main__":
    unittest.main(verbosity=2)
