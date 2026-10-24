// GENERATED: REMORA_BOOK_PRO_DECISORIA.mq5; integral modular expansion.
// EXPERIMENTAL: operational ABS/CONT validation; DECISION_APLICAR is the source default.
// Audited control: 815077efec40adf1897bcf64640756bb46c4c118; its monolithic file remains unchanged.
// Provider aggressor flags require an independent explicit configuration assumption.
// Only official MQL5 headers remain external; no custom repository include is required.
// Native MetaEditor compilation NOT verified; no production deployment or approval.

// BOOK1125_SURGERY_EXP1: branch experimental, fonte original preservada em scalpertalvez.
// Comando mestre comando.pdf lido integralmente. Compilacao nativa/MT5 pendentes.
// Novos modos financeiros opt-in; microestrutura exclusivamente observacional.
// FASE A OBSERVACIONAL - candidata experimental separada; NAO HOMOLOGADA.
// Fonte textual de controle: scalperbook; versao-base BOOK 1.125.
// Compilacao MetaEditor e replay nativo pendentes; ver docs/relatorio-tecnico.md.
// RC3 SCOPE FIX - based directly on RC3 commit 62b2b0c; NOT APPROVED.
// COMPILACAO NAO VERIFICADA - CANDIDATA NAO HOMOLOGADA.
// See experimental/docs/scope-fix-report.md for this correction and evidence.
// RC2 EXPERIMENTAL: PDF-derived reference; NOT COMPILED IN METAEDITOR.
// No production approval. Local freshness budgets remain uncalibrated.
// Remora_Scalper_Book_v1_124_DOM_Confluence.mq5
// EXPERIMENTAL. Reconstructed exclusively from the supplied BOOK 1.123 PDF.
// NOT COMPILED IN METAEDITOR. EMPIRICAL DOM VALIDATION PENDING.
// Source equivalence to an original .mq5 is not demonstrated.
// Provenance, transcription repairs and behavioral diff: experimental/docs/.
// The inherited historical header below belongs to the supplied PDF reference.

// RC12_SURGICAL_CANDIDATE_01: authorized RC1.2 PDF baseline; not production approved.
// RC1.2 derived directly and exclusively from RC1.1: /workspace/R-mora-/scalper 2.pdf.
// Canonical read-only reference: /workspace/R-mora-/5.0 Rêmora .pdf.
// PDF transcription repairs and operational changes have separate full diffs.
// CÓDIGO ESTATICAMENTE AUDITADO, MAS NÃO COMPILADO.
// REQUER COMPILAÇÃO NO METAEDITOR.
//+------------------------------------------------------------------+
//| Remora_Scalper_v1_123_DOM_Shadow.mq5                                   |
//| Descendente conceitual da Rêmora 2.44                              |
//| Arquitetura: M3 (Contexto) / M1 (Sinal) / Tick (Execução)            |
//|               |
//| CÓDIGO NÃO COMPILADO — REQUER COMPILAÇÃO NO METAEDITOR.
// |
//| Edge empírico não demonstrado. Não declarar rentabilidade.             |
//+------------------------------------------------------------------+
#property copyright "Remora Scalper Research"
#property version "1.125" // EXPERIMENTAL: PDF reconstruction + directional DOM confluence.
#property description "BOOK PRO experimental operational ABS/CONT validation; DECISION_APLICAR default; native compilation pending"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//=====================================================================
// ENUMS
//=====================================================================
enum SIZING_MODE
{
   SIZING_FIXED = 0, // Lote fixo
   SIZING_RISK_PERCENT = 1 // % risco por trade
};

enum ENUM_MACRO_STATUS
{
  MACRO_NOT_COMPUTED = 0,
  MACRO_OK,
  MACRO_VWAP_INVALID,
  MACRO_SIGMA_INVALID,
  MACRO_STRUCT_INVALID,
   MACRO_NO_TRIGGER
};

enum ENUM_MSS
{
  MSS_NOT_COMPUTED = 0,
  MSS_OK,
  MSS_MACRO_INVALID,
  MSS_VWAP_D1_INVALID,
  MSS_SIGMA_INVALID,
  MSS_STRUCT_INVALID,
  MSS_STOP_KAMIKAZE_CONT_ONLY,
   MSS_STOP_NO_C5_TRIGGER
};

enum ENUM_APS
{
   APS_STILL_ARMED = 0,
   APS_ENDED_REEVAL_ALLOWED,
   APS_ENDED_FAIL_CLOSED,
   APS_TRADE_OR_POSITION,
   APS_ENTRY_READY // Internal result of the unchanged Stage2 checks.
};

enum ENUM_POC_STATE
{
   POCS_INVALID = 0,
   POCS_NO_DISPLACEMENT,
   POCS_FOLLOWING,
   POCS_DIVERGENT
};

//=====================================================================
// CONSTANTS
//=====================================================================
const int D1_SESSION_START = 900;
const int D1_SESSION_END_INDEX = 1825;
const int D1_SESSION_END_DOLLAR = 1830;
const int D1_MIN_M1_BARS = 480;
const int MAX_SEARCH_DAYS = 40;
#define MAX_TRADE_RECORDS 200

//=====================================================================
// INPUTS
//=====================================================================
//--- Identidade
input int Inp_Magic_WIN = 60001;
input int Inp_Magic_WDO = 60002;
input string CSVFileName = "Scalper01_RC1"; // RC1 is also enforced in filenames
input datetime BacktestStart = D'2025.01.01';

//--- Timeframes
input ENUM_TIMEFRAMES Inp_ContextTF = PERIOD_M3; // TF Contexto (M3)
input ENUM_TIMEFRAMES Inp_SignalTF = PERIOD_M1; // TF Sinal (M1)

//--- Sessão
input int Inp_StartHHMM = 900; // Início entradas
input int Inp_StopEntryHHMM = 1530; // Fim entradas
input int Inp_EOD_CloseHHMM = 1750; // EOD (RESEARCH)
//--- Sizing
input SIZING_MODE Inp_SizingMode                   = SIZING_FIXED; // Modo sizing
input double Inp_FixedLots = 1.0; // Lote fixo
input double Inp_RiskPerTradePct = 0.15;       // % risco (RISK_PERCENT)
input double Inp_MaxLots = 10.0; // Lote máximo

//--- SL/TP fixos (pts) — hipóteses V0.1, não declarar ótimos
input double Inp_SL_Pts_WIN = 150.0; // SL WIN (pts)
input double Inp_TP_Pts_WIN = 300.0; // TP WIN (pts)
input double Inp_SL_Pts_WDO = 5.0; // SL WDO (pts)
input double Inp_TP_Pts_WDO = 12.5; // TP WDO (pts)

//--- Spread
input double Inp_SpreadMaxPts_WIN = 5.0; // Spread máx WIN (pts)
input double Inp_SpreadMaxPts_WDO = 0.5; // Spread máx WDO (pts)

//--- Gestão RESEARCH (padrão OFF — medir entrada/saída fixa)
input bool Inp_EnableBreakEven = true; // +1R real confirmado -> SL no preço de entrada

//--- Proteção diária RESEARCH (padrão OFF)
input bool Inp_EnableDailyRiskStop = false; // Stop perda diária
input double Inp_MaxDailyLossR = 3.0; // Máx perda (em R)
input bool Inp_EnableConsecutiveLossStop = false; // Stop perdas seguidas
input int Inp_MaxConsecutiveLosses = 3; // Nº perdas seguidas

//--- Limites (LIMITE, não meta)
input int Inp_MaxTradesDay = 10; // Máx trades/dia

//--- Cooldown (segundos desde fechamento confirmado)
input int Inp_CooldownSec = 0; // Cooldown geral (s)
input int Inp_LossCooldownSec = 0; // Cooldown após perda (s)

//--- Armed
input int Inp_ArmedTimeoutSec = 90; // Timeout armed (s)
//--- Região / Rompimento
input int Inp_Region_Candles = 2; // Candles região (M1 fechadas)
input double Inp_BreakoutMargin_WIN = 5.0; // Margem rompimento WIN (pts)
input double Inp_BreakoutMargin_WDO = 0.5; // Margem rompimento WDO (pts)
input double Inp_MaxOvershoot_WIN = 25.0; // Overshoot máx WIN (pts)
input double Inp_MaxOvershoot_WDO            = 1.0; // Overshoot máx WDO (pts)

//--- Weis Wave M1
input double Inp_ABS_Effort = 1.50; // WW esforço ABS (C1)
input double Inp_CONT_Effort = 1.25; // WW esforço CONT (C1)
input double Inp_ABS_BreakoutEffort = 1.50; // WW onda viva ABS (Stage2)
input double Inp_CONT_BreakoutEffort = 1.50; // WW onda viva CONT (Stage2)
//--- POC M1
input int Inp_POC_WindowSec = 60; // Janela POC (s) — baseline = M1
input double Inp_POC_FollowRatio = 0.50; // Razão POC segue preço
input bool Inp_RejectPOCTies = false; // Ablation only; baseline keeps canonical POC

//--- ABS thresholds (pts — hipóteses, não declarar ótimos)
input double Inp_ABS_MinPriceMovePts_WIN = 60.0; // ABS displ min WIN (pts)
input double Inp_ABS_MaxBodyPts_WIN                 = 60.0; // ABS corpo max WIN (pts)
input double Inp_ABS_MinPriceMovePts_WDO = 2.0; // ABS displ min WDO (pts)
input double Inp_ABS_MaxBodyPts_WDO                     = 2.0; // ABS corpo max WDO (pts)

//--- CONT thresholds (pts — hipóteses)
input double Inp_CONT_MinPriceMovePts_WIN = 50.0; // CONT displ min WIN (pts)
input double Inp_CONT_MinPriceMovePts_WDO = 1.5; // CONT displ min WDO (pts)
input bool Inp_Cont_RequireCandleDirection = true; // CONT: vela na direção

//--- Geometria VWAP (herdada da 2.44)
input double BandMultiplier = 1.0;
input double Inp_VWAP_Inner_Pct = 0.60;
input double Inp_VWAP_Outer_Pct = 1.50;

//--- C2/C3/C4 (herdados da 2.44 — hipóteses para scalp, não validados OOS)
input double Inp_Rule_40_60 = 0.40;
input double Inp_C2_WIN = 700.0;
input double Inp_C3_Min_WIN = 125.0;
input double Inp_C3_Max_WIN = 400.0;
input double Inp_C2_WDO = 25.0;
input double Inp_C3_Min_WDO = 5.0;
input double Inp_C3_Max_WDO = 15.0;

//--- Sigma histórico (ainda necessário para bandas/C2/C3/C4)
input int SigmaLookbackDays = 5;
input double Inp_SigmaFloor_WIN = 200.0;
input double Inp_SigmaFloor_WDO = 7.0;

//--- Execução
input int Inp_MaxDeviationPts_WIN = 10;
input int Inp_MaxDeviationPts_WDO = 2;
//--- Rotas habilitadas
input bool Inp_EnableMacroDirectionGate = true;
input bool Inp_EnableLateDirectionBlock = false;
input bool Inp_EnableAbsorption = true;
input bool Inp_EnableContinuation = true;

//--- Optional descriptive book telemetry; original 66 inputs above unchanged.
input bool Inp_DOM_Enable = false;
input string Inp_DOM_InstanceTag = "shadow";

// Experimental gate: the preceding 68 declarations are unchanged.
input bool Inp_DOM_TradeGateEnable = false;
input double Inp_DOM_MinDominancePct = 55.0;

// Phase A: observation only; OBSERVAR retains the original trading capability.
enum ENUM_RESPONSE_MODE { RESPONSE_ORIGINAL=0, RESPONSE_OBSERVAR=1 };
input ENUM_RESPONSE_MODE Inp_ResponseMode = RESPONSE_ORIGINAL;

// Observational additions: none can authorize, block, cancel or route an order.
input bool Inp_ObserveMicrostructure = true; // Effective only in RESPONSE_OBSERVAR
input bool Inp_Obs_TrustAggressorFlags = false; // Explicit feed-quality assumption; not a gate
input double Inp_Obs_Min_Displ_Sigma = 0.0; // ABS hypothetical M1 multiplier; 0=unconfigured
input double Inp_Obs_Max_Body_Sigma = 0.0; // ABS hypothetical M1 multiplier; 0=unconfigured
input double Inp_Obs_Cont_Min_Displ_Sigma = 0.0; // CONT hypothetical M1 multiplier; 0=unconfigured
input int Inp_Obs_WindowBudgetUS = 5000; // Suspend extension after an over-budget snapshot


// ORIGINAL_INCLUDE | #include "Include\BookRiskInputs.mqh"
// BEGIN_INCORPORATED Include/BookRiskInputs.mqh
#ifndef BOOK_RISK_INPUTS_MQH
#define BOOK_RISK_INPUTS_MQH
// Appended after all 71 historical declarations. Units: quoted asset points,
// never SYMBOL_POINT; R_INITIAL is confirmed entry minus proven original SL.
enum ENUM_BOOK_SL_MODE { SL_ORIGINAL_PONTOS=0, SL_SIGMA_COM_TETO=1 };
enum ENUM_BOOK_TP_MODE { TP_MODE_ORIGINAL=0, TP_MODE_BY_ROUTE_R=1 };
input ENUM_BOOK_SL_MODE Inp_SL_Mode = SL_ORIGINAL_PONTOS;
input double Inp_Mult_SL = 1.0;
input double Inp_Max_SL_Pts_WIN = 150.0;
input double Inp_Max_SL_Pts_WDO = 5.0;
input double BE_Trigger_R = 1.0;
input bool EnableProfitLocks = false;
input double Lock1_Trigger_R = 2.0;
input double Lock1_Protected_R = 1.0;
input double Lock2_Trigger_R = 3.0;
input double Lock2_Protected_R = 2.0;
input ENUM_BOOK_TP_MODE Inp_TP_Mode = TP_MODE_ORIGINAL;
// Experimental examples, inactive while TP_MODE_ORIGINAL is selected.
input double TP_BASE_R = 5.0;
input double TP_TURBO_R = 6.0;
#endif
// END_INCORPORATED Include/BookRiskInputs.mqh
// ORIGINAL_INCLUDE | #include "Include/BookArmedInputs.mqh"
// BEGIN_INCORPORATED Include/BookArmedInputs.mqh
#ifndef BOOK_ARMED_INPUTS_V1
#define BOOK_ARMED_INPUTS_V1
// Pure diagnostics: never used as an entry/exit/financial predicate.
input bool Inp_EnableArmedDiagnostics = true;
#endif
// END_INCORPORATED Include/BookArmedInputs.mqh
// New experimental controls are appended after all 91 historical inputs.
// ORIGINAL_INCLUDE | #include "Include/BookDecisionInputs.mqh"
// BEGIN_INCORPORATED Include/BookDecisionInputs.mqh
#ifndef BOOK_DECISION_INPUTS_MQH
#define BOOK_DECISION_INPUTS_MQH
// Appended AFTER the 91 preserved BOOK inputs. These are experimental policy
// settings, not a claim about a live chart preset or statistical calibration.
enum ENUM_BOOK_DECISION_MODE { DECISION_ORIGINAL=0, DECISION_APLICAR=1 };
enum ENUM_BOOK_DECISION_SOURCE
{
   DECISION_FLAGS_UNVERIFIED=0,
   DECISION_FLAGS_PROVIDER_ASSERTED=1
};
enum ENUM_BOOK_DECISION_RESULT
{
   DECISION_VALIDAR=0,
   DECISION_AGUARDAR=1,
   DECISION_VETAR_CANDIDATO=2,
   DECISION_INVALIDAR_ARMED=3,
   DECISION_DADOS_INSUFICIENTES=4
};
input ENUM_BOOK_DECISION_MODE Inp_DecisionMode = DECISION_APLICAR;
// An independent explicit assumption about TRADE tick BUY/SELL flags. Selecting
// ASSERTED does not prove provider accuracy; every batch still needs integrity.
input ENUM_BOOK_DECISION_SOURCE Inp_DecisionAggressorSource = DECISION_FLAGS_UNVERIFIED;
input int Inp_DecisionWindowSec = 5;
input int Inp_DecisionMinReferences = 16;
input double Inp_DecisionEffortQuantile = 0.80;
input double Inp_DecisionResultQuantile = 0.20;
input double Inp_DecisionMinCoverage = 0.80;
input double Inp_DecisionMinDirectionalShare = 0.20;
input double Inp_DecisionMinAcceptance = 0.60;
input double Inp_DecisionMinObservedCoverage = 0.50;
input double Inp_DecisionMinProgressTicks = 1.0;
input double Inp_DecisionComparableEffortFactor = 2.0;
#endif
// END_INCORPORATED Include/BookDecisionInputs.mqh

//=====================================================================
// STRUCTS
//=====================================================================
struct MacroContext
{
   ENUM_MACRO_STATUS status;
   datetime barTime;
   double closedPrice;
   double vwap;
   double SigmaD1; // value actually used by the closed M3 snapshot
   double distVWAP_D1;
   double posRel;
   bool glass;
   int macroAbsDir; // dir C5 ABS (M3)
   int macroContDir; // dir C5 CONT (M3)
};

struct POCResult
{
   bool ok;
   double poc;
   double totalVolume;
   double lastValidPrice;
   int tradeCount;
   int levels;
   bool hasTie;
   double top1Price, top1Vol;
   double top2Price, top2Vol;
   double dominance;
   double buyVol, sellVol, unkVol;
};
struct MatrixSnapshot
{
   ENUM_MSS status;
   // Bandas
   double vwapVig, upper, lower, bandRange;
   // Candle M1 fechada
   double price, open1, candleBody;
   double posRel;
   bool glass;
   // C5
   int dir, dirCont;
   bool c5AbsOk, c5ContOk;
   // Thresholds
   double distAbs;
   double minDispl, maxBody, contMinDispl;
   // C2/C3/C4
   bool c2, c3, c23, c4;
   bool c2Cont, c3Cont, c23Cont, c4Cont;
   double posRange;
   // POC
   POCResult pocNow, pocPrev;
      bool windowsValid;
      double priceMove, pocMove;
      bool displacementOk;
      int moveDir;
      ENUM_POC_STATE pocState;
      bool contDisplacementOk;
      int contMoveDir;
      ENUM_POC_STATE contPocState;
      // WW
      bool wwok;
      double effort;
      int waveDir;
      int wwWaveBars;
      long wwWaveAgeSec;
      bool wwWaveAgeAvailable;
      double wwAccumVolume, wwDistancePts;
      // C1 ABS sub
      bool c1_effort_ok, c1_body_ok, c1_displacement_ok;
      bool c1_movedir_ok, c1_wavedir_ok;
      // ABS contexts
      bool absDivergence, absStallStrict, absFollowingReaction, absFollowingExtension;
      bool absPocContextOk, c1;
      // C1 CONT sub
      bool cont_effort_ok, cont_displacement_ok, cont_poc_ok;
      bool cont_movedir_ok, cont_wavedir_ok, cont_candle_dir_ok;
      bool c1Cont;
      // Mode
       bool turboAbs, baseAbs, turboCont, baseCont;
     int scoreEff, scoreContEff;
     // Final validity
     bool      absValid, contValid;
     int candleDir;
     // MacroContext filter results (telemetria)
     bool      macroAbsCompatible, macroContCompatible;
};

struct ArmedSignal
{
  bool active;
  int dir;
  double regionHigh, regionLow;
  double activeSL_Pts, activeTP_Pts;
  datetime regionEndTime;
  string mode;
  double lots;
  string route;
  double breakoutEffortMin;
  datetime armedAt;
   bool sameSideGlassLogged;
   // Snapshot para auditoria
   double posRel, distD1, effort, vwapVig;
   int c1, c2, c3, c4, c5, scoreEff;
};

// RC1.2 execution and accounting state.
// RC1.2: exact order identity survives disappearance from OrdersTotal.
enum PendingOrderNature
{
   PENDING_ORDER_UNKNOWN=0,
   PENDING_ORDER_ENTRY,
   PENDING_ORDER_EXIT
};

struct UnresolvedOrderContext
{
  bool active, classificationPending;
  bool persistencePending;
  ulong orderTicket, positionID, positionByID;
  datetime firstSeen, setupTime, doneTime;
  PendingOrderNature nature;
  ENUM_ORDER_STATE lastState;
  long orderType, orderReason;
  double initialVolume, remainingVolume;
  string comment, route, mode;
  string persistenceSnapshot;
};
UnresolvedOrderContext gUnresolvedOrders[];
bool gMultipleOwnOrdersActive=false;
bool gOrderRegistryUnavailable=false;
ulong gOrderRegistryFallback[MAX_TRADE_RECORDS];
int gOrderRegistryFallbackCount=0;
bool gOrderRegistryOverflow=false;
bool gOrderObligationScanUnresolved=false;
bool gOrderObligationRestoring=false;
datetime gNextOrderReconcile=0;


// Separate BE evidence; no field below replaces the original SL/risk.
enum BE_STAGE
{
   BE_NONE=0, BE_TRIGGERED, BE_REQUEST_PENDING, BE_ACKNOWLEDGED,
   BE_CONFIRMED, BE_UNRESOLVED
};
struct BreakEvenState
{
   int stage, direction;
   ulong ticket;
   double entryPrice, initialSL, price, tp;
   long triggerMSC, confirmedMSC;
   uint requestID, retcode;
   bool durable, successLogged, exitLogged;
   datetime nextTry, lastFailureLog;
};

struct TradeRecord
{
  ulong positionID;
  int direction;
  string route, mode;
  bool quotaCounted;
  double requestPrice, breakoutPrice;
  bool requestPriceAvailable, breakoutPriceAvailable;
    ulong entryOrderTicket;
    double expectedEntryVolume;
    datetime entryTime;
    double entryPrice, weightedEntryPrice, totalVolumeIn, entrySlippage;
    double slPrice, tpPrice;
    datetime exitTime;
    long exitTimeMSC;
    ulong lastExitDealTicket;
    double exitPrice, weightedExitPrice, totalVolumeOut, volume;
    double grossProfit, commission, fee, swap, netProfit;
    string exitReason;
     double MAE, MFE;
     long holdSeconds;
     double initialRiskMoney, PnL_R;
     bool closed, maeMfePartialAfterRestart, volumeClosedComplete;
     bool finalizationWritten, dailyApplied;
     bool accountingResolved, riskValid, pnlRValid;
     bool initialStopsProven, economicMarkerPending;
     bool economicMarkerCleanupPending; // Maintenance only after fresh durable proof.
     int economicMarkerDeleteError;
     bool historyRefreshPending;
     // Rebuilt from authoritative deals; never ownership of the live residual.
     bool residualForeignDetected, ownCycleEconomicallyClosed;
     bool volumeOwnershipResolved, inoutCostsUnresolved;
      BreakEvenState be;
      bool breakEvenExit; // Derived only from all confirmed own exit components.
      bool breakEvenClassificationPending; // Do not publish a loss before BE proof resolves.
};

// Zero/default and legacy journals must always retain dispatch uncertainty.
enum ENUM_REQUEST_DISPATCH_PHASE
{
  REQUEST_MAY_HAVE_DISPATCHED=0,
  REQUEST_PREPARED=1
};

struct PendingExecContext
{
  bool active;
  ENUM_REQUEST_DISPATCH_PHASE dispatchPhase;
  int direction;
  string route, mode;
  double requestPrice, requestedLots, slPrice, tpPrice;
  datetime sentAt;
  ulong orderTicket, resultDeal;
  uint requestID;
  bool accepted, requestPriceAvailable;
  double breakoutPrice;
  bool breakoutPriceAvailable;
};

struct PendingExitIntent
{
  bool active;
  ENUM_REQUEST_DISPATCH_PHASE dispatchPhase;
  ulong positionID, positionTicket;
  string reason;
  datetime sentAt;
  ulong orderTicket, resultDeal;
  uint requestID;
  bool accepted, uncertain;
  MqlTradeRequest requestSnapshot;
};




struct OpenPositionInfo
{
  bool active;
  ulong positionID;
  int direction;
  double entryPrice;
  double MAE, MFE;
  datetime entryTime;
  string route, mode;
  double lots;
  double initialRiskMoney;
    int tradeRecordIdx;
};

struct PerfStat
{
   long count;
   double sumUs, maxUs;
};

//=====================================================================
// GLOBAL VARIABLES
//=====================================================================
CTrade trade;
CPositionInfo posInfo;

// Família e conta
bool gIsIndexFamily = false;
bool gIsDollarFamily = false;
bool gNetting = false;
double gTickSize = 1.0;
int gDayKey      = -1;

// Parâmetros resolvidos no OnInit (família-específicos)
int gMagicCore = 0;
double gC2 = 0, gC3Min = 0, gC3Max = 0;
int gMaxDeviationPts = 0;
double gSpreadMaxPts = 5.0;
double gBreakoutMargin = 5.0;
double gMaxOvershoot = 25.0;
double gSL_Pts = 150.0;
double gTP_Pts = 300.0;
double gABS_MinDisplPts = 60.0;
double gABS_MaxBodyPts = 60.0;
double gCONT_MinDisplPts= 50.0;

// D-1
double H1 = 0.0, L1 = 0.0, VWAP_D1 = 0.0, SigmaD1 = 0.0;
bool VWAP_D1_Official = false;
bool d1Ready = false;
datetime nextD1Retry = 0;

// VWAP vigente (incremental acumulador diário)
double vwapSumPV = 0.0, vwapSumVol = 0.0;
ulong vwapNextFromMsc = 0;
bool vwapReady = false;
int vwapDayKey = -1;
double gVwapValue = 0.0;
bool gVwapOk = false;
// Weis Wave cache M1
bool wwValid = false;
bool wwUseReal        = false;
int wwDirClosed = 0;
double wwAccumClosed = 0.0;
double wwAvgClosed          = 0.0;
double wwAvgIfFlip = 0.0;
double wwCloseRef        = 0.0;
double wwEffortClosed = 0.0;
int wwWaveDirClosed = 0;
int wwCurrentWaveBars= 0; // telemetria WW_WAVE_BARS
double wwWaveStartPrice = 0.0; // para WW_DISTANCE_PTS
// Temporal
datetime lastContextBarTime = 0; // M3
datetime lastSignalBarTime = 0; // M1
datetime gLastMatrixEvalBar = 0; // anti-duplo
datetime gLastReadOnlyMatrixBar = 0; // Diagnostic attempts never consume the entry clock.

// MacroContext (M3)
MacroContext gMacro;

// Armed
ArmedSignal armed;
// Open position tracker (MAE/MFE)
OpenPositionInfo gOpenPos;

// Trade records
TradeRecord gTradeRecords[];
int gTradeRecordCount = 0;

// Contadores diários
// Accounting globals. Existing daily counters and gTradeRecords remain.
PendingExecContext gPendingExec;
PendingExitIntent gPendingExit;
int requestsAcceptedToday = 0;
double dailyPnLR = 0.0;
bool gDailyPnLRValid = true;
bool gDailyEconomicsValid = true;
bool gQuotaHistoryValid = true;
bool gAccountingUnresolved = false;
enum DailyEconomicsRecoveryState
{
    DAILY_ECONOMICS_VALID=0,
    TEMPORARY_HISTORY_UNAVAILABLE,
    ECONOMIC_ALLOCATION_IMPOSSIBLE,
    DAILY_ECONOMICS_UNRESOLVED
};
DailyEconomicsRecoveryState gDailyEconomicsState=DAILY_ECONOMICS_VALID;
bool gLiveOwnershipUnresolved=false;
bool gAccountingCapacityUnresolved=false;
bool gDailyRiskLimitLatched=false;
bool gDailyHistoryRetryRequired=false;
datetime gLastAccountingRecoveryTime=0;
ulong gDeferredAccountingPIDs[];
bool gDeferredRegistryUnavailable=false;
ulong gDeferredFallback[MAX_TRADE_RECORDS];
int gDeferredFallbackCount=0;
bool gDeferredRegistryOverflow=false;
ulong gDeferredDeals[];
ulong gDeferredDealFallback[MAX_TRADE_RECORDS];
int gDeferredDealFallbackCount=0;
bool gDeferredDealOverflow=false;
bool gEconomicMarkerScanUnresolved=false;
bool gEMRMaintenanceNeeded=false;
string gEMRMaintenanceCursor="";
bool gIdentityLossUnresolved=false;
bool gIdentityLossPersistPending=false;
bool gRequestJournalUnresolved=false;
bool gRequestJournalWritePending=false;
bool gEntryJournalCleanupPending=false;
bool gExitJournalCleanupPending=false;
bool gEntryJournalInvalid=false, gExitJournalInvalid=false;
bool gEntryJournalWritePending=false, gExitJournalWritePending=false;
bool gRequestJournalRestoring=false;
datetime gNextRequestJournalRecovery=0;
// Independent guard: a history retry cannot erase an unclassified own order.
bool gPendingOrderClassificationUnresolved = false;
bool gNeedsAccountingSync = false;
datetime gLastPendingReconcileTime = 0;
ulong gConfirmedPositionsToday[];

int ordersEnteredToday = 0;
int consecutiveLosses = 0;
double dailyNetPnL = 0.0;
datetime lastCloseConfirmedTime = 0;
bool dailyRiskBlocked = false;
bool lastTradeWasLoss      = false;

// EOD
bool eodDone = false;
bool eodStuckLogged = false;
datetime eodNextTry = 0;

// Bandas cache
double UpperBand1 = 0.0, LowerBand1 = 0.0;
// CSV handles
int csvAuditHandle = INVALID_HANDLE;
int csvTradeHandle = INVALID_HANDLE;
int csvShadowHandle = INVALID_HANDLE;

// Performance telemetry (contagem de execução)
PerfStat perfMacro, perfMicro, perfStage2;
long gLastPerfLoggedMicroCount = 0;
int hardFlipsPerDay = 0, armedCancelHard = 0, oppositeRearmAfterHard = 0;
double gLastBreakoutPrice = 0.0;
bool gLateMismatchLogged = false, gSpreadHoldLogged = false;
MatrixSnapshot gCachedMicroSnapshot;
datetime gCachedMicroBar = 0;
bool gCachedMicroReady = false;

// Flush periódico (evitar por tick)
datetime gLastFlushTime = 0;

// Descriptive DOM cache. No trade, account, persistence, network or book API calls.
// Collection timestamps are local monotonic times; they are NOT exchange times.
#define DOM_RAW_RECORD_LIMIT 4096
enum ENUM_DOM_QUALITY
{
   DOM_QUALITY_NONE=0,
   DOM_QUALITY_OK=1,
   DOM_QUALITY_EMPTY=2,
   DOM_QUALITY_TOO_LARGE=3,
   DOM_QUALITY_INVALID=4,
   DOM_QUALITY_ONE_SIDED=5,
     DOM_QUALITY_CROSSED=6,
     DOM_QUALITY_SHALLOW=7,
     DOM_QUALITY_API_FAILURE=8,
     DOM_QUALITY_NO_SUBSCRIPTION=9,
     DOM_QUALITY_DISCONNECTED=10,
     DOM_QUALITY_SYMBOL_MISMATCH=11
};

struct DOMSnapshot
{
  ulong collectedMS;
  ulong sequence;
  ENUM_DOM_QUALITY quality;
   bool bookValid;
   bool i5Available;
   bool micropriceAvailable;
   int rawRecords;
   int bidLevels;
   int askLevels;
   int bidPriceRecords;
   int askPriceRecords;
   int marketBuyRecords;
   int marketSellRecords;
   int invalidRecords;
   int zeroVolumeRecords;
   int volumeFallbackRecords;
   // At most five distinct prices on each side, best price first.
   // Missing slots are unavailable; consult min(5, bidLevels/askLevels).
   double bidDepthPrice[5];
   double bidDepthVolume[5];
   double askDepthPrice[5];
   double askDepthVolume[5];
   double bestBid;
   double bestAsk;
   double spread;
   double bidVolume1;
   double askVolume1;
   double bidVolume5;
   double askVolume5;
   double marketBuyVolume;
   double marketSellVolume;
   double i5;
   double midpoint;
   double microprice;
   double micropriceMinusMid;
};

// Fixed workspaces: 131072 bytes of price/volume arrays, reused at 1 Hz.
// More than 4096 raw records is unavailable, never a truncated valid snapshot.
double gDOMBidPrices[DOM_RAW_RECORD_LIMIT];
double gDOMBidVolumes[DOM_RAW_RECORD_LIMIT];
double gDOMAskPrices[DOM_RAW_RECORD_LIMIT];
double gDOMAskVolumes[DOM_RAW_RECORD_LIMIT];
DOMSnapshot gDOMCurrent;
ulong gDOMSequence=0;

// ORIGINAL_INCLUDE | #include "Include\BookAdvancedRisk.mqh"
// BEGIN_INCORPORATED Include/BookAdvancedRisk.mqh
#ifndef BOOK_ADVANCED_RISK_MQH
#define BOOK_ADVANCED_RISK_MQH
// ORIGINAL_INCLUDE | #include "BookRiskCore.mqh"
// BEGIN_INCORPORATED Include/BookRiskCore.mqh
#ifndef BOOK_RISK_CORE_MQH
#define BOOK_RISK_CORE_MQH
// The same numerical/state kernel is compiled by host tests and MQL5.
// HOST_CPP_INACTIVE | #ifdef BOOK_RISK_HOST
// HOST_CPP_INACTIVE | #include <cmath>
// HOST_CPP_INACTIVE | bool BRFinite(double x) { return std::isfinite(x); }
// HOST_CPP_INACTIVE | double BRFloor(double x) { return std::floor(x); }
// HOST_CPP_INACTIVE | double BRCeil(double x) { return std::ceil(x); }
// HOST_CPP_INACTIVE | double BRAbs(double x) { return std::fabs(x); }
// HOST_CPP_INACTIVE | #else
bool BRFinite(double x) { return MathIsValidNumber(x) && x!=EMPTY_VALUE; }
double BRFloor(double x) { return MathFloor(x); }
double BRCeil(double x) { return MathCeil(x); }
double BRAbs(double x) { return MathAbs(x); }
// HOST_CPP_INACTIVE | #endif
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
// END_INCORPORATED Include/BookRiskCore.mqh
// Optional financial layer. Never reads book dominance. Legacy TradeRecord,
// SL/TP provenance, economic accounting and SCALPER_BE1 remain authoritative.
struct BookRiskState
{
   ulong pid,ticket;
   int direction,slMode,tpMode,stage,operation,step,closedLockStep;
   string route,mode;
   datetime sentAt,nextTry;
   double requestEntry,requestSL,initialTP,requestedLots;
   double sigma,multiplier,cap,raw,normalized,tpMultiplier;
   double entry,initialSL,initialR,volume,targetSL,targetTP,serverSL,serverTP,realizedNet;
   uint requestID,retcode;
   long requestMSC,confirmedMSC;
   bool loaded,durable,unavailableLogged,noJournal;
};
BookRiskState gBookRisk[];
BookRiskState gBookRiskCandidate;

bool BookRiskEnabled()
{ return Inp_SL_Mode!=SL_ORIGINAL_PONTOS || Inp_TP_Mode!=TP_MODE_ORIGINAL || EnableProfitLocks; }
bool BookRiskInputsValid()
{
   bool ok=(Inp_SL_Mode==SL_ORIGINAL_PONTOS || Inp_SL_Mode==SL_SIGMA_COM_TETO) &&
      (Inp_TP_Mode==TP_MODE_ORIGINAL || Inp_TP_Mode==TP_MODE_BY_ROUTE_R) &&
      BRPositive(BE_Trigger_R) && BRPositive(Inp_Mult_SL) &&
      BRPositive(Inp_Max_SL_Pts_WIN) && BRPositive(Inp_Max_SL_Pts_WDO) &&
      BRPositive(TP_BASE_R) && BRPositive(TP_TURBO_R);
   // Inactive experimental numbers are still checked; no silent substitutions.
   if(!BRPositive(Lock1_Trigger_R) || !BRPositive(Lock1_Protected_R) ||
      !BRPositive(Lock2_Trigger_R) || !BRPositive(Lock2_Protected_R)) ok=false;
   if(EnableProfitLocks && !BRActiveLadderValid(Inp_EnableBreakEven,BE_Trigger_R,
      Lock1_Trigger_R,Lock1_Protected_R,Lock2_Trigger_R,Lock2_Protected_R)) ok=false;
   if(!ok) Print("[BOOK_RISK][INVALID_INPUTS] finite positive values required; active ladder requires BE < Lock1 < Lock2 and increasing protections below triggers; no defaults substituted");
   if(ok && EnableProfitLocks && Inp_TP_Mode==TP_MODE_BY_ROUTE_R)
   {
      if(TP_BASE_R<Lock1_Trigger_R || TP_BASE_R<Lock2_Trigger_R)
         Print("[BOOK_RISK][UNREACHABLE_LOCK] BASE TP_R below a lock trigger");
      if(TP_TURBO_R<Lock1_Trigger_R || TP_TURBO_R<Lock2_Trigger_R)
         Print("[BOOK_RISK][UNREACHABLE_LOCK] TURBO TP_R below a lock trigger");
   }
   return ok;
}
string BookRiskD(double value) { return DoubleToString(value,16); }
string BookRiskRow(const BookRiskState &s)
{
   string v="SCALPER_RISK1|"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+RJEncode(Symbol())+
      "|"+(string)gMagicCore+"|"+(string)s.pid+"|"+(string)s.direction+"|"+s.route+"|"+s.mode+
      "|"+(string)s.sentAt+"|"+BookRiskD(s.requestEntry)+"|"+BookRiskD(s.requestSL)+
      "|"+BookRiskD(s.initialTP)+"|"+BookRiskD(s.requestedLots)+"|"+BookRiskD(s.sigma)+
      "|"+BookRiskD(s.multiplier)+"|"+BookRiskD(s.cap)+"|"+BookRiskD(s.raw)+
      "|"+BookRiskD(s.normalized)+"|"+(string)s.slMode+"|"+(string)s.tpMode+
      "|"+BookRiskD(s.tpMultiplier)+"|"+(string)s.stage+"|"+(string)s.ticket+
      "|"+BookRiskD(s.entry)+"|"+BookRiskD(s.initialSL)+"|"+BookRiskD(s.initialR)+
      "|"+BookRiskD(s.volume)+"|"+(string)s.operation+"|"+(string)s.step+
      "|"+BookRiskD(s.targetSL)+"|"+BookRiskD(s.targetTP)+"|"+(string)s.requestID+
      "|"+(string)s.retcode+"|"+(string)s.requestMSC+"|"+(string)s.confirmedMSC+
      "|"+BookRiskD(s.serverSL)+"|"+BookRiskD(s.serverTP)+"|"+BookRiskD(s.realizedNet)+
      "|"+(string)s.closedLockStep;
   return v+"|"+RJChecksum(v)+"|COMPLETE_RISK1";
}
// Only realized net PnL is signed; price/risk/reference fields retain the
// legacy nonnegative grammar. Do not reinterpret old SCALPER_BE1 records.
bool BookRiskSignedDouble(string text,double &value)
{
   bool negative=(StringLen(text)>0 && StringGetCharacter(text,0)==45);
   string magnitude=negative?StringSubstr(text,1):text;
   if(!RJDouble(magnitude,value)) return false;
   if(negative) value=-value;
   return BRFinite(value);
}
bool BookRiskParse(string row,ulong pid,BookRiskState &s)
{
   string f[],symbol;
   if(StringSplit(row,'|',f)!=41 || f[0]!="SCALPER_RISK1" || f[40]!="COMPLETE_RISK1") return false;
   string prefix=f[0]; for(int k=1;k<39;k++) prefix+="|"+f[k];
   if(RJChecksum(prefix)!=f[39] || !RJDecode(f[2],symbol) || symbol!=Symbol() ||
      f[1]!=(string)AccountInfoInteger(ACCOUNT_LOGIN) || f[3]!=(string)gMagicCore ||
      f[4]!=(string)pid || (f[5]!="1" && f[5]!="-1") || !RJRoute(f[6],f[7])) return false;
   ulong u[15]; int idx[15]={8,18,19,21,22,27,28,31,32,33,34,38,1,3,4};
   for(int i=0;i<15;i++) if(!RJUnsigned(f[idx[i]],u[i])) return false;
   if(u[0]==0 || u[0]>9223372036854775807 || u[1]>1 || u[2]>1 || u[3]>BR_CLOSED ||
      u[5]>3 || u[6]>2 || u[7]>4294967295 || u[8]>4294967295 ||
      u[9]>9223372036854775807 || u[10]>9223372036854775807 || u[11]>2) return false;
   double x[20]; int di[20]={9,10,11,12,13,14,15,16,17,20,23,24,25,26,29,30,35,36,37,13};
   for(int i=0;i<20;i++)
      if(!(di[i]==37?BookRiskSignedDouble(f[di[i]],x[i]):RJDouble(f[di[i]],x[i])) || !BRFinite(x[i])) return false;
   ZeroMemory(s); s.pid=pid; s.direction=(f[5]=="1"?1:-1); s.route=f[6]; s.mode=f[7];
   s.sentAt=(datetime)u[0]; s.slMode=(int)u[1]; s.tpMode=(int)u[2]; s.stage=(int)u[3];
   s.ticket=u[4]; s.operation=(int)u[5]; s.step=(int)u[6]; s.requestID=(uint)u[7];
   s.retcode=(uint)u[8]; s.requestMSC=(long)u[9]; s.confirmedMSC=(long)u[10]; s.closedLockStep=(int)u[11];
   s.requestEntry=x[0]; s.requestSL=x[1]; s.initialTP=x[2]; s.requestedLots=x[3];
   s.sigma=x[4]; s.multiplier=x[5]; s.cap=x[6]; s.raw=x[7]; s.normalized=x[8];
   s.tpMultiplier=x[9]; s.entry=x[10]; s.initialSL=x[11]; s.initialR=x[12]; s.volume=x[13];
   s.targetSL=x[14]; s.targetTP=x[15]; s.serverSL=x[16]; s.serverTP=x[17]; s.realizedNet=x[18];
   if(!BRPositive(s.requestEntry) || !BRPositive(s.requestSL) || !BRPositive(s.initialTP) ||
      !BRPositive(s.requestedLots) || s.direction*(s.requestEntry-s.requestSL)<=0 ||
      !BRPositive(s.multiplier) || !BRPositive(s.cap) || !BRPositive(s.normalized) ||
      !BRPositive(s.tpMultiplier) || s.sigma<0 || s.raw<0) return false;
   if(s.slMode==SL_SIGMA_COM_TETO && (!BRPositive(s.sigma) || !BRPositive(s.raw) || s.normalized>s.cap)) return false;
   if(s.stage!=BR_WAIT_FILL && (!BRPositive(s.entry) || !BRPositive(s.initialSL) ||
      !BRPositive(s.initialR) || !BRPositive(s.volume) ||
      !BEPriceEqual(s.initialR,MathAbs(s.entry-s.initialSL)) ||
      s.direction*(s.entry-s.initialSL)<=0)) return false;
   if((s.stage==BR_PENDING || s.stage==BR_ACK || s.stage==BR_UNCERTAIN || s.stage==BR_CONFIRMED) &&
      (s.operation<1 || s.ticket==0 || s.requestMSC<=0 || !BRPositive(s.targetSL) || !BRPositive(s.targetTP))) return false;
   if((s.stage==BR_ACK || s.stage==BR_CONFIRMED) && s.retcode!=TRADE_RETCODE_DONE) return false;
   s.loaded=true; s.durable=true; return true;
}
// Exact binary reads prevent accepting an earlier valid prefix after a later
// I/O failure. A clean byte count, stable size and successful close are required.
bool BookRiskReadPayload(string path,string &payload,bool &exists)
{
   payload="";
   ResetLastError(); exists=FileIsExist(path); int error=GetLastError();
   if(!exists || error!=0) return false;
   ResetLastError();
   int h=FileOpen(path,FILE_READ|FILE_BIN|FILE_SHARE_READ);
   if(h==INVALID_HANDLE || GetLastError()!=0) { if(h!=INVALID_HANDLE) FileClose(h); return false; }
   ResetLastError(); ulong size=FileSize(h);
   bool ok=(GetLastError()==0 && size>0 && size<=1048576);
   uchar bytes[];
   if(ok) ok=(ArrayResize(bytes,(int)size)==(int)size);
   if(ok)
   {
      ResetLastError(); uint read=FileReadArray(h,bytes,0,(int)size);
      ok=(read==(uint)size && GetLastError()==0);
      ResetLastError(); ulong at=FileTell(h); if(GetLastError()!=0 || at!=size) ok=false;
      ResetLastError(); ulong after=FileSize(h); if(GetLastError()!=0 || after!=size) ok=false;
   }
   ResetLastError(); FileClose(h); if(GetLastError()!=0) ok=false;
   if(!ok) return false;
   payload=CharArrayToString(bytes,0,(int)size,CP_UTF8);
   return StringLen(payload)>0 && StringGetCharacter(payload,StringLen(payload)-1)=='\n';
}
bool BookRiskRead(string path,ulong pid,BookRiskState &s,bool &exists)
{
   string payload;
   if(!BookRiskReadPayload(path,payload,exists)) return false;
   string rows[]; int n=StringSplit(payload,'\n',rows); bool found=false;
   for(int i=0;i<n;i++)
   {
      string row=rows[i];
      int len=StringLen(row);
      if(len>0 && StringGetCharacter(row,len-1)=='\r') row=StringSubstr(row,0,len-1);
      if(row=="") continue;
      BookRiskState candidate;
      if(!BookRiskParse(row,pid,candidate)) return false;
      s=candidate; found=true;
   }
   return found;
}
bool BookRiskAppend(string path,BookRiskState &s)
{
   string row=BookRiskRow(s),payload="\r\n"+row+"\r\n";
   int h=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   bool ok=false;
   if(h!=INVALID_HANDLE)
   {
      if(FileSeek(h,0,SEEK_END))
      {
         ResetLastError(); uint written=FileWriteString(h,payload);
         ok=(written==(uint)StringLen(payload) && GetLastError()==0);
         ResetLastError(); FileFlush(h); if(GetLastError()!=0) ok=false;
      }
      FileClose(h);
   }
   BookRiskState proof; bool exists=false;
   if(ok) ok=BookRiskRead(path,s.pid,proof,exists) && BookRiskRow(proof)==row;
   s.durable=ok;
   if(!ok) PrintFormat("[BOOK_RISK][PERSISTENCE_UNCONFIRMED] pid=%I64u stage=%d; no optional dispatch permitted",s.pid,s.stage);
   return ok;
}
// A distinct leading namespace is essential: EMRInspectFiles intentionally
// rejects unknown suffixes beneath EconomicMarkerPrefix(). Legacy files and
// legacy proof rules remain unchanged; no existing financial file is renamed.
string BookRiskPath(ulong pid) { return "BOOK_RISK1_"+TradeMetaPath(pid)+".journal"; }
string BookRiskPendingIdentity()
{
   return (string)gPendingExec.sentAt+"|"+(string)gPendingExec.direction+"|"+gPendingExec.route+
      "|"+gPendingExec.mode+"|"+BookRiskD(gPendingExec.requestPrice)+"|"+
      BookRiskD(gPendingExec.requestedLots)+"|"+BookRiskD(gPendingExec.slPrice)+"|"+BookRiskD(gPendingExec.tpPrice);
}
string BookRiskPendingPath()
{ return "BOOK_RISK1_"+RequestJournalPath(false)+".frozen."+RJChecksum(BookRiskPendingIdentity()); }
bool BookRiskPendingMatches(const BookRiskState &s)
{
   return s.pid==0 && s.direction==gPendingExec.direction && s.sentAt==gPendingExec.sentAt &&
      s.route==gPendingExec.route && s.mode==gPendingExec.mode &&
      s.requestEntry==gPendingExec.requestPrice && s.requestSL==gPendingExec.slPrice &&
      s.initialTP==gPendingExec.tpPrice && s.requestedLots==gPendingExec.requestedLots;
}
// freeze=true is called once for the final pricing attempt. Later quote checks
// reuse that raw SigmaD1; they never change VWAP/C5 SigmaD1 or widen an open SL.
bool BookRiskResolveTerms(int direction,double price,string mode,double slPts,double tpPts,
                         bool freeze,double &sl,double &tp)
{
   if(freeze)
   {
      ZeroMemory(gBookRiskCandidate);
      gBookRiskCandidate.direction=direction; gBookRiskCandidate.route=armed.route;
      gBookRiskCandidate.mode=mode; gBookRiskCandidate.slMode=(int)Inp_SL_Mode;
      gBookRiskCandidate.tpMode=(int)Inp_TP_Mode;
      gBookRiskCandidate.sigma=(d1Ready && BRPositive(SigmaD1)?SigmaD1:0.0);
      gBookRiskCandidate.multiplier=Inp_Mult_SL;
      gBookRiskCandidate.cap=(gIsDollarFamily?Inp_Max_SL_Pts_WDO:Inp_Max_SL_Pts_WIN);
      gBookRiskCandidate.tpMultiplier=(mode=="TURBO" || mode=="TURBO_CONT"?TP_TURBO_R:TP_BASE_R);
   }
   if(Inp_SL_Mode==SL_ORIGINAL_PONTOS) sl=NormEntrySL(direction,price-direction*slPts);
   else
   {
      double raw,distance; bool capped;
      if(!BRSigmaStop(direction,price,gBookRiskCandidate.sigma,Inp_Mult_SL,gBookRiskCandidate.cap,
                      gTickSize,sl,raw,distance,capped))
      { Print("[BOOK_RISK][SIGMA_STOP_INVALID] raw sigma/tick/cap invalid; no fallback"); return false; }
      sl=NormPriceDigits(sl);
      if(direction*(price-sl)>gBookRiskCandidate.cap || direction*(price-sl)<=0) return false;
   }
   tp=NormEntryTP(direction,price+direction*tpPts);
   if(Inp_TP_Mode==TP_MODE_BY_ROUTE_R)
      tp=NormEntryTP(direction,price+direction*MathAbs(price-sl)*gBookRiskCandidate.tpMultiplier);
   return BRPositive(sl) && BRPositive(tp);
}
bool BookRiskPrepareEntry()
{
   if(!BookRiskEnabled()) return true;
   BookRiskState s=gBookRiskCandidate;
   s.pid=0; s.sentAt=gPendingExec.sentAt; s.stage=BR_WAIT_FILL;
   s.requestEntry=gPendingExec.requestPrice; s.requestSL=gPendingExec.slPrice;
   s.initialTP=gPendingExec.tpPrice; s.requestedLots=gPendingExec.requestedLots;
   s.normalized=MathAbs(s.requestEntry-s.requestSL);
   s.raw=(s.sigma>0?s.sigma*s.multiplier:0);
   if(!BookRiskPendingMatches(s)) return false;
   return BookRiskAppend(BookRiskPendingPath(),s);
}
// Called before the original request guard is released. On restart this reads
// frozen request provenance; never substitutes today's sigma for a lost value.
bool BookRiskAttachEntry(const TradeRecord &r)
{
   BookRiskState s; bool exists=false;
   if(!BookRiskRead(BookRiskPendingPath(),0,s,exists))
   {
      if(exists || BookRiskEnabled())
      {
         PrintFormat("[BOOK_RISK][ENTRY_PROVENANCE_UNAVAILABLE] pid=%I64u; existing SL/TP kept; new optional management suspended",r.positionID);
         // Proven original entry is still accounted. No invented risk reference.
      }
      return true;
   }
   if(!BookRiskPendingMatches(s)) return false;
   s.pid=r.positionID;
   BookRiskState old; bool oldExists=false;
   if(BookRiskRead(BookRiskPath(s.pid),s.pid,old,oldExists))
   {
      bool match=(old.requestEntry==s.requestEntry && old.requestSL==s.requestSL && old.sentAt==s.sentAt);
      if(match) for(int i=0;i<ArraySize(gBookRisk);i++) if(gBookRisk[i].pid==s.pid) gBookRisk[i]=old;
      return match;
   }
   if(oldExists) return false;
   bool ok=BookRiskAppend(BookRiskPath(s.pid),s);
   if(ok) for(int i=0;i<ArraySize(gBookRisk);i++) if(gBookRisk[i].pid==s.pid) gBookRisk[i]=s;
   return ok;
}
int BookRiskIndex(ulong pid)
{
   for(int i=0;i<ArraySize(gBookRisk);i++) if(gBookRisk[i].pid==pid) return i;
   int n=ArraySize(gBookRisk),slot=n;
   if(n>=MAX_TRADE_RECORDS)
   {
      slot=-1;
      for(int i=0;i<n;i++)
         if(((gBookRisk[i].stage==BR_CLOSED && gBookRisk[i].durable) || gBookRisk[i].noJournal) &&
            FindTrackedTrade(gBookRisk[i].pid)<0) { slot=i; break; }
      if(slot<0)
      {
         static datetime nextCapacityLog=0;
         if(TimeTradeServer()>=nextCapacityLog)
         { Print("[BOOK_RISK][CAPACITY_UNRESOLVED] no releasable durable closed cache slot; optional management suspended"); nextCapacityLog=TimeTradeServer()+10; }
         return -1;
      }
   }
   else if(ArrayResize(gBookRisk,n+1)!=n+1) return -1;
   n=slot;
   ZeroMemory(gBookRisk[n]); gBookRisk[n].pid=pid;
   bool exists=false; BookRiskState loaded;
   if(BookRiskRead(BookRiskPath(pid),pid,loaded,exists)) gBookRisk[n]=loaded;
   else
   {
      int error=GetLastError();
      gBookRisk[n].stage=BR_CORRUPT; gBookRisk[n].loaded=true;
      gBookRisk[n].noJournal=(!exists && (error==0 || error==ERR_FILE_NOT_EXIST));
   }
   return n;
}
bool BookRiskBlocksBE(ulong pid)
{
   int idx=BookRiskIndex(pid);
   if(idx<0) return BookRiskEnabled();
   // Missing legacy references do not disable legacy BE. A real pending/new
   // uncertain financial request does prevent a conflicting BE modification.
   if(gBookRisk[idx].stage==BR_CORRUPT)
   {
      // Absence was established by a read-only probe on loading this PID;
      // attachment of our own proven entry journal refreshes this cache.
      return !gBookRisk[idx].noJournal;
   }
   return BRPending(gBookRisk[idx].stage);
}
bool BookRiskStopsValid(const TradeRecord &r,const MqlTick &tick,double targetSL,double targetTP,double liveSL,double liveTP,bool tpOnly)
{
   double point=SymbolInfoDouble(Symbol(),SYMBOL_POINT);
   long stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL),freeze=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_FREEZE_LEVEL);
   if(!BRPositive(point) || stops<0 || freeze<0 || !OnPriceGrid(targetSL) || !OnPriceGrid(targetTP) ||
      !BRPositive(tick.bid) || !BRPositive(tick.ask) || tick.ask<tick.bid || !BRPositive(liveSL)) return false;
   if(tpOnly ? !BEPriceEqual(targetSL,liveSL) : !BRImproves(r.direction,targetSL,liveSL,gTickSize)) return false;
   return BRBrokerDistances(r.direction,tick.bid,tick.ask,point,(int)stops,(int)freeze,
                            targetSL,targetTP,liveSL,liveTP);
}
void BookRiskAccept(BookRiskState &s,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(!BRPending(s.stage) || s.stage==BR_CORRUPT || request.action!=TRADE_ACTION_SLTP ||
      request.position!=s.ticket || request.position_by!=0 || request.symbol!=Symbol() ||
      request.magic!=(ulong)gMagicCore || !BEPriceEqual(request.sl,s.targetSL) ||
      !BEPriceEqual(request.tp,s.targetTP) || (s.requestID>0 && result.request_id!=s.requestID)) return;
   if(result.request_id>0) s.requestID=result.request_id;
   s.retcode=result.retcode;
   if(result.retcode==TRADE_RETCODE_DONE) s.stage=BR_ACK;
   else if(IsFinalRejectedRetcode(result.retcode) || result.retcode==TRADE_RETCODE_NO_CHANGES)
   { s.stage=BR_REJECTED; s.nextTry=TimeTradeServer()+1; }
   else s.stage=BR_UNCERTAIN;
   BookRiskAppend(BookRiskPath(s.pid),s);
}
void BookRiskTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(trans.type!=TRADE_TRANSACTION_REQUEST || request.action!=TRADE_ACTION_SLTP) return;
   for(int i=0;i<ArraySize(gBookRisk);i++)
      if(gBookRisk[i].requestID>0 && result.request_id==gBookRisk[i].requestID)
         BookRiskAccept(gBookRisk[i],request,result);
}
void BookRiskConfirm(BookRiskState &s,const TradeRecord &r)
{
   if(s.stage!=BR_ACK || !s.durable || !OwnPositionSafe(s.pid)) return;
   ulong ticket=0;
   if(!BESelectOwn(s.pid,ticket,s.direction)) return;
   double sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
   bool slProof=BEPriceEqual(sl,s.targetSL) || BRImproves(s.direction,sl,s.targetSL,gTickSize);
   if(!BRServerProof(s.stage,s.retcode==TRADE_RETCODE_DONE,slProof,BEPriceEqual(tp,s.targetTP))) return;
   s.serverSL=sl; s.serverTP=tp; s.confirmedMSC=(long)TimeTradeServer()*1000;
   s.stage=BR_CONFIRMED;
   if(!BookRiskAppend(BookRiskPath(s.pid),s)) { s.stage=BR_ACK; return; }
   PrintFormat("[BOOK_RISK][SERVER_PROTECTION_CONFIRMED] pid=%I64u op=%d step=%d request=%u ret=%u SL=%.16f TP=%.16f; price protection, not a net-profit guarantee",
      s.pid,s.operation,s.step,s.requestID,s.retcode,s.serverSL,s.serverTP);
}
// Read the independent lock certificate from append-only history. Later TP
// recalibration/no-op ticks cannot erase an earlier confirmed lock's identity.
bool BookRiskLastLockProof(ulong pid,BookRiskState &proof)
{
   string payload; bool exists=false;
   if(!BookRiskReadPayload(BookRiskPath(pid),payload,exists)) return false;
   string rows[]; int n=StringSplit(payload,'\n',rows); bool found=false;
   for(int i=0;i<n;i++)
   {
      string row=rows[i]; int len=StringLen(row);
      if(len>0 && StringGetCharacter(row,len-1)=='\r') row=StringSubstr(row,0,len-1);
      if(row=="") continue;
      BookRiskState candidate;
      if(!BookRiskParse(row,pid,candidate)) return false;
      if(candidate.operation==2 && candidate.step>0 && candidate.retcode==TRADE_RETCODE_DONE &&
         (candidate.stage==BR_ACK || candidate.stage==BR_CONFIRMED))
      { proof=candidate; found=true; }
   }
   return found;
}
void BookRiskClosed(BookRiskState &s,const TradeRecord &r)
{
   if((s.stage==BR_CLOSED && s.durable) || !r.volumeClosedComplete || !r.accountingResolved ||
      !BRFinite(r.netProfit)) return;
   if(TimeTradeServer()<s.nextTry) return;
   if(s.stage==BR_CLOSED && !s.durable)
   { s.nextTry=TimeTradeServer()+1; BookRiskAppend(BookRiskPath(s.pid),s); return; }
   if(s.stage==BR_WAIT_FILL)
   {
      if(!r.initialStopsProven || !r.riskValid || !BEEntryComplete(r)) return;
      s.entry=r.weightedEntryPrice; s.initialSL=r.slPrice;
      s.initialR=MathAbs(s.entry-s.initialSL); s.volume=r.totalVolumeIn;
      if(!BRPositive(s.initialR)) return;
   }
   s.closedLockStep=0;
   // A lock exit is not BE-neutral. Require exact deal-side original stop proof,
   // independent DONE acknowledgement and all own exit components at that lock.
   BookRiskState lock;
   bool all=(BookRiskLastLockProof(s.pid,lock) && BEPriceEqual(lock.entry,s.entry) &&
      BEPriceEqual(lock.initialSL,s.initialSL) && HistorySelectByPosition(s.pid));
   int count=0;
   if(all) for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY && entry!=DEAL_ENTRY_INOUT) continue;
      count++;
      if(HistoryDealGetInteger(deal,DEAL_REASON)!=DEAL_REASON_SL ||
         HistoryDealGetInteger(deal,DEAL_TIME_MSC)<lock.requestMSC ||
         !BEPriceEqual(HistoryDealGetDouble(deal,DEAL_SL),lock.targetSL)) all=false;
   }
   if(all && count>0) s.closedLockStep=lock.step;
   s.realizedNet=r.netProfit; s.stage=BR_CLOSED; s.nextTry=TimeTradeServer()+1;
   if(BookRiskAppend(BookRiskPath(s.pid),s))
      PrintFormat("[BOOK_RISK][CLOSED] pid=%I64u lock_exit_step=%d net=%.16f initialR=%.16f legacy_accounting_unchanged=1",s.pid,s.closedLockStep,s.realizedNet,s.initialR);
}
void BookRiskManage(bool dispatch=true)
{
   for(int i=0;i<gTradeRecordCount;i++)
   {
      TradeRecord r=gTradeRecords[i]; if(r.positionID==0) continue;
      int idx=BookRiskIndex(r.positionID); if(idx<0) continue;
      BookRiskState s=gBookRisk[idx];
      if(s.stage==BR_CORRUPT)
      {
         if(BookRiskEnabled() && !s.unavailableLogged)
         { PrintFormat("[BOOK_RISK][NO_VERIFIABLE_REFERENCE] pid=%I64u; optional locks/TP suspended; existing protections retained",r.positionID); s.unavailableLogged=true; }
         gBookRisk[idx]=s; continue;
      }
      if(r.volumeClosedComplete) { BookRiskClosed(s,r); gBookRisk[idx]=s; continue; }
      BookRiskConfirm(s,r);
      // A persisted uncertain dispatch never becomes retryable merely through
      // elapsed time or a live price. The exact request result must reconcile.
      if(!dispatch || (!BRMayDispatch(s.stage) && s.stage!=BR_WAIT_FILL))
      { gBookRisk[idx]=s; continue; }
      if(r.closed || r.historyRefreshPending || !r.accountingResolved || !r.initialStopsProven || !r.riskValid ||
         !BRPositive(r.weightedEntryPrice) || !BRPositive(r.slPrice) ||
         r.direction*(r.weightedEntryPrice-r.slPrice)<=0 || gPendingExec.active || gPendingExit.active ||
         gLiveOwnershipUnresolved || gPendingOrderClassificationUnresolved || gMultipleOwnOrdersActive ||
         gOrderRegistryUnavailable || gOrderObligationScanUnresolved || HasOwnPendingOrder() ||
         r.be.stage==BE_REQUEST_PENDING || r.be.stage==BE_ACKNOWLEDGED || r.be.stage==BE_UNRESOLVED)
      { gBookRisk[idx]=s; continue; }
      MqlDateTime now; TimeToStruct(TimeTradeServer(),now);
      if(now.hour*100+now.min>=Inp_EOD_CloseHHMM || TimeTradeServer()<s.nextTry)
      { gBookRisk[idx]=s; continue; }
      ulong ticket=0;
      if(!BESelectOwn(s.pid,ticket,r.direction) || !BEEntryComplete(r) || !OwnPositionSafe(s.pid) ||
         !PositionSelectByTicket(ticket) ||
         !BEPriceEqual(PositionGetDouble(POSITION_PRICE_OPEN),r.weightedEntryPrice) ||
         MathAbs(PositionGetDouble(POSITION_VOLUME)-(r.totalVolumeIn-r.totalVolumeOut))>AccountingVolumeTolerance())
      { gBookRisk[idx]=s; continue; }
      double liveSL=PositionGetDouble(POSITION_SL),liveTP=PositionGetDouble(POSITION_TP);
      if(s.stage==BR_WAIT_FILL)
      {
         s.entry=r.weightedEntryPrice; s.initialSL=r.slPrice;
         s.initialR=MathAbs(s.entry-s.initialSL); s.volume=r.totalVolumeIn; s.ticket=ticket; s.stage=BR_IDLE;
         if(!BookRiskAppend(BookRiskPath(s.pid),s)) { s.stage=BR_WAIT_FILL; gBookRisk[idx]=s; continue; }
         // Known entry costs are disclosed separately; unknown exit costs and
         // slippage/gaps mean this is an estimate, never a maximum realized loss.
         double knownCosts=MathMax(0,-r.commission)+MathMax(0,-r.fee)+MathMax(0,-r.swap);
         PrintFormat("[BOOK_RISK][INITIAL_REFERENCE] pid=%I64u route=%s mode=%s SIGMA_RISK_REFERENCE=%.16f SL_MULTIPLIER=%.16f SL_CAP_PTS=%.16f SL_RAW_PTS=%.16f SL_NORMALIZED_PTS=%.16f SL_CAP_ACTIVE=%d SL_INITIAL_PRICE=%.16f SL_INITIAL_RISK_MONEY=%.16f SL_EFFECTIVE_RISK_AFTER_FILL=%.16f KNOWN_COSTS=%.16f COST_INCLUSIVE_ESTIMATE=%.16f",
            s.pid,s.route,s.mode,s.sigma,s.multiplier,s.cap,s.raw,s.normalized,(int)(s.slMode==SL_SIGMA_COM_TETO && s.raw>s.cap),s.initialSL,
            CalcInitialRiskMoney(s.direction,s.requestEntry,s.requestSL,s.requestedLots),r.initialRiskMoney,knownCosts,r.initialRiskMoney+knownCosts);
         if(s.slMode==SL_SIGMA_COM_TETO && s.initialR>s.cap)
            PrintFormat("[BOOK_RISK][SL_EFFECTIVE_CAP_EXCEEDED] pid=%I64u requested_distance=%.16f effective_fill_distance=%.16f cap=%.16f; slippage changed risk; original protective SL retained, never widened",s.pid,s.normalized,s.initialR,s.cap);
         double tpR=s.direction*(liveTP-s.entry)/s.initialR;
         if(EnableProfitLocks && (tpR<Lock1_Trigger_R || tpR<Lock2_Trigger_R))
            PrintFormat("[BOOK_RISK][UNREACHABLE_LOCK] pid=%I64u current TP_R=%.8f below lock trigger",s.pid,tpR);
      }
      // Refuse partial-fill/reference drift instead of recalculating initial R
      // from an already moved live SL. Finalized entry must remain identical.
      if(!BEPriceEqual(s.entry,r.weightedEntryPrice) || !BEPriceEqual(s.initialSL,r.slPrice) ||
         MathAbs(s.volume-r.totalVolumeIn)>AccountingVolumeTolerance())
      { s.stage=BR_CORRUPT; gBookRisk[idx]=s; continue; }
      MqlTick tick;
      if(!SymbolInfoTick(Symbol(),tick) || !BRPositive(tick.bid) || !BRPositive(tick.ask) || tick.ask<tick.bid)
      { gBookRisk[idx]=s; continue; }
      int operation=0; double targetSL=liveSL,targetTP=liveTP; int step=0;
      // Calibrate TP first from confirmed entry and original proven SL; live SL
      // is preserved verbatim, never reset to its original risk-bearing level.
      if(s.tpMode==TP_MODE_BY_ROUTE_R && Inp_TP_Mode==TP_MODE_BY_ROUTE_R)
      {
         double expected=NormEntryTP(s.direction,s.entry+s.direction*s.initialR*s.tpMultiplier);
         if(!BEPriceEqual(liveTP,expected)) { operation=3; targetTP=expected; }
      }
      if(operation==0 && EnableProfitLocks)
      {
         double progress=s.direction*((s.direction==1?tick.bid:tick.ask)-s.entry)/s.initialR;
         step=BRHighestLock(progress,Lock1_Trigger_R,Lock2_Trigger_R);
         if(step>0)
         {
            double protectedR=(step==2?Lock2_Protected_R:Lock1_Protected_R);
            // Rounding toward entry avoids claiming more protection than an
            // off-grid requested rung. The actual rounded price is journaled.
            if(!BRLockPrice(s.direction,s.entry,s.initialR,protectedR,gTickSize,targetSL))
            { gBookRisk[idx]=s; continue; }
            targetSL=NormPriceDigits(targetSL);
            if(BRImproves(s.direction,targetSL,liveSL,gTickSize)) operation=2;
         }
      }
      if(operation==0 || !BookRiskStopsValid(r,tick,targetSL,targetTP,liveSL,liveTP,operation==3))
      { s.nextTry=TimeTradeServer()+1; gBookRisk[idx]=s; continue; }
      s.operation=operation; s.ticket=ticket; s.step=step; s.targetSL=targetSL; s.targetTP=targetTP;
      s.requestID=0; s.retcode=0; s.requestMSC=(tick.time_msc>0?tick.time_msc:(long)TimeTradeServer()*1000);
      s.confirmedMSC=0; s.stage=BR_PENDING;
      // Durable MAY_HAVE_DISPATCHED barrier precedes the only financial API.
      // A crash after this point leaves an uncertain request, never a safe retry.
      if(!BookRiskAppend(BookRiskPath(s.pid),s)) { s.stage=BR_UNCERTAIN; gBookRisk[idx]=s; continue; }
      gBookRisk[idx]=s;
      trade.SetExpertMagicNumber(gMagicCore);
      bool sent=trade.PositionModify(ticket,targetSL,targetTP);
      MqlTradeRequest request; MqlTradeResult result; trade.Request(request); trade.Result(result);
      if(!sent && result.retcode==TRADE_RETCODE_DONE) result.retcode=TRADE_RETCODE_ERROR;
      BookRiskAccept(gBookRisk[idx],request,result);
      BookRiskConfirm(gBookRisk[idx],r);
   }
}
#endif
// END_INCORPORATED Include/BookAdvancedRisk.mqh

void DOMClearSnapshot(DOMSnapshot &out)
{
  ZeroMemory(out);
  out.quality=DOM_QUALITY_NONE;
}
void DOMResetCache()
{
  DOMClearSnapshot(gDOMCurrent);
  gDOMSequence=0;
}

bool DOMFinite(const double value)
{
  return MathIsValidNumber(value) && value!=EMPTY_VALUE;
}

bool DOMAddVolume(double &total,const double volume)
{
  double sum=total+volume;
  if(!DOMFinite(sum) || sum<0.0) return false;
  total=sum;
  return true;
}

// volume_real==0 is treated as unavailable; only then is integer volume used.
// NaN, infinity or negative volume_real is corrupt data, never a fallback case.
// A positive volume_real takes precedence; integer volume may lose precision.
bool DOMRecordVolume(const MqlBookInfo &record,double &volume,bool &fallback)
{
   volume=0.0;
   fallback=false;
   if(!DOMFinite(record.volume_real) || record.volume_real<0.0 || record.volume<0)
      return false;
   if(record.volume_real>0.0)
      volume=record.volume_real;
   else
   {
      // A larger integer cannot always be represented exactly by a double.
      // Prefer unavailable evidence over silently rounding the fallback size.
      if(record.volume>9007199254740992) return false;
     volume=(double)record.volume;
     fallback=(record.volume>0);
    }
    return DOMFinite(volume) && volume>=0.0;
}

void DOMSwapLevel(double &prices[],double &volumes[],const int a,const int b)
{
  double price=prices[a];
  double volume=volumes[a];
  prices[a]=prices[b]; volumes[a]=volumes[b];
  prices[b]=price; volumes[b]=volume;
}

// Heapsort gives a deterministic O(n log n) bound with fixed auxiliary storage.
void DOMSiftLevels(double &prices[],double &volumes[],int root,const int count)
{
   while(root<count/2)
   {
     int child=2*root+1;
     if(child+1<count && prices[child]<prices[child+1]) child++;
     if(prices[root]>=prices[child]) return;
     DOMSwapLevel(prices,volumes,root,child);
     root=child;
   }
}

void DOMSortLevels(double &prices[],double &volumes[],const int count)
{
  for(int root=count/2-1;root>=0;root--) DOMSiftLevels(prices,volumes,root,count);
  for(int end=count-1;end>0;end--)
  {
    DOMSwapLevel(prices,volumes,0,end);
    DOMSiftLevels(prices,volumes,0,end);
  }
}

bool DOMSummarizeSide(double &prices[],double &volumes[],const int count,
           const bool buy,int &levels,double &best,
           double &volume1,double &volume5,
           double &depthPrice[],double &depthVolume[])
{
  levels=0; best=0.0; volume1=0.0; volume5=0.0;
  for(int i=0;i<5;i++) { depthPrice[i]=0.0; depthVolume[i]=0.0; }
  if(count<=0) return true;
  DOMSortLevels(prices,volumes,count);
  int step=buy ? -1 : 1;
  int first=buy ? count-1 : 0;
    double groupPrice=prices[first];
    double groupVolume=0.0;
    for(int offset=0;offset<count;offset++)
    {
       int idx=first+offset*step;
       if(prices[idx]!=groupPrice)
       {
          levels++;
          if(levels==1) { best=groupPrice; volume1=groupVolume; }
          if(levels<=5)
          {
             depthPrice[levels-1]=groupPrice; depthVolume[levels-1]=groupVolume;
           if(!DOMAddVolume(volume5,groupVolume)) return false;
         }
         groupPrice=prices[idx]; groupVolume=0.0;
       }
       if(!DOMAddVolume(groupVolume,volumes[idx])) return false;
      }
      levels++;
      if(levels==1) { best=groupPrice; volume1=groupVolume; }
      if(levels<=5)
      {
         depthPrice[levels-1]=groupPrice; depthVolume[levels-1]=groupVolume;
         if(!DOMAddVolume(volume5,groupVolume)) return false;
      }
      return true;
}

// The caller validates connection, exact chart symbol and subscription first.
// Equal double prices on the SAME side are aggregated without rounding.
bool DOMBuildSnapshot(const MqlBookInfo &book[],const int count,
         const ulong collectedMS,DOMSnapshot &out)
{
   DOMClearSnapshot(out);
   out.collectedMS=collectedMS;
   out.rawRecords=count;
   if(count<=0) { out.quality=DOM_QUALITY_EMPTY; return false; }
   if(count>DOM_RAW_RECORD_LIMIT)
   { out.quality=DOM_QUALITY_TOO_LARGE; return false; }
   if(count>ArraySize(book))
   { out.quality=DOM_QUALITY_INVALID; out.invalidRecords=1; return false; }

int bids=0,asks=0;
for(int i=0;i<count;i++)
{
  double volume=0.0;
  bool fallback=false;
  if(!DOMRecordVolume(book[i],volume,fallback))
   { out.invalidRecords++; continue; }
   if(fallback) out.volumeFallbackRecords++;
   if(volume==0.0) out.zeroVolumeRecords++;
   if(book[i].type==BOOK_TYPE_BUY_MARKET ||
book[i].type==BOOK_TYPE_SELL_MARKET)
   {
      // Market records have no usable price and never contribute to depth.
      if(book[i].type==BOOK_TYPE_BUY_MARKET)
      {
         out.marketBuyRecords++;
         if(!DOMAddVolume(out.marketBuyVolume,volume)) out.invalidRecords++;
      }
   else
   {
     out.marketSellRecords++;
     if(!DOMAddVolume(out.marketSellVolume,volume)) out.invalidRecords++;
   }
   continue;
 }
 if((book[i].type!=BOOK_TYPE_BUY && book[i].type!=BOOK_TYPE_SELL) ||
    !DOMFinite(book[i].price) || book[i].price<=0.0)
 { out.invalidRecords++; continue; }
 if(volume==0.0) continue; // Zero quantity is not an available price level.
 if(book[i].type==BOOK_TYPE_BUY)
 {
    gDOMBidPrices[bids]=book[i].price;
    gDOMBidVolumes[bids]=volume;
    bids++;
 }
 else
 {
    gDOMAskPrices[asks]=book[i].price;
    gDOMAskVolumes[asks]=volume;
    asks++;
 }
}
out.bidPriceRecords=bids;
out.askPriceRecords=asks;
if(out.invalidRecords>0) { out.quality=DOM_QUALITY_INVALID; return false; }
if(!DOMSummarizeSide(gDOMBidPrices,gDOMBidVolumes,bids,true,out.bidLevels,
             out.bestBid,out.bidVolume1,out.bidVolume5,
             out.bidDepthPrice,out.bidDepthVolume) ||
   !DOMSummarizeSide(gDOMAskPrices,gDOMAskVolumes,asks,false,out.askLevels,
             out.bestAsk,out.askVolume1,out.askVolume5,
             out.askDepthPrice,out.askDepthVolume))
{ out.quality=DOM_QUALITY_INVALID; out.invalidRecords++; return false; }
if(out.bidLevels==0 || out.askLevels==0)
{ out.quality=DOM_QUALITY_ONE_SIDED; return false; }
if(out.bestBid>=out.bestAsk)
{ out.quality=DOM_QUALITY_CROSSED; return false; }

out.spread=out.bestAsk-out.bestBid;
out.midpoint=out.bestBid+out.spread*0.5;
double depthSum=out.bidVolume5+out.askVolume5;
double bestSum=out.bidVolume1+out.askVolume1;
if(!DOMFinite(out.spread) || !DOMFinite(out.midpoint) ||
   !DOMFinite(depthSum) || depthSum<=0.0 ||
   !DOMFinite(bestSum) || bestSum<=0.0)
{ out.quality=DOM_QUALITY_INVALID; return false; }
out.i5=(out.bidVolume5-out.askVolume5)/depthSum;
    // Algebraically (Ask*BidVol1 + Bid*AskVol1)/(BidVol1+AskVol1).
    // This equivalent form avoids multiplying a price by a potentially huge size.
    out.microprice=out.bestBid+out.spread*(out.bidVolume1/bestSum);
    out.micropriceMinusMid=out.microprice-out.midpoint;
    if(!DOMFinite(out.i5) || out.i5 < -1.0 || out.i5 > 1.0 ||
       !DOMFinite(out.microprice) || !DOMFinite(out.micropriceMinusMid))
    { out.quality=DOM_QUALITY_INVALID; return false; }
    out.bookValid=true;
    out.i5Available=(out.bidLevels>=5 && out.askLevels>=5);
    if(!out.i5Available) out.i5=0.0; // No five-price imbalance on shallow depth.
    out.micropriceAvailable=true;
    out.quality=(out.bidLevels>=5 && out.askLevels>=5) ?
          DOM_QUALITY_OK : DOM_QUALITY_SHALLOW;
    return true;
}

// Copying this observational snapshot has no operational return value.
// It does not classify a signal, authorize an order or change strategy state.
void DOMStoreSnapshot(const DOMSnapshot &snapshot)
{
   DOMSnapshot next=snapshot;
   next.sequence=++gDOMSequence;
   gDOMCurrent=next;
}

string DOMQualityName(const ENUM_DOM_QUALITY quality)
{
  switch(quality)
  {
    case DOM_QUALITY_NONE: return "NONE";
    case DOM_QUALITY_OK: return "OK";
    case DOM_QUALITY_EMPTY: return "EMPTY";
    case DOM_QUALITY_TOO_LARGE: return "TOO_LARGE";
    case DOM_QUALITY_INVALID: return "INVALID";
    case DOM_QUALITY_ONE_SIDED: return "ONE_SIDED";
    case DOM_QUALITY_CROSSED: return "CROSSED_OR_LOCKED";
     case DOM_QUALITY_SHALLOW: return "SHALLOW";
     case DOM_QUALITY_API_FAILURE: return "API_FAILURE";
     case DOM_QUALITY_NO_SUBSCRIPTION: return "NO_SUBSCRIPTION";
     case DOM_QUALITY_DISCONNECTED: return "DISCONNECTED";
     case DOM_QUALITY_SYMBOL_MISMATCH: return "SYMBOL_MISMATCH";
    }
    return "NONE";
}


// Optional descriptive DOM telemetry. No trading/accounting state is changed.
// This module is called after the original timer work; no OnBookEvent handler.
#define DOM_EVENT_CAPACITY 256
#define DOM_TELEMETRY_DAY_BYTES 10485760
#define DOM_LATENCY_WINDOW 128
enum ENUM_DOM_LATENCY_KIND
{
   DOM_LAT_API=0, DOM_LAT_AGG=1, DOM_LAT_WRITE=2, DOM_LAT_RUNTIME=3
};
struct DOMTelemetryEvent
{
   int kind, status, direction, route;
   ulong sequence, localMS;
   datetime signalBar, contextBar;
   ulong positionID, entryOrder, entryDeal, exitPositionID, exitOrder, exitDeal;
   uint entryRequestID, exitRequestID;
   bool entryActive, exitActive;
   double price, trigger, lots, sl, tp, netProfit;
   bool closed, volumeComplete, accountingResolved, finalizationWritten;
   bool apiCalled, aggregationDone;
   ulong apiDurationUS, aggregationUS;
   int apiError;
   int latencyKind;
   ulong samples, p50, p95, p99, maximum;
   bool percentilesAvailable;
   DOMSnapshot snapshot;
};
DOMTelemetryEvent gDOMEvents[DOM_EVENT_CAPACITY];
int gDOMEventHead=0, gDOMEventCount=0;
ulong gDOMEventSequence=0, gDOMDroppedEvents=0;
ulong gDOMLatencySamples[4][DOM_LATENCY_WINDOW];
int gDOMLatencyNext[4];
ulong gDOMLatencySeen[4], gDOMLatencyMaximum[4];
bool gDOMSubscriptionOwned=false, gDOMRuntimeReady=false;
bool gDOMCollectionEnabled=false, gDOMTelemetryEnabled=false;
string gDOMBookSymbol="", gDOMTelemetryPrefix="";
string gDOMTelemetryDay="", gDOMTelemetryPath="";
ulong gDOMTelemetryBytes=0, gDOMRunStartOffset=0;
ulong gDOMLastCollectMS=0, gDOMLastFlushMS=0, gDOMLastSummaryMS=0;
ulong gDOMSuspendUntilMS=0, gDOMSamplingGaps=0;
ulong gDOMTelemetryErrors=0, gDOMApiFailures=0, gDOMOversizedBooks=0;
int gDOMApiFailureRun=0, gDOMSlowRun=0, gDOMSlowWriteRun=0;
int gDOMContainmentEvents=0, gDOMLastApiError=0;

void DOMLatency(const int kind,const ulong elapsedUS)
{
  if(!Inp_DOM_Enable || kind<0 || kind>=4) return;
  gDOMLatencySamples[kind][gDOMLatencyNext[kind]]=elapsedUS;
  gDOMLatencyNext[kind]=(gDOMLatencyNext[kind]+1)%DOM_LATENCY_WINDOW;
  gDOMLatencySeen[kind]++;
    if(elapsedUS>gDOMLatencyMaximum[kind]) gDOMLatencyMaximum[kind]=elapsedUS;
}

bool DOMPushEvent(const DOMTelemetryEvent &event)
{
  if(!Inp_DOM_Enable || !gDOMRuntimeReady) return false;
  if(!gDOMTelemetryEnabled || gDOMEventCount>=DOM_EVENT_CAPACITY)
  { gDOMDroppedEvents++; return false; }
  int index=(gDOMEventHead+gDOMEventCount)%DOM_EVENT_CAPACITY;
  gDOMEvents[index]=event;
  gDOMEvents[index].sequence=++gDOMEventSequence;
  gDOMEventCount++;
  return true;
}

int DOMAuditStatusCode(const string &status)
{
  // Existing audit events only. No inference of execution or profitability.
  if(status=="ARMED") return 1;
  if(status=="REQUEST_ACCEPTED") return 2;
  if(status=="ORDER_FAILED") return 3;
  if(status=="TIMEOUT_ARMED") return 4;
  if(status=="ABORT_SESSION_END") return 5;
  if(status=="ABORT_EOD") return 6;
  if(status=="ARMED_CANCEL_HARD") return 7;
  if(status=="OVERSHOOT_BLOCK") return 8;
  if(status=="LATE_BREAKOUT_LOST") return 9;
  if(status=="LATE_OVERSHOOT_BLOCK") return 10;
  if(status=="HOLD_SPREAD") return 11;
  if(status=="LATE_PENDING_BLOCK") return 12;
  if(status=="LATE_POSITION_BLOCK") return 13;
  if(status=="DAILY_RISK_BLOCK" || status=="LATE_DAILY_RISK_BLOCK") return 14;
  if(status=="LATE_QUOTA_BLOCK") return 15;
  if(status=="LATE_DIRECTION_BLOCK") return 16;
  if(status=="LATE_GLASS_BLOCK") return 17;
  if(status=="LATE_VWAP_INVALID") return 18;
    if(status=="STOPS_LEVEL_BLOCK") return 19;
    if(status=="NO_MARGIN") return 20;
    return 0;
}

int DOMRouteCode(const string &mode)
{
  if(mode=="BASE") return 1;
  if(mode=="TURBO") return 2;
  if(mode=="BASE_CONT") return 3;
  if(mode=="TURBO_CONT") return 4;
  return 0;
}

void DOMCopyCorrelation(DOMTelemetryEvent &event)
{
  event.signalBar=gLastMatrixEvalBar;
  event.contextBar=gMacro.barTime;
  event.positionID=gOpenPos.active ? gOpenPos.positionID : 0;
  event.entryActive=gPendingExec.active;
  if(event.entryActive)
  {
     event.entryOrder=gPendingExec.orderTicket;
     event.entryDeal=gPendingExec.resultDeal;
     event.entryRequestID=gPendingExec.requestID;
  }
  event.exitActive=gPendingExit.active;
  if(event.exitActive)
  {
     event.exitPositionID=gPendingExit.positionID;
     event.exitOrder=gPendingExit.orderTicket;
     event.exitDeal=gPendingExit.resultDeal;
     event.exitRequestID=gPendingExit.requestID;
  }
  event.snapshot=gDOMCurrent;
}

void DOMObserveAudit(const string &status,const string &direction,
        const string &mode,const double price,const double trigger)
{
  if(!Inp_DOM_Enable || !gDOMRuntimeReady) return;
  int code=DOMAuditStatusCode(status);
  if(code==0) return;
  if(!gDOMTelemetryEnabled) { gDOMDroppedEvents++; return; }
  DOMTelemetryEvent event;
  ZeroMemory(event);
  event.kind=2; event.status=code; event.localMS=GetTickCount64();
  event.direction=(direction=="BUY" ? 1 : (direction=="SELL" ? -1 : 0));
    event.route=DOMRouteCode(mode); event.price=price; event.trigger=trigger;
    DOMCopyCorrelation(event);
    DOMPushEvent(event); // Fixed numeric copy only: no file/book/history/allocation.
}

void DOMObserveTrade(const TradeRecord &record)
{
  if(!Inp_DOM_Enable || !gDOMRuntimeReady) return;
  if(!gDOMTelemetryEnabled) { gDOMDroppedEvents++; return; }
  DOMTelemetryEvent event;
  ZeroMemory(event);
  event.kind=3; event.localMS=GetTickCount64();
    event.direction=record.direction; event.route=DOMRouteCode(record.mode);
    // A recovered row can refer to a different cycle from the current pending
    // request. Copy only identifiers present in this exact record; unknown
    // request/deal identities remain zero, never borrowed from another cycle.
    event.signalBar=gLastMatrixEvalBar; event.contextBar=gMacro.barTime;
    event.snapshot=gDOMCurrent;
    event.positionID=record.positionID; event.entryOrder=record.entryOrderTicket;
    event.exitDeal=record.lastExitDealTicket;
    event.price=record.entryPrice; event.lots=record.volume;
    event.sl=record.slPrice; event.tp=record.tpPrice; event.netProfit=record.netProfit;
    event.closed=record.closed; event.volumeComplete=record.volumeClosedComplete;
    event.accountingResolved=record.accountingResolved;
    event.finalizationWritten=record.finalizationWritten;
    // The caller's durable CSV write is the event being observed. These copied
    // flags are telemetry only and cannot establish economic resolution.
    DOMPushEvent(event);
}

bool DOMTelemetryNamespace()
{
  if(StringLen(Inp_DOM_InstanceTag)<1 || StringLen(Inp_DOM_InstanceTag)>32)
     return false;
  for(int i=0;i<StringLen(Inp_DOM_InstanceTag);i++)
  {
     ushort c=StringGetCharacter(Inp_DOM_InstanceTag,i);
     if(!((c>='a' && c<='z') || (c>='A' && c<='Z') ||
          (c>='0' && c<='9') || c=='_' || c=='-')) return false;
  }
  string server=AccountInfoString(ACCOUNT_SERVER);
  string symbol=Symbol();
  long account=AccountInfoInteger(ACCOUNT_LOGIN);
  if(account<=0 || StringLen(server)<1 || StringLen(server)>512 ||
     StringLen(symbol)<1 || StringLen(symbol)>512 || gMagicCore<=0) return false;
  // Length-delimited UTF-8 inputs avoid delimiter ambiguity. Full SHA-256
  // scopes only these new telemetry files, never financial persistence.
  string canonical=(string)StringLen(server)+":"+server+"|"+(string)account+
       "|"+(string)StringLen(symbol)+":"+symbol+"|"+(string)gMagicCore+
       "|"+(string)StringLen(Inp_DOM_InstanceTag)+":"+Inp_DOM_InstanceTag;
    uchar data[], key[], digest[];
    int size=StringToCharArray(canonical,data,0,WHOLE_ARRAY,CP_UTF8);
    if(size<=1 || size>8192 || ArraySize(data)!=size || data[size-1]!=0 ||
       ArrayResize(data,size-1)!=size-1) return false;
    ResetLastError();
    int written=CryptEncode(CRYPT_HASH_SHA256,data,key,digest);
    if(written!=32 || ArraySize(digest)!=32 || GetLastError()!=0) return false;
    string hash="";
    for(int i=0;i<32;i++) hash+=StringFormat("%02x",(uint)digest[i]);
    gDOMTelemetryPrefix="DOMOBS_1123_"+hash+"_";
      return true;
}

string DOMCsvField(string value)
{
  StringReplace(value,"\"","\"\"");
  StringReplace(value,"\r"," "); StringReplace(value,"\n"," ");
  return "\""+value+"\"";
}

string DOMDayString()
{
  MqlDateTime parts;
  TimeToStruct(TimeCurrent(),parts);
  return StringFormat("%04d%02d%02d",parts.year,parts.mon,parts.day);
}

void DOMDisableTelemetry(const string reason)
{
  if(gDOMTelemetryEnabled)
     Print("[SCALPER_DOM][TELEMETRY_SUSPENDED] ",reason,
      " queued=",gDOMEventCount," dropped=",gDOMDroppedEvents);
  gDOMTelemetryEnabled=false;
  gDOMDroppedEvents+=(ulong)gDOMEventCount;
  gDOMEventHead=0; gDOMEventCount=0;
}

bool DOMOpenTelemetryDay()
{
  // One stable file per account/server/symbol/Magic/tag/day. No directory
  // scans, chart-ID filenames, file deletion or financial-file inspection.
  gDOMTelemetryDay=DOMDayString();
  gDOMTelemetryPath=gDOMTelemetryPrefix+gDOMTelemetryDay+".csv";
  gDOMTelemetryEnabled=true;
  ResetLastError();
  int handle=FileOpen(gDOMTelemetryPath,
     FILE_READ|FILE_WRITE|FILE_BIN|FILE_SHARE_READ);
  if(handle==INVALID_HANDLE)
  { gDOMTelemetryErrors++; DOMDisableTelemetry("cannot open daily file"); return false; }
  ResetLastError();
  ulong bytes=FileSize(handle);
  bool valid=(GetLastError()==0 && bytes<=(ulong)DOM_TELEMETRY_DAY_BYTES);
  if(valid && bytes>0)
  {
     // Never append behind an interrupted partial row. A failed query is
     // uncertainty, not proof that the file is absent or empty.
     if(bytes<2 || !FileSeek(handle,-2,SEEK_END)) valid=false;
     else
   {
       uchar tail[2];
       ResetLastError();
       uint read=FileReadArray(handle,tail,0,2);
       if(read!=2 || GetLastError()!=0 || tail[0]!=13 || tail[1]!=10) valid=false;
   }
  }
  ResetLastError(); FileClose(handle);
  if(GetLastError()!=0) valid=false;
  if(!valid)
  { gDOMTelemetryErrors++; DOMDisableTelemetry("unverified size or incomplete row");
return false; }
  gDOMTelemetryBytes=bytes; gDOMRunStartOffset=bytes;
  if(bytes>=(ulong)DOM_TELEMETRY_DAY_BYTES)
  { DOMDisableTelemetry("daily 10 MiB cap reached"); return false; }
  return true;
}

string DOMTelemetryHeader()
{
   string
row="account;server;symbol;magic;chart;instance;day;run_start_offset;event_seq;kind;status_code;local_ms;signal_bar;context_bar;direction;route;position_id;entry_active;entry_order;entry_deal;entry_request_id;exit_active;exit_position_id;exit_order;exit_deal;exit_request_id;price;trigger;lots;sl;tp;net_profit;closed;volume_complete;accounting_resolved;finalization_written;quality;sample_ms;sample_seq;book_valid;bid_levels;ask_levels;bid;ask;spread;bid_vol1;ask_vol1;bid_vol5;ask_vol5;i5;microprice;micro_minus_mid;market_buy_vol;market_sell_vol;invalid_records;zero_volume_records;fallback_records";
   for(int i=1;i<=5;i++)
    row+=";bid_price_"+(string)i+";bid_volume_"+(string)i+
       ";ask_price_"+(string)i+";ask_volume_"+(string)i;
   return
row+";api_duration_us;aggregation_us;sample_api_error;latency_kind;samples_since_attach;latency_window_count;p50_us;p95_us;p99_us;max_since_attach_us;terminal_memory_mb;dropped;sampling_gaps;api_failures;io_errors;oversized_books;api_error\r\n";
}
string DOMNumber(const bool available,const double value)
{
  return available ? StringFormat("%.17g",value) : "NA";
}

string DOMTelemetryRow(const DOMTelemetryEvent &event)
{
  DOMSnapshot snapshot=event.snapshot;
  string kind=(event.kind==1 ? "SNAPSHOT" : (event.kind==2 ? "BASE_AUDIT" :
        (event.kind==3 ? "BASE_TRADE_CSV_WRITTEN" : "LATENCY")));
  string row=(string)AccountInfoInteger(ACCOUNT_LOGIN)+";"+
DOMCsvField(AccountInfoString(ACCOUNT_SERVER))+";"+DOMCsvField(Symbol())+";"+
  (string)gMagicCore+";"+(string)ChartID()+";"+DOMCsvField(Inp_DOM_InstanceTag)+";"+
  gDOMTelemetryDay+";"+(string)gDOMRunStartOffset+";"+(string)event.sequence+";"+
  kind+";"+(string)event.status+";"+(string)event.localMS+";"+
  (string)(long)event.signalBar+";"+(string)(long)event.contextBar+";"+
  (string)event.direction+";"+(string)event.route+";"+(string)event.positionID+";"+

(string)(int)event.entryActive+";"+(string)event.entryOrder+";"+(string)event.entryDeal+";"+
   (string)event.entryRequestID+";"+(string)(int)event.exitActive+";"+
   (string)event.exitPositionID+";"+(string)event.exitOrder+";"+(string)event.exitDeal+";"+
   (string)event.exitRequestID+";"+StringFormat("%.17g",event.price)+";"+
   StringFormat("%.17g",event.trigger)+";"+StringFormat("%.17g",event.lots)+";"+
   StringFormat("%.17g",event.sl)+";"+StringFormat("%.17g",event.tp)+";"+
   (event.kind==3 ? StringFormat("%.17g",event.netProfit) : "NA")+";"+
   (string)(int)event.closed+";"+(string)(int)event.volumeComplete+";"+
   (string)(int)event.accountingResolved+";"+(string)(int)event.finalizationWritten+";"+
   DOMQualityName(snapshot.quality)+";"+(string)snapshot.collectedMS+";"+
   (string)snapshot.sequence+";"+(string)(int)snapshot.bookValid+";"+
   (string)snapshot.bidLevels+";"+(string)snapshot.askLevels+";"+
   DOMNumber(snapshot.bookValid,snapshot.bestBid)+";"+
   DOMNumber(snapshot.bookValid,snapshot.bestAsk)+";"+
   DOMNumber(snapshot.bookValid,snapshot.spread)+";"+
   DOMNumber(snapshot.bookValid,snapshot.bidVolume1)+";"+
   DOMNumber(snapshot.bookValid,snapshot.askVolume1)+";"+
   DOMNumber(snapshot.i5Available,snapshot.bidVolume5)+";"+
   DOMNumber(snapshot.i5Available,snapshot.askVolume5)+";"+
   DOMNumber(snapshot.i5Available,snapshot.i5)+";"+
   DOMNumber(snapshot.micropriceAvailable,snapshot.microprice)+";"+
   DOMNumber(snapshot.micropriceAvailable,snapshot.micropriceMinusMid)+";"+
   DOMNumber(snapshot.bookValid,snapshot.marketBuyVolume)+";"+
   DOMNumber(snapshot.bookValid,snapshot.marketSellVolume)+";"+
   (string)snapshot.invalidRecords+";"+(string)snapshot.zeroVolumeRecords+";"+
   (string)snapshot.volumeFallbackRecords;
 for(int i=0;i<5;i++)
 {
   bool bid=snapshot.bookValid && i<snapshot.bidLevels;
  bool ask=snapshot.bookValid && i<snapshot.askLevels;
 row+=";"+DOMNumber(bid,snapshot.bidDepthPrice[i])+";"+
  DOMNumber(bid,snapshot.bidDepthVolume[i])+";"+
  DOMNumber(ask,snapshot.askDepthPrice[i])+";"+
  DOMNumber(ask,snapshot.askDepthVolume[i]);
}
return row+";"+(event.apiCalled ? (string)event.apiDurationUS : "NA")+";"+
  (event.aggregationDone ? (string)event.aggregationUS : "NA")+";"+
  (event.apiCalled ? (string)event.apiError : "NA")+";"+
  (string)event.latencyKind+";"+(string)event.samples+";"+
  (string)(int)MathMin((ulong)DOM_LATENCY_WINDOW,event.samples)+";"+
 (event.percentilesAvailable ? (string)event.p50 : "NA")+";"+
 (event.percentilesAvailable ? (string)event.p95 : "NA")+";"+
 (event.percentilesAvailable ? (string)event.p99 : "NA")+";"+

(string)event.maximum+";"+(string)TerminalInfoInteger(TERMINAL_MEMORY_USED)+";"+
   (string)gDOMDroppedEvents+";"+(string)gDOMSamplingGaps+";"+
   (string)gDOMApiFailures+";"+(string)gDOMTelemetryErrors+";"+
   (string)gDOMOversizedBooks+";"+(string)gDOMLastApiError+"\r\n";
}

void DOMContainment(const bool slow,const ulong nowMS,const bool disk=false)
{
  if(!slow)
  {
     if(disk) gDOMSlowWriteRun=0; else gDOMSlowRun=0;
     return;
  }
  if(disk) gDOMSlowWriteRun++; else gDOMSlowRun++;
  int count=disk ? gDOMSlowWriteRun : gDOMSlowRun;
  if(count<3) return;
  if(disk)
  {
     gDOMSlowWriteRun=0;
     DOMDisableTelemetry("three slow writes; only telemetry stopped");
     return;
  }
  gDOMSlowRun=0; gDOMContainmentEvents++; gDOMSamplingGaps++;
  if(gDOMContainmentEvents>=3) gDOMCollectionEnabled=false;
  else gDOMSuspendUntilMS=nowMS+(gDOMContainmentEvents==1 ? 5000 : 30000);
  Print("[SCALPER_DOM][COLLECTION_CONTAINMENT] event=",gDOMContainmentEvents,
        " collection=",gDOMCollectionEnabled,
        "; synchronous calls are measured after return, not preempted.");
}

void DOMFlushTelemetry(const ulong nowMS)
{
if(!Inp_DOM_Enable || !gDOMTelemetryEnabled || gDOMEventCount==0) return;
if(gDOMEventCount<8 && nowMS-gDOMLastFlushMS<5000) return;
ulong begin=GetMicrosecondCount();
ResetLastError();
int handle=FileOpen(gDOMTelemetryPath,
   FILE_READ|FILE_WRITE|FILE_BIN|FILE_SHARE_READ);
if(handle==INVALID_HANDLE)
{ gDOMTelemetryErrors++; DOMDisableTelemetry("open failure"); return; }
ResetLastError();
ulong existing=FileSize(handle);
if(GetLastError()!=0 || existing!=gDOMTelemetryBytes || !FileSeek(handle,0,SEEK_END))
  {
      FileClose(handle); gDOMTelemetryErrors++;
      DOMDisableTelemetry("unverified or externally changed size"); return;
  }
  int batch=0; bool failed=false;
  while(batch<16 && gDOMEventCount>0)
  {
     string line=(existing==0 ? DOMTelemetryHeader() : "");
     line+=DOMTelemetryRow(gDOMEvents[gDOMEventHead]);
     if(StringLen(line)>8192)
     { DOMDisableTelemetry("bounded line limit"); break; }
     uchar encoded[];
     int count=StringToCharArray(line,encoded,0,WHOLE_ARRAY,CP_UTF8);
     int bytes=count-1;
     if(count<=1 || ArraySize(encoded)!=count || encoded[count-1]!=0 ||
        (ulong)bytes>(ulong)DOM_TELEMETRY_DAY_BYTES-gDOMTelemetryBytes)
     { ArrayFree(encoded); DOMDisableTelemetry("daily cap or encoding failure"); break; }
     ResetLastError();
     uint written=FileWriteArray(handle,encoded,0,bytes);
     int writeError=GetLastError();
     ArrayFree(encoded);
     ResetLastError();
     ulong after=FileSize(handle);
     if(written!=(uint)bytes || writeError!=0 || GetLastError()!=0 ||
        after<existing || after-existing!=(ulong)bytes)
     { failed=true; break; }
     gDOMTelemetryBytes=after; existing=after;
     gDOMEventHead=(gDOMEventHead+1)%DOM_EVENT_CAPACITY;
     gDOMEventCount--; batch++;
  }
  ResetLastError(); FileFlush(handle);
  if(GetLastError()!=0) failed=true;
  ResetLastError(); FileClose(handle);
  if(GetLastError()!=0) failed=true;
  gDOMLastFlushMS=nowMS;
  ulong elapsed=GetMicrosecondCount()-begin;
  DOMLatency(DOM_LAT_WRITE,elapsed);
    if(failed)
    { gDOMTelemetryErrors++; DOMDisableTelemetry("partial or failed write; inspect CSV"); }
    DOMContainment(elapsed>5000,GetTickCount64(),true);
}

void DOMQueueLatencySummary(const ulong nowMS)
{
  for(int kind=0;kind<4;kind++)
  {
    DOMTelemetryEvent event;
    ZeroMemory(event);
    event.kind=4; event.localMS=nowMS; event.latencyKind=kind;
    event.samples=gDOMLatencySeen[kind];
event.maximum=gDOMLatencyMaximum[kind];
    int count=(int)MathMin((ulong)DOM_LATENCY_WINDOW,event.samples);
    if(count>=100)
    {
       ulong sorted[DOM_LATENCY_WINDOW];
       for(int i=0;i<count;i++) sorted[i]=gDOMLatencySamples[kind][i];
       for(int i=1;i<count;i++)
       {
         ulong value=sorted[i]; int j=i-1;
         while(j>=0 && sorted[j]>value) { sorted[j+1]=sorted[j]; j--; }
         sorted[j+1]=value;
       }
       event.p50=sorted[(int)MathCeil(count*0.50)-1];
       event.p95=sorted[(int)MathCeil(count*0.95)-1];
       event.p99=sorted[(int)MathCeil(count*0.99)-1];
       event.percentilesAvailable=true;
    }
    DOMPushEvent(event);
  }
}

void DOMRuntimeInit()
{
  if(!Inp_DOM_Enable) return;
  DOMResetCache();
  // Conservative allowance includes bounded line/UTF-8/hash temporaries and
  // fixed scalar/string metadata. MarketBookGet's API-returned array cannot
  // be hard-capped by its public signature; it is separately released below.
  long ownBytes=(long)sizeof(gDOMEvents)+(long)sizeof(gDOMCurrent)+
     (long)sizeof(gDOMBidPrices)+(long)sizeof(gDOMBidVolumes)+
     (long)sizeof(gDOMAskPrices)+(long)sizeof(gDOMAskVolumes)+
     (long)sizeof(gDOMLatencySamples)+65536;
  if(ownBytes>1048576 || !DOMTelemetryNamespace())
  {
     Print("[SCALPER_DOM][UNAVAILABLE] invalid telemetry identity or buffer bound; base unchanged.");
     return; // Never fail the EA initialization because of DOM.
    }
    gDOMBookSymbol=Symbol(); gDOMRuntimeReady=true;
    gDOMLastFlushMS=GetTickCount64(); gDOMLastSummaryMS=gDOMLastFlushMS;
    DOMOpenTelemetryDay();
    ResetLastError();
    gDOMSubscriptionOwned=MarketBookAdd(gDOMBookSymbol);
    gDOMLastApiError=GetLastError();
    gDOMCollectionEnabled=gDOMSubscriptionOwned;
    if(!gDOMSubscriptionOwned)
       Print("[SCALPER_DOM][SUBSCRIPTION_FAILED] error=",gDOMLastApiError,
           "; no repeated subscription attempts; base unchanged.");
      Print("[SCALPER_DOM][OBSERVATION_ONLY] own_buffer_bound=",ownBytes,
         " max_hz=1; local capture is not exchange freshness.");
}

void DOMRuntimeTimer()
{
  if(!Inp_DOM_Enable || !gDOMRuntimeReady) return;
  ulong beginRuntime=GetMicrosecondCount();
  ulong nowMS=GetTickCount64();
  if(DOMDayString()!=gDOMTelemetryDay)
  {
     gDOMDroppedEvents+=(ulong)gDOMEventCount;
     gDOMEventHead=0; gDOMEventCount=0;
     DOMOpenTelemetryDay(); // At most one storage re-open attempt per new day.
  }
  if(gDOMLastCollectMS==0 || nowMS-gDOMLastCollectMS>=1000)
  {
     if(gDOMLastCollectMS>0 && nowMS-gDOMLastCollectMS>1500)
gDOMSamplingGaps++;
     gDOMLastCollectMS=nowMS;
     DOMSnapshot snapshot;
     DOMClearSnapshot(snapshot); snapshot.collectedMS=nowMS;
     bool apiCalled=false, aggregationDone=false;
     ulong apiDurationUS=0, aggregationUS=0;
     int capturedApiError=0;
     if(!gDOMSubscriptionOwned) snapshot.quality=DOM_QUALITY_NO_SUBSCRIPTION;
     else if(!gDOMCollectionEnabled || nowMS<gDOMSuspendUntilMS)
        snapshot.quality=DOM_QUALITY_NONE;
     else if(Symbol()!=gDOMBookSymbol)
snapshot.quality=DOM_QUALITY_SYMBOL_MISMATCH;
     else if(!TerminalInfoInteger(TERMINAL_CONNECTED))
snapshot.quality=DOM_QUALITY_DISCONNECTED;
     else
     {
        MqlBookInfo raw[];
        ResetLastError();
        ulong begin=GetMicrosecondCount();
        bool received=MarketBookGet(gDOMBookSymbol,raw);
        ulong apiElapsed=GetMicrosecondCount()-begin;
        int apiError=GetLastError();
        apiCalled=true; apiDurationUS=apiElapsed; capturedApiError=apiError;
        DOMLatency(DOM_LAT_API,apiElapsed); gDOMLastApiError=apiError;
        snapshot.collectedMS=GetTickCount64(); // Local receipt, NOT B3 time.
        ulong aggregateElapsed=0;
        if(!received || apiError!=0)
        {
         snapshot.quality=DOM_QUALITY_API_FAILURE;
         gDOMApiFailures++; gDOMApiFailureRun++;
         if(gDOMApiFailureRun>=3)
         {
            gDOMCollectionEnabled=false;
            Print("[SCALPER_DOM][COLLECTION_SUSPENDED] three API failures; base unchanged.");
         }
       }
       else
       {
         gDOMApiFailureRun=0; begin=GetMicrosecondCount();
         DOMBuildSnapshot(raw,ArraySize(raw),snapshot.collectedMS,snapshot);
         aggregateElapsed=GetMicrosecondCount()-begin;
         aggregationDone=true; aggregationUS=aggregateElapsed;
         DOMLatency(DOM_LAT_AGG,aggregateElapsed);
         if(snapshot.quality==DOM_QUALITY_TOO_LARGE) gDOMOversizedBooks++;
       }
       ArrayFree(raw);
       DOMContainment(apiElapsed>2000 || aggregateElapsed>2000,GetTickCount64());
     }
     DOMStoreSnapshot(snapshot);
     DOMTelemetryEvent event;
     ZeroMemory(event);
     event.kind=1; event.localMS=snapshot.collectedMS;
     DOMCopyCorrelation(event);
     event.apiCalled=apiCalled; event.apiDurationUS=apiDurationUS;
     event.aggregationDone=aggregationDone; event.aggregationUS=aggregationUS;
     event.apiError=capturedApiError;
     DOMPushEvent(event);
  }
  if(nowMS-gDOMLastSummaryMS>=60000)
  { DOMQueueLatencySummary(nowMS); gDOMLastSummaryMS=nowMS; }
  DOMFlushTelemetry(nowMS);
  DOMLatency(DOM_LAT_RUNTIME,GetMicrosecondCount()-beginRuntime);
}
void DOMRuntimeDeinit()
{
    if(!Inp_DOM_Enable) return;
    if(gDOMRuntimeReady)
    {
       gDOMLastFlushMS=0;
       DOMFlushTelemetry(GetTickCount64()); // One bounded batch, never a wait loop.
    }
    if(gDOMSubscriptionOwned)
    {
       ResetLastError();
       if(!MarketBookRelease(gDOMBookSymbol))
          Print("[SCALPER_DOM][RELEASE_FAILED] error=",GetLastError());
       gDOMSubscriptionOwned=false;
      }
      if(gDOMEventCount>0) gDOMDroppedEvents+=(ulong)gDOMEventCount;
      Print("[SCALPER_DOM][SUMMARY] dropped=",gDOMDroppedEvents,
          " gaps=",gDOMSamplingGaps," api_failures=",gDOMApiFailures,
          " io_errors=",gDOMTelemetryErrors," oversized=",gDOMOversizedBooks);
      gDOMEventHead=0; gDOMEventCount=0;
      gDOMRuntimeReady=false; gDOMCollectionEnabled=false;
}

// Optional observer runs only AFTER the original financial timer body.
void OnTimer()
{
   ulong began=GetMicrosecondCount();
   DOMBaseOnTimer();
   BookDecisionPump(); // Financial timer/protection always runs first.
   BookDiagTimer();
   DOMGateSubscriptionTimer(); // Only after the original financial timer body.
   if(Inp_DOM_Enable) DOMRuntimeTimer();
   if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseTimer();
   BookPerfTimer(began);
}

// BEGIN EXPERIMENTAL DOM CONFLUENCE MODULE
// Experimental 1.124 addition. Embedded by build_candidate.py into the full EA.
// No cached DOM approval, no alternate order path, no financial state persistence.
enum ENUM_BOOK_CONFLUENCE
{
   BOOK_CONFIRM_BUY=0, BOOK_CONFIRM_SELL, BOOK_NEUTRAL_WAIT,
   BOOK_OPPOSITE_BUY, BOOK_OPPOSITE_SELL, BOOK_UNAVAILABLE,
   BOOK_REVERSAL_WATCH, BOOK_ENTRY_RELEASED, BOOK_ENTRY_BLOCKED
};
enum ENUM_SEND_OUTCOME
{
   SEND_FINAL_FAILURE=0, SEND_ACCEPTED, SEND_WAIT_ARMED,
   SEND_CANCEL_REEVAL, SEND_TRADE_OR_POSITION,
   SEND_FINANCIAL_UNRESOLVED, SEND_ORIGINAL_CANCEL
};

// Experimental local budgets, not exchange freshness guarantees or strategy inputs.
// Reject rather than trade after an unbounded read/revalidation/persistence delay.
#define BOOK_GATE_API_BUDGET_US 10000
#define BOOK_GATE_AGG_BUDGET_US 5000
#define BOOK_GATE_DECISION_BUDGET_US 50000
#define BOOK_GATE_LOGS_PER_DAY 512

struct BookGateDecision
{
   DOMSnapshot snapshot;
   ENUM_BOOK_CONFLUENCE state;
   double pctBid, pctAsk;
   ulong beginUS, apiUS, aggregationUS;
   datetime signalClock, contextClock;
   int apiError;
   string reason;
};

bool gBookGateSubscriptionOwned=false;
string gBookGateSymbol="";
bool gBookGateWaiting=false, gBookGateOppositeWatch=false;
bool gBookGateHadOpposite=false;
ulong gBookGateObservationMS=0;
ulong gBookGateNextSubscriptionMS=0, gBookGateRetryDelayMS=5000;
ulong gBookGateSubscriptionAttempts=0, gBookGateSubscriptionRecoveries=0;
ulong gBookGateApiBudgetBlocks=0, gBookGateAggregationBudgetBlocks=0;
ulong gBookGateDecisionBudgetBlocks=0, gBookGateQuoteDeferrals=0;
ulong gBookGatePrepareMaxUS=0, gBookGateJournalMaxUS=0;
double gBookGatePrepareSumUS=0, gBookGateJournalSumUS=0;
ulong gBookGatePrepareCalls=0, gBookGateJournalCalls=0;
datetime gBookGateArmedAt=0, gBookGateRegionEnd=0;
int gBookGateDirection=0, gBookGateLastState=-1;
double gBookGateRegionHigh=0, gBookGateRegionLow=0;
ulong gBookGateLastLogMS=0;
int gBookGateLogDay=0, gBookGateDayLogs=0;
ulong gBookGateReads=0, gBookGateBlocks=0, gBookGateReleased=0;
ulong gBookGateUnavailable=0, gBookGateLogsDropped=0;
ulong gBookGateApiMaxUS=0, gBookGateAggregationMaxUS=0;
ulong gBookGateDecisionMaxUS=0, gBookGateDispatchMaxUS=0;
ulong gBookGateRevalidationMaxUS=0, gBookGateRevalidations=0;
double gBookGateRevalidationSumUS=0;
ulong gBookGateLateDeferrals=0;
double gBookGateApiSumUS=0, gBookGateAggregationSumUS=0;
ulong gBookGateApiCalls=0, gBookGateAggregations=0;

bool DOMGateValidateInputs()
{
  if(!DOMFinite(Inp_DOM_MinDominancePct) ||
     Inp_DOM_MinDominancePct<55.0 || Inp_DOM_MinDominancePct>100.0)
  {
     Print("[BOOK_GATE][INVALID_INPUT] Inp_DOM_MinDominancePct must be finite and in [55,100]; no correction.");
   return false;
  }
  if(Inp_DOM_MinDominancePct==100.0)
     Print("[BOOK_GATE][INPUT_WARNING] 100% is mathematically unattainable with positive volume on both sides; floating point percentages do not prove zero opposing volume.");
  return true;
}

// Pure classification: I5 and microprice are descriptive, never extra trade filters.
ENUM_BOOK_CONFLUENCE DOMGateClassify(const DOMSnapshot &s,const int
direction,
                   const double threshold,double &pctBid,double &pctAsk)
{
   pctBid=0.0; pctAsk=0.0;
   if(!DOMFinite(threshold) || threshold<55.0 || threshold>100.0 ||
      (direction!=1 && direction!=-1) || !s.bookValid ||
      s.quality!=DOM_QUALITY_OK || s.bidLevels<5 || s.askLevels<5 ||
      !DOMFinite(s.bidVolume5) || !DOMFinite(s.askVolume5) ||
      s.bidVolume5<=0.0 || s.askVolume5<=0.0)
      return BOOK_UNAVAILABLE;
   double total=s.bidVolume5+s.askVolume5;
   if(!DOMFinite(total) || total<=0.0) return BOOK_UNAVAILABLE;
   pctBid=100.0*(s.bidVolume5/total);
   pctAsk=100.0*(s.askVolume5/total);
   if(!DOMFinite(pctBid) || !DOMFinite(pctAsk)) return BOOK_UNAVAILABLE;
   // Positive sizes on both sides cannot yield a mathematical 100% dominance.
   // Avoid accidental release from floating point rounding at the endpoint.
   if(threshold==100.0) return BOOK_NEUTRAL_WAIT;
   if(direction==1)
   {
      if(pctBid>=threshold) return BOOK_CONFIRM_BUY;
      if(pctAsk>=threshold) return BOOK_OPPOSITE_SELL;
   }
   else
   {
      if(pctAsk>=threshold) return BOOK_CONFIRM_SELL;
      if(pctBid>=threshold) return BOOK_OPPOSITE_BUY;
   }
   return BOOK_NEUTRAL_WAIT;
}

string DOMGateStateName(const ENUM_BOOK_CONFLUENCE state)
{
  switch(state)
  {
    case BOOK_CONFIRM_BUY: return "BOOK_CONFIRM_BUY";
    case BOOK_CONFIRM_SELL: return "BOOK_CONFIRM_SELL";
     case BOOK_NEUTRAL_WAIT: return "BOOK_NEUTRAL_WAIT";
     case BOOK_OPPOSITE_BUY: return "BOOK_OPPOSITE_BUY";
     case BOOK_OPPOSITE_SELL: return "BOOK_OPPOSITE_SELL";
     case BOOK_UNAVAILABLE: return "BOOK_UNAVAILABLE";
     case BOOK_REVERSAL_WATCH: return "BOOK_REVERSAL_WATCH";
     case BOOK_ENTRY_RELEASED: return "BOOK_ENTRY_RELEASED";
     case BOOK_ENTRY_BLOCKED: return "BOOK_ENTRY_BLOCKED";
    }
    return "BOOK_UNAVAILABLE";
}

void DOMGateSyncIdentity()
{
  if(gBookGateArmedAt==armed.armedAt && gBookGateDirection==armed.dir &&
     gBookGateRegionEnd==armed.regionEndTime &&
     gBookGateRegionHigh==armed.regionHigh &&
gBookGateRegionLow==armed.regionLow)
     return;
  gBookGateArmedAt=armed.armedAt; gBookGateDirection=armed.dir;
  gBookGateRegionEnd=armed.regionEndTime;
  gBookGateRegionHigh=armed.regionHigh; gBookGateRegionLow=armed.regionLow;
  gBookGateWaiting=false; gBookGateOppositeWatch=false;
  gBookGateHadOpposite=false; gBookGateObservationMS=0;
  gBookGateLastState=-1; gBookGateLastLogMS=0;
}

bool DOMGateLogAllowed()
{
  MqlDateTime dt; TimeToStruct(TimeTradeServer(),dt);
  int day=dt.year*1000+dt.day_of_year;
  if(day!=gBookGateLogDay) { gBookGateLogDay=day; gBookGateDayLogs=0; }
  if(gBookGateDayLogs>=BOOK_GATE_LOGS_PER_DAY)
  { gBookGateLogsDropped++; return false; }
  gBookGateDayLogs++;
  return true;
}

void DOMGateReport(const BookGateDecision &decision,const bool confirmed)
{
  BookDiagBook(decision,confirmed);
  DOMGateSyncIdentity();
  bool wasWaiting=gBookGateWaiting;
  if(!confirmed)
  {
     gBookGateBlocks++; gBookGateWaiting=true;
     if(decision.state==BOOK_UNAVAILABLE) gBookGateUnavailable++;
  }
  bool opposite=(decision.state==BOOK_OPPOSITE_BUY ||
decision.state==BOOK_OPPOSITE_SELL);
 // This flag describes this read only; historical opposition is separate.
 gBookGateOppositeWatch=opposite;
 // A local intent/price rejection is not a new depth observation.

gBookGateObservationMS=(decision.state==BOOK_ENTRY_BLOCKED)?0:GetTickCount64();
 if(opposite) gBookGateHadOpposite=true;
 ulong nowMS=GetTickCount64();
 // First confirmation/block plus at most one changed state per second per signal.
 bool emit=(gBookGateLastState<0 || (!confirmed && !wasWaiting) ||
        (gBookGateLastState!=(int)decision.state &&
nowMS-gBookGateLastLogMS>=1000));
 if(emit && DOMGateLogAllowed())
 {
  PrintFormat("[BOOK_GATE][%s] state=%s attention=%s symbol=%s dir=%d armedAt=%I64d bidPct=%.8f askPct=%.8f min=%.2f quality=%s reason=%s apiError=%d apiUS=%I64u aggregationUS=%I64u; local receipt is not exchange age",

confirmed?"BOOK_CONFIRM":"BOOK_ENTRY_BLOCKED",DOMGateStateName(decision.
state),
     opposite?"BOOK_REVERSAL_WATCH":"NONE",gBookGateSymbol,armed.dir,
     (long)armed.armedAt,decision.pctBid,decision.pctAsk,Inp_DOM_MinDominancePct,
     DOMQualityName(decision.snapshot.quality),decision.reason,decision.apiError,
     decision.apiUS,decision.aggregationUS);
    gBookGateLastState=(int)decision.state; gBookGateLastLogMS=nowMS;
  }
  else if(!emit) gBookGateLogsDropped++;
}

ENUM_SEND_OUTCOME DOMGateDefer(const BookGateDecision &decision,const string reason)
{
  if(HasExecutionInFlight() || gEntryJournalInvalid || gExitJournalInvalid)
     return SEND_FINANCIAL_UNRESOLVED;
  if(!armed.active) return SEND_ORIGINAL_CANCEL;
  ArmedSignal original=armed;
  double effort,trigger,last;
  MqlTick current;
  ENUM_APS readiness=CheckArmedEntryReady(effort,trigger,last,current);
  if(readiness==APS_ENDED_REEVAL_ALLOWED) return SEND_CANCEL_REEVAL;
  if(readiness==APS_TRADE_OR_POSITION) return SEND_TRADE_OR_POSITION;
  if(readiness==APS_ENDED_FAIL_CLOSED || !armed.active) return SEND_ORIGINAL_CANCEL;
  if(readiness==APS_ENTRY_READY)
  {
     // A sampling/DOM veto must not hide a late execution failure on this
     // same sample. Stage2's own STILL result retains its original meaning.
     double price=(original.dir==1)?current.ask:current.bid;
     if(!DOMGateFinalTickReady(current,original,trigger,price,readiness) &&
        readiness==APS_ENDED_FAIL_CLOSED) return SEND_ORIGINAL_CANCEL;
     double sl=NormEntrySL(original.dir,price-original.dir*original.activeSL_Pts);
     double tp=NormEntryTP(original.dir,price+original.dir*original.activeTP_Pts);
     if(BookRiskEnabled() && !BookRiskResolveTerms(original.dir,price,original.mode,
         original.activeSL_Pts,original.activeTP_Pts,false,sl,tp))
     { ResetArmedSignal(); return SEND_ORIGINAL_CANCEL; }
     if(BookRiskEnabled() && !BookRiskResolveTerms(original.dir,price,original.mode,
         original.activeSL_Pts,original.activeTP_Pts,false,sl,tp))
     { ResetArmedSignal(); return SEND_ORIGINAL_CANCEL; }
     double lots=ComputeLotsForEntry(original.dir,price,sl);
     if(!DOMGateTermsCurrent(current,original,price,lots,sl,tp,readiness) &&
        readiness==APS_ENDED_FAIL_CLOSED) return SEND_ORIGINAL_CANCEL;
  }
  BookGateDecision rejected=decision;
  rejected.state=BOOK_ENTRY_BLOCKED; rejected.reason=reason+"; source="+decision.reason;
  gBookGateLateDeferrals++;
  ulong elapsed=GetMicrosecondCount()-decision.beginUS;
  if(elapsed>gBookGateDecisionMaxUS) gBookGateDecisionMaxUS=elapsed;
  DOMGateReport(rejected,false);
  return SEND_WAIT_ARMED;
}

void DOMGateSubscriptionTimer()
{
  if(!Inp_DOM_TradeGateEnable || gBookGateSubscriptionOwned) return;
  ulong nowMS=GetTickCount64();
  if(nowMS<gBookGateNextSubscriptionMS) return;
  bool retry=(gBookGateSubscriptionAttempts>0);
  // Frequency control is operational, never an entry or signal parameter.
  gBookGateNextSubscriptionMS=nowMS+gBookGateRetryDelayMS;
  if(!TerminalInfoInteger(TERMINAL_CONNECTED))
  {
     gBookGateOppositeWatch=false; gBookGateObservationMS=0;
     Print("[BOOK_GATE][BOOK_SUBSCRIPTION_UNAVAILABLE] terminal disconnected; no approval retained");
     return;
  }
  if(retry) PrintFormat("[BOOK_GATE][BOOK_SUBSCRIPTION_RETRY] attempt=%I64u symbol=%s",
                  gBookGateSubscriptionAttempts+1,gBookGateSymbol);
  ResetLastError();
  bool added=MarketBookAdd(gBookGateSymbol);
  int error=GetLastError();
  gBookGateSubscriptionAttempts++;
  if(added)
  {
     // Own exactly one successful reference; never re-add an owned reference.
     gBookGateSubscriptionOwned=true;
     gBookGateRetryDelayMS=5000;
     if(retry)
     {
        gBookGateSubscriptionRecoveries++;
        PrintFormat("[BOOK_GATE][BOOK_SUBSCRIPTION_RECOVERED] symbol=%s; fresh read and original ARMED required",
                gBookGateSymbol);
     }
     return;
  }
  gBookGateOppositeWatch=false; gBookGateObservationMS=0;
  PrintFormat("[BOOK_GATE][BOOK_SUBSCRIPTION_FAILED] symbol=%s error=%d attempt=%I64u",
            gBookGateSymbol,error,gBookGateSubscriptionAttempts);
  PrintFormat("[BOOK_GATE][BOOK_SUBSCRIPTION_UNAVAILABLE] advertised_depth=%I64d; provider support must be verified; entries stay blocked",
            SymbolInfoInteger(gBookGateSymbol,SYMBOL_TICKS_BOOKDEPTH));
  // Backoff 5,10,20,40,60 seconds; no Sleep, no tick-driven subscription calls.

gBookGateRetryDelayMS=(ulong)MathMin((double)60000,(double)gBookGateRetryDelayMS*2.0);
}

void DOMGateInit()
{
  gBookGateSubscriptionOwned=false; gBookGateSymbol="";
  gBookGateWaiting=false; gBookGateOppositeWatch=false; gBookGateHadOpposite=false;
  gBookGateObservationMS=0; gBookGateArmedAt=0; gBookGateDirection=0;
  gBookGateRegionEnd=0; gBookGateRegionHigh=0; gBookGateRegionLow=0;
  gBookGateLastState=-1; gBookGateNextSubscriptionMS=0;
gBookGateRetryDelayMS=5000;
  gBookGateSubscriptionAttempts=0; gBookGateSubscriptionRecoveries=0;
  if(!Inp_DOM_TradeGateEnable) return;
  gBookGateSymbol=Symbol();
  DOMGateSubscriptionTimer(); // One initial attempt; retries exclusively on timer.
  Print("[BOOK_GATE][INIT] RC2 experimental; 10/5/50ms local budgets UNCALIBRATED;no exchange-age guarantee");
}

bool DOMGateRead(const int direction,BookGateDecision &decision)
{
  BookDiagBookReadBegin();
  ZeroMemory(decision);
  decision.beginUS=GetMicrosecondCount();
  decision.signalClock=iTime(Symbol(),Inp_SignalTF,0);
  decision.contextClock=iTime(Symbol(),Inp_ContextTF,0);
  decision.state=BOOK_UNAVAILABLE;
  DOMClearSnapshot(decision.snapshot);
  gBookGateReads++;
  if(!gBookGateSubscriptionOwned)
     decision.snapshot.quality=DOM_QUALITY_NO_SUBSCRIPTION;
  else if(Symbol()!=gBookGateSymbol ||
       SymbolInfoInteger(gBookGateSymbol,SYMBOL_CUSTOM)!=0 ||

SymbolInfoInteger(gBookGateSymbol,SYMBOL_EXPIRATION_TIME)<=TimeTradeServer())
  decision.snapshot.quality=DOM_QUALITY_SYMBOL_MISMATCH;
else if(!TerminalInfoInteger(TERMINAL_CONNECTED))
  decision.snapshot.quality=DOM_QUALITY_DISCONNECTED;
else
{
  MqlBookInfo raw[];
  ResetLastError();
  ulong begin=GetMicrosecondCount();
  BookDiagBookAttempt();
  bool received=MarketBookGet(gBookGateSymbol,raw);
  decision.apiUS=GetMicrosecondCount()-begin;
  decision.apiError=GetLastError();
  gBookGateApiCalls++; gBookGateApiSumUS+=(double)decision.apiUS;
  if(decision.apiUS>gBookGateApiMaxUS) gBookGateApiMaxUS=decision.apiUS;
  if(!received || decision.apiError!=0)
     decision.snapshot.quality=DOM_QUALITY_API_FAILURE;
  else
  {
     begin=GetMicrosecondCount();
     DOMBuildSnapshot(raw,ArraySize(raw),GetTickCount64(),decision.snapshot);
     // Structural price-grid check, not an additional strategic indicator.
     if(decision.snapshot.quality==DOM_QUALITY_OK)
     {
     for(int n=0;n<ArraySize(raw);n++)
       if(raw[n].type==BOOK_TYPE_BUY || raw[n].type==BOOK_TYPE_SELL)
       {
          if(!DOMFinite(gTickSize) || gTickSize<=0.0)
          { decision.snapshot.quality=DOM_QUALITY_INVALID; break; }
          double tickUnits=raw[n].price/gTickSize;
          // An infinite ratio would otherwise make Abs(inf-inf) NaN,
          // whose comparison is false and would fail open on the grid.
          if(!DOMFinite(tickUnits) ||
           MathAbs(tickUnits-MathRound(tickUnits))>0.0000001)
         { decision.snapshot.quality=DOM_QUALITY_INVALID; break; }
     }
      }
      decision.aggregationUS=GetMicrosecondCount()-begin;
      gBookGateAggregations++;
gBookGateAggregationSumUS+=(double)decision.aggregationUS;
      if(decision.aggregationUS>gBookGateAggregationMaxUS)
         gBookGateAggregationMaxUS=decision.aggregationUS;
   }
   ArrayFree(raw);
   if(decision.apiUS>BOOK_GATE_API_BUDGET_US) gBookGateApiBudgetBlocks++;
   if(decision.aggregationUS>BOOK_GATE_AGG_BUDGET_US)
gBookGateAggregationBudgetBlocks++;
   if(decision.apiUS>BOOK_GATE_API_BUDGET_US ||
      decision.aggregationUS>BOOK_GATE_AGG_BUDGET_US)
   {
      decision.state=BOOK_UNAVAILABLE;
      decision.reason="LOCAL_READ_OR_AGGREGATION_BUDGET_EXCEEDED";
      DOMGateReport(decision,false);
      return false;
   }
}
if(decision.reason=="") decision.reason=DOMQualityName(decision.snapshot.quality);

decision.state=DOMGateClassify(decision.snapshot,direction,Inp_DOM_MinDominancePct,
               decision.pctBid,decision.pctAsk);
  bool confirmed=(direction==1 && decision.state==BOOK_CONFIRM_BUY) ||
        (direction==-1 && decision.state==BOOK_CONFIRM_SELL);
  DOMGateReport(decision,confirmed);
  return confirmed;
}


bool DOMGateIdentityCurrent(const ArmedSignal &original)
{
  return armed.active && original.active && armed.dir==original.dir &&
    armed.armedAt==original.armedAt && armed.regionEndTime==original.regionEndTime
&&
    armed.regionHigh==original.regionHigh && armed.regionLow==original.regionLow &&
    armed.route==original.route && armed.mode==original.mode &&
   armed.activeSL_Pts==original.activeSL_Pts &&
armed.activeTP_Pts==original.activeTP_Pts &&
   armed.breakoutEffortMin==original.breakoutEffortMin;
}

// These helpers are used only in the current synchronous SendOrder call.
// No local no-dispatch witness is restored from a journal or reused after return.
bool DOMGateIntentMatches(const PendingExecContext &expected)
{
  if(!gPendingExec.active || !expected.active || gPendingExec.accepted ||
     gPendingExec.orderTicket!=0 || gPendingExec.resultDeal!=0 ||
gPendingExec.requestID!=0 ||
     gPendingExec.dispatchPhase!=expected.dispatchPhase ||
     gPendingExec.direction!=expected.direction || gPendingExec.route!=expected.route ||
     gPendingExec.mode!=expected.mode ||
gPendingExec.requestPrice!=expected.requestPrice ||
     gPendingExec.requestedLots!=expected.requestedLots ||
gPendingExec.slPrice!=expected.slPrice ||
     gPendingExec.tpPrice!=expected.tpPrice || gPendingExec.sentAt!=expected.sentAt ||
     gPendingExec.requestPriceAvailable!=expected.requestPriceAvailable ||
     gPendingExec.breakoutPrice!=expected.breakoutPrice ||
     gPendingExec.breakoutPriceAvailable!=expected.breakoutPriceAvailable) return false;
  return true;
}

bool DOMGateOwnUndispatchedIntent(const PendingExecContext &expected)
{
  if(!DOMGateIntentMatches(expected)) return false;
  // All original HasExecutionInFlight reasons, excluding only this proven intent.
  if(gOrderObligationScanUnresolved) return false;
  for(int i=0;i<ArraySize(gUnresolvedOrders);i++)
     if(gUnresolvedOrders[i].active && (gUnresolvedOrders[i].classificationPending ||
        gUnresolvedOrders[i].persistencePending)) return false;
  if(gRequestJournalUnresolved || gEntryJournalCleanupPending ||
     gExitJournalCleanupPending || gRequestJournalWritePending ||
     gEntryJournalInvalid || gExitJournalInvalid ||
     gPendingExit.active || gPendingOrderClassificationUnresolved ||
HasOwnPendingOrder()) return false;
  for(int i=0;i<gTradeRecordCount;i++)
     if(gTradeRecords[i].positionID>0 && !gTradeRecords[i].closed &&
        gTradeRecords[i].totalVolumeIn>0) return false;
  return true;
}

// Validate predicates, never equality of event timestamps or traded volume.
// Full inherited Stage2 runs on every decision before this final sample.
bool DOMGateFinalTickReady(const MqlTick &current,const ArmedSignal &original,
                           const double trigger,const double price,ENUM_APS &readiness)
{
  double exec=(original.dir==1)?current.ask:current.bid;
  // These are terminal failures in the original SendOrder, even if DOM vetoes.
  if(!DOMFinite(current.bid) || !DOMFinite(current.ask) || current.bid<=0 ||
     current.ask<=0 || current.ask<current.bid || current.ask-current.bid>gSpreadMaxPts)
  { ResetArmedSignal(); readiness=APS_ENDED_FAIL_CLOSED; return false; }
  if(original.dir*(exec-trigger)<0)
  {
     WriteAuditRow("LATE_BREAKOUT_LOST",DirStr(original.dir),original.mode,exec,
                   original.posRel,original.distD1,original.effort,trigger);
     ResetArmedSignal(); readiness=APS_ENDED_FAIL_CLOSED; return false;
  }
  if(original.dir*(exec-trigger)>gMaxOvershoot)
  {
     WriteAuditRow("LATE_OVERSHOOT_BLOCK",DirStr(original.dir),original.mode,exec,
                   original.posRel,original.distD1,original.effort,trigger);
     ResetArmedSignal(); readiness=APS_ENDED_FAIL_CLOSED; return false;
  }
  // Original Stage2 can still wait for a real trade / last-price breakout.
  bool realTrade=((current.flags&TICK_FLAG_LAST)!=0) ||
                 ((current.flags&TICK_FLAG_VOLUME)!=0) ||
                 ((current.flags&TICK_FLAG_BUY)!=0) ||
                 ((current.flags&TICK_FLAG_SELL)!=0);
  if(current.time_msc<=0 || !DOMFinite(current.last) || current.last<=0 ||
     !realTrade || original.dir*(current.last-trigger)<0) return false;
  return true;
}

// Preserve the inherited terminal overshoot decision on the observed sample;
// a later retracement must not turn that original cancellation into WAIT.
bool DOMGateOriginalOvershoot(const MqlTick &current,const ArmedSignal &original,
                              const double trigger)
{
  bool realTrade=((current.flags&TICK_FLAG_LAST)!=0) ||
                 ((current.flags&TICK_FLAG_VOLUME)!=0) ||
                 ((current.flags&TICK_FLAG_BUY)!=0) ||
                 ((current.flags&TICK_FLAG_SELL)!=0);
  double exec=(original.dir==1)?current.ask:current.bid;
  if(!realTrade || current.last<=0 || exec<=0 ||
     original.dir*(current.last-trigger)<0) return false;
  return MathMax(original.dir*(current.last-trigger),
                 original.dir*(exec-trigger))>gMaxOvershoot;
}

// Invalid original sizing/stops/margin cancel. Only still-valid changed terms
// may defer an immutable intent after proven safe cleanup.
bool DOMGateTermsCurrent(const MqlTick &pricedTick,const ArmedSignal &original,
                   const double price,const double lots,const double sl,const double tp,
                   ENUM_APS &readiness)
{
  int direction=original.dir;
  double currentPrice=(direction==1)?pricedTick.ask:pricedTick.bid;
  double currentSL=NormEntrySL(direction,currentPrice-direction*original.activeSL_Pts);
  double currentTP=NormEntryTP(direction,currentPrice+direction*original.activeTP_Pts);
  if(BookRiskEnabled() && !BookRiskResolveTerms(direction,currentPrice,original.mode,
      original.activeSL_Pts,original.activeTP_Pts,false,currentSL,currentTP))
  { ResetArmedSignal(); readiness=APS_ENDED_FAIL_CLOSED; return false; }
  double currentLots=ComputeLotsForEntry(direction,currentPrice,currentSL);
  double minDist=(double)SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL)*
                 SymbolInfoDouble(Symbol(),SYMBOL_POINT);
  double closingQuote=(direction==1)?pricedTick.bid:pricedTick.ask;
  bool valid=currentSL>0 && currentTP>0 && currentLots>0 &&
       direction*(currentPrice-currentSL)>=minDist && direction*(currentTP-currentPrice)>=minDist &&
       direction*(closingQuote-currentSL)>=minDist && direction*(currentTP-closingQuote)>=minDist;
  ENUM_ORDER_TYPE type=(direction==1)?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
  double margin=0;
  if(valid) valid=OrderCalcMargin(type,Symbol(),currentLots,currentPrice,margin) &&
       MathIsValidNumber(margin) && margin>=0 && AccountInfoDouble(ACCOUNT_MARGIN_FREE)>=margin;
  if(!valid)
  { ResetArmedSignal(); readiness=APS_ENDED_FAIL_CLOSED; return false; }
  // A still-valid changed quote requires fresh terms after safe cleanup; it
  // cannot be used to conceal a terminal margin/stops/sizing rejection above.
  return price==currentPrice && sl==currentSL && tp==currentTP && lots==currentLots;
}

// Finite sampling: full inherited Stage2 -> current terms -> NEW DOM -> witness.
// Ticks need not stop arriving. There is no atomic tick/history/DOM API: VWAP and
// live-wave validity apply to the Stage2 sample, with a bounded residual window.
bool DOMGateDecisionCurrent(BookGateDecision &decision,const MqlTick &pricedTick,
                   const ArmedSignal &original,const bool prepared,
                   const PendingExecContext &expected,ENUM_APS &readiness,
                   double &effort,double &trigger,double &last,
                   const double price,const double lots,const double sl,const double tp)
{
  readiness=APS_STILL_ARMED;
  ulong windowBegin=GetMicrosecondCount();
  datetime signalClock=decision.signalClock, contextClock=decision.contextClock;
  if(!DOMGateIdentityCurrent(original))
  { decision.reason="ARMED_IDENTITY_CHANGED"; return false; }
  if(prepared && !DOMGateOwnUndispatchedIntent(expected))
  { decision.reason="FINANCIAL_GUARD_NOT_READY"; return false; }
  bool clocksCurrent=(signalClock>0 && contextClock>0 &&
     iTime(Symbol(),Inp_SignalTF,0)==signalClock &&
     iTime(Symbol(),Inp_ContextTF,0)==contextClock);
  MqlTick stageTick;
  ulong stageBegin=GetMicrosecondCount();
  if(prepared) readiness=CheckArmedMarketReady(effort,trigger,last,stageTick);
  else readiness=CheckArmedEntryReady(effort,trigger,last,stageTick);
  ulong stageUS=GetMicrosecondCount()-stageBegin;
  gBookGateRevalidations++; gBookGateRevalidationSumUS+=(double)stageUS;
  if(stageUS>gBookGateRevalidationMaxUS) gBookGateRevalidationMaxUS=stageUS;
  if(readiness!=APS_ENTRY_READY || !DOMGateIdentityCurrent(original))
  { decision.reason="ORIGINAL_STAGE2_NOT_READY"; return false; }
  if(!DOMGateFinalTickReady(stageTick,original,trigger,price,readiness))
  { gBookGateQuoteDeferrals++; decision.reason="CURRENT_EXECUTION_TERMS_CHANGED"; return false; }
  if(!SpreadOk() || HasOpenPosition() || ordersEnteredToday>=Inp_MaxTradesDay ||
     dailyRiskBlocked || gAccountingUnresolved)
  { ResetArmedSignal(); readiness=APS_ENDED_FAIL_CLOSED;
    decision.reason="ORIGINAL_OPERATIONAL_GUARD"; return false; }
  if(prepared ? !DOMGateOwnUndispatchedIntent(expected) : HasExecutionInFlight())
  { decision.reason="FINANCIAL_GUARD_NOT_READY"; return false; }
  if(!DOMGateTermsCurrent(stageTick,original,price,lots,sl,tp,readiness))
  { decision.reason="SIZING_STOPS_OR_MARGIN_CHANGED"; return false; }
  if(GetMicrosecondCount()-windowBegin>BOOK_GATE_DECISION_BUDGET_US)
  { gBookGateDecisionBudgetBlocks++; decision.reason="LOCAL_REVALIDATION_BUDGET_EXCEEDED"; return false; }
  if(Inp_DecisionMode!=DECISION_ORIGINAL &&
     BookDecisionEvaluateArmed()!=DECISION_VALIDAR)
  { decision.reason="ABS_CONT_DECISION_REJECTED"; return false; }
  // No cached DOM authorization survives either journal or slow calculation.
  bool bookConfirmed=DOMGateRead(original.dir,decision);
  clocksCurrent=clocksCurrent && decision.signalClock==signalClock &&
                decision.contextClock==contextClock;
  MqlTick current;
  if(!SymbolInfoTick(Symbol(),current))
  { ResetArmedSignal(); readiness=APS_ENDED_FAIL_CLOSED;
    decision.reason="FINAL_TICK_UNAVAILABLE"; return false; }
  datetime now=TimeTradeServer();
  MqlDateTime dt; TimeToStruct(now,dt);
  if(!DOMGateIdentityCurrent(original))
  { decision.reason="ARMED_IDENTITY_CHANGED"; return false; }
  if((armed.armedAt>0 && now-armed.armedAt>=(datetime)Inp_ArmedTimeoutSec) ||
     dt.hour*100+dt.min>=Inp_StopEntryHHMM)
  {
     // Preserve original timeout/session precedence over tick predicates.
     readiness=CheckArmedMarketReady(effort,trigger,last,current);
     decision.reason="ORIGINAL_TIMEOUT_OR_SESSION_END"; return false;
  }
  if(DOMGateIdentityCurrent(original) && DOMGateOriginalOvershoot(current,original,trigger))
  {
     WriteAuditRow("OVERSHOOT_BLOCK",DirStr(armed.dir),armed.mode,current.last,
                   armed.posRel,armed.distD1,effort,trigger);
     ResetArmedSignal(); readiness=APS_ENDED_FAIL_CLOSED;
     decision.reason="ORIGINAL_OVERSHOOT_BLOCK"; return false;
  }
  if(!DOMGateFinalTickReady(current,original,trigger,price,readiness))
  { gBookGateQuoteDeferrals++; decision.reason="FINAL_MARKET_PREDICATE_NOT_READY"; return false; }
  if(!DOMGateTermsCurrent(current,original,price,lots,sl,tp,readiness))
  { decision.reason="FINAL_SIZING_STOPS_OR_MARGIN_CHANGED"; return false; }
  // Unavailable DOM cannot suppress an original terminal execution decision.
  if(!gBookGateSubscriptionOwned || Symbol()!=gBookGateSymbol ||
     !TerminalInfoInteger(TERMINAL_CONNECTED))
  { decision.reason="SUBSCRIPTION_UNAVAILABLE"; return false; }
  if(!clocksCurrent || iTime(Symbol(),Inp_SignalTF,0)!=signalClock ||
     iTime(Symbol(),Inp_ContextTF,0)!=contextClock)
  { decision.reason="BAR_CLOCK_CHANGED"; return false; }
  ulong elapsed=GetMicrosecondCount()-windowBegin;
  if(elapsed>gBookGateDecisionMaxUS) gBookGateDecisionMaxUS=elapsed;
  if(elapsed>BOOK_GATE_DECISION_BUDGET_US)
  { gBookGateDecisionBudgetBlocks++; decision.reason="LOCAL_REVALIDATION_BUDGET_EXCEEDED"; return false; }
  if(Inp_DecisionMode!=DECISION_ORIGINAL && !BookDecisionDispatchValid(original))
  { decision.reason="ABS_CONT_DECISION_STALE"; return false; }
  return bookConfirmed;
}

ENUM_SEND_OUTCOME DOMGateRejectPrepared(const BookGateDecision &decision,
                   const string reason,const ArmedSignal &original,
                   const PendingExecContext &expected,const bool apiCallStarted,
                   const ENUM_APS readiness)
{
  BookGateDecision rejected=decision;
  rejected.state=BOOK_ENTRY_BLOCKED; rejected.reason=reason+"; source="+decision.reason;
  DOMGateReport(rejected,false);
  // Tickets alone are NOT negative proof. This witness belongs to the same
  // SendOrder invocation that prepared expected, before its only API call.
  // Never call this helper from recovery, a timer, or after PositionOpen.
  if(apiCallStarted || !DOMGateIntentMatches(expected) || HasOpenPosition() ||
     HasOwnPendingOrder() || gPendingExit.active ||
     gOrderObligationScanUnresolved || gPendingOrderClassificationUnresolved)
  {
     Print("[BOOK_GATE][FINANCIAL_UNRESOLVED] no exclusive local no-dispatch proof; reconciliation required");
     return SEND_FINANCIAL_UNRESOLVED;
  }
  for(int i=0;i<ArraySize(gUnresolvedOrders);i++)
     if(gUnresolvedOrders[i].active && (gUnresolvedOrders[i].classificationPending ||
        gUnresolvedOrders[i].persistencePending)) return SEND_FINANCIAL_UNRESOLVED;
  for(int i=0;i<gTradeRecordCount;i++)
     if(gTradeRecords[i].positionID>0 && !gTradeRecords[i].closed &&
        gTradeRecords[i].totalVolumeIn>0) return SEND_FINANCIAL_UNRESOLVED;
  // MAY is not downgraded. An explicit durable result precedes memory cleanup.
  if(!ResolveRequestJournal(false))
  {
     Print("[BOOK_GATE][JOURNAL_RESOLUTION_FAILED] pending intent retained; no retry");
     return SEND_FINANCIAL_UNRESOLVED;
  }
  ResetLastError();
  bool journalExists=FileIsExist(RequestJournalPath(false));
  int journalProbeError=GetLastError();
  if(journalExists || (journalProbeError!=0 && journalProbeError!=ERR_FILE_NOT_EXIST) ||
     gEntryJournalCleanupPending ||
     gEntryJournalWritePending || gEntryJournalInvalid)
  {
     PrintFormat("[BOOK_GATE][JOURNAL_PROOF_FAILED] probe_error=%d; pending intent retained",journalProbeError);
     return SEND_FINANCIAL_UNRESOLVED;
  }
  ResetPendingExec(false);
  if(HasExecutionInFlight() || gEntryJournalInvalid || gExitJournalInvalid)
     return SEND_FINANCIAL_UNRESOLVED;
  PrintFormat("[BOOK_GATE][NO_DISPATCH_RESOLVED] phase=%d reason=%s; durable cleanup confirmed",
              (int)expected.dispatchPhase,reason);
  if(readiness==APS_ENDED_REEVAL_ALLOWED) return SEND_CANCEL_REEVAL;
  if(readiness==APS_ENDED_FAIL_CLOSED || !DOMGateIdentityCurrent(original))
     return SEND_ORIGINAL_CANCEL;
  if(readiness==APS_TRADE_OR_POSITION) return SEND_TRADE_OR_POSITION;
  // Cleanup itself can take time. Reuse original cancellation/operational rules
  // on the current sample; do not return WAIT with an expired signal.
  double effort,trigger,last;
  MqlTick current;
  ENUM_APS currentReadiness=CheckArmedEntryReady(effort,trigger,last,current);
  if(currentReadiness==APS_ENDED_REEVAL_ALLOWED) return SEND_CANCEL_REEVAL;
  if(currentReadiness==APS_ENDED_FAIL_CLOSED || !DOMGateIdentityCurrent(original))
     return SEND_ORIGINAL_CANCEL;
  if(currentReadiness==APS_TRADE_OR_POSITION) return SEND_TRADE_OR_POSITION;
  if(currentReadiness==APS_ENTRY_READY)
  {
     // Use the same Stage2 sample; never mix its LAST with a newer quote.
     if(DOMGateOriginalOvershoot(current,original,trigger))
     {
        WriteAuditRow("OVERSHOOT_BLOCK",DirStr(original.dir),original.mode,current.last,
                      original.posRel,original.distD1,effort,trigger);
        ResetArmedSignal(); return SEND_ORIGINAL_CANCEL;
     }
     double exec=(original.dir==1)?current.ask:current.bid;
     if(!DOMGateFinalTickReady(current,original,trigger,exec,currentReadiness) &&
        (currentReadiness==APS_ENDED_FAIL_CLOSED || !DOMGateIdentityCurrent(original)))
        return SEND_ORIGINAL_CANCEL;
  }
  if(HasExecutionInFlight() || gEntryJournalInvalid || gExitJournalInvalid)
     return SEND_FINANCIAL_UNRESOLVED;
  return SEND_WAIT_ARMED;
}

void DOMGateObserveMatrix(const MatrixSnapshot &s)
{
  if(!Inp_DOM_TradeGateEnable || !armed.active) return;
  DOMGateSyncIdentity();
  if(!gBookGateHadOpposite || !DOMGateLogAllowed()) return;
  PrintFormat("[BOOK_GATE][BOOK_LAST_OBSERVATION] opposite=%s ageMS=%I64u available=%s; not a fresh book read",
     BStr(gBookGateOppositeWatch),
     gBookGateObservationMS>0?GetTickCount64()-gBookGateObservationMS:0,
     BStr(gBookGateObservationMS>0));
  bool soleRoute=(s.absValid!=s.contValid);
  int matrixDir=s.absValid?s.dir:s.dirCont;
  bool oppositeComplete=(s.status==MSS_OK && soleRoute && matrixDir==-armed.dir);
  PrintFormat("[BOOK_GATE][BOOK_OPPOSITION_HISTORY] bar=%I64d armedAt=%I64d armedDir=%d status=%s absValid=%s contValid=%s absDir=%d contDir=%d completeOpposite=%s c1abs=%s c1cont=%s c2abs=%s c3abs=%s c4abs=%s c2cont=%s c3cont=%s c4cont=%s c5abs=%s c5cont=%s; OBSERVATION ONLY, original hard-contradiction/rearm controls execution",
     (long)gCachedMicroBar,(long)armed.armedAt,armed.dir,MssStr(s.status),
     BStr(s.absValid),BStr(s.contValid),s.dir,s.dirCont,BStr(oppositeComplete),
     BStr(s.c1),BStr(s.c1Cont),BStr(s.c2),BStr(s.c3),BStr(s.c4),
     BStr(s.c2Cont),BStr(s.c3Cont),BStr(s.c4Cont),BStr(s.c5AbsOk),BStr(s.c5ContOk));
}

void DOMGateDeinit()
{
  if(gBookGateSubscriptionOwned)
  {
     ResetLastError();
     if(!MarketBookRelease(gBookGateSymbol))
        Print("[BOOK_GATE][RELEASE_FAILED] own reference error=",GetLastError());
     gBookGateSubscriptionOwned=false;
  }
  if(Inp_DOM_TradeGateEnable)
     PrintFormat("[BOOK_GATE][RC2_METRICS] symbol=%s api_budget_blocks=%I64u agg_budget_blocks=%I64u decision_budget_blocks=%I64u quote_deferrals=%I64u prepare_calls=%I64u prepare_sum_us=%.0f prepare_max_us=%I64u journal_calls=%I64u journal_sum_us=%.0f journal_max_us=%I64u subscription_attempts=%I64u subscription_recoveries=%I64u terminal_memory_mb=%I64d; budgets uncalibrated; CPUrequires terminal/OS measurement",
        Symbol(),gBookGateApiBudgetBlocks,gBookGateAggregationBudgetBlocks,
        gBookGateDecisionBudgetBlocks,gBookGateQuoteDeferrals,gBookGatePrepareCalls,
        gBookGatePrepareSumUS,gBookGatePrepareMaxUS,gBookGateJournalCalls,
        gBookGateJournalSumUS,gBookGateJournalMaxUS,gBookGateSubscriptionAttempts,

gBookGateSubscriptionRecoveries,TerminalInfoInteger(TERMINAL_MEMORY_USED));
  if(Inp_DOM_TradeGateEnable)
     PrintFormat("[BOOK_GATE][SUMMARY] reads=%I64u blocked=%I64u unavailable=%I64u accepted=%I64u api_calls=%I64u api_sum_us=%.0f api_max_us=%I64u aggregation_calls=%I64u aggregation_sum_us=%.0f aggregation_max_us=%I64u decision_max_us=%I64u dispatch_gap_max_us=%I64u revalidation_calls=%I64u revalidation_sum_us=%.0f revalidation_max_us=%I64u late_deferrals=%I64u logs_dropped=%I64u; no financial performance claim",
       gBookGateReads,gBookGateBlocks,gBookGateUnavailable,gBookGateReleased,

gBookGateApiCalls,gBookGateApiSumUS,gBookGateApiMaxUS,gBookGateAggregations,

gBookGateAggregationSumUS,gBookGateAggregationMaxUS,gBookGateDecisionMaxUS,
  gBookGateDispatchMaxUS,gBookGateRevalidations,gBookGateRevalidationSumUS,
  gBookGateRevalidationMaxUS,gBookGateLateDeferrals,gBookGateLogsDropped);
}

// END EXPERIMENTAL DOM CONFLUENCE MODULE

//=====================================================================
// RC1 telemetry. No decision gates, CopyTicks, Print or tick flushing here.
MatrixSnapshot gLastTelemetryMatrix;
bool gLastTelemetryMatrixValid = false;
datetime gLastTelemetrySignalBar = 0;
bool gLiveDirectionTelemetryValid = false;
int gLiveDirAbs = 0;
int gLiveDirCont = 0;
bool gLateDirectionMismatch = false;
ulong gTradeCsvWrittenPIDs[];
bool gTradeCsvIndexLoaded = false;
bool gTradeCsvAppendSafe = false;
string gTradeCsvFileName="";
datetime gNextTradeCsvRecovery=0;
// HELPER FUNCTIONS
//=====================================================================
string DirStr(int d) { return d==1 ? "BUY" : (d==-1 ? "SELL" : "NONE"); }
string BStr(bool b) { return b ? "1" : "0"; }

string PocStateStr(ENUM_POC_STATE st)
{
  switch(st)
  {
    case POCS_NO_DISPLACEMENT: return "POC_NO_DISPLACEMENT";
    case POCS_FOLLOWING:              return "POC_FOLLOWING";
    case POCS_DIVERGENT:             return "POC_DIVERGENT";
    default: return "POC_INVALID";
  }
}
string MacroStatusStr(ENUM_MACRO_STATUS st)
{
    switch(st)
    {
       case MACRO_OK:        return "MACRO_OK";
       case MACRO_VWAP_INVALID: return "MACRO_VWAP_INVALID";
       case MACRO_SIGMA_INVALID: return "MACRO_SIGMA_INVALID";
       case MACRO_STRUCT_INVALID: return "MACRO_STRUCT_INVALID";
       case MACRO_NO_TRIGGER: return "MACRO_NO_TRIGGER";
       default: return "MACRO_NOT_COMPUTED";
      }
}

string MssStr(ENUM_MSS st)
{
  switch(st)
  {
    case MSS_OK:        return "OK";
    case MSS_MACRO_INVALID:             return "MACRO_INVALID";
    case MSS_VWAP_D1_INVALID:              return "VWAP_D1_INVALID";
    case MSS_SIGMA_INVALID:          return "SIGMA_INVALID";
    case MSS_STRUCT_INVALID:            return "STRUCT_INVALID";
    case MSS_STOP_KAMIKAZE_CONT_ONLY: return "KAMIKAZE_CONT_ONLY";
    case MSS_STOP_NO_C5_TRIGGER:                    return "NO_C5_TRIGGER";
    default: return "NOT_COMPUTED";
  }
}

int GetD1SessionEndHHMM()
{
  return gIsDollarFamily ? D1_SESSION_END_DOLLAR : D1_SESSION_END_INDEX;
}
double NormPriceDigits(double p)
{
  return NormalizeDouble(p, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

double RoundUpTick(double p)
{
  double r = p / gTickSize;
  double n = MathRound(r);
  if(MathAbs(r - n) < 1e-6) return NormPriceDigits(n * gTickSize);
  return NormPriceDigits(MathCeil(r) * gTickSize);
}

double RoundDownTick(double p)
{
  double r = p / gTickSize;
  double n = MathRound(r);
   if(MathAbs(r - n) < 1e-6) return NormPriceDigits(n * gTickSize);
   return NormPriceDigits(MathFloor(r) * gTickSize);
}

double NormEntrySL(int dir, double sl)
{ return (dir == 1) ? RoundDownTick(sl) : RoundUpTick(sl); }

double NormEntryTP(int dir, double tp)
{ return (dir == 1) ? RoundUpTick(tp) : RoundDownTick(tp); }

long TickIndex(double price) { return (long)MathRound(price / gTickSize); }

double ComputeTrigger(int dir, double regHigh, double regLow)
{
  if(dir == 1) return RoundUpTick(regHigh + gBreakoutMargin);
  return RoundDownTick(regLow - gBreakoutMargin);
}

bool IsFokSupported()
{
  ENUM_SYMBOL_TRADE_EXECUTION exec =
      (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(Symbol(),
SYMBOL_TRADE_EXEMODE);
  if(exec == SYMBOL_TRADE_EXECUTION_INSTANT ||
     exec == SYMBOL_TRADE_EXECUTION_REQUEST)
      return true;
  long filling = SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE);
  return ((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK);
}
void ResetPerfStat(PerfStat &p) { p.count = 0; p.sumUs = 0.0; p.maxUs = 0.0; }
void RecordPerf(PerfStat &p, double us)
{
  p.count++;
  p.sumUs += us;
  if(us > p.maxUs) p.maxUs = us;
}

void ResetMacroContext(MacroContext &m)
{
  m.status = MACRO_NOT_COMPUTED;
  m.barTime = 0;
  m.closedPrice = 0.0;
  m.vwap = 0.0;
  m.SigmaD1 = 0.0;
  m.distVWAP_D1 = 0.0;
  m.posRel = 0.0;
  m.glass = false;
  m.macroAbsDir = 0;
   m.macroContDir = 0;
}

void ResetPOCResult(POCResult &r)
{
  r.ok = false; r.poc = 0; r.totalVolume = 0; r.lastValidPrice = 0;
  r.tradeCount = 0; r.levels = 0; r.hasTie = false;
    r.top1Price = 0; r.top1Vol = 0; r.top2Price = 0; r.top2Vol = 0;
    r.dominance = 0; r.buyVol = 0; r.sellVol = 0; r.unkVol = 0;
}

void ResetMatrixSnapshot(MatrixSnapshot &s)
{
  s.status = MSS_NOT_COMPUTED;
  s.vwapVig=0;s.upper=0;s.lower=0;s.bandRange=0;
  s.price=0;s.open1=0;s.candleBody=0;s.posRel=0;
  s.glass=false;s.dir=0;s.dirCont=0;
  s.c5AbsOk=false;s.c5ContOk=false;
  s.distAbs=0;s.minDispl=0;s.maxBody=0;s.contMinDispl=0;
  s.c2=false;s.c3=false;s.c23=false;s.c4=false;
  s.c2Cont=false;s.c3Cont=false;s.c23Cont=false;s.c4Cont=false;
  s.posRange=0;
  ResetPOCResult(s.pocNow);
  ResetPOCResult(s.pocPrev);
  s.windowsValid=false;
  s.priceMove=0;s.pocMove=0;s.displacementOk=false;s.moveDir=0;
  s.pocState=POCS_INVALID;
  s.contDisplacementOk=false;s.contMoveDir=0;s.contPocState=POCS_INVALID;
    s.wwok=false;s.effort=0;s.waveDir=0;
     s.wwWaveBars=0; s.wwWaveAgeSec=0; s.wwWaveAgeAvailable=false;
     s.wwAccumVolume=0; s.wwDistancePts=0;
     s.c1_effort_ok=false;s.c1_body_ok=false;s.c1_displacement_ok=false;
     s.c1_movedir_ok=false;s.c1_wavedir_ok=false;
     s.absDivergence=false;s.absStallStrict=false;
     s.absFollowingReaction=false;s.absFollowingExtension=false;
     s.absPocContextOk=false;s.c1=false;
     s.cont_effort_ok=false;s.cont_displacement_ok=false;s.cont_poc_ok=false;
     s.cont_movedir_ok=false;s.cont_wavedir_ok=false;s.cont_candle_dir_ok=false;
     s.c1Cont=false;
     s.turboAbs=false;s.baseAbs=false;s.turboCont=false;s.baseCont=false;
     s.scoreEff=0;s.scoreContEff=0;
     s.absValid=false;s.contValid=false;
     s.candleDir=0;
     s.macroAbsCompatible=false;s.macroContCompatible=false;
}

void ResetArmedSignal()
{
  BookDiagBeforeReset();
  BookDecisionResetSignal();
  armed.active=false;armed.dir=0;
  armed.regionHigh=0;armed.regionLow=0;
  armed.activeSL_Pts=0;armed.activeTP_Pts=0;
  armed.regionEndTime=0;
  armed.mode="NONE";armed.lots=0;armed.route="NONE";
  armed.breakoutEffortMin=0;armed.armedAt=0;
  armed.sameSideGlassLogged=false;
  armed.posRel=0;armed.distD1=0;armed.effort=0;armed.vwapVig=0;
  armed.c1=0;armed.c2=0;armed.c3=0;armed.c4=0;armed.c5=0;armed.scoreEff=0;
}

void ResetOpenPos()
{
  gOpenPos.active=false;gOpenPos.positionID=0;gOpenPos.direction=0;
  gOpenPos.entryPrice=0;gOpenPos.MAE=0;gOpenPos.MFE=0;
  gOpenPos.entryTime=0;gOpenPos.route="";gOpenPos.mode="";
  gOpenPos.lots=0;gOpenPos.initialRiskMoney=0;gOpenPos.tradeRecordIdx=-1;
}

//=====================================================================
// TICK COPY — FAIL CLOSED (from v2.44, unchanged)
//=====================================================================
int CopyTradeTicksStrict(ulong from_msc, ulong to_msc, MqlTick &ticksOut[])
{
   if(to_msc < from_msc) return -1;
   ResetLastError();
   int copied = CopyTicksRange(Symbol(), ticksOut, COPY_TICKS_TRADE, from_msc,
to_msc);
    if(copied < 0 || GetLastError() != 0) return -1;
    // Reuse the exact acquired trade batch; independent of observation/export.
    if(Inp_DecisionMode!=DECISION_ORIGINAL)
       BookDecisionIngestBatch(from_msc,to_msc,ticksOut,copied);
    return copied;
}

//=====================================================================
// VWAP INCREMENTAL (from v2.44 — lógica idêntica, prefixo SCALPER)
//=====================================================================
void ResetVwapCache()
{
   vwapSumPV=0;vwapSumVol=0;vwapNextFromMsc=0;
   vwapReady=false;vwapDayKey=-1;gVwapValue=0;gVwapOk=false;
}

bool UpdateVwapIncremental(datetime t0)
{
  MqlDateTime d; TimeToStruct(t0, d);
  int key = d.year*1000 + d.day_of_year;
  if(key != vwapDayKey)
  {
vwapSumPV=0;vwapSumVol=0;vwapNextFromMsc=0;vwapReady=false;vwapDayKey=key;
 }
 ulong t0_msc = (ulong)t0 * 1000;
 if(!vwapReady)
 {
     d.hour=0;d.min=0;d.sec=0;
     datetime dayStart = StructToTime(d);
      ulong from = (ulong)dayStart * 1000;
      if(t0_msc <= from) {
vwapSumPV=0;vwapSumVol=0;vwapReady=false;vwapNextFromMsc=0; return false; }
      ulong to = t0_msc - 1;
      MqlTick tk[];
      int copied = CopyTradeTicksStrict(from, to, tk);
      if(copied <= 0) {
vwapSumPV=0;vwapSumVol=0;vwapReady=false;vwapNextFromMsc=0; return false; }
      double pv=0,vv=0; bool any=false;
      for(int i=0;i<copied;i++)
          if(tk[i].last>0&&tk[i].volume>0){ pv+=tk[i].last*(double)tk[i].volume;
vv+=(double)tk[i].volume; any=true; }
      if(!any||vv<=0) {
vwapSumPV=0;vwapSumVol=0;vwapReady=false;vwapNextFromMsc=0; return false; }
      vwapSumPV=pv;vwapSumVol=vv;vwapReady=true;vwapNextFromMsc=t0_msc;
      return true;
  }
  if(vwapNextFromMsc >= t0_msc) return (vwapSumVol > 0.0);
  ulong from = vwapNextFromMsc;
  ulong to = t0_msc - 1;
  MqlTick tk[];
  int copied = CopyTradeTicksStrict(from, to, tk);
  if(copied < 0) return false;
  if(copied == 0) { vwapNextFromMsc=t0_msc; return (vwapSumVol>0.0); }
  double pv=0,vv=0;
  for(int i=0;i<copied;i++)
      if(tk[i].last>0&&tk[i].volume>0){ pv+=tk[i].last*(double)tk[i].volume;
vv+=(double)tk[i].volume; }
  vwapSumPV+=pv;vwapSumVol+=vv;vwapNextFromMsc=t0_msc;
  return (vwapSumVol > 0.0);
}

bool GetLiveVwapSnapshot(ulong to_msc, double &liveVwap)
{
  liveVwap = 0.0;
  if(!vwapReady || vwapSumVol <= 0.0 || vwapNextFromMsc == 0) return false;
  double localPV = vwapSumPV, localVol = vwapSumVol;
  if(to_msc >= vwapNextFromMsc)
  {
      MqlTick ticks[];
      int copied = CopyTradeTicksStrict(vwapNextFromMsc, to_msc, ticks);
     if(copied <= 0) return false;
     for(int i=0;i<copied;i++)
         if(ticks[i].last>0&&ticks[i].volume>0)
         { localPV+=ticks[i].last*(double)ticks[i].volume; localVol+=(double)ticks[i].volume; }
    }
    if(localVol <= 0.0) return false;
    liveVwap = localPV / localVol;
      return liveVwap > 0.0;
}

//=====================================================================
// POC M1 COM DETECÇÃO DE EMPATE
// Preserva o princípio do ComputePOCWindow da 2.44.
// Tie is telemetry; canonical ascending scan keeps first maximum without a new tie rule.
//=====================================================================
bool ComputePOCWithTie(ulong from_msc, ulong to_msc, POCResult &res)
{
   if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseWindowBegin(from_msc,to_msc);
   ResetPOCResult(res);
   if(to_msc < from_msc) return false;

  MqlTick t[];
  int copied = CopyTradeTicksStrict(from_msc, to_msc, t);
  if(copied < 0) return false;
  if(copied == 0) return false;
double ts = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
if(ts <= 0.0) ts = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
if(ts <= 0.0) return false;

double pmin=DBL_MAX, pmax=-DBL_MAX; bool any=false;
for(int i=0;i<copied;i++)
{
    if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseWindowTick(from_msc,to_msc,t[i]);
    if(t[i].last>0.0 && t[i].volume>0)
    {
        any=true;
        if(t[i].last < pmin) pmin=t[i].last;
        if(t[i].last > pmax) pmax=t[i].last;
        res.lastValidPrice=t[i].last;
        res.tradeCount++;
        double v=(double)t[i].volume;
        bool fb=((t[i].flags & TICK_FLAG_BUY) != 0);
        bool fs=((t[i].flags & TICK_FLAG_SELL) != 0);
        if(fb && !fs) res.buyVol += v;
        else if(fs && !fb) res.sellVol += v;
        else            res.unkVol += v;
    }
}
if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseWindowFinish(from_msc,to_msc);
if(!any || pmax < pmin) return false;
long levelsL = (long)MathRound((pmax-pmin)/ts) + 1;
if(levelsL < 1 || levelsL > 100000) return false;
int levCount = (int)levelsL;

double vol[];
ArrayResize(vol, levCount);
ArrayInitialize(vol, 0.0);
for(int i=0;i<copied;i++)
{
    if(t[i].last>0.0 && t[i].volume>0)
    {
        int idx=(int)MathRound((t[i].last-pmin)/ts);
        if(idx<0||idx>=levCount) continue;
        vol[idx]+=(double)t[i].volume;
        res.totalVolume+=(double)t[i].volume;
    }
}
if(res.totalVolume <= 0.0) return false;

// Encontrar top1 e top2 separadamente (sem colapso silencioso de empate)
int best=-1, second=-1; double bestV=-1.0, secondV=-1.0; int nz=0;
for(int i=0;i<levCount;i++)
{
    if(vol[i] > 0.0) nz++;
    if(vol[i] > bestV) { bestV=vol[i]; best=i; }
  }
  for(int i=0;i<levCount;i++)
  {
      if(i==best) continue;
   if(vol[i] > 0.0 && vol[i] > secondV) { secondV=vol[i]; second=i; }
}
if(best < 0) return false;

res.levels = nz;
res.poc = pmin + best*ts;
res.top1Price = res.poc;
res.top1Vol = bestV;
if(second >= 0)
{
    res.top2Price = pmin + second*ts;
    res.top2Vol = secondV;
    // Canonical diagnostic: exactly equal executed volumes
    res.hasTie = (secondV == bestV);
}
else { res.top2Price=0; res.top2Vol=0; res.hasTie=false; }

 res.dominance = (res.totalVolume>0 && second>=0) ?
(res.top1Vol-res.top2Vol)/res.totalVolume : 0.0;
  res.ok = true;
   return true;
}

//=====================================================================
// WEIS WAVE M1
// Lógica operacional idêntica à v2.44.
// Adaptado: usa Inp_SignalTF (PERIOD_M1) em vez de Inp_Timeframe.
// Adicionado: wwCurrentWaveBars e wwWaveStartPrice (telemetria apenas).
//=====================================================================
void RebuildWeisCache()
{
   wwValid=false;
   int need=150;
   double close[]; long rvol[],tvol[];
   ArraySetAsSeries(close,true);
   ArraySetAsSeries(rvol,true);
   ArraySetAsSeries(tvol,true);
   int n=CopyClose(Symbol(),Inp_SignalTF,0,need,close);
   if(n<12) return;
   bool useReal=(CopyRealVolume(Symbol(),Inp_SignalTF,0,need,rvol)==n);
    if(!useReal && CopyTickVolume(Symbol(),Inp_SignalTF,0,need,tvol)!=n) return;

double waves[]; int wc=0;
int curDir=0; double accum=0.0;
int curWaveBars=0; double curWaveStart=0.0;

for(int i=n-2;i>=1;i--)
{
    int bd=(close[i]>close[i+1])?1:(close[i]<close[i+1]?-1:curDir);
        if(bd==0) bd=(curDir==0?1:curDir);
        double v=useReal?(double)rvol[i]:(double)tvol[i];
        if(curDir==0)
        {
            curDir=bd; accum=v; curWaveBars=1; curWaveStart=close[i+1];
        }
        else if(bd==curDir)
        {
            accum+=v; curWaveBars++;
        }
        else
        {
            ArrayResize(waves,wc+1); waves[wc++]=accum;
            curDir=bd; accum=v; curWaveBars=1; curWaveStart=close[i+1];
        }
    }
        int cnt=MathMin(10,wc); double s=0.0;
        for(int k=wc-1;k>=wc-cnt&&k>=0;k--) s+=waves[k];
        double avgClosed=(cnt>0)?s/cnt:0.0;
        int cntF=MathMin(10,wc+1); double sF=accum;
        for(int k=wc-1;k>=wc-(cntF-1)&&k>=0;k--) sF+=waves[k];
        double avgFlip=(cntF>0)?sF/cntF:0.0;
         wwUseReal        = useReal;
         wwDirClosed = curDir;
         wwAccumClosed = accum;
         wwAvgClosed = avgClosed;
         wwAvgIfFlip = avgFlip;
         wwCloseRef = close[1];
         wwWaveDirClosed = curDir;
         wwEffortClosed = (avgClosed>0.0)?accum/avgClosed:0.0;
         wwCurrentWaveBars = curWaveBars; // telemetria
         wwWaveStartPrice = curWaveStart; // telemetria
         wwValid = true;
}

// ComputeLiveWaveO1 adaptado para M1 — idêntico à v2.44 mas usa Inp_SignalTF
void ComputeLiveWaveO1(double &effort, double &curVol, double &avgVol, int &waveDir)
{
  double v0 = wwUseReal ?
      (double)iRealVolume(Symbol(),Inp_SignalTF,0) :
      (double)iVolume(Symbol(),Inp_SignalTF,0);
  double c0 = iClose(Symbol(),Inp_SignalTF,0);
  int bd0=(c0>wwCloseRef)?1:((c0<wwCloseRef)?-1:wwDirClosed);
  if(bd0==0) bd0=wwDirClosed;
  if(bd0==wwDirClosed)
    { curVol=wwAccumClosed+v0; waveDir=wwDirClosed; avgVol=wwAvgClosed; }
    else
    { curVol=v0; waveDir=bd0; avgVol=wwAvgIfFlip; }
    effort=(avgVol>0.0)?curVol/avgVol:0.0;
    if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseLiveWave(effort,curVol,avgVol,waveDir,c0);
}

//=====================================================================
// D-1 LITERAL (from v2.44 — idêntico, prefixo SCALPER nos prints)
//=====================================================================
void CalcD1Structure()
{
   H1=0;L1=0;VWAP_D1=0;VWAP_D1_Official=false;
   MqlDateTime td; TimeToStruct(TimeTradeServer(),td);
   td.hour=0;td.min=0;td.sec=0;
   datetime todayStart=StructToTime(td);
   datetime d1_0=iTime(Symbol(),PERIOD_D1,0);
   if(d1_0<=0) { Print("[SCALPER][D1] iTime D1 shift 0 falhou."); return; }
   datetime expected=0;
   if(d1_0>=todayStart)
   {
       expected=iTime(Symbol(),PERIOD_D1,1);
   if(expected<=0) { Print("[SCALPER][D1] iTime D1 shift 1 falhou."); return; }
   }
   else expected=d1_0;
   MqlDateTime ed; TimeToStruct(expected,ed);
  ed.hour=0;ed.min=0;ed.sec=0;
  datetime dayStart=StructToTime(ed);
  datetime dayEnd=dayStart+86400-1;
  datetime timeBuf[];
  int nBars=CopyTime(Symbol(),PERIOD_M1,dayStart,dayEnd,timeBuf);
  if(nBars<D1_MIN_M1_BARS)
  { PrintFormat("[SCALPER][D1] M1 insuficiente (%d<%d).",nBars,D1_MIN_M1_BARS);
return; }
  MqlDateTime b0; TimeToStruct(timeBuf[0],b0);
  if(b0.year!=ed.year||b0.mon!=ed.mon||b0.day!=ed.day)
  { Print("[SCALPER][D1] Data carregada difere."); return; }
  double highBuf[],lowBuf[],closeBuf[];
 if(CopyHigh (Symbol(),PERIOD_M1,dayStart,dayEnd,highBuf )!=nBars) return;
 if(CopyLow (Symbol(),PERIOD_M1,dayStart,dayEnd,lowBuf )!=nBars) return;
 if(CopyClose(Symbol(),PERIOD_M1,dayStart,dayEnd,closeBuf)!=nBars) return;
 long realVol[],tickVol[];
 bool
useRealVol=(CopyRealVolume(Symbol(),PERIOD_M1,dayStart,dayEnd,realVol)==nBars);

if(!useRealVol&&CopyTickVolume(Symbol(),PERIOD_M1,dayStart,dayEnd,tickVol)!=nBars)
return;
    int sessEnd=GetD1SessionEndHHMM();
    double dayHigh=0,dayLow=DBL_MAX;
    double sumTPVol=0,sumVol=0; int sessBar=0;
    for(int i=0;i<nBars;i++)
    {
    MqlDateTime b; TimeToStruct(timeBuf[i],b);
    int h=b.hour*100+b.min;
    if(h>=D1_SESSION_START&&h<sessEnd)
    {
        if(highBuf[i]>dayHigh) dayHigh=highBuf[i];
        if(lowBuf[i]<dayLow) dayLow=lowBuf[i];
        double tp=(highBuf[i]+lowBuf[i]+closeBuf[i])/3.0;
        double vol=useRealVol?(double)realVol[i]:(double)tickVol[i];
        if(vol>0){sumTPVol+=tp*vol;sumVol+=vol;}
        sessBar++;
    }
  }
  if(dayHigh<=0||dayLow>=DBL_MAX||dayHigh<=dayLow||sessBar==0||sumVol<=0) return;
  double dayVWAP=sumTPVol/sumVol;
  if(dayVWAP<=0) return;
  H1=dayHigh;L1=dayLow;VWAP_D1=dayVWAP;VWAP_D1_Official=true;
  PrintFormat("[SCALPER][D1] %s: VWAP=%.4f H1=%.4f L1=%.4f Barras=%d",
     TimeToString(dayStart,TIME_DATE),VWAP_D1,H1,L1,nBars);
}
//=====================================================================
// SIGMA HISTÓRICO (from v2.44 — idêntico na lógica)
//=====================================================================
void CalcSigmaHistory()
{
  SigmaD1=0;
  gBookSigmaValidDays=0;
  MqlDateTime todayDT; TimeToStruct(TimeTradeServer(),todayDT);
  todayDT.hour=0;todayDT.min=0;todayDT.sec=0;
  datetime searchDay=StructToTime(todayDT);
  int targetDays=SigmaLookbackDays; // validated, no silent input clamp
  double sigmaArray[20]; int validDaysFound=0;
  int sessEnd=GetD1SessionEndHHMM();
  for(int
attempt=0;attempt<MAX_SEARCH_DAYS&&validDaysFound<targetDays;attempt++)
  {
    searchDay-=86400;
    MqlDateTime sdt; TimeToStruct(searchDay,sdt);
    if(sdt.day_of_week==0||sdt.day_of_week==6) continue;
    sdt.hour=0;sdt.min=0;sdt.sec=0;
    datetime dayStart=StructToTime(sdt);
    datetime dayEnd=dayStart+86400-1;
    datetime timeBuf[];
    int nBars=CopyTime(Symbol(),PERIOD_M1,dayStart,dayEnd,timeBuf);
    if(nBars<D1_MIN_M1_BARS) continue;
    double highBuf[],lowBuf[],closeBuf[];
   if(CopyHigh(Symbol(),PERIOD_M1,dayStart,dayEnd,highBuf)!=nBars) continue;
   if(CopyLow (Symbol(),PERIOD_M1,dayStart,dayEnd,lowBuf )!=nBars) continue;
   double dayHigh=0,dayLow=DBL_MAX; int sessBar=0;
   for(int i=0;i<nBars;i++)
 {
      MqlDateTime b; TimeToStruct(timeBuf[i],b);
      int h=b.hour*100+b.min;
      if(h>=D1_SESSION_START&&h<sessEnd)
      { if(highBuf[i]>dayHigh)dayHigh=highBuf[i]; if(lowBuf[i]<dayLow)dayLow=lowBuf[i];
sessBar++; }
  }
  if(dayHigh<=0||dayLow>=DBL_MAX||dayHigh<=dayLow||sessBar==0) continue;
  if(CopyClose(Symbol(),PERIOD_M1,dayStart,dayEnd,closeBuf)!=nBars) continue;
  long realVol[],tickVol[];
  bool
useRealVol=(CopyRealVolume(Symbol(),PERIOD_M1,dayStart,dayEnd,realVol)==nBars);
  int copiedTV=0;
  if(!useRealVol)
copiedTV=CopyTickVolume(Symbol(),PERIOD_M1,dayStart,dayEnd,tickVol);
  if(!useRealVol&&copiedTV!=nBars) continue;
  double sumTPVol=0,sumVol=0;
  for(int i=0;i<nBars;i++)
  {
      MqlDateTime b; TimeToStruct(timeBuf[i],b);
      int h=b.hour*100+b.min;
   if(h>=D1_SESSION_START&&h<sessEnd)
   {
       double tp=(highBuf[i]+lowBuf[i]+closeBuf[i])/3.0;
       double vol=useRealVol?(double)realVol[i]:(double)tickVol[i];
       if(vol>0){sumTPVol+=tp*vol;sumVol+=vol;}
   }
   }
   if(sumVol<=0) continue;
   double dayVWAP=sumTPVol/sumVol;
   double sumWVar=0,sumVolB=0;
 for(int j=0;j<nBars;j++)
 {
    MqlDateTime b2; TimeToStruct(timeBuf[j],b2);
    int h2=b2.hour*100+b2.min;
    if(h2>=D1_SESSION_START&&h2<sessEnd)
    {
        double tp=(highBuf[j]+lowBuf[j]+closeBuf[j])/3.0;
        double vol=useRealVol?(double)realVol[j]:(double)tickVol[j];
        if(vol>0){double dd=tp-dayVWAP;sumWVar+=vol*dd*dd;sumVolB+=vol;}
    }
 }
 double daySigma=(sumVolB>0)?MathSqrt(sumWVar/sumVolB):0.0;
 sigmaArray[validDaysFound++]=daySigma;
 }
 gBookSigmaValidDays=validDaysFound;
 if(validDaysFound==0) { Print("[SCALPER][SIGMA] CRÍTICO: nenhum dia válido.");
return; }
 double sumS=0;
  for(int k=0;k<validDaysFound;k++) sumS+=sigmaArray[k];
  SigmaD1=sumS/(double)validDaysFound;
  double pisoSigma=gIsIndexFamily?Inp_SigmaFloor_WIN:Inp_SigmaFloor_WDO;
  if(SigmaD1<pisoSigma)
  { PrintFormat("[SCALPER] Sigma=%.4f<piso=%.4f. Aplicando piso.",SigmaD1,pisoSigma);
SigmaD1=pisoSigma; }
  PrintFormat("[SCALPER][SIGMA] SigmaD1=%.4f DiasValidos=%d/%d",SigmaD1,validDaysFound,targetDays);
}

void TryCalcD1()
{
  if(!VWAP_D1_Official) CalcD1Structure();
  if(SigmaD1<=0.0) CalcSigmaHistory();
    d1Ready=(VWAP_D1_Official&&VWAP_D1>0&&SigmaD1>0&&H1>0&&L1>0&&H1>L1);
    if(!d1Ready) nextD1Retry=TimeTradeServer()+60;
}
//=====================================================================
// MACRO CONTEXT (M3) — NOVO
// Determina regime estrutural. NÃO calcula ABS/CONT completo.
// Usa mesma lógica C5 da v2.44 para determinar macroAbsDir/macroContDir.
//=====================================================================
void ComputeMacroContext()
{
   datetime contextClock=iTime(Symbol(),Inp_ContextTF,0);
   ResetMacroContext(gMacro);
   if(VWAP_D1<=0||!VWAP_D1_Official) { gMacro.status=MACRO_VWAP_INVALID; return;
}
   if(SigmaD1<=0)       { gMacro.status=MACRO_SIGMA_INVALID; return; }
    if(!gVwapOk||gVwapValue<=0)        { gMacro.status=MACRO_STRUCT_INVALID; return;
}
    double closedM3=iClose(Symbol(),Inp_ContextTF,1);
    if(closedM3<=0) { gMacro.status=MACRO_STRUCT_INVALID; return; }
    gMacro.barTime =iTime(Symbol(),Inp_ContextTF,1);
    gMacro.closedPrice=closedM3;
    gMacro.vwap      =gVwapValue;
    gMacro.SigmaD1 =SigmaD1;
    gMacro.distVWAP_D1=MathAbs(closedM3-VWAP_D1);
    double upper=gMacro.vwap+SigmaD1*BandMultiplier;
    double lower=gMacro.vwap-SigmaD1*BandMultiplier;
    double range=upper-lower;
    if(range<=0) { gMacro.status=MACRO_STRUCT_INVALID; return; }
    gMacro.posRel=(closedM3-lower)/range;
gMacro.glass=(gMacro.posRel>Inp_VWAP_Outer_Pct)||(gMacro.posRel<(1.0-Inp_VWAP_Outer_Pct));
  // C5 idêntico ao da v2.44
  gMacro.macroAbsDir=0;
  if(gMacro.posRel>=Inp_VWAP_Inner_Pct) gMacro.macroAbsDir=-1;
    else if(gMacro.posRel<=(1.0-Inp_VWAP_Inner_Pct)) gMacro.macroAbsDir=1;
    gMacro.macroContDir=0;
    if(gMacro.posRel>=Inp_VWAP_Inner_Pct) gMacro.macroContDir=1;
    else if(gMacro.posRel<=(1.0-Inp_VWAP_Inner_Pct)) gMacro.macroContDir=-1;
    if(gMacro.macroAbsDir==0&&gMacro.macroContDir==0)
    { gMacro.status=MACRO_NO_TRIGGER; return; }
    if(contextClock<=0 || iTime(Symbol(),Inp_ContextTF,0)!=contextClock)
    { gMacro.status=MACRO_STRUCT_INVALID; return; }
    gMacro.status=MACRO_OK;
}

//=====================================================================
// MATRIX SNAPSHOT M1
// Preserva todas as fórmulas da v2.44 (C2/C3/C4/C5/WW/POC/ABS/CONT).
// Diferenças chave vs. v2.44:
// - usa Inp_SignalTF (M1) para close/open/volume
// - displacement e corpo em pts fixos (não sigma-fração)
// - DIVERGENCE requires displacement, exactly as canonical v2.44
// - POC: janela 60s, com detecção de empate
// - filtro MacroContext ao final
//=====================================================================
ENUM_MSS ComputeMatrixSnapshot(MatrixSnapshot &s)
{
   if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseSnapshotBegin();
   ResetMatrixSnapshot(s);

  // MacroContext deve ser válido (fail closed se não)
  if(Inp_EnableMacroDirectionGate && gMacro.status!=MACRO_OK)
  { s.status=MSS_MACRO_INVALID; return s.status; }
 if(VWAP_D1<=0||!VWAP_D1_Official) { s.status=MSS_VWAP_D1_INVALID; return
s.status; }
 if(SigmaD1<=0) { s.status=MSS_SIGMA_INVALID; return s.status; }
 if(H1<=0||L1<=0||H1<=L1)      { s.status=MSS_STRUCT_INVALID; return s.status; }

s.vwapVig=gVwapValue;
if(s.vwapVig<=0) { s.status=MSS_STRUCT_INVALID; return s.status; }

s.upper =s.vwapVig+SigmaD1*BandMultiplier;
s.lower =s.vwapVig-SigmaD1*BandMultiplier;
s.bandRange=s.upper-s.lower;
if(s.bandRange<=0) { s.status=MSS_STRUCT_INVALID; return s.status; }

// Candle M1 fechada (shift 1 = última fechada)
s.price =iClose(Symbol(),Inp_SignalTF,1);
s.open1 =iOpen (Symbol(),Inp_SignalTF,1);
s.candleBody=MathAbs(s.price-s.open1);
if(s.price<=0) { s.status=MSS_STRUCT_INVALID; return s.status; }

// C5 (idêntico à v2.44)
s.posRel=(s.price-s.lower)/s.bandRange;
s.glass=(s.posRel>Inp_VWAP_Outer_Pct)||(s.posRel<(1.0-Inp_VWAP_Outer_Pct));
s.dir=0;
if(s.posRel>=Inp_VWAP_Inner_Pct)      s.dir=-1;
else if(s.posRel<=(1.0-Inp_VWAP_Inner_Pct)) s.dir=1;
s.dirCont=0;
if(s.posRel>=Inp_VWAP_Inner_Pct)      s.dirCont=1;
else if(s.posRel<=(1.0-Inp_VWAP_Inner_Pct)) s.dirCont=-1;

 if(s.glass&&!Inp_EnableAbsorption) { s.status=MSS_STOP_KAMIKAZE_CONT_ONLY;
return s.status; }
 if(s.dir==0&&s.dirCont==0) { s.status=MSS_STOP_NO_C5_TRIGGER; return
s.status; }
s.c5AbsOk =(s.dir!=0);
s.c5ContOk=(s.dirCont!=0)&&!s.glass;
// Distância D-1
s.distAbs =MathAbs(s.price-VWAP_D1);
bool priceAbove=(s.price>VWAP_D1);
// Thresholds (pts fixos — hipóteses)
s.minDispl =gABS_MinDisplPts;
s.maxBody =gABS_MaxBodyPts;
s.contMinDispl=gCONT_MinDisplPts;

// C2/C3 ABS (fórmulas idênticas à v2.44)
bool sideC2Ok=((s.dir==-1&&priceAbove)||(s.dir==1&&!priceAbove));
s.c2=(sideC2Ok&&s.distAbs>=gC2);
bool sideC3Ok=((s.dir==-1&&!priceAbove)||(s.dir==1&&priceAbove));
s.c3=(sideC3Ok&&s.distAbs>=gC3Min&&s.distAbs<=gC3Max);
s.c23=(s.c2||s.c3);

 // C2/C3 CONT
 bool
sideContOk=((s.dirCont==1&&s.price>VWAP_D1)||(s.dirCont==-1&&s.price<VWAP_D1));
 s.c2Cont=(sideContOk&&s.distAbs>=gC2);
 s.c3Cont=(sideContOk&&s.distAbs>=gC3Min&&s.distAbs<=gC3Max);
 s.c23Cont=(s.c2Cont||s.c3Cont);

// C4 (idêntico à v2.44)
s.posRange=(s.price-L1)/(H1-L1);
s.c4
=(s.dir==-1)?(s.posRange>=1.0-Inp_Rule_40_60):(s.posRange<=Inp_Rule_40_60);

s.c4Cont=(s.dirCont==1)?(s.posRange>=1.0-Inp_Rule_40_60):(s.posRange<=Inp_Rule_40_60);

// POC M1 — janelas 60s referenciadas ao início da M1 atual (causal)
// Nunca inclui ticks da barra viva (to = t0 - 1ms)
datetime t0_bar=iTime(Symbol(),Inp_SignalTF,0); // início da barra viva atual
ulong t0_msc=(ulong)t0_bar*1000;
ulong win_msc=(ulong)Inp_POC_WindowSec*1000;

if(t0_msc>2*win_msc)
{
    ulong fromNow =t0_msc-win_msc;
    ulong toNow =t0_msc-1;
    ulong fromPrev=t0_msc-2*win_msc;
    ulong toPrev =t0_msc-win_msc-1;
BookMeasuredPOC(fromNow, toNow, s.pocNow);
BookMeasuredPOC(fromPrev, toPrev, s.pocPrev);

// Optional tie rejection; baseline false preserves canonical deterministic POC
// Comportamento como input: frequência real de ties ainda desconhecida
 if(Inp_RejectPOCTies)
{
    if(s.pocNow.ok && s.pocNow.hasTie) s.pocNow.ok = false;
    if(s.pocPrev.ok && s.pocPrev.hasTie) s.pocPrev.ok = false;
 }
}
s.windowsValid=(s.pocNow.ok&&s.pocPrev.ok);

// Movimento de preço e POC
if(s.windowsValid)
{
    s.priceMove=s.pocNow.lastValidPrice-s.pocPrev.lastValidPrice;
    s.pocMove =s.pocNow.poc-s.pocPrev.poc;
}

// Canonical v2.44 classification; only scale is fixed points.
s.displacementOk=s.windowsValid && MathAbs(s.priceMove)>=s.minDispl;
s.moveDir=0;
s.pocState=POCS_INVALID;
if(s.windowsValid)
{
    if(s.displacementOk)
    {
        s.moveDir=(s.priceMove>0)?1:-1;
    bool follows=(s.pocMove*s.priceMove>0) &&
      MathAbs(s.pocMove)>=MathAbs(s.priceMove)*Inp_POC_FollowRatio;
    s.pocState=follows?POCS_FOLLOWING:POCS_DIVERGENT;
  }
  else s.pocState=POCS_NO_DISPLACEMENT;
}
s.contDisplacementOk=s.windowsValid && MathAbs(s.priceMove)>=s.contMinDispl;
s.contMoveDir=0;
s.contPocState=POCS_INVALID;
if(s.windowsValid)
{
    if(s.contDisplacementOk)
    {
        s.contMoveDir=(s.priceMove>0)?1:-1;
        bool follows=(s.pocMove*s.priceMove>0) &&
         MathAbs(s.pocMove)>=MathAbs(s.priceMove)*Inp_POC_FollowRatio;
        s.contPocState=follows?POCS_FOLLOWING:POCS_DIVERGENT;
    }
    else s.contPocState=POCS_NO_DISPLACEMENT;
}

// WW M1 (do cache reconstruído)
s.wwok =wwValid;
s.effort =wwEffortClosed;
s.waveDir=wwWaveDirClosed;
 if(s.wwok)
 {
    s.wwWaveBars=wwCurrentWaveBars;
   s.wwAccumVolume=wwAccumClosed;
   s.wwDistancePts=(wwWaveStartPrice>0)?MathAbs(s.price-wwWaveStartPrice):0;
   datetime waveStart=iTime(Symbol(),Inp_SignalTF,wwCurrentWaveBars);
   s.wwWaveAgeAvailable=wwCurrentWaveBars>0 && waveStart>0 &&
t0_bar>=waveStart;
   if(s.wwWaveAgeAvailable) s.wwWaveAgeSec=(long)(t0_bar-waveStart);
 }

// C1 ABS — fórmula idêntica à v2.44
s.c1_effort_ok =s.wwok&&(s.effort>=Inp_ABS_Effort);
s.c1_body_ok =(s.candleBody<=s.maxBody);
s.c1_displacement_ok=s.displacementOk;
s.c1_movedir_ok =(s.moveDir==-s.dir); // telemetria
s.c1_wavedir_ok =(s.waveDir==s.moveDir); // telemetria

// Contextos POC ABS
// DIVERGENCE: possible only after displacementOk in canonical classification
s.absDivergence =s.windowsValid&&(s.pocState==POCS_DIVERGENT);
// STALL_STRICT: below minimum displacement + small candle body
s.absStallStrict
=s.windowsValid&&(s.pocState==POCS_NO_DISPLACEMENT)&&s.c1_body_ok;
// STALL_RAW: sem movimento (sem exigência de corpo — telemetria)
// FOLLOWING_REACTION: POC segue, preço na direção ABS, com displacement
s.absFollowingReaction =s.windowsValid&&(s.pocState==POCS_FOLLOWING)&&
   s.displacementOk&&(s.moveDir==s.dir);
// FOLLOWING_EXTENSION: POC segue, preço contra ABS — NÃO valida ABS
s.absFollowingExtension =s.windowsValid&&(s.pocState==POCS_FOLLOWING)&&
   s.displacementOk&&(s.moveDir==-s.dir);
s.absPocContextOk=s.absDivergence||s.absStallStrict||s.absFollowingReaction;
// C1 ABS (mestre)
s.c1=s.c1_effort_ok&&s.absPocContextOk;

// C1 CONT — fórmula idêntica à v2.44
s.cont_effort_ok =s.wwok&&(s.effort>=Inp_CONT_Effort);
s.cont_displacement_ok=s.contDisplacementOk;
s.cont_poc_ok
=s.windowsValid&&s.contDisplacementOk&&(s.contPocState==POCS_FOLLOWING);
s.cont_movedir_ok =(s.contMoveDir==s.dirCont);
s.cont_wavedir_ok =(s.waveDir==s.dirCont);
s.candleDir =(s.price>s.open1)?1:((s.price<s.open1)?-1:0);
s.cont_candle_dir_ok=!Inp_Cont_RequireCandleDirection||
   (s.dirCont==1&&s.price>s.open1)||
   (s.dirCont==-1&&s.price<s.open1);
s.c1Cont=s.cont_effort_ok&&s.cont_displacement_ok&&s.cont_poc_ok&&
    s.cont_movedir_ok&&s.cont_wavedir_ok&&s.cont_candle_dir_ok;
   // BASE / TURBO (idêntico à v2.44)
   s.turboAbs =(s.c1&&s.c23&&s.c4);
   s.baseAbs =(s.c1&&(s.c23||s.c4)&&!s.turboAbs);
    s.scoreEff =(s.c1?1:0)+(s.c23?1:0)+(s.c4?1:0);
    s.turboCont=(s.c1Cont&&s.c23Cont&&s.c4Cont);
    s.baseCont =(s.c1Cont&&(s.c23Cont||s.c4Cont)&&!s.turboCont);
    s.scoreContEff=(s.c1Cont?1:0)+(s.c23Cont?1:0)+(s.c4Cont?1:0);

    // Validade antes do filtro macro
    s.absValid =Inp_EnableAbsorption &&s.c5AbsOk &&(s.turboAbs||s.baseAbs);
    s.contValid=Inp_EnableContinuation&&s.c5ContOk&&(s.turboCont||s.baseCont);

 // FILTRO MACROCONTEXT
 // ABS M1 precisa concordar com macroAbsDir
 // CONT M1 precisa concordar com macroContDir
 s.macroAbsCompatible =(s.dir ==gMacro.macroAbsDir) &&(s.dir
!=0)&&(gMacro.status==MACRO_OK);

s.macroContCompatible=(s.dirCont==gMacro.macroContDir)&&(s.dirCont!=0)&&(gMacro.status==MACRO_OK);
 if(Inp_EnableMacroDirectionGate)
 {
    if(s.absValid && !s.macroAbsCompatible) s.absValid=false;
        if(s.contValid && !s.macroContCompatible) s.contValid=false;
    }

    s.status=MSS_OK;
    return s.status;
}

//=====================================================================
// HARD DIRECTIONAL CONTRADICTION (idêntico à v2.44)
//=====================================================================
bool HasHardDirectionalContradiction(const MatrixSnapshot &s, int armedDir)
{
  if(s.status!=MSS_OK) return false;
  if(armedDir!=1&&armedDir!=-1) return false;
  return (s.absValid&&s.dir==-armedDir)||(s.contValid&&s.dirCont==-armedDir);
}

//=====================================================================
// SIZING
//=====================================================================
double ComputeLotsForEntry(int direction, double entryPrice, double slPrice)
{
   if(Inp_SizingMode==SIZING_FIXED) return Inp_FixedLots; // already validated
   double profit=0.0;
 ENUM_ORDER_TYPE type=(direction==1)?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
 if(!OrderCalcProfit(type,Symbol(),1.0,entryPrice,slPrice,profit) ||
    !MathIsValidNumber(profit) || profit>=0.0)
 {
  WriteAuditRow("RISK_CALC_FAIL",DirStr(direction),armed.mode,entryPrice,0,0,0,0);
  return 0.0;
 }
 double riskCash=AccountInfoDouble(ACCOUNT_EQUITY)*Inp_RiskPerTradePct/100.0;
 if(!MathIsValidNumber(riskCash) || riskCash<=0) return 0.0;
 double step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
 double
cap=MathMin(Inp_MaxLots,SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX));
 double raw=MathMin(riskCash/MathAbs(profit),cap);
 double lots=NormalizeDouble(MathFloor(raw/step)*step,8);
 // Never allow a rounded floating representation to exceed raw risk/cap.
 if(lots>raw+1e-10) lots=NormalizeDouble(lots-step,8);
 if(lots<SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN)-1e-10)
 {

WriteAuditRow("RISK_BELOW_MIN_LOT",DirStr(direction),armed.mode,entryPrice,0,0,0,0);
    return 0.0;
  }
  return lots;
}
bool MarginOk(ENUM_ORDER_TYPE otype, double lots)
{
  double margin=0;
  double price=(otype==ORDER_TYPE_BUY)?
      SymbolInfoDouble(Symbol(),SYMBOL_ASK):
      SymbolInfoDouble(Symbol(),SYMBOL_BID);
  if(!OrderCalcMargin(otype,Symbol(),lots,price,margin)) return false;
  return (AccountInfoDouble(ACCOUNT_MARGIN_FREE)>=margin);
}
bool SpreadOk()
{
  MqlTick tick;
  if(!SymbolInfoTick(Symbol(),tick) || tick.ask<=0 || tick.bid<=0 || tick.ask<tick.bid)
     return false;
  BookDiagSpread(tick);
  return tick.ask-tick.bid<=gSpreadMaxPts;
}
//=====================================================================
// POSITION HELPERS (adaptados da v2.44)
//=====================================================================
bool HasOpenPosition()
{
    for(int i=PositionsTotal()-1;i>=0;i--)
    {
      if(!posInfo.SelectByIndex(i)) continue;
     if(posInfo.Symbol()!=Symbol()) continue;
     if(gNetting) return true;
     if(posInfo.Magic()==(long)gMagicCore) return true;
    }
    return false;
}

bool HasOwnPositionStrict()
{
  for(int i=PositionsTotal()-1;i>=0;i--)
  {
    if(!posInfo.SelectByIndex(i)) continue;
    if(posInfo.Symbol()!=Symbol()) continue;
    if(posInfo.Magic()==(long)gMagicCore) return true;
  }
  return false;
}

// Conta trades por POSITION_ID (não por deals) — idêntico à v2.44
//=====================================================================
// MAE/MFE TRACKING (por tick, sem escrita por tick)
//=====================================================================
void UpdateMAEMFE()
{
   if(!gOpenPos.active) return;
   MqlTick tk;
   if(!SymbolInfoTick(Symbol(),tk)) return;
   // Usar bid/ask para cálculo conservador
   double current=(gOpenPos.direction==1)?tk.bid:tk.ask;
   double move=(double)gOpenPos.direction*(current-gOpenPos.entryPrice);
    double adverse=-move;
    if(adverse>gOpenPos.MAE) gOpenPos.MAE=adverse;
    if(move>gOpenPos.MFE) gOpenPos.MFE=move;
}

//=====================================================================
// TELEMETRIA CSV
// Não escreve por tick. FileFlush apenas em eventos importantes ou no Timer.
//=====================================================================
string CsvCell(string value)
{
  if(StringLen(value) == 0) return "\"\"";
   bool quoted = StringFind(value,",") >= 0 || StringFind(value,"\"") >= 0 ||
        StringFind(value,"\r") >= 0 || StringFind(value,"\n") >= 0;
    if(!quoted) return value;
    StringReplace(value,"\"","\"\"");
    return "\"" + value + "\"";
}
void CsvAdd(string &line,string value)
{
  if(StringLen(line) > 0) line += ",";
  line += CsvCell(value);
}

string CsvD(double value)
{
  if(!MathIsValidNumber(value) || value == EMPTY_VALUE) return "";
  return DoubleToString(value,8);
}

string CsvTime(datetime value)
{
  return value > 0 ? TimeToString(value,TIME_DATE|TIME_SECONDS) : "";
}
bool TradeCsvContainsPID(ulong positionID)
{
  for(int i=0;i<ArraySize(gTradeCsvWrittenPIDs);i++)
   if(gTradeCsvWrittenPIDs[i] == positionID) return true;
  return false;
}

bool TradeCsvAddPID(ulong positionID)
{
  if(TradeCsvContainsPID(positionID)) return true;
  int n=ArraySize(gTradeCsvWrittenPIDs);
  if(ArrayResize(gTradeCsvWrittenPIDs,n+1) != n+1) return false;
  gTradeCsvWrittenPIDs[n]=positionID;
  return true;
}

bool CsvParsePID(string value,ulong &positionID)
{
  positionID=0;
  if(StringLen(value)==0) return false;
  for(int i=0;i<StringLen(value);i++)
  {
     ushort c=StringGetCharacter(value,i);
     if(c<48 || c>57) return false;
     ulong digit=(ulong)(c-48);
     ulong next=positionID*10+digit;
     if(next<digit || (next-digit)/10 != positionID) return false;
     positionID=next;
    }
    return positionID>0;
}
// Strict quote-aware parsing of one complete logical CSV record.
// CR/LF inside quoted fields are preserved; malformed quoting fails closed.
bool CsvParseRecord(string record,string &fields[])
{
   ArrayResize(fields,0);
   string value="";
   bool quoted=false,afterQuote=false;
   int len=StringLen(record);
   for(int i=0;i<len;i++)
   {
     ushort c=StringGetCharacter(record,i);
     if(quoted)
     {
        if(c==34)
        {
         if(i+1<len && StringGetCharacter(record,i+1)==34)
         { value+="\""; i++; }
         else { quoted=false; afterQuote=true; }
       }
       else value+=StringSubstr(record,i,1);
     }
     else if(c==44)
     {
       int n=ArraySize(fields);
       if(ArrayResize(fields,n+1)!=n+1) return false;
       fields[n]=value; value=""; afterQuote=false;
     }
     else if(c==34)
     {
       if(StringLen(value)>0 || afterQuote) return false;
       quoted=true;
     }
     else
     {
       if(afterQuote || c==10 || c==13) return false;
       value+=StringSubstr(record,i,1);
     }
    }
    if(quoted) return false;
    int n=ArraySize(fields);
     if(ArrayResize(fields,n+1)!=n+1) return false;
     fields[n]=value;
     return true;
}

int CsvColumnIndex(string &headers[],string name)
{
   for(int i=0;i<ArraySize(headers);i++) if(headers[i]==name) return i;
   return -1;
}

// One attach-time scan. Never truncate, repair, or overwrite an existing CSV.
// A nonterminated tail is conservatively incomplete, even if fields look valid.
// ORIGINAL_INCLUDE | #include "Include\BookCsvDiagnostics.mqh"
// BEGIN_INCORPORATED Include/BookCsvDiagnostics.mqh
#ifndef BOOK_CSV_DIAGNOSTICS_MQH
#define BOOK_CSV_DIAGNOSTICS_MQH
// Financial CSV validation only. Never modifies, truncates or repairs source bytes.
// Include in place of InitializeTradeCsvIndex, after the legacy CSV helpers.
bool gTradeCsvInfrastructureUnresolved=true;
string gBookCsvLastDiagnostic="";
ulong gBookCsvVerifiedSize=0;
bool gBookCsvObservedEver=false;
bool gBookCsvSentinelWarning=false;

// A durable path-seen marker survives restart even after old trade records have
// aged out of the current accounting window. This is evidence of prior presence,
// never a backup or a replacement for the financial CSV.
bool BookCsvSentinelIdentity(string &path,string &payload)
{
   string identity=AccountInfoString(ACCOUNT_SERVER)+"|"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+
      "|"+Symbol()+"|"+(string)gMagicCore+"|"+gTradeCsvFileName;
   uchar bytes[],key[],digest[];
   int count=StringToCharArray(identity,bytes,0,WHOLE_ARRAY,CP_UTF8);
   if(count<=1 || ArrayResize(bytes,count-1)!=count-1) return false;
   ResetLastError();
   if(CryptEncode(CRYPT_HASH_SHA256,bytes,key,digest)!=32 || GetLastError()!=0 || ArraySize(digest)!=32)
      return false;
   string hash=""; for(int i=0;i<32;i++) hash+=StringFormat("%02x",(uint)digest[i]);
   path="BOOK_CSV_SEEN_"+hash+".state";
   payload="BOOK_CSV_SEEN_V1\n"+hash+"\n";
   return true;
}

// Return 0 only for positively absent metadata, 1 for valid prior presence,
// -1 for uncertain/corrupt metadata. Never reinterpret uncertainty as absence.
int BookCsvSentinelStatus()
{
   string path,payload;
   if(!BookCsvSentinelIdentity(path,payload)) return -1;
   ResetLastError(); bool exists=FileIsExist(path); int probeError=GetLastError();
   if(!exists) return (probeError==0 || probeError==ERR_FILE_NOT_EXIST)?0:-1;
   ResetLastError(); int h=FileOpen(path,FILE_READ|FILE_BIN|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return -1;
   ResetLastError(); ulong size=FileSize(h); int sizeError=GetLastError();
   if(sizeError!=0 || size==0 || size>256) { FileClose(h); return -1; }
   uchar bytes[];
   if(ArrayResize(bytes,(int)size)!=(int)size) { FileClose(h); return -1; }
   ResetLastError(); uint read=FileReadArray(h,bytes,0,(int)size); int readError=GetLastError();
   ResetLastError(); FileClose(h); int closeError=GetLastError();
   if(read!=(uint)size || readError!=0 || closeError!=0) return -1;
   return CharArrayToString(bytes,0,(int)size,CP_UTF8)==payload?1:-1;
}

void BookCsvEnsureSentinel()
{
   int status=BookCsvSentinelStatus();
   if(status==1) return;
   string path,payload;
   if(status==0 && BookCsvSentinelIdentity(path,payload))
   {
      // Existing/corrupt markers are preserved. Only positively absent metadata
      // is created, followed by durable flush and a separate readback.
      ResetLastError(); int h=FileOpen(path,FILE_WRITE|FILE_BIN);
      if(h!=INVALID_HANDLE)
      {
         uchar encoded[]; int count=StringToCharArray(payload,encoded,0,WHOLE_ARRAY,CP_UTF8);
         ResetLastError(); uint written=(count>1)?FileWriteArray(h,encoded,0,count-1):0;
         int writeError=GetLastError();
         ResetLastError(); FileFlush(h); int flushError=GetLastError();
         ResetLastError(); FileClose(h); int closeError=GetLastError();
         if(count>1 && written==(uint)(count-1) && writeError==0 && flushError==0 && closeError==0 &&
            BookCsvSentinelStatus()==1) return;
      }
   }
   if(!gBookCsvSentinelWarning)
      Print("[BOOK][CSV_PRESENCE_SENTINEL_UNVERIFIED] valid CSV retained; cross-restart missing-file proof unavailable; existing marker never overwritten");
   gBookCsvSentinelWarning=true;
}

bool BookCsvCanCreateMissing(const bool previouslySeen,const bool markerKnownAbsent,
                             const bool financialEvidence)
{
   return !previouslySeen && markerKnownAbsent && !financialEvidence;
}

bool BookCsvReject(const string fileName,const long logicalRow,const int expected,
                   const int received,const string reason,const long offset=-1)
{
   gTradeCsvIndexLoaded=false;
   gTradeCsvAppendSafe=false;
   gTradeCsvInfrastructureUnresolved=true;
   string detail=fileName+"|"+(string)logicalRow+"|"+(string)expected+"|"+
      (string)received+"|"+reason+"|"+(string)offset;
   if(detail!=gBookCsvLastDiagnostic)
      PrintFormat("[BOOK][TRADE_CSV_INVALID] file=%s logical_row=%I64d expected_columns=%d received_columns=%d cause=%s character_offset=%I64d; ORIGINAL_PRESERVED; entries require reconciliation",
                  fileName,logicalRow,expected,received,reason,offset);
   gBookCsvLastDiagnostic=detail;
   return false;
}

// Parser exposes a precise syntactic cause. Column count includes an empty tail.
bool BookCsvParse(const string record,string &fields[],string &reason,int &offset)
{
   ArrayResize(fields,0); reason=""; offset=-1;
   string value=""; bool quoted=false,afterQuote=false;
   for(int i=0;i<StringLen(record);i++)
   {
      ushort c=StringGetCharacter(record,i);
      if(quoted)
      {
         if(c==34)
         {
            if(i+1<StringLen(record) && StringGetCharacter(record,i+1)==34)
            { value+="\""; i++; }
            else { quoted=false; afterQuote=true; }
         }
         else value+=StringSubstr(record,i,1);
      }
      else if(c==44)
      {
         int n=ArraySize(fields);
         if(ArrayResize(fields,n+1)!=n+1) { reason="MEMORY_FAILURE"; offset=i; return false; }
         fields[n]=value; value=""; afterQuote=false;
      }
      else if(c==34)
      {
         if(StringLen(value)>0 || afterQuote) { reason="QUOTE_IN_UNQUOTED_FIELD"; offset=i; return false; }
         quoted=true;
      }
      else
      {
         if(afterQuote || c==10 || c==13)
         { reason=afterQuote?"CHARACTER_AFTER_CLOSING_QUOTE":"UNQUOTED_LINE_BREAK"; offset=i; return false; }
         value+=StringSubstr(record,i,1);
      }
   }
   if(quoted) { reason="UNTERMINATED_QUOTED_FIELD"; offset=StringLen(record); return false; }
   int n=ArraySize(fields);
   if(ArrayResize(fields,n+1)!=n+1) { reason="MEMORY_FAILURE"; return false; }
   fields[n]=value;
   return true;
}

bool InitializeTradeCsvIndex(string fileName)
{
   // Prefix IDs remain available for diagnosis but are never authoritative until
   // the ENTIRE file validates. Interrupted recovery cannot bless a partial scan.
   ArrayResize(gTradeCsvWrittenPIDs,0);
   gTradeCsvIndexLoaded=false; gTradeCsvAppendSafe=false;
   gTradeCsvInfrastructureUnresolved=true; gBookCsvVerifiedSize=0;
   ResetLastError();
   int h=FileOpen(fileName,FILE_READ|FILE_BIN|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h==INVALID_HANDLE) return BookCsvReject(fileName,0,0,0,"OPEN_ERROR_"+(string)GetLastError());
   gBookCsvObservedEver=true;
   ResetLastError(); ulong size=FileSize(h); int sizeError=GetLastError();
   if(sizeError!=0 || size==0 || size>67108864)
   { FileClose(h); return BookCsvReject(fileName,0,0,0,size>67108864?"SCAN_LIMIT_64_MIB":"EMPTY_OR_SIZE_QUERY_FAILED"); }
   uchar bytes[];
   if(ArrayResize(bytes,(int)size)!=(int)size)
   { FileClose(h); return BookCsvReject(fileName,0,0,0,"ALLOCATION_FAILED"); }
   ResetLastError(); uint read=FileReadArray(h,bytes,0,(int)size); int readError=GetLastError();
   ResetLastError(); ulong after=FileSize(h); int afterError=GetLastError();
   ResetLastError(); FileClose(h); int closeError=GetLastError();
   if(read!=(uint)size || readError!=0 || afterError!=0 || after!=size || closeError!=0)
      return BookCsvReject(fileName,0,0,0,"READ_FAILED_OR_CONCURRENT_SIZE_CHANGE");
   if(size>=2 && ((bytes[0]==255 && bytes[1]==254) || (bytes[0]==254 && bytes[1]==255)))
      return BookCsvReject(fileName,0,0,0,"UTF16_ENCODING_REQUIRES_EXPLICIT_MIGRATION");
   for(int i=0;i<(int)size;i++)
      if(bytes[i]==0) return BookCsvReject(fileName,0,0,0,"EMBEDDED_NUL",i);
   // UTF-8 BOM is metadata, not part of SCHEMA_VERSION; no source rewrite.
   int begin=(size>=3 && bytes[0]==239 && bytes[1]==187 && bytes[2]==191)?3:0;
   string content=CharArrayToString(bytes,begin,(int)size-begin,begin==3?CP_UTF8:CP_ACP);
   ArrayFree(bytes);
   string expectedLine=""; CsvConfigHeader(expectedLine); CsvTradeHeader(expectedLine);
   string expected[],headers[],reason=""; int errorOffset=-1;
   if(!BookCsvParse(expectedLine,expected,reason,errorOffset))
      return BookCsvReject(fileName,0,0,0,"INTERNAL_SCHEMA_"+reason,errorOffset);
   int expectedColumns=ArraySize(expected);
   int schema=-1,symbol=-1,magic=-1,pid=-1,closed=-1,accounting=-1;
   bool haveHeader=false,inQuote=false;
   long positionRows[];
   int recordStart=0,len=StringLen(content); long logicalRow=0;
   for(int i=0;i<len;i++)
   {
      ushort c=StringGetCharacter(content,i);
      if(c==34)
      {
         if(inQuote && i+1<len && StringGetCharacter(content,i+1)==34) i++;
         else inQuote=!inQuote;
      }
      if((c!=10 && c!=13) || inQuote) continue;
      string record=StringSubstr(content,recordStart,i-recordStart);
      int start=recordStart;
      if(c==13 && i+1<len && StringGetCharacter(content,i+1)==10) i++;
      recordStart=i+1; logicalRow++;
      string fields[];
      if(!BookCsvParse(record,fields,reason,errorOffset))
         return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields)+1,reason,start+errorOffset);
      if(!haveHeader)
      {
         if(ArraySize(fields)!=expectedColumns)
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"HEADER_COLUMN_COUNT",start);
         for(int k=0;k<expectedColumns;k++)
            if(fields[k]!=expected[k])
               return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"HEADER_FIELD_"+(string)(k+1)+"_EXPECTED_"+expected[k],start);
         ArrayCopy(headers,fields);
         schema=CsvColumnIndex(headers,"SCHEMA_VERSION"); symbol=CsvColumnIndex(headers,"SYMBOL");
         magic=CsvColumnIndex(headers,"MAGIC"); pid=CsvColumnIndex(headers,"POSITION_ID");
         closed=CsvColumnIndex(headers,"CLOSED"); accounting=CsvColumnIndex(headers,"ACCOUNTING_RESOLVED");
         if(schema<0 || symbol<0 || magic<0 || pid<0 || closed<0 || accounting<0)
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"INTERNAL_REQUIRED_COLUMN_MISSING",start);
         haveHeader=true;
      }
      else if(StringLen(record)>0)
      {
         if(ArraySize(fields)!=expectedColumns)
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"ROW_COLUMN_COUNT",start);
         if(fields[schema]!="RC1" || fields[symbol]!=Symbol() || fields[magic]!=IntegerToString(gMagicCore))
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"ROW_SCHEMA_OR_OWNERSHIP_MISMATCH",start);
         if(fields[closed]!="1" || (fields[accounting]!="0" && fields[accounting]!="1"))
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"INVALID_FINALIZATION_FLAGS",start);
         ulong positionID=0;
         if(!CsvParsePID(fields[pid],positionID))
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"INVALID_OR_OVERFLOW_POSITION_ID",start);
         // Amortized append; a sorted copy below detects duplicates in O(n log n)
         // instead of repeatedly scanning an entire historical ledger.
         int count=ArraySize(gTradeCsvWrittenPIDs);
         if(ArrayResize(gTradeCsvWrittenPIDs,count+1,1024)!=count+1 ||
            ArrayResize(positionRows,count+1,1024)!=count+1)
            return BookCsvReject(fileName,logicalRow,expectedColumns,ArraySize(fields),"PID_INDEX_ALLOCATION_FAILED",start);
         gTradeCsvWrittenPIDs[count]=positionID; positionRows[count]=logicalRow;
         if(fields[accounting]=="0")
         {
            if(!PersistEconomicMarker(positionID)) gEconomicMarkerScanUnresolved=true;
            RememberDeferredAccountingPID(positionID);
         }
      }
   }
   if(!haveHeader || inQuote || recordStart!=len)
   {
      string tail=StringSubstr(content,recordStart); string fields[];
      bool parsed=BookCsvParse(tail,fields,reason,errorOffset);
      return BookCsvReject(fileName,logicalRow+1,expectedColumns,ArraySize(fields)+(parsed?0:1),
            inQuote?"UNTERMINATED_QUOTED_TAIL":"UNTERMINATED_RECORD",recordStart);
   }
   ulong sorted[];
   int count=ArraySize(gTradeCsvWrittenPIDs);
   if(count>0 && (ArrayCopy(sorted,gTradeCsvWrittenPIDs)!=count || !ArraySort(sorted)))
      return BookCsvReject(fileName,0,expectedColumns,expectedColumns,"DUPLICATE_VALIDATION_ALLOCATION_FAILED");
   for(int i=1;i<count;i++)
      if(sorted[i]==sorted[i-1])
      {
         bool first=false; long duplicateRow=0;
         for(int k=0;k<count;k++)
            if(gTradeCsvWrittenPIDs[k]==sorted[i])
            { if(first) { duplicateRow=positionRows[k]; break; } first=true; }
         return BookCsvReject(fileName,duplicateRow,expectedColumns,expectedColumns,"DUPLICATE_POSITION_ID_"+(string)sorted[i]);
      }
   gTradeCsvIndexLoaded=true; gTradeCsvAppendSafe=true;
   gTradeCsvInfrastructureUnresolved=false; gBookCsvVerifiedSize=size;
   BookCsvEnsureSentinel();
   if(gBookCsvLastDiagnostic!="")
      PrintFormat("[BOOK][TRADE_CSV_RECOVERED] file=%s logical_rows=%I64d positions=%d; external repair verified without rewriting",fileName,logicalRow,ArraySize(gTradeCsvWrittenPIDs));
   gBookCsvLastDiagnostic="";
   return true;
}

// Detect external append/truncation before our next write. This protects against
// accidental second instances; concurrent writers still require operator isolation.
bool BookCsvBeforeAppend()
{
   if(csvTradeHandle==INVALID_HANDLE || !gTradeCsvAppendSafe || !gTradeCsvIndexLoaded)
      return BookCsvReject(gTradeCsvFileName,0,0,0,"APPEND_WITHOUT_VERIFIED_INDEX");
   if(!FileIsExist(gTradeCsvFileName))
      return BookCsvReject(gTradeCsvFileName,0,0,0,"PREVIOUS_FINANCIAL_FILE_MISSING");
   ResetLastError(); ulong size=FileSize(csvTradeHandle); int error=GetLastError();
   if(error!=0 || size!=gBookCsvVerifiedSize || !FileSeek(csvTradeHandle,0,SEEK_END))
      return BookCsvReject(gTradeCsvFileName,0,0,0,"FILE_CHANGED_SINCE_VERIFIED_SCAN");
   return true;
}

bool BookCsvRecoveryPathAllowed()
{
   ResetLastError(); bool exists=FileIsExist(gTradeCsvFileName); int error=GetLastError();
   bool evidence=(gTradeRecordCount>0 || ordersEnteredToday>0 ||
      gPendingExec.active || gPendingExit.active || gOpenPos.active);
   if(!exists && ((error!=0 && error!=ERR_FILE_NOT_EXIST) ||
      !BookCsvCanCreateMissing(gBookCsvObservedEver,BookCsvSentinelStatus()==0,evidence)))
      return BookCsvReject(gTradeCsvFileName,0,0,0,"PREVIOUS_FINANCIAL_FILE_MISSING_OR_PROBE_UNCERTAIN");
   return true;
}

int BookCsvOpenInitialFile()
{
   ResetLastError(); bool exists=FileIsExist(gTradeCsvFileName); int probeError=GetLastError();
   if(!exists && probeError!=0 && probeError!=ERR_FILE_NOT_EXIST)
   { BookCsvReject(gTradeCsvFileName,0,0,0,"INITIAL_PATH_PROBE_UNCERTAIN"); return INVALID_HANDLE; }
   // A missing trade file alongside recovered trade/request evidence is loss of
   // evidence, never an invitation to recreate an empty historical ledger.
   bool evidence=(gTradeRecordCount>0 || ordersEnteredToday>0 ||
      gPendingExec.active || gPendingExit.active || gOpenPos.active);
   if(!exists && !BookCsvCanCreateMissing(gBookCsvObservedEver,BookCsvSentinelStatus()==0,evidence))
   { BookCsvReject(gTradeCsvFileName,0,0,0,"MISSING_FILE_WITH_RECOVERED_FINANCIAL_EVIDENCE"); return INVALID_HANDLE; }
   ResetLastError();
   int h=FileOpen(gTradeCsvFileName,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h==INVALID_HANDLE)
   { BookCsvReject(gTradeCsvFileName,0,0,0,"INITIAL_OPEN_FAILED"); return INVALID_HANDLE; }
   ResetLastError(); ulong size=FileSize(h); int sizeError=GetLastError();
   if(sizeError!=0 || (exists && size==0))
   {
      FileClose(h); gBookCsvObservedEver=exists;
      BookCsvReject(gTradeCsvFileName,0,0,0,sizeError!=0?"INITIAL_SIZE_UNVERIFIED":"EXISTING_EMPTY_FILE_PRESERVED");
      return INVALID_HANDLE;
   }
   gBookCsvObservedEver=true;
   return h;
}
#endif
// END_INCORPORATED Include/BookCsvDiagnostics.mqh
// ORIGINAL_INCLUDE | #include "Include\BookIdentity.mqh"
// BEGIN_INCORPORATED Include/BookIdentity.mqh
#ifndef BOOK_IDENTITY_MQH
#define BOOK_IDENTITY_MQH
// ORIGINAL_INCLUDE | #include "BookBuildIdentity.mqh"
// BEGIN_INCORPORATED Include/BookBuildIdentity.mqh
// Generated provenance, not a native compilation certificate.
#ifndef BOOK_BUILD_IDENTITY_MQH
#define BOOK_BUILD_IDENTITY_MQH
#define BOOK_BASELINE_REVISION "a31f7b03701dd13b5c26801669552001d3ed634c"
#define BOOK_REVISION_AT_GENERATION "815077efec40adf1897bcf64640756bb46c4c118"
#define BOOK_BUILD_ID "BOOK1125_SURGERY_EXP1"
#define BOOK_SOURCE_BUNDLE_SHA256 "82f31e5fa90f26602e2a5fa1b41500cf06cf9c02e53518ab766415f5819d7c86"
#endif
// END_INCORPORATED Include/BookBuildIdentity.mqh
// Identity is telemetry only: failure never authorizes or changes an order.
string gBookConfigHash="UNAVAILABLE",gBookRunID="UNAVAILABLE";
string gBookCanonicalInputs="";
int gBookLoadedInputCount=0;
datetime gBookRunServerTime=0;
bool gBookIdentityReady=false;

void BookIdentityAdd(string &canonical,const string type,const string name,const string value)
{
   // Lengths are UTF-16 code units (MQL5 StringLen), payload hashes UTF-8 bytes.
   canonical+=(string)StringLen(type)+":"+type+(string)StringLen(name)+":"+name+
      (string)StringLen(value)+":"+value+"\n";
   gBookLoadedInputCount++;
}

bool BookIdentityHash(const string payload,string &hash)
{
   hash="UNAVAILABLE"; uchar bytes[],key[],digest[];
   int count=StringToCharArray(payload,bytes,0,WHOLE_ARRAY,CP_UTF8);
   if(count<1 || ArrayResize(bytes,count-1)!=count-1) return false;
   ResetLastError();
   if(CryptEncode(CRYPT_HASH_SHA256,bytes,key,digest)!=32 || GetLastError()!=0 || ArraySize(digest)!=32)
      return false;
   hash="";
   for(int i=0;i<32;i++) hash+=StringFormat("%02x",(uint)digest[i]);
   return true;
}

// ORIGINAL_INCLUDE | #include "BookInputSnapshot.mqh"
// BEGIN_INCORPORATED Include/BookInputSnapshot.mqh
// Generated by tools/generate_identity_inputs.py; actual loaded values.
#ifndef BOOK_INPUT_SNAPSHOT_MQH
#define BOOK_INPUT_SNAPSHOT_MQH
void BookCollectInputIdentity(string &canonical)
{
   BookIdentityAdd(canonical,"int","Inp_Magic_WIN",(string)(int)Inp_Magic_WIN);
   BookIdentityAdd(canonical,"int","Inp_Magic_WDO",(string)(int)Inp_Magic_WDO);
   BookIdentityAdd(canonical,"string","CSVFileName",CSVFileName);
   BookIdentityAdd(canonical,"datetime","BacktestStart",(string)(long)BacktestStart);
   BookIdentityAdd(canonical,"ENUM_TIMEFRAMES","Inp_ContextTF",(string)(int)Inp_ContextTF);
   BookIdentityAdd(canonical,"ENUM_TIMEFRAMES","Inp_SignalTF",(string)(int)Inp_SignalTF);
   BookIdentityAdd(canonical,"int","Inp_StartHHMM",(string)(int)Inp_StartHHMM);
   BookIdentityAdd(canonical,"int","Inp_StopEntryHHMM",(string)(int)Inp_StopEntryHHMM);
   BookIdentityAdd(canonical,"int","Inp_EOD_CloseHHMM",(string)(int)Inp_EOD_CloseHHMM);
   BookIdentityAdd(canonical,"SIZING_MODE","Inp_SizingMode",(string)(int)Inp_SizingMode);
   BookIdentityAdd(canonical,"double","Inp_FixedLots",StringFormat("%.17g",Inp_FixedLots));
   BookIdentityAdd(canonical,"double","Inp_RiskPerTradePct",StringFormat("%.17g",Inp_RiskPerTradePct));
   BookIdentityAdd(canonical,"double","Inp_MaxLots",StringFormat("%.17g",Inp_MaxLots));
   BookIdentityAdd(canonical,"double","Inp_SL_Pts_WIN",StringFormat("%.17g",Inp_SL_Pts_WIN));
   BookIdentityAdd(canonical,"double","Inp_TP_Pts_WIN",StringFormat("%.17g",Inp_TP_Pts_WIN));
   BookIdentityAdd(canonical,"double","Inp_SL_Pts_WDO",StringFormat("%.17g",Inp_SL_Pts_WDO));
   BookIdentityAdd(canonical,"double","Inp_TP_Pts_WDO",StringFormat("%.17g",Inp_TP_Pts_WDO));
   BookIdentityAdd(canonical,"double","Inp_SpreadMaxPts_WIN",StringFormat("%.17g",Inp_SpreadMaxPts_WIN));
   BookIdentityAdd(canonical,"double","Inp_SpreadMaxPts_WDO",StringFormat("%.17g",Inp_SpreadMaxPts_WDO));
   BookIdentityAdd(canonical,"bool","Inp_EnableBreakEven",(Inp_EnableBreakEven?"1":"0"));
   BookIdentityAdd(canonical,"bool","Inp_EnableDailyRiskStop",(Inp_EnableDailyRiskStop?"1":"0"));
   BookIdentityAdd(canonical,"double","Inp_MaxDailyLossR",StringFormat("%.17g",Inp_MaxDailyLossR));
   BookIdentityAdd(canonical,"bool","Inp_EnableConsecutiveLossStop",(Inp_EnableConsecutiveLossStop?"1":"0"));
   BookIdentityAdd(canonical,"int","Inp_MaxConsecutiveLosses",(string)(int)Inp_MaxConsecutiveLosses);
   BookIdentityAdd(canonical,"int","Inp_MaxTradesDay",(string)(int)Inp_MaxTradesDay);
   BookIdentityAdd(canonical,"int","Inp_CooldownSec",(string)(int)Inp_CooldownSec);
   BookIdentityAdd(canonical,"int","Inp_LossCooldownSec",(string)(int)Inp_LossCooldownSec);
   BookIdentityAdd(canonical,"int","Inp_ArmedTimeoutSec",(string)(int)Inp_ArmedTimeoutSec);
   BookIdentityAdd(canonical,"int","Inp_Region_Candles",(string)(int)Inp_Region_Candles);
   BookIdentityAdd(canonical,"double","Inp_BreakoutMargin_WIN",StringFormat("%.17g",Inp_BreakoutMargin_WIN));
   BookIdentityAdd(canonical,"double","Inp_BreakoutMargin_WDO",StringFormat("%.17g",Inp_BreakoutMargin_WDO));
   BookIdentityAdd(canonical,"double","Inp_MaxOvershoot_WIN",StringFormat("%.17g",Inp_MaxOvershoot_WIN));
   BookIdentityAdd(canonical,"double","Inp_MaxOvershoot_WDO",StringFormat("%.17g",Inp_MaxOvershoot_WDO));
   BookIdentityAdd(canonical,"double","Inp_ABS_Effort",StringFormat("%.17g",Inp_ABS_Effort));
   BookIdentityAdd(canonical,"double","Inp_CONT_Effort",StringFormat("%.17g",Inp_CONT_Effort));
   BookIdentityAdd(canonical,"double","Inp_ABS_BreakoutEffort",StringFormat("%.17g",Inp_ABS_BreakoutEffort));
   BookIdentityAdd(canonical,"double","Inp_CONT_BreakoutEffort",StringFormat("%.17g",Inp_CONT_BreakoutEffort));
   BookIdentityAdd(canonical,"int","Inp_POC_WindowSec",(string)(int)Inp_POC_WindowSec);
   BookIdentityAdd(canonical,"double","Inp_POC_FollowRatio",StringFormat("%.17g",Inp_POC_FollowRatio));
   BookIdentityAdd(canonical,"bool","Inp_RejectPOCTies",(Inp_RejectPOCTies?"1":"0"));
   BookIdentityAdd(canonical,"double","Inp_ABS_MinPriceMovePts_WIN",StringFormat("%.17g",Inp_ABS_MinPriceMovePts_WIN));
   BookIdentityAdd(canonical,"double","Inp_ABS_MaxBodyPts_WIN",StringFormat("%.17g",Inp_ABS_MaxBodyPts_WIN));
   BookIdentityAdd(canonical,"double","Inp_ABS_MinPriceMovePts_WDO",StringFormat("%.17g",Inp_ABS_MinPriceMovePts_WDO));
   BookIdentityAdd(canonical,"double","Inp_ABS_MaxBodyPts_WDO",StringFormat("%.17g",Inp_ABS_MaxBodyPts_WDO));
   BookIdentityAdd(canonical,"double","Inp_CONT_MinPriceMovePts_WIN",StringFormat("%.17g",Inp_CONT_MinPriceMovePts_WIN));
   BookIdentityAdd(canonical,"double","Inp_CONT_MinPriceMovePts_WDO",StringFormat("%.17g",Inp_CONT_MinPriceMovePts_WDO));
   BookIdentityAdd(canonical,"bool","Inp_Cont_RequireCandleDirection",(Inp_Cont_RequireCandleDirection?"1":"0"));
   BookIdentityAdd(canonical,"double","BandMultiplier",StringFormat("%.17g",BandMultiplier));
   BookIdentityAdd(canonical,"double","Inp_VWAP_Inner_Pct",StringFormat("%.17g",Inp_VWAP_Inner_Pct));
   BookIdentityAdd(canonical,"double","Inp_VWAP_Outer_Pct",StringFormat("%.17g",Inp_VWAP_Outer_Pct));
   BookIdentityAdd(canonical,"double","Inp_Rule_40_60",StringFormat("%.17g",Inp_Rule_40_60));
   BookIdentityAdd(canonical,"double","Inp_C2_WIN",StringFormat("%.17g",Inp_C2_WIN));
   BookIdentityAdd(canonical,"double","Inp_C3_Min_WIN",StringFormat("%.17g",Inp_C3_Min_WIN));
   BookIdentityAdd(canonical,"double","Inp_C3_Max_WIN",StringFormat("%.17g",Inp_C3_Max_WIN));
   BookIdentityAdd(canonical,"double","Inp_C2_WDO",StringFormat("%.17g",Inp_C2_WDO));
   BookIdentityAdd(canonical,"double","Inp_C3_Min_WDO",StringFormat("%.17g",Inp_C3_Min_WDO));
   BookIdentityAdd(canonical,"double","Inp_C3_Max_WDO",StringFormat("%.17g",Inp_C3_Max_WDO));
   BookIdentityAdd(canonical,"int","SigmaLookbackDays",(string)(int)SigmaLookbackDays);
   BookIdentityAdd(canonical,"double","Inp_SigmaFloor_WIN",StringFormat("%.17g",Inp_SigmaFloor_WIN));
   BookIdentityAdd(canonical,"double","Inp_SigmaFloor_WDO",StringFormat("%.17g",Inp_SigmaFloor_WDO));
   BookIdentityAdd(canonical,"int","Inp_MaxDeviationPts_WIN",(string)(int)Inp_MaxDeviationPts_WIN);
   BookIdentityAdd(canonical,"int","Inp_MaxDeviationPts_WDO",(string)(int)Inp_MaxDeviationPts_WDO);
   BookIdentityAdd(canonical,"bool","Inp_EnableMacroDirectionGate",(Inp_EnableMacroDirectionGate?"1":"0"));
   BookIdentityAdd(canonical,"bool","Inp_EnableLateDirectionBlock",(Inp_EnableLateDirectionBlock?"1":"0"));
   BookIdentityAdd(canonical,"bool","Inp_EnableAbsorption",(Inp_EnableAbsorption?"1":"0"));
   BookIdentityAdd(canonical,"bool","Inp_EnableContinuation",(Inp_EnableContinuation?"1":"0"));
   BookIdentityAdd(canonical,"bool","Inp_DOM_Enable",(Inp_DOM_Enable?"1":"0"));
   BookIdentityAdd(canonical,"string","Inp_DOM_InstanceTag",Inp_DOM_InstanceTag);
   BookIdentityAdd(canonical,"bool","Inp_DOM_TradeGateEnable",(Inp_DOM_TradeGateEnable?"1":"0"));
   BookIdentityAdd(canonical,"double","Inp_DOM_MinDominancePct",StringFormat("%.17g",Inp_DOM_MinDominancePct));
   BookIdentityAdd(canonical,"ENUM_RESPONSE_MODE","Inp_ResponseMode",(string)(int)Inp_ResponseMode);
   BookIdentityAdd(canonical,"bool","Inp_ObserveMicrostructure",(Inp_ObserveMicrostructure?"1":"0"));
   BookIdentityAdd(canonical,"bool","Inp_Obs_TrustAggressorFlags",(Inp_Obs_TrustAggressorFlags?"1":"0"));
   BookIdentityAdd(canonical,"double","Inp_Obs_Min_Displ_Sigma",StringFormat("%.17g",Inp_Obs_Min_Displ_Sigma));
   BookIdentityAdd(canonical,"double","Inp_Obs_Max_Body_Sigma",StringFormat("%.17g",Inp_Obs_Max_Body_Sigma));
   BookIdentityAdd(canonical,"double","Inp_Obs_Cont_Min_Displ_Sigma",StringFormat("%.17g",Inp_Obs_Cont_Min_Displ_Sigma));
   BookIdentityAdd(canonical,"int","Inp_Obs_WindowBudgetUS",(string)(int)Inp_Obs_WindowBudgetUS);
   BookIdentityAdd(canonical,"ENUM_BOOK_SL_MODE","Inp_SL_Mode",(string)(int)Inp_SL_Mode);
   BookIdentityAdd(canonical,"double","Inp_Mult_SL",StringFormat("%.17g",Inp_Mult_SL));
   BookIdentityAdd(canonical,"double","Inp_Max_SL_Pts_WIN",StringFormat("%.17g",Inp_Max_SL_Pts_WIN));
   BookIdentityAdd(canonical,"double","Inp_Max_SL_Pts_WDO",StringFormat("%.17g",Inp_Max_SL_Pts_WDO));
   BookIdentityAdd(canonical,"double","BE_Trigger_R",StringFormat("%.17g",BE_Trigger_R));
   BookIdentityAdd(canonical,"bool","EnableProfitLocks",(EnableProfitLocks?"1":"0"));
   BookIdentityAdd(canonical,"double","Lock1_Trigger_R",StringFormat("%.17g",Lock1_Trigger_R));
   BookIdentityAdd(canonical,"double","Lock1_Protected_R",StringFormat("%.17g",Lock1_Protected_R));
   BookIdentityAdd(canonical,"double","Lock2_Trigger_R",StringFormat("%.17g",Lock2_Trigger_R));
   BookIdentityAdd(canonical,"double","Lock2_Protected_R",StringFormat("%.17g",Lock2_Protected_R));
   BookIdentityAdd(canonical,"ENUM_BOOK_TP_MODE","Inp_TP_Mode",(string)(int)Inp_TP_Mode);
   BookIdentityAdd(canonical,"double","TP_BASE_R",StringFormat("%.17g",TP_BASE_R));
   BookIdentityAdd(canonical,"double","TP_TURBO_R",StringFormat("%.17g",TP_TURBO_R));
   BookIdentityAdd(canonical,"bool","Inp_EnableArmedDiagnostics",(Inp_EnableArmedDiagnostics?"1":"0"));
   BookIdentityAdd(canonical,"ENUM_BOOK_DECISION_MODE","Inp_DecisionMode",(string)(int)Inp_DecisionMode);
   BookIdentityAdd(canonical,"ENUM_BOOK_DECISION_SOURCE","Inp_DecisionAggressorSource",(string)(int)Inp_DecisionAggressorSource);
   BookIdentityAdd(canonical,"int","Inp_DecisionWindowSec",(string)(int)Inp_DecisionWindowSec);
   BookIdentityAdd(canonical,"int","Inp_DecisionMinReferences",(string)(int)Inp_DecisionMinReferences);
   BookIdentityAdd(canonical,"double","Inp_DecisionEffortQuantile",StringFormat("%.17g",Inp_DecisionEffortQuantile));
   BookIdentityAdd(canonical,"double","Inp_DecisionResultQuantile",StringFormat("%.17g",Inp_DecisionResultQuantile));
   BookIdentityAdd(canonical,"double","Inp_DecisionMinCoverage",StringFormat("%.17g",Inp_DecisionMinCoverage));
   BookIdentityAdd(canonical,"double","Inp_DecisionMinDirectionalShare",StringFormat("%.17g",Inp_DecisionMinDirectionalShare));
   BookIdentityAdd(canonical,"double","Inp_DecisionMinAcceptance",StringFormat("%.17g",Inp_DecisionMinAcceptance));
   BookIdentityAdd(canonical,"double","Inp_DecisionMinObservedCoverage",StringFormat("%.17g",Inp_DecisionMinObservedCoverage));
   BookIdentityAdd(canonical,"double","Inp_DecisionMinProgressTicks",StringFormat("%.17g",Inp_DecisionMinProgressTicks));
   BookIdentityAdd(canonical,"double","Inp_DecisionComparableEffortFactor",StringFormat("%.17g",Inp_DecisionComparableEffortFactor));
}
#endif
// END_INCORPORATED Include/BookInputSnapshot.mqh

string BookIdentityField(string value)
{
   StringReplace(value,"\"","\"\"");
   return "\""+value+"\"";
}

void BookIdentityInit()
{
   gBookIdentityReady=false;
   gBookRunServerTime=TimeTradeServer();
   // Cryptographic service failure must never merge all failed runs under one
   // filename. This non-secret fallback is a namespace, not a configuration hash.
   gBookRunID="UNHASHED_"+(string)(long)TimeLocal()+"_"+(string)ChartID()+"_"+
      (string)GetMicrosecondCount()+"_"+(string)GetTickCount64();
   gBookLoadedInputCount=0; gBookCanonicalInputs="";
   BookCollectInputIdentity(gBookCanonicalInputs);
   if(!BookIdentityHash("BOOK_INPUT_CANONICAL_V1\n"+gBookCanonicalInputs,gBookConfigHash))
      Print("[BOOK][IDENTITY_HASH_UNAVAILABLE] unique run namespace retained; no configuration equivalence claim possible");
   string context=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
      AccountInfoString(ACCOUNT_SERVER)+"|"+Symbol()+"|"+(string)gMagicCore+"|"+
      gBookConfigHash+"|"+(string)(long)gBookRunServerTime+"|"+(string)ChartID()+"|"+
      (string)GetMicrosecondCount()+"|"+(string)GetTickCount64();
   string hashedRun="";
   if(BookIdentityHash(context,hashedRun)) gBookRunID=hashedRun;
   // Unique run/context namespace: old Audit/Shadow financial schemas unchanged.
   string path="BOOK_1125_CONTEXT_"+gBookRunID+".csv";
   string baseRun=gBookRunID;
   for(int retry=0;FileIsExist(path) && retry<16;retry++)
   {
      gBookRunID=baseRun+"_"+(string)(retry+1);
      path="BOOK_1125_CONTEXT_"+gBookRunID+".csv";
   }
   if(FileIsExist(path))
   { Print("[BOOK][IDENTITY_COLLISION] existing contexts preserved; run telemetry suspended: ",path); return; }
   ResetLastError();
   int h=FileOpen(path,FILE_WRITE|FILE_BIN);
   if(h==INVALID_HANDLE)
   { Print("[BOOK][IDENTITY_WRITE_FAILED] error=",GetLastError()); return; }
   string line="schema,run_id,config_hash,declared_version,baseline_revision,revision_at_generation,build_id,source_bundle_sha256,symbol,account,server,magic,server_time,historical_inputs,total_inputs,volumes,canonical_inputs\r\n";
   line+="BOOK_CONTEXT_V1,"+gBookRunID+","+gBookConfigHash+",1.125,"+
      BOOK_BASELINE_REVISION+","+BOOK_REVISION_AT_GENERATION+","+BOOK_BUILD_ID+","+
      BOOK_SOURCE_BUNDLE_SHA256+","+BookIdentityField(Symbol())+","+
      (string)AccountInfoInteger(ACCOUNT_LOGIN)+","+BookIdentityField(AccountInfoString(ACCOUNT_SERVER))+","+
      (string)gMagicCore+","+(string)(long)gBookRunServerTime+",71,"+
      (string)gBookLoadedInputCount+","+
      BookIdentityField("POC/VWAP ticks=MqlTick.volume integer; flags buy/sell/unknown; Weis/D1=real_volume when available else tick_count, source observed per snapshot; units not interchangeable")+","+
      BookIdentityField(gBookCanonicalInputs)+"\r\n";
   uchar encoded[]; int count=StringToCharArray(line,encoded,0,WHOLE_ARRAY,CP_UTF8);
   ResetLastError();
   uint written=(count>1)?FileWriteArray(h,encoded,0,count-1):0;
   int error=GetLastError();
   ResetLastError(); FileFlush(h); int flushError=GetLastError();
   ResetLastError(); FileClose(h); int closeError=GetLastError();
   if(count<=1 || written!=(uint)(count-1) || error!=0 || flushError!=0 || closeError!=0)
   { Print("[BOOK][IDENTITY_WRITE_FAILED] partial context retained; run telemetry suspended: ",path); return; }
   gBookIdentityReady=true;
   PrintFormat("[BOOK][RUN_CONTEXT] declared_version=1.125 baseline=%s build=%s loaded_inputs=%d historical_inputs=71 config_sha256=%s run_id=%s context=%s; experimental, native compilation pending",
               BOOK_BASELINE_REVISION,BOOK_BUILD_ID,gBookLoadedInputCount,gBookConfigHash,gBookRunID,path);
}

// New telemetry files include these fields; old RC1 trade schema remains legible.
void BookIdentityAppendContext(string &line)
{
   CsvAdd(line,gBookRunID); CsvAdd(line,gBookConfigHash);
}

void BookIdentityAuditHeader(string &line)
{
   CsvAdd(line,"OBSERVED_RUN_ID"); CsvAdd(line,"OBSERVED_CONFIG_SHA256");
   CsvAdd(line,"OBSERVED_POSITION_ID"); CsvAdd(line,"PENDING_ENTRY_ORDER");
   CsvAdd(line,"PENDING_ENTRY_DEAL"); CsvAdd(line,"PENDING_ENTRY_REQUEST_ID");
   CsvAdd(line,"PENDING_EXIT_POSITION_ID"); CsvAdd(line,"PENDING_EXIT_ORDER");
   CsvAdd(line,"PENDING_EXIT_REQUEST_ID");
   CsvAdd(line,"IDENTITY_SCOPE");
}

void BookIdentityAuditRow(string &line)
{
   BookIdentityAppendContext(line);
   CsvAdd(line,gOpenPos.active?(string)gOpenPos.positionID:"");
   CsvAdd(line,gPendingExec.active?(string)gPendingExec.orderTicket:"");
   CsvAdd(line,gPendingExec.active?(string)gPendingExec.resultDeal:"");
   CsvAdd(line,gPendingExec.active?(string)gPendingExec.requestID:"");
   CsvAdd(line,gPendingExit.active?(string)gPendingExit.positionID:"");
   CsvAdd(line,gPendingExit.active?(string)gPendingExit.orderTicket:"");
   CsvAdd(line,gPendingExit.active?(string)gPendingExit.requestID:"");
   CsvAdd(line,"OBSERVED_CONTEXT_NOT_HISTORICAL_ORIGIN_PROOF");
}

void BookIdentityCorrelateTrade(const TradeRecord &record)
{
   if(!gBookIdentityReady) return;
   // Exact record identifiers only. A recovered record does not acquire this
   // run's configuration retrospectively; historical origin remains unproven.
   string path="BOOK_1125_"+gBookRunID+"_TradeContexts.csv";
   ResetLastError();
   int h=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) { Print("[BOOK][TRADE_CONTEXT_WRITE_FAILED]",GetLastError()); return; }
   string row="";
   if(FileSize(h)==0)
      row="observed_run_id,observed_config_sha256,position_id,entry_order,last_exit_deal,route,mode,entry_time,exit_time,server_time,identity_scope\r\n";
   string fields="";
   BookIdentityAppendContext(fields);
   CsvAdd(fields,(string)record.positionID); CsvAdd(fields,(string)record.entryOrderTicket);
   CsvAdd(fields,(string)record.lastExitDealTicket); CsvAdd(fields,record.route); CsvAdd(fields,record.mode);
   CsvAdd(fields,(string)(long)record.entryTime); CsvAdd(fields,(string)(long)record.exitTime);
   CsvAdd(fields,(string)(long)TimeTradeServer());
   CsvAdd(fields,"FINALIZATION_OBSERVED_HERE_ORIGINAL_PRESET_UNPROVEN_IF_RECOVERED");
   row+=fields+"\r\n";
   bool seek=FileSeek(h,0,SEEK_END);
   ResetLastError();
   uint written=seek?FileWriteString(h,row):0;
   int error=GetLastError();
   FileFlush(h); int flushError=GetLastError(); FileClose(h);
   if(!seek || written==0 || error!=0 || flushError!=0)
      Print("[BOOK][TRADE_CONTEXT_WRITE_FAILED] partial telemetry retained; financial row unaffected");
}
#endif
// END_INCORPORATED Include/BookIdentity.mqh

void CsvConfigHeader(string &line)
{
  CsvAdd(line,"SCHEMA_VERSION");
  CsvAdd(line,"MACRO_GATE_ENABLED");
  CsvAdd(line,"LATE_DIRECTION_BLOCK_ENABLED");
  CsvAdd(line,"REJECT_POC_TIES");
  CsvAdd(line,"SYMBOL");
  CsvAdd(line,"MAGIC");
}

void CsvConfigRow(string &line)
{
  CsvAdd(line,"RC1"); // SCHEMA_VERSION
  CsvAdd(line,BStr(Inp_EnableMacroDirectionGate)); // MACRO_GATE_ENABLED
  CsvAdd(line,BStr(Inp_EnableLateDirectionBlock)); //
// LATE_DIRECTION_BLOCK_ENABLED
  CsvAdd(line,BStr(Inp_RejectPOCTies)); // REJECT_POC_TIES
  CsvAdd(line,Symbol()); // SYMBOL
  CsvAdd(line,IntegerToString(gMagicCore)); // MAGIC
}

void CsvMacroHeader(string &line)
{
  CsvAdd(line,"MACRO_STATUS");
  CsvAdd(line,"CONTEXT_BAR");
  CsvAdd(line,"MACRO_CLOSED_PRICE");
  CsvAdd(line,"MACRO_VWAP");
  CsvAdd(line,"MACRO_SIGMA_D1");
  CsvAdd(line,"MACRO_DIST_VWAP_D1");
  CsvAdd(line,"MACRO_POSREL");
  CsvAdd(line,"MACRO_GLASS");
  CsvAdd(line,"MACRO_ABS_DIR");
  CsvAdd(line,"MACRO_CONT_DIR");
}
void CsvMacroRow(string &line)
{
  CsvAdd(line,MacroStatusStr(gMacro.status)); // MACRO_STATUS
  CsvAdd(line,CsvTime(gMacro.barTime)); // CONTEXT_BAR
  CsvAdd(line,CsvD(gMacro.closedPrice)); // MACRO_CLOSED_PRICE
  CsvAdd(line,CsvD(gMacro.vwap)); // MACRO_VWAP
  CsvAdd(line,CsvD(gMacro.SigmaD1)); // MACRO_SIGMA_D1
  CsvAdd(line,CsvD(gMacro.distVWAP_D1)); // MACRO_DIST_VWAP_D1
  CsvAdd(line,CsvD(gMacro.posRel)); // MACRO_POSREL
  CsvAdd(line,BStr(gMacro.glass)); // MACRO_GLASS
  CsvAdd(line,DirStr(gMacro.macroAbsDir)); // MACRO_ABS_DIR
  CsvAdd(line,DirStr(gMacro.macroContDir)); // MACRO_CONT_DIR
}

void CsvMatrixHeader(string &line)
{
 CsvAdd(line,"MATRIX_SNAPSHOT_AVAILABLE");
 CsvAdd(line,"SIGNAL_BAR");
 CsvAdd(line,"MATRIX_STATUS");
 CsvAdd(line,"ROUTE");
 CsvAdd(line,"MODE");
 CsvAdd(line,"DIR");
 CsvAdd(line,"PRICE");
 CsvAdd(line,"OPEN");
 CsvAdd(line,"CANDLE_BODY");
 CsvAdd(line,"CANDLE_DIR");
 CsvAdd(line,"POSREL");
 CsvAdd(line,"POS_RANGE");
 CsvAdd(line,"GLASS");
 CsvAdd(line,"DIST_VWAP_D1");
 CsvAdd(line,"VWAP_VIG");
 CsvAdd(line,"UPPER_BAND");
 CsvAdd(line,"LOWER_BAND");
 CsvAdd(line,"BAND_RANGE");
 CsvAdd(line,"SIGMA_D1");
 CsvAdd(line,"VWAP_D1");
 CsvAdd(line,"H1");
 CsvAdd(line,"L1");
 CsvAdd(line,"ABS_DIR");
 CsvAdd(line,"CONT_DIR");
 CsvAdd(line,"C1");
 CsvAdd(line,"C2");
 CsvAdd(line,"C3");
 CsvAdd(line,"C4");
 CsvAdd(line,"C5");
 CsvAdd(line,"C23");
 CsvAdd(line,"BASE");
CsvAdd(line,"TURBO");
CsvAdd(line,"CONT_C1");
CsvAdd(line,"CONT_C2");
CsvAdd(line,"CONT_C3");
CsvAdd(line,"CONT_C4");
CsvAdd(line,"CONT_C5");
CsvAdd(line,"CONT_C23");
CsvAdd(line,"CONT_BASE");
CsvAdd(line,"CONT_TURBO");
CsvAdd(line,"ABS_SCORE");
CsvAdd(line,"CONT_SCORE");
CsvAdd(line,"ABS_VALID");
CsvAdd(line,"CONT_VALID");
CsvAdd(line,"MACRO_ABS_COMPATIBLE");
CsvAdd(line,"MACRO_CONT_COMPATIBLE");
CsvAdd(line,"WW_VALID");
CsvAdd(line,"WW_EFFORT");
CsvAdd(line,"WW_DIR");
CsvAdd(line,"WW_WAVE_BARS");
CsvAdd(line,"WW_WAVE_AGE_SEC");
CsvAdd(line,"WW_ACCUM_VOLUME");
CsvAdd(line,"WW_DISTANCE_PTS");
CsvAdd(line,"WINDOWS_VALID");
CsvAdd(line,"ABS_POC_STATE");
CsvAdd(line,"CONT_POC_STATE");
CsvAdd(line,"ABS_MIN_MOVE");
CsvAdd(line,"ABS_MAX_BODY");
CsvAdd(line,"CONT_MIN_MOVE");
CsvAdd(line,"ABS_DISPLACEMENT_OK");
CsvAdd(line,"CONT_DISPLACEMENT_OK");
CsvAdd(line,"ABS_DIVERGENCE");
CsvAdd(line,"ABS_STALL_STRICT");
CsvAdd(line,"ABS_BODY_OK");
CsvAdd(line,"ABS_FOLLOWING_REACTION");
CsvAdd(line,"ABS_FOLLOWING_EXTENSION");
CsvAdd(line,"ABS_EFFORT_OK");
CsvAdd(line,"CONT_EFFORT_OK");
CsvAdd(line,"CONT_POC_OK");
CsvAdd(line,"CONT_MOVE_DIR_OK");
CsvAdd(line,"CONT_WAVE_DIR_OK");
CsvAdd(line,"CONT_CANDLE_DIR_OK");
CsvAdd(line,"PRICE_MOVE");
CsvAdd(line,"POC_MOVE");
CsvAdd(line,"MOVE_DIR");
CsvAdd(line,"CONT_MOVE_DIR");
CsvAdd(line,"POC_NOW");
CsvAdd(line,"POC_NOW_VOLUME");
CsvAdd(line,"POC_NOW_WINDOW_STATE");
CsvAdd(line,"POC_NOW_TIE");
CsvAdd(line,"POC_NOW_TRADE_COUNT");
CsvAdd(line,"POC_NOW_LEVELS");
CsvAdd(line,"POC_NOW_LAST_PRICE");
CsvAdd(line,"POC_NOW_TOP1_PRICE");
CsvAdd(line,"POC_NOW_TOP1_VOL");
CsvAdd(line,"POC_NOW_TOP2_PRICE");
CsvAdd(line,"POC_NOW_TOP2_VOL");
CsvAdd(line,"POC_NOW_DOMINANCE");
CsvAdd(line,"AGG_BUY_NOW");
CsvAdd(line,"AGG_SELL_NOW");
CsvAdd(line,"AGG_UNKNOWN_NOW");
CsvAdd(line,"AGG_DELTA_NOW");
CsvAdd(line,"AGG_IMBALANCE_NOW");
CsvAdd(line,"AGG_KNOWN_PCT_NOW");
CsvAdd(line,"POC_PREV");
  CsvAdd(line,"POC_PREV_VOLUME");
  CsvAdd(line,"POC_PREV_WINDOW_STATE");
  CsvAdd(line,"POC_PREV_TIE");
  CsvAdd(line,"POC_PREV_TRADE_COUNT");
  CsvAdd(line,"POC_PREV_LEVELS");
  CsvAdd(line,"POC_PREV_LAST_PRICE");
  CsvAdd(line,"POC_PREV_TOP1_PRICE");
  CsvAdd(line,"POC_PREV_TOP1_VOL");
  CsvAdd(line,"POC_PREV_TOP2_PRICE");
  CsvAdd(line,"POC_PREV_TOP2_VOL");
  CsvAdd(line,"POC_PREV_DOMINANCE");
  CsvAdd(line,"AGG_BUY_PREV");
  CsvAdd(line,"AGG_SELL_PREV");
  CsvAdd(line,"AGG_UNKNOWN_PREV");
  CsvAdd(line,"AGG_DELTA_PREV");
  CsvAdd(line,"AGG_IMBALANCE_PREV");
  CsvAdd(line,"AGG_KNOWN_PCT_PREV");
  CsvAdd(line,"FLOW_REGIME");
  CsvAdd(line,"VOL_RATIO");
  CsvAdd(line,"PRICE_EFFICIENCY");
  CsvAdd(line,"POC_RESPONSE");
}

void CsvMatrixRow(string &line,const MatrixSnapshot &s,bool available,datetime signalBar)
{
  string route = s.absValid && s.contValid ? "CONFLICT" :
      (s.absValid ? "ABS" : (s.contValid ? "CONT" : "NONE"));
  string mode = s.absValid && s.contValid ? "CONFLICT" :
     (s.absValid ? (s.turboAbs ? "TURBO" : "BASE") :
      (s.contValid ? (s.turboCont ? "TURBO" : "BASE") : "NONE"));
  int direction = s.absValid && !s.contValid ? s.dir :
       (s.contValid && !s.absValid ? s.dirCont : 0);
// These four formulas are executable diagnostics in canonical v2.44.
// They remain telemetry and cannot change ABS/CONT or execution.
string flowRegime = !s.c1_effort_ok ? "FLOW_WEAK" :
     (!s.displacementOk ? "FLOW_STALL" :
      (s.moveDir == s.dir ? "FLOW_REACTION" :
       (s.moveDir == -s.dir ? "FLOW_EXTENSION" : "FLOW_NA")));
CsvAdd(line,BStr(available)); // MATRIX_SNAPSHOT_AVAILABLE
CsvAdd(line,CsvTime(signalBar)); // SIGNAL_BAR
CsvAdd(line,available ? (EnumToString(s.status)) : ""); // MATRIX_STATUS
CsvAdd(line,available ? (route) : ""); // ROUTE
CsvAdd(line,available ? (mode) : ""); // MODE
CsvAdd(line,available ? (DirStr(direction)) : ""); // DIR
CsvAdd(line,available ? (CsvD(s.price)) : ""); // PRICE
CsvAdd(line,available ? (CsvD(s.open1)) : ""); // OPEN
CsvAdd(line,available ? (CsvD(s.candleBody)) : ""); // CANDLE_BODY
CsvAdd(line,available ? (IntegerToString(s.candleDir)) : ""); // CANDLE_DIR
CsvAdd(line,available ? (CsvD(s.posRel)) : ""); // POSREL
CsvAdd(line,available ? (CsvD(s.posRange)) : ""); // POS_RANGE
CsvAdd(line,available ? (BStr(s.glass)) : ""); // GLASS
CsvAdd(line,available ? (CsvD(s.distAbs)) : ""); // DIST_VWAP_D1
CsvAdd(line,available ? (CsvD(s.vwapVig)) : ""); // VWAP_VIG
CsvAdd(line,available ? (CsvD(s.upper)) : ""); // UPPER_BAND
CsvAdd(line,available ? (CsvD(s.lower)) : ""); // LOWER_BAND
CsvAdd(line,available ? (CsvD(s.bandRange)) : ""); // BAND_RANGE
CsvAdd(line,available ? (CsvD(SigmaD1)) : ""); // SIGMA_D1
CsvAdd(line,available ? (CsvD(VWAP_D1)) : ""); // VWAP_D1
CsvAdd(line,available ? (CsvD(H1)) : ""); // H1
CsvAdd(line,available ? (CsvD(L1)) : ""); // L1
CsvAdd(line,available ? (DirStr(s.dir)) : ""); // ABS_DIR
CsvAdd(line,available ? (DirStr(s.dirCont)) : ""); // CONT_DIR
CsvAdd(line,available ? (BStr(s.c1)) : ""); // C1
CsvAdd(line,available ? (BStr(s.c2)) : ""); // C2
CsvAdd(line,available ? (BStr(s.c3)) : ""); // C3
CsvAdd(line,available ? (BStr(s.c4)) : ""); // C4
CsvAdd(line,available ? (BStr(s.c5AbsOk)) : ""); // C5
CsvAdd(line,available ? (BStr(s.c23)) : ""); // C23
CsvAdd(line,available ? (BStr(s.baseAbs)) : ""); // BASE
CsvAdd(line,available ? (BStr(s.turboAbs)) : ""); // TURBO
CsvAdd(line,available ? (BStr(s.c1Cont)) : ""); // CONT_C1
CsvAdd(line,available ? (BStr(s.c2Cont)) : ""); // CONT_C2
CsvAdd(line,available ? (BStr(s.c3Cont)) : ""); // CONT_C3
CsvAdd(line,available ? (BStr(s.c4Cont)) : ""); // CONT_C4
CsvAdd(line,available ? (BStr(s.c5ContOk)) : ""); // CONT_C5
CsvAdd(line,available ? (BStr(s.c23Cont)) : ""); // CONT_C23
CsvAdd(line,available ? (BStr(s.baseCont)) : ""); // CONT_BASE
CsvAdd(line,available ? (BStr(s.turboCont)) : ""); // CONT_TURBO
CsvAdd(line,available ? (IntegerToString(s.scoreEff)) : ""); // ABS_SCORE
CsvAdd(line,available ? (IntegerToString(s.scoreContEff)) : ""); // CONT_SCORE
  CsvAdd(line,available ? (BStr(s.absValid)) : ""); // ABS_VALID
  CsvAdd(line,available ? (BStr(s.contValid)) : ""); // CONT_VALID
  CsvAdd(line,available ? (BStr(s.macroAbsCompatible)) : ""); //
// MACRO_ABS_COMPATIBLE
  CsvAdd(line,available ? (BStr(s.macroContCompatible)) : ""); //
// MACRO_CONT_COMPATIBLE
  CsvAdd(line,available ? (BStr(s.wwok)) : ""); // WW_VALID
  CsvAdd(line,available ? (CsvD(s.effort)) : ""); // WW_EFFORT
  CsvAdd(line,available ? (IntegerToString(s.waveDir)) : ""); // WW_DIR
  CsvAdd(line,available ? (s.wwok ? IntegerToString(s.wwWaveBars) : "") : ""); //
// WW_WAVE_BARS
  CsvAdd(line,available ? (s.wwok && s.wwWaveAgeAvailable ?
IntegerToString(s.wwWaveAgeSec) : "") : ""); // WW_WAVE_AGE_SEC
  CsvAdd(line,available ? (s.wwok ? CsvD(s.wwAccumVolume) : "") : ""); //
// WW_ACCUM_VOLUME
 CsvAdd(line,available ? (s.wwok ? CsvD(s.wwDistancePts) : "") : ""); //
// WW_DISTANCE_PTS
 CsvAdd(line,available ? (BStr(s.windowsValid)) : ""); // WINDOWS_VALID
 CsvAdd(line,available ? (PocStateStr(s.pocState)) : ""); // ABS_POC_STATE
 CsvAdd(line,available ? (PocStateStr(s.contPocState)) : ""); // CONT_POC_STATE
 CsvAdd(line,available ? (CsvD(s.minDispl)) : ""); // ABS_MIN_MOVE
 CsvAdd(line,available ? (CsvD(s.maxBody)) : ""); // ABS_MAX_BODY
 CsvAdd(line,available ? (CsvD(s.contMinDispl)) : ""); // CONT_MIN_MOVE
 CsvAdd(line,available ? (BStr(s.displacementOk)) : ""); // ABS_DISPLACEMENT_OK
 CsvAdd(line,available ? (BStr(s.contDisplacementOk)) : ""); //
// CONT_DISPLACEMENT_OK
 CsvAdd(line,available ? (BStr(s.absDivergence)) : ""); // ABS_DIVERGENCE
 CsvAdd(line,available ? (BStr(s.absStallStrict)) : ""); // ABS_STALL_STRICT
 CsvAdd(line,available ? (BStr(s.c1_body_ok)) : ""); // ABS_BODY_OK
 CsvAdd(line,available ? (BStr(s.absFollowingReaction)) : ""); //
// ABS_FOLLOWING_REACTION
 CsvAdd(line,available ? (BStr(s.absFollowingExtension)) : ""); //
// ABS_FOLLOWING_EXTENSION
 CsvAdd(line,available ? (BStr(s.c1_effort_ok)) : ""); // ABS_EFFORT_OK
 CsvAdd(line,available ? (BStr(s.cont_effort_ok)) : ""); // CONT_EFFORT_OK
 CsvAdd(line,available ? (BStr(s.cont_poc_ok)) : ""); // CONT_POC_OK
 CsvAdd(line,available ? (BStr(s.cont_movedir_ok)) : ""); // CONT_MOVE_DIR_OK
 CsvAdd(line,available ? (BStr(s.cont_wavedir_ok)) : ""); // CONT_WAVE_DIR_OK
 CsvAdd(line,available ? (BStr(s.cont_candle_dir_ok)) : ""); // CONT_CANDLE_DIR_OK
 CsvAdd(line,available ? (CsvD(s.priceMove)) : ""); // PRICE_MOVE
 CsvAdd(line,available ? (CsvD(s.pocMove)) : ""); // POC_MOVE
 CsvAdd(line,available ? (IntegerToString(s.moveDir)) : ""); // MOVE_DIR
 CsvAdd(line,available ? (IntegerToString(s.contMoveDir)) : ""); // CONT_MOVE_DIR
 CsvAdd(line,available ? (CsvD(s.pocNow.poc)) : ""); // POC_NOW
 CsvAdd(line,available ? (CsvD(s.pocNow.totalVolume)) : ""); // POC_NOW_VOLUME
 CsvAdd(line,available ? (s.pocNow.ok ? "VALID" : "INVALID") : ""); //
// POC_NOW_WINDOW_STATE
 CsvAdd(line,available ? (BStr(s.pocNow.hasTie)) : ""); // POC_NOW_TIE
 CsvAdd(line,available ? (IntegerToString(s.pocNow.tradeCount)) : ""); //
// POC_NOW_TRADE_COUNT
 CsvAdd(line,available ? (IntegerToString(s.pocNow.levels)) : ""); // POC_NOW_LEVELS
 CsvAdd(line,available ? (CsvD(s.pocNow.lastValidPrice)) : ""); // POC_NOW_LAST_PRICE
 CsvAdd(line,available ? (CsvD(s.pocNow.top1Price)) : ""); // POC_NOW_TOP1_PRICE
 CsvAdd(line,available ? (CsvD(s.pocNow.top1Vol)) : ""); // POC_NOW_TOP1_VOL
 CsvAdd(line,available ? (s.pocNow.levels >= 2 ? CsvD(s.pocNow.top2Price) : "") : ""); //
// POC_NOW_TOP2_PRICE
 CsvAdd(line,available ? (s.pocNow.levels >= 2 ? CsvD(s.pocNow.top2Vol) : "") : ""); //
// POC_NOW_TOP2_VOL
 CsvAdd(line,available ? (CsvD(s.pocNow.dominance)) : ""); // POC_NOW_DOMINANCE
 CsvAdd(line,available ? (CsvD(s.pocNow.buyVol)) : ""); // AGG_BUY_NOW
 CsvAdd(line,available ? (CsvD(s.pocNow.sellVol)) : ""); // AGG_SELL_NOW
 CsvAdd(line,available ? (CsvD(s.pocNow.unkVol)) : ""); // AGG_UNKNOWN_NOW
   CsvAdd(line,available ? (CsvD(s.pocNow.buyVol - s.pocNow.sellVol)) : ""); //
// AGG_DELTA_NOW
   CsvAdd(line,available ? ((s.pocNow.buyVol + s.pocNow.sellVol > 0.0) ?
CsvD((s.pocNow.buyVol - s.pocNow.sellVol)/(s.pocNow.buyVol + s.pocNow.sellVol)) : "") : "");
// AGG_IMBALANCE_NOW
   CsvAdd(line,available ? ((s.pocNow.buyVol + s.pocNow.sellVol + s.pocNow.unkVol > 0.0) ?
CsvD((s.pocNow.buyVol + s.pocNow.sellVol)/(s.pocNow.buyVol + s.pocNow.sellVol +
s.pocNow.unkVol)) : "") : ""); // AGG_KNOWN_PCT_NOW
   CsvAdd(line,available ? (CsvD(s.pocPrev.poc)) : ""); // POC_PREV
   CsvAdd(line,available ? (CsvD(s.pocPrev.totalVolume)) : ""); // POC_PREV_VOLUME
   CsvAdd(line,available ? (s.pocPrev.ok ? "VALID" : "INVALID") : ""); //
// POC_PREV_WINDOW_STATE
   CsvAdd(line,available ? (BStr(s.pocPrev.hasTie)) : ""); // POC_PREV_TIE
   CsvAdd(line,available ? (IntegerToString(s.pocPrev.tradeCount)) : ""); //
// POC_PREV_TRADE_COUNT
   CsvAdd(line,available ? (IntegerToString(s.pocPrev.levels)) : ""); // POC_PREV_LEVELS
   CsvAdd(line,available ? (CsvD(s.pocPrev.lastValidPrice)) : ""); //
// POC_PREV_LAST_PRICE
   CsvAdd(line,available ? (CsvD(s.pocPrev.top1Price)) : ""); // POC_PREV_TOP1_PRICE
   CsvAdd(line,available ? (CsvD(s.pocPrev.top1Vol)) : ""); // POC_PREV_TOP1_VOL
   CsvAdd(line,available ? (s.pocPrev.levels >= 2 ? CsvD(s.pocPrev.top2Price) : "") : ""); //
// POC_PREV_TOP2_PRICE
   CsvAdd(line,available ? (s.pocPrev.levels >= 2 ? CsvD(s.pocPrev.top2Vol) : "") : ""); //
// POC_PREV_TOP2_VOL
   CsvAdd(line,available ? (CsvD(s.pocPrev.dominance)) : ""); // POC_PREV_DOMINANCE
   CsvAdd(line,available ? (CsvD(s.pocPrev.buyVol)) : ""); // AGG_BUY_PREV
   CsvAdd(line,available ? (CsvD(s.pocPrev.sellVol)) : ""); // AGG_SELL_PREV
   CsvAdd(line,available ? (CsvD(s.pocPrev.unkVol)) : ""); // AGG_UNKNOWN_PREV
   CsvAdd(line,available ? (CsvD(s.pocPrev.buyVol - s.pocPrev.sellVol)) : ""); //
// AGG_DELTA_PREV
   CsvAdd(line,available ? ((s.pocPrev.buyVol + s.pocPrev.sellVol > 0.0) ?
CsvD((s.pocPrev.buyVol - s.pocPrev.sellVol)/(s.pocPrev.buyVol + s.pocPrev.sellVol)) : "") :
""); // AGG_IMBALANCE_PREV
   CsvAdd(line,available ? ((s.pocPrev.buyVol + s.pocPrev.sellVol + s.pocPrev.unkVol > 0.0) ?
CsvD((s.pocPrev.buyVol + s.pocPrev.sellVol)/(s.pocPrev.buyVol + s.pocPrev.sellVol +
s.pocPrev.unkVol)) : "") : ""); // AGG_KNOWN_PCT_PREV
   CsvAdd(line,available ? (flowRegime) : ""); // FLOW_REGIME
   CsvAdd(line,available ? (CsvD(s.pocPrev.totalVolume > 0.0 ?
s.pocNow.totalVolume/s.pocPrev.totalVolume : 0.0)) : ""); // VOL_RATIO
   CsvAdd(line,available ? (CsvD(s.minDispl > 0.0 ? MathAbs(s.priceMove)/s.minDispl : 0.0))
: ""); // PRICE_EFFICIENCY
  CsvAdd(line,available ? (CsvD(MathAbs(s.priceMove) > 0.0 ?
MathAbs(s.pocMove)/MathAbs(s.priceMove) : 0.0)) : ""); // POC_RESPONSE
}

void CsvArmedHeader(string &line)
{
  CsvAdd(line,"ARMED_ACTIVE");
  CsvAdd(line,"ARMED_DIR");
  CsvAdd(line,"ARMED_ROUTE");
   CsvAdd(line,"ARMED_MODE");
   CsvAdd(line,"REGION_HIGH");
   CsvAdd(line,"REGION_LOW");
   CsvAdd(line,"TRIGGER");
   CsvAdd(line,"ARMED_AT");
   CsvAdd(line,"ARMED_AGE_SEC");
   CsvAdd(line,"REQUESTS_ACCEPTED_TODAY");
   CsvAdd(line,"ORDERS_ENTERED_TODAY");
   CsvAdd(line,"HARD_FLIPS_PER_DAY");
   CsvAdd(line,"ARMED_CANCEL_HARD");
   CsvAdd(line,"OPPOSITE_REARM_AFTER_HARD");
}

void CsvArmedRow(string &line)
{
  datetime now = TimeTradeServer();
  bool armedAgeAvailable = armed.active && armed.armedAt > 0 && now >=
armed.armedAt;
  long armedAge = armedAgeAvailable ? (long)(now - armed.armedAt) : 0;
  CsvAdd(line,BStr(armed.active)); // ARMED_ACTIVE
  CsvAdd(line,armed.active ? DirStr(armed.dir) : ""); // ARMED_DIR
  CsvAdd(line,armed.active ? armed.route : ""); // ARMED_ROUTE
  CsvAdd(line,armed.active ? armed.mode : ""); // ARMED_MODE
  CsvAdd(line,armed.active ? CsvD(armed.regionHigh) : ""); // REGION_HIGH
  CsvAdd(line,armed.active ? CsvD(armed.regionLow) : ""); // REGION_LOW
  CsvAdd(line,armed.active ?
CsvD(ComputeTrigger(armed.dir,armed.regionHigh,armed.regionLow)) : ""); // TRIGGER
  CsvAdd(line,armed.active ? CsvTime(armed.armedAt) : ""); // ARMED_AT
  CsvAdd(line,armedAgeAvailable ? IntegerToString(armedAge) : ""); // ARMED_AGE_SEC
  CsvAdd(line,IntegerToString(requestsAcceptedToday)); //
// REQUESTS_ACCEPTED_TODAY
  CsvAdd(line,IntegerToString(ordersEnteredToday)); // ORDERS_ENTERED_TODAY
  CsvAdd(line,IntegerToString(hardFlipsPerDay)); // HARD_FLIPS_PER_DAY
  CsvAdd(line,IntegerToString(armedCancelHard)); // ARMED_CANCEL_HARD
  CsvAdd(line,IntegerToString(oppositeRearmAfterHard)); //
// OPPOSITE_REARM_AFTER_HARD
}

void CsvExecutionHeader(string &line)
{
  CsvAdd(line,"EVENT_DIR");
  CsvAdd(line,"EVENT_MODE");
  CsvAdd(line,"EXEC_ROUTE");
  CsvAdd(line,"EVENT_PRICE");
  CsvAdd(line,"EVENT_POSREL");
  CsvAdd(line,"EVENT_DIST_D1");
  CsvAdd(line,"EVENT_EFFORT");
  CsvAdd(line,"EVENT_TRIGGER");
   CsvAdd(line,"BREAKOUT_PRICE");
   CsvAdd(line,"REQUEST_PRICE");
   CsvAdd(line,"WEIGHTED_ENTRY_PRICE");
   CsvAdd(line,"ENTRY_SLIPPAGE");
   CsvAdd(line,"SL_PRICE");
   CsvAdd(line,"TP_PRICE");
   CsvAdd(line,"LOTS");
   CsvAdd(line,"LIVE_DIRECTION_AVAILABLE");
   CsvAdd(line,"LIVE_DIR_ABS");
   CsvAdd(line,"LIVE_DIR_CONT");
   CsvAdd(line,"LATE_DIRECTION_MISMATCH");
}

void CsvExecutionRow(string &line,string dirStr,string mode,double price,double
posRel,double distD1,double effort,double trigger)
{
  int idx = gOpenPos.tradeRecordIdx;
  bool tracked = gOpenPos.active && idx >= 0 && idx < gTradeRecordCount &&
      gTradeRecords[idx].positionID == gOpenPos.positionID;
  CsvAdd(line,dirStr); // EVENT_DIR
  CsvAdd(line,mode); // EVENT_MODE
  CsvAdd(line,gPendingExec.active ? gPendingExec.route : (armed.active ? armed.route :
"")); // EXEC_ROUTE
  CsvAdd(line,CsvD(price)); // EVENT_PRICE
  CsvAdd(line,CsvD(posRel)); // EVENT_POSREL
  CsvAdd(line,CsvD(distD1)); // EVENT_DIST_D1
  CsvAdd(line,CsvD(effort)); // EVENT_EFFORT
  CsvAdd(line,CsvD(trigger)); // EVENT_TRIGGER
  CsvAdd(line,gLastBreakoutPrice > 0.0 ? CsvD(gLastBreakoutPrice) : ""); //
// BREAKOUT_PRICE
  CsvAdd(line,gPendingExec.active && gPendingExec.requestPriceAvailable ?
CsvD(gPendingExec.requestPrice) : (tracked && gTradeRecords[idx].requestPriceAvailable
? CsvD(gTradeRecords[idx].requestPrice) : "")); // REQUEST_PRICE
  CsvAdd(line,tracked ? CsvD(gTradeRecords[idx].weightedEntryPrice) : ""); //
// WEIGHTED_ENTRY_PRICE
  CsvAdd(line,tracked && gTradeRecords[idx].requestPriceAvailable ?
CsvD(gTradeRecords[idx].entrySlippage) : ""); // ENTRY_SLIPPAGE
  CsvAdd(line,tracked ? CsvD(gTradeRecords[idx].slPrice) : (gPendingExec.active ?
CsvD(gPendingExec.slPrice) : "")); // SL_PRICE
  CsvAdd(line,tracked ? CsvD(gTradeRecords[idx].tpPrice) : (gPendingExec.active ?
CsvD(gPendingExec.tpPrice) : "")); // TP_PRICE
  CsvAdd(line,tracked ? CsvD(gTradeRecords[idx].totalVolumeIn) : (gPendingExec.active ?
CsvD(gPendingExec.requestedLots) : "")); // LOTS
  CsvAdd(line,BStr(gLiveDirectionTelemetryValid)); // LIVE_DIRECTION_AVAILABLE
  CsvAdd(line,gLiveDirectionTelemetryValid ? IntegerToString(gLiveDirAbs) : ""); //
// LIVE_DIR_ABS
  CsvAdd(line,gLiveDirectionTelemetryValid ? IntegerToString(gLiveDirCont) : ""); //
// LIVE_DIR_CONT
  CsvAdd(line,gLiveDirectionTelemetryValid ? BStr(gLateDirectionMismatch) : ""); //
// LATE_DIRECTION_MISMATCH
}

void CsvTradeHeader(string &line)
{
  CsvAdd(line,"TIMESTAMP");
  CsvAdd(line,"POSITION_ID");
  CsvAdd(line,"DIR");
  CsvAdd(line,"ROUTE");
  CsvAdd(line,"MODE");
  CsvAdd(line,"ENTRY_TIME");
  CsvAdd(line,"EXIT_TIME");
  CsvAdd(line,"TOTAL_VOLUME_IN");
  CsvAdd(line,"TOTAL_VOLUME_OUT");
  CsvAdd(line,"WEIGHTED_ENTRY_PRICE");
  CsvAdd(line,"WEIGHTED_EXIT_PRICE");
  CsvAdd(line,"BREAKOUT_PRICE");
  CsvAdd(line,"BREAKOUT_PRICE_AVAILABLE");
  CsvAdd(line,"REQUEST_PRICE");
  CsvAdd(line,"ENTRY_SLIPPAGE");
  CsvAdd(line,"REQUEST_PRICE_STATUS");
  CsvAdd(line,"SL_PRICE");
  CsvAdd(line,"TP_PRICE");
  CsvAdd(line,"MAE");
  CsvAdd(line,"MFE");
  CsvAdd(line,"HOLD_SECONDS");
  CsvAdd(line,"GROSS_PNL");
  CsvAdd(line,"COMMISSION");
  CsvAdd(line,"FEE");
  CsvAdd(line,"SWAP");
  CsvAdd(line,"NET_PNL");
    CsvAdd(line,"INITIAL_RISK_MONEY");
    CsvAdd(line,"PNL_R");
    CsvAdd(line,"EXIT_REASON");
    CsvAdd(line,"QUOTA_COUNTED");
    CsvAdd(line,"MAE_MFE_PARTIAL_AFTER_RESTART");
    CsvAdd(line,"ACCOUNTING_RESOLVED");
    CsvAdd(line,"ACCOUNTING_STATUS");
    CsvAdd(line,"RISK_VALID");
    CsvAdd(line,"PNL_R_VALID");
    CsvAdd(line,"VOLUME_CLOSED_COMPLETE");
    CsvAdd(line,"CLOSED");
    CsvAdd(line,"DAILY_NET_PNL");
    CsvAdd(line,"DAILY_PNL_R");
    CsvAdd(line,"CONSECUTIVE_LOSSES");
    CsvAdd(line,"DAILY_RISK_BLOCKED");
    CsvAdd(line,"REQUESTS_ACCEPTED_TODAY");
     CsvAdd(line,"ORDERS_ENTERED_TODAY");
     CsvAdd(line,"HARD_FLIPS_PER_DAY");
     CsvAdd(line,"ARMED_CANCEL_HARD");
     CsvAdd(line,"OPPOSITE_REARM_AFTER_HARD");
}

void CsvTradeRow(string &line,const TradeRecord &r)
{
  CsvAdd(line,CsvTime(TimeTradeServer())); // TIMESTAMP
  CsvAdd(line,StringFormat("%I64u",r.positionID)); // POSITION_ID
  CsvAdd(line,DirStr(r.direction)); // DIR
  CsvAdd(line,r.route); // ROUTE
  CsvAdd(line,r.mode); // MODE
  CsvAdd(line,CsvTime(r.entryTime)); // ENTRY_TIME
  CsvAdd(line,CsvTime(r.exitTime)); // EXIT_TIME
  CsvAdd(line,CsvD(r.totalVolumeIn)); // TOTAL_VOLUME_IN
  CsvAdd(line,CsvD(r.totalVolumeOut)); // TOTAL_VOLUME_OUT
  CsvAdd(line,CsvD(r.weightedEntryPrice)); // WEIGHTED_ENTRY_PRICE
  CsvAdd(line,CsvD(r.weightedExitPrice)); // WEIGHTED_EXIT_PRICE
  CsvAdd(line,r.breakoutPriceAvailable ? CsvD(r.breakoutPrice) : ""); // BREAKOUT_PRICE
  CsvAdd(line,BStr(r.breakoutPriceAvailable)); // BREAKOUT_PRICE_AVAILABLE
  CsvAdd(line,r.requestPriceAvailable ? CsvD(r.requestPrice) : ""); // REQUEST_PRICE
  CsvAdd(line,r.requestPriceAvailable ? CsvD(r.entrySlippage) : ""); // ENTRY_SLIPPAGE
  CsvAdd(line,r.requestPriceAvailable ? "AVAILABLE" : (r.maeMfePartialAfterRestart ?
"REQUEST_PRICE_UNAVAILABLE_AFTER_RESTART" :
"REQUEST_PRICE_UNAVAILABLE")); // REQUEST_PRICE_STATUS
  CsvAdd(line,CsvD(r.slPrice)); // SL_PRICE
  CsvAdd(line,CsvD(r.tpPrice)); // TP_PRICE
  CsvAdd(line,CsvD(r.MAE)); // MAE
  CsvAdd(line,CsvD(r.MFE)); // MFE
  CsvAdd(line,IntegerToString(r.holdSeconds)); // HOLD_SECONDS
  CsvAdd(line,CsvD(r.grossProfit)); // GROSS_PNL
  CsvAdd(line,r.inoutCostsUnresolved ? "" : CsvD(r.commission)); // COMMISSION
  CsvAdd(line,r.inoutCostsUnresolved ? "" : CsvD(r.fee)); // FEE
  CsvAdd(line,CsvD(r.swap)); // SWAP
  CsvAdd(line,r.accountingResolved ? CsvD(r.netProfit) : ""); // NET_PNL
  CsvAdd(line,r.riskValid ? CsvD(r.initialRiskMoney) : ""); // INITIAL_RISK_MONEY
  CsvAdd(line,r.pnlRValid ? CsvD(r.PnL_R) : ""); // PNL_R
  CsvAdd(line,r.exitReason); // EXIT_REASON
  CsvAdd(line,BStr(r.quotaCounted)); // QUOTA_COUNTED
  CsvAdd(line,BStr(r.maeMfePartialAfterRestart)); //
// MAE_MFE_PARTIAL_AFTER_RESTART
  CsvAdd(line,BStr(r.accountingResolved)); // ACCOUNTING_RESOLVED
  CsvAdd(line,r.accountingResolved ? "RESOLVED" : (r.inoutCostsUnresolved ?
    "INOUT_COST_ALLOCATION_UNAVAILABLE" : (r.maeMfePartialAfterRestart ?
   "RESTART_ACCOUNTING_UNRESOLVED" : "ACCOUNTING_UNRESOLVED"))); //
// ACCOUNTING_STATUS
  CsvAdd(line,BStr(r.riskValid)); // RISK_VALID
  CsvAdd(line,BStr(r.pnlRValid)); // PNL_R_VALID
  CsvAdd(line,BStr(r.volumeClosedComplete)); // VOLUME_CLOSED_COMPLETE
  CsvAdd(line,BStr(r.closed)); // CLOSED
  CsvAdd(line,gDailyEconomicsValid ? CsvD(dailyNetPnL) : ""); // DAILY_NET_PNL
  CsvAdd(line,gDailyPnLRValid ? CsvD(dailyPnLR) : ""); // DAILY_PNL_R
  CsvAdd(line,gDailyEconomicsValid ? IntegerToString(consecutiveLosses) : ""); //
// CONSECUTIVE_LOSSES
  CsvAdd(line,BStr(dailyRiskBlocked)); // DAILY_RISK_BLOCKED
  CsvAdd(line,IntegerToString(requestsAcceptedToday)); //
// REQUESTS_ACCEPTED_TODAY
  CsvAdd(line,IntegerToString(ordersEnteredToday)); // ORDERS_ENTERED_TODAY
  CsvAdd(line,IntegerToString(hardFlipsPerDay)); // HARD_FLIPS_PER_DAY
  CsvAdd(line,IntegerToString(armedCancelHard)); // ARMED_CANCEL_HARD
  CsvAdd(line,IntegerToString(oppositeRearmAfterHard)); //
// OPPOSITE_REARM_AFTER_HARD
}
void WriteAuditHeader()
{
  if(csvAuditHandle == INVALID_HANDLE) return;
  string line = "TIMESTAMP,STATUS";
  CsvConfigHeader(line);
  CsvMacroHeader(line);
  CsvMatrixHeader(line);
  CsvArmedHeader(line);
  CsvExecutionHeader(line);
  BookIdentityAuditHeader(line);
  FileWriteString(csvAuditHandle,line + "\r\n");
}

void WriteAuditRow(string status,string dirStr,string mode,
       double price,double posRel,double distD1,double effort,double trigger)
{
  BookDiagAudit(status);
  if(Inp_DOM_Enable) DOMObserveAudit(status,dirStr,mode,price,trigger);
  if(csvAuditHandle == INVALID_HANDLE) return;
  string line = "";
  CsvAdd(line,CsvTime(TimeTradeServer()));
  CsvAdd(line,status);
  CsvConfigRow(line);
  CsvMacroRow(line);
CsvMatrixRow(line,gLastTelemetryMatrix,gLastTelemetryMatrixValid,gLastTelemetrySignalBar);
  CsvArmedRow(line);
  CsvExecutionRow(line,dirStr,mode,price,posRel,distD1,effort,trigger);
  BookIdentityAuditRow(line);
  FileWriteString(csvAuditHandle,line + "\r\n");
}
void WriteShadowHeader()
{
  if(csvShadowHandle == INVALID_HANDLE) return;
  string line = "TIMESTAMP,EVENT";
    CsvConfigHeader(line);
    CsvMacroHeader(line);
    CsvMatrixHeader(line);
    CsvArmedHeader(line);
    BookIdentityAuditHeader(line);
  FileWriteString(csvShadowHandle,line + "\r\n");
}

void WriteShadowRow(string event,const MatrixSnapshot &s)
{
  if(csvShadowHandle == INVALID_HANDLE) return;
  string line = "";
  CsvAdd(line,CsvTime(TimeTradeServer()));
  CsvAdd(line,event);
  CsvConfigRow(line);
  CsvMacroRow(line);
  CsvMatrixRow(line,s,true,iTime(Symbol(),Inp_SignalTF,1));
    CsvArmedRow(line);
    BookIdentityAuditRow(line);
  FileWriteString(csvShadowHandle,line + "\r\n");
}

void WriteTradeHeader()
{
  if(csvTradeHandle == INVALID_HANDLE) return;
  string line = "";
  CsvConfigHeader(line);
  CsvTradeHeader(line);
  FileWriteString(csvTradeHandle,line + "\r\n");
}

bool WriteTradeRow(const TradeRecord &r)
{
  if(r.positionID==0 || !r.closed) return false;
  if(gTradeCsvIndexLoaded && TradeCsvContainsPID(r.positionID)) return true;
  if(csvTradeHandle == INVALID_HANDLE || !gTradeCsvIndexLoaded ||
!gTradeCsvAppendSafe)
     return false;
  if(!BookCsvBeforeAppend()) return false;
  string line = "";
  CsvConfigRow(line);
    CsvTradeRow(line,r);
    string payload=line + "\r\n";
    uchar encoded[];
    int expected=StringToCharArray(payload,encoded,0,WHOLE_ARRAY,CP_ACP)-1;
    if(expected<=0) return false;
      ResetLastError();
    uint written=FileWriteString(csvTradeHandle,payload);
    int writeError=GetLastError();
    if(written!=(uint)expected || writeError!=0)
    { return BookCsvReject(gTradeCsvFileName,0,0,0,"WRITE_FAILED_OR_PARTIAL_ROW"); }
    ResetLastError();
    FileFlush(csvTradeHandle); // Confirmed trade finalization only.
    if(GetLastError()!=0) return BookCsvReject(gTradeCsvFileName,0,0,0,"FLUSH_FAILED_OUTCOME_UNCERTAIN");
    ResetLastError();
    ulong sizeAfterWrite=FileSize(csvTradeHandle);
    if(GetLastError()!=0 || sizeAfterWrite!=gBookCsvVerifiedSize+(ulong)expected)
       return BookCsvReject(gTradeCsvFileName,0,0,0,"SIZE_AFTER_WRITE_UNVERIFIED");
    gBookCsvVerifiedSize=sizeAfterWrite;
    if(!TradeCsvAddPID(r.positionID))
       return BookCsvReject(gTradeCsvFileName,0,0,0,"PID_INDEX_ALLOCATION_AFTER_WRITE");
    BookIdentityCorrelateTrade(r);
    if(Inp_DOM_Enable) DOMObserveTrade(r);
    return true;
}


// Additional validation never upgrades an original STILL/terminal result.
ENUM_APS BookDecisionArmedGate(const ENUM_APS originalReadiness)
{
   if(Inp_DecisionMode==DECISION_ORIGINAL ||
      (originalReadiness!=APS_ENTRY_READY && originalReadiness!=APS_STILL_ARMED))
      return originalReadiness;
   ENUM_BOOK_DECISION_RESULT result=BookDecisionEvaluateArmed();
   bool conflict=HasExecutionInFlight() || gAccountingUnresolved ||
                 gEntryJournalInvalid || gExitJournalInvalid;
   if(conflict)
   {
      // Preserve the original terminal READY-path financial rejection; only the
      // thesis is reset, never an accounting obligation or pending intent.
      if(originalReadiness==APS_ENTRY_READY)
      { ResetArmedSignal(); return APS_TRADE_OR_POSITION; }
      return APS_STILL_ARMED;
   }
   if(result==DECISION_INVALIDAR_ARMED)
   {
      BookDiagFinish("CANCEL_DECISION_INVALIDATION");
      ResetArmedSignal();
      return APS_ENDED_FAIL_CLOSED;
   }
   if(result!=DECISION_VALIDAR) return APS_STILL_ARMED;
   return originalReadiness;
}

ENUM_SEND_OUTCOME BookDecisionRejectUnprepared()
{
   if(HasExecutionInFlight() || gAccountingUnresolved ||
      gEntryJournalInvalid || gExitJournalInvalid) return SEND_FINANCIAL_UNRESOLVED;
   if(!armed.active) return SEND_ORIGINAL_CANCEL;
   ArmedSignal original=armed;
   double effort,trigger,last;
   MqlTick current;
   ENUM_APS readiness=CheckArmedEntryReady(effort,trigger,last,current);
   if(readiness==APS_ENDED_REEVAL_ALLOWED) return SEND_CANCEL_REEVAL;
   if(readiness==APS_TRADE_OR_POSITION) return SEND_TRADE_OR_POSITION;
   if(readiness==APS_ENDED_FAIL_CLOSED || !DOMGateIdentityCurrent(original))
      return SEND_ORIGINAL_CANCEL;
   if(readiness==APS_ENTRY_READY)
   {
      // A new veto cannot conceal an original terminal execution predicate.
      if(DOMGateOriginalOvershoot(current,original,trigger))
      {
         WriteAuditRow("OVERSHOOT_BLOCK",DirStr(original.dir),original.mode,current.last,
                       original.posRel,original.distD1,effort,trigger);
         ResetArmedSignal(); return SEND_ORIGINAL_CANCEL;
      }
      double exec=original.dir==1?current.ask:current.bid;
      if(!DOMGateFinalTickReady(current,original,trigger,exec,readiness) &&
         readiness==APS_ENDED_FAIL_CLOSED) return SEND_ORIGINAL_CANCEL;
      double sl=NormEntrySL(original.dir,exec-original.dir*original.activeSL_Pts);
      double tp=NormEntryTP(original.dir,exec+original.dir*original.activeTP_Pts);
      // SendOrder has already frozen the original risk terms before any new WAIT.
      if(BookRiskEnabled() && !BookRiskResolveTerms(original.dir,exec,original.mode,
         original.activeSL_Pts,original.activeTP_Pts,false,sl,tp))
      { ResetArmedSignal(); return SEND_ORIGINAL_CANCEL; }
      double lots=ComputeLotsForEntry(original.dir,exec,sl);
      if(!DOMGateTermsCurrent(current,original,exec,lots,sl,tp,readiness) &&
         readiness==APS_ENDED_FAIL_CLOSED) return SEND_ORIGINAL_CANCEL;
   }
   readiness=BookDecisionArmedGate(readiness);
   if(readiness==APS_ENDED_FAIL_CLOSED || !armed.active) return SEND_ORIGINAL_CANCEL;
   if(readiness==APS_TRADE_OR_POSITION) return SEND_FINANCIAL_UNRESOLVED;
   return SEND_WAIT_ARMED;
}

bool BookDecisionRevalidateNoBook(const ArmedSignal &original,
   const PendingExecContext &expected,ENUM_APS &readiness,
   const double price,const double lots,const double sl,const double tp,
   const datetime signalClock,const datetime contextClock)
{
   readiness=APS_STILL_ARMED;
   if(!DOMGateIdentityCurrent(original) || !DOMGateOwnUndispatchedIntent(expected))
      return false;
   double effort,trigger,last;
   MqlTick current;
   // The exclusive local intent is already prepared; retain the original
   // market rules without treating our own intent as an unrelated execution.
   readiness=CheckArmedMarketReady(effort,trigger,last,current);
   if(readiness!=APS_ENTRY_READY || !DOMGateIdentityCurrent(original)) return false;
   if(HasOpenPosition() || ordersEnteredToday>=Inp_MaxTradesDay ||
      dailyRiskBlocked || gAccountingUnresolved)
   { ResetArmedSignal(); readiness=APS_ENDED_FAIL_CLOSED; return false; }
   if(!DOMGateFinalTickReady(current,original,trigger,price,readiness) ||
      !DOMGateTermsCurrent(current,original,price,lots,sl,tp,readiness)) return false;
   if(!SymbolInfoTick(Symbol(),current))
   { readiness=APS_STILL_ARMED; return false; }
   datetime now=TimeTradeServer();
   MqlDateTime dt; TimeToStruct(now,dt);
   if((armed.armedAt>0 && now-armed.armedAt>=(datetime)Inp_ArmedTimeoutSec) ||
      dt.hour*100+dt.min>=Inp_StopEntryHHMM)
   { readiness=CheckArmedMarketReady(effort,trigger,last,current); return false; }
   if(DOMGateOriginalOvershoot(current,original,trigger))
   {
      WriteAuditRow("OVERSHOOT_BLOCK",DirStr(original.dir),original.mode,current.last,
                    original.posRel,original.distD1,effort,trigger);
      ResetArmedSignal(); readiness=APS_ENDED_FAIL_CLOSED; return false;
   }
   if(!DOMGateFinalTickReady(current,original,trigger,price,readiness) ||
      !DOMGateTermsCurrent(current,original,price,lots,sl,tp,readiness)) return false;
   if(signalClock<=0 || contextClock<=0 ||
      iTime(Symbol(),Inp_SignalTF,0)!=signalClock ||
      iTime(Symbol(),Inp_ContextTF,0)!=contextClock) return false;
   if(BookDecisionEvaluateArmed()!=DECISION_VALIDAR)
   { readiness=APS_STILL_ARMED; return false; }
   return BookDecisionDispatchValid(original);
}

ENUM_SEND_OUTCOME BookDecisionRejectPrepared(const ArmedSignal &original,
   const PendingExecContext &expected,const bool apiCallStarted,const ENUM_APS readiness)
{
   // Same-invocation witness only. A zero ticket is never proof of no dispatch.
   // This helper does not report a new veto as a book observation.
   if(apiCallStarted || !DOMGateIntentMatches(expected) || HasOpenPosition() ||
      HasOwnPendingOrder() || gPendingExit.active ||
      gOrderObligationScanUnresolved || gPendingOrderClassificationUnresolved)
      return SEND_FINANCIAL_UNRESOLVED;
   for(int i=0;i<ArraySize(gUnresolvedOrders);i++)
      if(gUnresolvedOrders[i].active && (gUnresolvedOrders[i].classificationPending ||
         gUnresolvedOrders[i].persistencePending)) return SEND_FINANCIAL_UNRESOLVED;
   for(int i=0;i<gTradeRecordCount;i++)
      if(gTradeRecords[i].positionID>0 && !gTradeRecords[i].closed &&
         gTradeRecords[i].totalVolumeIn>0) return SEND_FINANCIAL_UNRESOLVED;
   // PREPARED or MAY is resolved durably, never silently downgraded.
   if(!ResolveRequestJournal(false)) return SEND_FINANCIAL_UNRESOLVED;
   ResetLastError();
   bool exists=FileIsExist(RequestJournalPath(false));
   int error=GetLastError();
   if(exists || (error!=0 && error!=ERR_FILE_NOT_EXIST) ||
      gEntryJournalCleanupPending || gEntryJournalWritePending || gEntryJournalInvalid)
      return SEND_FINANCIAL_UNRESOLVED;
   ResetPendingExec(false);
   if(HasExecutionInFlight() || gEntryJournalInvalid || gExitJournalInvalid)
      return SEND_FINANCIAL_UNRESOLVED;
   if(readiness==APS_ENDED_REEVAL_ALLOWED) return SEND_CANCEL_REEVAL;
   if(readiness==APS_ENDED_FAIL_CLOSED || !DOMGateIdentityCurrent(original))
      return SEND_ORIGINAL_CANCEL;
   if(readiness==APS_TRADE_OR_POSITION) return SEND_TRADE_OR_POSITION;
   // Durable cleanup may take time: run original timeout/session/market checks
   // again. Any retry starts a new SendOrder and obtains its own final book.
   return BookDecisionRejectUnprepared();
}

ENUM_SEND_OUTCOME SendOrder(int direction, double unusedLots, string mode,
     double slPts, double tpPts,
     double posRel, double distD1, double effort, double trigger)
{
  string dStr=DirStr(direction);
  if(HasOpenPosition())
  { WriteAuditRow("LATE_POSITION_BLOCK",dStr,mode,0,posRel,distD1,effort,trigger);
return SEND_FINAL_FAILURE; }
 if(ordersEnteredToday>=Inp_MaxTradesDay)
 { WriteAuditRow("LATE_QUOTA_BLOCK",dStr,mode,0,posRel,distD1,effort,trigger); return
SEND_FINAL_FAILURE; }
 if(dailyRiskBlocked || gAccountingUnresolved)
 { WriteAuditRow("LATE_DAILY_RISK_BLOCK",dStr,mode,0,posRel,distD1,effort,trigger);
return SEND_FINAL_FAILURE; }
 if(HasExecutionInFlight())
 { WriteAuditRow("LATE_PENDING_BLOCK",dStr,mode,0,posRel,distD1,effort,trigger);
return SEND_FINAL_FAILURE; }

 BookGateDecision bookDecision;
 ArmedSignal bookOriginal=armed;
 PendingExecContext bookIntent;
 ZeroMemory(bookIntent);
  bool bookApiCallStarted=false; // local control-flow witness, never persisted
  datetime decisionSignalClock=0,decisionContextClock=0;
  if(Inp_DecisionMode!=DECISION_ORIGINAL)
  {
     decisionSignalClock=iTime(Symbol(),Inp_SignalTF,0);
     decisionContextClock=iTime(Symbol(),Inp_ContextTF,0);
  }
   // One final snapshot: all risk/stops calculations refer to this executable quote.
   MqlTick finalTick;
   if(!SymbolInfoTick(Symbol(),finalTick) || finalTick.ask<=0 || finalTick.bid<=0 ||
      finalTick.ask<finalTick.bid) return SEND_FINAL_FAILURE;
   double finalExec=(direction==1)?finalTick.ask:finalTick.bid;
   if(finalTick.ask-finalTick.bid>gSpreadMaxPts) return SEND_FINAL_FAILURE;
   bool finalBreakout=(direction==1)?finalExec>=trigger:finalExec<=trigger;
   if(!finalBreakout)
   {
WriteAuditRow("LATE_BREAKOUT_LOST",dStr,mode,finalExec,posRel,distD1,effort,trigger)
; return SEND_FINAL_FAILURE; }
   double over=(direction==1)?finalExec-trigger:trigger-finalExec;
   if(over>gMaxOvershoot)
   {
WriteAuditRow("LATE_OVERSHOOT_BLOCK",dStr,mode,finalExec,posRel,distD1,effort,trigger); return Inp_DOM_TradeGateEnable?SEND_ORIGINAL_CANCEL:SEND_FINAL_FAILURE; }
  double sl=NormEntrySL(direction,finalExec-direction*slPts);
  double tp=NormEntryTP(direction,finalExec+direction*tpPts);
  if(BookRiskEnabled() && !BookRiskResolveTerms(direction,finalExec,mode,slPts,tpPts,true,sl,tp))
     return SEND_FINAL_FAILURE;
  if(sl<=0 || tp<=0) return SEND_FINAL_FAILURE;
  double minDist=(double)SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL)*
      SymbolInfoDouble(Symbol(),SYMBOL_POINT);
  // Server stops are also measured from the closing quote (bid for buy, ask for sell).
  double closingQuote=(direction==1)?finalTick.bid:finalTick.ask;
  if(direction*(finalExec-sl)<minDist || direction*(tp-finalExec)<minDist ||
     direction*(closingQuote-sl)<minDist || direction*(tp-closingQuote)<minDist)
  {
WriteAuditRow("STOPS_LEVEL_BLOCK",dStr,mode,finalExec,posRel,distD1,effort,trigger);
return SEND_FINAL_FAILURE; }
  double lots=ComputeLotsForEntry(direction,finalExec,sl);
  if(lots<=0) return SEND_FINAL_FAILURE;
  ENUM_ORDER_TYPE type=(direction==1)?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
  double margin=0;
  if(!OrderCalcMargin(type,Symbol(),lots,finalExec,margin) ||
     !MathIsValidNumber(margin) || margin<0 ||
     AccountInfoDouble(ACCOUNT_MARGIN_FREE)<margin)
  { WriteAuditRow("NO_MARGIN",dStr,mode,finalExec,posRel,distD1,effort,trigger); return
SEND_FINAL_FAILURE; }
   trade.SetExpertMagicNumber(gMagicCore);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   // Re-read immediately before dispatch. A moved executable quote needs fresh
   // sizing/stops; a changed closing quote always needs a fresh STOPS_LEVEL check.
   MqlTick dispatchTick;
   if(!SymbolInfoTick(Symbol(),dispatchTick)) return SEND_FINAL_FAILURE;
   double dispatchExec=(direction==1)?dispatchTick.ask:dispatchTick.bid;
   if(dispatchExec<=0 || dispatchTick.ask<=0 || dispatchTick.bid<=0 ||
      dispatchTick.ask<dispatchTick.bid || dispatchTick.ask-dispatchTick.bid>gSpreadMaxPts)
return SEND_FINAL_FAILURE;
   if((direction==1 && dispatchExec<trigger) || (direction==-1 && dispatchExec>trigger))
   {
WriteAuditRow("LATE_BREAKOUT_LOST",dStr,mode,dispatchExec,posRel,distD1,effort,trigger); return SEND_FINAL_FAILURE; }
   if(direction*(dispatchExec-trigger)>gMaxOvershoot)
   {
WriteAuditRow("LATE_OVERSHOOT_BLOCK",dStr,mode,dispatchExec,posRel,distD1,effort,trigger); return Inp_DOM_TradeGateEnable?SEND_ORIGINAL_CANCEL:SEND_FINAL_FAILURE; }
   if(dispatchExec!=finalExec)
   {
      finalExec=dispatchExec;
      sl=NormEntrySL(direction,finalExec-direction*slPts);
      tp=NormEntryTP(direction,finalExec+direction*tpPts);
      if(BookRiskEnabled() && !BookRiskResolveTerms(direction,finalExec,mode,slPts,tpPts,false,sl,tp))
         return SEND_FINAL_FAILURE;
      lots=ComputeLotsForEntry(direction,finalExec,sl);
      closingQuote=(direction==1)?dispatchTick.bid:dispatchTick.ask;
      if(sl<=0 || tp<=0 || lots<=0 || direction*(closingQuote-sl)<minDist ||
     direction*(tp-closingQuote)<minDist)
      {
WriteAuditRow("STOPS_LEVEL_BLOCK",dStr,mode,finalExec,posRel,distD1,effort,trigger);
return SEND_FINAL_FAILURE; }
      if(!OrderCalcMargin(type,Symbol(),lots,finalExec,margin) || !MathIsValidNumber(margin)
|| margin<0 || AccountInfoDouble(ACCOUNT_MARGIN_FREE)<margin)
      { WriteAuditRow("NO_MARGIN",dStr,mode,finalExec,posRel,distD1,effort,trigger); return
SEND_FINAL_FAILURE; }
   }
   closingQuote=(direction==1)?dispatchTick.bid:dispatchTick.ask;
   if(direction*(finalExec-sl)<minDist || direction*(tp-finalExec)<minDist ||
      direction*(closingQuote-sl)<minDist || direction*(tp-closingQuote)<minDist)
   {
WriteAuditRow("STOPS_LEVEL_BLOCK",dStr,mode,finalExec,posRel,distD1,effort,trigger);
return SEND_FINAL_FAILURE; }
   if(HasOpenPosition()) return SEND_FINAL_FAILURE;
   if(HasOwnPendingOrder() || HasExecutionInFlight())
   {
WriteAuditRow("LATE_PENDING_BLOCK",dStr,mode,finalExec,posRel,distD1,effort,trigger)
; return SEND_FINAL_FAILURE; }
   if(Inp_DecisionMode!=DECISION_ORIGINAL &&
      BookDecisionArmedGate(APS_ENTRY_READY)!=APS_ENTRY_READY)
      return BookDecisionRejectUnprepared();
   if(Inp_DOM_TradeGateEnable)
   {
      // Original terminal execution guards above take precedence over DOM veto.
      ZeroMemory(bookDecision);
      DOMClearSnapshot(bookDecision.snapshot);
      bookDecision.state=BOOK_UNAVAILABLE;
      bookDecision.beginUS=GetMicrosecondCount();
      bookDecision.signalClock=iTime(Symbol(),Inp_SignalTF,0);
      bookDecision.contextClock=iTime(Symbol(),Inp_ContextTF,0);
      ENUM_APS ready;
      double currentEff,currentTrigger,currentLast;
      if(!DOMGateDecisionCurrent(bookDecision,dispatchTick,bookOriginal,false,bookIntent,
                         ready,currentEff,currentTrigger,currentLast,finalExec,lots,sl,tp))
      {
         if(StringFind(bookDecision.reason,"ABS_CONT_DECISION_")==0)
            return BookDecisionRejectUnprepared();
         if(ready==APS_ENDED_REEVAL_ALLOWED) return SEND_CANCEL_REEVAL;
         if(ready==APS_TRADE_OR_POSITION) return SEND_TRADE_OR_POSITION;
         if(!armed.active || ready==APS_ENDED_FAIL_CLOSED) return
SEND_FINAL_FAILURE;
         return
DOMGateDefer(bookDecision,"CURRENT_CONDITIONS_NOT_READY_BEFORE_INTENT");
      }
      effort=currentEff; trigger=currentTrigger; gLastBreakoutPrice=currentLast;
   }
   if(Inp_DecisionMode!=DECISION_ORIGINAL && !BookDecisionDispatchValid(bookOriginal))
      return BookDecisionRejectUnprepared();
   ulong bookPrepareBegin=Inp_DOM_TradeGateEnable?GetMicrosecondCount():0;
   if(!Inp_DOM_TradeGateEnable) armed.lots=lots; // Original gate-off behavior.
   if(!PreparePendingExec(direction,armed.route,mode,finalExec,lots,sl,tp))
   {
      if((Inp_DOM_TradeGateEnable || Inp_DecisionMode!=DECISION_ORIGINAL) &&
         (HasExecutionInFlight() || gEntryJournalInvalid || gExitJournalInvalid))
         return SEND_FINANCIAL_UNRESOLVED;
      return SEND_FINAL_FAILURE;
   }
  if(!BookRiskPrepareEntry())
  {
     // Still PREPARED: no entry API has been called. Retain the original guard
     // if durable no-dispatch cleanup cannot be proved.
     if(!ReleasePreparedRequest(false)) return SEND_FINANCIAL_UNRESOLVED;
     return SEND_FINAL_FAILURE;
  }
  gPendingExec.breakoutPrice=gLastBreakoutPrice;
  gPendingExec.breakoutPriceAvailable=gLastBreakoutPrice>0;
  if(Inp_DecisionMode!=DECISION_ORIGINAL) bookIntent=gPendingExec;
  if(Inp_DOM_TradeGateEnable)
  {
     ulong elapsed=GetMicrosecondCount()-bookPrepareBegin;
     gBookGatePrepareCalls++; gBookGatePrepareSumUS+=(double)elapsed;
     if(elapsed>gBookGatePrepareMaxUS) gBookGatePrepareMaxUS=elapsed;
     bookIntent=gPendingExec;
     ENUM_APS ready;
     double currentEff,currentTrigger,currentLast;
     if(!DOMGateDecisionCurrent(bookDecision,dispatchTick,bookOriginal,true,bookIntent,
                        ready,currentEff,currentTrigger,currentLast,finalExec,lots,sl,tp))
     {
        if(StringFind(bookDecision.reason,"ABS_CONT_DECISION_")==0)
           return BookDecisionRejectPrepared(bookOriginal,bookIntent,bookApiCallStarted,ready);
        return DOMGateRejectPrepared(bookDecision,"CURRENT_CONDITIONS_CHANGED_DURING_PREPARE",
                            bookOriginal,bookIntent,bookApiCallStarted,ready);
     }
    gLastBreakoutPrice=currentLast;
 }
 if(Inp_DecisionMode!=DECISION_ORIGINAL && !Inp_DOM_TradeGateEnable)
 {
    ENUM_APS ready;
    if(!BookDecisionRevalidateNoBook(bookOriginal,bookIntent,ready,finalExec,lots,sl,tp,
                                   decisionSignalClock,decisionContextClock))
       return BookDecisionRejectPrepared(bookOriginal,bookIntent,bookApiCallStarted,ready);
 }
 ulong bookJournalBegin=Inp_DOM_TradeGateEnable?GetMicrosecondCount():0;
 if(!MarkRequestDispatchPossible(false))
 {
    if(Inp_DecisionMode!=DECISION_ORIGINAL)
    {
       bookIntent.dispatchPhase=gPendingExec.dispatchPhase;
       return BookDecisionRejectPrepared(bookOriginal,bookIntent,bookApiCallStarted,APS_STILL_ARMED);
    }
    if(Inp_DOM_TradeGateEnable)
    {
       bookIntent.dispatchPhase=gPendingExec.dispatchPhase;
       return DOMGateRejectPrepared(bookDecision,"DISPATCH_JOURNAL_WRITE_FAILED",
                    bookOriginal,bookIntent,bookApiCallStarted,APS_STILL_ARMED);
    }
    ResetPendingExec(); return SEND_FINAL_FAILURE;
 }
 if(Inp_DOM_TradeGateEnable)
 {
    ulong elapsed=GetMicrosecondCount()-bookJournalBegin;
    gBookGateJournalCalls++; gBookGateJournalSumUS+=(double)elapsed;
    if(elapsed>gBookGateJournalMaxUS) gBookGateJournalMaxUS=elapsed;
    // The same call stack has still not called PositionOpen; update ONLY phase witness.
    bookIntent.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
    ENUM_APS ready;
    double currentEff,currentTrigger,currentLast;
    if(!DOMGateDecisionCurrent(bookDecision,dispatchTick,bookOriginal,true,bookIntent,
                     ready,currentEff,currentTrigger,currentLast,finalExec,lots,sl,tp))
    {
       if(StringFind(bookDecision.reason,"ABS_CONT_DECISION_")==0)
          return BookDecisionRejectPrepared(bookOriginal,bookIntent,bookApiCallStarted,ready);
       return DOMGateRejectPrepared(bookDecision,"CURRENT_CONDITIONS_CHANGED_DURING_DISPATCH_JOURNAL",
                            bookOriginal,bookIntent,bookApiCallStarted,ready);
    }
    armed.lots=lots;
    gLastBreakoutPrice=currentLast;
 }
 if(Inp_DecisionMode!=DECISION_ORIGINAL)
 {
    bookIntent.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
    if(!Inp_DOM_TradeGateEnable)
    {
       ENUM_APS ready;
       if(!BookDecisionRevalidateNoBook(bookOriginal,bookIntent,ready,finalExec,lots,sl,tp,
                                      decisionSignalClock,decisionContextClock))
          return BookDecisionRejectPrepared(bookOriginal,bookIntent,bookApiCallStarted,ready);
    }
    // PASS is strictly memory-only after the last book read: no export, logging or history API.
    if(!BookDecisionDispatchValid(bookOriginal))
       return BookDecisionRejectPrepared(bookOriginal,bookIntent,bookApiCallStarted,APS_STILL_ARMED);
 }
 ulong bookDispatchStartUS=Inp_DOM_TradeGateEnable?GetMicrosecondCount():0;
 bookApiCallStarted=true; // immediately BEFORE the only entry API call
 bool
sent=trade.PositionOpen(Symbol(),type,lots,finalExec,sl,tp,"RC1|"+armed.route+"|"+mode);
 uint ret=trade.ResultRetcode();
 MqlTradeResult executionResult;
 trade.Result(executionResult);
 BookDiagDispatch(executionResult);

CompletePendingExec(sent,ret,trade.ResultOrder(),trade.ResultDeal(),executionResult.request_id);
 bool accepted=sent && (ret==TRADE_RETCODE_DONE ||
ret==TRADE_RETCODE_PLACED || ret==TRADE_RETCODE_DONE_PARTIAL);

WriteAuditRow(accepted?"REQUEST_ACCEPTED":"ORDER_FAILED",dStr,mode,finalExec
,posRel,distD1,effort,trigger);
 if(Inp_DOM_TradeGateEnable)
 {
    // Only timing scalars and bounded diagnostics, never a return-value dependency.
    ulong dispatchGap=bookDispatchStartUS-bookDecision.beginUS;
    if(dispatchGap>gBookGateDispatchMaxUS) gBookGateDispatchMaxUS=dispatchGap;
    if(accepted)
    {
    gBookGateReleased++;
    if(DOMGateLogAllowed())
    PrintFormat("[BOOK_GATE][BOOK_ENTRY_RELEASED] symbol=%s dir=%d armedAt=%I64d waited=%s bidPct=%.8f askPct=%.8f; request accepted, not a fill or profit guarantee",

gBookGateSymbol,direction,(long)armed.armedAt,BStr(gBookGateWaiting),bookDecision.pctBid,bookDecision.pctAsk);
    }
  }
  if((Inp_DOM_TradeGateEnable || Inp_DecisionMode!=DECISION_ORIGINAL) && !accepted &&
     (HasExecutionInFlight() || gEntryJournalInvalid || gExitJournalInvalid))
     return SEND_FINANCIAL_UNRESOLVED;
  return accepted?SEND_ACCEPTED:SEND_FINAL_FAILURE;
}

//=====================================================================
// STAGE 1 — EVALUATE MATRIX
//=====================================================================
ENUM_MSS SnapshotForSignal(MatrixSnapshot &out)
{
   datetime bar=iTime(Symbol(),Inp_SignalTF,0);
   if(!gCachedMicroReady || gCachedMicroBar!=bar)
   {
    ulong begin=GetMicrosecondCount();
    ComputeMatrixSnapshot(gCachedMicroSnapshot);
    if(iTime(Symbol(),Inp_SignalTF,0)!=bar)
       gCachedMicroSnapshot.status=MSS_STRUCT_INVALID; // discard a torn bar
// snapshot
    gCachedMicroBar=bar;
    gCachedMicroReady=true;
    gLastTelemetryMatrix=gCachedMicroSnapshot;
    gLastTelemetryMatrixValid=true;
    gLastTelemetrySignalBar=iTime(Symbol(),Inp_SignalTF,1);
    RecordPerf(perfMicro,(double)(GetMicrosecondCount()-begin));
    BookDiagMatrix(gCachedMicroSnapshot,gLastTelemetrySignalBar);
    if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseCaptureSnapshot(gCachedMicroSnapshot,bar);
  }
  out=gCachedMicroSnapshot;
  return out.status;
}

void EvaluateMatrix()
{
  gLiveDirectionTelemetryValid=false;
  gLastBreakoutPrice=0;
 MatrixSnapshot s;
 ENUM_MSS status=SnapshotForSignal(s);

// Gates fail-closed
if(status==MSS_VWAP_D1_INVALID)
{ WriteAuditRow("VWAP_D1_INVALID","NONE","NONE",0,0,0,0,0); return; }
if(status==MSS_SIGMA_INVALID)
{ WriteAuditRow("SIGMA_INVALID","NONE","NONE",0,0,0,0,0); return; }
if(status==MSS_MACRO_INVALID)
{
WriteAuditRow("MACRO_INVALID","NONE","NONE",s.price,s.posRel,s.distAbs,s.effort,0);
  WriteShadowRow("MACRO_INVALID",s); return; }
if(status==MSS_STRUCT_INVALID) return;
if(status==MSS_STOP_KAMIKAZE_CONT_ONLY)
{ WriteAuditRow("KAMIKAZE_GLASS","NONE","NONE",s.price,s.posRel,0,0,0); return; }
if(status==MSS_STOP_NO_C5_TRIGGER)
{ WriteAuditRow("NO_C5_TRIGGER","NONE","NONE",s.price,s.posRel,0,0,0); return; }
if(status!=MSS_OK) return;

// Atualizar cache de bandas
UpperBand1=s.upper; LowerBand1=s.lower;

 // Log de FOLLOWING_EXTENSION (telemetria, não bloqueia nada além do que o C1 já
// bloqueia)
  if(Inp_EnableAbsorption&&s.absFollowingExtension)
    PrintFormat("[SCALPER][ABS_FOLLOWING_EXTENSION_BLOCK] Dir=%s PriceMove=%.4f PocMove=%.4f FLOW=extension",
       DirStr(s.dir),s.priceMove,s.pocMove);
// ROUTE_CONFLICT_BLOCK
if(s.absValid&&s.contValid)
{
    PrintFormat("[SCALPER][ROUTE_CONFLICT_BLOCK] ABS(dir=%s ctx=%s) e CONT(dir=%s) simultaneamente validas. BLOQUEADO.",
     DirStr(s.dir),PocStateStr(s.pocState),DirStr(s.dirCont));

WriteAuditRow("ROUTE_CONFLICT_BLOCK","NONE","NONE",s.price,s.posRel,s.distAbs,s
.effort,0);
   WriteShadowRow("ROUTE_CONFLICT",s);
   return;
 }

// Sem confluência
if(!s.absValid&&!s.contValid)
{
    int d2=(s.dir!=0)?s.dir:s.dirCont;

WriteAuditRow("NO_CONFLUENCE",DirStr(d2),"NONE",s.price,s.posRel,s.distAbs,s.effort,0
);
   WriteShadowRow("NO_CONFLUENCE",s);
   return;
 }

// Selecionar rota
bool useCont=(!s.absValid&&s.contValid);
int dirSel =useCont?s.dirCont:s.dir;
bool turboSel=useCont?s.turboCont:s.turboAbs;
int scoreSel=useCont?s.scoreContEff:s.scoreEff;
string mode;
if(useCont) mode=turboSel?"TURBO_CONT":"BASE_CONT";
else mode=turboSel?"TURBO":"BASE";

// Stage 1 arms only a thesis; lots are resolved at the final executable price.
double lots=0.0;

 // Região (N barras M1 fechadas)
 double regHigh=-DBL_MAX, regLow=DBL_MAX;
 MqlRates regionRates[];
 int
regionCopied=CopyRates(Symbol(),Inp_SignalTF,1,Inp_Region_Candles,regionRates);
 bool regionOk=(regionCopied==Inp_Region_Candles);
 if(regionOk)
 {
     for(int i=0;i<regionCopied;i++)
     {
if(regionRates[i].high<=0||regionRates[i].low<=0||regionRates[i].high<regionRates[i].low)
       { regionOk=false; break; }
       if(regionRates[i].high>regHigh) regHigh=regionRates[i].high;
       if(regionRates[i].low <regLow) regLow =regionRates[i].low;
    }
  }
  if(!regionOk||regHigh<=-DBL_MAX||regLow>=DBL_MAX||regHigh<=regLow)
  {

WriteAuditRow("REGION_INVALID",DirStr(dirSel),mode,s.price,s.posRel,s.distAbs,s.effort,0)
;
    return;
  }

 // Assess only the already-selected original route; conflicts returned above.
 if(Inp_DecisionMode!=DECISION_ORIGINAL &&
    !BookDecisionCandidate(s,dirSel,useCont,gCachedMicroBar)) return;

 // ARMAR
 if(iTime(Symbol(),Inp_SignalTF,0)!=gCachedMicroBar) return; // closed snapshot/region
// must share the same clock
 gLastBreakoutPrice=0;
 gLiveDirectionTelemetryValid=false;
 gLateMismatchLogged=false; gSpreadHoldLogged=false;
 armed.active =true;
armed.dir =dirSel;
armed.regionHigh =regHigh;
armed.regionLow =regLow;
armed.activeSL_Pts =gSL_Pts;
armed.activeTP_Pts =gTP_Pts;
armed.regionEndTime =iTime(Symbol(),Inp_SignalTF,1);
armed.mode        =mode;
armed.lots =lots;
armed.route =useCont?"CONT":"ABS";
armed.breakoutEffortMin=useCont?Inp_CONT_BreakoutEffort:Inp_ABS_BreakoutEffort;
armed.armedAt     =TimeTradeServer();
armed.sameSideGlassLogged=false;
armed.posRel=s.posRel; armed.distD1=s.distAbs; armed.effort=s.effort;
armed.vwapVig=s.vwapVig;
armed.c1=(int)(useCont?s.c1Cont:s.c1);
armed.c2=(int)(useCont?s.c2Cont:s.c2);
armed.c3=(int)(useCont?s.c3Cont:s.c3);
armed.c4=(int)(useCont?s.c4Cont:s.c4);
armed.c5=(int)(useCont?s.c5ContOk:s.c5AbsOk);
armed.scoreEff=scoreSel;
  BookDecisionBind(); // Freeze identity without changing armedAt or timeout.

double armTrigger=ComputeTrigger(dirSel,regHigh,regLow);
PrintFormat("[SCALPER][ARMED_%s] %s %s %.2f lots SCORE=%d/3 SL=%.1f "
"High=%.4f Low=%.4f Trigger=%.4f OndaViva>=%.2f | "
"Macro: AbsDir=%s ContDir=%s PosRelM3=%.4f",
armed.route,mode,DirStr(dirSel),lots,scoreSel,gSL_Pts,
regHigh,regLow,armTrigger,armed.breakoutEffortMin,
DirStr(gMacro.macroAbsDir),DirStr(gMacro.macroContDir),gMacro.posRel);
WriteAuditRow("ARMED",DirStr(dirSel),mode,s.price,s.posRel,s.distAbs,s.effort,armTrigger);
  WriteShadowRow("ARMED",s);
  BookDiagSelected(s,armed,armTrigger);
  if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseSelected(s,armed,armTrigger,gCachedMicroBar);
}

//=====================================================================
// STAGE 2 — PROCESS ARMED SIGNAL
// Preserva toda a lógica da v2.44.
// Diferenças: timeout por tempo, WW M1, LATE_DIRECTION_BLOCK novo.
//=====================================================================
ENUM_APS CheckArmedMarketReady(double &curEff,double &trigger,double &last,MqlTick
&validatedStageTick)
{
   BookDiagBeginEvaluation();
   curEff=0.0; trigger=0.0; last=0.0;
   datetime now=TimeTradeServer();

// Timeout por tempo (novo vs. v2.44 que usava barras)
if(armed.armedAt>0&&(now-armed.armedAt)>=(datetime)Inp_ArmedTimeoutSec)
{
    PrintFormat("[SCALPER][TIMEOUT_ARMED] %s %s | Idade=%ds | CANCELADO.",
     DirStr(armed.dir),armed.route,(int)(now-armed.armedAt));
    WriteAuditRow("TIMEOUT_ARMED",DirStr(armed.dir),armed.mode,0,
     armed.posRel,armed.distD1,armed.effort,0);
    ResetArmedSignal();
    return APS_ENDED_REEVAL_ALLOWED;
}

// Fim de sessão
MqlDateTime dt; TimeToStruct(now,dt);
int hhmm=dt.hour*100+dt.min;
if(hhmm>=Inp_StopEntryHHMM)
{
    WriteAuditRow("ABORT_SESSION_END",DirStr(armed.dir),armed.mode,0,
     armed.posRel,armed.distD1,armed.effort,0);
    ResetArmedSignal();
    return APS_ENDED_FAIL_CLOSED;
}

 // Evento de negócio real
 MqlTick tk;
 if(!SymbolInfoTick(Symbol(),tk)) { BookDiagWait(BD_DATA,"WAIT_DATA:TICK_UNAVAILABLE"); return APS_STILL_ARMED; }
 validatedStageTick=tk;
 if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseStageSample(tk);
 bool
realTradeEvent=((tk.flags&TICK_FLAG_LAST)!=0)||((tk.flags&TICK_FLAG_VOLUME)!=0)||
     ((tk.flags&TICK_FLAG_BUY)!=0)||((tk.flags&TICK_FLAG_SELL)!=0);
if(!realTradeEvent) { BookDiagWait(BD_DATA,"WAIT_DATA:NOT_REAL_TRADE_EVENT"); return APS_STILL_ARMED; }

last=tk.last;
if(last<=0) { BookDiagWait(BD_DATA,"WAIT_DATA:LAST_UNAVAILABLE"); return APS_STILL_ARMED; }
BookDiagPass(BD_DATA);
// Trigger
trigger=ComputeTrigger(armed.dir,armed.regionHigh,armed.regionLow);
BookDiagTick(tk,trigger);
bool breakout=false;
if(armed.dir==1&&last>=trigger) breakout=true;
if(armed.dir==-1&&last<=trigger) breakout=true;
if(!breakout) { BookDiagWait(BD_BREAKOUT,"WAIT_BREAKOUT"); return APS_STILL_ARMED; }
BookDiagPass(BD_BREAKOUT);

// Preço executável
double execPrice=(armed.dir==1)?tk.ask:tk.bid;
if(execPrice<=0) { BookDiagWait(BD_DATA,"WAIT_DATA:EXECUTABLE_PRICE"); return APS_STILL_ARMED; }

// Overshoot
double overLast=(armed.dir==1)?(last-trigger):(trigger-last);
double overExec=(armed.dir==1)?(execPrice-trigger):(trigger-execPrice);
double overshoot=MathMax(overLast,overExec);
BookDiagOvershoot(overshoot);
if(overshoot>gMaxOvershoot)
{
    PrintFormat("[SCALPER][OVERSHOOT_BLOCK] Last=%.4f Exec=%.4f Trig=%.4f Over=%.4f Max=%.4f",
     last,execPrice,trigger,overshoot,gMaxOvershoot);
    WriteAuditRow("OVERSHOOT_BLOCK",DirStr(armed.dir),armed.mode,last,
     armed.posRel,armed.distD1,armed.effort,trigger);
    ResetArmedSignal();
    return APS_ENDED_FAIL_CLOSED;
}

// Onda viva M1 (usa cache M1 — idêntico à v2.44 mas em M1)
if(!wwValid) { BookDiagWait(BD_DATA,"WAIT_DATA:WEIS_CACHE"); return APS_STILL_ARMED; }
double curVol,avgVol; int waveDir;
ComputeLiveWaveO1(curEff,curVol,avgVol,waveDir);
BookDiagLive(curEff,curVol,avgVol,waveDir);
if(waveDir!=armed.dir) { BookDiagWait(BD_WAVE_DIRECTION,"WAIT_LIVE_WAVE_DIRECTION"); return APS_STILL_ARMED; }
BookDiagPass(BD_WAVE_DIRECTION);
if(curEff<armed.breakoutEffortMin) { BookDiagWait(BD_WAVE_EFFORT,"WAIT_LIVE_WAVE_EFFORT"); return APS_STILL_ARMED; }
BookDiagPass(BD_WAVE_EFFORT);

// VWAP viva
double liveVwap=0;
if(!GetLiveVwapSnapshot((ulong)tk.time_msc,liveVwap))
{
    WriteAuditRow("LATE_VWAP_INVALID",DirStr(armed.dir),armed.mode,last,
    armed.posRel,armed.distD1,curEff,trigger);
    ResetArmedSignal();
  return APS_ENDED_FAIL_CLOSED;
}
double lateUpper=liveVwap+SigmaD1*BandMultiplier;
double lateLower=liveVwap-SigmaD1*BandMultiplier;
double lateRange=lateUpper-lateLower;
if(lateRange<=0)
{
    WriteAuditRow("LATE_VWAP_INVALID",DirStr(armed.dir),armed.mode,last,
   armed.posRel,armed.distD1,curEff,trigger);
  ResetArmedSignal();
  return APS_ENDED_FAIL_CLOSED;
}
double livePosRel=(last-lateLower)/lateRange;
BookDiagLiveBands(liveVwap,lateLower,lateUpper,livePosRel);

// New hypothesis, OFF in baseline. Neutrality is also a mismatch.
int liveDirAbs=0;
if(livePosRel>=Inp_VWAP_Inner_Pct) liveDirAbs=-1;
else if(livePosRel<=1.0-Inp_VWAP_Inner_Pct) liveDirAbs=1;
int liveDirCont=(liveDirAbs==0)?0:-liveDirAbs;
bool lateDirectionMismatch=(armed.route=="ABS")?
    liveDirAbs!=armed.dir : liveDirCont!=armed.dir;
gLiveDirectionTelemetryValid=true;
gLiveDirAbs=liveDirAbs; gLiveDirCont=liveDirCont;
gLateDirectionMismatch=lateDirectionMismatch;
if(lateDirectionMismatch)
{
   if(Inp_EnableLateDirectionBlock)
   {
    WriteAuditRow("LATE_DIRECTION_BLOCK",DirStr(armed.dir),armed.mode,last,
     livePosRel,armed.distD1,curEff,trigger);
    ResetArmedSignal();
    return APS_ENDED_FAIL_CLOSED;
  }
  if(!gLateMismatchLogged)
  {
  gLateMismatchLogged=true;
WriteAuditRow("LATE_DIRECTION_MISMATCH_SHADOW",DirStr(armed.dir),armed.mode,
last,
      livePosRel,armed.distD1,curEff,trigger);
    }
  }

    // LATE_GLASS_BLOCK (idêntico à v2.44)
    bool
dynamicGlass=(livePosRel>Inp_VWAP_Outer_Pct)||(livePosRel<(1.0-Inp_VWAP_Outer_Pct
));
    bool isAbsRoute=(armed.route=="ABS");
    bool oppositeGlassABS=
       (armed.dir==-1&&livePosRel<(1.0-Inp_VWAP_Outer_Pct))||
       (armed.dir== 1&&livePosRel>Inp_VWAP_Outer_Pct);
   bool lateGlassBlock=isAbsRoute?oppositeGlassABS:dynamicGlass;
   if(lateGlassBlock)
   {
  PrintFormat("[SCALPER][LATE_GLASS_BLOCK] Rota=%s Dir=%s LivePosRel=%.4f",
    armed.route,DirStr(armed.dir),livePosRel);
 WriteAuditRow("LATE_GLASS_BLOCK",DirStr(armed.dir),armed.mode,last,
   livePosRel,armed.distD1,curEff,trigger);
 ResetArmedSignal();
 return APS_ENDED_FAIL_CLOSED;
}
if(isAbsRoute&&dynamicGlass&&!armed.sameSideGlassLogged)
{
    armed.sameSideGlassLogged=true;
    PrintFormat("[SCALPER][ABS_LATE_GLASS_SAMESIDE_ALLOW] %s ABS LivePosRel=%.4f",
      DirStr(armed.dir),livePosRel);
}

    return APS_ENTRY_READY;
}

ENUM_APS CheckArmedEntryReady(double &curEff,double &trigger,double &last,MqlTick
&validatedStageTick)
{
   ENUM_APS market=CheckArmedMarketReady(curEff,trigger,last,validatedStageTick);
   if(market!=APS_ENTRY_READY) return market;
// Position, pending execution and daily quota remain operational guards.
if(HasExecutionInFlight()) { BookDiagWait(BD_OTHER,"WAIT_OTHER_GATE:EXECUTION_IN_FLIGHT"); BookDiagFinish("CANCEL_EXISTING_EXECUTION"); ResetArmedSignal(); return APS_TRADE_OR_POSITION; }
// Posição / cota / risco diário
if(HasOpenPosition())          { BookDiagWait(BD_OTHER,"WAIT_OTHER_GATE:OPEN_POSITION"); BookDiagFinish("CANCEL_EXISTING_POSITION"); ResetArmedSignal(); return APS_TRADE_OR_POSITION; }
if(ordersEnteredToday>=Inp_MaxTradesDay) { BookDiagWait(BD_OTHER,"WAIT_OTHER_GATE:DAILY_QUOTA"); BookDiagFinish("CANCEL_DAILY_QUOTA"); ResetArmedSignal(); return
APS_TRADE_OR_POSITION; }
if(dailyRiskBlocked)
{
    WriteAuditRow("DAILY_RISK_BLOCK",DirStr(armed.dir),armed.mode,last,
     armed.posRel,armed.distD1,armed.effort,trigger);
    ResetArmedSignal();
    return APS_ENDED_FAIL_CLOSED;
}
// Spread
if(!SpreadOk())
{
    BookDiagWait(BD_SPREAD,"WAIT_SPREAD");
    if(!gSpreadHoldLogged)
    {
       gSpreadHoldLogged=true;
       WriteAuditRow("HOLD_SPREAD",DirStr(armed.dir),armed.mode,last,
         armed.posRel,armed.distD1,armed.effort,trigger);
    }
    return APS_STILL_ARMED;
}

    BookDiagPass(BD_SPREAD);
    return APS_ENTRY_READY;
}

ENUM_APS ResponseBaseProcessArmedSignal()
{
   double curEff,trigger,last;
   MqlTick validatedStageTick;
   ENUM_APS readiness=CheckArmedEntryReady(curEff,trigger,last,validatedStageTick);
   // Original STILL can be invalidated objectively, never upgraded. READY
   // continues through original terminal sizing/stops/margin in SendOrder before
   // its new gate, which is still before PreparePendingExec or any dispatch.
   if(readiness==APS_STILL_ARMED) readiness=BookDecisionArmedGate(readiness);
   if(readiness!=APS_ENTRY_READY) return readiness;
if(!Inp_DOM_TradeGateEnable)
PrintFormat("[SCALPER][DISPARO_%s] %s Trigger=%.4f Last=%.4f WW_EFF=%.2f>=%.2f Modo=%s",
armed.route,DirStr(armed.dir),trigger,last,curEff,armed.breakoutEffortMin,armed.mode);
   gLastBreakoutPrice=last; // observed real trade, never fabricated
   ENUM_SEND_OUTCOME outcome=SendOrder(armed.dir,armed.lots,armed.mode,
    armed.activeSL_Pts,armed.activeTP_Pts,
     armed.posRel,armed.distD1,curEff,trigger);
   BookDiagSendOutcome(outcome);
   if(outcome==SEND_FINANCIAL_UNRESOLVED)
   {
      // Ending the original signal never clears its financial obligation.
      ResetArmedSignal(); return APS_TRADE_OR_POSITION;
   }
   if(outcome==SEND_WAIT_ARMED)
   {
      // WAIT is legal only with no financial obligation. Never erase a pending
      // intent here merely to preserve ARMED. Next event uses original guards.
      if((Inp_DOM_TradeGateEnable || Inp_DecisionMode!=DECISION_ORIGINAL) &&
         (HasExecutionInFlight() || gAccountingUnresolved ||
          gEntryJournalInvalid || gExitJournalInvalid))
      { ResetArmedSignal(); return APS_TRADE_OR_POSITION; }
      return APS_STILL_ARMED;
   }
   if(outcome==SEND_ORIGINAL_CANCEL)
   { ResetArmedSignal(); return APS_ENDED_FAIL_CLOSED; }
   if(outcome==SEND_CANCEL_REEVAL) return APS_ENDED_REEVAL_ALLOWED;
   if(outcome==SEND_TRADE_OR_POSITION) return APS_TRADE_OR_POSITION;
   ResetArmedSignal();
   return
outcome==SEND_ACCEPTED?APS_TRADE_OR_POSITION:APS_ENDED_FAIL_CLOSED;
}

//=====================================================================
// PERSISTENCE (adaptada da v2.44, chaves prefixadas com "SCALP_RC1_")
//=====================================================================
//=====================================================================
// EOD (adaptado da v2.44)
//=====================================================================
void ProcessEOD(int hhmm)
{
  if(hhmm<Inp_EOD_CloseHHMM) return;
  if(armed.active)
  {

WriteAuditRow("ABORT_EOD",DirStr(armed.dir),armed.mode,0,armed.posRel,armed.distD1
,armed.effort,0);
        ResetArmedSignal();
     }
     if(eodDone) return;
     // A live own order can be an entry, a close, or unresolved. Never duplicate it.
     if(gPendingOrderClassificationUnresolved || gPendingExit.active || gPendingExec.active ||
        gOrderObligationScanUnresolved ||
        gRequestJournalUnresolved || gRequestJournalWritePending ||
        gEntryJournalCleanupPending || gExitJournalCleanupPending ||
gIdentityLossUnresolved
||
HasOwnPendingOrder())
     {
        // Recovery still runs in OnTimer; this diagnostic must precede the guards.
        static datetime nextBlockedDiagnostic=0;
        datetime blockedAt=TimeTradeServer();
        if(blockedAt>=nextBlockedDiagnostic && HasOwnPositionStrict())
        {
           nextBlockedDiagnostic=blockedAt+10;
           PrintFormat("[SCALPER][EOD_CRITICAL_BLOCKED] hhmm=%d entry=%d exit=%d journal_invalid=%d journal_write=%d entry_cleanup=%d exit_cleanup=%d; reconciliation required, no close dispatched.",
            hhmm,(int)gPendingExec.active,(int)gPendingExit.active,
         (int)gRequestJournalUnresolved,(int)gRequestJournalWritePending,
         (int)gEntryJournalCleanupPending,(int)gExitJournalCleanupPending);
     }
     return;
    }
    if(!HasOwnPositionStrict())
   { if(!HasExecutionInFlight() && !gLiveOwnershipUnresolved) eodDone=true; return; }
 if(hhmm>=1830)
 {
     if(!eodStuckLogged) { eodStuckLogged=true; Print("[SCALPER][EOD_STUCK] Own position remains open after 18:30."); }
     return;
 }
 datetime now=TimeTradeServer();
 if(eodNextTry>0 && now<eodNextTry) return;
 eodNextTry=now+10;
 for(int i=PositionsTotal()-1;i>=0;i--)
 {
  if(!posInfo.SelectByIndex(i) || posInfo.Symbol()!=Symbol() ||
posInfo.Magic()!=(long)gMagicCore) continue;
  ulong ticket=posInfo.Ticket(), identifier=posInfo.Identifier();
  if(!OwnPositionSafe(identifier))
  { Print("[SCALPER][EOD_FOREIGN_NETTING_BLOCK] Ownership ambiguous; manual reconciliation required."); return; }
  BeginExitIntent(identifier,"EOD");
  gPendingExit.dispatchPhase=REQUEST_PREPARED;
  trade.SetExpertMagicNumber(gMagicCore);
  gPendingExit.positionTicket=ticket;
  gPendingExit.requestSnapshot.action=TRADE_ACTION_DEAL;
  gPendingExit.requestSnapshot.position=ticket;
  gPendingExit.requestSnapshot.symbol=Symbol();
  gPendingExit.requestSnapshot.magic=(ulong)gMagicCore;
  gPendingExit.requestSnapshot.type=(posInfo.PositionType()==POSITION_TYPE_BUY?
     ORDER_TYPE_SELL:ORDER_TYPE_BUY);
  gPendingExit.requestSnapshot.volume=posInfo.Volume();
  gPendingExit.requestSnapshot.price=SymbolInfoDouble(Symbol(),

gPendingExit.requestSnapshot.type==ORDER_TYPE_BUY?SYMBOL_ASK:SYMBOL_BID);
 gPendingExit.requestSnapshot.deviation=(ulong)gMaxDeviationPts;
 gPendingExit.requestSnapshot.type_filling=ORDER_FILLING_FOK;
 if(!PersistRequestJournal(true))
 {
    PrintFormat("[SCALPER][EOD_PERSISTENCE_CRITICAL] pid=%I64u PREPARED write failed; no close dispatched.",identifier);
    FailExitIntent(identifier,true); return;
 }
 if(!MarkRequestDispatchPossible(true))
 {
     PrintFormat("[SCALPER][EOD_PERSISTENCE_CRITICAL] pid=%I64u dispatch barrier failed; no close dispatched.",identifier);
     FailExitIntent(identifier,true); return;
  }
  trade.PositionClose(ticket);
    MqlTradeResult closeResult;
    trade.Result(closeResult);
    trade.Request(gPendingExit.requestSnapshot);
    uint ret=closeResult.retcode;
    CompletePendingExit(closeResult);
    PrintFormat("[SCALPER][EOD_REQUEST] ticket=%I64u ret=%u; closure requires confirmed deals.",ticket,ret);
    break;
    }
}

//=====================================================================
// DAILY RESET (adaptado da v2.44)
//=====================================================================
void DailyReset()
{
  UpperBand1=0; LowerBand1=0;
  ResetArmedSignal(); ResetVwapCache(); ResetMacroContext(gMacro);
  wwValid=false; wwCurrentWaveBars=0; wwWaveStartPrice=0;
  VWAP_D1=0; H1=0; L1=0; VWAP_D1_Official=false; SigmaD1=0;
  d1Ready=false; nextD1Retry=0;
  eodDone=false; eodStuckLogged=false; eodNextTry=0;
  gLastMatrixEvalBar=0; gCachedMicroReady=false; gCachedMicroBar=0;
  gLastTelemetryMatrixValid=false; gLastTelemetrySignalBar=0;
  gLiveDirectionTelemetryValid=false;
  hardFlipsPerDay=0; armedCancelHard=0; oppositeRearmAfterHard=0;
  gLastBreakoutPrice=0; gLateMismatchLogged=false; gSpreadHoldLogged=false;
  ResetPerfStat(perfMacro); ResetPerfStat(perfMicro); ResetPerfStat(perfStage2);
  gLastPerfLoggedMicroCount=0;
  ResetAccountingDay(); // preserve open lifecycle and pending requests across midnight
  TryCalcD1();
  BootstrapCachesNoTrade();
}

//=====================================================================
// ON INIT
//=====================================================================
bool Positive(double value)
{ return MathIsValidNumber(value) && value>0; }
bool OnPriceGrid(double value)
{ return Positive(value) && MathAbs(value/gTickSize-MathRound(value/gTickSize))<=1e-6; }
bool ValidHHMM(int hhmm)
{ return hhmm>=0 && hhmm/100<=23 && hhmm%100<=59; }
bool OnVolumeGrid(double value, double step)
{ return Positive(value) && MathAbs(value/step-MathRound(value/step))<=1e-6; }
bool ValidateRC1Inputs()
{
   int ctxSec=PeriodSeconds(Inp_ContextTF), sigSec=PeriodSeconds(Inp_SignalTF);
   if(ctxSec<=0 || sigSec<=0 || ctxSec<=sigSec || ctxSec%sigSec!=0) return false;
   if(!ValidHHMM(Inp_StartHHMM) || !ValidHHMM(Inp_StopEntryHHMM) ||
      !ValidHHMM(Inp_EOD_CloseHHMM) || Inp_StartHHMM>=Inp_StopEntryHHMM ||
      Inp_StopEntryHHMM>=Inp_EOD_CloseHHMM) return false;
   if(Inp_POC_WindowSec<=0 || Inp_ArmedTimeoutSec<=0 || Inp_Region_Candles<1 ||
      Inp_MaxTradesDay<1 || Inp_MaxTradesDay>MAX_TRADE_RECORDS) return false;
   if(!Positive(Inp_ABS_Effort) || !Positive(Inp_CONT_Effort) ||
      !Positive(Inp_ABS_BreakoutEffort) || !Positive(Inp_CONT_BreakoutEffort)) return false;
   if(!Positive(gSL_Pts) || !Positive(gTP_Pts) || !Positive(gSpreadMaxPts) ||
      !Positive(gMaxOvershoot) || !Positive(gABS_MinDisplPts) ||
      !Positive(gABS_MaxBodyPts) || !Positive(gCONT_MinDisplPts)) return false;
   if(!OnPriceGrid(gSL_Pts) || !OnPriceGrid(gTP_Pts) || !OnPriceGrid(gMaxOvershoot) ||
      !OnPriceGrid(gBreakoutMargin) || gBreakoutMargin<gTickSize-1e-9) return false;
   // Analytical thresholds are deliberately not required to be on the tick grid.
   if(!Positive(BandMultiplier) || !MathIsValidNumber(Inp_VWAP_Inner_Pct) ||
      Inp_VWAP_Inner_Pct<=0.5 || Inp_VWAP_Inner_Pct>=1 ||
      !Positive(Inp_VWAP_Outer_Pct) || Inp_VWAP_Outer_Pct<=1 ||
      !MathIsValidNumber(Inp_Rule_40_60) || Inp_Rule_40_60<=0 || Inp_Rule_40_60>=0.5 ||
      !Positive(gC3Min) || !Positive(gC3Max) || !Positive(gC2) ||
      gC3Min>gC3Max || gC3Max>=gC2 || !Positive(Inp_POC_FollowRatio)) return false;
   if(SigmaLookbackDays<1 || SigmaLookbackDays>20 || !Positive(Inp_SigmaFloor_WIN) ||
      !Positive(Inp_SigmaFloor_WDO) || Inp_CooldownSec<0 || Inp_LossCooldownSec<0)
return false;
   if(gMagicCore<=0 || gMaxDeviationPts<0) return false;
   if(Inp_SizingMode!=SIZING_FIXED && Inp_SizingMode!=SIZING_RISK_PERCENT)
return false;
   double minimum=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   double maximum=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
   if(!Positive(minimum) || !Positive(maximum) || maximum<minimum || !Positive(step)) return
false;
  if(!OnVolumeGrid(Inp_MaxLots,step) || Inp_MaxLots<minimum || Inp_MaxLots>maximum)
return false;
  if(Inp_SizingMode==SIZING_FIXED && (!OnVolumeGrid(Inp_FixedLots,step) ||
     Inp_FixedLots<minimum || Inp_FixedLots>maximum || Inp_FixedLots>Inp_MaxLots))
return false;
  if(Inp_SizingMode==SIZING_RISK_PERCENT && !Positive(Inp_RiskPerTradePct)) return
false;
  if(Inp_EnableDailyRiskStop && !Positive(Inp_MaxDailyLossR)) return false;
  if(Inp_EnableConsecutiveLossStop && Inp_MaxConsecutiveLosses<1) return false;
  if(!Inp_EnableAbsorption && !Inp_EnableContinuation) return false;
  return true;
}
void BootstrapCachesNoTrade()
{
  datetime contextBar=iTime(Symbol(),Inp_ContextTF,0);
  datetime signalBar=iTime(Symbol(),Inp_SignalTF,0);
   // Set clocks before any fallible data work. Recovery cannot synthesize a close.
   if(contextBar>0) lastContextBarTime=contextBar;
    if(signalBar>0) lastSignalBarTime=signalBar;
    gCachedMicroReady=false; gCachedMicroBar=0;
    gLastTelemetryMatrixValid=false; gLastTelemetrySignalBar=0;
    gLiveDirectionTelemetryValid=false;
    ResetArmedSignal();
    if(contextBar>0)
    {
     gVwapOk=UpdateVwapIncremental(contextBar);
     gVwapValue=(gVwapOk && vwapSumVol>0)?vwapSumPV/vwapSumVol:0;
     if(d1Ready && gVwapOk)
     {
        ulong begin=GetMicrosecondCount();
       ComputeMacroContext();
       RecordPerf(perfMacro,(double)(GetMicrosecondCount()-begin));
     }
    }
    if(signalBar>0)
    {
       gVwapOk=UpdateVwapIncremental(signalBar);
       gVwapValue=(gVwapOk && vwapSumVol>0)?vwapSumPV/vwapSumVol:0;
       RebuildWeisCache();
    }
    // Never EvaluateMatrix here, even if every cache is ready.
}

int OnInit()
{
  string sym=Symbol();
  gIsDollarFamily=(StringFind(sym,"WDO")>=0 || StringFind(sym,"DOL")>=0);
  gIsIndexFamily=!gIsDollarFamily && (StringFind(sym,"WIN")>=0 ||
StringFind(sym,"IND")>=0);
  if(!gIsDollarFamily && !gIsIndexFamily) return INIT_PARAMETERS_INCORRECT;
  gMagicCore=gIsIndexFamily?Inp_Magic_WIN:Inp_Magic_WDO;
  gC2=gIsIndexFamily?Inp_C2_WIN:Inp_C2_WDO;
  gC3Min=gIsIndexFamily?Inp_C3_Min_WIN:Inp_C3_Min_WDO;
  gC3Max=gIsIndexFamily?Inp_C3_Max_WIN:Inp_C3_Max_WDO;

gMaxDeviationPts=gIsIndexFamily?Inp_MaxDeviationPts_WIN:Inp_MaxDeviationPts_WDO;
gSpreadMaxPts=gIsIndexFamily?Inp_SpreadMaxPts_WIN:Inp_SpreadMaxPts_WDO;
gBreakoutMargin=gIsIndexFamily?Inp_BreakoutMargin_WIN:Inp_BreakoutMargin_WDO;
gMaxOvershoot=gIsIndexFamily?Inp_MaxOvershoot_WIN:Inp_MaxOvershoot_WDO;
gSL_Pts=gIsIndexFamily?Inp_SL_Pts_WIN:Inp_SL_Pts_WDO;
gTP_Pts=gIsIndexFamily?Inp_TP_Pts_WIN:Inp_TP_Pts_WDO;

gABS_MinDisplPts=gIsIndexFamily?Inp_ABS_MinPriceMovePts_WIN:Inp_ABS_MinPriceMovePts_WDO;
gABS_MaxBodyPts=gIsIndexFamily?Inp_ABS_MaxBodyPts_WIN:Inp_ABS_MaxBodyPts_WDO;
gCONT_MinDisplPts=gIsIndexFamily?Inp_CONT_MinPriceMovePts_WIN:Inp_CONT_MinPriceMovePts_WDO;
  gTickSize=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE);
  if(gTickSize<=0) gTickSize=SymbolInfoDouble(Symbol(),SYMBOL_POINT);
  if(!Positive(gTickSize) || !ValidateRC1Inputs())
  { Print("[SCALPER][FATAL] Invalid RC1 parameters; no silent correction."); return
INIT_PARAMETERS_INCORRECT; }
  if(!DOMGateValidateInputs() || !BookRiskInputsValid()) return INIT_PARAMETERS_INCORRECT;
  if(!IsFokSupported())
  { Print("[SCALPER][FATAL] FOK unsupported."); return
INIT_PARAMETERS_INCORRECT; }
  trade.SetExpertMagicNumber(gMagicCore);
  trade.SetDeviationInPoints(gMaxDeviationPts);
  trade.SetTypeFilling(ORDER_FILLING_FOK);
  trade.SetAsyncMode(false);
  ENUM_ACCOUNT_MARGIN_MODE
mm=(ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  gNetting=mm!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
  if(gNetting)
     Print("[SCALPER][SCALPER_NETTING_SHARED_SYMBOL_RISK] Remora 1.0, Remora 2.44 and Scalper do not have independent positions on the same symbol/account merely through Magic numbers.");
  MqlDateTime now; TimeToStruct(TimeTradeServer(),now);
  gDayKey=now.year*1000+now.day_of_year;
  ResetMacroContext(gMacro); ResetArmedSignal(); ResetVwapCache(); ResetOpenPos();
  InitializeAccounting();
  BookRiskManage(false); // Load/reconcile durable optional state before transactions.
  wwValid=false; wwCurrentWaveBars=0; wwWaveStartPrice=0;
 lastContextBarTime=0; lastSignalBarTime=0; gLastMatrixEvalBar=0;
 gCachedMicroReady=false; gCachedMicroBar=0;
 gLastTelemetryMatrixValid=false; gLastTelemetrySignalBar=0;
 gLiveDirectionTelemetryValid=false;
 gLastBreakoutPrice=0; gLateMismatchLogged=false; gSpreadHoldLogged=false;
 hardFlipsPerDay=0; armedCancelHard=0; oppositeRearmAfterHard=0;
 d1Ready=false; nextD1Retry=0;
 eodDone=false; eodStuckLogged=false; eodNextTry=0;
 ResetPerfStat(perfMacro); ResetPerfStat(perfMicro); ResetPerfStat(perfStage2);
 gLastPerfLoggedMicroCount=0; gLastFlushTime=0;
 RestoreDailyPersistence();
 TryCalcD1();
 BootstrapCachesNoTrade();
 BookIdentityInit();
 BookDecisionInit(); // Unavailable decision data blocks entries, never protection.
// A configurable label cannot remove the explicit schema namespace.
string prefix="Scalper01_RC1_";
if(CSVFileName!="Scalper01_RC1" && CSVFileName!="") prefix+=CSVFileName+"_";
string suffix=Symbol()+"_"+IntegerToString(gMagicCore);
gTradeCsvFileName=prefix+suffix+"_Trades.csv";
if(gBookIdentityReady) csvAuditHandle=FileOpen("BOOK1125_"+gBookRunID+"_"+suffix+"_Audit.csv",FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
 if(csvAuditHandle!=INVALID_HANDLE)
 { if(FileSize(csvAuditHandle)==0) WriteAuditHeader();
FileSeek(csvAuditHandle,0,SEEK_END); FileFlush(csvAuditHandle); }

if(gBookIdentityReady) csvShadowHandle=FileOpen("BOOK1125_"+gBookRunID+"_"+suffix+"_Shadow.csv",FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
 if(csvShadowHandle!=INVALID_HANDLE)
{ if(FileSize(csvShadowHandle)==0) WriteShadowHeader();
FileSeek(csvShadowHandle,0,SEEK_END); FileFlush(csvShadowHandle); }

csvTradeHandle=BookCsvOpenInitialFile();
  if(csvTradeHandle!=INVALID_HANDLE)
  {
     if(FileSize(csvTradeHandle)==0) WriteTradeHeader();
     FileFlush(csvTradeHandle);
     if(!InitializeTradeCsvIndex(prefix+suffix+"_Trades.csv"))
        Print("[SCALPER][TRADES_CSV_INDEX_UNAVAILABLE] Finalization records require CSV reconciliation.");
     FileSeek(csvTradeHandle,0,SEEK_END);
  }
  int timerSec=(MQLInfoInteger(MQL_TESTER)!=0)?60:1;
  if(!EventSetTimer(timerSec)) return INIT_FAILED;
  PrintFormat("[SCALPER RC1.2] %s Magic=%d Context=%s Signal=%s MacroGate=%s LateDirection=%s RejectTies=%s; edge empirical not demonstrated.",
     sym,gMagicCore,EnumToString(Inp_ContextTF),EnumToString(Inp_SignalTF),
BStr(Inp_EnableMacroDirectionGate),BStr(Inp_EnableLateDirectionBlock),BStr(Inp_RejectPOCTies));
  BookDiagInit(gBookRunID+"|"+gBookConfigHash);
  DOMRuntimeInit();
  DOMGateInit();
  if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseInit();
  RecomputeAccountingBlock();
  return INIT_SUCCEEDED;
}

//=====================================================================
// ON DEINIT
//=====================================================================
void OnDeinit(const int reason)
{
   BookDecisionDeinit();
   BookDiagDeinit();
   EventKillTimer();
   if(csvAuditHandle !=INVALID_HANDLE){ FileFlush(csvAuditHandle);
FileClose(csvAuditHandle); csvAuditHandle =INVALID_HANDLE; }
   if(csvShadowHandle!=INVALID_HANDLE){
FileFlush(csvShadowHandle);FileClose(csvShadowHandle);csvShadowHandle=INVALID_HANDLE; }
  if(csvTradeHandle !=INVALID_HANDLE){ FileFlush(csvTradeHandle);
FileClose(csvTradeHandle); csvTradeHandle =INVALID_HANDLE; }
   DOMRuntimeDeinit();
   DOMGateDeinit();
   if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseDeinit();
}

//=====================================================================
// ON TICK
//=====================================================================
// Accounting/execution uncertainty still blocks entries. This observer has no
// access to the arming path and does not populate its shared snapshot cache.
void ObserveAccountingBlockedMatrix(datetime signalBar)
{
  if(!gAccountingUnresolved || armed.active || signalBar<=0 ||
     gLastReadOnlyMatrixBar==signalBar) return;
  if(HasOpenPosition() || ordersEnteredToday>=Inp_MaxTradesDay || dailyRiskBlocked)
return;
  MqlDateTime observationTime; TimeToStruct(TimeTradeServer(),observationTime);
  int observationHHMM=observationTime.hour*100+observationTime.min;
  if(observationHHMM<Inp_StartHHMM || observationHHMM>=Inp_StopEntryHHMM) return;
  if(Inp_CooldownSec>0 && lastCloseConfirmedTime>0 &&
     TimeTradeServer()-lastCloseConfirmedTime<Inp_CooldownSec) return;
  if(Inp_LossCooldownSec>0 && lastTradeWasLoss && lastCloseConfirmedTime>0 &&
     TimeTradeServer()-lastCloseConfirmedTime<Inp_LossCooldownSec) return;
  if(!d1Ready || !gVwapOk || !wwValid) return;
  if(Inp_EnableMacroDirectionGate && gMacro.status!=MACRO_OK) return;
  if(iTime(Symbol(),Inp_SignalTF,0)!=signalBar) return;
  gLastReadOnlyMatrixBar=signalBar; // One bounded attempt, including invalid snapshots.
  MatrixSnapshot observation;
  ComputeMatrixSnapshot(observation);
  if(iTime(Symbol(),Inp_SignalTF,0)!=signalBar)
  {
    Print("[SCALPER][MATRIX_READ_ONLY_DISCARDED] Signal bar changed; entries remain blocked.");
    return;
  }
  if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseCaptureSnapshot(observation,signalBar);
  WriteShadowRow("MATRIX_READ_ONLY_ACCOUNTING_BLOCK",observation);
  PrintFormat("[SCALPER][MATRIX_READ_ONLY_ACCOUNTING_BLOCK] Status=%s ExecutionInFlight=%s; observation only, entries remain blocked.",
       MssStr(observation.status),BStr(HasExecutionInFlight()));
}

void ResponseBaseOnTick()
{
  if(TimeCurrent()<BacktestStart) return;
  MqlDateTime day; TimeToStruct(TimeTradeServer(),day);
  int key=day.year*1000+day.day_of_year;
  if(key!=gDayKey) { gDayKey=key; DailyReset(); }
 SyncAccountingState();
 if(gOpenPos.active) UpdateMAEMFE();
 int hhmm=day.hour*100+day.min;
 ProcessEOD(hhmm);
 ManageBreakEven();
 BookRiskManage();
 BookDecisionPump(); // Entry data failure cannot skip BE, locks, accounting or EOD.
 if(hhmm>=Inp_StopEntryHHMM && armed.active) ResetArmedSignal();
 datetime btCtx=iTime(Symbol(),Inp_ContextTF,0);
 datetime btSig=iTime(Symbol(),Inp_SignalTF,0);
 if(btCtx<=0 || btSig<=0) return;
 if(lastContextBarTime==0 || lastSignalBarTime==0)
 {
  // Late availability of bar clocks initializes state, never synthesizes a signal.
  BootstrapCachesNoTrade();
  return;
 }
 bool newCtx=btCtx!=lastContextBarTime;
 bool newSig=btSig!=lastSignalBarTime;
 if(newCtx)
 {
 lastContextBarTime=btCtx;
 double savedValue=gVwapValue; bool savedOk=gVwapOk;
 gVwapOk=UpdateVwapIncremental(btCtx);
 gVwapValue=(gVwapOk && vwapSumVol>0)?vwapSumPV/vwapSumVol:0;
 ulong begin=GetMicrosecondCount();
 ComputeMacroContext();
 RecordPerf(perfMacro,(double)(GetMicrosecondCount()-begin));
 gVwapValue=savedValue; gVwapOk=savedOk;
}
if(newSig)
{
   lastSignalBarTime=btSig;
   gCachedMicroReady=false;
   gVwapOk=UpdateVwapIncremental(btSig);
   gVwapValue=(gVwapOk && vwapSumVol>0)?vwapSumPV/vwapSumVol:0;
   if(gVwapValue<=0) gVwapOk=false;
   RebuildWeisCache();
}
bool hardCancelled=false;
int previousDir=0;
if(armed.active)
{
   if(newSig && d1Ready && gVwapOk && wwValid &&
      (!Inp_EnableMacroDirectionGate || gMacro.status==MACRO_OK))
   {
      MatrixSnapshot snapshot;
      SnapshotForSignal(snapshot);
      DOMGateObserveMatrix(snapshot); // Reuses the original snapshot; observation only.
      if(HasHardDirectionalContradiction(snapshot,armed.dir))
      {
        previousDir=armed.dir;
        hardFlipsPerDay++; armedCancelHard++;
        WriteAuditRow("ARMED_CANCEL_HARD",DirStr(armed.dir),armed.mode,
        snapshot.price,armed.posRel,armed.distD1,armed.effort,0);
    WriteShadowRow("ARMED_CANCEL_HARD",snapshot);
    ResetArmedSignal(); hardCancelled=true;
    }
   }
   if(!hardCancelled)
   {
   ulong begin=GetMicrosecondCount();
   ENUM_APS outcome=ProcessArmedSignal();
   RecordPerf(perfStage2,(double)(GetMicrosecondCount()-begin));
   if(outcome!=APS_ENDED_REEVAL_ALLOWED || !newSig) return;
   }
  }
  if(!newSig || hhmm<Inp_StartHHMM || hhmm>=Inp_StopEntryHHMM) return;
  if(HasOpenPosition() || HasExecutionInFlight() ||
ordersEnteredToday>=Inp_MaxTradesDay ||
       dailyRiskBlocked || gAccountingUnresolved)
  {
    if(gAccountingUnresolved) ObserveAccountingBlockedMatrix(btSig);
    return;
  }
    if(Inp_CooldownSec>0 && lastCloseConfirmedTime>0 &&
       TimeTradeServer()-lastCloseConfirmedTime<Inp_CooldownSec) return;
    if(Inp_LossCooldownSec>0 && lastTradeWasLoss && lastCloseConfirmedTime>0 &&
       TimeTradeServer()-lastCloseConfirmedTime<Inp_LossCooldownSec) return;
    if(!d1Ready || !gVwapOk || !wwValid) return;
    if(Inp_EnableMacroDirectionGate && gMacro.status!=MACRO_OK) return;
    if(gLastMatrixEvalBar==btSig) return;
    gLastMatrixEvalBar=btSig;
    EvaluateMatrix(); // reuses exact hard-contradiction snapshot if already computed
    if(hardCancelled && armed.active && armed.dir==-previousDir)
    {
       oppositeRearmAfterHard++;
       WriteShadowRow("OPPOSITE_REARM_AFTER_HARD",gCachedMicroSnapshot);
    }
}

//=====================================================================
// ON TIMER
//=====================================================================
void DOMBaseOnTimer()
{
  if(TimeCurrent()<BacktestStart) return;
  MqlDateTime nowDT; TimeToStruct(TimeTradeServer(),nowDT);
  int key=nowDT.year*1000+nowDT.day_of_year;
 int hhmm=nowDT.hour*100+nowDT.min;
 if(key!=gDayKey) { gDayKey=key; DailyReset(); }
 SyncAccountingState(true);
 ReconcileBreakEvenProofs(); // Proof/persistence only; never dispatches a stop modification.
 BookRiskManage(false); // Proof/persistence only, including after restart.
 if(!d1Ready && TimeTradeServer()>=nextD1Retry) TryCalcD1();
 if(hhmm>=Inp_StopEntryHHMM && armed.active) ResetArmedSignal();
 ProcessEOD(hhmm);
 datetime now=TimeTradeServer();
 if(now-gLastFlushTime>=30)
{
    gLastFlushTime=now;
    if(csvAuditHandle!=INVALID_HANDLE) FileFlush(csvAuditHandle);
    if(csvShadowHandle!=INVALID_HANDLE) FileFlush(csvShadowHandle);
    if(csvTradeHandle!=INVALID_HANDLE) FileFlush(csvTradeHandle);
 }
 if(MQLInfoInteger(MQL_TESTER)==0 &&
perfMicro.count>=gLastPerfLoggedMicroCount+100)
 {
 PrintFormat("[SCALPER][PERF] Macro(us) count=%I64d mean=%.1f max=%.1f; Micro(us) count=%I64d mean=%.1f max=%.1f; Stage2(us) count=%I64d mean=%.1f max=%.1f",

perfMacro.count,perfMacro.count>0?perfMacro.sumUs/perfMacro.count:0,perfMacro.maxUs
,

perfMicro.count,perfMicro.count>0?perfMicro.sumUs/perfMicro.count:0,perfMicro.maxUs,

perfStage2.count,perfStage2.count>0?perfStage2.sumUs/perfStage2.count:0,perfStage2.maxUs);
    gLastPerfLoggedMicroCount=perfMicro.count;
  }
}

//=====================================================================
// ON TRADE TRANSACTION
// Trata DEAL_ENTRY_IN (entrada) e DEAL_ENTRY_OUT (saída).
// Agrupa por DEAL_POSITION_ID.
// Exige flat, salvo ciclo próprio fechado com residual INOUT explicitamente estrangeiro.
//=====================================================================


//=====================================================================
// ON TESTER
//=====================================================================
//=====================================================================
// RC1 execution context, confirmed quota and positionID accounting
//=====================================================================
// BE-only lifecycle. Initial TradeRecord.slPrice/risk and all entry rules stay unchanged.
double BEPrice(double entry)
{ return NormPriceDigits(MathRound(entry/gTickSize)*gTickSize); }
bool BEPriceEqual(double a,double b)
{ return MathIsValidNumber(a) && MathIsValidNumber(b) &&
MathAbs(a-b)<=gTickSize*0.000001; }

double BERiskPoints(const TradeRecord &r)
{ return MathAbs(r.weightedEntryPrice-r.slPrice); }

bool BEReferenceValid(const TradeRecord &r)
{
    return r.initialStopsProven && r.riskValid && r.accountingResolved &&
     Positive(r.weightedEntryPrice) && Positive(r.slPrice) &&
     (r.direction==1 || r.direction==-1) &&
     r.direction*(r.weightedEntryPrice-r.slPrice)>0 &&
      r.be.direction==r.direction && BEPriceEqual(r.be.entryPrice,r.weightedEntryPrice) &&
      BEPriceEqual(r.be.initialSL,r.slPrice) && Positive(r.be.price) &&
      BEPriceEqual(r.be.price,BEPrice(r.be.entryPrice));
}

bool BETriggerReached(const TradeRecord &r,const MqlTick &tick)
{
  double trigger=r.weightedEntryPrice+r.direction*BERiskPoints(r)*BE_Trigger_R;
  return r.direction==1 ? tick.bid>=trigger : tick.ask<=trigger;
}

void BELog(const TradeRecord &r,string event,string detail="")
{
  PrintFormat("[SCALPER][%s] POSITION_ID=%I64u ticket=%I64u dir=%s entry=%.16f initialSL=%.16f R_points=%.16f trigger=%.16f newSL=%.16f TP_preserved=%.16f %s",
  event,r.positionID,r.be.ticket,DirStr(r.be.direction),r.be.entryPrice,r.be.initialSL,
  MathAbs(r.be.entryPrice-r.be.initialSL),
  r.be.entryPrice+r.be.direction*MathAbs(r.be.entryPrice-r.be.initialSL)*BE_Trigger_R,
  r.be.price,r.be.tp,detail);
}

void BEFailure(TradeRecord &r,string detail)
{
  datetime now=TimeTradeServer();
  if(r.be.lastFailureLog==0 || now-r.be.lastFailureLog>=10)
  { BELog(r,"BE_MODIFY_FAIL",detail); r.be.lastFailureLog=now; }
}

string BEJournalPath(ulong pid)
{ return TradeMetaPath(pid)+".be.journal"; }

uint BEChecksum(string text)
{
  uint value=2166136261;
  for(int i=0;i<StringLen(text);i++)
    value=(value^(uint)StringGetCharacter(text,i))*16777619;
   return value;
}

string BEJournalRow(ulong pid,const BreakEvenState &b)
{
  string row="SCALPER_BE1|"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
   RJEncode(Symbol())+"|"+(string)gMagicCore+"|"+(string)pid+"|"+
    (string)b.stage+"|"+(string)b.ticket+"|"+(b.direction==1?"BUY":"SELL")+"|"+
    DoubleToString(b.entryPrice,16)+"|"+DoubleToString(b.initialSL,16)+"|"+
    DoubleToString(b.price,16)+"|"+DoubleToString(b.tp,16)+"|"+
    (string)b.triggerMSC+"|"+(string)b.confirmedMSC+"|"+
    (string)b.requestID+"|"+(string)b.retcode;
     return row+"|"+(string)BEChecksum(row)+"|COMPLETE_BE1";
}

bool BEParseRow(string row,ulong pid,BreakEvenState &b)
{
   string f[]; ulong
account,magic,parsedPID,stage,ticket,trigger,confirmed,requestID,retcode,checksum;
   string symbol;
   if(StringSplit(row,'|',f)!=18 || f[0]!="SCALPER_BE1" || f[17]!="COMPLETE_BE1" ||
      !RJUnsigned(f[1],account) || account!=(ulong)AccountInfoInteger(ACCOUNT_LOGIN) ||
      !RJDecode(f[2],symbol) || symbol!=Symbol() ||
      !RJUnsigned(f[3],magic) || magic!=(ulong)gMagicCore ||
      !RJUnsigned(f[4],parsedPID) || parsedPID!=pid || pid==0 ||
      !RJUnsigned(f[5],stage) || stage<BE_TRIGGERED || stage>BE_CONFIRMED ||
      !RJUnsigned(f[6],ticket) || ticket==0 || (f[7]!="BUY" && f[7]!="SELL") ||
      !RJUnsigned(f[12],trigger) || trigger==0 || trigger>9223372036854775807 ||
      !RJUnsigned(f[13],confirmed) || confirmed>9223372036854775807 ||
      !RJUnsigned(f[14],requestID) || requestID>4294967295 ||
      !RJUnsigned(f[15],retcode) || retcode>4294967295 ||
      !RJUnsigned(f[16],checksum) || checksum>4294967295) return false;
   string prefix=f[0];
   for(int i=1;i<16;i++) prefix+="|"+f[i];
   if(BEChecksum(prefix)!=(uint)checksum) return false;
   ZeroMemory(b);
   if(!RJDouble(f[8],b.entryPrice) || !RJDouble(f[9],b.initialSL) ||
      !RJDouble(f[10],b.price) || !RJDouble(f[11],b.tp) ||
        !Positive(b.entryPrice) || !Positive(b.initialSL) || !Positive(b.price)) return false;
     b.stage=(int)stage; b.ticket=ticket; b.direction=(f[7]=="BUY"?1:-1);
     b.triggerMSC=(long)trigger; b.confirmedMSC=(long)confirmed;
     b.requestID=(uint)requestID; b.retcode=(uint)retcode;
     if(b.direction*(b.entryPrice-b.initialSL)<=0 || !BEPriceEqual(b.price,BEPrice(b.entryPrice))
||
        (b.stage>=BE_ACKNOWLEDGED && (b.retcode!=TRADE_RETCODE_DONE ||
         b.confirmedMSC<b.triggerMSC))) return false;
     b.durable=true;
    return true;
}

bool BEReadJournal(ulong pid,BreakEvenState &b,bool &exists)
{
  exists=FileIsExist(BEJournalPath(pid));
  if(!exists) return false; // Legacy metadata remains valid; BE defaults to NONE.
  int
h=FileOpen(BEJournalPath(pid),FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
  if(h==INVALID_HANDLE) return false;
  bool found=false,badTail=false;
  while(!FileIsEnding(h))
  {
     string row=FileReadString(h);
     if(row=="") continue;
     BreakEvenState candidate;
     if(BEParseRow(row,pid,candidate)) { b=candidate; found=true; badTail=false; }
     else badTail=true;
    }
    FileClose(h);
    // An immutable confirmed certificate survives an unrelated torn tail.
    // An ambiguous pending tail must never authorize another modification.
    return found && (!badTail || b.stage==BE_CONFIRMED);
}

bool BEPersist(TradeRecord &r)
{
  string row=BEJournalRow(r.positionID,r.be),payload="\r\n"+row+"\r\n";
  int h=FileOpen(BEJournalPath(r.positionID),
     FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
  bool ok=false;
  if(h!=INVALID_HANDLE)
  {
     if(FileSeek(h,0,SEEK_END))
     {
        ResetLastError(); uint written=FileWriteString(h,payload);
        ok=(written==(uint)StringLen(payload) && GetLastError()==0);
        ResetLastError(); FileFlush(h); if(GetLastError()!=0) ok=false;
     }
     FileClose(h);
    }
    BreakEvenState verified; bool exists=false;
    if(ok) ok=BEReadJournal(r.positionID,verified,exists) &&
       BEJournalRow(r.positionID,verified)==row;
    r.be.durable=ok;
    if(!ok) BEFailure(r,"BE_PERSISTENCE_UNCONFIRMED; no durable activation claimed");
    return ok;
}
void BELoad(TradeRecord &r)
{
  BreakEvenState loaded; bool exists=false;
  if(BEReadJournal(r.positionID,loaded,exists)) r.be=loaded;
  else if(exists)
  {
     r.be.stage=BE_UNRESOLVED;
     BELog(r,"BE_PROOF_UNAVAILABLE","Unreadable/corrupt journal; no inferred BE");
    }
}

bool BESelectOwn(ulong pid,ulong &ticket,int direction)
{
  for(int i=PositionsTotal()-1;i>=0;i--)
  {
    ulong candidate=PositionGetTicket(i);
    if(candidate==0 || !PositionSelectByTicket(candidate) ||
       PositionGetString(POSITION_SYMBOL)!=Symbol() ||
       PositionGetInteger(POSITION_MAGIC)!=(long)gMagicCore ||
       (ulong)PositionGetInteger(POSITION_IDENTIFIER)!=pid ||
       (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1)!=direction)
continue;
    ticket=candidate; return true;
  }
  return false;
}

bool BEEntryComplete(const TradeRecord &r)
{
  if(r.entryOrderTicket==0 || OrderSelect(r.entryOrderTicket) ||
     !HistoryOrderSelect(r.entryOrderTicket) ||
     HistoryOrderGetString(r.entryOrderTicket,ORDER_SYMBOL)!=Symbol() ||
     HistoryOrderGetInteger(r.entryOrderTicket,ORDER_MAGIC)!=(long)gMagicCore ||
     (ulong)HistoryOrderGetInteger(r.entryOrderTicket,ORDER_POSITION_ID)!=r.positionID)
     return false;
  ENUM_ORDER_STATE
state=(ENUM_ORDER_STATE)HistoryOrderGetInteger(r.entryOrderTicket,ORDER_STATE);
  if(state!=ORDER_STATE_FILLED && state!=ORDER_STATE_CANCELED &&
     state!=ORDER_STATE_REJECTED && state!=ORDER_STATE_EXPIRED) return false;
    double filled=HistoryOrderGetDouble(r.entryOrderTicket,ORDER_VOLUME_INITIAL)-
      HistoryOrderGetDouble(r.entryOrderTicket,ORDER_VOLUME_CURRENT);
    return filled>0 && MathAbs(filled-r.totalVolumeIn)<=AccountingVolumeTolerance();
}

bool BEStopsValid(const TradeRecord &r,const MqlTick &tick,double liveSL,double liveTP)
{
  double size=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE);
  double point=SymbolInfoDouble(Symbol(),SYMBOL_POINT);
  if(!Positive(size) || !Positive(point) || MathAbs(size-gTickSize)>size*0.000001 ||
     !Positive(tick.bid) || !Positive(tick.ask) || tick.ask<tick.bid ||
     !OnPriceGrid(r.be.price) || !Positive(liveSL) ||
     r.direction*(r.be.price-liveSL)<=size*0.000001) return false;
  long stops=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL);
  long freeze=SymbolInfoInteger(Symbol(),SYMBOL_TRADE_FREEZE_LEVEL);
  if(stops<0 || freeze<0) return false;
  double quote=(r.direction==1?tick.bid:tick.ask);
    double stopDistance=r.direction*(quote-r.be.price);
    double oldDistance=r.direction*(quote-liveSL);
    if(stopDistance<=0 || stopDistance+size*0.000001<stops*point ||
       (freeze>0 && (stopDistance<=freeze*point || oldDistance<=freeze*point))) return false;
    if(liveTP!=0)
     {
         double tpDistance=r.direction*(liveTP-quote);
         if(!OnPriceGrid(liveTP) || tpDistance<=0 || tpDistance+size*0.000001<stops*point ||
            (freeze>0 && tpDistance<=freeze*point)) return false;
     }
     return true;
}

bool BEExitAtProtectedLevel(const TradeRecord &r,ulong deal)
{
  if(!BEReferenceValid(r) ||
     HistoryDealGetString(deal,DEAL_SYMBOL)!=Symbol() ||
     (ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID)!=r.positionID ||
     HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_OUT ||
     HistoryDealGetInteger(deal,DEAL_REASON)!=DEAL_REASON_SL ||
     HistoryDealGetInteger(deal,DEAL_TIME_MSC)<r.be.triggerMSC ||
     !BEPriceEqual(HistoryDealGetDouble(deal,DEAL_SL),r.be.price)) return false;
  // DEAL_SL is the historical stop at this exit, not the realized fill price.
  return true;
}

bool BEProtectedDeal(const TradeRecord &r,ulong deal)
{
  return r.be.stage>=BE_ACKNOWLEDGED && r.be.stage<=BE_CONFIRMED &&
r.be.durable &&
   r.be.retcode==TRADE_RETCODE_DONE && BEExitAtProtectedLevel(r,deal);
}

bool BEConfirm(TradeRecord &r,bool protectedExit=false)
{
  if(r.be.stage==BE_CONFIRMED) return r.be.durable;
  if(r.be.stage!=BE_ACKNOWLEDGED || r.be.retcode!=TRADE_RETCODE_DONE ||
     !BEReferenceValid(r)) return false;
  if(!r.be.durable && !BEPersist(r)) return false;
    ulong ticket=0;
    bool live=BESelectOwn(r.positionID,ticket,r.direction) &&
       BEPriceEqual(PositionGetDouble(POSITION_SL),r.be.price) &&
       PositionGetDouble(POSITION_TP)==r.be.tp;
    if(!live && !protectedExit) return false;
    r.be.stage=BE_CONFIRMED;
    if(!BEPersist(r)) { r.be.stage=BE_ACKNOWLEDGED; return false; }
    if(!r.be.successLogged) { BELog(r,"BE_MODIFY_OK"); r.be.successLogged=true; }
    return true;
}

bool BEManagerLoss(const TradeRecord &r)
{ return r.netProfit<0 && !r.breakEvenExit; }
void BEAcceptResult(TradeRecord &r,const MqlTradeRequest &request,const
MqlTradeResult &result)
{
  if(r.be.stage!=BE_REQUEST_PENDING || request.action!=TRADE_ACTION_SLTP ||
     request.position!=r.be.ticket || request.position_by!=0 ||
     request.symbol!=Symbol() || request.magic!=(ulong)gMagicCore ||
     (r.be.requestID>0 && result.request_id!=r.be.requestID) ||
     !BEPriceEqual(request.sl,r.be.price) || request.tp!=r.be.tp) return;
  if(result.request_id>0) r.be.requestID=result.request_id;
  r.be.retcode=result.retcode;
  if(result.retcode==TRADE_RETCODE_DONE)
  {
     r.be.stage=BE_ACKNOWLEDGED;
     // Second-resolution server clock is a conservative lower bound, not a fill price.
     r.be.confirmedMSC=(long)TimeTradeServer()*1000;
     if(r.be.confirmedMSC<r.be.triggerMSC) r.be.confirmedMSC=r.be.triggerMSC;
     if(BEPersist(r)) BEConfirm(r);
     if(r.volumeClosedComplete || r.breakEvenClassificationPending)
     { r.historyRefreshPending=true; gNeedsAccountingSync=true; }
  }
  else if(IsFinalRejectedRetcode(result.retcode) ||
result.retcode==TRADE_RETCODE_NO_CHANGES)
  {
     r.be.stage=BE_TRIGGERED; r.be.requestID=0; r.be.confirmedMSC=0;
     r.be.nextTry=TimeTradeServer()+1;
     BEPersist(r); BEFailure(r,"retcode="+(string)result.retcode+"; safe retry allowed");
   if(r.volumeClosedComplete || r.breakEvenClassificationPending)
   { r.historyRefreshPending=true; gNeedsAccountingSync=true; }
  }
  else
  {
    BEPersist(r);
    BEFailure(r,"retcode="+(string)result.retcode+"; awaiting exact request result, no blind retry");
    }
}

void BEHandleTransaction(const MqlTradeTransaction &trans,
  const MqlTradeRequest &request,const MqlTradeResult &result)
{
  if(trans.type!=TRADE_TRANSACTION_REQUEST ||
request.action!=TRADE_ACTION_SLTP) return;
  for(int i=0;i<gTradeRecordCount;i++)
     if(gTradeRecords[i].be.stage==BE_REQUEST_PENDING &&
     gTradeRecords[i].be.requestID>0 &&
     result.request_id==gTradeRecords[i].be.requestID)
     BEAcceptResult(gTradeRecords[i],request,result);
}
void ReconcileBreakEvenProofs()
{
  for(int i=0;i<gTradeRecordCount;i++)
  {
    TradeRecord r=gTradeRecords[i];
    if(r.be.stage!=BE_ACKNOWLEDGED) continue;
    BEConfirm(r); gTradeRecords[i]=r;
    if(r.volumeClosedComplete && r.breakEvenClassificationPending)
    { gTradeRecords[i].historyRefreshPending=true; gNeedsAccountingSync=true; }
  }
}

void ManageBreakEven()
{
  ReconcileBreakEvenProofs();
  for(int i=0;i<gTradeRecordCount;i++)
  {
    TradeRecord r=gTradeRecords[i];
    if(BookRiskBlocksBE(r.positionID) || r.be.stage==BE_ACKNOWLEDGED || r.be.stage==BE_CONFIRMED ||
r.be.stage==BE_UNRESOLVED ||
       r.be.stage==BE_REQUEST_PENDING || !Inp_EnableBreakEven || r.closed ||
       r.volumeClosedComplete || r.historyRefreshPending || !r.accountingResolved ||
       !r.initialStopsProven || !r.riskValid || !Positive(r.weightedEntryPrice) ||
       !Positive(r.slPrice) || r.direction*(r.weightedEntryPrice-r.slPrice)<=0 ||
       gPendingExec.active || gPendingExit.active || gLiveOwnershipUnresolved ||
      gPendingOrderClassificationUnresolved || gMultipleOwnOrdersActive ||
      gOrderRegistryUnavailable || gOrderObligationScanUnresolved) continue;
   MqlTick tick;
   if(!SymbolInfoTick(Symbol(),tick) || !Positive(tick.bid) || !Positive(tick.ask) ||
      tick.ask<tick.bid || (r.be.stage==BE_NONE && !BETriggerReached(r,tick))) continue;
   if(TimeTradeServer()<r.be.nextTry) continue;
   ulong ticket=0;
   if(!BESelectOwn(r.positionID,ticket,r.direction) || !BEEntryComplete(r) ||
   !OwnPositionSafe(r.positionID) || !PositionSelectByTicket(ticket) ||
   PositionGetString(POSITION_SYMBOL)!=Symbol() ||
   PositionGetInteger(POSITION_MAGIC)!=(long)gMagicCore ||
   (ulong)PositionGetInteger(POSITION_IDENTIFIER)!=r.positionID ||
   (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1)!=r.direction ||
   !BEPriceEqual(PositionGetDouble(POSITION_PRICE_OPEN),r.weightedEntryPrice) ||

MathAbs(PositionGetDouble(POSITION_VOLUME)-(r.totalVolumeIn-r.totalVolumeOut))>
      AccountingVolumeTolerance()) continue;
if(r.be.stage==BE_NONE)
{
    r.be.stage=BE_TRIGGERED; r.be.ticket=ticket; r.be.direction=r.direction;
    r.be.entryPrice=r.weightedEntryPrice; r.be.initialSL=r.slPrice;
    r.be.price=BEPrice(r.weightedEntryPrice);
     r.be.tp=PositionGetDouble(POSITION_TP);
     r.be.triggerMSC=tick.time_msc>0?tick.time_msc:(long)TimeTradeServer()*1000;
     BELog(r,"BE_TRIGGER");
     if(!BEPersist(r)) { r.be.nextTry=TimeTradeServer()+1; gTradeRecords[i]=r; continue; }
    }
    // Each retry reselects the exact live ticket and preserves its current TP.
    r.be.ticket=ticket; r.be.tp=PositionGetDouble(POSITION_TP);
    double liveSL=PositionGetDouble(POSITION_SL);
    r.be.nextTry=TimeTradeServer()+1;
    if(!BEReferenceValid(r) || !SymbolInfoTick(Symbol(),tick) ||
       !BEStopsValid(r,tick,liveSL,r.be.tp))
    { BEFailure(r,"stop/grid/freeze invalid or live SL already at least as protective");
      gTradeRecords[i]=r; continue; }
    r.be.stage=BE_REQUEST_PENDING; r.be.requestID=0; r.be.retcode=0;
    if(!BEPersist(r))
    { r.be.stage=BE_TRIGGERED; gTradeRecords[i]=r; continue; }
    gTradeRecords[i]=r;
    trade.SetExpertMagicNumber(gMagicCore);
    bool dispatched=trade.PositionModify(ticket,r.be.price,r.be.tp);
    MqlTradeRequest request; MqlTradeResult result;
    trade.Request(request); trade.Result(result);
    // A false CTrade return must not adopt a stale DONE result as confirmation.
    if(!dispatched && result.retcode==TRADE_RETCODE_DONE)
       result.retcode=TRADE_RETCODE_ERROR;
    BEAcceptResult(gTradeRecords[i],request,result);
    if(!dispatched && gTradeRecords[i].be.stage==BE_REQUEST_PENDING)
         BEFailure(gTradeRecords[i],"PositionModify returned false; no success inferred");
     }
}


void ResetTradeRecord(TradeRecord &r)
{
  r.positionID=0; r.direction=0; r.route="UNAVAILABLE"; r.mode="UNAVAILABLE";
 r.quotaCounted=false; r.requestPrice=0; r.breakoutPrice=0;
 r.requestPriceAvailable=false; r.breakoutPriceAvailable=false;
 r.entryOrderTicket=0; r.expectedEntryVolume=0;
 r.entryTime=0; r.entryPrice=0; r.weightedEntryPrice=0; r.totalVolumeIn=0;
 r.entrySlippage=EMPTY_VALUE; r.slPrice=0; r.tpPrice=0;
 r.exitTime=0; r.exitPrice=0; r.weightedExitPrice=0; r.totalVolumeOut=0; r.volume=0;
 r.exitTimeMSC=0; r.lastExitDealTicket=0;
 r.grossProfit=0; r.commission=0; r.fee=0; r.swap=0; r.netProfit=0;
 r.exitReason="UNAVAILABLE"; r.MAE=0; r.MFE=0; r.holdSeconds=0;
 r.initialRiskMoney=0; r.PnL_R=EMPTY_VALUE;
 r.closed=false; r.maeMfePartialAfterRestart=false; r.volumeClosedComplete=false;
 r.finalizationWritten=false; r.dailyApplied=false;
 r.accountingResolved=true; r.riskValid=false; r.pnlRValid=false;
 r.initialStopsProven=false; r.economicMarkerPending=false;
 r.economicMarkerCleanupPending=false; r.economicMarkerDeleteError=0;
 r.historyRefreshPending=false;
 r.residualForeignDetected=false; r.ownCycleEconomicallyClosed=false;
 r.volumeOwnershipResolved=false; r.inoutCostsUnresolved=false;
 ZeroMemory(r.be); r.breakEvenExit=false; r.breakEvenClassificationPending=false;
}
void ResetPendingExec(bool releaseProof=true)
{
  if(releaseProof && gPendingExec.active) ResolveRequestJournal(false);
  gPendingExec.active=false; gPendingExec.direction=0;
  gPendingExec.route="UNAVAILABLE"; gPendingExec.mode="UNAVAILABLE";
  gPendingExec.requestPrice=0; gPendingExec.requestedLots=0;
  gPendingExec.slPrice=0; gPendingExec.tpPrice=0; gPendingExec.sentAt=0;
  gPendingExec.orderTicket=0; gPendingExec.resultDeal=0;
  gPendingExec.requestID=0;
  gPendingExec.accepted=false; gPendingExec.requestPriceAvailable=false;
  gPendingExec.breakoutPrice=0; gPendingExec.breakoutPriceAvailable=false;
  gPendingExec.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
}

void BeginExitIntent(ulong positionID,string intention)
{
  gPendingExit.active=true; gPendingExit.positionID=positionID;
  gPendingExit.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
  gPendingExit.reason=intention; gPendingExit.sentAt=TimeTradeServer();
  gPendingExit.orderTicket=0; gPendingExit.resultDeal=0; gPendingExit.positionTicket=0;
  gPendingExit.requestID=0; gPendingExit.accepted=false; gPendingExit.uncertain=false;
  ZeroMemory(gPendingExit.requestSnapshot);
}

void ClearPendingExitIntent()
{
  gPendingExit.active=false; gPendingExit.positionID=0; gPendingExit.positionTicket=0;
  gPendingExit.reason=""; gPendingExit.sentAt=0;
  gPendingExit.orderTicket=0; gPendingExit.resultDeal=0; gPendingExit.requestID=0;
  gPendingExit.accepted=false; gPendingExit.uncertain=false;
  gPendingExit.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
  ZeroMemory(gPendingExit.requestSnapshot);
}

void FailExitIntent(ulong positionID,bool requestResolved=false)
{
  if(!gPendingExit.active || gPendingExit.positionID!=positionID) return;
  // A closed position alone is not terminal proof for its exit request.
  if(!requestResolved) return;
 ResolveRequestJournal(true);
 ClearPendingExitIntent();
}
datetime AccountingDayStart()
{
  MqlDateTime dt; TimeToStruct(TimeTradeServer(),dt);
  dt.hour=0; dt.min=0; dt.sec=0;
  return StructToTime(dt);
}

bool HasOwnPendingOrder()
{
  for(int i=OrdersTotal()-1;i>=0;i--)
  {
    ulong ticket=OrderGetTicket(i);
    if(ticket==0) continue;
    if(OrderGetString(ORDER_SYMBOL)==Symbol() &&
       OrderGetInteger(ORDER_MAGIC)==(long)gMagicCore) return true;
  }
  return false;
}

bool HasOwnPendingOrderToday()
{
  datetime start=AccountingDayStart();
  for(int i=OrdersTotal()-1;i>=0;i--)
  {
    ulong ticket=OrderGetTicket(i);
    if(ticket==0) continue;
  if(OrderGetString(ORDER_SYMBOL)==Symbol() &&
     OrderGetInteger(ORDER_MAGIC)==(long)gMagicCore &&
     (datetime)OrderGetInteger(ORDER_TIME_SETUP)>=start) return true;
 }
 return false;
}
bool HasExecutionInFlight()
{
    if(gOrderObligationScanUnresolved) return true;
    for(int i=0;i<ArraySize(gUnresolvedOrders);i++)
       if(gUnresolvedOrders[i].active && (gUnresolvedOrders[i].classificationPending ||
          gUnresolvedOrders[i].persistencePending)) return true;
    if(gRequestJournalUnresolved || gEntryJournalCleanupPending ||
       gExitJournalCleanupPending || gRequestJournalWritePending) return true;
    if(gPendingExec.active || gPendingExit.active ||
       gPendingOrderClassificationUnresolved || HasOwnPendingOrder()) return true;
    // A confirmed IN can arrive before Positions exposes the position; an OUT
    // can likewise precede flat state. The tracked lifecycle spans both races.
    for(int i=0;i<gTradeRecordCount;i++)
      if(gTradeRecords[i].positionID>0 && !gTradeRecords[i].closed &&
         gTradeRecords[i].totalVolumeIn>0) return true;
    return false;
}

bool PreparePendingExec(int direction,string route,string mode,double requestPrice,
      double lots,double sl,double tp)
{
  // Call only after the final guards; active state blocks another request.
  if(gPendingExec.active || gRequestJournalUnresolved ||
     gEntryJournalCleanupPending || gRequestJournalWritePending) return false;
  ResetPendingExec(false);
  gPendingExec.active=true; gPendingExec.direction=direction;
  gPendingExec.dispatchPhase=REQUEST_PREPARED;
  gPendingExec.route=route; gPendingExec.mode=mode;
  gPendingExec.requestPrice=requestPrice;
gPendingExec.requestPriceAvailable=(requestPrice>0);
  gPendingExec.requestedLots=lots; gPendingExec.slPrice=sl; gPendingExec.tpPrice=tp;
  gPendingExec.sentAt=TimeTradeServer();
  if(!PersistRequestJournal(false)) { ResetPendingExec(); return false; }
  return true;
}

bool IsAcceptedRetcode(uint ret)
{
  return ret==TRADE_RETCODE_DONE || ret==TRADE_RETCODE_PLACED ||
   ret==TRADE_RETCODE_DONE_PARTIAL;
}
bool IsUncertainRetcode(uint ret)
{ return ret==TRADE_RETCODE_TIMEOUT || ret==TRADE_RETCODE_CONNECTION; }

void CompletePendingExec(bool sent,uint ret,ulong orderTicket,ulong resultDeal,uint
requestID=0)
{
  gPendingExec.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
  if(orderTicket>0) gPendingExec.orderTicket=orderTicket;
    if(resultDeal>0) gPendingExec.resultDeal=resultDeal;
    if(requestID>0) gPendingExec.requestID=requestID;
    if(IsAcceptedRetcode(ret))
    {
       if(!gPendingExec.accepted) requestsAcceptedToday++;
       gPendingExec.accepted=true;
    }
    // FILLED, ORDER_DELETE and HISTORY_ADD are never evidence of no deal.
    // Transport uncertainty keeps the request guard active until reconciliation.
    else if(IsFinalRejectedRetcode(ret) && !gPendingExec.accepted &&
       gPendingExec.orderTicket==0 && gPendingExec.resultDeal==0)
       ResetPendingExec();
    if(gPendingExec.active) PersistRequestJournal(false);
    gNeedsAccountingSync=true;
}

double AccountingVolumeTolerance()
{
  double step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
  return (step>0 ? step*0.000001 : 0.00000001);
}

double CalcInitialRiskMoney(int direction,double entryPrice,double slPrice,double volume)
{
  if(volume<=0 || entryPrice<=0 || slPrice<=0 ||
     (double)direction*(entryPrice-slPrice)<=0) return 0;
  double profit=0;
  ENUM_ORDER_TYPE type=(direction==1 ? ORDER_TYPE_BUY :
ORDER_TYPE_SELL);
  if(!OrderCalcProfit(type,Symbol(),volume,entryPrice,slPrice,profit) ||
     !MathIsValidNumber(profit) || profit>=0) return 0;
  return MathAbs(profit);
}

int FindTrackedTrade(ulong positionID)
{
  for(int i=0;i<gTradeRecordCount;i++)
   if(gTradeRecords[i].positionID==positionID) return i;
  return -1;
}
bool HasOwnEntryHistory(ulong positionID)
{
  if(!HistorySelectByPosition(positionID)) return false;
  for(int i=0;i<HistoryDealsTotal();i++)
  {
     ulong deal=HistoryDealGetTicket(i);
     if(HistoryDealGetString(deal,DEAL_SYMBOL)==Symbol() &&
      HistoryDealGetInteger(deal,DEAL_MAGIC)==(long)gMagicCore &&
     HistoryDealGetInteger(deal,DEAL_ENTRY)==DEAL_ENTRY_IN) return true;
    }
    return false;
}

int NewTrackedTrade(ulong positionID)
{
  int known=FindTrackedTrade(positionID); if(known>=0) return known;
  int idx=-1;
  for(int i=0;i<gTradeRecordCount;i++)
    if(gTradeRecords[i].closed && gTradeRecords[i].finalizationWritten &&
       gTradeRecords[i].dailyApplied && gTradeRecords[i].accountingResolved &&
     !gTradeRecords[i].economicMarkerPending &&
!gTradeRecords[i].historyRefreshPending &&
        !gTradeRecords[i].inoutCostsUnresolved &&
        gTradeRecords[i].exitTime<AccountingDayStart()) { idx=i; break; }
  if(idx<0)
  {
     if(ArrayResize(gTradeRecords,gTradeRecordCount+1)!=gTradeRecordCount+1)
     {
        RememberDeferredAccountingPID(positionID);
        return -1;
     }
     idx=gTradeRecordCount++;
  }
  ResetTradeRecord(gTradeRecords[idx]); gTradeRecords[idx].positionID=positionID;
  BELoad(gTradeRecords[idx]);
  ForgetDeferredAccountingPID(positionID);
  return idx;
}

bool PositionStateByID(ulong positionID,double &volume,double &sl,double &tp,int
&direction)
{
  volume=0; sl=0; tp=0; direction=0;
  for(int i=PositionsTotal()-1;i>=0;i--)
  {
    ulong ticket=PositionGetTicket(i);
    if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=Symbol()) continue;
  if((ulong)PositionGetInteger(POSITION_IDENTIFIER)!=positionID) continue;
  volume=PositionGetDouble(POSITION_VOLUME);
  sl=PositionGetDouble(POSITION_SL); tp=PositionGetDouble(POSITION_TP);
  direction=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1 : -1);
  return true;
 }
 return false;
}
bool ParseScalperComment(string comment,string &route,string &mode)
{
    route="UNAVAILABLE"; mode="UNAVAILABLE";
    if(comment=="SCALPER_BASE" || comment=="RC1|ABS|BASE")
    { route="ABS"; mode="BASE"; return true; }
      if(comment=="SCALPER_TURBO" || comment=="RC1|ABS|TURBO")
      { route="ABS"; mode="TURBO"; return true; }
      if(comment=="SCALPER_BASE_CONT" || comment=="RC1|CONT|BASE_CONT")
      { route="CONT"; mode="BASE_CONT"; return true; }
      if(comment=="SCALPER_TURBO_CONT" || comment=="RC1|CONT|TURBO_CONT")
      { route="CONT"; mode="TURBO_CONT"; return true; }
      return false;
}
string GvDateToday()
{
   MqlDateTime dt; TimeToStruct(TimeTradeServer(),dt);
   return StringFormat("%04d%02d%02d",dt.year,dt.mon,dt.day);
}

string AccountingKey(string field)
{
  return StringFormat("SCALP_RC1_%I64d_%s_%I64d_%s_%s",

AccountInfoInteger(ACCOUNT_LOGIN),Symbol(),(long)gMagicCore,field,GvDateToday());
}
string GvKeyShots() { return AccountingKey("CONF"); }
string GvKeyDailyBlock() { return AccountingKey("BLOCK"); }
string GvKeyConsecLoss() { return AccountingKey("LOSS"); }
string GvKeyDailyPnL() { return AccountingKey("NET"); }
string GvKeyDailyPnLR() { return AccountingKey("R"); }

bool PersistShotCount()
{
  bool ok=(GlobalVariableSet(GvKeyShots(),(double)ordersEnteredToday)!=0);
  if(!ok) Print("[SCALPER][PERSIST_FAIL] CONFIRMED_TRADE_COUNT");
  GlobalVariablesFlush();
  return ok;
}

void PersistDailyAccounting()
{
  // VALID is a commit marker. Partial state is rebuilt, never silently trusted.
  GlobalVariableSet(AccountingKey("VALID"),0.0);
  bool ok=true;
  if(GlobalVariableSet(AccountingKey("RISK_LATCH"),gDailyRiskLimitLatched?1.0:0.0)==0)
ok=false;
  if(GlobalVariableSet(GvKeyShots(),(double)ordersEnteredToday)==0) ok=false;
  if(GlobalVariableSet(GvKeyDailyPnL(),dailyNetPnL)==0) ok=false;
  if(GlobalVariableSet(GvKeyDailyPnLR(),dailyPnLR)==0) ok=false;
  if(GlobalVariableSet(GvKeyConsecLoss(),(double)consecutiveLosses)==0) ok=false;
  if(GlobalVariableSet(GvKeyDailyBlock(),dailyRiskBlocked?1.0:0.0)==0) ok=false;
  if(GlobalVariableSet(AccountingKey("RVALID"),gDailyPnLRValid?1.0:0.0)==0) ok=false;
  if(GlobalVariableSet(AccountingKey("CLOSE"),(double)lastCloseConfirmedTime)==0)
ok=false;
  if(GlobalVariableSet(AccountingKey("LASTLOSS"),lastTradeWasLoss?1.0:0.0)==0)
ok=false;
  if(ok) GlobalVariableSet(AccountingKey("VALID"),1.0);
  else Print("[SCALPER][PERSIST_FAIL] DAILY_ACCOUNTING_INCOMPLETE");
  GlobalVariablesFlush();
}
void PersistDailyBlock() { PersistDailyAccounting(); }
void PersistConsecLoss(int n) { consecutiveLosses=n; PersistDailyAccounting(); }
void PersistDailyPnL(double pnl) { dailyNetPnL=pnl; PersistDailyAccounting(); }

string TradeMetaPath(ulong positionID)
{
  return StringFormat("Scalper01_RC1_%I64d_%s_%I64d_%I64u.meta.csv",
   AccountInfoInteger(ACCOUNT_LOGIN),Symbol(),(long)gMagicCore,positionID);
}

void SaveTradeMetadata(const TradeRecord &r)
{
  int h=FileOpen(TradeMetaPath(r.positionID),FILE_WRITE|FILE_CSV|FILE_ANSI,';');
  if(h==INVALID_HANDLE) { Print("[SCALPER][PERSIST_FAIL] TRADE_METADATA");
return; }
  FileWrite(h,"RC1",r.route,r.mode,r.requestPriceAvailable?1:0,

DoubleToString(r.requestPrice,16),DoubleToString(r.slPrice,16),DoubleToString(r.tpPrice,16),
 DoubleToString(r.initialRiskMoney,16),r.riskValid?1:0,r.finalizationWritten?1:0,
 r.breakoutPriceAvailable?1:0,DoubleToString(r.breakoutPrice,16),
   (string)r.entryOrderTicket,DoubleToString(r.expectedEntryVolume,16),
   (string)AccountInfoInteger(ACCOUNT_LOGIN),Symbol(),(string)gMagicCore,
   (string)r.positionID,r.initialStopsProven?"COMPLETE_RC12":"COMPLETE");
   FileFlush(h); FileClose(h);
}

void LoadTradeMetadata(TradeRecord &r)
{
  int h=FileOpen(TradeMetaPath(r.positionID),FILE_READ|FILE_CSV|FILE_ANSI,';');
  if(h==INVALID_HANDLE) return;
  if(FileReadString(h)!="RC1") { FileClose(h); return; }
  TradeRecord parsed=r;
  parsed.route=FileReadString(h); parsed.mode=FileReadString(h);
  string requestFlag=FileReadString(h);
  parsed.requestPriceAvailable=(requestFlag=="1");
  parsed.requestPrice=StringToDouble(FileReadString(h));
  parsed.slPrice=StringToDouble(FileReadString(h));
parsed.tpPrice=StringToDouble(FileReadString(h));
  parsed.initialRiskMoney=StringToDouble(FileReadString(h));
  string riskFlag=FileReadString(h), writtenFlag=FileReadString(h),
breakoutFlag=FileReadString(h);
  parsed.riskValid=(riskFlag=="1"); parsed.finalizationWritten=(writtenFlag=="1");
  parsed.breakoutPriceAvailable=(breakoutFlag=="1");
  parsed.breakoutPrice=StringToDouble(FileReadString(h));
  parsed.entryOrderTicket=(ulong)StringToInteger(FileReadString(h));
  parsed.expectedEntryVolume=StringToDouble(FileReadString(h));
  string account=FileReadString(h), symbol=FileReadString(h), magic=FileReadString(h);
  string pid=FileReadString(h), complete=FileReadString(h);
  FileClose(h);
  bool routeValid=((parsed.route=="ABS" && (parsed.mode=="BASE" ||
parsed.mode=="TURBO")) ||
     (parsed.route=="CONT" && (parsed.mode=="BASE_CONT" ||
parsed.mode=="TURBO_CONT")) ||
     (parsed.route=="UNAVAILABLE" && parsed.mode=="UNAVAILABLE"));
  bool flagsValid=((requestFlag=="0" || requestFlag=="1") &&
     (riskFlag=="0" || riskFlag=="1") && (writtenFlag=="0" || writtenFlag=="1") &&
     (breakoutFlag=="0" || breakoutFlag=="1"));
  bool valuesValid=(MathIsValidNumber(parsed.requestPrice) &&
MathIsValidNumber(parsed.slPrice) &&
     MathIsValidNumber(parsed.tpPrice) && MathIsValidNumber(parsed.initialRiskMoney) &&
     MathIsValidNumber(parsed.breakoutPrice) &&
MathIsValidNumber(parsed.expectedEntryVolume) &&
     parsed.requestPrice>=0 && parsed.slPrice>=0 && parsed.tpPrice>=0 &&
     parsed.initialRiskMoney>=0 && parsed.breakoutPrice>=0 &&
parsed.expectedEntryVolume>=0 &&
     (!parsed.requestPriceAvailable || parsed.requestPrice>0) &&
     (!parsed.riskValid || (parsed.initialRiskMoney>0 && parsed.slPrice>0)) &&
     (!parsed.breakoutPriceAvailable || parsed.breakoutPrice>0));
  bool identityValid=(account==(string)AccountInfoInteger(ACCOUNT_LOGIN) &&
symbol==Symbol() &&
     magic==(string)gMagicCore && pid==(string)r.positionID);
  if((complete!="COMPLETE" && complete!="COMPLETE_RC12") || !routeValid || !flagsValid
|| !valuesValid || !identityValid)
  { Print("[SCALPER][TRADE_METADATA_INCOMPLETE_OR_INVALID] persisted fields not adopted"); return; }
  parsed.finalizationWritten=false; // CSV index is the output authority after restart.
    // Legacy RC1.1 metadata could contain a later mutable live SL/TP.
    parsed.initialStopsProven=(complete=="COMPLETE_RC12" && parsed.slPrice>0);
    if(!parsed.initialStopsProven)
    { parsed.slPrice=0; parsed.tpPrice=0; parsed.initialRiskMoney=0; parsed.riskValid=false; }
    r=parsed;
}

bool IsConfirmedToday(ulong positionID)
{
    for(int i=0;i<ArraySize(gConfirmedPositionsToday);i++)
     if(gConfirmedPositionsToday[i]==positionID) return true;
    return false;
}
bool AddConfirmedToday(ulong positionID)
{
  if(positionID==0) return false;
  if(IsConfirmedToday(positionID)) return true;
  int n=ArraySize(gConfirmedPositionsToday);
  if(ArrayResize(gConfirmedPositionsToday,n+1)!=n+1)
  { gQuotaHistoryValid=false; return false; }
    gConfirmedPositionsToday[n]=positionID;
    return true;
}

int CountTodayTrades()
{
  datetime start=AccountingDayStart();
  if(!HistorySelect(start,TimeTradeServer())) return -1;
  ulong candidates[]; int count=0;
  for(int i=0;i<HistoryDealsTotal();i++)
  {
     ulong deal=HistoryDealGetTicket(i);
     if(deal==0 || HistoryDealGetString(deal,DEAL_SYMBOL)!=Symbol() ||
        HistoryDealGetInteger(deal,DEAL_MAGIC)!=(long)gMagicCore ||
        HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
     ulong pid=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
     if(pid==0) return -1;
     bool seen=false;
     for(int j=0;j<count;j++) if(candidates[j]==pid) { seen=true; break; }
     if(!seen)
     {
         if(ArrayResize(candidates,count+1)!=count+1) return -1;
         candidates[count++]=pid;
     }
    }
    ulong confirmed[]; int confirmedCount=0;
    for(int i=0;i<count;i++)
    {
       if(!HistorySelectByPosition(candidates[i])) return -1;
       datetime first=0;
       for(int j=0;j<HistoryDealsTotal();j++)
       {
          ulong d=HistoryDealGetTicket(j);
          if(HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_IN ||
             HistoryDealGetInteger(d,DEAL_MAGIC)!=(long)gMagicCore ||
             HistoryDealGetString(d,DEAL_SYMBOL)!=Symbol()) continue;
      datetime tm=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
      if(first==0 || tm<first) first=tm;
     }
     if(first==0) return -1; // incomplete per-position evidence, retry later
     if(first>=start)
     {
        if(ArrayResize(confirmed,confirmedCount+1)!=confirmedCount+1) return -1;
        confirmed[confirmedCount++]=candidates[i];
     }
    }
    // Publish only a complete authoritative snapshot. A failed scan must not
    // replace the in-memory PID set with a partial one and allow duplicate quota.
    if(ArrayResize(gConfirmedPositionsToday,confirmedCount)!=confirmedCount) return -1;
    for(int i=0;i<confirmedCount;i++) gConfirmedPositionsToday[i]=confirmed[i];
    for(int i=0;i<gTradeRecordCount;i++)
      gTradeRecords[i].quotaCounted=IsConfirmedToday(gTradeRecords[i].positionID);
    return confirmedCount;
}

string DealExitReason(ulong deal,ulong positionID)
{
  ENUM_DEAL_REASON
reason=(ENUM_DEAL_REASON)HistoryDealGetInteger(deal,DEAL_REASON);
  switch(reason)
  {
    case DEAL_REASON_SL: return "SL";
    case DEAL_REASON_TP: return "TP";
    case DEAL_REASON_EXPERT:
     if(gPendingExit.active && gPendingExit.positionID==positionID &&
        HistoryDealGetInteger(deal,DEAL_MAGIC)==(long)gMagicCore &&
        ((gPendingExit.resultDeal>0 && gPendingExit.resultDeal==deal) ||
         (gPendingExit.orderTicket>0 &&
gPendingExit.orderTicket==(ulong)HistoryDealGetInteger(deal,DEAL_ORDER))))
      return gPendingExit.reason;
    return "EXPERT";
   case DEAL_REASON_CLIENT: return "MANUAL_DESKTOP";
   case DEAL_REASON_MOBILE: return "MANUAL_MOBILE";
   case DEAL_REASON_WEB: return "MANUAL_WEB";
   case DEAL_REASON_SO: return "STOP_OUT";
   case DEAL_REASON_ROLLOVER: return "ROLLOVER";
   case DEAL_REASON_VMARGIN: return "VMARGIN";
   case DEAL_REASON_SPLIT: return "SPLIT";
   case DEAL_REASON_CORPORATE_ACTION: return "CORPORATE_ACTION";
  }
  return EnumToString(reason)+"("+IntegerToString((int)reason)+")";
}

bool PendingMatchesDeal(ulong deal)
{
  if(!gPendingExec.active || HistoryDealGetString(deal,DEAL_SYMBOL)!=Symbol() ||
     HistoryDealGetInteger(deal,DEAL_MAGIC)!=(long)gMagicCore) return false;
  if(gPendingExec.resultDeal>0 && deal==gPendingExec.resultDeal) return true;
  ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
  if(gPendingExec.orderTicket>0) return order==gPendingExec.orderTicket;
  // A request without ticket is first matched uniquely by the controlled
  // reconciler; rebuilding one PID must not silently choose among candidates.
  return false;
}

void AttachPendingToRecord(TradeRecord &r,ulong deal)
{
    if(!PendingMatchesDeal(deal)) return;
      r.route=gPendingExec.route; r.mode=gPendingExec.mode;
        r.requestPrice=gPendingExec.requestPrice;
        r.requestPriceAvailable=gPendingExec.requestPriceAvailable;
        r.slPrice=gPendingExec.slPrice; r.tpPrice=gPendingExec.tpPrice;
        r.initialStopsProven=(gPendingExec.slPrice>0);
        r.entryOrderTicket=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
        r.expectedEntryVolume=gPendingExec.requestedLots;
        r.breakoutPrice=gPendingExec.breakoutPrice;
        r.breakoutPriceAvailable=gPendingExec.breakoutPriceAvailable;
        // Save before releasing the request guard. Armed is never an accounting source.
        SaveTradeMetadata(r);
        // A durable PID obligation must replace the request guard before it is
        // released; Positions can still lag this confirmed IN, including at restart.
        if(BookRiskAttachEntry(r) && PersistEconomicMarker(r.positionID)) ResetPendingExec();
        else r.economicMarkerPending=true;
}

bool OwnPositionSafe(ulong positionID)
{
  if(!HistorySelectByPosition(positionID)) return false;
  bool ownEntry=false;
  for(int i=0;i<HistoryDealsTotal();i++)
  {
     ulong d=HistoryDealGetTicket(i);
     if(d==0 || HistoryDealGetString(d,DEAL_SYMBOL)!=Symbol()) continue;
     long entry=HistoryDealGetInteger(d,DEAL_ENTRY);
     long type=HistoryDealGetInteger(d,DEAL_TYPE);
     if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) continue;
     if(entry==DEAL_ENTRY_IN || entry==DEAL_ENTRY_INOUT)
     {
        if(HistoryDealGetInteger(d,DEAL_MAGIC)!=(long)gMagicCore) return false;
        if(entry==DEAL_ENTRY_IN) ownEntry=true;
        else return false; // A reversal changes ownership of the net position.
     }
    }
    return ownEntry;
}

// Complete history is sorted explicitly. Transaction arrival order is irrelevant;
// economic totals are rebuilt, never incremented twice by replayed notifications.
bool RebuildTrackedHistory(int idx,bool restarting)
{
   ulong positionID=gTradeRecords[idx].positionID;
   if(!HistorySelectByPosition(positionID))
   { gTradeRecords[idx].historyRefreshPending=true;
gTradeRecords[idx].accountingResolved=false;
     gTradeRecords[idx].volumeOwnershipResolved=false;
     gTradeRecords[idx].ownCycleEconomicallyClosed=false;
     MarkTemporaryAccountingHistory(); return false; }
   ulong deals[]; long times[];
   int n=HistoryDealsTotal();
   if(ArrayResize(deals,n)!=n || ArrayResize(times,n)!=n)
   {
      gTradeRecords[idx].historyRefreshPending=true;
      gTradeRecords[idx].accountingResolved=false;
      gTradeRecords[idx].volumeOwnershipResolved=false;
      gTradeRecords[idx].ownCycleEconomicallyClosed=false;
      MarkTemporaryAccountingHistory(); return false;
   }
   for(int i=0;i<n;i++)
   { deals[i]=HistoryDealGetTicket(i);
times[i]=HistoryDealGetInteger(deals[i],DEAL_TIME_MSC); }
  for(int i=1;i<n;i++)
  {
     ulong d=deals[i]; long tm=times[i]; int j=i-1;
     while(j>=0 && (times[j]>tm || (times[j]==tm && deals[j]>d)))
   { deals[j+1]=deals[j]; times[j+1]=times[j]; j--; }
   deals[j+1]=d; times[j+1]=tm;
  }
  TradeRecord r=gTradeRecords[idx];
  r.historyRefreshPending=false;
  r.entryTime=0; r.exitTime=0; r.totalVolumeIn=0; r.totalVolumeOut=0;
  r.exitTimeMSC=0; r.lastExitDealTicket=0;
  r.weightedEntryPrice=0; r.weightedExitPrice=0;
  r.grossProfit=0; r.commission=0; r.fee=0; r.swap=0;
  r.accountingResolved=true;
  r.residualForeignDetected=false; r.ownCycleEconomicallyClosed=false;
  r.volumeOwnershipResolved=false; r.inoutCostsUnresolved=false;
  bool ownsCycle=false, foreignEntry=false, residualForeign=false;
  bool beHasContext=(r.be.stage>=BE_REQUEST_PENDING &&
r.be.stage<=BE_CONFIRMED);
  ulong beOwnExitDeals[]; int beOwnExitCount=0;
  bool beExitListValid=(!beHasContext || ArrayResize(beOwnExitDeals,n)==n);
  r.breakEvenExit=false; r.breakEvenClassificationPending=false;
  double tol=AccountingVolumeTolerance();
  for(int i=0;i<n;i++)
  {
    // Everything after a proven INOUT rejection belongs to the foreign residual.
    // Do not replay it into the original Scalper ledger, even with the same Magic.
    if(r.ownCycleEconomicallyClosed) break;
    ulong d=deals[i];
    if(d==0 || HistoryDealGetString(d,DEAL_SYMBOL)!=Symbol()) continue;
    long type=HistoryDealGetInteger(d,DEAL_TYPE);
    if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) continue;
   long entry=HistoryDealGetInteger(d,DEAL_ENTRY);
   long magic=HistoryDealGetInteger(d,DEAL_MAGIC);
  int dir=(type==DEAL_TYPE_BUY ? 1 : -1);
  double vol=HistoryDealGetDouble(d,DEAL_VOLUME);
  double price=HistoryDealGetDouble(d,DEAL_PRICE);
  datetime tm=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
  if(vol<=0 || price<=0) { r.accountingResolved=false; continue; }
  if(entry==DEAL_ENTRY_IN)
  {
     if(magic!=(long)gMagicCore)
     { foreignEntry=true; if(ownsCycle) r.accountingResolved=false; continue; }
     if(foreignEntry || residualForeign || (ownsCycle && dir!=r.direction))
     { r.accountingResolved=false; continue; }
     if(!ownsCycle)
     {
        ownsCycle=true; r.direction=dir; r.entryTime=tm;
        AttachPendingToRecord(r,d);
        if(r.entryOrderTicket==0)
r.entryOrderTicket=(ulong)HistoryDealGetInteger(d,DEAL_ORDER);
        if(r.expectedEntryVolume<=0 && r.entryOrderTicket>0 &&
HistoryOrderSelect(r.entryOrderTicket))
     {
   ENUM_ORDER_STATE
orderState=(ENUM_ORDER_STATE)HistoryOrderGetInteger(r.entryOrderTicket,ORDER_STATE);
   if(orderState==ORDER_STATE_FILLED)

r.expectedEntryVolume=HistoryOrderGetDouble(r.entryOrderTicket,ORDER_VOLUME_INITIAL);
  else if(orderState==ORDER_STATE_CANCELED ||
orderState==ORDER_STATE_REJECTED ||
orderState==ORDER_STATE_EXPIRED)
r.expectedEntryVolume=HistoryOrderGetDouble(r.entryOrderTicket,ORDER_VOLUME_INITIAL)-

HistoryOrderGetDouble(r.entryOrderTicket,ORDER_VOLUME_CURRENT);
}
if(r.route=="UNAVAILABLE" || r.mode=="UNAVAILABLE")
{
   string route,mode;
   if(ParseScalperComment(HistoryDealGetString(d,DEAL_COMMENT),route,mode))
   { r.route=route; r.mode=mode; }
   else if(HistoryOrderSelect(r.entryOrderTicket) &&

ParseScalperComment(HistoryOrderGetString(r.entryOrderTicket,ORDER_COMMENT),route,mode))
     { r.route=route; r.mode=mode; }
   }
   }
   double total=r.totalVolumeIn+vol;
     r.weightedEntryPrice=(r.weightedEntryPrice*r.totalVolumeIn+price*vol)/total;
     r.totalVolumeIn=total;
     r.grossProfit+=HistoryDealGetDouble(d,DEAL_PROFIT);
     r.commission+=HistoryDealGetDouble(d,DEAL_COMMISSION);
     r.fee+=HistoryDealGetDouble(d,DEAL_FEE);
r.swap+=HistoryDealGetDouble(d,DEAL_SWAP);
     if(r.entryTime>=AccountingDayStart())
     {
        if(!IsConfirmedToday(positionID))
        {
           if(AddConfirmedToday(positionID)) { ordersEnteredToday++; PersistShotCount(); }
        }
        r.quotaCounted=IsConfirmedToday(positionID);
     }
   }
   else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY ||
entry==DEAL_ENTRY_INOUT)
   {
    if(!ownsCycle) continue;
    double remaining=MathMax(0.0,r.totalVolumeIn-r.totalVolumeOut);
    if(remaining<=tol) continue;
    double ownVol=MathMin(vol,remaining);
      if(entry!=DEAL_ENTRY_INOUT && vol>remaining+tol) r.accountingResolved=false;
      double total=r.totalVolumeOut+ownVol;
      r.weightedExitPrice=(r.weightedExitPrice*r.totalVolumeOut+price*ownVol)/total;
      r.totalVolumeOut=total; r.exitTime=tm;
      r.exitTimeMSC=HistoryDealGetInteger(d,DEAL_TIME_MSC); r.lastExitDealTicket=d;
      // DEAL_PROFIT/SWAP of INOUT belong to its closing component.
      r.grossProfit+=HistoryDealGetDouble(d,DEAL_PROFIT);
      r.swap+=HistoryDealGetDouble(d,DEAL_SWAP);
       if(MathAbs(vol-ownVol)<=tol)
       {
          r.commission+=HistoryDealGetDouble(d,DEAL_COMMISSION);
          r.fee+=HistoryDealGetDouble(d,DEAL_FEE);
       }
       else if(HistoryDealGetDouble(d,DEAL_COMMISSION)!=0 ||
HistoryDealGetDouble(d,DEAL_FEE)!=0)
       {
          // A single INOUT cost has no authoritative close/reversal split.
          // Do not invent proportional fees for the unowned residual.
          if(entry==DEAL_ENTRY_INOUT) r.inoutCostsUnresolved=true;
          else r.accountingResolved=false;
          Print("[SCALPER][RESTART_ACCOUNTING_PARTIAL] INOUT_COST_ALLOCATION_UNAVAILABLE");
       }
       if(beHasContext && beExitListValid) beOwnExitDeals[beOwnExitCount++]=d;
      r.exitReason=DealExitReason(d,positionID);
      if(entry==DEAL_ENTRY_INOUT && vol>ownVol+tol)
     {
         // RC1 never requests a reversal: current-position guards forbid it.
         // Even a matching request cannot turn a mixed netting cycle into
         // a fresh positionID. Preserve the own close; reject appropriation.
         residualForeign=true; r.residualForeignDetected=true;
         r.ownCycleEconomicallyClosed=(gNetting && r.accountingResolved && !foreignEntry
&&
         r.totalVolumeIn>tol && r.totalVolumeOut+tol>=r.totalVolumeIn);
         Print("[SCALPER][INOUT_RESIDUAL_NOT_APPROPRIATED]");
     }
  }
}
if(!ownsCycle)
{ gTradeRecords[idx].historyRefreshPending=true;
gTradeRecords[idx].accountingResolved=false;
  gTradeRecords[idx].volumeOwnershipResolved=false;
  gTradeRecords[idx].ownCycleEconomicallyClosed=false;
   MarkTemporaryAccountingHistory(); return false; }
 if(foreignEntry) r.accountingResolved=false;
 r.entryPrice=r.weightedEntryPrice; r.exitPrice=r.weightedExitPrice;
 r.volume=r.totalVolumeIn;
 r.netProfit=r.grossProfit+r.commission+r.fee+r.swap;
 double liveVol,liveSL,liveTP; int liveDir;
 bool live=PositionStateByID(positionID,liveVol,liveSL,liveTP,liveDir);
 if(live && !residualForeign)
{
    // Initial SL/TP come from request/metadata/entry order, not mutable live stops.
    double expected=r.totalVolumeIn-r.totalVolumeOut;
    // During transaction delivery, the deal cache and position state can lag
    // independently. A completed OUT waits in TryFinalize until flat; a
    // transient state mismatch does not permanently poison the record.
  if(restarting && (MathAbs(expected-liveVol)>tol || liveDir!=r.direction))
     r.accountingResolved=false;
  }
  if(r.entryOrderTicket>0 && HistoryOrderSelect(r.entryOrderTicket))
  {
     double initialSL=HistoryOrderGetDouble(r.entryOrderTicket,ORDER_SL);
     if(initialSL>0)
     {
        r.slPrice=initialSL; r.tpPrice=HistoryOrderGetDouble(r.entryOrderTicket,ORDER_TP);
        r.initialStopsProven=true;
     }
  }
  if(!r.initialStopsProven) { r.slPrice=0; r.tpPrice=0; }
  double risk=CalcInitialRiskMoney(r.direction,r.weightedEntryPrice,r.slPrice,r.totalVolumeIn);
  if(risk>0) { r.initialRiskMoney=risk; r.riskValid=true; }
  else { r.initialRiskMoney=0; r.riskValid=false; }
  if(r.requestPriceAvailable)
      r.entrySlippage=(double)r.direction*(r.weightedEntryPrice-r.requestPrice);
   else r.entrySlippage=EMPTY_VALUE;
   r.volumeClosedComplete=(r.totalVolumeIn>tol && r.totalVolumeOut+tol>=r.totalVolumeIn);
   r.volumeOwnershipResolved=r.accountingResolved;
   r.ownCycleEconomicallyClosed=(r.ownCycleEconomicallyClosed &&
      r.volumeOwnershipResolved && r.volumeClosedComplete &&
r.residualForeignDetected);
   // Classify only after the complete entry mean and initial order stops are rebuilt.
   if(r.be.stage==BE_ACKNOWLEDGED && !r.be.durable) BEPersist(r);
   bool allOwnExitsBE=(beHasContext && beExitListValid && beOwnExitCount>0);
   bool allExitsAtBELevel=allOwnExitsBE;
   for(int j=0;j<beOwnExitCount;j++)
   {
      if(!BEExitAtProtectedLevel(r,beOwnExitDeals[j])) allExitsAtBELevel=false;
      if(!BEProtectedDeal(r,beOwnExitDeals[j]) || !BEConfirm(r,true)) allOwnExitsBE=false;
   }
   r.breakEvenClassificationPending=(r.volumeClosedComplete && beHasContext &&
      (!beExitListValid || (allExitsAtBELevel &&
        (r.be.stage==BE_REQUEST_PENDING || r.be.stage==BE_ACKNOWLEDGED))));
  if(r.breakEvenClassificationPending)
     BEFailure(r,"BE_EXIT_PROOF_PENDING; finalization/accounting publication deferred");
  r.breakEvenExit=(allOwnExitsBE && r.volumeClosedComplete &&
     r.accountingResolved && r.be.stage==BE_CONFIRMED && r.be.durable &&
BEReferenceValid(r));
  if(r.breakEvenExit)
  {
     r.exitReason="BE";
     if(!r.be.exitLogged) { BELog(r,"BE_EXIT","BE_NEUTRAL; economic PnL unchanged");
r.be.exitLogged=true; }
  }
  if(r.inoutCostsUnresolved)
  { r.accountingResolved=false; r.netProfit=EMPTY_VALUE; r.PnL_R=EMPTY_VALUE;
r.pnlRValid=false; }
  if(r.volumeClosedComplete && gOpenPos.active && gOpenPos.positionID==positionID &&
     (r.expectedEntryVolume<=0 || r.totalVolumeIn+tol>=r.expectedEntryVolume))
 {
     // Volume already closed stops excursion tracking even if Positions lags
     // or an unowned INOUT residual still occupies the netting identifier.
     r.MAE=gOpenPos.MAE; r.MFE=gOpenPos.MFE; ResetOpenPos();
  }
  if(restarting) r.maeMfePartialAfterRestart=true;
  r.holdSeconds=(r.exitTime>0 ? (long)(r.exitTime-r.entryTime) : 0);
  gTradeRecords[idx]=r;
  SyncEconomicMarker(idx);
  if(!r.accountingResolved)
  {
    if(live && !CanIgnoreForeignResidual(r)) gLiveOwnershipUnresolved=true;
    gDailyEconomicsValid=false;
    gDailyPnLRValid=false;
    gDailyHistoryRetryRequired=true;
    Print("[SCALPER][RESTART_ACCOUNTING_UNRESOLVED] historical/current volume or ownership mismatch");
  }
  SaveTradeMetadata(gTradeRecords[idx]);
   return true;
}

void SyncOpenPositionFromRecord(int idx)
{
  TradeRecord r=gTradeRecords[idx];
  BookDiagConfirmed(r);
  if(r.volumeClosedComplete) return;
  double volume,sl,tp; int direction;
  if(r.totalVolumeIn<=0 || !r.accountingResolved) return;
  bool positionVisible=PositionStateByID(r.positionID,volume,sl,tp,direction);
  if(positionVisible && direction!=r.direction) return;
  if(gOpenPos.active && gOpenPos.positionID!=r.positionID)
  { gLiveOwnershipUnresolved=true;
Print("[SCALPER][MULTIPLE_OWN_POSITIONS_UNRESOLVED]"); return; }
  if(!gOpenPos.active)
  { ResetOpenPos(); gOpenPos.active=true; gOpenPos.MAE=r.MAE;
gOpenPos.MFE=r.MFE; }
  gOpenPos.positionID=r.positionID; gOpenPos.direction=r.direction;
  gOpenPos.entryPrice=r.weightedEntryPrice; gOpenPos.lots=r.totalVolumeIn;
  gOpenPos.entryTime=r.entryTime; gOpenPos.route=r.route; gOpenPos.mode=r.mode;
  gOpenPos.initialRiskMoney=r.initialRiskMoney; gOpenPos.tradeRecordIdx=idx;
}

bool CanIgnoreForeignResidual(const TradeRecord &r)
{
  double tol=AccountingVolumeTolerance();
  return gNetting && !r.historyRefreshPending && r.volumeOwnershipResolved &&
   r.residualForeignDetected && r.ownCycleEconomicallyClosed &&
    r.totalVolumeIn>tol && r.totalVolumeOut+tol>=r.totalVolumeIn;
}

bool MayFinalizeTrackedCycle(const TradeRecord &r)
{
  if(r.breakEvenClassificationPending) return false;
  if(r.historyRefreshPending) return false;
  // Unknown costs may keep economics partial, without keeping the own cycle open.
  return r.accountingResolved || (CanIgnoreForeignResidual(r) && r.inoutCostsUnresolved);
}

bool IsTrackedVolumeCycleComplete(const TradeRecord &r)
{
  if(!MayFinalizeTrackedCycle(r) || !r.volumeClosedComplete) return false;
  if(HasOwnPendingOrder() || gPendingOrderClassificationUnresolved ||
     gOrderRegistryUnavailable || gMultipleOwnOrdersActive ||
     gOrderObligationScanUnresolved) return false;
  // Every observed exact-order lifecycle associated with this PID must finish,
  // not only the first entry order. A vanished UNKNOWN still carries its PID.
  for(int i=0;i<ArraySize(gUnresolvedOrders);i++)
     if(gUnresolvedOrders[i].active &&
        (gUnresolvedOrders[i].positionID==r.positionID ||
         gUnresolvedOrders[i].positionByID==r.positionID)) return false;
  double vol,sl,tp; int direction;
  if(PositionStateByID(r.positionID,vol,sl,tp,direction) && !CanIgnoreForeignResidual(r))
return false;
  if(r.entryOrderTicket>0 && OrderSelect(r.entryOrderTicket))
     return false;
  // A notified exit can precede other entry fills. A known requested quantity
  // provides a further guard, without assuming FOK means one deal.
    if(r.expectedEntryVolume>0 &&
r.totalVolumeIn+AccountingVolumeTolerance()<r.expectedEntryVolume)
    {
      bool completed=false;
      if(r.entryOrderTicket>0 && HistoryOrderSelect(r.entryOrderTicket))
      {
         ENUM_ORDER_STATE
st=(ENUM_ORDER_STATE)HistoryOrderGetInteger(r.entryOrderTicket,ORDER_STATE);
         if(st==ORDER_STATE_CANCELED || st==ORDER_STATE_REJECTED ||
st==ORDER_STATE_EXPIRED)
           // Rejected terminal orders can also have confirmed partial fills.
         {
            double
filled=HistoryOrderGetDouble(r.entryOrderTicket,ORDER_VOLUME_INITIAL)-
              HistoryOrderGetDouble(r.entryOrderTicket,ORDER_VOLUME_CURRENT);
            completed=(MathAbs(filled-r.totalVolumeIn)<=AccountingVolumeTolerance());
         }
      }
     if(!completed) return false;
    }
    return true;
}

void TryFinalizeTrackedTrade(ulong positionID)
{
  int idx=FindTrackedTrade(positionID);
  if(idx<0 || gTradeRecords[idx].closed || !gTradeRecords[idx].volumeClosedComplete)
return;
  TradeRecord r=gTradeRecords[idx];
  if(!MayFinalizeTrackedCycle(r)) return;
  if(!IsTrackedVolumeCycleComplete(r)) { gNeedsAccountingSync=true; return; }
  if(gOpenPos.active && gOpenPos.positionID==positionID)
 { r.MAE=gOpenPos.MAE; r.MFE=gOpenPos.MFE; }
 r.closed=true; r.holdSeconds=(long)(r.exitTime-r.entryTime);
 r.netProfit=(r.accountingResolved ? r.grossProfit+r.commission+r.fee+r.swap :
EMPTY_VALUE);
 if(r.accountingResolved && r.riskValid && r.initialRiskMoney>0)
 { r.PnL_R=r.netProfit/r.initialRiskMoney; r.pnlRValid=true; }
 else
 { r.PnL_R=EMPTY_VALUE; r.pnlRValid=false;
Print("[SCALPER][ACCOUNTING_RISK_UNAVAILABLE]"); }
 if(!r.accountingResolved)
 {
    // Acknowledge this partial cycle once; no invented net result or loss count.
    r.PnL_R=EMPTY_VALUE; r.pnlRValid=false; r.dailyApplied=true;
    gDailyEconomicsValid=false; gDailyPnLRValid=false;
    gDailyEconomicsState=ECONOMIC_ALLOCATION_IMPOSSIBLE;
    lastCloseConfirmedTime=TimeTradeServer();
    RecomputeDailyRiskBlock();
    PersistDailyAccounting();
    Print("[SCALPER][OWN_CYCLE_CLOSED_ACCOUNTING_PARTIAL] INOUT_COST_ALLOCATION_UNAVAILABLE");
 }
 if(r.accountingResolved && !r.dailyApplied && r.exitTime>=AccountingDayStart())
 {
    dailyNetPnL+=r.netProfit;
    if(r.pnlRValid) dailyPnLR+=r.PnL_R;
    else gDailyPnLRValid=false;
    lastTradeWasLoss=BEManagerLoss(r);
    consecutiveLosses=(lastTradeWasLoss ? consecutiveLosses+1 : 0);
    lastCloseConfirmedTime=TimeTradeServer();
    if(Inp_EnableDailyRiskStop && gDailyPnLRValid && dailyPnLR<=-Inp_MaxDailyLossR)
       gDailyRiskLimitLatched=true;
    if(Inp_EnableConsecutiveLossStop && gDailyEconomicsValid &&
consecutiveLosses>=Inp_MaxConsecutiveLosses)
       gDailyRiskLimitLatched=true;
    r.dailyApplied=true;
    gDailyHistoryRetryRequired=true;
    RecomputeDailyRiskBlock();
    PersistDailyAccounting();
   }
   gTradeRecords[idx]=r;
   if(!r.finalizationWritten && csvTradeHandle!=INVALID_HANDLE)
   {
      if(WriteTradeRow(gTradeRecords[idx])) gTradeRecords[idx].finalizationWritten=true;
   }
   SaveTradeMetadata(gTradeRecords[idx]);
   SyncEconomicMarker(idx);
    FailExitIntent(positionID);
    if(gOpenPos.active && gOpenPos.positionID==positionID) ResetOpenPos();
}

int FindUnresolvedOrder(ulong ticket)
{
  for(int i=0;i<ArraySize(gUnresolvedOrders);i++)
   if(gUnresolvedOrders[i].active && gUnresolvedOrders[i].orderTicket==ticket) return i;
  return -1;
}

int RememberUnresolvedOrder(ulong ticket)
{
  if(ticket==0) return -1; // Request context itself protects an unknown ticket.
  // Commit the exact identity before any allocation can lose its RAM slot.
  bool present=FileIsExist(OrderObligationPath(ticket));
  bool durable=EnsureOrderObligationIdentity(ticket);
  if(!durable) gOrderObligationScanUnresolved=true;
  int idx=FindUnresolvedOrder(ticket);
if(idx>=0)
{
   if(!present || !durable) gUnresolvedOrders[idx].persistencePending=true;
   for(int i=0;i<gOrderRegistryFallbackCount;i++)
      if(gOrderRegistryFallback[i]==ticket)
      {
         for(int j=i+1;j<gOrderRegistryFallbackCount;j++)
           gOrderRegistryFallback[j-1]=gOrderRegistryFallback[j];
         gOrderRegistryFallbackCount--; break;
      }
   return idx;
}
int n=ArraySize(gUnresolvedOrders);
idx=-1;
for(int i=0;i<n;i++) if(!gUnresolvedOrders[i].active) { idx=i; break; }
if(idx<0)
{
     if(ArrayResize(gUnresolvedOrders,n+1)!=n+1)
     {
        bool seen=false;
        for(int i=0;i<gOrderRegistryFallbackCount;i++)
           if(gOrderRegistryFallback[i]==ticket) { seen=true; break; }
        if(!seen)
        {
           if(gOrderRegistryFallbackCount<MAX_TRADE_RECORDS)
              gOrderRegistryFallback[gOrderRegistryFallbackCount++]=ticket;
           else if(!FileIsExist(OrderObligationPath(ticket)))
           {
              // Only a genuinely lost identity is a permanent obligation.
          gOrderRegistryOverflow=true;
          MarkInfrastructureIdentityLoss();
      }
      }
      // A durable filename remains recoverable even if both RAM lists fill.
      gOrderObligationScanUnresolved=true;
      gOrderRegistryUnavailable=true; gPendingOrderClassificationUnresolved=true;
      return -1;
     }
     idx=n;
    }
    UnresolvedOrderContext c;
    UnknownOrderObligationContext(ticket,c);
    c.firstSeen=TimeTradeServer();
    if(!gOrderObligationRestoring) PersistOrderObligationSnapshot(c);
    gUnresolvedOrders[idx]=c;
    gPendingOrderClassificationUnresolved=true;
    for(int i=0;i<gOrderRegistryFallbackCount;i++)
       if(gOrderRegistryFallback[i]==ticket)
        {
           for(int j=i+1;j<gOrderRegistryFallbackCount;j++)
            gOrderRegistryFallback[j-1]=gOrderRegistryFallback[j];
           gOrderRegistryFallbackCount--; break;
        }
      return idx;
}

bool ReadOwnOrder(UnresolvedOrderContext &c,bool &live)
{
  ulong ticket=c.orderTicket;
  live=OrderSelect(ticket);
  if(!live && !HistoryOrderSelect(ticket)) return false;
  string
symbol=live?OrderGetString(ORDER_SYMBOL):HistoryOrderGetString(ticket,ORDER_SYMBOL);
  long
magic=live?OrderGetInteger(ORDER_MAGIC):HistoryOrderGetInteger(ticket,ORDER_MAGIC);
 if(symbol!=Symbol() || magic!=(long)gMagicCore) return false;

c.orderType=live?OrderGetInteger(ORDER_TYPE):HistoryOrderGetInteger(ticket,ORDER_TYPE);

c.orderReason=live?OrderGetInteger(ORDER_REASON):HistoryOrderGetInteger(ticket,ORDER_REASON);
 ulong
pid=(ulong)(live?OrderGetInteger(ORDER_POSITION_ID):HistoryOrderGetInteger(ticket,ORDER_POSITION_ID));
 if(c.positionID>0 && pid>0 && c.positionID!=pid) return false;
 if(pid>0) c.positionID=pid;
c.positionByID=(ulong)(live?OrderGetInteger(ORDER_POSITION_BY_ID):HistoryOrderGetInteger(ticket,ORDER_POSITION_BY_ID));

c.setupTime=(datetime)(live?OrderGetInteger(ORDER_TIME_SETUP):HistoryOrderGetInteger(ticket,ORDER_TIME_SETUP));
 c.doneTime=live?0:(datetime)HistoryOrderGetInteger(ticket,ORDER_TIME_DONE);
c.lastState=(ENUM_ORDER_STATE)(live?OrderGetInteger(ORDER_STATE):HistoryOrderGetInteger(ticket,ORDER_STATE));

c.initialVolume=live?OrderGetDouble(ORDER_VOLUME_INITIAL):HistoryOrderGetDouble(ticket,ORDER_VOLUME_INITIAL);

c.remainingVolume=live?OrderGetDouble(ORDER_VOLUME_CURRENT):HistoryOrderGetDouble(ticket,ORDER_VOLUME_CURRENT);
c.comment=live?OrderGetString(ORDER_COMMENT):HistoryOrderGetString(ticket,ORDER_COMMENT);
  return c.setupTime>0 && c.initialVolume>0 && c.remainingVolume>=0;
}

bool PendingOrderFillEvidence(ulong order,bool &entryFill,bool &exitFill,
             bool &conflict,ulong &positionID,double &filledVolume,
             string &route,string &mode)
{
  entryFill=false; exitFill=false; conflict=false;
  positionID=0; filledVolume=0; route="UNAVAILABLE"; mode="UNAVAILABLE";
  UnresolvedOrderContext c; c.orderTicket=order; c.positionID=0;
  bool live;
  if(!ReadOwnOrder(c,live)) return false;
  // No account-wide scan from zero. Setup is the authoritative lower bound;
  // one second of overlap covers timestamps truncated by ORDER_TIME_SETUP.
  datetime until=TimeTradeServer();
  if(c.doneTime>=until) until=c.doneTime+1;
  if(!HistorySelect(c.setupTime-1,until)) return false;
 for(int i=0;i<HistoryDealsTotal();i++)
 {
    ulong d=HistoryDealGetTicket(i);
    if(d==0 || (ulong)HistoryDealGetInteger(d,DEAL_ORDER)!=order) continue;
    if(HistoryDealGetString(d,DEAL_SYMBOL)!=Symbol()) { conflict=true; continue; }
    long type=HistoryDealGetInteger(d,DEAL_TYPE);
    if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) continue;
    ulong pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
    long entry=HistoryDealGetInteger(d,DEAL_ENTRY);
    // CLOSE_BY has two position IDs. Its paired OUT_BY is not a second
    // fill of the primary position; both ledgers reconcile independently.
    if(c.orderType==ORDER_TYPE_CLOSE_BY && pid==c.positionByID &&
pid!=c.positionID)
   {
   if(entry!=DEAL_ENTRY_OUT_BY) conflict=true;
   continue;
  }
  if(pid==0 || (positionID>0 && positionID!=pid) ||
     (c.positionID>0 && c.positionID!=pid)) conflict=true;
positionID=pid;
if(entry==DEAL_ENTRY_IN)
{
   entryFill=true;
   if(HistoryDealGetInteger(d,DEAL_MAGIC)!=(long)gMagicCore) conflict=true;
   string foundRoute,foundMode;

if(ParseScalperComment(HistoryDealGetString(d,DEAL_COMMENT),foundRoute,foundMode))
      {
          if(route!="UNAVAILABLE" && (route!=foundRoute || mode!=foundMode))
conflict=true;
          route=foundRoute; mode=foundMode;
        }
     }
     else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY ||
entry==DEAL_ENTRY_INOUT)
        exitFill=true; // Own portion of INOUT must still be proven by the ledger.
     else conflict=true;
     double volume=HistoryDealGetDouble(d,DEAL_VOLUME);
     if(volume<=0 || !MathIsValidNumber(volume)) conflict=true;
     else filledVolume+=volume;
  }
  if(entryFill && exitFill) conflict=true;
  return true;
}

bool TerminalOrder(ENUM_ORDER_STATE state)
{
  return state==ORDER_STATE_FILLED || state==ORDER_STATE_CANCELED ||
   state==ORDER_STATE_REJECTED || state==ORDER_STATE_EXPIRED;
}

bool ProvenOrderFillComplete(const UnresolvedOrderContext &c,double filled)
{
  double expected=c.initialVolume-c.remainingVolume;
  double tol=AccountingVolumeTolerance();
  return TerminalOrder(c.lastState) && expected>=-tol &&
   MathAbs(expected-filled)<=tol &&
   (c.lastState!=ORDER_STATE_FILLED || filled>tol);
}
bool AdoptLiveEntry(const UnresolvedOrderContext &c)
{
  if(gRequestJournalUnresolved || gRequestJournalWritePending ||
     gEntryJournalCleanupPending || gExitJournalCleanupPending) return false;
  if(gPendingExit.active) return false;
  if(gPendingExec.active)
 {
     // Never overwrite a known request with a newly discovered ambiguous order.
     if(gPendingExec.orderTicket==c.orderTicket) return true;
     return false;
  }
  if(!OrderSelect(c.orderTicket)) return false;
  ResetPendingExec(false); gPendingExec.active=true; gPendingExec.accepted=true;
  gPendingExec.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
  gPendingExec.orderTicket=c.orderTicket;
  gPendingExec.direction=(c.orderType==ORDER_TYPE_BUY?1:-1);
  gPendingExec.sentAt=c.setupTime; gPendingExec.requestedLots=c.initialVolume;
  gPendingExec.slPrice=OrderGetDouble(ORDER_SL);
gPendingExec.tpPrice=OrderGetDouble(ORDER_TP);
  gPendingExec.route=c.route; gPendingExec.mode=c.mode;
  gPendingExec.requestPriceAvailable=false;
  PersistRequestJournal(false);
  return true;
}

bool AdoptLiveExit(const UnresolvedOrderContext &c)
{
  if(gRequestJournalUnresolved || gRequestJournalWritePending ||
     gEntryJournalCleanupPending || gExitJournalCleanupPending) return false;
  if(c.positionID==0 || gPendingExec.active) return false;
  if(gPendingExit.active && (gPendingExit.positionID!=c.positionID ||
     (gPendingExit.orderTicket>0 && gPendingExit.orderTicket!=c.orderTicket))) return false;
  if(!gPendingExit.active) BeginExitIntent(c.positionID,"RECOVERED_EXIT");
  gPendingExit.orderTicket=c.orderTicket; gPendingExit.sentAt=c.setupTime;
  gPendingExit.accepted=true;
    PersistRequestJournal(true);
    return true;
}

void RestorePendingOrder()
{
  int found=0;
  bool complete=true;
  // Failed allocations retain exact identities independently of OrdersTotal.
  int fallback=gOrderRegistryFallbackCount;
  for(int i=fallback-1;i>=0;i--)
     if(RememberUnresolvedOrder(gOrderRegistryFallback[i])<0) complete=false;
  for(int i=OrdersTotal()-1;i>=0;i--)
 {
     ulong ticket=OrderGetTicket(i);
     if(ticket==0) { complete=false; continue; }
     if(OrderGetString(ORDER_SYMBOL)!=Symbol() ||
OrderGetInteger(ORDER_MAGIC)!=(long)gMagicCore) continue;
     found++;
     if(RememberUnresolvedOrder(ticket)<0) complete=false;
  }
  gMultipleOwnOrdersActive=found>1;
  gOrderRegistryUnavailable=!complete || gOrderRegistryFallbackCount>0 ||
gOrderRegistryOverflow;
  gPendingOrderClassificationUnresolved=gMultipleOwnOrdersActive ||
gOrderRegistryUnavailable ||
     gOrderObligationScanUnresolved;
  for(int i=0;i<ArraySize(gUnresolvedOrders);i++)
     if(gUnresolvedOrders[i].active && (gUnresolvedOrders[i].classificationPending ||
        gUnresolvedOrders[i].persistencePending))
        gPendingOrderClassificationUnresolved=true;
    // Zero live orders does not clear any stored ambiguity.
}

void ReconcileUnresolvedOrders()
{
   RestorePendingOrder();
   for(int i=0;i<ArraySize(gUnresolvedOrders);i++)
   {
     if(!gUnresolvedOrders[i].active) continue;
     UnresolvedOrderContext c=gUnresolvedOrders[i];
     c.classificationPending=true;
     bool live;
     if(!ReadOwnOrder(c,live)) { StoreOrderObligationContext(i,c,false); continue; }
     bool entryFill,exitFill,conflict; ulong pid; double filled; string route,mode;
     if(!PendingOrderFillEvidence(c.orderTicket,entryFill,exitFill,conflict,pid,filled,route,mode)
|| conflict)
     { StoreOrderObligationContext(i,c,true); continue; }
    if(pid>0) c.positionID=pid;
    bool marker=StringFind(c.comment,"RC1|")==0 &&
ParseScalperComment(c.comment,c.route,c.mode);
    bool market=c.orderType==ORDER_TYPE_BUY || c.orderType==ORDER_TYPE_SELL;
    int idx=FindTrackedTrade(c.positionID);
    if(entryFill || exitFill)
    {
       if(entryFill && (!market || c.positionByID>0 || c.orderReason==ORDER_REASON_SL ||
          c.orderReason==ORDER_REASON_TP ||
          (marker && route!="UNAVAILABLE" && (c.route!=route || c.mode!=mode))))
       { StoreOrderObligationContext(i,c,true); continue; }
       // OUT with another Magic is admitted only through proven own IN history.
       if(idx<0 && (entryFill || HasOwnEntryHistory(c.positionID)))
       {
      idx=NewTrackedTrade(c.positionID);
      if(idx>=0) LoadTradeMetadata(gTradeRecords[idx]);
      }
      if(idx<0 || !RebuildTrackedHistory(idx,false)) { StoreOrderObligationContext(i,c,true);
continue; }
      TradeRecord r=gTradeRecords[idx];
    bool own=r.volumeOwnershipResolved && r.totalVolumeIn>0;
    if(!own || (entryFill && (r.residualForeignDetected || r.entryOrderTicket!=c.orderTicket)))
    { StoreOrderObligationContext(i,c,true); continue; }
    c.nature=entryFill?PENDING_ORDER_ENTRY:PENDING_ORDER_EXIT;
    if(exitFill && gPendingExec.active && gPendingExec.orderTicket==c.orderTicket)
       ResetPendingExec(); // Exact order + own exit ledger, never an inferred entry.
    SyncOpenPositionFromRecord(idx);
    TryFinalizeTrackedTrade(c.positionID);
    if(c.positionByID>0)
 {
      int by=FindTrackedTrade(c.positionByID);
      if(by<0 && HasOwnEntryHistory(c.positionByID))
      { by=NewTrackedTrade(c.positionByID); if(by>=0)
LoadTradeMetadata(gTradeRecords[by]); }
      if(by>=0 && RebuildTrackedHistory(by,false))
TryFinalizeTrackedTrade(c.positionByID);
   }
   if(!live && ProvenOrderFillComplete(c,filled))
   {
      if(ReleaseOrderObligation(c) && exitFill && gPendingExit.active &&
         gPendingExit.orderTicket==c.orderTicket &&
         gPendingExit.positionID==c.positionID && gTradeRecords[idx].closed)
         FailExitIntent(c.positionID,true);
   }
   else if(live && !gMultipleOwnOrdersActive)
   {
      // A confirmed own IN is already represented by its ledger. Do not
      // recreate/reset entry request metadata after the first fill.
      bool adopted=entryFill?true:AdoptLiveExit(c);
      c.classificationPending=!adopted;
  }
 }
 else if(!live && ProvenOrderFillComplete(c,filled) &&
c.lastState!=ORDER_STATE_FILLED)
 {
   // Terminal negative state plus complete, exact-order zero-fill history.
   if(ReleaseOrderObligation(c))
   {
      if(gPendingExec.active && gPendingExec.orderTicket==c.orderTicket)
ResetPendingExec();
      if(gPendingExit.active && gPendingExit.orderTicket==c.orderTicket)
FailExitIntent(gPendingExit.positionID,true);
  }
  }
  else if(live && !gMultipleOwnOrdersActive)
  {
    if(marker && market && c.orderReason!=ORDER_REASON_SL &&
c.orderReason!=ORDER_REASON_TP &&
       c.positionID==0 && c.positionByID==0 && !HasOpenPosition())
    {
       c.nature=PENDING_ORDER_ENTRY; c.classificationPending=!AdoptLiveEntry(c);
     }
     else if(!marker && idx>=0 && gTradeRecords[idx].accountingResolved &&
OwnPositionSafe(c.positionID))
     {
       TradeRecord r=gTradeRecords[idx]; double volume,sl,tp; int direction;
       double remainder=r.totalVolumeIn-r.totalVolumeOut;
    bool opposite=(c.orderType==ORDER_TYPE_BUY && r.direction==-1) ||
         (c.orderType==ORDER_TYPE_SELL && r.direction==1);
    bool bounded=!r.closed && remainder>0 && c.remainingVolume>0 &&
       c.remainingVolume<=remainder+AccountingVolumeTolerance() &&
       PositionStateByID(c.positionID,volume,sl,tp,direction) && direction==r.direction &&
       MathAbs(volume-remainder)<=AccountingVolumeTolerance();
    if(bounded && ((market && opposite && c.positionByID==0) ||
       (c.orderType==ORDER_TYPE_CLOSE_BY && c.positionByID>0)))
    { c.nature=PENDING_ORDER_EXIT; c.classificationPending=!AdoptLiveExit(c); }
   }
 }
 StoreOrderObligationContext(i,c,true);
 }
 gPendingOrderClassificationUnresolved=gMultipleOwnOrdersActive ||
gOrderRegistryUnavailable ||
   gOrderObligationScanUnresolved;
 for(int i=0;i<ArraySize(gUnresolvedOrders);i++)
   if(gUnresolvedOrders[i].active && (gUnresolvedOrders[i].classificationPending ||
      gUnresolvedOrders[i].persistencePending))
    gPendingOrderClassificationUnresolved=true;
}

bool MatchesUnidentifiedEntryOrder(ulong ticket)
{
  UnresolvedOrderContext c; ZeroMemory(c);
  c.orderTicket=ticket; bool live;
  if(!ReadOwnOrder(c,live) || gPendingExec.sentAt<=0 ||
     c.setupTime<gPendingExec.sentAt || c.positionByID>0 ||
     c.orderReason==ORDER_REASON_SL || c.orderReason==ORDER_REASON_TP)
return false;
  int direction=(c.orderType==ORDER_TYPE_BUY?1:
     (c.orderType==ORDER_TYPE_SELL?-1:0));
    string route,mode;
     return direction==gPendingExec.direction &&
       ParseScalperComment(c.comment,route,mode) && route==gPendingExec.route &&
       mode==gPendingExec.mode &&
       MathAbs(c.initialVolume-gPendingExec.requestedLots)<=AccountingVolumeTolerance();
}

void RecoverUnidentifiedEntryOrder()
{
  if(!gPendingExec.active || gPendingExec.orderTicket>0 ||
      gPendingExec.resultDeal>0 || gPendingExec.sentAt<=0) return;
   datetime start=gPendingExec.sentAt-1;
   if(!HistorySelect(start,TimeTradeServer())) { MarkTemporaryAccountingHistory(); return; }
   // Snapshot exact tickets before HistoryOrderSelect changes the selected list.
   ulong tickets[]; int count=0;
   int total=HistoryOrdersTotal()+OrdersTotal();
   if(ArrayResize(tickets,total)!=total) { MarkTemporaryAccountingHistory(); return; }
   for(int i=0;i<HistoryOrdersTotal();i++)
   {
      ulong ticket=HistoryOrderGetTicket(i);
      if(ticket>0 && HistoryOrderGetString(ticket,ORDER_SYMBOL)==Symbol() &&
         HistoryOrderGetInteger(ticket,ORDER_MAGIC)==(long)gMagicCore)
tickets[count++]=ticket;
   }
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || OrderGetString(ORDER_SYMBOL)!=Symbol() ||
         OrderGetInteger(ORDER_MAGIC)!=(long)gMagicCore) continue;
      bool known=false;
      for(int j=0;j<count;j++) if(tickets[j]==ticket) { known=true; break; }
      if(!known) tickets[count++]=ticket;
   }
   ulong candidate=0; int matches=0;
   for(int i=0;i<count;i++)
       if(MatchesUnidentifiedEntryOrder(tickets[i]))
       {
          matches++; candidate=tickets[i];
          RememberUnresolvedOrder(tickets[i]);
       }
    if(matches==1)
    {
       // Own symbol/Magic, exact route/mode, request volume/type and uniqueness
       // jointly associate the order; time and BUY/SELL alone never do so.
       gPendingExec.orderTicket=candidate;
       gPendingExec.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
       PersistRequestJournal(false);
    }
}
void ReconcilePendingExecution()
{
  if(!gPendingExec.active) return;
  RecoverUnidentifiedEntryOrder();
  ulong order=gPendingExec.orderTicket;
  if(order==0 && gPendingExec.resultDeal>0 &&
HistoryDealSelect(gPendingExec.resultDeal))
  {
     ulong d=gPendingExec.resultDeal;
     if(HistoryDealGetString(d,DEAL_SYMBOL)!=Symbol() ||
       HistoryDealGetInteger(d,DEAL_MAGIC)!=(long)gMagicCore) return;
     order=(ulong)HistoryDealGetInteger(d,DEAL_ORDER);
     gPendingExec.orderTicket=order;
    }
    if(order==0) return; // Transport uncertainty has no negative proof.
    RememberUnresolvedOrder(order);
}

void ReconcilePendingExitIntent()
{
  if(!gPendingExit.active) return;
  ulong pid=gPendingExit.positionID;
  int idx=FindTrackedTrade(pid);
  if(idx>=0 && !gTradeRecords[idx].closed)
  {
     if(!RebuildTrackedHistory(idx,false)) return;
     TryFinalizeTrackedTrade(pid);
     if(!gPendingExit.active) return;
  }
  ulong order=gPendingExit.orderTicket;
  if(order==0 && gPendingExit.resultDeal>0 && HistoryDealSelect(gPendingExit.resultDeal))
  {
     ulong d=gPendingExit.resultDeal; long entry=HistoryDealGetInteger(d,DEAL_ENTRY);
     if(HistoryDealGetString(d,DEAL_SYMBOL)!=Symbol() ||
        (ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID)!=pid ||
        (entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY &&
entry!=DEAL_ENTRY_INOUT)) return;
     order=(ulong)HistoryDealGetInteger(d,DEAL_ORDER); gPendingExit.orderTicket=order;
  }
  if(order==0) return;
  int oi=RememberUnresolvedOrder(order);
  if(oi<0) return;
  UnresolvedOrderContext c=gUnresolvedOrders[oi]; bool live;
  if(!ReadOwnOrder(c,live) || live) return;
  bool entryFill,exitFill,conflict; ulong fillPID; double filled; string route,mode;
  if(!PendingOrderFillEvidence(order,entryFill,exitFill,conflict,fillPID,filled,route,mode) ||
     conflict || entryFill || (fillPID>0 && fillPID!=pid) || !ProvenOrderFillComplete(c,filled))
return;
  bool released=ReleaseOrderObligation(c);
  StoreOrderObligationContext(oi,c,false);
  if(!released) return;
  RestorePendingOrder();
  if(idx>=0 && gTradeRecords[idx].closed)
  { FailExitIntent(pid,true); return; }
  if(!exitFill && c.lastState!=ORDER_STATE_FILLED)
  { FailExitIntent(pid,true); return; }
  if(idx<0 || !RebuildTrackedHistory(idx,false)) return;
  TryFinalizeTrackedTrade(pid);
  if(!gPendingExit.active) return;
  if(gTradeRecords[idx].closed) { FailExitIntent(pid,true); return; }
  TradeRecord r=gTradeRecords[idx]; double liveVol,sl,tp; int direction;
  double remainder=r.totalVolumeIn-r.totalVolumeOut;
  if(r.accountingResolved && remainder>AccountingVolumeTolerance() &&
OwnPositionSafe(pid) &&
    PositionStateByID(pid,liveVol,sl,tp,direction) && direction==r.direction &&
    MathAbs(liveVol-remainder)<=AccountingVolumeTolerance()) FailExitIntent(pid,true);
}


void ReconstructOpenPosition(bool restarting=true)
{
  // A fresh authoritative scan owns this flag; absence alone does not clear a
  // tracked order/deal ambiguity, which has its own independent context.
  gLiveOwnershipUnresolved=false;
  ulong ids[]; int count=0;
  for(int i=PositionsTotal()-1;i>=0;i--)
  {
     ulong ticket=PositionGetTicket(i);
     if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=Symbol()) continue;
     ulong pid=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
     long liveMagic=PositionGetInteger(POSITION_MAGIC);
 int tracked=FindTrackedTrade(pid);
 if(!HistorySelectByPosition(pid))
 {
    if(gNetting || liveMagic==(long)gMagicCore || tracked>=0)
       gLiveOwnershipUnresolved=true;
    continue;
 }
 bool ownEntry=false;
 for(int j=0;j<HistoryDealsTotal();j++)
 {
    ulong d=HistoryDealGetTicket(j);
    if(d>0 && HistoryDealGetString(d,DEAL_SYMBOL)==Symbol() &&
       HistoryDealGetInteger(d,DEAL_MAGIC)==(long)gMagicCore &&
       HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_IN)
  { ownEntry=true; break; }
 }
 if(!OwnPositionSafe(pid))
 {
    if(gNetting && ownEntry)
    {
       int idx=tracked; bool existing=(idx>=0);
       if(idx<0) idx=NewTrackedTrade(pid);
       if(idx>=0)
       {
          if(!existing) LoadTradeMetadata(gTradeRecords[idx]);
          if(RebuildTrackedHistory(idx,restarting) &&
             CanIgnoreForeignResidual(gTradeRecords[idx]))
          { TryFinalizeTrackedTrade(pid); continue; }
       }
    gLiveOwnershipUnresolved=true;
    continue;
 }
 if(ownEntry || liveMagic==(long)gMagicCore || tracked>=0)
    gLiveOwnershipUnresolved=true;
 continue;
 }
 if(ArrayResize(ids,count+1)!=count+1)
 { gLiveOwnershipUnresolved=true; continue; }
 ids[count++]=pid;
}
if(count>1) gLiveOwnershipUnresolved=true;
for(int i=0;i<count;i++)
{
   int idx=FindTrackedTrade(ids[i]); bool existing=(idx>=0);
   if(idx<0) idx=NewTrackedTrade(ids[i]);
   if(idx<0) { gLiveOwnershipUnresolved=true; continue; }
   if(!existing) LoadTradeMetadata(gTradeRecords[idx]);
   if(!RebuildTrackedHistory(idx,restarting))
        { gLiveOwnershipUnresolved=true; continue; }
        if(!gTradeRecords[idx].accountingResolved)
        { gLiveOwnershipUnresolved=true; continue; }
        // Keep the one-slot excursion tracker from adopting a second position.
        if(count==1) SyncOpenPositionFromRecord(idx);
        if(restarting && !gTradeRecords[idx].requestPriceAvailable)
           Print("[SCALPER][REQUEST_PRICE_UNAVAILABLE_AFTER_RESTART]");
        if(restarting) Print("[SCALPER][MAE_MFE_PARTIAL_AFTER_RESTART] 1");
    }
}

bool RestoreDailyEconomicsFromHistory(bool restarting=true)
{
  datetime start=AccountingDayStart();
  datetime previousCloseConfirmation=lastCloseConfirmedTime;
  if(!HistorySelect(start,TimeTradeServer()))
  {
     gDailyEconomicsValid=false; gDailyPnLRValid=false;
     gDailyEconomicsState=TEMPORARY_HISTORY_UNAVAILABLE;
     gDailyHistoryRetryRequired=true;
     return false;
  }
  ulong ids[]; int n=0;
  for(int i=0;i<HistoryDealsTotal();i++)
  {
     ulong d=HistoryDealGetTicket(i);
     if(d==0 || HistoryDealGetString(d,DEAL_SYMBOL)!=Symbol()) continue;
     long entry=HistoryDealGetInteger(d,DEAL_ENTRY);
     if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY &&
        entry!=DEAL_ENTRY_INOUT) continue;
     ulong pid=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
 if(pid==0)
 {
    gDailyEconomicsValid=false; gDailyPnLRValid=false;
    gDailyEconomicsState=TEMPORARY_HISTORY_UNAVAILABLE;
 gDailyHistoryRetryRequired=true;
    return false;
 }
 bool seen=false;
 for(int j=0;j<n;j++) if(ids[j]==pid) { seen=true; break; }
 if(!seen)
 {
    if(ArrayResize(ids,n+1)!=n+1)
    {
       gDailyEconomicsValid=false; gDailyPnLRValid=false;
       gDailyEconomicsState=DAILY_ECONOMICS_UNRESOLVED;
       return false;
    }
  ids[n++]=pid;
 }
}
int closedIdx[]; int closedCount=0;
int finalizeIdx[]; int finalizeCount=0;
double net=0, sumR=0;
bool rValid=true, allResolved=true, historyUnavailable=false;
bool allocationImpossible=false;
for(int i=0;i<n;i++)
{
  int idx=FindTrackedTrade(ids[i]); bool existing=(idx>=0);
  // First establish ownership from complete per-position history. A
  // manual OUT with another Magic is still part of the proven own cycle.
  if(!HistorySelectByPosition(ids[i]))
{ allResolved=false; historyUnavailable=true; continue; }
bool own=false;
for(int j=0;j<HistoryDealsTotal();j++)
{
   ulong d=HistoryDealGetTicket(j);
   if(HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_IN &&
      HistoryDealGetInteger(d,DEAL_MAGIC)==(long)gMagicCore &&
      HistoryDealGetString(d,DEAL_SYMBOL)==Symbol())
   { own=true; break; }
}
if(!own) continue;
if(idx<0) idx=NewTrackedTrade(ids[i]);
if(idx<0) { allResolved=false; continue; }
if(!existing) LoadTradeMetadata(gTradeRecords[idx]);
if(!RebuildTrackedHistory(idx,restarting))
 { allResolved=false; historyUnavailable=true; continue; }
 TradeRecord r=gTradeRecords[idx];
  if(!MayFinalizeTrackedCycle(r))
  {
     allResolved=false;
     if(r.inoutCostsUnresolved) allocationImpossible=true;
     continue;
  }
  if(!IsTrackedVolumeCycleComplete(r))
  {
     if(r.volumeClosedComplete)
     { gNeedsAccountingSync=true; allResolved=false; historyUnavailable=true; }
     continue;
  }
  if(r.exitTime<start) continue;
  // The authoritative aggregate applies the day once; TryFinalize remains
  // the closure authority and therefore cannot add this cycle a second time.
  r.dailyApplied=true;
  if(!r.accountingResolved)
{
    r.netProfit=EMPTY_VALUE; r.PnL_R=EMPTY_VALUE; r.pnlRValid=false;
    allResolved=false; rValid=false;
    if(r.inoutCostsUnresolved) allocationImpossible=true;
    gTradeRecords[idx]=r;
  }
  else
  {
     if(r.riskValid && r.initialRiskMoney>0)
     { r.PnL_R=r.netProfit/r.initialRiskMoney; r.pnlRValid=true; sumR+=r.PnL_R; }
     else { r.PnL_R=EMPTY_VALUE; r.pnlRValid=false; rValid=false; }
     net+=r.netProfit;
     gTradeRecords[idx]=r;
     if(ArrayResize(closedIdx,closedCount+1)!=closedCount+1)
    { allResolved=false; continue; }
    closedIdx[closedCount++]=idx;
    }
    if(ArrayResize(finalizeIdx,finalizeCount+1)!=finalizeCount+1)
    { allResolved=false; continue; }
    finalizeIdx[finalizeCount++]=idx;
    }
    for(int i=1;i<closedCount;i++)
    {
      int x=closedIdx[i],j=i-1;
      while(j>=0 &&
(gTradeRecords[closedIdx[j]].exitTimeMSC>gTradeRecords[x].exitTimeMSC ||
         (gTradeRecords[closedIdx[j]].exitTimeMSC==gTradeRecords[x].exitTimeMSC &&
          (gTradeRecords[closedIdx[j]].lastExitDealTicket>gTradeRecords[x].lastExitDealTicket
||
(gTradeRecords[closedIdx[j]].lastExitDealTicket==gTradeRecords[x].lastExitDealTicket &&
        gTradeRecords[closedIdx[j]].positionID>gTradeRecords[x].positionID)))))
   { closedIdx[j+1]=closedIdx[j]; j--; }
   closedIdx[j+1]=x;
 }
 int losses=0; datetime last=0; bool lastLoss=false;
 double runningR=0; bool runningRValid=true;
 for(int i=0;i<closedCount;i++)
 {
    TradeRecord r=gTradeRecords[closedIdx[i]];
    lastLoss=BEManagerLoss(r); losses=(lastLoss ? losses+1 : 0); last=r.exitTime;
    if(r.pnlRValid) runningR+=r.PnL_R; else runningRValid=false;
    // Recover an already-hit stop from the historical daily path, even if a
    // subsequent close recovered the total. These are the existing limits.
    if(Inp_EnableDailyRiskStop && allResolved && runningRValid &&
       runningR<=-Inp_MaxDailyLossR)
       gDailyRiskLimitLatched=true;
    if(Inp_EnableConsecutiveLossStop && allResolved &&
       losses>=Inp_MaxConsecutiveLosses)
    gDailyRiskLimitLatched=true;
}
dailyNetPnL=net; dailyPnLR=sumR;
consecutiveLosses=losses;
// A retry must not move a known runtime confirmation clock backwards.

lastCloseConfirmedTime=(previousCloseConfirmation>last?previousCloseConfirmation:last);
  lastTradeWasLoss=lastLoss;
  gDailyEconomicsValid=allResolved;
  gDailyHistoryRetryRequired=historyUnavailable;
  gDailyPnLRValid=(rValid && allResolved);
  gDailyEconomicsState=(allocationImpossible ? ECONOMIC_ALLOCATION_IMPOSSIBLE
:
    (historyUnavailable ? TEMPORARY_HISTORY_UNAVAILABLE :
       (allResolved ? DAILY_ECONOMICS_VALID : DAILY_ECONOMICS_UNRESOLVED)));
    RecomputeDailyRiskBlock();
    for(int i=0;i<finalizeCount;i++)
    {
      int idx=finalizeIdx[i];
      if(!gTradeRecords[idx].closed) TryFinalizeTrackedTrade(gTradeRecords[idx].positionID);
      else FailExitIntent(gTradeRecords[idx].positionID);
    }
    return allResolved;
}

void RestoreDailyPersistence(bool restarting=true)
{
  RestoreUnresolvedEconomicMarkers();
  int historyCount=CountTodayTrades();
  bool committed=GlobalVariableCheck(AccountingKey("VALID")) &&
     GlobalVariableGet(AccountingKey("VALID"))==1.0 &&
     GlobalVariableCheck(GvKeyDailyPnL()) && GlobalVariableCheck(GvKeyDailyPnLR())
&&
     GlobalVariableCheck(GvKeyConsecLoss()) &&
GlobalVariableCheck(GvKeyDailyBlock());
  gQuotaHistoryValid=(historyCount>=0);
  if(gQuotaHistoryValid) ordersEnteredToday=historyCount;
  // A failed read does not adopt an old counter or publish a partial PID set.
  // Entries remain blocked until a complete CountTodayTrades succeeds.
  if(committed && GlobalVariableCheck(AccountingKey("RISK_LATCH")) &&
     GlobalVariableGet(AccountingKey("RISK_LATCH"))==1.0)
     gDailyRiskLimitLatched=true;
  bool reconstructed=RestoreDailyEconomicsFromHistory(restarting);
  if(!reconstructed && committed)
  {
     dailyNetPnL=GlobalVariableGet(GvKeyDailyPnL());
     dailyPnLR=GlobalVariableGet(GvKeyDailyPnLR());
     consecutiveLosses=(int)GlobalVariableGet(GvKeyConsecLoss());
     // A committed snapshot can predate an unprocessed close. It is partial
     // evidence and cannot restore validity while history is unavailable.
     gDailyEconomicsValid=false; gDailyPnLRValid=false;
     if(GlobalVariableCheck(AccountingKey("CLOSE")))
        lastCloseConfirmedTime=(datetime)GlobalVariableGet(AccountingKey("CLOSE"));
     if(GlobalVariableCheck(AccountingKey("LASTLOSS")))
        lastTradeWasLoss=(GlobalVariableGet(AccountingKey("LASTLOSS"))==1.0);
    }
    ReconstructOpenPosition(restarting);
    if(restarting || !gPendingExec.active) RestorePendingOrder();
    RecomputeDailyRiskBlock(); RecomputeAccountingBlock();
    if(gQuotaHistoryValid && reconstructed) PersistDailyAccounting();
}
// RC1.2 infrastructure helpers; final EA lifecycle follows below.
void RememberDeferredAccountingPID(ulong pid)
{
   for(int i=0;i<ArraySize(gDeferredAccountingPIDs);i++)
      if(gDeferredAccountingPIDs[i]==pid) return;
   int n=ArraySize(gDeferredAccountingPIDs);
   if(ArrayResize(gDeferredAccountingPIDs,n+1)!=n+1)
   {
      bool seen=false;
      for(int i=0;i<gDeferredFallbackCount;i++) if(gDeferredFallback[i]==pid) { seen=true;
break; }
      if(!seen)
      {
      if(gDeferredFallbackCount<MAX_TRADE_RECORDS)
gDeferredFallback[gDeferredFallbackCount++]=pid;
      else
      {
         gDeferredRegistryOverflow=true;
         MarkInfrastructureIdentityLoss();
      }
    }
    gDeferredRegistryUnavailable=true;
  }
  else gDeferredAccountingPIDs[n]=pid;
  gAccountingCapacityUnresolved=true;
}

void ForgetDeferredAccountingPID(ulong pid)
{
  int n=ArraySize(gDeferredAccountingPIDs);
  for(int i=0;i<n;i++)
    if(gDeferredAccountingPIDs[i]==pid)
    {
       for(int j=i+1;j<n;j++) gDeferredAccountingPIDs[j-1]=gDeferredAccountingPIDs[j];
    ArrayResize(gDeferredAccountingPIDs,n-1); break;
   }
  gAccountingCapacityUnresolved=(gDeferredRegistryUnavailable ||
ArraySize(gDeferredAccountingPIDs)>0);
  for(int i=0;i<gDeferredFallbackCount;i++)
   if(gDeferredFallback[i]==pid)
   {
      for(int j=i+1;j<gDeferredFallbackCount;j++)
gDeferredFallback[j-1]=gDeferredFallback[j];
      gDeferredFallbackCount--; break;
   }
  gDeferredRegistryUnavailable=gDeferredRegistryOverflow || gDeferredFallbackCount>0;
  gAccountingCapacityUnresolved=gDeferredRegistryUnavailable ||
ArraySize(gDeferredAccountingPIDs)>0;
}
bool IsFinalRejectedRetcode(uint ret)
{
  switch(ret)
  {
    case TRADE_RETCODE_REQUOTE: case TRADE_RETCODE_REJECT:
    case TRADE_RETCODE_CANCEL: case TRADE_RETCODE_INVALID:
    case TRADE_RETCODE_INVALID_VOLUME: case
TRADE_RETCODE_INVALID_PRICE:
    case TRADE_RETCODE_INVALID_STOPS: case
TRADE_RETCODE_TRADE_DISABLED:
    case TRADE_RETCODE_MARKET_CLOSED: case TRADE_RETCODE_NO_MONEY:
    case TRADE_RETCODE_PRICE_CHANGED: case TRADE_RETCODE_PRICE_OFF:
    case TRADE_RETCODE_INVALID_EXPIRATION: case
TRADE_RETCODE_TOO_MANY_REQUESTS:
    case TRADE_RETCODE_SERVER_DISABLES_AT: case
TRADE_RETCODE_CLIENT_DISABLES_AT:
    case TRADE_RETCODE_INVALID_FILL: case TRADE_RETCODE_ONLY_REAL:
    case TRADE_RETCODE_LIMIT_ORDERS: case TRADE_RETCODE_LIMIT_VOLUME:
    case TRADE_RETCODE_INVALID_ORDER: case
TRADE_RETCODE_POSITION_CLOSED:
    case TRADE_RETCODE_INVALID_CLOSE_VOLUME: case
TRADE_RETCODE_LIMIT_POSITIONS:
    case TRADE_RETCODE_LONG_ONLY: case TRADE_RETCODE_SHORT_ONLY:
    case TRADE_RETCODE_CLOSE_ONLY: case TRADE_RETCODE_FIFO_CLOSE:
    case TRADE_RETCODE_HEDGE_PROHIBITED: return true;
  }
  return false; // Unknown, LOCKED, ERROR and CLOSE_ORDER_EXIST are uncertain.
}

void CompletePendingExit(const MqlTradeResult &result)
{
  if(!gPendingExit.active) return;
    gPendingExit.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
    if(result.request_id>0) gPendingExit.requestID=result.request_id;
    if(result.order>0) gPendingExit.orderTicket=result.order;
    if(result.deal>0) gPendingExit.resultDeal=result.deal;
    if(IsAcceptedRetcode(result.retcode))
    { gPendingExit.accepted=true; gPendingExit.uncertain=false; }
    else if(IsFinalRejectedRetcode(result.retcode) && !gPendingExit.accepted &&
       gPendingExit.orderTicket==0 && gPendingExit.resultDeal==0)
       FailExitIntent(gPendingExit.positionID,true);
    else gPendingExit.uncertain=true;
    if(gPendingExit.active) PersistRequestJournal(true);
    gNeedsAccountingSync=true;
}
bool MatchesExitRequest(const MqlTradeRequest &request,const MqlTradeResult &result)
{
 if(!gPendingExit.active || gPendingExit.positionTicket==0 ||
    gPendingExit.requestID==0 || result.request_id!=gPendingExit.requestID) return false;
 return request.position==gPendingExit.positionTicket && request.symbol==Symbol() &&
    request.magic==(ulong)gMagicCore && request.action==TRADE_ACTION_DEAL &&
    request.position_by==0 && request.type==gPendingExit.requestSnapshot.type &&

MathAbs(request.volume-gPendingExit.requestSnapshot.volume)<=AccountingVolumeTolerance();
}
void SyncAccountingState(bool reconcilePending=false)
{
  // Tick path is a cheap projection only. No history selection/finalization.
  if(!reconcilePending) { RecomputeAccountingBlock(); return; }
  datetime now=TimeTradeServer();
  if(now<gNextOrderReconcile) { RecomputeAccountingBlock(); return; }
  gNextOrderReconcile=now+5; // Timer or transaction transition, never each tick.
  RecoverTradeCsvInfrastructure();
  ReconcileDeferredDeals();
  RecoverAccountingInfrastructure();
  ReconcilePendingExecution();
  ReconcileUnresolvedOrders();
  ReconcilePendingExitIntent();
  for(int i=0;i<gTradeRecordCount;i++)
  {
     if(gTradeRecords[i].historyRefreshPending ||
        (!gTradeRecords[i].closed && !gTradeRecords[i].accountingResolved &&
         !gTradeRecords[i].inoutCostsUnresolved))
     {
        if(RebuildTrackedHistory(i,false)) SyncOpenPositionFromRecord(i);
     }
     if(!gTradeRecords[i].closed) TryFinalizeTrackedTrade(gTradeRecords[i].positionID);
     else if(gPendingExit.active && gPendingExit.positionID==gTradeRecords[i].positionID)
       FailExitIntent(gPendingExit.positionID);
    }
    gNeedsAccountingSync=false;
    if(csvTradeHandle!=INVALID_HANDLE)
       for(int i=0;i<gTradeRecordCount;i++)
         if(gTradeRecords[i].closed && !gTradeRecords[i].finalizationWritten &&
            MayFinalizeTrackedCycle(gTradeRecords[i]))
         {
            if(WriteTradeRow(gTradeRecords[i]))
            {
               gTradeRecords[i].finalizationWritten=true;
               SaveTradeMetadata(gTradeRecords[i]); SyncEconomicMarker(i);
            }
         }
    RecomputeDailyRiskBlock();
    RecomputeAccountingBlock();
}

void RecomputeAccountingBlock()
{
  gAccountingCapacityUnresolved=(ArraySize(gDeferredAccountingPIDs)>0 ||
   gDeferredRegistryUnavailable);
  bool blocked=gPendingOrderClassificationUnresolved || !gQuotaHistoryValid ||
   gLiveOwnershipUnresolved || gAccountingCapacityUnresolved ||
   gMultipleOwnOrdersActive || gOrderRegistryUnavailable ||
   gOrderObligationScanUnresolved ||
    ArraySize(gDeferredDeals)>0 || gDeferredDealFallbackCount>0 ||
gDeferredDealOverflow ||
    !gDailyEconomicsValid || gEconomicMarkerScanUnresolved ||
    gTradeCsvInfrastructureUnresolved ||
    gIdentityLossUnresolved || gRequestJournalUnresolved ||
    gRequestJournalWritePending || gEntryJournalCleanupPending ||
gExitJournalCleanupPending;
  for(int i=0;i<gTradeRecordCount;i++)
  {
    TradeRecord r=gTradeRecords[i];
    if(r.positionID==0) continue;
    // An INOUT cost that cannot be allocated is an explicit permanent
    // economic ambiguity; midnight cannot invent the missing allocation.
    bool relevant=!r.closed || r.exitTime>=AccountingDayStart() ||
       r.inoutCostsUnresolved;
    if(r.economicMarkerPending) blocked=true;
    if(r.breakEvenClassificationPending) blocked=true;
    if(relevant && (r.historyRefreshPending || !r.accountingResolved ||
       r.inoutCostsUnresolved)) blocked=true;
  }
  for(int i=0;i<ArraySize(gUnresolvedOrders);i++)
    if(gUnresolvedOrders[i].active && (gUnresolvedOrders[i].classificationPending ||
       gUnresolvedOrders[i].persistencePending)) blocked=true;
    // The only assignment to the aggregate blocker is here.
    gAccountingUnresolved=blocked;
}

void RecomputeDailyRiskBlock()
{
  // Preserve the existing daily stop latch for an actual economic breach.
  // History validity itself is recomputed and never latched as a breach.
  if(Inp_EnableDailyRiskStop && gDailyPnLRValid &&
     dailyPnLR<=-Inp_MaxDailyLossR) gDailyRiskLimitLatched=true;
  if(Inp_EnableConsecutiveLossStop && gDailyEconomicsValid &&
     consecutiveLosses>=Inp_MaxConsecutiveLosses) gDailyRiskLimitLatched=true;
  // Match RC1.1: a persisted daily stop cannot enable disabled controls.
  dailyRiskBlocked=(gDailyRiskLimitLatched &&
    (Inp_EnableDailyRiskStop || Inp_EnableConsecutiveLossStop)) ||
    (Inp_EnableDailyRiskStop && !gDailyPnLRValid) ||
    (Inp_EnableConsecutiveLossStop && !gDailyEconomicsValid);
}

void RecoverAccountingInfrastructure()
{
  bool needsQuota=!gQuotaHistoryValid;
  bool needsEconomics=gDailyHistoryRetryRequired ||
   (gDailyEconomicsState!=ECONOMIC_ALLOCATION_IMPOSSIBLE &&
    (!gDailyEconomicsValid || !gDailyPnLRValid));
  bool needsRecords=false;
bool needsMarkers=gEMRMaintenanceNeeded || gEconomicMarkerScanUnresolved ||
gIdentityLossPersistPending ||
   gOrderObligationScanUnresolved || gOrderRegistryUnavailable ||
   gRequestJournalUnresolved || gRequestJournalWritePending ||
   gEntryJournalCleanupPending || gExitJournalCleanupPending;
for(int i=0;i<gTradeRecordCount;i++)
   if(gTradeRecords[i].economicMarkerPending ||
      gTradeRecords[i].economicMarkerCleanupPending) needsMarkers=true;
for(int i=0;i<ArraySize(gUnresolvedOrders);i++)
   if(gUnresolvedOrders[i].active && gUnresolvedOrders[i].persistencePending)
needsMarkers=true;
for(int i=0;i<gTradeRecordCount;i++)
{
   TradeRecord r=gTradeRecords[i];
   if(r.positionID>0 && !r.inoutCostsUnresolved &&
      (r.historyRefreshPending || (!r.closed && !r.accountingResolved)))
   { needsRecords=true; break; }
}
if(!needsQuota && !needsEconomics && !needsRecords && !needsMarkers &&
   !gLiveOwnershipUnresolved && !gAccountingCapacityUnresolved) return;
datetime now=TimeTradeServer();
if(gLastAccountingRecoveryTime>0 && now-gLastAccountingRecoveryTime<10) return;
gLastAccountingRecoveryTime=now;
if(gIdentityLossPersistPending) PersistInfrastructureIdentityLoss();
RecoverRequestJournals();
if(gOrderObligationScanUnresolved || gOrderRegistryUnavailable)
RestoreOrderObligations();
RecoverEconomicMarkers();
// Snapshot deferred identities because NewTrackedTrade removes each PID
// after successful allocation. Failed allocations never forget the PID.
// No snapshot allocation is necessary: iterate backwards and remove only
// the exact PID recovered by NewTrackedTrade/ForgetDeferredAccountingPID.
for(int list=0;list<2;list++)
{
   int
deferredCount=list==0?ArraySize(gDeferredAccountingPIDs):gDeferredFallbackCount;
for(int i=deferredCount-1;i>=0;i--)
{
  ulong pid=list==0?gDeferredAccountingPIDs[i]:gDeferredFallback[i];
  if(!HistorySelectByPosition(pid)) continue;
  bool own=false;
  for(int j=0;j<HistoryDealsTotal();j++)
  {
     ulong deal=HistoryDealGetTicket(j);
     if(deal>0 && HistoryDealGetString(deal,DEAL_SYMBOL)==Symbol() &&
        HistoryDealGetInteger(deal,DEAL_MAGIC)==(long)gMagicCore &&
        HistoryDealGetInteger(deal,DEAL_ENTRY)==DEAL_ENTRY_IN)
     { own=true; break; }
  }
  if(!own) continue;
   int idx=FindTrackedTrade(pid); bool existing=(idx>=0);
   if(idx<0) idx=NewTrackedTrade(pid);
   if(idx<0) continue;
   ForgetDeferredAccountingPID(pid);
   if(!existing) LoadTradeMetadata(gTradeRecords[idx]);
   if(RebuildTrackedHistory(idx,false))
   {
      SyncOpenPositionFromRecord(idx);
      TryFinalizeTrackedTrade(pid); gNeedsAccountingSync=true;
   }
 }
}
if(needsQuota)
{
   int count=CountTodayTrades();
   if(count>=0) { ordersEnteredToday=count; gQuotaHistoryValid=true; }
}
if(needsRecords)
{
   for(int i=0;i<gTradeRecordCount;i++)
 {
     TradeRecord r=gTradeRecords[i];
     if(r.positionID==0 || r.inoutCostsUnresolved ||
        !(r.historyRefreshPending || (!r.closed && !r.accountingResolved))) continue;
     if(RebuildTrackedHistory(i,false))
     { SyncOpenPositionFromRecord(i); gNeedsAccountingSync=true; }
 }
}
if(gLiveOwnershipUnresolved || gAccountingCapacityUnresolved)
   ReconstructOpenPosition(false);
// Record repair can invalidate or recover today's economics. Rebuild the
// current-day window only; never query the account from time zero here.
if(needsEconomics || needsRecords || !gDailyEconomicsValid)
   RestoreDailyEconomicsFromHistory(false);
   RecomputeDailyRiskBlock(); RecomputeAccountingBlock();
   if(gQuotaHistoryValid && gDailyEconomicsValid) PersistDailyAccounting();
}

void RecoverTradeCsvInfrastructure()
{
  if(gTradeCsvFileName=="" ||
     (csvTradeHandle!=INVALID_HANDLE && gTradeCsvIndexLoaded &&
gTradeCsvAppendSafe)) return;
  datetime now=TimeTradeServer();
  if(now<gNextTradeCsvRecovery) return;
  gNextTradeCsvRecovery=now+30;
  gTradeCsvInfrastructureUnresolved=true;
  if(!BookCsvRecoveryPathAllowed()) return;
  // Reopen the current path after unavailable I/O or external repair. Never
  // truncate/repair an existing file, and never trust metadata as CSV presence.
if(csvTradeHandle!=INVALID_HANDLE)
{ FileClose(csvTradeHandle); csvTradeHandle=INVALID_HANDLE; }
csvTradeHandle=BookCsvOpenInitialFile();
 if(csvTradeHandle==INVALID_HANDLE) return;
 ResetLastError();
 ulong size=FileSize(csvTradeHandle);
 if(GetLastError()!=0)
 { FileClose(csvTradeHandle); csvTradeHandle=INVALID_HANDLE; return; }
 if(size==0)
 {
    WriteTradeHeader();
    FileFlush(csvTradeHandle);
 }
 // Invalid schema/tail stays append-disabled. A later full successful scan
 // can recognize an authoritative external repair without destroying rows.
 if(!InitializeTradeCsvIndex(gTradeCsvFileName)) return;
 if(!FileSeek(csvTradeHandle,0,SEEK_END))
    BookCsvReject(gTradeCsvFileName,0,0,0,"RECOVERY_SEEK_FAILED");
}

void MarkTemporaryAccountingHistory()
{
  gDailyHistoryRetryRequired=true;
  gDailyEconomicsValid=false; gDailyPnLRValid=false;
  if(gDailyEconomicsState!=ECONOMIC_ALLOCATION_IMPOSSIBLE)
     gDailyEconomicsState=TEMPORARY_HISTORY_UNAVAILABLE;
}

bool ProcessAccountingDeal(ulong ticket)
{
  if(!HistoryDealSelect(ticket)) return false;
  if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=Symbol()) return true;
  long type=HistoryDealGetInteger(ticket,DEAL_TYPE);
  if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) return true;
  long entry=HistoryDealGetInteger(ticket,DEAL_ENTRY);
  ulong pid=(ulong)HistoryDealGetInteger(ticket,DEAL_POSITION_ID);
  long magic=HistoryDealGetInteger(ticket,DEAL_MAGIC);
  if(pid==0) return false;
  int idx=FindTrackedTrade(pid);
  bool ownNew=(entry==DEAL_ENTRY_IN && magic==(long)gMagicCore);
  if(idx<0 && ownNew)
  {
     idx=NewTrackedTrade(pid);
     if(idx>=0) LoadTradeMetadata(gTradeRecords[idx]);
  }
  if(idx<0 && (entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY ||
entry==DEAL_ENTRY_INOUT))
  {
     // Unavailable ownership history is not a proven foreign cycle.
     if(!HistorySelectByPosition(pid)) return false;
     bool own=false;
     for(int i=0;i<HistoryDealsTotal();i++)
     {
        ulong d=HistoryDealGetTicket(i);
        if(HistoryDealGetString(d,DEAL_SYMBOL)==Symbol() &&
           HistoryDealGetInteger(d,DEAL_MAGIC)==(long)gMagicCore &&
           HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_IN)
        { own=true; break; }
     }
     if(!own) return true;
     idx=NewTrackedTrade(pid);
     if(idx>=0)
     { LoadTradeMetadata(gTradeRecords[idx]);
gTradeRecords[idx].maeMfePartialAfterRestart=true; }
  }
  if(idx<0) return !ownNew; // Capacity failure retains own IN identity for retry.
    if(gTradeRecords[idx].closed) return true;
    if(!RebuildTrackedHistory(idx,false)) return false;
    SyncOpenPositionFromRecord(idx); TryFinalizeTrackedTrade(pid);
    return true;
}

void RememberDeferredDeal(ulong ticket)
{
  MarkTemporaryAccountingHistory();
  // Keep the exact event identity even if no position or own record is visible.
  for(int i=0;i<ArraySize(gDeferredDeals);i++) if(gDeferredDeals[i]==ticket) return;
  for(int i=0;i<gDeferredDealFallbackCount;i++) if(gDeferredDealFallback[i]==ticket) return;
  int n=ArraySize(gDeferredDeals);
  if(ArrayResize(gDeferredDeals,n+1)==n+1) gDeferredDeals[n]=ticket;
    else if(gDeferredDealFallbackCount<MAX_TRADE_RECORDS)
     gDeferredDealFallback[gDeferredDealFallbackCount++]=ticket;
    else
    {
      gDeferredDealOverflow=true;
      MarkInfrastructureIdentityLoss();
    }
}

void ReconcileDeferredDeals()
{
  for(int i=ArraySize(gDeferredDeals)-1;i>=0;i--)
   if(ProcessAccountingDeal(gDeferredDeals[i]))
    {
       int n=ArraySize(gDeferredDeals);
       for(int j=i+1;j<n;j++) gDeferredDeals[j-1]=gDeferredDeals[j];
       ArrayResize(gDeferredDeals,n-1);
     }
    for(int i=gDeferredDealFallbackCount-1;i>=0;i--)
     if(ProcessAccountingDeal(gDeferredDealFallback[i]))
     {
        for(int j=i+1;j<gDeferredDealFallbackCount;j++)
         gDeferredDealFallback[j-1]=gDeferredDealFallback[j];
        gDeferredDealFallbackCount--;
     }
}

string EconomicMarkerPrefix()
{
  return StringFormat("Scalper01_RC1_%I64d_%s_%I64d_",
   AccountInfoInteger(ACCOUNT_LOGIN),Symbol(),(long)gMagicCore);
}

string EconomicMarkerPath(ulong pid)
{ return EconomicMarkerPrefix()+(string)pid+".econ.partial"; }

string IdentityLossMarkerPath()
{ return EconomicMarkerPrefix()+"identity.loss"; }

void PersistInfrastructureIdentityLoss()
{
  string path=IdentityLossMarkerPath();
  if(FileIsExist(path)) { gIdentityLossPersistPending=false; return; }
  gIdentityLossPersistPending=true;
  int h=FileOpen(path,FILE_WRITE|FILE_TXT|FILE_ANSI);
  if(h==INVALID_HANDLE) return;
  string message="RC1_IDENTITY_EVIDENCE_LOST\r\n";
  ResetLastError();
    uint written=FileWriteString(h,message);
    bool ok=(written==(uint)StringLen(message) && GetLastError()==0);
    ResetLastError(); FileFlush(h);
    if(GetLastError()!=0) ok=false;
    FileClose(h);
    gIdentityLossPersistPending=!ok;
}

void MarkInfrastructureIdentityLoss()
{
  // If even the emergency identity registry is exhausted, restart cannot
  // prove that the forgotten evidence was resolved. Persist that obligation.
  gIdentityLossUnresolved=true;
    PersistInfrastructureIdentityLoss();
}

bool PersistEconomicMarker(ulong pid)
{
  string path=EconomicMarkerPath(pid);
  // Presence is an unresolved obligation, not proof of economic resolution.
  // Even an interrupted marker write must be rebuilt by its exact PID.
  if(FileIsExist(path)) return true;
  int h=FileOpen(path,FILE_WRITE|FILE_TXT|FILE_ANSI);
  if(h==INVALID_HANDLE) return false;
  ResetLastError();
  uint written=FileWriteString(h,"RC1_ECONOMIC_OBLIGATION\r\n");
  bool ok=(written==25 && GetLastError()==0);
  ResetLastError(); FileFlush(h);
  if(GetLastError()!=0) ok=false;
  FileClose(h);
  return ok;
}

void RestoreUnresolvedEconomicMarkers()
{
  // PID0 is a sentinel: a successful scan must find it. Thus enumeration
  // failure cannot masquerade as an empty registry and release the blocker.
  gEconomicMarkerScanUnresolved=false;
  if(!PersistEconomicMarker(0)) { gEconomicMarkerScanUnresolved=true; return; }
  string name, prefix=EconomicMarkerPrefix(), suffix=".econ.partial";
  long search=FileFindFirst(prefix+"*"+suffix,name);
  if(search==INVALID_HANDLE) { gEconomicMarkerScanUnresolved=true; return; }
  bool sentinel=false;
  ulong markerPIDs[]; int markerCount=0;
  bool more=true;
  while(more)
  {
     if(name==prefix+"0"+suffix) sentinel=true;
         else
         {
          int length=StringLen(name)-StringLen(prefix)-StringLen(suffix);
          ulong pid=0;
          if(length<=0 || StringSubstr(name,0,StringLen(prefix))!=prefix ||
             StringSubstr(name,StringLen(name)-StringLen(suffix))!=suffix ||
             !CsvParsePID(StringSubstr(name,StringLen(prefix),length),pid))
             gEconomicMarkerScanUnresolved=true;
          else if(ArrayResize(markerPIDs,markerCount+1)!=markerCount+1)
             gEconomicMarkerScanUnresolved=true;
          else markerPIDs[markerCount++]=pid;
         }
         ResetLastError();
         more=FileFindNext(search,name);
         // No guessed EOF error code: an explicit enumeration error cannot
         // certify a complete registry. Retry later rather than release it.
         if(!more && GetLastError()!=0) gEconomicMarkerScanUnresolved=true;
        }
        FileFindClose(search);
        if(!sentinel) gEconomicMarkerScanUnresolved=true;
        // Snapshot filenames before rebuild can remove an authoritatively resolved marker.
        for(int i=0;i<markerCount;i++)
        {
           ulong pid=markerPIDs[i];
           int idx=FindTrackedTrade(pid); bool existing=(idx>=0);
           if(idx<0) idx=NewTrackedTrade(pid);
           if(idx<0) { gEconomicMarkerScanUnresolved=true; continue; }
           if(!existing) LoadTradeMetadata(gTradeRecords[idx]);
           gTradeRecords[idx].economicMarkerPending=true;
           if(!RebuildTrackedHistory(idx,false))
           { gEconomicMarkerScanUnresolved=true; continue; }
           if(!gTradeRecords[idx].volumeClosedComplete)
           {
              gTradeRecords[idx].historyRefreshPending=true;
           MarkTemporaryAccountingHistory();
          }
          TryFinalizeTrackedTrade(pid);
    }
}

void SyncEconomicMarker(int idx)
{
  TradeRecord r=gTradeRecords[idx];
  // A prior administrative classification is invalidated by any fresh rebuild.
  if(r.economicMarkerCleanupPending) gTradeRecords[idx].economicMarkerPending=true;
  if(r.inoutCostsUnresolved || (r.totalVolumeIn>0 &&
     (!r.closed || !r.finalizationWritten)))
  {
  gTradeRecords[idx].economicMarkerCleanupPending=false;
  bool durableIdentity=PersistEconomicMarker(r.positionID);
  // Persisting an obligation is not proof that its finalization is durable.
  gTradeRecords[idx].economicMarkerPending=!durableIdentity ||
     r.inoutCostsUnresolved || (r.closed && !r.finalizationWritten);
  }
  else if(r.closed && r.finalizationWritten && r.accountingResolved &&
    r.volumeClosedComplete)
  {
    // Never remove the durable PID while its own reconstruction is uncertain.
    if(r.historyRefreshPending || r.breakEvenClassificationPending ||
       r.be.stage==BE_REQUEST_PENDING || r.be.stage==BE_ACKNOWLEDGED ||
       r.be.stage==BE_UNRESOLVED)
    {
       gTradeRecords[idx].economicMarkerPending=true;
       if(!PersistEconomicMarker(r.positionID)) gEconomicMarkerScanUnresolved=true;
       return;
    }
    string path=EconomicMarkerPath(r.positionID);
    ResetLastError(); bool present=FileIsExist(path);
    int probeError=GetLastError();
    if(!present && probeError!=0)
    {
       bool confirmed=false;
       if(EMRProbeMarker(r.positionID,confirmed))
       { present=confirmed; probeError=0; }
    }
    bool removed=false;
    int error=probeError;
    if(present)
    {
       ResetLastError(); removed=FileDelete(path);
       error=GetLastError();
    }
    if((present && !removed) || (!present && probeError!=0) ||
       (!present && r.economicMarkerCleanupPending))
    {
       gTradeRecords[idx].economicMarkerPending=true;
       gTradeRecords[idx].economicMarkerCleanupPending=true;
       gTradeRecords[idx].economicMarkerDeleteError=error;
       if(!r.economicMarkerCleanupPending || r.economicMarkerDeleteError!=error)
          PrintFormat("[SCALPER][ECONOMIC_MARKER_CLEANUP_FAILED] pid=%I64u file=%s error=%d; authoritative resolution proof required; evidence retained.",
             r.positionID,path,error);
    }
    else
    {
       gTradeRecords[idx].economicMarkerPending=false;
            gTradeRecords[idx].economicMarkerCleanupPending=false;
            gTradeRecords[idx].economicMarkerDeleteError=0;
        }
    }
}

void RecoverEconomicMarkers()
{
  if(gEconomicMarkerScanUnresolved) RestoreUnresolvedEconomicMarkers();
  for(int i=0;i<gTradeRecordCount;i++)
  {
     if(!gTradeRecords[i].economicMarkerPending &&
        !gTradeRecords[i].economicMarkerCleanupPending) continue;
     if(gTradeRecords[i].closed && gTradeRecords[i].finalizationWritten)
        EMRRecoverRecord(i);
     else SyncEconomicMarker(i);
  }
  EMRMaintainArchivedCleanup();
  EMRReleaseArchivedRecords();
}

// Economic-marker certification only; this does not authorize an order.
// Mixed/reversal/INOUT histories are deliberately outside this administrative
// exception. Their original economic and ownership protections remain active.
#define EMR_MAX_HISTORY_DEALS 4096
#define EMR_MAX_HISTORY_ORDERS 512
#define EMR_MAX_LIVE_ITEMS 4096

struct EMRDealSnapshot
{
   ulong ticket, order;
   long timeMSC, timeSec, magic, type, entry;
   double volume, price, profit, commission, fee, swap;
};
struct EMROrderSnapshot
{
   ulong ticket, pid, by;
   long state, type, magic, setupMSC, doneMSC;
   double initial, remaining, sl, tp, dealVolume, entryVolume, exitVolume;
};

bool EMRDealI(ulong ticket,ENUM_DEAL_PROPERTY_INTEGER property,long &value)
{
  ResetLastError();
  return HistoryDealGetInteger(ticket,property,value) && GetLastError()==0;
}
bool EMRDealD(ulong ticket,ENUM_DEAL_PROPERTY_DOUBLE property,double &value)
{
 ResetLastError();
 return HistoryDealGetDouble(ticket,property,value) && GetLastError()==0 &&
 MathIsValidNumber(value) && value!=EMPTY_VALUE;
}
bool EMRDealS(ulong ticket,ENUM_DEAL_PROPERTY_STRING property,string &value)
{
   ResetLastError();
   return HistoryDealGetString(ticket,property,value) && GetLastError()==0;
}
bool EMROrderI(ulong ticket,ENUM_ORDER_PROPERTY_INTEGER property,long &value)
{
   ResetLastError();
   return HistoryOrderGetInteger(ticket,property,value) && GetLastError()==0;
}
bool EMROrderD(ulong ticket,ENUM_ORDER_PROPERTY_DOUBLE property,double
&value)
{
   ResetLastError();
   return HistoryOrderGetDouble(ticket,property,value) && GetLastError()==0 &&
    MathIsValidNumber(value) && value!=EMPTY_VALUE;
}
bool EMROrderS(ulong ticket,ENUM_ORDER_PROPERTY_STRING property,string &value)
{
   ResetLastError();
   return HistoryOrderGetString(ticket,property,value) && GetLastError()==0;
}
bool EMRFinite(double value)
{ return MathIsValidNumber(value) && value!=EMPTY_VALUE; }
bool EMRNear(double first,double second,double tolerance)
{
   return EMRFinite(first) && EMRFinite(second) &&
    MathAbs(first-second)<=MathMax(tolerance,
     MathMax(MathAbs(first),MathAbs(second))*1e-11);
}
string EMRD(double value) { return DoubleToString(value,16); }

bool EMRReadDeal(ulong ticket,ulong positionID,EMRDealSnapshot &d)
{
  string symbol; long pid, order;
  d.ticket=ticket;
  if(ticket==0 || !EMRDealS(ticket,DEAL_SYMBOL,symbol) || symbol!=Symbol() ||
     !EMRDealI(ticket,DEAL_POSITION_ID,pid) || (ulong)pid!=positionID ||
     !EMRDealI(ticket,DEAL_ORDER,order) || order<=0 ||
     !EMRDealI(ticket,DEAL_TIME_MSC,d.timeMSC) || d.timeMSC<=0 ||
     !EMRDealI(ticket,DEAL_TIME,d.timeSec) || d.timeSec<=0 ||
     d.timeMSC/1000!=d.timeSec ||
     !EMRDealI(ticket,DEAL_MAGIC,d.magic) ||
     !EMRDealI(ticket,DEAL_TYPE,d.type) ||
      (d.type!=DEAL_TYPE_BUY && d.type!=DEAL_TYPE_SELL) ||
      !EMRDealI(ticket,DEAL_ENTRY,d.entry) ||
     (d.entry!=DEAL_ENTRY_IN && d.entry!=DEAL_ENTRY_OUT &&
      d.entry!=DEAL_ENTRY_OUT_BY) ||
     !EMRDealD(ticket,DEAL_VOLUME,d.volume) || d.volume<=0 ||
     !EMRDealD(ticket,DEAL_PRICE,d.price) || d.price<=0 ||
     !EMRDealD(ticket,DEAL_PROFIT,d.profit) ||
     !EMRDealD(ticket,DEAL_COMMISSION,d.commission) ||
     !EMRDealD(ticket,DEAL_FEE,d.fee) ||
     !EMRDealD(ticket,DEAL_SWAP,d.swap)) return false;
    d.order=(ulong)order;
    return d.entry!=DEAL_ENTRY_IN || d.magic==(long)gMagicCore;
}

string EMRDealEvidence(const EMRDealSnapshot &d)
{
  return (string)d.ticket+"|"+(string)d.order+"|"+(string)d.timeMSC+"|"+
   (string)d.timeSec+"|"+(string)d.magic+"|"+(string)d.type+"|"+
   (string)d.entry+"|"+EMRD(d.volume)+"|"+EMRD(d.price)+"|"+
   EMRD(d.profit)+"|"+EMRD(d.commission)+"|"+EMRD(d.fee)+"|"+EMRD(d.swap);
}

bool EMRReadOrder(ulong ticket,ulong positionID,EMROrderSnapshot &o)
{
  string symbol; long pid, by;
  ZeroMemory(o); o.ticket=ticket;
  if(ticket==0 || !EMROrderS(ticket,ORDER_SYMBOL,symbol) || symbol!=Symbol() ||
     !EMROrderI(ticket,ORDER_POSITION_ID,pid) || pid<0 ||
     !EMROrderI(ticket,ORDER_POSITION_BY_ID,by) || by<0 ||
     ((ulong)pid!=positionID && (ulong)by!=positionID) ||
     !EMROrderI(ticket,ORDER_STATE,o.state) ||
     (o.state!=ORDER_STATE_FILLED && o.state!=ORDER_STATE_CANCELED &&
      o.state!=ORDER_STATE_REJECTED && o.state!=ORDER_STATE_EXPIRED) ||
     !EMROrderI(ticket,ORDER_TYPE,o.type) ||
      (o.type!=ORDER_TYPE_BUY && o.type!=ORDER_TYPE_SELL &&
       o.type!=ORDER_TYPE_CLOSE_BY) ||
      !EMROrderI(ticket,ORDER_MAGIC,o.magic) ||
      !EMROrderI(ticket,ORDER_TIME_SETUP_MSC,o.setupMSC) || o.setupMSC<=0 ||
      !EMROrderI(ticket,ORDER_TIME_DONE_MSC,o.doneMSC) || o.doneMSC<=0 ||
      o.doneMSC<o.setupMSC ||
      !EMROrderD(ticket,ORDER_VOLUME_INITIAL,o.initial) || o.initial<=0 ||
      !EMROrderD(ticket,ORDER_VOLUME_CURRENT,o.remaining) || o.remaining<0 ||
      !EMROrderD(ticket,ORDER_SL,o.sl) || o.sl<0 ||
      !EMROrderD(ticket,ORDER_TP,o.tp) || o.tp<0) return false;
    o.pid=(ulong)pid; o.by=(ulong)by;
    return true;
}
string EMROrderEvidence(const EMROrderSnapshot &o)
{
  return (string)o.ticket+"|"+(string)o.pid+"|"+(string)o.by+"|"+
    (string)o.state+"|"+(string)o.type+"|"+(string)o.magic+"|"+
    (string)o.setupMSC+"|"+(string)o.doneMSC+"|"+EMRD(o.initial)+"|"+
    EMRD(o.remaining)+"|"+EMRD(o.sl)+"|"+EMRD(o.tp);
}

bool EMRConnected()
{
  ResetLastError();
  long connected=TerminalInfoInteger(TERMINAL_CONNECTED);
  return connected!=0 && GetLastError()==0;
}

// All selections must succeed, including foreign items. Foreign Hedging
// positions/orders with another PID and Magic are independent and permitted.
bool EMRStrictLiveSnapshot(ulong positionID)
{
   ResetLastError(); int positions=PositionsTotal();
   if(GetLastError()!=0 || positions<0 || positions>EMR_MAX_LIVE_ITEMS) return false;
   ResetLastError(); int orders=OrdersTotal();
   if(GetLastError()!=0 || orders<0 || orders>EMR_MAX_LIVE_ITEMS) return false;
   ulong positionTickets[],orderTickets[];
   if(ArrayResize(positionTickets,positions)!=positions ||
      ArrayResize(orderTickets,orders)!=orders) return false;
   for(int i=0;i<positions;i++)
   {
      ResetLastError(); ulong ticket=PositionGetTicket(i);
      if(ticket==0 || GetLastError()!=0) return false;
      positionTickets[i]=ticket;
      string symbol; long pid,magic; double volume;
      ResetLastError();
      if(!PositionGetString(POSITION_SYMBOL,symbol) || GetLastError()!=0) return false;
     ResetLastError();
     if(!PositionGetInteger(POSITION_IDENTIFIER,pid) || GetLastError()!=0 || pid<=0)
        return false;
     ResetLastError();
     if(!PositionGetInteger(POSITION_MAGIC,magic) || GetLastError()!=0) return false;
     ResetLastError();
     if(!PositionGetDouble(POSITION_VOLUME,volume) || GetLastError()!=0 ||
        !EMRFinite(volume) || volume<=0) return false;
     if(symbol==Symbol() && (ulong)pid==positionID) return false;
    }
    for(int i=0;i<orders;i++)
    {
       ResetLastError(); ulong ticket=OrderGetTicket(i);
       if(ticket==0 || GetLastError()!=0) return false;
      orderTickets[i]=ticket;
      string symbol; long magic,pid,by;
      ResetLastError();
     if(!OrderGetString(ORDER_SYMBOL,symbol) || GetLastError()!=0) return false;
     ResetLastError();
     if(!OrderGetInteger(ORDER_MAGIC,magic) || GetLastError()!=0) return false;
     ResetLastError();
     if(!OrderGetInteger(ORDER_POSITION_ID,pid) || GetLastError()!=0 || pid<0)
        return false;
     ResetLastError();
     if(!OrderGetInteger(ORDER_POSITION_BY_ID,by) || GetLastError()!=0 || by<0)
        return false;
     if(symbol==Symbol() && (magic==(long)gMagicCore ||
        (ulong)pid==positionID || (ulong)by==positionID)) return false;
    }
    ResetLastError(); int positionsAfter=PositionsTotal();
    if(GetLastError()!=0 || positionsAfter!=positions) return false;
    ResetLastError(); int ordersAfter=OrdersTotal();
    if(GetLastError()!=0 || ordersAfter!=orders) return false;
    for(int i=0;i<positions;i++)
    {
       ResetLastError(); ulong ticket=PositionGetTicket(i);
       if(GetLastError()!=0 || ticket!=positionTickets[i]) return false;
    }
    for(int i=0;i<orders;i++)
    {
       ResetLastError(); ulong ticket=OrderGetTicket(i);
       if(GetLastError()!=0 || ticket!=orderTickets[i]) return false;
    }
    return true;
}

bool EMRStrictSnapshot(const TradeRecord &r,string &evidence)
{
evidence="";
if(r.positionID==0 || !EMRConnected()) return false;
ResetLastError(); long account=AccountInfoInteger(ACCOUNT_LOGIN);
if(GetLastError()!=0 || account<=0) return false;
ResetLastError(); string server=AccountInfoString(ACCOUNT_SERVER);
if(GetLastError()!=0 || server=="") return false;
ResetLastError();
if(!HistorySelectByPosition(r.positionID) || GetLastError()!=0) return false;
ResetLastError(); int dealCount=HistoryDealsTotal();
if(GetLastError()!=0 || dealCount<=0 || dealCount>EMR_MAX_HISTORY_DEALS)
   return false;
ResetLastError(); int orderCount=HistoryOrdersTotal();
if(GetLastError()!=0 || orderCount<=0 || orderCount>EMR_MAX_HISTORY_ORDERS)
   return false;
EMRDealSnapshot deals[]; EMROrderSnapshot historyOrders[];
ulong dealTickets[],historyOrderTickets[];
if(ArrayResize(deals,dealCount)!=dealCount ||
   ArrayResize(historyOrders,orderCount)!=orderCount ||
   ArrayResize(dealTickets,dealCount)!=dealCount ||
   ArrayResize(historyOrderTickets,orderCount)!=orderCount) return false;
for(int i=0;i<dealCount;i++)
{
   ResetLastError(); ulong ticket=HistoryDealGetTicket(i);
   if(ticket==0 || GetLastError()!=0) return false;
   dealTickets[i]=ticket;
   if(!EMRReadDeal(ticket,r.positionID,deals[i])) return false;
}
for(int i=0;i<orderCount;i++)
{
   ResetLastError(); ulong ticket=HistoryOrderGetTicket(i);
   if(ticket==0 || GetLastError()!=0) return false;
   historyOrderTickets[i]=ticket;
   if(!EMRReadOrder(ticket,r.positionID,historyOrders[i])) return false;
}
// Independent ordering makes the receipt deterministic across terminal restarts.
for(int i=1;i<dealCount;i++)
{
   EMRDealSnapshot value=deals[i]; int j=i-1;
   while(j>=0 && (deals[j].timeMSC>value.timeMSC ||
      (deals[j].timeMSC==value.timeMSC && deals[j].ticket>value.ticket)))
   { deals[j+1]=deals[j]; j--; }
   deals[j+1]=value;
}
for(int i=1;i<orderCount;i++)
{
   EMROrderSnapshot value=historyOrders[i]; int j=i-1;
   while(j>=0 && historyOrders[j].ticket>value.ticket)
   { historyOrders[j+1]=historyOrders[j]; j--; }
 historyOrders[j+1]=value;
}
for(int i=1;i<dealCount;i++)
   if(deals[i-1].ticket==deals[i].ticket) return false;
for(int i=1;i<orderCount;i++)
   if(historyOrders[i-1].ticket==historyOrders[i].ticket) return false;
double tolerance=AccountingVolumeTolerance();
if(!EMRFinite(tolerance) || tolerance<=0) return false;
double volumeIn=0,volumeOut=0,entryMean=0,exitMean=0;
double gross=0,commission=0,fee=0,swap=0;
long firstEntryTime=0,lastExitTime=0,lastExitMSC=0;
ulong firstEntryOrder=0,lastExitDeal=0;
int direction=0;
bool ownStarted=false,ownFinished=false;
string dealDigest="EMR_DEALS_V1",orderDigest="EMR_ORDERS_V1";
for(int i=0;i<dealCount;i++)
{
 EMRDealSnapshot d=deals[i]; int index=-1;
 for(int j=0;j<orderCount;j++)
    if(historyOrders[j].ticket==d.order) { index=j; break; }
 if(index<0 || historyOrders[index].magic!=d.magic ||
    d.timeMSC<historyOrders[index].setupMSC ||
    d.timeMSC>historyOrders[index].doneMSC) return false;
 if((historyOrders[index].type==ORDER_TYPE_BUY && d.type!=DEAL_TYPE_BUY) ||
    (historyOrders[index].type==ORDER_TYPE_SELL && d.type!=DEAL_TYPE_SELL))
    return false;
 int dealDirection=(d.type==DEAL_TYPE_BUY?1:-1);
 historyOrders[index].dealVolume+=d.volume;
 if(d.entry==DEAL_ENTRY_IN)
 {
    if(ownFinished || historyOrders[index].type==ORDER_TYPE_CLOSE_BY ||
       historyOrders[index].magic!=(long)gMagicCore) return false;
    if(!ownStarted)
    {
       ownStarted=true; direction=dealDirection;
       firstEntryTime=d.timeSec; firstEntryOrder=d.order;
    }
    if(dealDirection!=direction) return false;
    entryMean=(entryMean*volumeIn+d.price*d.volume)/(volumeIn+d.volume);
    volumeIn+=d.volume;
    historyOrders[index].entryVolume+=d.volume;
 }
 else
 {
    if(!ownStarted || ownFinished || dealDirection==direction ||
       d.volume>volumeIn-volumeOut+tolerance) return false;
    exitMean=(exitMean*volumeOut+d.price*d.volume)/(volumeOut+d.volume);
    volumeOut+=d.volume;
 historyOrders[index].exitVolume+=d.volume;
 lastExitTime=d.timeSec; lastExitMSC=d.timeMSC; lastExitDeal=d.ticket;
 if(volumeIn-volumeOut<=tolerance) ownFinished=true;
 }
 gross+=d.profit; commission+=d.commission; fee+=d.fee; swap+=d.swap;
 if(!EMRFinite(volumeIn) || !EMRFinite(volumeOut) || !EMRFinite(entryMean) ||
    !EMRFinite(exitMean) || !EMRFinite(gross) || !EMRFinite(commission) ||
    !EMRFinite(fee) || !EMRFinite(swap)) return false;
 dealDigest=RJChecksum(dealDigest+"|"+EMRDealEvidence(d));
}
if(!ownStarted || !ownFinished || volumeIn<=tolerance ||
   !EMRNear(volumeIn,volumeOut,tolerance)) return false;
bool entryOrderProven=false;
for(int i=0;i<orderCount;i++)
{
    EMROrderSnapshot o=historyOrders[i];
    double filled=o.initial-o.remaining;
  if(filled < -tolerance || !EMRNear(filled,o.dealVolume,tolerance) ||
     (o.state==ORDER_STATE_FILLED && o.remaining>tolerance) ||
     (o.entryVolume>tolerance && o.exitVolume>tolerance)) return false;
  if(o.entryVolume>tolerance &&
     (!EMRNear(o.sl,r.slPrice,1e-8) || !EMRNear(o.tp,r.tpPrice,1e-8)))
     return false;
  if(o.ticket==firstEntryOrder && o.ticket==r.entryOrderTicket)
  {
     if(r.expectedEntryVolume<=0 ||
         (!EMRNear(r.expectedEntryVolume,o.initial,tolerance) &&
          !EMRNear(r.expectedEntryVolume,filled,tolerance))) return false;
     entryOrderProven=true;
  }
  orderDigest=RJChecksum(orderDigest+"|"+EMROrderEvidence(o));
}
double net=gross+commission+fee+swap;
if(!entryOrderProven || direction!=r.direction ||
   firstEntryTime!=(long)r.entryTime || lastExitTime!=(long)r.exitTime ||
   lastExitMSC!=r.exitTimeMSC || lastExitDeal!=r.lastExitDealTicket ||
   !EMRNear(volumeIn,r.totalVolumeIn,tolerance) ||
   !EMRNear(volumeOut,r.totalVolumeOut,tolerance) ||
   !EMRNear(volumeIn,r.volume,tolerance) ||
   !EMRNear(entryMean,r.weightedEntryPrice,1e-8) ||
   !EMRNear(exitMean,r.weightedExitPrice,1e-8) ||
   !EMRNear(entryMean,r.entryPrice,1e-8) ||
   !EMRNear(exitMean,r.exitPrice,1e-8) ||
   !EMRNear(gross,r.grossProfit,1e-8) ||
   !EMRNear(commission,r.commission,1e-8) ||
   !EMRNear(fee,r.fee,1e-8) || !EMRNear(swap,r.swap,1e-8) ||
   !EMRNear(net,r.netProfit,1e-8)) return false;
if(r.riskValid)
{
    if(!r.initialStopsProven || r.slPrice<=0 || r.initialRiskMoney<=0 ||
       (double)direction*(entryMean-r.slPrice)<=0) return false;
    double initialProfit=0;
    ResetLastError();
    if(!OrderCalcProfit(direction==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL,Symbol(),
       volumeIn,entryMean,r.slPrice,initialProfit) || GetLastError()!=0 ||
       !EMRFinite(initialProfit) || initialProfit>=0 ||
       !EMRNear(-initialProfit,r.initialRiskMoney,1e-8)) return false;
    if(!r.pnlRValid || !EMRNear(net/r.initialRiskMoney,r.PnL_R,1e-8)) return false;
}
else if(r.pnlRValid || r.initialRiskMoney!=0) return false;
// The selected history must remain identical across a second fresh selection.
// No HistoryOrderSelect/HistoryDealSelect is used: those truncate selection lists.
ResetLastError();
if(!HistorySelectByPosition(r.positionID) || GetLastError()!=0) return false;
ResetLastError(); int dealsAfter=HistoryDealsTotal();
if(GetLastError()!=0 || dealsAfter!=dealCount) return false;
ResetLastError(); int historyOrdersAfter=HistoryOrdersTotal();
if(GetLastError()!=0 || historyOrdersAfter!=orderCount) return false;
for(int i=0;i<dealCount;i++)
{
   ResetLastError(); ulong ticket=HistoryDealGetTicket(i);
   if(GetLastError()!=0 || ticket!=dealTickets[i]) return false;
}
for(int i=0;i<orderCount;i++)
{
   ResetLastError(); ulong ticket=HistoryOrderGetTicket(i);
   if(GetLastError()!=0 || ticket!=historyOrderTickets[i]) return false;
}
for(int i=0;i<dealCount;i++)
{
   EMRDealSnapshot again;
   if(!EMRReadDeal(deals[i].ticket,r.positionID,again) ||
      EMRDealEvidence(again)!=EMRDealEvidence(deals[i])) return false;
}
for(int i=0;i<orderCount;i++)
{
   EMROrderSnapshot again;
   if(!EMRReadOrder(historyOrders[i].ticket,r.positionID,again) ||
      EMROrderEvidence(again)!=EMROrderEvidence(historyOrders[i])) return false;
}
if(!EMRStrictLiveSnapshot(r.positionID) || !EMRConnected()) return false;
ResetLastError(); long accountAfter=AccountInfoInteger(ACCOUNT_LOGIN);
if(GetLastError()!=0 || accountAfter!=account) return false;
ResetLastError(); string serverAfter=AccountInfoString(ACCOUNT_SERVER);
if(GetLastError()!=0 || serverAfter!=server) return false;
evidence="EMR_STRICT_SNAPSHOT_V1|"+(string)account+"|"+RJEncode(server)+"|"+
   RJEncode(Symbol())+"|"+(string)(ulong)gMagicCore+"|"+(string)r.positionID+"|"+
   (string)direction+"|"+(string)firstEntryOrder+"|"+(string)firstEntryTime+"|"+
   (string)lastExitTime+"|"+(string)lastExitMSC+"|"+(string)lastExitDeal+"|"+

EMRD(volumeIn)+"|"+EMRD(volumeOut)+"|"+EMRD(entryMean)+"|"+EMRD(exitMean)+"|"+

EMRD(gross)+"|"+EMRD(commission)+"|"+EMRD(fee)+"|"+EMRD(swap)+"|"+EMRD(net)+"|"
+
  EMRD(r.slPrice)+"|"+EMRD(r.tpPrice)+"|"+EMRD(r.expectedEntryVolume)+"|"+
  (string)(int)r.riskValid+"|"+EMRD(r.initialRiskMoney)+"|"+
  (string)(int)r.pnlRValid+"|"+(r.pnlRValid?EMRD(r.PnL_R):"NA")+"|"+
  (string)(int)r.breakEvenExit+"|"+(string)(int)r.breakEvenClassificationPending+"|"+
  (string)r.be.stage+"|"+(string)(int)r.be.durable+"|"+
  (string)r.be.confirmedMSC+"|"+EMRD(r.be.price)+"|"+
    (string)dealCount+"|"+(string)orderCount+"|"+dealDigest+"|"+orderDigest;
   return true;
}
// EMR storage only. A receipt never replaces fresh authoritative economic proof.
string EMRResolutionPath(ulong pid)
{ return EconomicMarkerPrefix()+(string)pid+".econ.resolved"; }

bool EMRHasSuffix(string value,string suffix)
{
  int offset=StringLen(value)-StringLen(suffix);
  return offset>=0 && StringSubstr(value,offset)==suffix;
}

bool EMRNamePID(string tail,string suffix,ulong &pid)
{
  pid=0;
  int count=StringLen(tail)-StringLen(suffix);
  if(count<=0 || !EMRHasSuffix(tail,suffix)) return false;
  string digits=StringSubstr(tail,0,count);
  return CsvParsePID(digits,pid) && digits==(string)pid;
}

// FileIsExist(false) with an error is not proof of absence. Confirm the exact
// namespace through a complete enumeration containing the positive sentinel.
bool EMRProbeMarker(ulong pid,bool &present)
{
   present=false;
   if(pid==0 || !PersistEconomicMarker(0)) return false;
   string prefix=EconomicMarkerPrefix(),suffix=".econ.partial",name;
   ResetLastError(); long search=FileFindFirst(prefix+"*"+suffix,name);
   if(search==INVALID_HANDLE || GetLastError()!=0)
   {
      if(search!=INVALID_HANDLE) FileFindClose(search);
     return false;
    }
    bool more=true,sentinel=false,ok=true;
    int visited=0;
    while(more)
    {
       if(++visited>100000) { ok=false; break; }
       if(name==EconomicMarkerPath(0)) sentinel=true;
       else
       {
          ulong found=0;
          if(StringSubstr(name,0,StringLen(prefix))!=prefix ||
             !EMRNamePID(StringSubstr(name,StringLen(prefix)),suffix,found))
          { ok=false; break; }
       if(found==pid) present=true;
     }
     ResetLastError(); more=FileFindNext(search,name);
     if(!more && GetLastError()!=0) ok=false;
    }
    ResetLastError(); FileFindClose(search);
    if(GetLastError()!=0) ok=false;
    return ok && sentinel && !more;
}

bool EMRInspectFiles(ulong pid,bool &markerPresent,bool &receiptPresent,bool
&bePresent)
{
  markerPresent=false; receiptPresent=false; bePresent=false;
  if(pid==0 || !PersistEconomicMarker(0)) return false;
  string prefix=EconomicMarkerPrefix(),name;
  ResetLastError();
  long search=FileFindFirst(prefix+"*",name);
  if(search==INVALID_HANDLE || GetLastError()!=0)
  {
     if(search!=INVALID_HANDLE) FileFindClose(search);
     return false;
  }
  bool sentinel=false,ok=true,more=true;
  int visited=0;
  while(more)
  {
     if(++visited>100000 || StringSubstr(name,0,StringLen(prefix))!=prefix)
     { ok=false; break; }
     string tail=StringSubstr(name,StringLen(prefix));
     ulong foundPID=0;
     if(name==EconomicMarkerPath(0)) sentinel=true;
     else if(tail=="identity.loss" || tail=="request.entry.intent" ||
           tail=="request.exit.intent")
     { ok=false; break; }
     else if(tail=="0.order.unresolved") { /* Existing registry sentinel only. */ }
     else if(EMRNamePID(tail,".order.unresolved",foundPID))
     { ok=false; break; } // Includes other PIDs: request/order cleanup is unchanged.
     else if(EMRNamePID(tail,".econ.partial",foundPID))
     { if(foundPID==pid) markerPresent=true; }
     else if(EMRNamePID(tail,".econ.resolved",foundPID))
     { if(foundPID==pid) receiptPresent=true; }
     else if(EMRNamePID(tail,".meta.csv.be.journal",foundPID))
     { if(foundPID==pid) bePresent=true; }
     else if(!EMRNamePID(tail,".meta.csv",foundPID))
     { ok=false; break; } // Malformed/truncated same-identity evidence is ambiguous.
     ResetLastError();
     more=FileFindNext(search,name);
     if(!more && GetLastError()!=0) ok=false;
    }
    ResetLastError(); FileFindClose(search);
    if(GetLastError()!=0) ok=false;
    return ok && sentinel && !more;
}

bool EMRPayloadBytes(string payload,uchar &bytes[])
{
  int length=StringLen(payload);
  if(length<=0 || length>16384) return false;
  for(int i=0;i<length;i++)
  {
     ushort c=StringGetCharacter(payload,i);
     if(c>126 || (c<32 && c!=13 && c!=10)) return false;
  }
  int encoded=StringToCharArray(payload,bytes,0,WHOLE_ARRAY,CP_UTF8);
  if(encoded!=length+1 || ArraySize(bytes)!=encoded || bytes[encoded-1]!=0)
     return false;
  return ArrayResize(bytes,encoded-1)==length;
}

bool EMRReadExact(string path,string payload)
{
  uchar expected[];
  if(!EMRPayloadBytes(payload,expected)) return false;
  ResetLastError();
  int h=FileOpen(path,FILE_READ|FILE_BIN);
  if(h==INVALID_HANDLE) return false;
  bool ok=(GetLastError()==0);
  ResetLastError(); ulong size=FileSize(h);
  if(GetLastError()!=0 || size==0 || size>16384 || size!=(ulong)ArraySize(expected))
     ok=false;
  uchar actual[];
    int count=ArraySize(expected);
    if(ok && ArrayResize(actual,count)!=count) ok=false;
    if(ok)
    {
       ResetLastError(); uint got=FileReadArray(h,actual,0,count);
       if(got!=(uint)count || GetLastError()!=0) ok=false;
    }
    if(ok)
       for(int i=0;i<count;i++)
          if(actual[i]!=expected[i]) { ok=false; break; }
    ResetLastError(); ulong finalSize=FileSize(h);
    if(GetLastError()!=0 || finalSize!=size) ok=false;
    ResetLastError(); FileClose(h);
    if(GetLastError()!=0) ok=false;
    return ok;
}
bool EMRConfirmExisting(string path,string payload)
{
  if(!EMRReadExact(path,payload)) return false;
  ResetLastError();
  int h=FileOpen(path,FILE_READ|FILE_WRITE|FILE_BIN);
  if(h==INVALID_HANDLE) return false;
  bool ok=(GetLastError()==0);
  ResetLastError(); FileFlush(h);
  if(GetLastError()!=0) ok=false;
  ResetLastError(); FileClose(h);
  if(GetLastError()!=0) ok=false;
  return ok && EMRReadExact(path,payload);
}

bool EMRCommitResolution(ulong pid,string evidence)
{
  if(pid==0 || StringLen(evidence)==0 || StringLen(evidence)>16300) return false;
  // Canonical evidence is printable ASCII; symbol/route text must be RJEncode'd.
  for(int i=0;i<StringLen(evidence);i++)
  {
     ushort c=StringGetCharacter(evidence,i);
     if(c<32 || c>126) return false;
  }
  string prefix="SCALPER_EMR1|"+evidence;
  string payload=prefix+"|"+(string)BEChecksum(prefix)+"|COMPLETE_EMR1\r\n";
  uchar expected[];
  if(!EMRPayloadBytes(payload,expected)) return false;
  bool markerPresent=false,receiptPresent=false,bePresent=false;
  if(!EMRInspectFiles(pid,markerPresent,receiptPresent,bePresent)) return false;
  string path=EMRResolutionPath(pid);
  // Existing invalid, partial or different evidence is never overwritten.
    if(receiptPresent) return EMRConfirmExisting(path,payload);
    // READ|WRITE preserves an existing file if another writer appeared after
    // enumeration. Never use WRITE-only truncation or delete/rename evidence.
    ResetLastError();
    int h=FileOpen(path,FILE_READ|FILE_WRITE|FILE_BIN);
    if(h==INVALID_HANDLE) return false;
    bool ok=(GetLastError()==0);
    ResetLastError(); ulong size=FileSize(h);
    if(GetLastError()!=0) ok=false;
    if(ok && size>0)
    {
       ResetLastError(); FileClose(h);
       if(GetLastError()!=0) return false;
       return EMRConfirmExisting(path,payload);
    }
    if(ok)
    {
     ResetLastError(); uint written=FileWriteArray(h,expected,0,ArraySize(expected));
     if(written!=(uint)ArraySize(expected) || GetLastError()!=0) ok=false;
     ResetLastError(); FileFlush(h);
     if(GetLastError()!=0) ok=false;
     ResetLastError(); ulong writtenSize=FileSize(h);
     if(GetLastError()!=0 || writtenSize!=(ulong)ArraySize(expected)) ok=false;
    }
    ResetLastError(); FileClose(h);
    if(GetLastError()!=0) ok=false;
    return ok && EMRReadExact(path,payload);
}

// Only failed economic-marker cleanup uses this proof. No strategy gate is added.
bool EMRReady(const TradeRecord &r)
{
   if(r.positionID==0 || !r.closed || !r.finalizationWritten || !r.accountingResolved ||
      !r.volumeClosedComplete || !r.volumeOwnershipResolved || r.historyRefreshPending ||
      r.inoutCostsUnresolved || r.residualForeignDetected || r.breakEvenClassificationPending
||
      !r.riskValid || !r.pnlRValid || !r.initialStopsProven ||
      r.be.stage==BE_REQUEST_PENDING || r.be.stage==BE_ACKNOWLEDGED ||
      r.be.stage==BE_UNRESOLVED) return false;
   if(r.exitTime>=AccountingDayStart() && !r.dailyApplied) return false;
   if(gPendingExec.active || gPendingExit.active || gPendingOrderClassificationUnresolved ||
      !gQuotaHistoryValid || gLiveOwnershipUnresolved || gAccountingCapacityUnresolved ||
      gMultipleOwnOrdersActive || gOrderRegistryUnavailable ||
gOrderObligationScanUnresolved ||
      !gDailyEconomicsValid || !gDailyPnLRValid || gDailyHistoryRetryRequired ||
      gEconomicMarkerScanUnresolved || gIdentityLossUnresolved ||
gIdentityLossPersistPending ||
      gRequestJournalUnresolved || gRequestJournalWritePending ||
      gEntryJournalCleanupPending || gExitJournalCleanupPending ||
      gEntryJournalInvalid || gExitJournalInvalid || gEntryJournalWritePending ||
      gExitJournalWritePending || gDeferredRegistryUnavailable ||
      ArraySize(gDeferredAccountingPIDs)>0 || ArraySize(gDeferredDeals)>0 ||
      gDeferredDealFallbackCount>0 || gDeferredDealOverflow) return false;
    for(int i=0;i<ArraySize(gUnresolvedOrders);i++)
      if(gUnresolvedOrders[i].active) return false;
    return true;
}

bool EMRBreakEvenEvidence(const TradeRecord &r,bool journalPresent)
{
  if(!journalPresent) return r.be.stage==BE_NONE && !r.breakEvenExit;
  if(r.be.stage!=BE_TRIGGERED && r.be.stage!=BE_CONFIRMED) return false;
    // Bound both bytes and iterations. A failed read can never become EOF.
    ResetLastError();
    int h=FileOpen(BEJournalPath(r.positionID),FILE_READ|FILE_BIN|FILE_SHARE_READ);
    if(h==INVALID_HANDLE) return false;
    ResetLastError(); ulong size=FileSize(h);
    bool ok=(GetLastError()==0 && size>0 && size<=1048576);
    uchar bytes[4096];
    ulong offset=0;
    string row="";
    bool cr=false,found=false;
    BreakEvenState verified = {};
    while(ok && offset<size)
    {
       int want=(size-offset>4096)?4096:(int)(size-offset);
       ResetLastError(); uint got=FileReadArray(h,bytes,0,want);
       if(got!=(uint)want || GetLastError()!=0) { ok=false; break; }
       offset+=got;
       for(int i=0;i<want;i++)
       {
          uchar b=bytes[i];
          if(b==10 && cr)
          {
             if(row!="")
             {
                BreakEvenState candidate;
                if(!BEParseRow(row,r.positionID,candidate)) { ok=false; break; }
                verified=candidate; found=true;
             }
             row=""; cr=false; continue;
          }
          if(cr) { ok=false; break; }
          if(b==13) { cr=true; continue; }
          if(b<32 || b>126 || StringLen(row)>=32768) { ok=false; break; }
          row+=ShortToString((ushort)b);
       }
      }
      if(row!="" || cr || !found) ok=false;
      ResetLastError(); ulong finalSize=FileSize(h);
      if(GetLastError()!=0 || finalSize!=size) ok=false;
      ResetLastError(); FileClose(h);
      if(GetLastError()!=0 || !ok) return false;
      return r.be.durable && verified.durable &&
         BEJournalRow(r.positionID,verified)==BEJournalRow(r.positionID,r.be);
}

void EMRRecoverRecord(int idx)
{
  bool wasAdministrative=(gTradeRecords[idx].economicMarkerCleanupPending &&
             !gTradeRecords[idx].economicMarkerPending);
   gTradeRecords[idx].economicMarkerPending=true;
   if(!RebuildTrackedHistory(idx,false)) return;
      // Rebuild calls SyncEconomicMarker. Successful physical cleanup keeps the
      // original behavior; only a residual/error needs the additional proof.
      if(!gTradeRecords[idx].economicMarkerPending) return;
      TradeRecord r=gTradeRecords[idx];
      bool markerPresent=false,receiptPresent=false,bePresent=false;
      if(!EMRReady(r) ||
!EMRInspectFiles(r.positionID,markerPresent,receiptPresent,bePresent)
||
      !EMRBreakEvenEvidence(r,bePresent)) return;
   string evidence="";
   if(!EMRStrictSnapshot(r,evidence)) return;
   if(r.be.stage!=BE_NONE) evidence+="|BE_JOURNAL|"+BEJournalRow(r.positionID,r.be);
   if(!EMRCommitResolution(r.positionID,evidence)) return;
   // Recheck authoritative data after persistence, before publishing RAM state.
   // The receipt is a durable finalization record, never a substitute for history.
   string verified="";
   if(!EMRReady(gTradeRecords[idx]) || !EMRStrictSnapshot(gTradeRecords[idx],verified))
return;
   if(gTradeRecords[idx].be.stage!=BE_NONE)
      verified+="|BE_JOURNAL|"+BEJournalRow(r.positionID,gTradeRecords[idx].be);
   if(verified!=evidence ||
      !EMRInspectFiles(r.positionID,markerPresent,receiptPresent,bePresent) ||
      !receiptPresent || !EMRBreakEvenEvidence(gTradeRecords[idx],bePresent)) return;
   gTradeRecords[idx].economicMarkerPending=false;
   gTradeRecords[idx].economicMarkerCleanupPending=markerPresent;
   if(!wasAdministrative)
      PrintFormat("[SCALPER][ECONOMIC_RESOLUTION_VERIFIED] pid=%I64u cleanup_only=%d; exact history, orders, positions and durable receipt revalidated.",
         r.positionID,(int)markerPresent);
}

// A constant-size cursor replaces retention of old resolved PIDs in RAM.
// One archived PID at most is rebuilt per existing ten-second recovery pass.
void EMRMaintainArchivedCleanup()
{
   if(!gEMRMaintenanceNeeded) return;
   string prefix=EconomicMarkerPrefix(),suffix=".econ.partial",name,chosen="",first="";
   ResetLastError(); long search=FileFindFirst(prefix+"*"+suffix,name);
   if(search==INVALID_HANDLE || GetLastError()!=0)
   {
      if(search!=INVALID_HANDLE) FileFindClose(search);
      gEconomicMarkerScanUnresolved=true; return;
   }
   bool more=true,sentinel=false,ok=true;
   int visited=0;
   while(more)
    {
        if(++visited>100000) { ok=false; break; }
      if(name==EconomicMarkerPath(0)) sentinel=true;
      else
      {
         ulong pid=0;
         if(StringSubstr(name,0,StringLen(prefix))!=prefix ||
            !EMRNamePID(StringSubstr(name,StringLen(prefix)),suffix,pid))
         { ok=false; break; }
         if(FindTrackedTrade(pid)<0)
         {
            if(first=="" || StringCompare(name,first)<0) first=name;
            if(StringCompare(name,gEMRMaintenanceCursor)>0 &&
               (chosen=="" || StringCompare(name,chosen)<0)) chosen=name;
         }
      }
      ResetLastError(); more=FileFindNext(search,name);
      if(!more && GetLastError()!=0) ok=false;
    }
    ResetLastError(); FileFindClose(search);
    if(GetLastError()!=0 || !ok || !sentinel || more)
    { gEconomicMarkerScanUnresolved=true; return; }
    if(first=="")
    { gEMRMaintenanceNeeded=false; gEMRMaintenanceCursor=""; return; }
    if(chosen=="") chosen=first;
    gEMRMaintenanceCursor=chosen;
    ulong pid=0;
    if(!EMRNamePID(StringSubstr(chosen,StringLen(prefix)),suffix,pid))
    { gEconomicMarkerScanUnresolved=true; return; }
    int idx=NewTrackedTrade(pid);
    if(idx<0) { gEconomicMarkerScanUnresolved=true; return; }
    LoadTradeMetadata(gTradeRecords[idx]);
    gTradeRecords[idx].economicMarkerPending=true;
    if(!RebuildTrackedHistory(idx,false)) return;
     TryFinalizeTrackedTrade(pid);
     if(gTradeRecords[idx].closed && gTradeRecords[idx].finalizationWritten &&
        gTradeRecords[idx].economicMarkerPending) EMRRecoverRecord(idx);
     // This slot was allocated solely for one archived maintenance revisit.
     // Successful eventual deletion must not retain an old, dailyApplied=false PID.
     EMRReleaseArchivedRecord(idx);
}

bool EMRReleaseArchivedRecord(int idx)
{
  if(idx<0 || idx>=gTradeRecordCount) return false;
  TradeRecord r=gTradeRecords[idx];
  if(!r.closed || !r.finalizationWritten || !r.accountingResolved ||
     !r.volumeClosedComplete || !r.volumeOwnershipResolved ||
       r.economicMarkerPending || r.historyRefreshPending || r.inoutCostsUnresolved ||
       r.residualForeignDetected || r.breakEvenClassificationPending ||
       r.be.stage==BE_REQUEST_PENDING || r.be.stage==BE_ACKNOWLEDGED ||
       r.be.stage==BE_UNRESOLVED || r.exitTime>=AccountingDayStart()) return false;
    // No financial aggregate is modified. Exact residual evidence stays on disk.
    int tail=gTradeRecordCount-1;
    TradeRecord moved=gTradeRecords[tail];
    if(gOpenPos.active && gOpenPos.tradeRecordIdx==idx) return false;
    if(ArrayResize(gTradeRecords,tail)!=tail) return false;
    if(idx<tail) gTradeRecords[idx]=moved;
    if(gOpenPos.active && gOpenPos.tradeRecordIdx==tail) gOpenPos.tradeRecordIdx=idx;
    gTradeRecordCount=tail;
    if(r.economicMarkerCleanupPending) gEMRMaintenanceNeeded=true;
    return true;
}

void EMRReleaseArchivedRecords()
{
  for(int i=gTradeRecordCount-1;i>=0;i--)
   if(gTradeRecords[i].economicMarkerCleanupPending) EMRReleaseArchivedRecord(i);
}

void EMRInvalidateTransaction(const MqlTradeTransaction &trans)
{
  if(trans.type!=TRADE_TRANSACTION_DEAL_ADD &&
     trans.type!=TRADE_TRANSACTION_DEAL_UPDATE &&
     trans.type!=TRADE_TRANSACTION_DEAL_DELETE) return;
  if(trans.symbol!="" && trans.symbol!=Symbol()) return;
  ulong pid=0; long magic=0; bool identified=false;
  if(trans.type!=TRADE_TRANSACTION_DEAL_DELETE && trans.deal>0)
  {
     ResetLastError();
     long id=HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
     magic=HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
     string symbol=HistoryDealGetString(trans.deal,DEAL_SYMBOL);
     identified=(GetLastError()==0 && id>0 && symbol==Symbol());
     if(identified) pid=(ulong)id;
    }
    bool matched=false;
    for(int i=0;i<gTradeRecordCount;i++)
    {
       if(!gTradeRecords[i].economicMarkerCleanupPending ||
          (identified && gTradeRecords[i].positionID!=pid)) continue;
       gTradeRecords[i].economicMarkerPending=true;
       gTradeRecords[i].historyRefreshPending=true;
       matched=true;
    }
    if(matched)
    {
        // A changed closed cycle requires a fresh daily reconstruction too.
      // Never increment the financial result here.
      MarkTemporaryAccountingHistory();
    }
    if(gEMRMaintenanceNeeded && (!identified ||
       (!matched && (trans.type!=TRADE_TRANSACTION_DEAL_ADD ||
           (magic==(long)gMagicCore && !gPendingExec.active)))))
       gEconomicMarkerScanUnresolved=true;
}


// Durable request obligations, RC1.2.
void RecomputeRequestJournalFlags()
{
   gRequestJournalUnresolved=gEntryJournalInvalid || gExitJournalInvalid;
   gRequestJournalWritePending=gEntryJournalWritePending || gExitJournalWritePending;
}

string RequestJournalPath(bool exitRequest)
{ return EconomicMarkerPrefix()+(exitRequest?"request.exit.intent":"request.entry.intent"); }

bool RJUnsigned(string text,ulong &value)
{
  if(text=="0") { value=0; return true; }
  return CsvParsePID(text,value); // Exact ulong; rejects overflow and non-digits.
}

bool RJBoolean(string text,bool &value)
{
  if(text!="0" && text!="1") return false;
  value=(text=="1"); return true;
}
bool RJDouble(string text,double &value)
{
  bool digit=false,point=false;
  for(int i=0;i<StringLen(text);i++)
  {
     ushort c=StringGetCharacter(text,i);
     if(c>=48 && c<=57) digit=true;
     else if(c==46 && !point) point=true;
     else return false;
  }
  if(!digit) return false;
  value=StringToDouble(text);
  return MathIsValidNumber(value) && value>=0;
}
string RJEncode(string value)
{
  string out="";
 for(int i=0;i<StringLen(value);i++)
  out+=StringFormat("%04X",(uint)StringGetCharacter(value,i));
 return out;
}
bool RJDecode(string text,string &value)
{
  value="";
  if(StringLen(text)%4!=0 || StringLen(text)>8192) return false;
  for(int i=0;i<StringLen(text);i+=4)
  {
     uint code=0;
     for(int j=0;j<4;j++)
     {
        ushort c=StringGetCharacter(text,i+j); uint digit=0;
        if(c>=48 && c<=57) digit=(uint)(c-48);
        else if(c>=65 && c<=70) digit=(uint)(c-55);
        else return false;
        code=code*16+digit;
     }
     if(code==0) return false;
     value+=ShortToString((ushort)code);
  }
  return true;
}

bool RJRoute(string route,string mode)
{
  return (route=="ABS" && (mode=="BASE" || mode=="TURBO")) ||
   (route=="CONT" && (mode=="BASE_CONT" || mode=="TURBO_CONT")) ||
   (route=="UNAVAILABLE" && mode=="UNAVAILABLE");
}

string RJChecksum(string text)
{
  // ASCII journal fields only. Integrity check, not authentication.
  uint hash=2166136261;
  for(int i=0;i<StringLen(text);i++)
     hash=(hash^(uint)StringGetCharacter(text,i))*(uint)16777619;
  return StringFormat("%08X",hash);
}

bool RJParse(string row,bool exitRequest,bool &resolved,
      PendingExecContext &entry,PendingExitIntent &exitIntent)
{
  string f[];
  int fields=StringSplit(row,'|',f);
  bool legacy=(fields==38 && f[0]=="RC12_REQUEST_JOURNAL_V1");
  bool current=(fields==40 && f[0]=="RC12_REQUEST_JOURNAL_V2");
  if((!legacy && !current) ||
     f[37]!="COMPLETE" || f[4]!=(exitRequest?"EXIT":"ENTRY") ||
     (f[5]!="ACTIVE" && f[5]!="RESOLVED")) return false;
  ENUM_REQUEST_DISPATCH_PHASE phase=REQUEST_MAY_HAVE_DISPATCHED;
  if(current)
  {
 if(f[38]!="0" && f[38]!="1") return false;
 string checked=f[0];
 for(int i=1;i<39;i++) checked+="|"+f[i];
 if(f[39]!=RJChecksum(checked)) return false;
 phase=(f[38]=="1"?REQUEST_PREPARED:REQUEST_MAY_HAVE_DISPATCHED);
}
ulong account,magic;
string symbol;
if(!RJUnsigned(f[1],account) || account!=(ulong)AccountInfoInteger(ACCOUNT_LOGIN) ||
   !RJDecode(f[2],symbol) || symbol!=Symbol() ||
   !RJUnsigned(f[3],magic) || magic!=(ulong)gMagicCore) return false;
resolved=(f[5]=="RESOLVED");
ZeroMemory(entry); ZeroMemory(exitIntent);
entry.dispatchPhase=phase; exitIntent.dispatchPhase=phase;
bool active;
if(!RJBoolean(f[6],active) || (!resolved && !active)) return false;
entry.active=active; exitIntent.active=active;
if(f[7]!="-1" && f[7]!="0" && f[7]!="1") return false;
entry.direction=(int)StringToInteger(f[7]);
if(!RJDecode(f[8],entry.route) || !RJDecode(f[9],entry.mode) ||
   !RJRoute(entry.route,entry.mode) ||
   !RJDouble(f[10],entry.requestPrice) || !RJDouble(f[11],entry.requestedLots) ||
   !RJDouble(f[12],entry.slPrice) || !RJDouble(f[13],entry.tpPrice)) return false;
ulong sentAt,order,deal,requestID,pid,ticket,action,type,position,byPosition,requestMagic;
if(!RJUnsigned(f[14],sentAt) || (long)sentAt<0 ||
   !RJUnsigned(f[15],order) || !RJUnsigned(f[16],deal) ||
   !RJUnsigned(f[17],requestID) || requestID>(ulong)4294967295 ||
   !RJBoolean(f[18],entry.accepted) || !RJBoolean(f[19],entry.requestPriceAvailable) ||
   !RJDouble(f[20],entry.breakoutPrice) || !RJBoolean(f[21],entry.breakoutPriceAvailable) ||
   !RJUnsigned(f[22],pid) || !RJUnsigned(f[23],ticket) ||
   !RJDecode(f[24],exitIntent.reason) || !RJBoolean(f[25],exitIntent.uncertain) ||
   !RJUnsigned(f[26],action) || action>100 ||
   !RJUnsigned(f[27],type) || type>100 ||
   !RJDouble(f[28],exitIntent.requestSnapshot.volume) ||
   !RJDouble(f[29],exitIntent.requestSnapshot.price) ||
   !RJDouble(f[30],exitIntent.requestSnapshot.sl) ||
   !RJDouble(f[31],exitIntent.requestSnapshot.tp) ||
   !RJUnsigned(f[32],position) || !RJUnsigned(f[33],byPosition) ||
   !RJUnsigned(f[34],requestMagic) ||
   !RJDecode(f[35],exitIntent.requestSnapshot.symbol) ||
   !RJDecode(f[36],exitIntent.requestSnapshot.comment)) return false;
entry.sentAt=(datetime)sentAt; entry.orderTicket=order; entry.resultDeal=deal;
entry.requestID=(uint)requestID;
exitIntent.sentAt=entry.sentAt; exitIntent.orderTicket=order;
exitIntent.resultDeal=deal; exitIntent.requestID=entry.requestID;
exitIntent.accepted=entry.accepted; exitIntent.positionID=pid;
exitIntent.positionTicket=ticket;
exitIntent.requestSnapshot.action=(ENUM_TRADE_REQUEST_ACTIONS)action;
  exitIntent.requestSnapshot.type=(ENUM_ORDER_TYPE)type;
  exitIntent.requestSnapshot.position=position;
  exitIntent.requestSnapshot.position_by=byPosition;
  exitIntent.requestSnapshot.magic=requestMagic;
  if(phase==REQUEST_PREPARED &&
     (order>0 || deal>0 || requestID>0 || entry.accepted || exitIntent.uncertain))
     return false;
  if(resolved) return true; // Tombstone itself is the caller's durable proof.
  if(sentAt==0) return false;
  if(!exitRequest)
     return (entry.direction==1 || entry.direction==-1) && entry.requestedLots>0 &&
        (!entry.requestPriceAvailable || entry.requestPrice>0) &&
        (!entry.breakoutPriceAvailable || entry.breakoutPrice>0);
  if(pid==0 || (exitIntent.reason!="EOD" && exitIntent.reason!="RECOVERED_EXIT")) return
false;
  // A pre-dispatch/recovered close can lack the CTrade request snapshot.
  // Its PID/ticket/intent still protects it; no success/failure is inferred.
  if(exitIntent.requestSnapshot.symbol=="")
     return action==0 && type==0 && exitIntent.requestSnapshot.volume==0 &&
        requestMagic==0 && position==0 && byPosition==0;
  return exitIntent.requestSnapshot.symbol==Symbol() &&
requestMagic==(ulong)gMagicCore &&
    (action==(ulong)TRADE_ACTION_DEAL ||
action==(ulong)TRADE_ACTION_CLOSE_BY) &&
   (type==(ulong)ORDER_TYPE_BUY || type==(ulong)ORDER_TYPE_SELL ||
type==(ulong)ORDER_TYPE_CLOSE_BY) &&
   exitIntent.requestSnapshot.volume>0 && (ticket==0 || position==ticket);
}

string RJRow(bool exitRequest,bool resolved)
{
  PendingExecContext e=gPendingExec;
  PendingExitIntent x=gPendingExit;
  if(exitRequest)
  {
     ZeroMemory(e); e.route="UNAVAILABLE"; e.mode="UNAVAILABLE";
     e.active=x.active; e.sentAt=x.sentAt; e.orderTicket=x.orderTicket;
     e.resultDeal=x.resultDeal; e.requestID=x.requestID; e.accepted=x.accepted;
     e.dispatchPhase=x.dispatchPhase;
  }
  else ZeroMemory(x);
  string f[];
  if(ArrayResize(f,40)!=40) return "";
  f[0]="RC12_REQUEST_JOURNAL_V2";
f[1]=(string)AccountInfoInteger(ACCOUNT_LOGIN);
  f[2]=RJEncode(Symbol()); f[3]=(string)(ulong)gMagicCore;
  f[4]=exitRequest?"EXIT":"ENTRY"; f[5]=resolved?"RESOLVED":"ACTIVE";
  f[6]=e.active?"1":"0"; f[7]=(string)e.direction;
  f[8]=RJEncode(e.route); f[9]=RJEncode(e.mode);
  f[10]=DoubleToString(e.requestPrice,16); f[11]=DoubleToString(e.requestedLots,16);
  f[12]=DoubleToString(e.slPrice,16); f[13]=DoubleToString(e.tpPrice,16);
  f[14]=(string)(ulong)e.sentAt; f[15]=(string)e.orderTicket; f[16]=(string)e.resultDeal;
  f[17]=(string)e.requestID; f[18]=e.accepted?"1":"0";
  f[19]=e.requestPriceAvailable?"1":"0"; f[20]=DoubleToString(e.breakoutPrice,16);
  f[21]=e.breakoutPriceAvailable?"1":"0"; f[22]=(string)x.positionID;
  f[23]=(string)x.positionTicket; f[24]=RJEncode(x.reason); f[25]=x.uncertain?"1":"0";
  f[26]=(string)(int)x.requestSnapshot.action; f[27]=(string)(int)x.requestSnapshot.type;
  f[28]=DoubleToString(x.requestSnapshot.volume,16);
f[29]=DoubleToString(x.requestSnapshot.price,16);
  f[30]=DoubleToString(x.requestSnapshot.sl,16);
f[31]=DoubleToString(x.requestSnapshot.tp,16);
  f[32]=(string)x.requestSnapshot.position; f[33]=(string)x.requestSnapshot.position_by;
  f[34]=(string)x.requestSnapshot.magic; f[35]=RJEncode(x.requestSnapshot.symbol);
  f[36]=RJEncode(x.requestSnapshot.comment); f[37]="COMPLETE";
  f[38]=(string)(int)e.dispatchPhase;
  string row=f[0];
  for(int i=1;i<39;i++) row+="|"+f[i];
  f[39]=RJChecksum(row); row+="|"+f[39];
  bool checkResolved; PendingExecContext checkEntry; PendingExitIntent checkExit;
  if(!RJParse(row,exitRequest,checkResolved,checkEntry,checkExit)) return "";
  return row;
}
bool PersistRequestJournal(bool exitRequest,bool resolved=false)
{
  // Never turn an older PREPARED snapshot plus torn MAY tail into negative proof.
  if(!resolved &&
     ((exitRequest && gExitJournalInvalid &&
gPendingExit.dispatchPhase==REQUEST_PREPARED) ||
      (!exitRequest && gEntryJournalInvalid &&
gPendingExec.dispatchPhase==REQUEST_PREPARED)))
     return false;
  string row=RJRow(exitRequest,resolved);
  bool ok=false;
  if(row!="")
  {
     int h=FileOpen(RequestJournalPath(exitRequest),
        FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
     if(h!=INVALID_HANDLE)
     {
        if(FileSeek(h,0,SEEK_END))
      {
         // Leading CRLF separates a torn previous tail from this snapshot.
         string payload="\r\n"+row+"\r\n";
         ResetLastError(); uint written=FileWriteString(h,payload);
         ok=(written==(uint)StringLen(payload) && GetLastError()==0);
         ResetLastError(); FileFlush(h);
        if(GetLastError()!=0) ok=false;
       }
       FileClose(h);
     }
    }
    if(exitRequest)
    { gExitJournalWritePending=!ok; if(ok) gExitJournalInvalid=false; }
    else
    { gEntryJournalWritePending=!ok; if(ok) gEntryJournalInvalid=false; }
    RecomputeRequestJournalFlags();
    return ok;
}

bool MarkRequestDispatchPossible(bool exitRequest)
{
  if(exitRequest)
  {
     if(!gPendingExit.active || gPendingExit.dispatchPhase!=REQUEST_PREPARED ||
        gExitJournalInvalid || gExitJournalCleanupPending) return false;
     gPendingExit.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
  }
  else
  {
     if(!gPendingExec.active || gPendingExec.dispatchPhase!=REQUEST_PREPARED ||
      gEntryJournalInvalid || gEntryJournalCleanupPending) return false;
     gPendingExec.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
    }
    // Once this flush succeeds, a crash is ambiguous even before the API call.
    return PersistRequestJournal(exitRequest);
}

bool ResolveRequestJournal(bool exitRequest)
{
  if(exitRequest) gExitJournalCleanupPending=true;
  else gEntryJournalCleanupPending=true;
  PersistRequestJournal(exitRequest,true);
  string path=RequestJournalPath(exitRequest);
  // The caller supplies terminal proof. Successful whole-file deletion is
  // also a durable resolution even if appending the tombstone failed.
    bool gone=!FileIsExist(path);
    if(!gone && FileDelete(path)) gone=!FileIsExist(path);
    if(exitRequest)
    {
        gExitJournalCleanupPending=!gone;
        if(gone) { gExitJournalWritePending=false; gExitJournalInvalid=false; }
    }
    else
    {
       gEntryJournalCleanupPending=!gone;
       if(gone) { gEntryJournalWritePending=false; gEntryJournalInvalid=false; }
      }
      RecomputeRequestJournalFlags();
      return gone;
}

bool ReleasePreparedRequest(bool exitRequest)
{
  // Caller must supply a pristine restored snapshot, or retained local cleanup proof.
  if(exitRequest)
  {
     if(!gPendingExit.active || gPendingExit.dispatchPhase!=REQUEST_PREPARED ||
        gPendingExit.orderTicket>0 || gPendingExit.resultDeal>0 ||
        gPendingExit.requestID>0 || gPendingExit.accepted || gPendingExit.uncertain ||
        (gExitJournalInvalid && !gExitJournalCleanupPending)) return false;
  }
  else
  {
     if(!gPendingExec.active || gPendingExec.dispatchPhase!=REQUEST_PREPARED ||
        gPendingExec.orderTicket>0 || gPendingExec.resultDeal>0 ||
        gPendingExec.requestID>0 || gPendingExec.accepted ||
        (gEntryJournalInvalid && !gEntryJournalCleanupPending)) return false;
  }
    if(!ResolveRequestJournal(exitRequest)) return false;
    if(exitRequest) ClearPendingExitIntent();
    else ResetPendingExec(false);
    return true;
}

bool RJRead(bool exitRequest,bool &exists,bool &resolved,
       PendingExecContext &entry,PendingExitIntent &exitIntent,bool &hasSnapshot)
{
  exists=FileIsExist(RequestJournalPath(exitRequest)); resolved=false; hasSnapshot=false;
  if(!exists) return true;
  int
h=FileOpen(RequestJournalPath(exitRequest),FILE_READ|FILE_BIN|FILE_SHARE_READ)
;
  if(h==INVALID_HANDLE) return false;
 ResetLastError(); ulong size=FileSize(h);
 if(GetLastError()!=0) { FileClose(h); return false; }
 uchar bytes[4096]; string row=""; bool cr=false,malformed=false,tailInvalid=false;
 ulong offset=0;
 while(offset<size)
 {
    int want=(size-offset>4096)?4096:(int)(size-offset);
    ResetLastError(); uint got=FileReadArray(h,bytes,0,want);
    if(got!=(uint)want || GetLastError()!=0) { FileClose(h); return false; }
  offset+=got;
  for(int i=0;i<want;i++)
  {
    uchar b=bytes[i];
    if(b==10 && cr)
    {
       if(row!="" || malformed)
       {
          bool terminal; PendingExecContext candidateEntry; PendingExitIntent
candidateExit;
          if(!malformed && RJParse(row,exitRequest,terminal,candidateEntry,candidateExit))
          {
             // An earlier ambiguous dispatch cannot become negative proof.
             if(!terminal &&

(exitRequest?candidateExit.dispatchPhase:candidateEntry.dispatchPhase)==REQUEST_PREPARED &&
   (tailInvalid || (hasSnapshot && !resolved &&

(exitRequest?exitIntent.dispatchPhase:entry.dispatchPhase)==REQUEST_MAY_HAVE_DISPATCHED)))
       { FileClose(h); return false; }
       if(hasSnapshot && !resolved && !terminal &&
          ((exitRequest && exitIntent.positionID!=candidateExit.positionID) ||
           ((exitRequest?exitIntent.orderTicket:entry.orderTicket)>0 &&
            (exitRequest?exitIntent.orderTicket:entry.orderTicket)!=
            (exitRequest?candidateExit.orderTicket:candidateEntry.orderTicket))))
        { FileClose(h); return false; }
        entry=candidateEntry; exitIntent=candidateExit;
        resolved=terminal; hasSnapshot=true; tailInvalid=false;
      }
      else tailInvalid=true;
    }
    row=""; malformed=false; cr=false; continue;
  }
  if(cr) { malformed=true; cr=false; }
  if(b==13) { cr=true; continue; }
  if(b<32 || b>126) malformed=true;
  if(StringLen(row)<32768) row+=ShortToString((ushort)b);
   else malformed=true;
  }
 }
 FileClose(h);
 if(row!="" || malformed || cr) tailInvalid=true;
 // A later torn row never turns an older ACTIVE snapshot into absence.
 // With no usable snapshot, or after a tombstone, ambiguity stays explicit.
 return hasSnapshot && !tailInvalid;
}
bool RJCompatibleEntry(const PendingExecContext &a,const PendingExecContext &b)
{
  if(a.orderTicket>0 && b.orderTicket>0) return a.orderTicket==b.orderTicket;
  if(a.requestID>0 && b.requestID>0) return a.requestID==b.requestID;
  if(a.resultDeal>0 && b.resultDeal>0) return a.resultDeal==b.resultDeal;
  return a.sentAt==b.sentAt && a.direction==b.direction && a.route==b.route &&
     a.mode==b.mode &&
MathAbs(a.requestedLots-b.requestedLots)<=AccountingVolumeTolerance() &&
     MathAbs(a.requestPrice-b.requestPrice)<=gTickSize*0.000001 &&
     MathAbs(a.slPrice-b.slPrice)<=gTickSize*0.000001 &&
     MathAbs(a.tpPrice-b.tpPrice)<=gTickSize*0.000001;
}

bool RJCompatibleExit(const PendingExitIntent &a,const PendingExitIntent &b)
{
  if(a.positionID!=b.positionID) return false;
  if(a.orderTicket>0 && b.orderTicket>0) return a.orderTicket==b.orderTicket;
  if(a.requestID>0 && b.requestID>0) return a.requestID==b.requestID;
  if(a.resultDeal>0 && b.resultDeal>0) return a.resultDeal==b.resultDeal;
  return a.sentAt==b.sentAt && a.reason==b.reason &&
     (a.positionTicket==0 || b.positionTicket==0 || a.positionTicket==b.positionTicket);
}

bool RestoreRequestJournals()
{
 gRequestJournalRestoring=true;
 for(int side=0;side<2;side++)
 {
   bool isExit=(side==1),exists,resolved,snapshot;
   PendingExecContext entry; PendingExitIntent exitIntent;
   bool valid=RJRead(isExit,exists,resolved,entry,exitIntent,snapshot);
   if(isExit) gExitJournalInvalid=!valid;
   else gEntryJournalInvalid=!valid;
   if(!exists) continue;
   if(snapshot && !resolved)
   {
      if(isExit)
      {
         if(!gPendingExit.active) gPendingExit=exitIntent;
       else if(!RJCompatibleExit(gPendingExit,exitIntent)) gExitJournalInvalid=true;
       else if(gPendingExit.dispatchPhase==REQUEST_MAY_HAVE_DISPATCHED &&
            exitIntent.dispatchPhase==REQUEST_PREPARED) gExitJournalInvalid=true;
       else if(exitIntent.dispatchPhase==REQUEST_MAY_HAVE_DISPATCHED)
          gPendingExit.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
       if(valid && !gExitJournalInvalid &&
exitIntent.dispatchPhase==REQUEST_PREPARED)
          ReleasePreparedRequest(true);
  }
  else
  {
    if(!gPendingExec.active) gPendingExec=entry;
    else if(!RJCompatibleEntry(gPendingExec,entry)) gEntryJournalInvalid=true;
    else if(gPendingExec.dispatchPhase==REQUEST_MAY_HAVE_DISPATCHED &&
           entry.dispatchPhase==REQUEST_PREPARED) gEntryJournalInvalid=true;
    else if(entry.dispatchPhase==REQUEST_MAY_HAVE_DISPATCHED)
       gPendingExec.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
    if(valid && !gEntryJournalInvalid && entry.dispatchPhase==REQUEST_PREPARED)
       ReleasePreparedRequest(false);
  }
  }
  else if(valid && resolved)
  {
    // A committed tombstone is proof for deletion retry, never ACTIVE.
    // Do not remove a conflicting live request's obligation on recovery.
    if((isExit && gPendingExit.active) || (!isExit && gPendingExec.active))
    {
       if(isExit) gExitJournalInvalid=true;
       else gEntryJournalInvalid=true;
    }
    else
    {
       if(isExit) gExitJournalCleanupPending=true;
       else gEntryJournalCleanupPending=true;
       ResolveRequestJournal(isExit);
   }
   }
  }
  gRequestJournalRestoring=false;
  RecomputeRequestJournalFlags();
  return !gRequestJournalUnresolved && !gRequestJournalWritePending &&
    !gEntryJournalCleanupPending && !gExitJournalCleanupPending;
}

void RecoverRequestJournals()
{
  datetime now=TimeTradeServer();
  if(now<gNextRequestJournalRecovery) return;
  gNextRequestJournalRecovery=now+10;
  if(gEntryJournalCleanupPending)
  {
   if(gPendingExec.active && gPendingExec.dispatchPhase==REQUEST_PREPARED)
      ReleasePreparedRequest(false);
   else ResolveRequestJournal(false);
  }
  if(gExitJournalCleanupPending)
 {
     if(gPendingExit.active && gPendingExit.dispatchPhase==REQUEST_PREPARED)
        ReleasePreparedRequest(true);
     else ResolveRequestJournal(true);
  }
  if(gEntryJournalInvalid || gExitJournalInvalid) RestoreRequestJournals();
  if(gEntryJournalWritePending && !gEntryJournalCleanupPending &&
gPendingExec.active)
     PersistRequestJournal(false);
  if(gExitJournalWritePending && !gExitJournalCleanupPending && gPendingExit.active)
     PersistRequestJournal(true);
  RecomputeRequestJournalFlags();
}

// Durable exact-order obligations; metadata is never terminal proof.
string OrderObligationPath(ulong ticket)
{
  return EconomicMarkerPrefix()+(string)ticket+".order.unresolved";
}

void UnknownOrderObligationContext(ulong ticket,UnresolvedOrderContext &c)
{
  ZeroMemory(c);
  c.active=true; c.classificationPending=true; c.orderTicket=ticket;
  c.nature=PENDING_ORDER_UNKNOWN; c.lastState=ORDER_STATE_STARTED;
   c.orderType=-1; c.orderReason=-1;
   c.route="UNAVAILABLE"; c.mode="UNAVAILABLE";
   c.persistencePending=true; c.persistenceSnapshot="";
   // Unknown/corrupt metadata cannot invent a setup lower bound or firstSeen.
   c.firstSeen=0; c.setupTime=0; c.doneTime=0;
}

bool EnsureOrderObligationIdentity(ulong ticket)
{
  string path=OrderObligationPath(ticket);
  // Filename presence alone is an unresolved identity, even if body is torn.
  // Ticket zero is the enumeration sentinel and never an operational order.
  if(FileIsExist(path)) return true;
  int h=FileOpen(path,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
  if(h==INVALID_HANDLE) return false;
 string payload="RC12_ORDER_IDENTITY_V1\r\n";
 ResetLastError(); uint written=FileWriteString(h,payload);
 bool ok=(written==(uint)StringLen(payload) && GetLastError()==0);
 ResetLastError(); FileFlush(h);
 if(GetLastError()!=0) ok=false;
 FileClose(h);
 return ok && FileIsExist(path);
}
bool OrderObligationOptionalEnum(string text,long maximum,long &value)
{
  if(text=="-1") { value=-1; return true; }
  ulong parsed;
  if(!RJUnsigned(text,parsed) || parsed>(ulong)maximum) return false;
  value=(long)parsed;
  return true;
}

bool ParseOrderObligationSnapshot(string row,ulong filenameTicket,
          UnresolvedOrderContext &c)
{
  string f[];
  if(filenameTicket==0 || StringSplit(row,'|',f)!=20 ||
     f[0]!="RC12_ORDER_OBLIGATION_V1" || f[19]!="COMPLETE") return false;
  ulong account,magic,ticket,firstSeen,setup,done,pid,by,nature,state;
  string symbol;
  if(!RJUnsigned(f[1],account) || account!=(ulong)AccountInfoInteger(ACCOUNT_LOGIN) ||
     !RJDecode(f[2],symbol) || symbol!=Symbol() ||
     !RJUnsigned(f[3],magic) || magic!=(ulong)gMagicCore ||
     !RJUnsigned(f[4],ticket) || ticket!=filenameTicket ||
     !RJUnsigned(f[5],firstSeen) || (long)firstSeen<0 ||
     !RJUnsigned(f[6],setup) || (long)setup<0 ||
     !RJUnsigned(f[7],done) || (long)done<0 ||
     !RJUnsigned(f[8],pid) || !RJUnsigned(f[9],by) ||
     !RJUnsigned(f[10],nature) || nature>(ulong)PENDING_ORDER_EXIT ||
     !RJUnsigned(f[11],state) || state>(ulong)ORDER_STATE_REQUEST_CANCEL)
     return false;
  UnknownOrderObligationContext(ticket,c);
  if(!OrderObligationOptionalEnum(f[12],(long)ORDER_TYPE_CLOSE_BY,c.orderType) ||
     !OrderObligationOptionalEnum(f[13],(long)ORDER_REASON_SO,c.orderReason) ||
     !RJDouble(f[14],c.initialVolume) || !RJDouble(f[15],c.remainingVolume) ||
     !RJDecode(f[16],c.comment) || !RJDecode(f[17],c.route) ||
     !RJDecode(f[18],c.mode) || !RJRoute(c.route,c.mode)) return false;
  c.firstSeen=(datetime)firstSeen; c.setupTime=(datetime)setup;
c.doneTime=(datetime)done;
  c.positionID=pid; c.positionByID=by;
  c.nature=(PendingOrderNature)nature; c.lastState=(ENUM_ORDER_STATE)state;
  // Persisted classification/state/volumes are metadata, never terminal proof.
  c.active=true; c.classificationPending=true;
    c.persistencePending=false; c.persistenceSnapshot=row;
    return true;
}
string OrderObligationSnapshot(const UnresolvedOrderContext &c)
{
  if(c.orderTicket==0) return "";
  string f[];
  if(ArrayResize(f,20)!=20) return "";
  f[0]="RC12_ORDER_OBLIGATION_V1";
f[1]=(string)AccountInfoInteger(ACCOUNT_LOGIN);
  f[2]=RJEncode(Symbol()); f[3]=(string)(ulong)gMagicCore;
  f[4]=(string)c.orderTicket; f[5]=(string)(ulong)c.firstSeen;
  f[6]=(string)(ulong)c.setupTime; f[7]=(string)(ulong)c.doneTime;
  f[8]=(string)c.positionID; f[9]=(string)c.positionByID;
  f[10]=(string)(int)c.nature; f[11]=(string)(int)c.lastState;
  f[12]=(string)c.orderType; f[13]=(string)c.orderReason;
  f[14]=DoubleToString(c.initialVolume,16); f[15]=DoubleToString(c.remainingVolume,16);
  f[16]=RJEncode(c.comment); f[17]=RJEncode(c.route); f[18]=RJEncode(c.mode);
  f[19]="COMPLETE";
  string row=f[0];
  for(int i=1;i<20;i++) row+="|"+f[i];
    UnresolvedOrderContext check;
    if(!ParseOrderObligationSnapshot(row,c.orderTicket,check)) return "";
    return row;
}

bool PersistOrderObligationSnapshot(UnresolvedOrderContext &c)
{
  bool alreadyPresent=FileIsExist(OrderObligationPath(c.orderTicket));
  if(c.orderTicket==0 || !EnsureOrderObligationIdentity(c.orderTicket))
  { c.persistencePending=true; return false; }
  string row=OrderObligationSnapshot(c);
 if(row=="") { c.persistencePending=true; return false; }
 // An unchanged observed context never grows the file on every scan/tick.
 if(alreadyPresent && !c.persistencePending && row==c.persistenceSnapshot) return true;
 int h=FileOpen(OrderObligationPath(c.orderTicket),
    FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
 bool ok=false;
 if(h!=INVALID_HANDLE)
 {
    if(FileSeek(h,0,SEEK_END))
    {
       string payload="\r\n"+row+"\r\n";
       ResetLastError(); uint written=FileWriteString(h,payload);
       ok=(written==(uint)StringLen(payload) && GetLastError()==0);
       ResetLastError(); FileFlush(h);
       if(GetLastError()!=0) ok=false;
  }
  FileClose(h);
 }
 c.persistencePending=!ok;
 if(ok) c.persistenceSnapshot=row;
 return ok;
}
bool ReadOrderObligationSnapshot(ulong ticket,UnresolvedOrderContext &c)
{
  UnknownOrderObligationContext(ticket,c);
  int h=FileOpen(OrderObligationPath(ticket),FILE_READ|FILE_BIN|FILE_SHARE_READ);
  if(h==INVALID_HANDLE) return false;
  ResetLastError(); ulong size=FileSize(h);
  if(GetLastError()!=0) { FileClose(h); return false; }
  uchar bytes[4096]; string row="";
  bool cr=false,malformed=false,tailInvalid=false,hasSnapshot=false;
  UnresolvedOrderContext latest;
  ulong offset=0;
  while(offset<size)
  {
     int want=(size-offset>4096)?4096:(int)(size-offset);
     ResetLastError(); uint got=FileReadArray(h,bytes,0,want);
     if(got!=(uint)want || GetLastError()!=0) { FileClose(h); return false; }
     offset+=got;
     for(int i=0;i<want;i++)
     {
        uchar b=bytes[i];
        if(b==10 && cr)
        {
           if(row!="" || malformed)
           {
              UnresolvedOrderContext candidate;
              if(!malformed && ParseOrderObligationSnapshot(row,ticket,candidate))
        { latest=candidate; hasSnapshot=true; tailInvalid=false; }
        else tailInvalid=true;
       }
       row=""; malformed=false; cr=false; continue;
     }
     if(cr) { malformed=true; cr=false; }
     if(b==13) { cr=true; continue; }
     if(b<32 || b>126) malformed=true;
     if(StringLen(row)<32768) row+=ShortToString((ushort)b);
     else malformed=true;
   }
  }
  FileClose(h);
  if(row!="" || malformed || cr) tailInvalid=true;
  // Empty/identity-only/invalid-tail files retain an UNKNOWN exact ticket.
 // No prior metadata snapshot can authorize classification/terminal cleanup.
 if(!hasSnapshot || tailInvalid) return false;
 c=latest;
 return true;
}
bool ReleaseOrderObligation(UnresolvedOrderContext &c)
{
  // CALL ONLY AFTER fresh ReadOwnOrder + exact complete history/ledger proof.
  // A persisted lastState, missing live order or flat Positions is insufficient.
  if(c.orderTicket==0) return false;
  string path=OrderObligationPath(c.orderTicket);
  bool gone=!FileIsExist(path);
  if(!gone && FileDelete(path)) gone=!FileIsExist(path);
  if(!gone)
  {
     c.active=true; c.classificationPending=true; c.persistencePending=true;
     gOrderObligationScanUnresolved=true;
     return false;
  }
  c.active=false; c.classificationPending=false;
    c.persistencePending=false; c.persistenceSnapshot="";
    return true;
}

void StoreOrderObligationContext(int idx,UnresolvedOrderContext &c,bool
authoritativeOrder)
{
  if(c.active)
  {
     if(authoritativeOrder) PersistOrderObligationSnapshot(c);
     else if(!EnsureOrderObligationIdentity(c.orderTicket)) c.persistencePending=true;
  }
  // A deleted terminal obligation must not be recreated by this assignment.
    gUnresolvedOrders[idx]=c;
}

void RestoreOrderObligations()
{
  if(gOrderObligationRestoring) return;
  gOrderObligationRestoring=true;
  gOrderObligationScanUnresolved=false;
  if(!EnsureOrderObligationIdentity(0))
  {
     gOrderObligationScanUnresolved=true;
     gOrderObligationRestoring=false; return;
  }
  string prefix=EconomicMarkerPrefix(),suffix=".order.unresolved",name;
  long search=FileFindFirst(prefix+"*"+suffix,name);
if(search==INVALID_HANDLE)
{
   gOrderObligationScanUnresolved=true;
    gOrderObligationRestoring=false; return;
}
    ulong tickets[]; int count=0; bool sentinel=false,more=true;
    while(more)
    {
       if(name==prefix+"0"+suffix) sentinel=true;
       else
       {
          int length=StringLen(name)-StringLen(prefix)-StringLen(suffix);
          ulong ticket=0;
          if(length<=0 || StringSubstr(name,0,StringLen(prefix))!=prefix ||
             StringSubstr(name,StringLen(name)-StringLen(suffix))!=suffix ||
             !CsvParsePID(StringSubstr(name,StringLen(prefix),length),ticket))
             gOrderObligationScanUnresolved=true;
          else if(ArrayResize(tickets,count+1)!=count+1)
             gOrderObligationScanUnresolved=true; // Exact filename remains durable.
          else tickets[count++]=ticket;
       }
       ResetLastError(); more=FileFindNext(search,name);
       // Only an explicit clean EOF (zero after ResetLastError) is accepted.
       // No guessed nonzero EOF code can turn an incomplete scan into emptiness.
       if(!more && GetLastError()!=0) gOrderObligationScanUnresolved=true;
      }
      FileFindClose(search);
      if(!sentinel) gOrderObligationScanUnresolved=true;
      // Enumeration is closed before allocation/rebuild/persistence can mutate files.
      for(int i=0;i<count;i++)
      {
         ulong ticket=tickets[i];
         int known=FindUnresolvedOrder(ticket);
     int idx=RememberUnresolvedOrder(ticket);
     if(idx<0) { gOrderObligationScanUnresolved=true; continue; }
     if(known>=0)
     {
        // A retry never overwrites a newer in-memory authoritative context.
        if(gUnresolvedOrders[idx].persistencePending)
           gOrderObligationScanUnresolved=true;
        continue;
     }
     UnresolvedOrderContext restored;
     bool valid=ReadOrderObligationSnapshot(ticket,restored);
     // Remember may have written an UNKNOWN initial snapshot; therefore the
     // integration must suppress snapshot writes while gOrderObligationRestoring.
     gUnresolvedOrders[idx]=restored;
     if(!valid) gOrderObligationScanUnresolved=true;
      }
      gOrderObligationRestoring=false;
}
void InitializeAccounting()
{
  ArrayResize(gTradeRecords,0); ArrayResize(gDeferredAccountingPIDs,0);
  gDeferredRegistryUnavailable=false;
  gTradeRecordCount=0; ResetOpenPos(); ResetPendingExec(false);
  gPendingExit.active=false; gPendingExit.positionID=0; gPendingExit.reason="";
  gPendingExit.dispatchPhase=REQUEST_MAY_HAVE_DISPATCHED;
gPendingExit.sentAt=0;
  gPendingExit.orderTicket=0; gPendingExit.resultDeal=0;
  gPendingExit.positionTicket=0; gPendingExit.requestID=0;
  gPendingExit.accepted=false; gPendingExit.uncertain=false;
  ZeroMemory(gPendingExit.requestSnapshot);
  ArrayResize(gUnresolvedOrders,0);
  gMultipleOwnOrdersActive=false; gOrderRegistryUnavailable=false;
  gOrderRegistryFallbackCount=0; gOrderRegistryOverflow=false;
  gOrderObligationScanUnresolved=false; gOrderObligationRestoring=false;
  gDeferredFallbackCount=0; gDeferredRegistryOverflow=false;
  gEconomicMarkerScanUnresolved=false;
  gEMRMaintenanceNeeded=false; gEMRMaintenanceCursor="";
  gIdentityLossUnresolved=FileIsExist(IdentityLossMarkerPath());
  gIdentityLossPersistPending=false;
  gRequestJournalUnresolved=false; gRequestJournalWritePending=false;
  gEntryJournalCleanupPending=false; gExitJournalCleanupPending=false;
  gEntryJournalInvalid=false; gExitJournalInvalid=false;
  gEntryJournalWritePending=false; gExitJournalWritePending=false;
  gRequestJournalRestoring=false; gNextRequestJournalRecovery=0;
  ArrayResize(gDeferredDeals,0); gDeferredDealFallbackCount=0;
gDeferredDealOverflow=false;
  gNextOrderReconcile=0;
  gLiveOwnershipUnresolved=false; gAccountingCapacityUnresolved=false;
  gDailyRiskLimitLatched=false; gDailyHistoryRetryRequired=false;
  gDailyEconomicsState=DAILY_ECONOMICS_VALID; gLastAccountingRecoveryTime=0;
  gPendingOrderClassificationUnresolved=false;
  requestsAcceptedToday=0; ordersEnteredToday=0; dailyNetPnL=0; dailyPnLR=0;
  consecutiveLosses=0; dailyRiskBlocked=false; lastTradeWasLoss=false;
  lastCloseConfirmedTime=0; gDailyPnLRValid=true;
  gDailyEconomicsValid=true; gQuotaHistoryValid=true;
  gNeedsAccountingSync=false; gLastPendingReconcileTime=0;
  ArrayResize(gConfirmedPositionsToday,0);
  RestoreRequestJournals();
  RestoreOrderObligations();
}

void ResetAccountingDay()
{
  // An open cycle, its exit intent and pending request survive midnight.
  requestsAcceptedToday=0; ordersEnteredToday=0; dailyNetPnL=0; dailyPnLR=0;
  consecutiveLosses=0; dailyRiskBlocked=false; lastTradeWasLoss=false;
  lastCloseConfirmedTime=0; gDailyPnLRValid=true;
  gDailyRiskLimitLatched=false; gDailyHistoryRetryRequired=true;
gLastAccountingRecoveryTime=0;
  gDailyEconomicsValid=true; gQuotaHistoryValid=true;
  ArrayResize(gConfirmedPositionsToday,0);
  for(int i=0;i<gTradeRecordCount;i++)
  {
    // Prior finalized records remain reusable; an open cycle is accounted
    // against the date on which its closure will be confirmed.
    if(!gTradeRecords[i].closed) gTradeRecords[i].dailyApplied=false;
    gTradeRecords[i].quotaCounted=false;
  }
  RestoreDailyPersistence(false);
  RecomputeAccountingBlock();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
     const MqlTradeRequest &request,const MqlTradeResult &result)
{
  EMRInvalidateTransaction(trans);
  BEHandleTransaction(trans,request,result);
  BookRiskTransaction(trans,request,result);
  bool ownEntryRequest=(gPendingExec.active && request.position==0 &&
request.position_by==0 &&
  request.symbol==Symbol() && request.magic==gMagicCore &&
request.action==TRADE_ACTION_DEAL &&
   ((gPendingExec.direction==1 && request.type==ORDER_TYPE_BUY) ||
    (gPendingExec.direction==-1 && request.type==ORDER_TYPE_SELL)) &&
   MathAbs(request.volume-gPendingExec.requestedLots)<=AccountingVolumeTolerance()
&&
      request.comment=="RC1|"+gPendingExec.route+"|"+gPendingExec.mode &&
      MathAbs(request.price-gPendingExec.requestPrice)<=gTickSize*0.000001 &&
      MathAbs(request.sl-gPendingExec.slPrice)<=gTickSize*0.000001 &&
      MathAbs(request.tp-gPendingExec.tpPrice)<=gTickSize*0.000001 &&
      gPendingExec.requestID>0 && result.request_id==gPendingExec.requestID);
   if(trans.type==TRADE_TRANSACTION_REQUEST && ownEntryRequest)
   {
      BookDiagRequestResult(result);
      if(result.order>0) gPendingExec.orderTicket=result.order;
      if(result.deal>0) gPendingExec.resultDeal=result.deal;
      if(IsAcceptedRetcode(result.retcode))
      { if(!gPendingExec.accepted) requestsAcceptedToday++; gPendingExec.accepted=true;
}
   else if(IsFinalRejectedRetcode(result.retcode) && !gPendingExec.accepted &&
     gPendingExec.orderTicket==0 && gPendingExec.resultDeal==0)
    ResetPendingExec();
   if(gPendingExec.active) PersistRequestJournal(false);
  }
  if(trans.type==TRADE_TRANSACTION_REQUEST &&
MatchesExitRequest(request,result))
     CompletePendingExit(result);
  if(trans.type==TRADE_TRANSACTION_DEAL_ADD && trans.deal>0)
  {
     if(!ProcessAccountingDeal(trans.deal)) RememberDeferredDeal(trans.deal);
    }
    // Every transaction may reconcile a position state that lagged DEAL_ADD.
    gNeedsAccountingSync=true;
    SyncAccountingState(true);
}


double OnTester() { return 0.0; }


// Phase A wrappers: the inherited callback bodies above are unchanged.
// No observer runs inside SendOrder or between its final DOM sample and dispatch.
ENUM_APS ProcessArmedSignal()
{
   ENUM_APS outcome=ResponseBaseProcessArmedSignal();
   BookDiagAfterEvaluation();
   if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseArmedOutcome(outcome);
   return outcome;
}

void OnTick()
{
   ulong began=GetMicrosecondCount();
   ResponseBaseOnTick();
   if(Inp_ResponseMode==RESPONSE_OBSERVAR) ResponseAfterTick();
   BookPerfTick(began);
}

// BEGIN EMBEDDED ResponseObserver.mqh
// Phase A observational module; include after the unmodified strategy's types/globals.
// No return value is consumed by strategy code. ORIGINAL exits before all work.
#ifndef REMORA_RESPONSE_OBSERVER_V1
#define REMORA_RESPONSE_OBSERVER_V1
// BEGIN EMBEDDED ResponseMath.mqh
// Phase A only. Shared arithmetic/accumulator: MQL5 and the C++ numerical harness.
// No strategy types, market APIs, I/O, authorization or invented neutral-flow labels.
#ifndef REMORA_RESPONSE_MATH_V1
#define REMORA_RESPONSE_MATH_V1
// HOST_CPP_INACTIVE | #ifdef __cplusplus
// HOST_CPP_INACTIVE | #include <cmath>
// HOST_CPP_INACTIVE | bool ResponseFinite(double x) { return std::isfinite(x); }
// HOST_CPP_INACTIVE | double ResponseAbs(double x) { return std::fabs(x); }
// HOST_CPP_INACTIVE | #else
bool ResponseFinite(double x) { return MathIsValidNumber(x); }
double ResponseAbs(double x) { return MathAbs(x); }
// HOST_CPP_INACTIVE | #endif

// ORIGINAL_INCLUDE | #include "Include/BookMicroMath.mqh"
// BEGIN_INCORPORATED Include/BookMicroMath.mqh
// Observational arithmetic shared by MQL5 and the native C++ test harness.
// No strategy state, order API, tick retrieval, wall clock or I/O.
#ifndef REMORA_BOOK_MICRO_MATH_V1
#define REMORA_BOOK_MICRO_MATH_V1
// HOST_CPP_INACTIVE | #ifdef __cplusplus
// HOST_CPP_INACTIVE | #include <cmath>
// HOST_CPP_INACTIVE | bool BookMicroFinite(const double x) { return std::isfinite(x); }
// HOST_CPP_INACTIVE | double BookMicroAbs(const double x) { return std::fabs(x); }
// HOST_CPP_INACTIVE | #else
bool BookMicroFinite(const double x) { return MathIsValidNumber(x) && x!=EMPTY_VALUE; }
double BookMicroAbs(const double x) { return MathAbs(x); }
// HOST_CPP_INACTIVE | #endif

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
// HOST_CPP_INACTIVE | #ifdef __cplusplus
// HOST_CPP_INACTIVE | double BookMicroRank(const double value,const double sample[],const int count)
// HOST_CPP_INACTIVE | #else
double BookMicroRank(const double value,const double &sample[],const int count)
// HOST_CPP_INACTIVE | #endif
{
   if(count<=0) return -1;
   double less=0,equal=0;
   for(int i=0;i<count;i++)
   { if(sample[i]<value) less++; else if(sample[i]==value) equal++; }
   return (less+0.5*equal)/(double)count;
}
// HOST_CPP_INACTIVE | #ifdef __cplusplus
// HOST_CPP_INACTIVE | bool BookMicroER11(const double closes[],const int count,double &er,double &direction)
// HOST_CPP_INACTIVE | #else
bool BookMicroER11(const double &closes[],const int count,double &er,double &direction)
// HOST_CPP_INACTIVE | #endif
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
// END_INCORPORATED Include/BookMicroMath.mqh
struct ResponseFlow
{
   BookMicroFlow micro;
   long from_msc,to_msc,first_msc,last_msc;
   double first_price,last_price,vb,vs,vu;
   long eligible,known,invalid,rejected,zero_real;
   bool complete;
};
struct ResponseMetrics
{
   bool available,impact_available,volume_available,records_available;
   double v,delta,delta_pct_total,known_volume_pct,known_record_pct;
   double r_window,impact_signed,flow_balance_strength;
};
void ResponseFlowReset(ResponseFlow &f,long from_msc,long to_msc)
{
   BookMicroFlowReset(f.micro,from_msc,to_msc,0,0,0);
   f.from_msc=from_msc; f.to_msc=to_msc; f.first_msc=0; f.last_msc=0;
   f.first_price=0; f.last_price=0; f.vb=0; f.vs=0; f.vu=0;
   f.eligible=0; f.known=0; f.invalid=0; f.rejected=0; f.zero_real=0;
   f.complete=false;
   if(from_msc<0 || to_msc<from_msc) f.invalid++;
}
void ResponseFlowTick(ResponseFlow &f,double price,double volume,double real_volume,
                      long msc,bool buy,bool sell)
{
   // Same inclusion as the original first POC loop; all other validation is
   // observer-only. Invalid/ineligible feed records never change POC acceptance.
   if(!ResponseFinite(price) || !ResponseFinite(volume) || !ResponseFinite(real_volume))
   { f.invalid++; return; }
   if(price<0 || volume<0 || real_volume<0) { f.invalid++; return; }
   if(!(price>0 && volume>0)) { f.rejected++; return; }
   if(msc<f.from_msc || msc>f.to_msc || msc<=0 ||
      (f.eligible>0 && msc<f.last_msc))
   { f.invalid++; return; }
   BookMicroFlowTick(f.micro,price,volume,msc);
   if(f.eligible==0) { f.first_msc=msc; f.first_price=price; }
   f.last_msc=msc; f.last_price=price; f.eligible++;
   if(real_volume==0) f.zero_real++;
   if(buy && !sell) { f.vb+=volume; f.known++; }
   else if(sell && !buy) { f.vs+=volume; f.known++; }
   else f.vu+=volume;
   if(!ResponseFinite(f.vb) || !ResponseFinite(f.vs) || !ResponseFinite(f.vu))
      f.invalid++;
}
void ResponseComputeMetrics(const ResponseFlow &f,ResponseMetrics &m)
{
   m.available=false; m.impact_available=false;
   m.volume_available=false; m.records_available=false;
   m.v=0; m.delta=0; m.delta_pct_total=0; m.known_volume_pct=0;
   m.known_record_pct=0; m.r_window=0; m.impact_signed=0;
   m.flow_balance_strength=0;
   if(!f.complete || f.invalid>0 || f.eligible<=0 || f.from_msc>f.to_msc ||
      !ResponseFinite(f.vb) || !ResponseFinite(f.vs) || !ResponseFinite(f.vu) ||
      f.vb<0 || f.vs<0 || f.vu<0 || !ResponseFinite(f.first_price) ||
      !ResponseFinite(f.last_price) || f.first_price<=0 || f.last_price<=0 ||
      f.first_msc<f.from_msc || f.last_msc>f.to_msc || f.last_msc<f.first_msc)
      return;
   m.v=f.vb+f.vs+f.vu;
   m.delta=f.vb-f.vs;
   m.r_window=f.last_price-f.first_price;
   if(!ResponseFinite(m.v) || !ResponseFinite(m.delta) || !ResponseFinite(m.r_window))
      return;
   m.available=true;
   if(m.v>0)
   {
      m.delta_pct_total=(m.delta/m.v)*100.0;
      m.known_volume_pct=((f.vb+f.vs)/m.v)*100.0;
      m.flow_balance_strength=ResponseAbs(m.delta)/m.v;
      m.volume_available=ResponseFinite(m.delta_pct_total) &&
         ResponseFinite(m.known_volume_pct) && ResponseFinite(m.flow_balance_strength);
   }
   m.known_record_pct=((double)f.known/(double)f.eligible)*100.0;
   m.records_available=ResponseFinite(m.known_record_pct);
   if(m.delta!=0)
   {
      m.impact_signed=m.r_window/m.delta;
      m.impact_available=ResponseFinite(m.impact_signed);
   }
}
bool ResponseVolumePerPoint(double volume,double displacement,double tick_size,double &value)
{
   value=0;
   if(!ResponseFinite(volume) || volume<=0 || !ResponseFinite(displacement) ||
      !ResponseFinite(tick_size) || tick_size<=0 || ResponseAbs(displacement)<tick_size)
      return false;
   value=volume/ResponseAbs(displacement);
   return ResponseFinite(value);
}
#endif

// END EMBEDDED ResponseMath.mqh
#define RESPONSE_QUEUE_CAP 64
#define RESPONSE_WINDOW_CAP 4
#define RESPONSE_DRAIN_CAP 8
#define RESPONSE_DAILY_BYTES 16777216
#define RESPONSE_MAX_ROW_CHARS 16384

struct ResponseWindowSlot { bool used; ResponseFlow flow; };
struct ResponseRecord
{
   int kind; // 1 snapshot, 2 selected, 3 lifecycle, 4 outcome, 5 health, 6 live, 7 stage
   long event_msc;
   datetime live_bar,signal_bar;
   bool have_snapshot,have_now,have_prev,have_identity,c1_known,c1_current;
   bool wave_real;
   double tick_size,trigger;
   long age_sec;
   int outcome;
   bool bar_changed,have_live,have_stage;
   double live_effort,live_volume,live_average;
   double live_price,live_start;
   int live_direction;
   MqlTick stage_tick;
   long sample_overwrites;
   long dropped,gaps,io_errors;
   int hard_flips,hard_cancels;
   string suspension_reason;
   ulong after_last,after_count,after_total,after_max,timer_last,timer_count,timer_total,timer_max;
   MatrixSnapshot snapshot;
   BookMicroSnapshot micro;
   ResponseFlow now,prev;
   ArmedSignal identity;
};
ResponseWindowSlot gResponseWindows[RESPONSE_WINDOW_CAP];
ResponseRecord gResponseQueue[RESPONSE_QUEUE_CAP];
int gResponseWindowNext=0,gResponseHead=0,gResponseCount=0;
bool gResponseInitialized=false,gResponseSuspended=false,gResponseSelectedKnown=false;
bool gResponseLastActive=false,gResponseLatestSnapshotKnown=false;
ArmedSignal gResponseSelected;
MatrixSnapshot gResponseLatestSnapshot;
datetime gResponseLatestLiveBar=0,gResponseSelectedLiveBar=0,gResponseSelectedSignalBar=0;
datetime gResponseLastLifecycleSecond=0;
datetime gResponseLastSampleSecond=0;
int gResponseSampleIntervalSec=1;
double gResponseSelectedTrigger=0;
long gResponseDropped=0,gResponseGaps=0,gResponseIOErrors=0;
long gResponseLogin=0;
string gResponseServer="",gResponseSymbol="",gResponseRun="",gResponsePathBase="";
string gResponseFileDay="";
string gResponseSuspendReason="";
bool gResponseHealthAttempted=false;
bool gResponseTester=false;
int gResponseFile=INVALID_HANDLE;
ulong gResponseLastDrainMS=0,gResponseDayBytes=0,gResponseLastFlushMS=0;
ulong gResponseAfterCount=0,gResponseAfterTotalUS=0,gResponseAfterMaxUS=0;
ulong gResponseTimerCount=0,gResponseTimerTotalUS=0,gResponseTimerMaxUS=0;
ulong gResponseAfterLastUS=0,gResponseTimerLastUS=0;
bool gResponseLivePending=false,gResponseStagePending=false,gResponseLiveReal=false;
double gResponseLiveEffort=0,gResponseLiveVolume=0,gResponseLiveAverage=0;
int gResponseLiveDirection=0,gResponseLiveArmedDirection=0,gResponseStageArmedDirection=0;
datetime gResponseLiveArmedAt=0,gResponseLiveRegionEnd=0,gResponseStageArmedAt=0,gResponseStageRegionEnd=0;
MqlTick gResponseStageTick;
long gResponseLiveOverwrites=0,gResponseStageOverwrites=0;
ulong gResponseSelectionGeneration=0,gResponseLiveGeneration=0,gResponseStageGeneration=0;
double gResponseLivePrice=0,gResponseLiveStart=0;

// ORIGINAL_INCLUDE | #include "Include/BookMicrostructure.mqh"
// BEGIN_INCORPORATED Include/BookMicrostructure.mqh
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
// END_INCORPORATED Include/BookMicrostructure.mqh

bool ResponseEnabled()
{ return Inp_ResponseMode==RESPONSE_OBSERVAR; }

void ResponseSnapshotBegin()
{
   if(!ResponseEnabled()) return;
   if(!gResponseInitialized || gResponseSuspended) return;
   // Reset the observer generation before EVERY original matrix attempt, even
   // when that attempt returns before requesting POC. Queued copies are retained.
   for(int i=0;i<RESPONSE_WINDOW_CAP;i++) gResponseWindows[i].used=false;
}

int ResponseFindWindow(ulong from_msc,ulong to_msc)
{
   for(int i=0;i<RESPONSE_WINDOW_CAP;i++)
      if(gResponseWindows[i].used && gResponseWindows[i].flow.from_msc==(long)from_msc &&
         gResponseWindows[i].flow.to_msc==(long)to_msc) return i;
   return -1;
}
void ResponseWindowBegin(ulong from_msc,ulong to_msc)
{
   if(!ResponseEnabled()) return;
   if(!gResponseInitialized || gResponseSuspended) return;
   int index=ResponseFindWindow(from_msc,to_msc);
   if(index<0) { index=gResponseWindowNext; gResponseWindowNext=(index+1)%RESPONSE_WINDOW_CAP; }
   gResponseWindows[index].used=true;
   ResponseFlowReset(gResponseWindows[index].flow,(long)from_msc,(long)to_msc);
   BookMicroFreezeWindow(gResponseWindows[index].flow.micro);
}
void ResponseWindowTick(ulong from_msc,ulong to_msc,const MqlTick &tick)
{
   if(!ResponseEnabled()) return;
   if(!gResponseInitialized || gResponseSuspended) return;
   int index=ResponseFindWindow(from_msc,to_msc);
   if(index<0) { gResponseGaps++; return; }
   ResponseFlowTick(gResponseWindows[index].flow,tick.last,(double)tick.volume,
      tick.volume_real,tick.time_msc,(tick.flags&TICK_FLAG_BUY)!=0,(tick.flags&TICK_FLAG_SELL)!=0);
}
void ResponseWindowFinish(ulong from_msc,ulong to_msc)
{
   if(!ResponseEnabled()) return;
   if(!gResponseInitialized || gResponseSuspended) return;
   int index=ResponseFindWindow(from_msc,to_msc);
   if(index>=0) gResponseWindows[index].flow.complete=true;
}

// Hooks copy bounded raw records only; all CSV formatting and disk I/O is deferred.
void ResponseRecordReset(ResponseRecord &r,int kind)
{
   ZeroMemory(r); r.kind=kind; r.outcome=-1;
   r.event_msc=(long)TimeTradeServer()*1000; // server clock, second resolution
   r.tick_size=gTickSize; r.wave_real=wwUseReal;
   r.dropped=gResponseDropped; r.gaps=gResponseGaps; r.io_errors=gResponseIOErrors;
   r.suspension_reason=gResponseSuspendReason;
   r.hard_flips=hardFlipsPerDay; r.hard_cancels=armedCancelHard;
   r.after_last=gResponseAfterLastUS; r.after_count=gResponseAfterCount;
   r.after_total=gResponseAfterTotalUS; r.after_max=gResponseAfterMaxUS;
   r.timer_last=gResponseTimerLastUS; r.timer_count=gResponseTimerCount;
   r.timer_total=gResponseTimerTotalUS; r.timer_max=gResponseTimerMaxUS;
}
void ResponseQueue(const ResponseRecord &r)
{
   if(gResponseSuspended) { gResponseDropped++; gResponseGaps++; return; }
   if(gResponseCount>=RESPONSE_QUEUE_CAP)
   {
      gResponseDropped+=gResponseCount+1; gResponseGaps+=gResponseCount+1;
      gResponseCount=0; gResponseHead=0;
      gResponseSuspended=true; gResponseSuspendReason="QUEUE_CAPACITY"; return;
   }
   int index=(gResponseHead+gResponseCount)%RESPONSE_QUEUE_CAP;
   gResponseQueue[index]=r; gResponseCount++;
}
bool ResponseSameIdentity(const ArmedSignal &a,const ArmedSignal &b)
{
   return a.armedAt==b.armedAt && a.regionEndTime==b.regionEndTime &&
      a.dir==b.dir && a.route==b.route && a.mode==b.mode &&
      a.regionHigh==b.regionHigh && a.regionLow==b.regionLow;
}
void ResponseAttachIdentity(ResponseRecord &r)
{
   if(!gResponseSelectedKnown) return;
   r.have_identity=true; r.identity=gResponseSelected;
   r.trigger=gResponseSelectedTrigger; r.live_bar=gResponseSelectedLiveBar;
   r.signal_bar=gResponseSelectedSignalBar;
   long now_sec=r.event_msc/1000;
   r.age_sec=(now_sec>=(long)r.identity.armedAt)?now_sec-(long)r.identity.armedAt:-1;
   r.bar_changed=(lastSignalBarTime!=r.live_bar);
   if(gResponseLatestSnapshotKnown && gResponseLatestLiveBar==lastSignalBarTime)
   {
      r.have_snapshot=true; r.snapshot=gResponseLatestSnapshot;
      r.c1_known=(r.snapshot.status==MSS_OK);
      r.c1_current=(r.identity.route=="ABS")?r.snapshot.c1:r.snapshot.c1Cont;
   }
}
// Called inside original calculations, before the final DOM reading. Scalars only.
// No sample timestamp is manufactured for a live-wave computation.
void ResponseLiveWave(double effort,double volume,double average,int direction,double price)
{
   if(!ResponseEnabled()) return;
   if(!gResponseInitialized || gResponseSuspended) return;
   if(gResponseLivePending) gResponseLiveOverwrites++;
   gResponseLiveEffort=effort; gResponseLiveVolume=volume; gResponseLiveAverage=average;
   gResponseLiveDirection=direction; gResponseLiveReal=wwUseReal;
   gResponseLivePrice=price;
   gResponseLiveStart=(direction==wwDirClosed)?wwWaveStartPrice:wwCloseRef;
   gResponseLiveGeneration=(gResponseSelectedKnown && ResponseSameIdentity(armed,gResponseSelected))?
      gResponseSelectionGeneration:0;
   gResponseLiveArmedAt=armed.armedAt; gResponseLiveRegionEnd=armed.regionEndTime;
   gResponseLiveArmedDirection=armed.dir; gResponseLivePending=true;
}
void ResponseStageSample(const MqlTick &tick)
{
   if(!ResponseEnabled()) return;
   if(!gResponseInitialized || gResponseSuspended) return;
   if(gResponseStagePending) gResponseStageOverwrites++;
   gResponseStageTick=tick;
   gResponseStageGeneration=(gResponseSelectedKnown && ResponseSameIdentity(armed,gResponseSelected))?
      gResponseSelectionGeneration:0;
   gResponseStageArmedAt=armed.armedAt; gResponseStageRegionEnd=armed.regionEndTime;
   gResponseStageArmedDirection=armed.dir; gResponseStagePending=true;
}
void ResponseCapturePendingSamples()
{
   datetime sample_second=TimeTradeServer();
   // Match the inherited timer cadence (live=1s, tester=60s). Preserve the last
   // original sample between emissions; every overwrite is counted explicitly.
   if(gResponseLastSampleSecond>0 && sample_second-gResponseLastSampleSecond<gResponseSampleIntervalSec)
      return;
   gResponseLastSampleSecond=sample_second;
   if(gResponseLivePending)
   {
      ResponseRecord r; ResponseRecordReset(r,6);
      if(gResponseLiveGeneration>0 && gResponseLiveGeneration==gResponseSelectionGeneration)
         ResponseAttachIdentity(r);
      // This event is collected after financial work and is never backfilled into SNAPSHOT.
      r.have_live=true; r.live_effort=gResponseLiveEffort; r.live_volume=gResponseLiveVolume;
      r.live_average=gResponseLiveAverage; r.live_direction=gResponseLiveDirection;
      r.live_price=gResponseLivePrice; r.live_start=gResponseLiveStart;
      r.wave_real=gResponseLiveReal; r.sample_overwrites=gResponseLiveOverwrites;
      ResponseQueue(r); gResponseLivePending=false;
   }
   if(gResponseStagePending)
   {
      ResponseRecord r; ResponseRecordReset(r,7);
      if(gResponseStageGeneration>0 && gResponseStageGeneration==gResponseSelectionGeneration)
         ResponseAttachIdentity(r);
      r.have_stage=true; r.stage_tick=gResponseStageTick;
      r.sample_overwrites=gResponseStageOverwrites;
      ResponseQueue(r); gResponseStagePending=false;
   }
}
void ResponseCaptureSnapshot(const MatrixSnapshot &s,datetime live_bar)
{
   if(!ResponseEnabled()) return;
   if(!gResponseInitialized || gResponseSuspended) return;
   ResponseRecord r; ResponseRecordReset(r,1);
   r.have_snapshot=true; r.snapshot=s; r.live_bar=live_bar;
   // The caller supplies the live bar clock used by the original POC requests.
   // Closed signal time is explicit and never borrowed from a previous cycle.
   if(gCachedMicroReady && gCachedMicroBar==live_bar && gLastTelemetrySignalBar>0)
      r.signal_bar=gLastTelemetrySignalBar;
   ulong end=(ulong)live_bar*1000,span=(ulong)Inp_POC_WindowSec*1000;
   if(end>2*span)
   {
      int now=ResponseFindWindow(end-span,end-1);
      int prev=ResponseFindWindow(end-2*span,end-span-1);
      if(now>=0) { r.now=gResponseWindows[now].flow; r.have_now=true; }
      if(prev>=0) { r.prev=gResponseWindows[prev].flow; r.have_prev=true; }
   }
   if(!r.have_now || !r.have_prev) gResponseGaps++;
   gResponseLatestSnapshot=s; gResponseLatestSnapshotKnown=true;
   gResponseLatestLiveBar=live_bar;
   BookMicroCapture(r); // immutable observer metrics; original snapshot unchanged
   ResponseQueue(r);
}
void ResponseSelected(const MatrixSnapshot &s,const ArmedSignal &identity,double trigger,
                      datetime live_bar)
{
   if(!ResponseEnabled()) return;
   if(!gResponseInitialized || gResponseSuspended) return;
   if(gResponseSelectedKnown && gResponseLastActive && !ResponseSameIdentity(identity,gResponseSelected))
   {
      ResponseRecord previous; ResponseRecordReset(previous,3); ResponseAttachIdentity(previous);
      previous.outcome=-2; ResponseQueue(previous); // original replacement; reason remains unknown
   }
   gResponseSelected=identity; gResponseSelectedKnown=true;
   gResponseSelectionGeneration++;
   gResponseSelectedTrigger=trigger; gResponseSelectedLiveBar=live_bar;
   gResponseSelectedSignalBar=identity.regionEndTime; // actual original closed-bar clock
   gResponseLastActive=true;
   ResponseRecord r; ResponseRecordReset(r,2); ResponseAttachIdentity(r);
   r.have_snapshot=true; r.snapshot=s;
   ResponseQueue(r);
}
void ResponseArmedOutcome(ENUM_APS outcome)
{
   if(!ResponseEnabled()) return;
   if(!gResponseInitialized || !gResponseSelectedKnown || gResponseSuspended) return;
   // Repeated STILL_ARMED outcomes are represented by bounded periodic samples.
   if(outcome==APS_STILL_ARMED) return;
   ResponseRecord r; ResponseRecordReset(r,4); ResponseAttachIdentity(r);
   r.outcome=(int)outcome; ResponseQueue(r);
}
void ResponseObserveLifecycle()
{
   if(!gResponseSelectedKnown || gResponseSuspended) return;
   bool same=armed.active && ResponseSameIdentity(armed,gResponseSelected);
   datetime now=TimeTradeServer();
   if(same && gResponseLastActive && gResponseLastLifecycleSecond>0 &&
      now-gResponseLastLifecycleSecond<gResponseSampleIntervalSec) return;
   if(!same && !gResponseLastActive) return;
   ResponseRecord r; ResponseRecordReset(r,3); ResponseAttachIdentity(r);
   // outcome -1 = sampled active; -2 = original identity ended/changed, reason unknown.
   r.outcome=same?-1:-2;
   ResponseQueue(r); gResponseLastActive=same; gResponseLastLifecycleSecond=now;
}
void ResponseAfterTick()
{
   if(!ResponseEnabled()) return;
   if(!gResponseInitialized) return;
   ulong begin=GetMicrosecondCount();
   ResponseCapturePendingSamples();
   ResponseObserveLifecycle();
   ulong elapsed=GetMicrosecondCount()-begin;
   gResponseAfterLastUS=elapsed; gResponseAfterCount++; gResponseAfterTotalUS+=elapsed;
   if(elapsed>gResponseAfterMaxUS) gResponseAfterMaxUS=elapsed;
}

string ResponseNum(double value,bool available=true)
{ return available && ResponseFinite(value)?StringFormat("%.17g",value):""; }
string ResponseBool(bool value) { return value?"1":"0"; }
void ResponseCell(string &row,string value)
{
   StringReplace(value,"\"","\"\"");
   if(row!="") row+=";";
   row+="\""+value+"\"";
}
string ResponseComponent(string value)
{
   string result="";
   for(int i=0;i<StringLen(value);i++)
   {
      ushort c=StringGetCharacter(value,i);
      if((c>=48 && c<=57) || (c>=65 && c<=90) || (c>=97 && c<=122))
         result+=StringSubstr(value,i,1);
      else result+=StringFormat("_%04X",(uint)c); // reversible; '_' itself is encoded
   }
   return result;
}
string ResponseDay(long msc)
{ return TimeToString((datetime)(msc/1000),TIME_DATE); }
string ResponseAvailability(const ResponseFlow &f,bool matched)
{
   if(!matched) return "UNMATCHED";
   if(!f.complete) return "INCOMPLETE";
   if(f.invalid>0) return "INVALID";
   if(f.eligible==0) return "EMPTY";
   ResponseMetrics m; ResponseComputeMetrics(f,m);
   return m.available?"AVAILABLE":"INVALID";
}
string ResponseOutcome(int outcome)
{
   if(outcome==-1) return "SAMPLED_ACTIVE";
   if(outcome==-2) return "ORIGINAL_IDENTITY_ENDED_REASON_UNKNOWN";
   if(outcome==APS_ENDED_REEVAL_ALLOWED) return "APS_ENDED_REEVAL_ALLOWED";
   if(outcome==APS_ENDED_FAIL_CLOSED) return "APS_ENDED_FAIL_CLOSED";
   if(outcome==APS_TRADE_OR_POSITION) return "APS_TRADE_OR_POSITION_NOT_FILL_PROOF";
   if(outcome==APS_ENTRY_READY) return "APS_ENTRY_READY";
   return "UNKNOWN";
}
string ResponseHeader()
{
   return "schema;event;run_id;server_day;observed_time_msc;account;server;symbol;magic;signal_bar;route;mode;direction;armed_at;region_end;region_high;region_low;trigger;armed_age_sec;c1_current_status;outcome;window_role;window_from_msc;window_to_msc;first_msc;last_msc;first_price;last_price;vb;vs;vu;v;delta;delta_pct_total;known_volume_pct;known_record_pct;r_window;r_between;impact_signed;flow_balance_strength;d_r_window;d_delta;eligible_records;known_records;invalid_records;zero_real_volume_records;availability;coverage_status;volume_source;ww_accum_volume;ww_net_distance;ww_wave_bars;ww_wave_age_sec;ww_direction;ww_effort;ww_state;ww_volume_per_point;abs_divergence;abs_stall_strict;abs_following_reaction;abs_following_extension;abs_valid;cont_valid;abs_c1;cont_c1;matrix_status;dropped;gaps;io_errors;rejected_records;live_bar;bar_changed;aftertick_last_us;aftertick_count;aftertick_total_us;aftertick_max_us;timer_last_us;timer_count;timer_total_us;timer_max_us;live_wave_available;live_wave_volume;live_wave_average;live_wave_effort;live_wave_direction;live_wave_state;live_wave_sample_time_status;stage_sample_time_msc;stage_bid;stage_ask;stage_last;stage_flags;stage_directional_last_minus_trigger;trajectory_coverage;dwell_time_status;integral_volume_status;sample_overwrites;hard_flips_per_day;armed_cancel_hard;suspension_reason;live_wave_price;live_wave_start_reference;live_wave_net_displacement;live_wave_volume_per_point;live_wave_age_status;ww_volume_status;ww_volume_source;live_volume_status;"+BookMicroHeader();
}
string ResponseFormat(const ResponseRecord &r,int window_role)
{
   bool is_window=(window_role>0);
   ResponseFlow f; ZeroMemory(f);
   bool matched=false;
   if(window_role==1) { f=r.now; matched=r.have_now; }
   if(window_role==2) { f=r.prev; matched=r.have_prev; }
   ResponseMetrics m; ResponseComputeMetrics(f,m);
   bool measured=is_window && matched && m.available;
   bool have_s=r.have_snapshot;
   bool full_s=have_s && r.snapshot.status==MSS_OK;
   int direction=0;
   string route="NONE",mode="NONE";
   if(r.have_identity) { direction=r.identity.dir; route=r.identity.route; mode=r.identity.mode; }
   else if(full_s)
   {
      if(r.snapshot.absValid && r.snapshot.contValid) { route="CONFLICT"; mode="CONFLICT"; }
      else if(r.snapshot.absValid)
      { route="ABS"; mode=r.snapshot.turboAbs?"TURBO":"BASE"; direction=r.snapshot.dir; }
      else if(r.snapshot.contValid)
      { route="CONT"; mode=r.snapshot.turboCont?"TURBO_CONT":"BASE_CONT"; direction=r.snapshot.dirCont; }
   }
   string event=is_window?"WINDOW":(r.kind==1?"SNAPSHOT":(r.kind==2?"SELECTED":
      (r.kind==3?"LIFECYCLE":(r.kind==4?"OUTCOME":(r.kind==6?"LIVE_WAVE":
       (r.kind==7?"STAGE_SAMPLE":"HEALTH"))))));
   string row="";
   ResponseCell(row,"1"); ResponseCell(row,event); ResponseCell(row,gResponseRun);
   ResponseCell(row,ResponseDay(r.event_msc)); ResponseCell(row,(string)r.event_msc);
   ResponseCell(row,(string)gResponseLogin); ResponseCell(row,gResponseServer);
   ResponseCell(row,gResponseSymbol); ResponseCell(row,(string)gMagicCore);
   ResponseCell(row,r.signal_bar>0?(string)r.signal_bar:"");
   ResponseCell(row,route); ResponseCell(row,mode); ResponseCell(row,direction!=0?(string)direction:"");
   ResponseCell(row,r.have_identity?(string)r.identity.armedAt:"");
   ResponseCell(row,r.have_identity?(string)r.identity.regionEndTime:"");
   ResponseCell(row,ResponseNum(r.identity.regionHigh,r.have_identity));
   ResponseCell(row,ResponseNum(r.identity.regionLow,r.have_identity));
   ResponseCell(row,ResponseNum(r.trigger,r.have_identity));
   ResponseCell(row,r.have_identity && r.age_sec>=0?(string)r.age_sec:"");
   ResponseCell(row,r.c1_known?(r.c1_current?"VALID":"INVALID"):"UNAVAILABLE");
   ResponseCell(row,r.kind==3 || r.kind==4?ResponseOutcome(r.outcome):"UNAVAILABLE");
   ResponseCell(row,window_role==1?"NOW":(window_role==2?"PREV":""));
   ulong end=(ulong)r.live_bar*1000,span=(ulong)Inp_POC_WindowSec*1000;
   bool requested=is_window && end>2*span;
   ResponseCell(row,requested?(string)(window_role==1?end-span:end-2*span):"");
   ResponseCell(row,requested?(string)(window_role==1?end-1:end-span-1):"");
   ResponseCell(row,measured?(string)f.first_msc:""); ResponseCell(row,measured?(string)f.last_msc:"");
   ResponseCell(row,ResponseNum(f.first_price,measured)); ResponseCell(row,ResponseNum(f.last_price,measured));
   ResponseCell(row,ResponseNum(f.vb,measured)); ResponseCell(row,ResponseNum(f.vs,measured));
   ResponseCell(row,ResponseNum(f.vu,measured)); ResponseCell(row,ResponseNum(m.v,measured));
   ResponseCell(row,ResponseNum(m.delta,measured));
   ResponseCell(row,ResponseNum(m.delta_pct_total,measured && m.volume_available));
   ResponseCell(row,ResponseNum(m.known_volume_pct,measured && m.volume_available));
   ResponseCell(row,ResponseNum(m.known_record_pct,measured && m.records_available));
   ResponseCell(row,ResponseNum(m.r_window,measured));
   ResponseCell(row,ResponseNum(r.snapshot.priceMove,have_s && r.snapshot.windowsValid));
   ResponseCell(row,ResponseNum(m.impact_signed,measured && m.impact_available));
   ResponseCell(row,ResponseNum(m.flow_balance_strength,measured && m.volume_available));
   ResponseCell(row,ResponseNum(direction*m.r_window,measured && direction!=0));
   ResponseCell(row,ResponseNum(direction*m.delta,measured && direction!=0));
   ResponseCell(row,is_window && matched?(string)f.eligible:"");
   ResponseCell(row,is_window && matched?(string)f.known:"");
   ResponseCell(row,is_window && matched?(string)f.invalid:"");
   ResponseCell(row,is_window && matched?(string)f.zero_real:"");
   ResponseCell(row,is_window?ResponseAvailability(f,matched):(have_s?"AVAILABLE":"UNAVAILABLE"));
   string coverage="UNAVAILABLE";
   if(measured && m.volume_available)
      coverage=(f.vb+f.vs==0)?"KNOWN_ZERO":(f.vu==0?"FULL":"PARTIAL");
   ResponseCell(row,coverage);
   ResponseCell(row,is_window?"TRADE_TICK_VOLUME":(have_s || r.have_live?(r.wave_real?"WW_REAL":"WW_TICK"):""));
   bool ww=have_s && r.snapshot.wwok;
   ResponseCell(row,ResponseNum(r.snapshot.wwAccumVolume,ww));
   ResponseCell(row,ResponseNum(r.snapshot.wwDistancePts,ww));
   ResponseCell(row,ww?(string)r.snapshot.wwWaveBars:"");
   ResponseCell(row,ww && r.snapshot.wwWaveAgeAvailable?(string)r.snapshot.wwWaveAgeSec:"");
   ResponseCell(row,ww?(string)r.snapshot.waveDir:"");
   ResponseCell(row,ResponseNum(r.snapshot.effort,ww));
   ResponseCell(row,ww?"CURRENT_WAVE_CLOSED_BARS_NOT_PROVEN_ENDED":"UNAVAILABLE");
   double volume_per_point=0;
   bool vpp=ww && ResponseVolumePerPoint(r.snapshot.wwAccumVolume,r.snapshot.wwDistancePts,r.tick_size,volume_per_point);
   ResponseCell(row,ResponseNum(volume_per_point,vpp));
   ResponseCell(row,full_s?ResponseBool(r.snapshot.absDivergence):"");
   ResponseCell(row,full_s?ResponseBool(r.snapshot.absStallStrict):"");
   ResponseCell(row,full_s?ResponseBool(r.snapshot.absFollowingReaction):"");
   ResponseCell(row,full_s?ResponseBool(r.snapshot.absFollowingExtension):"");
   ResponseCell(row,full_s?ResponseBool(r.snapshot.absValid):"");
   ResponseCell(row,full_s?ResponseBool(r.snapshot.contValid):"");
   ResponseCell(row,full_s?ResponseBool(r.snapshot.c1):"");
   ResponseCell(row,full_s?ResponseBool(r.snapshot.c1Cont):"");
   ResponseCell(row,have_s?EnumToString(r.snapshot.status):"");
   ResponseCell(row,(string)r.dropped); ResponseCell(row,(string)r.gaps);
   ResponseCell(row,(string)r.io_errors); ResponseCell(row,is_window && matched?(string)f.rejected:"");
   ResponseCell(row,r.live_bar>0?(string)r.live_bar:"");
   ResponseCell(row,r.have_identity?ResponseBool(r.bar_changed):"");
   ResponseCell(row,(string)r.after_last); ResponseCell(row,(string)r.after_count);
   ResponseCell(row,(string)r.after_total); ResponseCell(row,(string)r.after_max);
   ResponseCell(row,(string)r.timer_last); ResponseCell(row,(string)r.timer_count);
   ResponseCell(row,(string)r.timer_total); ResponseCell(row,(string)r.timer_max);
   bool live=r.have_live && ResponseFinite(r.live_volume) && r.live_volume>=0 &&
      ResponseFinite(r.live_average) && r.live_average>=0 && ResponseFinite(r.live_effort) &&
      (r.live_direction==1 || r.live_direction==-1);
   ResponseCell(row,ResponseBool(live));
   ResponseCell(row,ResponseNum(r.live_volume,live)); ResponseCell(row,ResponseNum(r.live_average,live));
   ResponseCell(row,ResponseNum(r.live_effort,live)); ResponseCell(row,live?(string)r.live_direction:"");
   ResponseCell(row,r.have_live?"PARTIAL_M1_LIVE":"UNAVAILABLE");
   ResponseCell(row,"UNAVAILABLE");
   ResponseCell(row,r.have_stage && r.stage_tick.time_msc>0?(string)r.stage_tick.time_msc:"");
   ResponseCell(row,ResponseNum(r.stage_tick.bid,r.have_stage));
   ResponseCell(row,ResponseNum(r.stage_tick.ask,r.have_stage));
   ResponseCell(row,ResponseNum(r.stage_tick.last,r.have_stage));
   ResponseCell(row,r.have_stage?(string)r.stage_tick.flags:"");
   ResponseCell(row,ResponseNum(direction*(r.stage_tick.last-r.trigger),
      r.have_stage && r.have_identity && direction!=0 && r.stage_tick.last>0));
   ResponseCell(row,r.have_stage?"SAMPLED_CALLBACK_ONLY":"UNAVAILABLE");
   ResponseCell(row,"UNAVAILABLE"); ResponseCell(row,"UNAVAILABLE");
   ResponseCell(row,r.have_live || r.have_stage?(string)r.sample_overwrites:"");
   ResponseCell(row,(string)r.hard_flips); ResponseCell(row,(string)r.hard_cancels);
   // Health is generated after suspension; historical snapshot rows do not use this later state.
   ResponseCell(row,r.kind==5?r.suspension_reason:"");
   bool live_displacement=live && ResponseFinite(r.live_price) && r.live_price>0 &&
      ResponseFinite(r.live_start) && r.live_start>0;
   double live_move=r.live_price-r.live_start,live_vpp=0;
   bool live_vpp_available=live_displacement &&
      ResponseVolumePerPoint(r.live_volume,live_move,r.tick_size,live_vpp);
   ResponseCell(row,ResponseNum(r.live_price,live_displacement));
   ResponseCell(row,ResponseNum(r.live_start,live_displacement));
   ResponseCell(row,ResponseNum(live_move,live_displacement));
   ResponseCell(row,ResponseNum(live_vpp,live_vpp_available));
   ResponseCell(row,"UNAVAILABLE");
   string live_volume_status="UNAVAILABLE",ww_volume_status="UNAVAILABLE";
   if(r.have_live && live) live_volume_status=(r.live_volume==0)?
      (r.wave_real?"ZERO_REAL_VOLUME":"ZERO_TICK_VOLUME"):
      (r.live_average==0?"ZERO_REFERENCE_AVERAGE":"POSITIVE_VOLUME");
   if(ww) ww_volume_status=(!ResponseFinite(r.snapshot.wwAccumVolume) || r.snapshot.wwAccumVolume<0)?
      "INVALID_VOLUME":(r.snapshot.wwAccumVolume==0?
      (r.wave_real?"ZERO_REAL_VOLUME":"ZERO_TICK_VOLUME"):"POSITIVE_VOLUME");
   ResponseCell(row,ww_volume_status);
   ResponseCell(row,ww?(r.wave_real?"WW_REAL":"WW_TICK"):"");
   ResponseCell(row,live_volume_status);
   BookMicroCells(row,r.micro); // explicit micro_window timestamps identify NOW metrics
   return row+"\r\n";
}

bool ResponseWrite(string row)
{
   if(StringLen(row)>RESPONSE_MAX_ROW_CHARS)
   { gResponseDropped++; gResponseGaps++; gResponseSuspended=true;
     gResponseSuspendReason="ROW_LIMIT"; return false; }
   uchar bytes[];
   int expected=StringToCharArray(row,bytes,0,WHOLE_ARRAY,CP_UTF8)-1;
   if(expected<=0 || gResponseDayBytes+(ulong)expected>RESPONSE_DAILY_BYTES)
   { gResponseDropped++; gResponseGaps++; gResponseSuspended=true;
     gResponseSuspendReason="DAILY_BYTE_LIMIT"; return false; }
   ResetLastError();
   uint written=FileWriteString(gResponseFile,row);
   if(written!=(uint)expected || GetLastError()!=0)
   { gResponseIOErrors++; gResponseGaps++; gResponseSuspended=true;
     gResponseSuspendReason="WRITE_IO_ERROR"; return false; }
   gResponseDayBytes+=written;
   return true;
}
bool ResponseOpen()
{
   if(gResponseFile!=INVALID_HANDLE) return true;
   string path=gResponsePathBase+"_"+gResponseFileDay;
   StringReplace(path,".","_"); // day separators; suffix below restores extension
   path+=".csv";
   // Never truncate an existing artifact, even if the unlikely run-id collision occurs.
   ResetLastError(); bool exists=FileIsExist(path); int probe_error=GetLastError();
   if(StringLen(path)>240 || exists || (probe_error!=0 && probe_error!=ERR_FILE_NOT_EXIST))
   { gResponseIOErrors++; gResponseGaps++; gResponseSuspended=true;
     gResponseSuspendReason="PATH_OR_EXISTING_ARTIFACT"; return false; }
   gResponseFile=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ,0,CP_UTF8);
   if(gResponseFile==INVALID_HANDLE)
   { gResponseIOErrors++; gResponseGaps++; gResponseSuspended=true;
     gResponseSuspendReason="OPEN_IO_ERROR"; return false; }
   if(FileSize(gResponseFile)!=0)
   { FileClose(gResponseFile); gResponseFile=INVALID_HANDLE;
     gResponseIOErrors++; gResponseGaps++; gResponseSuspended=true;
     gResponseSuspendReason="EXISTING_ARTIFACT_AFTER_OPEN"; return false; }
   return ResponseWrite(ResponseHeader()+"\r\n");
}
void ResponseDrain()
{
   if(gResponseSuspended || gResponseCount==0 || !ResponseOpen()) return;
   // At most eight records (24 CSV rows) per timer, never an unbounded recovery loop.
   for(int i=0;i<RESPONSE_DRAIN_CAP && gResponseCount>0;i++)
   {
      ResponseRecord r=gResponseQueue[gResponseHead];
      if(!ResponseWrite(ResponseFormat(r,0))) return;
      if(r.kind==1)
      {
         if(!ResponseWrite(ResponseFormat(r,1))) return;
         if(!ResponseWrite(ResponseFormat(r,2))) return;
      }
      ZeroMemory(gResponseQueue[gResponseHead]);
      gResponseHead=(gResponseHead+1)%RESPONSE_QUEUE_CAP; gResponseCount--;
   }
}
void ResponseTimer()
{
   if(!ResponseEnabled()) return;
   if(!gResponseInitialized) return;
   ulong begin=GetMicrosecondCount(),now=GetTickCount64();
   if(!gResponseTester && gResponseLastDrainMS>0 && now-gResponseLastDrainMS<1000) return;
   gResponseLastDrainMS=now;
   string day=ResponseDay((long)TimeTradeServer()*1000);
   if(day!=gResponseFileDay)
   {
      if(gResponseFile!=INVALID_HANDLE) { FileClose(gResponseFile); gResponseFile=INVALID_HANDLE; }
      gResponseFileDay=day; gResponseDayBytes=0;
      // Daily-cap suspension resumes only on the next server day. I/O failure
      // remains suspended: retries must follow an external correction/restart.
      if(gResponseIOErrors==0 && gResponseSuspendReason=="DAILY_BYTE_LIMIT")
      { gResponseSuspended=false; gResponseSuspendReason=""; gResponseHealthAttempted=false; }
   }
   ResponseCapturePendingSamples(); ResponseObserveLifecycle();
   ResponseDrain();
   if(gResponseSuspended && !gResponseHealthAttempted)
   {
      gResponseHealthAttempted=true;
      gResponseDropped+=gResponseCount; gResponseGaps+=gResponseCount;
      gResponseCount=0; gResponseHead=0;
      // One bounded best-effort health record. No blind retry after an I/O failure.
      // If disk/budget is exhausted, counters remain available only in module memory.
      if(gResponseIOErrors==0 && ResponseOpen())
      {
         ResponseRecord health; ResponseRecordReset(health,5);
         ResponseWrite(ResponseFormat(health,0));
      }
      PrintFormat("[RESPONSE_A][SUSPENDED] reason=%s dropped=%I64d gaps=%I64d io_errors=%I64d; original trading/financial rules remain in control",
         gResponseSuspendReason,gResponseDropped,gResponseGaps,gResponseIOErrors);
   }
   if(!gResponseSuspended && gResponseIOErrors==0 && gResponseFile!=INVALID_HANDLE &&
      now-gResponseLastFlushMS>=30000)
   {
      ResetLastError(); FileFlush(gResponseFile);
      if(GetLastError()!=0) { gResponseIOErrors++; gResponseGaps++; gResponseSuspended=true;
         gResponseSuspendReason="FLUSH_IO_ERROR"; }
      gResponseLastFlushMS=now;
   }
   ulong elapsed=GetMicrosecondCount()-begin;
   gResponseTimerLastUS=elapsed; gResponseTimerCount++; gResponseTimerTotalUS+=elapsed;
   if(elapsed>gResponseTimerMaxUS) gResponseTimerMaxUS=elapsed;
}
void ResponseInit()
{
   if(!ResponseEnabled()) return;
   // Explicit bounded reset supports repeated init cycles without borrowing an
   // earlier run's queue, identity, collector generation or pending samples.
   if(gResponseFile!=INVALID_HANDLE) FileClose(gResponseFile);
   gResponseFile=INVALID_HANDLE;
   for(int i=0;i<RESPONSE_QUEUE_CAP;i++) ZeroMemory(gResponseQueue[i]);
   for(int i=0;i<RESPONSE_WINDOW_CAP;i++) ZeroMemory(gResponseWindows[i]);
   ZeroMemory(gResponseSelected); ZeroMemory(gResponseLatestSnapshot); ZeroMemory(gResponseStageTick);
   gResponseWindowNext=0; gResponseHead=0; gResponseCount=0;
   gResponseInitialized=false; gResponseSuspended=false; gResponseSelectedKnown=false;
   gResponseLastActive=false; gResponseLatestSnapshotKnown=false;
   gResponseLatestLiveBar=0; gResponseSelectedLiveBar=0; gResponseSelectedSignalBar=0;
   gResponseLastLifecycleSecond=0; gResponseLastSampleSecond=0; gResponseSelectedTrigger=0;
   gResponseDropped=0; gResponseGaps=0; gResponseIOErrors=0;
   gResponseHealthAttempted=false; gResponseSuspendReason="";
   gResponseLastDrainMS=0; gResponseDayBytes=0; gResponseLastFlushMS=0;
   gResponseAfterCount=0; gResponseAfterTotalUS=0; gResponseAfterMaxUS=0;
   gResponseTimerCount=0; gResponseTimerTotalUS=0; gResponseTimerMaxUS=0;
   gResponseAfterLastUS=0; gResponseTimerLastUS=0;
   gResponseLivePending=false; gResponseStagePending=false;
   gResponseLiveOverwrites=0; gResponseStageOverwrites=0;
   gResponseSelectionGeneration=0; gResponseLiveGeneration=0; gResponseStageGeneration=0;
   gResponseLogin=AccountInfoInteger(ACCOUNT_LOGIN);
   gResponseServer=AccountInfoString(ACCOUNT_SERVER); gResponseSymbol=Symbol();
   gResponseRun=(string)ChartID()+"_"+(string)GetMicrosecondCount();
   gResponsePathBase="ResponseA1_"+(string)gResponseLogin+"_"+ResponseComponent(gResponseServer)+
      "_"+ResponseComponent(gResponseSymbol)+"_"+(string)gMagicCore+"_"+gResponseRun;
   gResponseFileDay=ResponseDay((long)TimeTradeServer()*1000);
   gResponseTester=(MQLInfoInteger(MQL_TESTER)!=0);
   gResponseSampleIntervalSec=gResponseTester?60:1;
   gResponseInitialized=true;
   BookMicroInit();
   if(StringLen(gResponsePathBase)>210)
   { gResponseSuspended=true; gResponseIOErrors++; gResponseGaps++;
     gResponseSuspendReason="ENCODED_NAMESPACE_TOO_LONG"; }
   ResponseRecord r; ResponseRecordReset(r,5); ResponseQueue(r);
}
void ResponseDeinit()
{
   if(!ResponseEnabled()) return;
   if(!gResponseInitialized) return;
   ResponseDrain(); // one bounded final batch; no waiting for queued events
   if(gResponseCount>0) { gResponseDropped+=gResponseCount; gResponseGaps+=gResponseCount; }
   if(gResponseFile!=INVALID_HANDLE)
   {
      // A known I/O failure is not retried during shutdown. Close remains a
      // single bounded cleanup operation on the observer's own handle.
      if(!gResponseSuspended && gResponseIOErrors==0)
      {
         ResetLastError(); FileFlush(gResponseFile);
         if(GetLastError()!=0) { gResponseIOErrors++; gResponseSuspended=true;
            gResponseSuspendReason="DEINIT_FLUSH_IO_ERROR"; }
      }
      ResetLastError(); FileClose(gResponseFile);
      if(GetLastError()!=0) { gResponseIOErrors++; gResponseSuspended=true;
         if(gResponseSuspendReason=="") gResponseSuspendReason="DEINIT_CLOSE_IO_ERROR"; }
      gResponseFile=INVALID_HANDLE;
   }
   PrintFormat("[RESPONSE_A][DEINIT] suspended=%d reason=%s dropped=%I64d gaps=%I64d io_errors=%I64d remaining=%d; diagnostic status only",
      (int)gResponseSuspended,gResponseSuspendReason,gResponseDropped,gResponseGaps,gResponseIOErrors,gResponseCount);
   gResponseInitialized=false;
}
#endif

// END EMBEDDED ResponseObserver.mqh


// ORIGINAL_INCLUDE | #include "Include/BookArmedDiagnostics.mqh"
// BEGIN_INCORPORATED Include/BookArmedDiagnostics.mqh
#ifndef BOOK_ARMED_DIAGNOSTICS_V1
#define BOOK_ARMED_DIAGNOSTICS_V1
// ORIGINAL_INCLUDE | #include "BookArmedMath.mqh"
// BEGIN_INCORPORATED Include/BookArmedMath.mqh
#ifndef BOOK_ARMED_MATH_V1
#define BOOK_ARMED_MATH_V1
// Shared by MQL5 and the native deterministic diagnostic harness.
// HOST_CPP_INACTIVE | #ifdef __cplusplus
// HOST_CPP_INACTIVE | #include <cmath>
// HOST_CPP_INACTIVE | bool BookArmedFinite(double x) { return std::isfinite(x); }
// HOST_CPP_INACTIVE | #else
bool BookArmedFinite(double x) { return MathIsValidNumber(x) && x!=EMPTY_VALUE; }
// HOST_CPP_INACTIVE | #endif
enum BOOK_DIAG_GATE
{
   BD_BREAKOUT=1, BD_WAVE_DIRECTION=2, BD_WAVE_EFFORT=4,
   BD_BOOK=8, BD_SPREAD=16, BD_DATA=32, BD_OTHER=64,
   BD_ALL=127
};
struct BookArmedTrace
{
   int direction,evaluated,blocked,ever_blocked,first_blocked,last_blocked;
   long armed_msc,first_touch_observed_msc,last_tick_msc,samples,evaluations;
   double trigger,best,worst;
   bool price_available,touched;
};
void BookArmedResetTrace(BookArmedTrace &t,int direction,long armed_msc,double trigger)
{
   t.direction=direction; t.evaluated=0; t.blocked=0; t.ever_blocked=0;
   t.first_blocked=0; t.last_blocked=0; t.armed_msc=armed_msc;
   t.first_touch_observed_msc=0; t.last_tick_msc=0; t.samples=0; t.evaluations=0;
   t.trigger=trigger; t.best=0; t.worst=0; t.price_available=false; t.touched=false;
}
void BookArmedBeginEvaluation(BookArmedTrace &t)
{ t.evaluated=0; t.blocked=0; t.evaluations++; }
void BookArmedPass(BookArmedTrace &t,int mask) { t.evaluated|=mask; }
void BookArmedBlock(BookArmedTrace &t,int mask)
{
   t.evaluated|=mask; t.blocked|=mask; t.ever_blocked|=mask;
   if(t.first_blocked==0) t.first_blocked=mask;
   t.last_blocked=mask;
}
void BookArmedObserveTrade(BookArmedTrace &t,double price,long tick_msc,long observed_msc)
{
   if((t.direction!=1 && t.direction!=-1) || !BookArmedFinite(price) || price<=0 ||
      !BookArmedFinite(t.trigger) || t.trigger<=0 || tick_msc<=0) return;
   // Callback observations are samples, not an exhaustive exchange tick stream.
   if(!t.price_available)
   { t.best=price; t.worst=price; t.price_available=true; }
   else
   {
      if(t.direction*(price-t.best)>0) t.best=price;
      if(t.direction*(price-t.worst)<0) t.worst=price;
   }
   t.samples++; t.last_tick_msc=tick_msc;
   if(!t.touched && t.direction*(price-t.trigger)>=0)
   { t.touched=true; t.first_touch_observed_msc=observed_msc; }
}
int BookArmedNotEvaluated(const BookArmedTrace &t) { return BD_ALL & ~t.evaluated; }
// 1 = no observed breakout; 2 = trigger observed, later execution blocked.
int BookArmedTimeoutClass(const BookArmedTrace &t) { return t.touched?2:1; }
#endif
// END_INCORPORATED Include/BookArmedMath.mqh
// Diagnostics never return authorization, query depth/history or modify an order.
// Hook after existing predicates only. ALL excludes no original financial gate:
// OTHER denotes a named original gate; absence means NOT_EVALUATED, never PASS.
#define BOOK_DIAG_QUEUE_CAP 128
#define BOOK_DIAG_PENDING_CAP 8
#define BOOK_DIAG_DAILY_BYTES 16777216
#define BOOK_DIAG_CALLBACK_BUDGET_US 2000
struct BookArmedDiagnostic
{
   bool active,matrix_available,live_available,book_consulted;
   string id,route,mode,subtype,first_reason,last_reason,terminal;
   datetime signal_bar,armed_at;
   double high,low,margin,effort_min,live_effort,live_volume,live_average;
   int live_direction,book_state;
   double spread,overshoot,live_vwap,live_lower,live_upper,live_posrel;
   double bid_pct,ask_pct,sigma,vwap_d1,d1_high,d1_low;
   int sigma_days;
   ulong book_sequence;
   MatrixSnapshot matrixSnapshot;
   BookArmedTrace trace;
};
struct BookArmedEvent
{
   string event,reason;
   long observed_msc;
   BookArmedDiagnostic state;
   ulong order,deal,position;
   uint request_id,retcode;
   double confirmed_volume,confirmed_entry;
};
struct BookArmedAwaiting
{
   bool used;
   uint request_id;
   ulong order,deal;
   BookArmedDiagnostic state;
};
BookArmedDiagnostic gBookDiagState;
BookArmedEvent gBookDiagQueue[BOOK_DIAG_QUEUE_CAP];
BookArmedAwaiting gBookDiagAwaiting[BOOK_DIAG_PENDING_CAP];
int gBookDiagHead=0,gBookDiagCount=0,gBookSigmaValidDays=0;
bool gBookDiagReady=false,gBookDiagSuspended=false,gBookDiagHealthPrinted=false;
ulong gBookDiagSequence=0,gBookDiagDropped=0,gBookDiagOverwrites=0,gBookDiagBytes=0;
ulong gBookDiagIOErrors=0,gBookDiagDeduplicated=0,gBookDiagTimerUS=0;
ulong gBookDiagHookCount=0,gBookDiagHookTotalUS=0,gBookDiagHookMaxUS=0;
string gBookDiagRun="",gBookDiagExecutionContext="",gBookDiagDay="",gBookDiagSuspension="";
int gBookDiagFile=INVALID_HANDLE;
long gBookDiagLastEventMSC=0;
string gBookDiagLastEvent="",gBookDiagLastReason="";
double gBookDiagLastSigma=-1,gBookDiagLastD1=-1,gBookDiagLastH1=-1,gBookDiagLastL1=-1;

bool BookDiagEnabled()
{ return Inp_EnableArmedDiagnostics && gBookDiagReady && !gBookDiagSuspended; }
void BookDiagAccountCost(ulong start)
{
   ulong elapsed=GetMicrosecondCount()-start;
   gBookDiagHookCount++; gBookDiagHookTotalUS+=elapsed;
   if(elapsed>gBookDiagHookMaxUS) gBookDiagHookMaxUS=elapsed;
   if(elapsed>BOOK_DIAG_CALLBACK_BUDGET_US)
   { gBookDiagSuspended=true; gBookDiagSuspension="CALLBACK_BUDGET"; }
}
void BookDiagEnqueue(BookArmedEvent &e,bool force=false)
{
   if(!BookDiagEnabled()) return;
   // Repeated holds: at most one row per second; transition/terminal rows bypass dedup.
   e.observed_msc=(long)TimeTradeServer()*1000;
   if(!force && e.event==gBookDiagLastEvent && e.reason==gBookDiagLastReason &&
      e.observed_msc-gBookDiagLastEventMSC<1000)
   { gBookDiagDeduplicated++; return; }
   if(gBookDiagCount>=BOOK_DIAG_QUEUE_CAP)
   {
      gBookDiagDropped++;
      gBookDiagSuspended=true; gBookDiagSuspension="QUEUE_CAPACITY"; return;
   }
   gBookDiagLastEvent=e.event; gBookDiagLastReason=e.reason;
   gBookDiagLastEventMSC=e.observed_msc;
   gBookDiagQueue[(gBookDiagHead+gBookDiagCount)%BOOK_DIAG_QUEUE_CAP]=e;
   gBookDiagCount++;
}
void BookDiagEmit(string event,string reason,bool force=false)
{
   BookArmedEvent e; ZeroMemory(e);
   e.event=event; e.reason=reason; e.state=gBookDiagState;
   BookDiagEnqueue(e,force);
}
string BookDiagSubtype(const MatrixSnapshot &s)
{
   if(s.absDivergence) return "DIVERGENCE";
   if(s.absStallStrict) return "STALL_STRICT";
   if(s.absFollowingReaction) return "FOLLOWING_REACTION";
   if(s.absFollowingExtension) return "FOLLOWING_EXTENSION";
   return "NONE";
}
void BookDiagSelected(const MatrixSnapshot &s,const ArmedSignal &a,double trigger)
{
   if(!BookDiagEnabled()) return;
   ulong begin=GetMicrosecondCount();
   if(gBookDiagState.active) BookDiagEmit("IDENTITY_REPLACED","ORIGINAL_REPLACEMENT",true);
   ZeroMemory(gBookDiagState);
   gBookDiagState.active=true;
   gBookDiagState.id=gBookDiagRun+"_"+(string)(++gBookDiagSequence);
   gBookDiagState.route=a.route; gBookDiagState.mode=a.mode;
   gBookDiagState.subtype=BookDiagSubtype(s);
   gBookDiagState.signal_bar=a.regionEndTime; gBookDiagState.armed_at=a.armedAt;
   gBookDiagState.high=a.regionHigh; gBookDiagState.low=a.regionLow;
   gBookDiagState.margin=gBreakoutMargin; gBookDiagState.effort_min=a.breakoutEffortMin;
   gBookDiagState.matrixSnapshot=s; gBookDiagState.matrix_available=true;
   gBookDiagState.sigma=SigmaD1; gBookDiagState.sigma_days=gBookSigmaValidDays;
   gBookDiagState.vwap_d1=VWAP_D1; gBookDiagState.d1_high=H1; gBookDiagState.d1_low=L1;
   BookArmedResetTrace(gBookDiagState.trace,a.dir,(long)a.armedAt*1000,trigger);
   BookDiagEmit("ARMED","ORIGINAL_MATRIX_SELECTION",true);
   BookDiagAccountCost(begin);
}
void BookDiagBeginEvaluation()
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   BookArmedBeginEvaluation(gBookDiagState.trace);
   // Live/book values are unavailable until their original computations run.
   gBookDiagState.live_available=false; gBookDiagState.book_consulted=false;
   gBookDiagState.spread=EMPTY_VALUE; gBookDiagState.overshoot=EMPTY_VALUE;
   gBookDiagState.live_vwap=EMPTY_VALUE; gBookDiagState.live_lower=EMPTY_VALUE;
   gBookDiagState.live_upper=EMPTY_VALUE; gBookDiagState.live_posrel=EMPTY_VALUE;
}
void BookDiagPass(int mask)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   BookArmedPass(gBookDiagState.trace,mask);
}
void BookDiagWait(int mask,string reason)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   ulong begin=GetMicrosecondCount();
   BookArmedBlock(gBookDiagState.trace,mask);
   if(gBookDiagState.first_reason=="") gBookDiagState.first_reason=reason;
   gBookDiagState.last_reason=reason;
   BookDiagAccountCost(begin);
}
void BookDiagAfterEvaluation()
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   if(gBookDiagState.trace.blocked!=0) BookDiagEmit("WAIT",gBookDiagState.last_reason);
}
void BookDiagTick(const MqlTick &tick,double trigger)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   // Called only after the inherited real-trade predicate and positive last.
   gBookDiagState.trace.trigger=trigger;
   BookArmedObserveTrade(gBookDiagState.trace,tick.last,tick.time_msc,
      (long)TimeTradeServer()*1000);
   if(tick.bid>0 && tick.ask>=tick.bid)
      gBookDiagState.spread=tick.ask-tick.bid;
}
void BookDiagOvershoot(double overshoot)
{
   if(BookDiagEnabled() && gBookDiagState.active) gBookDiagState.overshoot=overshoot;
}
void BookDiagLive(double effort,double volume,double average,int direction)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   gBookDiagState.live_available=true; gBookDiagState.live_effort=effort;
   gBookDiagState.live_volume=volume; gBookDiagState.live_average=average;
   gBookDiagState.live_direction=direction;
}
void BookDiagLiveBands(double vwap,double lower,double upper,double posrel)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   gBookDiagState.live_vwap=vwap; gBookDiagState.live_lower=lower;
   gBookDiagState.live_upper=upper; gBookDiagState.live_posrel=posrel;
}
void BookDiagSpread(const MqlTick &tick)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   if(tick.bid>0 && tick.ask>=tick.bid) gBookDiagState.spread=tick.ask-tick.bid;
}
void BookDiagBook(const BookGateDecision &decision,bool confirmed)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   // A local intent rejection is NOT a fresh book observation. Only a completed
   // MarketBookGet path carries a raw snapshot, including an API-failure quality.
   if(decision.state==BOOK_ENTRY_BLOCKED) return;
   if(!gBookDiagState.book_consulted)
   { BookDiagWait(BD_DATA,"WAIT_DATA:BOOK_NOT_CONSULTED"); return; }
   gBookDiagState.book_state=(int)decision.state;
   gBookDiagState.bid_pct=decision.pctBid; gBookDiagState.ask_pct=decision.pctAsk;
   gBookDiagState.book_sequence=decision.snapshot.sequence;
   if(confirmed) BookDiagPass(BD_BOOK);
   else BookDiagWait(BD_BOOK,"WAIT_BOOK_CONFIRMATION");
}
void BookDiagBookReadBegin()
{
   if(BookDiagEnabled() && gBookDiagState.active) gBookDiagState.book_consulted=false;
}
void BookDiagBookAttempt()
{
   if(BookDiagEnabled() && gBookDiagState.active) gBookDiagState.book_consulted=true;
}
void BookDiagFinish(string reason)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   gBookDiagState.terminal=reason;
   BookDiagEmit("TERMINAL",reason,true);
   gBookDiagState.active=false;
}
void BookDiagAudit(string status)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   if(status=="TIMEOUT_ARMED")
      BookDiagFinish(BookArmedTimeoutClass(gBookDiagState.trace)==1?
         "TIMEOUT_NO_BREAKOUT":"TIMEOUT_TRIGGER_REACHED_BUT_BLOCKED");
   else if(status=="ABORT_SESSION_END" || status=="ABORT_EOD")
      BookDiagFinish("CANCEL_SESSION_END:"+status);
   else if(status=="ARMED_CANCEL_HARD") BookDiagFinish("CANCEL_HARD_CONTRADICTION");
   else if(status=="OVERSHOOT_BLOCK" || status=="LATE_OVERSHOOT_BLOCK")
      BookDiagFinish("CANCEL_OVERSHOOT");
   else if(status=="LATE_BREAKOUT_LOST") BookDiagFinish("CANCEL_BREAKOUT_LOST");
   else if(status=="LATE_VWAP_INVALID") BookDiagFinish("CANCEL_DATA:LIVE_VWAP");
   else if(status=="LATE_DIRECTION_BLOCK" || status=="LATE_GLASS_BLOCK" ||
      status=="DAILY_RISK_BLOCK" || status=="STOPS_LEVEL_BLOCK" ||
      status=="NO_MARGIN" || status=="LATE_POSITION_BLOCK" ||
      status=="LATE_QUOTA_BLOCK" || status=="LATE_DAILY_RISK_BLOCK" ||
      status=="LATE_PENDING_BLOCK")
   { BookDiagWait(BD_OTHER,"WAIT_OTHER_GATE:"+status); BookDiagFinish("ORIGINAL_GATE:"+status); }
}
void BookDiagBeforeReset()
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   MqlDateTime now; TimeToStruct(TimeTradeServer(),now);
   int hhmm=now.hour*100+now.min;
   if(hhmm>=Inp_StopEntryHHMM) BookDiagFinish("CANCEL_SESSION_END");
   else if(armed.armedAt>0 && (TimeTradeServer()/86400)!=(armed.armedAt/86400))
      BookDiagFinish("CANCEL_DAY_CHANGE");
   else BookDiagFinish("ORIGINAL_RESET_CAUSE_UNAVAILABLE");
}
void BookDiagSendOutcome(ENUM_SEND_OUTCOME outcome)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   if(outcome==SEND_WAIT_ARMED) return;
   if(outcome==SEND_ACCEPTED) BookDiagFinish("ORDER_ACCEPTED_WITHOUT_OBSERVER_DISPATCH_CORRELATION");
   else if(outcome==SEND_FINANCIAL_UNRESOLVED)
      BookDiagFinish("ORIGINAL_FINANCIAL_RESULT_UNCERTAIN");
   else if(outcome==SEND_FINAL_FAILURE)
      BookDiagFinish("ORDER_FAILED_BEFORE_API_OR_UNAVAILABLE_CAUSE");
   else BookDiagFinish("ORIGINAL_SEND_TERMINAL:"+(string)(int)outcome);
}
void BookDiagDispatch(const MqlTradeResult &result)
{
   if(!BookDiagEnabled() || !gBookDiagState.active) return;
   BookArmedEvent e; ZeroMemory(e); e.event="ORDER_SENT";
   e.reason="API_CALLED_NOT_FILL_PROOF"; e.state=gBookDiagState;
   e.order=result.order; e.deal=result.deal; e.request_id=result.request_id;
   e.retcode=result.retcode; BookDiagEnqueue(e,true);
   int slot=-1;
   for(int i=0;i<BOOK_DIAG_PENDING_CAP;i++)
      if(!gBookDiagAwaiting[i].used) { slot=i; break; }
   if(slot>=0)
   {
      gBookDiagAwaiting[slot].used=true; gBookDiagAwaiting[slot].state=gBookDiagState;
      gBookDiagAwaiting[slot].request_id=result.request_id;
      gBookDiagAwaiting[slot].order=result.order; gBookDiagAwaiting[slot].deal=result.deal;
   }
   else gBookDiagOverwrites++; // Never overwrite an unresolved diagnostic identity.
   if(IsFinalRejectedRetcode(result.retcode) && result.order==0 && result.deal==0)
   {
      e.event="ORDER_FAILED"; e.reason="FINAL_REJECTED_RETCODE";
      BookDiagEnqueue(e,true);
      if(slot>=0) gBookDiagAwaiting[slot].used=false;
   }
   BookDiagFinish("ORDER_SENT_AWAITING_SERVER_PROOF");
}
void BookDiagRequestResult(const MqlTradeResult &result)
{
   if(!BookDiagEnabled() || result.request_id==0) return;
   // Caller invokes only after original exact ownEntryRequest matches.
   for(int i=0;i<BOOK_DIAG_PENDING_CAP;i++)
   {
      if(!gBookDiagAwaiting[i].used ||
         gBookDiagAwaiting[i].request_id!=result.request_id) continue;
      if(result.order>0) gBookDiagAwaiting[i].order=result.order;
      if(result.deal>0) gBookDiagAwaiting[i].deal=result.deal;
      if(IsFinalRejectedRetcode(result.retcode) &&
         gBookDiagAwaiting[i].order==0 && gBookDiagAwaiting[i].deal==0)
      {
         BookArmedEvent e; ZeroMemory(e); e.event="ORDER_FAILED";
         e.reason="MATCHED_FINAL_REJECTED_REQUEST";
         e.state=gBookDiagAwaiting[i].state;
         e.request_id=result.request_id; e.retcode=result.retcode;
         BookDiagEnqueue(e,true); gBookDiagAwaiting[i].used=false;
      }
   }
}
void BookDiagConfirmed(const TradeRecord &r)
{
   if(!BookDiagEnabled() || !r.accountingResolved || r.historyRefreshPending ||
      r.positionID==0 || r.entryOrderTicket==0 || r.totalVolumeIn<=0 ||
      r.weightedEntryPrice<=0) return;
   for(int i=0;i<BOOK_DIAG_PENDING_CAP;i++)
   {
      if(!gBookDiagAwaiting[i].used || gBookDiagAwaiting[i].order==0 ||
         gBookDiagAwaiting[i].order!=r.entryOrderTicket ||
         gBookDiagAwaiting[i].state.trace.direction!=r.direction ||
         gBookDiagAwaiting[i].state.route!=r.route ||
         gBookDiagAwaiting[i].state.mode!=r.mode) continue;
      BookArmedEvent e; ZeroMemory(e); e.event="ORDER_CONFIRMED";
      e.reason="AUTHORITATIVE_ENTRY_DEALS_NOT_FULL_FILL_GUARANTEE";
      e.state=gBookDiagAwaiting[i].state; e.order=r.entryOrderTicket;
      e.position=r.positionID; e.request_id=gBookDiagAwaiting[i].request_id;
      e.confirmed_volume=r.totalVolumeIn; e.confirmed_entry=r.weightedEntryPrice;
      BookDiagEnqueue(e,true); gBookDiagAwaiting[i].used=false;
   }
}
void BookDiagMatrix(const MatrixSnapshot &s,datetime live_bar)
{
   if(!BookDiagEnabled() || s.status!=MSS_OK) return;
   BookArmedEvent e; ZeroMemory(e);
   e.event=gBookDiagState.active?"ARMED_MATRIX_OPPORTUNITY":"BANDS_REFERENCE";
   e.reason="ORIGINAL_SNAPSHOT_ONLY_NO_NEW_EVALUATION";
   if(gBookDiagState.active) e.state=gBookDiagState;
   e.state.matrixSnapshot=s; e.state.matrix_available=true;
   e.state.signal_bar=live_bar;
   e.state.sigma=SigmaD1; e.state.sigma_days=gBookSigmaValidDays;
   e.state.vwap_d1=VWAP_D1; e.state.d1_high=H1; e.state.d1_low=L1;
   BookDiagEnqueue(e,true);
   // Initial valid snapshot and actual D1/sigma-reference changes only.
   if(SigmaD1!=gBookDiagLastSigma || VWAP_D1!=gBookDiagLastD1 ||
      H1!=gBookDiagLastH1 || L1!=gBookDiagLastL1)
   {
      PrintFormat("[BOOK_BANDS] SIGMA_D1=%.8f SIGMA_VALID_DAYS=%d BAND_MULTIPLIER=%.8f VWAP_CURRENT=%.8f LOWER_BAND=%.8f UPPER_BAND=%.8f BAND_RANGE=%.8f VWAP_TO_LOWER_DISTANCE=%.8f VWAP_TO_UPPER_DISTANCE=%.8f VWAP_D1=%.8f D1_HIGH=%.8f D1_LOW=%.8f PRICE_POSITION_RELATIVE=%.8f; D1_OPEN/CURRENT_SESSION_OPEN=UNAVAILABLE; original snapshot only",
         SigmaD1,gBookSigmaValidDays,BandMultiplier,s.vwapVig,s.lower,s.upper,
         s.upper-s.lower,s.vwapVig-s.lower,s.upper-s.vwapVig,VWAP_D1,H1,L1,s.posRel);
      gBookDiagLastSigma=SigmaD1; gBookDiagLastD1=VWAP_D1;
      gBookDiagLastH1=H1; gBookDiagLastL1=L1;
   }
}
string BookDiagNumber(double value,bool available=true)
{ return available && BookArmedFinite(value)?StringFormat("%.17g",value):""; }
void BookDiagCell(string &row,string value)
{
   StringReplace(value,"\"","\"\"");
   if(row!="") row+=";";
   row+="\""+value+"\"";
}
string BookDiagOriginalMatrix(const MatrixSnapshot &s)
{
   string row="";
   BookDiagCell(row,"matrix.status="+(string)(int)s.status);
   BookDiagCell(row,"matrix.vwapVig="+BookDiagNumber(s.vwapVig));
   BookDiagCell(row,"matrix.upper="+BookDiagNumber(s.upper));
   BookDiagCell(row,"matrix.lower="+BookDiagNumber(s.lower));
   BookDiagCell(row,"matrix.bandRange="+BookDiagNumber(s.bandRange));
   BookDiagCell(row,"matrix.price="+BookDiagNumber(s.price));
   BookDiagCell(row,"matrix.open1="+BookDiagNumber(s.open1));
   BookDiagCell(row,"matrix.candleBody="+BookDiagNumber(s.candleBody));
   BookDiagCell(row,"matrix.posRel="+BookDiagNumber(s.posRel));
   BookDiagCell(row,"matrix.glass="+(string)(int)s.glass);
   BookDiagCell(row,"matrix.dir="+(string)(int)s.dir);
   BookDiagCell(row,"matrix.dirCont="+(string)(int)s.dirCont);
   BookDiagCell(row,"matrix.c5AbsOk="+(string)(int)s.c5AbsOk);
   BookDiagCell(row,"matrix.c5ContOk="+(string)(int)s.c5ContOk);
   BookDiagCell(row,"matrix.distAbs="+BookDiagNumber(s.distAbs));
   BookDiagCell(row,"matrix.minDispl="+BookDiagNumber(s.minDispl));
   BookDiagCell(row,"matrix.maxBody="+BookDiagNumber(s.maxBody));
   BookDiagCell(row,"matrix.contMinDispl="+BookDiagNumber(s.contMinDispl));
   BookDiagCell(row,"matrix.c2="+(string)(int)s.c2);
   BookDiagCell(row,"matrix.c3="+(string)(int)s.c3);
   BookDiagCell(row,"matrix.c23="+(string)(int)s.c23);
   BookDiagCell(row,"matrix.c4="+(string)(int)s.c4);
   BookDiagCell(row,"matrix.c2Cont="+(string)(int)s.c2Cont);
   BookDiagCell(row,"matrix.c3Cont="+(string)(int)s.c3Cont);
   BookDiagCell(row,"matrix.c23Cont="+(string)(int)s.c23Cont);
   BookDiagCell(row,"matrix.c4Cont="+(string)(int)s.c4Cont);
   BookDiagCell(row,"matrix.posRange="+BookDiagNumber(s.posRange));
   BookDiagCell(row,"matrix.windowsValid="+(string)(int)s.windowsValid);
   BookDiagCell(row,"matrix.priceMove="+BookDiagNumber(s.priceMove));
   BookDiagCell(row,"matrix.pocMove="+BookDiagNumber(s.pocMove));
   BookDiagCell(row,"matrix.displacementOk="+(string)(int)s.displacementOk);
   BookDiagCell(row,"matrix.moveDir="+(string)(int)s.moveDir);
   BookDiagCell(row,"matrix.pocState="+(string)(int)s.pocState);
   BookDiagCell(row,"matrix.contDisplacementOk="+(string)(int)s.contDisplacementOk);
   BookDiagCell(row,"matrix.contMoveDir="+(string)(int)s.contMoveDir);
   BookDiagCell(row,"matrix.contPocState="+(string)(int)s.contPocState);
   BookDiagCell(row,"matrix.wwok="+(string)(int)s.wwok);
   BookDiagCell(row,"matrix.effort="+BookDiagNumber(s.effort));
   BookDiagCell(row,"matrix.waveDir="+(string)(int)s.waveDir);
   BookDiagCell(row,"matrix.wwWaveBars="+(string)(int)s.wwWaveBars);
   BookDiagCell(row,"matrix.wwWaveAgeSec="+(string)s.wwWaveAgeSec);
   BookDiagCell(row,"matrix.wwWaveAgeAvailable="+(string)(int)s.wwWaveAgeAvailable);
   BookDiagCell(row,"matrix.wwAccumVolume="+BookDiagNumber(s.wwAccumVolume));
   BookDiagCell(row,"matrix.wwDistancePts="+BookDiagNumber(s.wwDistancePts));
   BookDiagCell(row,"matrix.c1_effort_ok="+(string)(int)s.c1_effort_ok);
   BookDiagCell(row,"matrix.c1_body_ok="+(string)(int)s.c1_body_ok);
   BookDiagCell(row,"matrix.c1_displacement_ok="+(string)(int)s.c1_displacement_ok);
   BookDiagCell(row,"matrix.c1_movedir_ok="+(string)(int)s.c1_movedir_ok);
   BookDiagCell(row,"matrix.c1_wavedir_ok="+(string)(int)s.c1_wavedir_ok);
   BookDiagCell(row,"matrix.absDivergence="+(string)(int)s.absDivergence);
   BookDiagCell(row,"matrix.absStallStrict="+(string)(int)s.absStallStrict);
   BookDiagCell(row,"matrix.absFollowingReaction="+(string)(int)s.absFollowingReaction);
   BookDiagCell(row,"matrix.absFollowingExtension="+(string)(int)s.absFollowingExtension);
   BookDiagCell(row,"matrix.absPocContextOk="+(string)(int)s.absPocContextOk);
   BookDiagCell(row,"matrix.c1="+(string)(int)s.c1);
   BookDiagCell(row,"matrix.cont_effort_ok="+(string)(int)s.cont_effort_ok);
   BookDiagCell(row,"matrix.cont_displacement_ok="+(string)(int)s.cont_displacement_ok);
   BookDiagCell(row,"matrix.cont_poc_ok="+(string)(int)s.cont_poc_ok);
   BookDiagCell(row,"matrix.cont_movedir_ok="+(string)(int)s.cont_movedir_ok);
   BookDiagCell(row,"matrix.cont_wavedir_ok="+(string)(int)s.cont_wavedir_ok);
   BookDiagCell(row,"matrix.cont_candle_dir_ok="+(string)(int)s.cont_candle_dir_ok);
   BookDiagCell(row,"matrix.c1Cont="+(string)(int)s.c1Cont);
   BookDiagCell(row,"matrix.turboAbs="+(string)(int)s.turboAbs);
   BookDiagCell(row,"matrix.baseAbs="+(string)(int)s.baseAbs);
   BookDiagCell(row,"matrix.turboCont="+(string)(int)s.turboCont);
   BookDiagCell(row,"matrix.baseCont="+(string)(int)s.baseCont);
   BookDiagCell(row,"matrix.scoreEff="+(string)(int)s.scoreEff);
   BookDiagCell(row,"matrix.scoreContEff="+(string)(int)s.scoreContEff);
   BookDiagCell(row,"matrix.absValid="+(string)(int)s.absValid);
   BookDiagCell(row,"matrix.contValid="+(string)(int)s.contValid);
   BookDiagCell(row,"matrix.candleDir="+(string)(int)s.candleDir);
   BookDiagCell(row,"matrix.macroAbsCompatible="+(string)(int)s.macroAbsCompatible);
   BookDiagCell(row,"matrix.macroContCompatible="+(string)(int)s.macroContCompatible);
   BookDiagCell(row,"pocNow.ok="+(string)(int)s.pocNow.ok);
   BookDiagCell(row,"pocNow.poc="+BookDiagNumber(s.pocNow.poc));
   BookDiagCell(row,"pocNow.totalVolume="+BookDiagNumber(s.pocNow.totalVolume));
   BookDiagCell(row,"pocNow.lastValidPrice="+BookDiagNumber(s.pocNow.lastValidPrice));
   BookDiagCell(row,"pocNow.tradeCount="+(string)(int)s.pocNow.tradeCount);
   BookDiagCell(row,"pocNow.levels="+(string)(int)s.pocNow.levels);
   BookDiagCell(row,"pocNow.hasTie="+(string)(int)s.pocNow.hasTie);
   BookDiagCell(row,"pocNow.top1Price="+BookDiagNumber(s.pocNow.top1Price));
   BookDiagCell(row,"pocNow.top1Vol="+BookDiagNumber(s.pocNow.top1Vol));
   BookDiagCell(row,"pocNow.top2Price="+BookDiagNumber(s.pocNow.top2Price));
   BookDiagCell(row,"pocNow.top2Vol="+BookDiagNumber(s.pocNow.top2Vol));
   BookDiagCell(row,"pocNow.dominance="+BookDiagNumber(s.pocNow.dominance));
   BookDiagCell(row,"pocNow.buyVol="+BookDiagNumber(s.pocNow.buyVol));
   BookDiagCell(row,"pocNow.sellVol="+BookDiagNumber(s.pocNow.sellVol));
   BookDiagCell(row,"pocNow.unkVol="+BookDiagNumber(s.pocNow.unkVol));
   BookDiagCell(row,"pocPrev.ok="+(string)(int)s.pocPrev.ok);
   BookDiagCell(row,"pocPrev.poc="+BookDiagNumber(s.pocPrev.poc));
   BookDiagCell(row,"pocPrev.totalVolume="+BookDiagNumber(s.pocPrev.totalVolume));
   BookDiagCell(row,"pocPrev.lastValidPrice="+BookDiagNumber(s.pocPrev.lastValidPrice));
   BookDiagCell(row,"pocPrev.tradeCount="+(string)(int)s.pocPrev.tradeCount);
   BookDiagCell(row,"pocPrev.levels="+(string)(int)s.pocPrev.levels);
   BookDiagCell(row,"pocPrev.hasTie="+(string)(int)s.pocPrev.hasTie);
   BookDiagCell(row,"pocPrev.top1Price="+BookDiagNumber(s.pocPrev.top1Price));
   BookDiagCell(row,"pocPrev.top1Vol="+BookDiagNumber(s.pocPrev.top1Vol));
   BookDiagCell(row,"pocPrev.top2Price="+BookDiagNumber(s.pocPrev.top2Price));
   BookDiagCell(row,"pocPrev.top2Vol="+BookDiagNumber(s.pocPrev.top2Vol));
   BookDiagCell(row,"pocPrev.dominance="+BookDiagNumber(s.pocPrev.dominance));
   BookDiagCell(row,"pocPrev.buyVol="+BookDiagNumber(s.pocPrev.buyVol));
   BookDiagCell(row,"pocPrev.sellVol="+BookDiagNumber(s.pocPrev.sellVol));
   BookDiagCell(row,"pocPrev.unkVol="+BookDiagNumber(s.pocPrev.unkVol));
   return row;
}
string BookDiagFormat(const BookArmedEvent &e)
{
   BookArmedDiagnostic s=e.state;
   bool identity=s.id!="";
   string row="";
   BookDiagCell(row,"BOOK_ARMED_V1"); BookDiagCell(row,gBookDiagRun);
   BookDiagCell(row,gBookDiagExecutionContext); BookDiagCell(row,s.id);
   BookDiagCell(row,(string)e.observed_msc); BookDiagCell(row,e.event);
   BookDiagCell(row,e.reason); BookDiagCell(row,s.route); BookDiagCell(row,s.mode);
   BookDiagCell(row,identity?(string)s.trace.direction:""); BookDiagCell(row,s.subtype);
   BookDiagCell(row,(string)s.signal_bar); BookDiagCell(row,identity?(string)s.armed_at:"");
   BookDiagCell(row,BookDiagNumber(s.high,identity)); BookDiagCell(row,BookDiagNumber(s.low,identity));
   BookDiagCell(row,BookDiagNumber(s.margin,identity)); BookDiagCell(row,BookDiagNumber(s.trace.trigger,identity));
   BookDiagCell(row,(string)Inp_ArmedTimeoutSec);
   BookDiagCell(row,BookDiagNumber(s.trace.best,s.trace.price_available));
   BookDiagCell(row,BookDiagNumber(s.trace.worst,s.trace.price_available));
   BookDiagCell(row,identity?(s.trace.touched?"1":"0"):"");
   BookDiagCell(row,s.trace.touched?(string)(s.trace.first_touch_observed_msc-s.trace.armed_msc):"");
   BookDiagCell(row,"CALLBACK_REAL_TRADE_SAMPLES_SERVER_SECOND_RESOLUTION");
   BookDiagCell(row,s.first_reason); BookDiagCell(row,s.last_reason);
   BookDiagCell(row,(string)s.trace.first_blocked); BookDiagCell(row,(string)s.trace.last_blocked);
   BookDiagCell(row,(string)s.trace.blocked); BookDiagCell(row,(string)s.trace.ever_blocked);
   BookDiagCell(row,(string)s.trace.evaluated); BookDiagCell(row,(string)BookArmedNotEvaluated(s.trace));
   BookDiagCell(row,(string)s.trace.samples); BookDiagCell(row,(string)s.trace.last_tick_msc);
   BookDiagCell(row,(string)s.trace.evaluations);
   BookDiagCell(row,s.live_available?"PARTIAL_LIVE_WAVE":"NOT_EVALUATED");
   BookDiagCell(row,s.live_available?(string)s.live_direction:"");
   BookDiagCell(row,BookDiagNumber(s.live_effort,s.live_available));
   BookDiagCell(row,BookDiagNumber(s.live_volume,s.live_available));
   BookDiagCell(row,BookDiagNumber(s.live_average,s.live_available));
   BookDiagCell(row,BookDiagNumber(s.effort_min,identity));
   BookDiagCell(row,BookDiagNumber(s.spread,identity)); BookDiagCell(row,BookDiagNumber(s.overshoot,identity));
   BookDiagCell(row,BookDiagNumber(s.live_vwap,identity)); BookDiagCell(row,BookDiagNumber(s.live_lower,identity));
   BookDiagCell(row,BookDiagNumber(s.live_upper,identity)); BookDiagCell(row,BookDiagNumber(s.live_posrel,identity));
   BookDiagCell(row,s.book_consulted?"CONSULTED":"NOT_EVALUATED");
   BookDiagCell(row,s.book_consulted?(string)s.book_state:"");
   BookDiagCell(row,BookDiagNumber(s.bid_pct,s.book_consulted));
   BookDiagCell(row,BookDiagNumber(s.ask_pct,s.book_consulted));
   BookDiagCell(row,s.book_consulted?(string)s.book_sequence:"");
   BookDiagCell(row,s.terminal); BookDiagCell(row,e.order>0?(string)e.order:"");
   BookDiagCell(row,e.deal>0?(string)e.deal:""); BookDiagCell(row,e.position>0?(string)e.position:"");
   BookDiagCell(row,e.request_id>0?(string)e.request_id:""); BookDiagCell(row,(string)e.retcode);
   BookDiagCell(row,BookDiagNumber(e.confirmed_volume,e.position>0));
   BookDiagCell(row,BookDiagNumber(e.confirmed_entry,e.position>0));
   BookDiagCell(row,BookDiagNumber(s.sigma,s.matrix_available));
   BookDiagCell(row,s.matrix_available?(string)s.sigma_days:"");
   BookDiagCell(row,BookDiagNumber(BandMultiplier));
   BookDiagCell(row,BookDiagNumber(s.matrixSnapshot.vwapVig,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.matrixSnapshot.lower,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.matrixSnapshot.upper,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.matrixSnapshot.upper-s.matrixSnapshot.lower,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.matrixSnapshot.vwapVig-s.matrixSnapshot.lower,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.matrixSnapshot.upper-s.matrixSnapshot.vwapVig,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.vwap_d1,s.matrix_available));
   BookDiagCell(row,BookDiagNumber(s.d1_high,s.matrix_available)); BookDiagCell(row,BookDiagNumber(s.d1_low,s.matrix_available));
   BookDiagCell(row,"UNAVAILABLE"); BookDiagCell(row,"UNAVAILABLE");
   BookDiagCell(row,BookDiagNumber(s.matrixSnapshot.posRel,s.matrix_available));
   BookDiagCell(row,(string)gBookDiagDropped); BookDiagCell(row,(string)gBookDiagOverwrites);
   BookDiagCell(row,(string)gBookDiagDeduplicated); BookDiagCell(row,(string)gBookDiagIOErrors);
   BookDiagCell(row,(string)gBookDiagHookCount); BookDiagCell(row,(string)gBookDiagHookTotalUS);
   BookDiagCell(row,(string)gBookDiagHookMaxUS); BookDiagCell(row,(string)gBookDiagTimerUS);
   // All original matrix fields retained as ONE quoted CSV cell, formatted only
   // on timer from frozen scalars. Sigma/previous-day references are separate.
   string matrixCsvCell=s.matrix_available?BookDiagOriginalMatrix(s.matrixSnapshot):"";
   BookDiagCell(row,matrixCsvCell);
   return row+"\r\n";
}
string BookDiagHeader()
{
   return "schema;run_id;execution_context;signal_id;observed_msc;event;reason;route;mode;direction;abs_subtype;signal_bar;armed_at;region_high;region_low;breakout_margin;trigger;timeout_sec;best_favorable_price;worst_adverse_price;trigger_touched;time_to_touch_observed_ms;trajectory_coverage;first_wait;last_wait;first_blocked_mask;last_blocked_mask;current_blocked_mask;ever_blocked_mask;evaluated_mask;not_evaluated_mask;samples;last_trade_tick_msc;evaluations;live_wave_state;live_wave_direction;live_effort;live_volume;live_reference;required_effort;spread;overshoot;live_vwap;live_lower;live_upper;live_posrel;book_consultation;book_state;bid_pct;ask_pct;book_sequence;terminal;order;deal;position;request_id;retcode;confirmed_entry_volume;confirmed_entry_price;SIGMA_D1;SIGMA_VALID_DAYS;BAND_MULTIPLIER;VWAP_CURRENT;LOWER_BAND;UPPER_BAND;BAND_RANGE;VWAP_TO_LOWER_DISTANCE;VWAP_TO_UPPER_DISTANCE;VWAP_D1;D1_HIGH;D1_LOW;D1_OPEN;CURRENT_SESSION_OPEN;PRICE_POSITION_RELATIVE;queue_dropped;unresolved_identity_capacity;deduplicated;io_errors;hook_count;hook_total_us;hook_max_us;timer_last_us;original_matrix_csv";
}
bool BookDiagWrite(string row)
{
   uchar bytes[];
   int expected=StringToCharArray(row,bytes,0,WHOLE_ARRAY,CP_UTF8)-1;
   if(expected<=0 || expected>32768 || gBookDiagBytes+(ulong)expected>BOOK_DIAG_DAILY_BYTES)
   { gBookDiagSuspended=true; gBookDiagSuspension="DAILY_OR_ROW_BYTE_LIMIT"; return false; }
   ResetLastError(); uint written=FileWriteString(gBookDiagFile,row);
   if(written!=(uint)expected || GetLastError()!=0)
   { gBookDiagIOErrors++; gBookDiagSuspended=true; gBookDiagSuspension="WRITE_IO_ERROR"; return false; }
   gBookDiagBytes+=written;
   return true;
}
bool BookDiagOpen()
{
   if(gBookDiagFile!=INVALID_HANDLE) return true;
   string path="BookArmed_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"_"+
      ResponseComponent(Symbol())+"_"+(string)gMagicCore+"_"+gBookDiagRun+"_"+gBookDiagDay+".csv";
   StringReplace(path,".","_"); path+=".log.csv";
   ResetLastError(); bool exists=FileIsExist(path); int probe=GetLastError();
   if(exists || (probe!=0 && probe!=ERR_FILE_NOT_EXIST) || StringLen(path)>240)
   { gBookDiagIOErrors++; gBookDiagSuspended=true; gBookDiagSuspension="PATH_EXISTING_OR_UNAVAILABLE"; return false; }
   gBookDiagFile=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ,0,CP_UTF8);
   if(gBookDiagFile==INVALID_HANDLE || FileSize(gBookDiagFile)!=0)
   { gBookDiagIOErrors++; gBookDiagSuspended=true; gBookDiagSuspension="OPEN_IO_ERROR"; return false; }
   return BookDiagWrite(BookDiagHeader()+"\r\n");
}
void BookDiagTimer()
{
   if(!Inp_EnableArmedDiagnostics || !gBookDiagReady) return;
   ulong begin=GetMicrosecondCount();
   string day=TimeToString(TimeTradeServer(),TIME_DATE); StringReplace(day,".","_");
   if(day!=gBookDiagDay)
   {
      if(gBookDiagFile!=INVALID_HANDLE) FileClose(gBookDiagFile);
      gBookDiagFile=INVALID_HANDLE; gBookDiagDay=day; gBookDiagBytes=0;
      if(gBookDiagIOErrors==0 && gBookDiagSuspension=="DAILY_OR_ROW_BYTE_LIMIT")
      { gBookDiagSuspended=false; gBookDiagSuspension=""; gBookDiagHealthPrinted=false; }
   }
   if(!gBookDiagSuspended && gBookDiagCount>0 && BookDiagOpen())
   {
      for(int i=0;i<8 && gBookDiagCount>0;i++)
      {
         if(!BookDiagWrite(BookDiagFormat(gBookDiagQueue[gBookDiagHead]))) break;
         ZeroMemory(gBookDiagQueue[gBookDiagHead]);
         gBookDiagHead=(gBookDiagHead+1)%BOOK_DIAG_QUEUE_CAP; gBookDiagCount--;
      }
      ResetLastError(); FileFlush(gBookDiagFile);
      if(GetLastError()!=0)
      { gBookDiagIOErrors++; gBookDiagSuspended=true; gBookDiagSuspension="FLUSH_IO_ERROR"; }
   }
   if(gBookDiagSuspended && !gBookDiagHealthPrinted)
   {
      gBookDiagHealthPrinted=true;
      PrintFormat("[BOOK_ARMED][DIAGNOSTICS_SUSPENDED] reason=%s queued=%d dropped=%I64u io_errors=%I64u; original strategy untouched, diagnostic coverage incomplete",
         gBookDiagSuspension,gBookDiagCount,gBookDiagDropped,gBookDiagIOErrors);
   }
   gBookDiagTimerUS=GetMicrosecondCount()-begin;
}
void BookDiagInit(string executionContext="")
{
   if(!Inp_EnableArmedDiagnostics) return;
   ZeroMemory(gBookDiagState);
   for(int i=0;i<BOOK_DIAG_QUEUE_CAP;i++) ZeroMemory(gBookDiagQueue[i]);
   for(int i=0;i<BOOK_DIAG_PENDING_CAP;i++) ZeroMemory(gBookDiagAwaiting[i]);
   gBookDiagHead=0; gBookDiagCount=0; gBookDiagSequence=0;
   gBookDiagDropped=0; gBookDiagOverwrites=0; gBookDiagBytes=0;
   gBookDiagIOErrors=0; gBookDiagDeduplicated=0; gBookDiagTimerUS=0;
   gBookDiagHookCount=0; gBookDiagHookTotalUS=0; gBookDiagHookMaxUS=0;
   gBookDiagSuspended=false; gBookDiagHealthPrinted=false; gBookDiagSuspension="";
   gBookDiagLastEventMSC=0; gBookDiagLastEvent=""; gBookDiagLastReason="";
   gBookDiagLastSigma=-1; gBookDiagLastD1=-1; gBookDiagLastH1=-1; gBookDiagLastL1=-1;
   gBookDiagExecutionContext=executionContext;
   gBookDiagRun=(string)TimeTradeServer()+"_"+(string)ChartID()+"_"+(string)GetMicrosecondCount();
   gBookDiagDay=TimeToString(TimeTradeServer(),TIME_DATE); StringReplace(gBookDiagDay,".","_");
   gBookDiagReady=true;
   BookDiagEmit("INIT","DIAGNOSTICS_ONLY",true);
}
void BookDiagDeinit()
{
   if(!Inp_EnableArmedDiagnostics || !gBookDiagReady) return;
   BookDiagFinish("CANCEL_DEINITIALIZATION");
   for(int i=0;i<BOOK_DIAG_PENDING_CAP;i++)
   {
      if(!gBookDiagAwaiting[i].used) continue;
      BookArmedEvent e; ZeroMemory(e); e.event="ORDER_EXECUTION_UNCONFIRMED_AT_DEINIT";
      e.reason="NO_DURABLE_OBSERVER_CORRELATION_RESTORED_NEXT_RUN";
      e.state=gBookDiagAwaiting[i].state; e.order=gBookDiagAwaiting[i].order;
      e.deal=gBookDiagAwaiting[i].deal; e.request_id=gBookDiagAwaiting[i].request_id;
      BookDiagEnqueue(e,true);
   }
   // Bounded final drain, no waiting and no changes to financial journals.
   BookDiagTimer();
   if(gBookDiagFile!=INVALID_HANDLE) { FileClose(gBookDiagFile); gBookDiagFile=INVALID_HANDLE; }
   PrintFormat("[BOOK_ARMED][SUMMARY] pending_rows=%d dropped=%I64u capacity_unresolved=%I64u dedup=%I64u bytes=%I64u hook_mean_us=%.3f hook_max_us=%I64u timer_last_us=%I64u; observation coverage is sampled, no homology claim",
      gBookDiagCount,gBookDiagDropped,gBookDiagOverwrites,gBookDiagDeduplicated,gBookDiagBytes,
      gBookDiagHookCount>0?(double)gBookDiagHookTotalUS/(double)gBookDiagHookCount:0,
      gBookDiagHookMaxUS,gBookDiagTimerUS);
   gBookDiagReady=false;
}
#endif
// END_INCORPORATED Include/BookArmedDiagnostics.mqh

// ORIGINAL_INCLUDE | #include "Include/BookRuntimePerf.mqh"
// BEGIN_INCORPORATED Include/BookRuntimePerf.mqh
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
// END_INCORPORATED Include/BookRuntimePerf.mqh

// Operational validation shares arithmetic, never the observer CSV queue.
// ORIGINAL_INCLUDE | #include "Include/BookDecisionRuntime.mqh"
// BEGIN_INCORPORATED Include/BookDecisionRuntime.mqh
#ifndef BOOK_DECISION_RUNTIME_MQH
#define BOOK_DECISION_RUNTIME_MQH
// ORIGINAL_INCLUDE | #include "BookDecisionCore.mqh"
// BEGIN_INCORPORATED Include/BookDecisionCore.mqh
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
// END_INCORPORATED Include/BookDecisionCore.mqh
// HOST_CPP_INACTIVE | #ifdef __cplusplus
// HOST_CPP_INACTIVE | #include <vector>
// HOST_CPP_INACTIVE | #endif

// Operational data, never an observer/CSV queue. Integer trade volume and
// provider BUY/SELL flags are the explicitly selected source. Every tick in an
// inclusive timestamp group has an ordinal, including byte-identical trades.
#define BOOK_DECISION_TAPE_CAP 8192
#define BOOK_DECISION_WINDOW_CAP 16
#define BOOK_DECISION_SOURCE_AGE_MS 2000
#define BOOK_DECISION_PROOF_AGE_MS 2000
#define BOOK_DECISION_MIN_POLL_MS 10
struct BookDecisionClosedWindow
{
   BookDecisionWindow window;
   BookDecisionRanks buy_ranks,sell_ranks;
};
BookDecisionConfig gBookDecisionConfig;
BookDecisionHistory gBookDecisionHistory;
BookDecisionWindow gBookDecisionWindow;
BookDecisionClosedWindow gBookDecisionClosed[BOOK_DECISION_WINDOW_CAP];
MqlTick gBookDecisionTape[BOOK_DECISION_TAPE_CAP];
MqlTick gBookDecisionTail[BOOK_DECISION_TAPE_CAP];
int gBookDecisionTapeHead=0,gBookDecisionTapeCount=0;
int gBookDecisionClosedHead=0,gBookDecisionClosedCount=0,gBookDecisionTailCount=0;
long gBookDecisionStartMSC=0,gBookDecisionCoveredMSC=0,gBookDecisionCursorMSC=0;
long gBookDecisionTapeFromMSC=0,gBookDecisionLastTradeMSC=0,gBookDecisionFaultMSC=0;
long gBookDecisionEpoch=0,gBookDecisionDataVersion=0,gBookDecisionSignalGeneration=0;
bool gBookDecisionReady=false,gBookDecisionFault=false;
bool gBookDecisionAcquisitionIncomplete=false;
string gBookDecisionSymbol="",gBookDecisionFaultReason="";
ENUM_BOOK_DECISION_RESULT gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;
string gBookDecisionReason="NOT_INITIALIZED";
BookDecisionVerdict gBookDecisionVerdict;
ArmedSignal gBookDecisionBound;
bool gBookDecisionBoundActive=false,gBookDecisionHaveFrozenTest=false;
BookDecisionWindow gBookDecisionFrozenTest;
BookDecisionRanks gBookDecisionFrozenTestRanks;
int gBookDecisionSubtype=0,gBookDecisionCandidateSubtype=0;
long gBookDecisionBoundEpoch=0,gBookDecisionProofGeneration=0,gBookDecisionProofEpoch=0;
long gBookDecisionProofVersion=0;
ulong gBookDecisionProofLocalMS=0;
datetime gBookDecisionProofSignalBar=0,gBookDecisionProofContextBar=0;
int gBookDecisionProofSignalSeconds=0,gBookDecisionProofContextSeconds=0;
ulong gBookDecisionLastPollLocalMS=0;
BookDecisionWindow gBookDecisionReactionCache;
bool gBookDecisionReactionCached=false,gBookDecisionReactionAvailable=false;
long gBookDecisionReactionTestTo=0,gBookDecisionReactionEpoch=0,gBookDecisionReactionVersion=0;
ENUM_BOOK_DECISION_RESULT gBookDecisionLastLogResult=DECISION_DADOS_INSUFICIENTES;
string gBookDecisionLastLogReason="";
ulong gBookDecisionLastLogMS=0;
ulong gBookDecisionIngestCalls=0,gBookDecisionIngestUS=0,gBookDecisionIngestMaxUS=0;
ulong gBookDecisionCoreCalls=0,gBookDecisionCoreUS=0,gBookDecisionCoreMaxUS=0;
ulong gBookDecisionPollCalls=0,gBookDecisionPollUS=0,gBookDecisionPollMaxUS=0;
ulong gBookDecisionTapeDrops=0,gBookDecisionBorrowedOversize=0,gBookDecisionDataErrors=0;
ulong gBookDecisionReactionRebuilds=0,gBookDecisionReactionRows=0;

void BookDecisionConfigure()
{
   BookDecisionConfigDefaults(gBookDecisionConfig);
   gBookDecisionConfig.source=(int)Inp_DecisionAggressorSource;
   gBookDecisionConfig.window_sec=Inp_DecisionWindowSec;
   gBookDecisionConfig.min_refs=Inp_DecisionMinReferences;
   gBookDecisionConfig.effort_q=Inp_DecisionEffortQuantile;
   gBookDecisionConfig.result_q=Inp_DecisionResultQuantile;
   gBookDecisionConfig.coverage=Inp_DecisionMinCoverage;
   gBookDecisionConfig.directional_share=Inp_DecisionMinDirectionalShare;
   gBookDecisionConfig.acceptance=Inp_DecisionMinAcceptance;
   gBookDecisionConfig.observed_coverage=Inp_DecisionMinObservedCoverage;
   gBookDecisionConfig.progress_ticks=Inp_DecisionMinProgressTicks;
   gBookDecisionConfig.effort_factor=Inp_DecisionComparableEffortFactor;
   gBookDecisionConfig.tick_size=gTickSize;
}
void BookDecisionAccountCost(const ulong began,const int kind)
{
   ulong elapsed=GetMicrosecondCount()-began;
   if(kind==0)
   { gBookDecisionIngestCalls++; gBookDecisionIngestUS+=elapsed;
     if(elapsed>gBookDecisionIngestMaxUS) gBookDecisionIngestMaxUS=elapsed; }
   else if(kind==1)
   { gBookDecisionCoreCalls++; gBookDecisionCoreUS+=elapsed;
     if(elapsed>gBookDecisionCoreMaxUS) gBookDecisionCoreMaxUS=elapsed; }
   else
   { gBookDecisionPollCalls++; gBookDecisionPollUS+=elapsed;
     if(elapsed>gBookDecisionPollMaxUS) gBookDecisionPollMaxUS=elapsed; }
}
void BookDecisionReport()
{
   if(!Inp_EnableArmedDiagnostics) return;
   if(gBookDecisionResult==gBookDecisionLastLogResult &&
      gBookDecisionReason==gBookDecisionLastLogReason) return;
   ulong now=GetTickCount64();
   if(gBookDecisionLastLogMS>0 && now-gBookDecisionLastLogMS<1000) return;
   PrintFormat("[BOOK_DECISION] result=%d reason=%s symbol=%s route=%s dir=%d bar=%I64d armed=%I64d generation=%I64d epoch=%I64d refs=%d; experimental thresholds",
      (int)gBookDecisionResult,gBookDecisionReason,gBookDecisionSymbol,
      armed.route,armed.dir,(long)armed.regionEndTime,(long)armed.armedAt,
      gBookDecisionSignalGeneration,gBookDecisionEpoch,gBookDecisionVerdict.conditional_count);
   gBookDecisionLastLogResult=gBookDecisionResult;
   gBookDecisionLastLogReason=gBookDecisionReason; gBookDecisionLastLogMS=now;
}
void BookDecisionResetSignal()
{
   gBookDecisionSignalGeneration++;
   gBookDecisionBoundActive=false; gBookDecisionHaveFrozenTest=false;
   gBookDecisionProofGeneration=0; gBookDecisionProofEpoch=0;
   gBookDecisionProofVersion=0; gBookDecisionProofLocalMS=0;
   gBookDecisionProofSignalBar=0; gBookDecisionProofContextBar=0;
   gBookDecisionReactionCached=false;
   gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;
   gBookDecisionReason="NO_BOUND_SIGNAL";
}
bool BookDecisionIdentityCurrent(const ArmedSignal &original)
{
   return gBookDecisionBoundActive && armed.active && original.active &&
      armed.dir==original.dir && armed.route==original.route && armed.mode==original.mode &&
      armed.armedAt==original.armedAt && armed.regionEndTime==original.regionEndTime &&
      armed.regionHigh==original.regionHigh && armed.regionLow==original.regionLow &&
      armed.activeSL_Pts==original.activeSL_Pts && armed.activeTP_Pts==original.activeTP_Pts &&
      armed.breakoutEffortMin==original.breakoutEffortMin &&
      original.dir==gBookDecisionBound.dir && original.route==gBookDecisionBound.route &&
      original.mode==gBookDecisionBound.mode && original.armedAt==gBookDecisionBound.armedAt &&
      original.regionEndTime==gBookDecisionBound.regionEndTime &&
      original.regionHigh==gBookDecisionBound.regionHigh &&
      original.regionLow==gBookDecisionBound.regionLow &&
      original.activeSL_Pts==gBookDecisionBound.activeSL_Pts &&
      original.activeTP_Pts==gBookDecisionBound.activeTP_Pts &&
      original.breakoutEffortMin==gBookDecisionBound.breakoutEffortMin;
}
int BookDecisionBucket(const long from_msc)
{ return (int)((from_msc/1800000)%48); }
void BookDecisionOpenWindow(const long from_msc,const double level,const long reference_msc,
                            const double previous_vwap,const bool previous_available)
{
   long duration=(long)gBookDecisionConfig.window_sec*1000;
   BookDecisionWindowReset(gBookDecisionWindow,from_msc,from_msc+duration-1,
      level,gBookDecisionConfig.tick_size,reference_msc,previous_vwap,previous_available,
      gBookDecisionConfig.source,BookDecisionBucket(from_msc),gBookDecisionEpoch);
   gBookDecisionWindow.source_ok=true;
}
void BookDecisionDataReset(const long now_msc)
{
   gBookDecisionEpoch++; gBookDecisionDataVersion++;
   BookDecisionHistoryReset(gBookDecisionHistory);
   gBookDecisionTapeHead=0; gBookDecisionTapeCount=0;
   gBookDecisionClosedHead=0; gBookDecisionClosedCount=0;
   gBookDecisionTailCount=0; gBookDecisionCursorMSC=0;
   long duration=(long)gBookDecisionConfig.window_sec*1000;
   gBookDecisionStartMSC=(now_msc/duration)*duration;
   gBookDecisionCoveredMSC=gBookDecisionStartMSC-1;
   gBookDecisionTapeFromMSC=gBookDecisionStartMSC;
   gBookDecisionLastTradeMSC=0;
   gBookDecisionFault=false; gBookDecisionFaultReason="";
   gBookDecisionAcquisitionIncomplete=false;
   gBookDecisionReactionCached=false; gBookDecisionLastPollLocalMS=0;
   gBookDecisionHaveFrozenTest=false;
   gBookDecisionProofGeneration=0; gBookDecisionProofEpoch=0;
   BookDecisionOpenWindow(gBookDecisionStartMSC,0,0,0,false);
}
void BookDecisionDataFailure(const string reason)
{
   gBookDecisionFault=true; gBookDecisionFaultReason=reason;
   gBookDecisionFaultMSC=gBookDecisionCoveredMSC;
   gBookDecisionDataErrors++; gBookDecisionDataVersion++;
   gBookDecisionProofGeneration=0; gBookDecisionProofEpoch=0;
   gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;
   gBookDecisionReason=reason; BookDecisionReport();
}
bool BookDecisionInit()
{
   BookDecisionResetSignal(); BookDecisionConfigure();
   gBookDecisionSymbol=Symbol();
   gBookDecisionReady=false;
   if(Inp_DecisionMode==DECISION_ORIGINAL) return true;
   if(Inp_DecisionMode!=DECISION_APLICAR)
   { gBookDecisionReason="INVALID_DECISION_MODE"; BookDecisionReport(); return false; }
   if(!BookDecisionConfigValid(gBookDecisionConfig))
   { gBookDecisionReason="INVALID_DECISION_CONFIGURATION"; BookDecisionReport(); return false; }
   BookDecisionDataReset((long)TimeTradeServer()*1000);
   gBookDecisionReady=true;
   PrintFormat("[BOOK_DECISION][CONFIG] mode=APLICAR source=%d volume=MqlTick.volume window_sec=%d min_refs=%d P_effort=%.3f P_result=%.3f coverage=%.3f directional_share=%.3f acceptance_volume_and_time=%.3f observed_coverage=%.3f progress_ticks=%.3f effort_factor=%.3f; feed setting is an assumption, not provider validation; source 0 blocks entries",
      gBookDecisionConfig.source,gBookDecisionConfig.window_sec,gBookDecisionConfig.min_refs,
      gBookDecisionConfig.effort_q,gBookDecisionConfig.result_q,gBookDecisionConfig.coverage,
      gBookDecisionConfig.directional_share,gBookDecisionConfig.acceptance,
      gBookDecisionConfig.observed_coverage,gBookDecisionConfig.progress_ticks,
      gBookDecisionConfig.effort_factor);
   return true;
}
void BookDecisionCloseCurrent()
{
   gBookDecisionWindow.complete=true;
   BookDecisionClosedWindow closed;
   closed.window=gBookDecisionWindow;
   // Compare BOTH directions against strictly prior windows, BEFORE insertion.
   BookDecisionCompare(gBookDecisionConfig,gBookDecisionHistory,closed.window,1,closed.buy_ranks);
   BookDecisionCompare(gBookDecisionConfig,gBookDecisionHistory,closed.window,-1,closed.sell_ranks);
   int slot=(gBookDecisionClosedHead+gBookDecisionClosedCount)%BOOK_DECISION_WINDOW_CAP;
   if(gBookDecisionClosedCount==BOOK_DECISION_WINDOW_CAP)
   { slot=gBookDecisionClosedHead; gBookDecisionClosedHead=(gBookDecisionClosedHead+1)%BOOK_DECISION_WINDOW_CAP; }
   else gBookDecisionClosedCount++;
   gBookDecisionClosed[slot]=closed;
   BookDecisionHistoryInsert(gBookDecisionConfig,gBookDecisionHistory,closed.window);
   double level=closed.window.flow.count>0?closed.window.flow.last:0;
   long reference=closed.window.flow.last_msc;
   double volume=closed.window.vb+closed.window.vs+closed.window.vu;
   double previous_vwap=volume>0?closed.window.pv/volume:0;
   BookDecisionOpenWindow(closed.window.flow.to_msc+1,level,reference,
      previous_vwap,closed.window.flow.count>0 && volume>0);
}
bool BookDecisionAdvanceWindows(const long known_through_msc)
{
   int count=0;
   // The current timestamp group remains appendable. Close only strictly older
   // windows; their complete inclusive batches cannot acquire another ordinal.
   while(known_through_msc>gBookDecisionWindow.flow.to_msc)
   {
      if(++count>BOOK_DECISION_WINDOW_CAP*4)
      { BookDecisionDataFailure("REGULAR_WINDOW_GAP"); return false; }
      BookDecisionCloseCurrent();
   }
   return true;
}
bool BookDecisionSameTick(const MqlTick &a,const MqlTick &b)
{
   return a.time==b.time && a.time_msc==b.time_msc && a.bid==b.bid && a.ask==b.ask &&
      a.last==b.last && a.volume==b.volume && a.volume_real==b.volume_real && a.flags==b.flags;
}
void BookDecisionAppendTrade(const MqlTick &tick)
{
   int slot=(gBookDecisionTapeHead+gBookDecisionTapeCount)%BOOK_DECISION_TAPE_CAP;
   if(gBookDecisionTapeCount==BOOK_DECISION_TAPE_CAP)
   {
      slot=gBookDecisionTapeHead;
      long lost=gBookDecisionTape[slot].time_msc;
      if(lost+1>gBookDecisionTapeFromMSC) gBookDecisionTapeFromMSC=lost+1;
      gBookDecisionTapeHead=(gBookDecisionTapeHead+1)%BOOK_DECISION_TAPE_CAP;
      gBookDecisionTapeDrops++;
   }
   else gBookDecisionTapeCount++;
   gBookDecisionTape[slot]=tick;
   int aggressor=0;
   bool buy=(tick.flags&TICK_FLAG_BUY)!=0,sell=(tick.flags&TICK_FLAG_SELL)!=0;
   if(buy && sell) aggressor=2; else if(buy) aggressor=1; else if(sell) aggressor=-1;
   BookDecisionWindowTick(gBookDecisionWindow,tick.last,(double)tick.volume,tick.time_msc,aggressor);
   gBookDecisionLastTradeMSC=tick.time_msc; gBookDecisionDataVersion++;
}
// HOST_CPP_INACTIVE | #ifdef __cplusplus
// HOST_CPP_INACTIVE | void BookDecisionIngestBatch(ulong from_msc,ulong to_msc,const MqlTick ticks[],int copied)
// HOST_CPP_INACTIVE | #else
void BookDecisionIngestBatch(ulong from_msc,ulong to_msc,const MqlTick &ticks[],int copied)
// HOST_CPP_INACTIVE | #endif
{
   if(Inp_DecisionMode==DECISION_ORIGINAL || !gBookDecisionReady || gBookDecisionFault) return;
   ulong began=GetMicrosecondCount();
   if(to_msc<(ulong)gBookDecisionStartMSC || to_msc<(ulong)gBookDecisionCoveredMSC)
   { BookDecisionAccountCost(began,0); return; }
   // Borrowed full-day/M1 arrays are never rescanned without a bound. The own
   // incremental cursor fills only the missing suffix, with at most 8192 rows.
   if(copied>BOOK_DECISION_TAPE_CAP)
   { gBookDecisionBorrowedOversize++; BookDecisionAccountCost(began,0); return; }
   if(copied<0 || to_msc<from_msc || Symbol()!=gBookDecisionSymbol ||
      (long)to_msc>(long)TimeTradeServer()*1000+1000)
   { BookDecisionDataFailure("INVALID_BATCH_OR_SYMBOL"); BookDecisionAccountCost(began,0); return; }
   if(from_msc>(ulong)(gBookDecisionCoveredMSC+1))
   { BookDecisionDataFailure("UNCOVERED_BATCH_INTERVAL"); BookDecisionAccountCost(began,0); return; }
   long previous=-1;
   int tail_seen=0;
   // Validate the entire bounded batch before mutating any accumulator.
   for(int i=0;i<copied;i++)
   {
      const MqlTick tick=ticks[i];
      if(tick.time_msc<(long)from_msc || tick.time_msc>(long)to_msc ||
         tick.time_msc<previous || tick.time!=(datetime)(tick.time_msc/1000) ||
         !BookMicroFinite(tick.last) || tick.last<=0 || tick.volume==0 ||
         tick.volume>9007199254740992 || !BookMicroFinite(tick.volume_real) || tick.volume_real<0 ||
         ((tick.flags&(TICK_FLAG_LAST|TICK_FLAG_VOLUME|TICK_FLAG_BUY|TICK_FLAG_SELL))==0))
      { BookDecisionDataFailure("MALFORMED_OR_UNORDERED_TRADE_BATCH"); BookDecisionAccountCost(began,0); return; }
      previous=tick.time_msc;
      if(tick.time_msc==gBookDecisionCursorMSC)
      {
         if(tail_seen<gBookDecisionTailCount &&
            !BookDecisionSameTick(tick,gBookDecisionTail[tail_seen]))
         { BookDecisionDataFailure("OVERLAP_PREFIX_CHANGED"); BookDecisionAccountCost(began,0); return; }
         tail_seen++;
      }
   }
   if(gBookDecisionTailCount>0 && from_msc<=(ulong)gBookDecisionCursorMSC &&
      to_msc>=(ulong)gBookDecisionCursorMSC && tail_seen<gBookDecisionTailCount)
   { BookDecisionDataFailure("OVERLAP_PREFIX_INCOMPLETE"); BookDecisionAccountCost(began,0); return; }
   int ordinal=0;
   long observed_msc=-1;
   for(int i=0;i<copied;i++)
   {
      const MqlTick tick=ticks[i];
      if(tick.time_msc<gBookDecisionStartMSC || tick.time_msc<gBookDecisionCursorMSC) continue;
      if(observed_msc!=tick.time_msc) { observed_msc=tick.time_msc; ordinal=0; }
      ordinal++;
      if(tick.time_msc==gBookDecisionCursorMSC && ordinal<=gBookDecisionTailCount) continue;
      if(tick.time_msc<gBookDecisionCoveredMSC ||
         tick.time_msc<gBookDecisionWindow.flow.from_msc)
      { BookDecisionDataFailure("LATE_TRADE_BEHIND_WATERMARK"); break; }
      if(!BookDecisionAdvanceWindows(tick.time_msc)) break;
      if(tick.time_msc!=gBookDecisionCursorMSC)
      { gBookDecisionCursorMSC=tick.time_msc; gBookDecisionTailCount=0; }
      if(gBookDecisionTailCount>=BOOK_DECISION_TAPE_CAP)
      { BookDecisionDataFailure("TIMESTAMP_ORDINAL_CAPACITY"); break; }
      gBookDecisionTail[gBookDecisionTailCount++]=tick;
      BookDecisionAppendTrade(tick);
   }
   if(!gBookDecisionFault)
   {
      if((long)to_msc>gBookDecisionCoveredMSC)
      { gBookDecisionCoveredMSC=(long)to_msc; gBookDecisionDataVersion++; }
      BookDecisionAdvanceWindows(gBookDecisionCoveredMSC);
      gBookDecisionAcquisitionIncomplete=false;
   }
   BookDecisionAccountCost(began,0);
}
void BookDecisionPump()
{
   if(Inp_DecisionMode==DECISION_ORIGINAL || !gBookDecisionReady) return;
   MqlTick quote;
   if(!SymbolInfoTick(Symbol(),quote) || quote.time_msc<=0)
   { BookDecisionDataFailure("MARKET_CLOCK_UNAVAILABLE"); return; }
   long goal=quote.time_msc;
   if(gBookDecisionFault)
   {
      if(goal<=gBookDecisionFaultMSC+(long)gBookDecisionConfig.window_sec*1000) return;
      // Lost continuity never reuses old references/approvals. Bounded recovery
      // starts a new epoch and must warm the same causal history again.
      BookDecisionDataReset(goal);
   }
   ulong local_now=GetTickCount64();
   if(gBookDecisionLastPollLocalMS>0 && local_now>=gBookDecisionLastPollLocalMS &&
      local_now-gBookDecisionLastPollLocalMS<BOOK_DECISION_MIN_POLL_MS)
   {
      // A skipped acquisition is not evidence of one trade per OnTick. Keep the
      // ARMED clocks but do not authorize an unknown append at the same ms.
      gBookDecisionAcquisitionIncomplete=true; return;
   }
   gBookDecisionLastPollLocalMS=local_now;
   long from=gBookDecisionCursorMSC>0?gBookDecisionCursorMSC:gBookDecisionStartMSC;
   if(goal<from) { BookDecisionDataFailure("MARKET_CLOCK_REVERSED"); return; }
   ulong began=GetMicrosecondCount();
// HOST_CPP_INACTIVE | #ifdef __cplusplus
// HOST_CPP_INACTIVE |    std::vector<MqlTick> ticks;
// HOST_CPP_INACTIVE | #else
   MqlTick ticks[];
// HOST_CPP_INACTIVE | #endif
   ResetLastError();
   int copied=CopyTicks(Symbol(),ticks,COPY_TICKS_TRADE,(ulong)from,BOOK_DECISION_TAPE_CAP);
   int error=GetLastError();
   if(copied<0 || error!=0)
      BookDecisionDataFailure("INCREMENTAL_TRADE_COPY_FAILED");
   else
   {
      long through=goal;
      if(copied>0)
      {
         long last=ticks[copied-1].time_msc;
         if(copied==BOOK_DECISION_TAPE_CAP) through=last;
         else if(last>through) through=last;
         if(copied==BOOK_DECISION_TAPE_CAP && last==from)
            BookDecisionDataFailure("TIMESTAMP_ORDINAL_CAPACITY");
      }
      if(!gBookDecisionFault)
      {
// HOST_CPP_INACTIVE | #ifdef __cplusplus
// HOST_CPP_INACTIVE |          BookDecisionIngestBatch((ulong)from,(ulong)through,ticks.data(),copied);
// HOST_CPP_INACTIVE | #else
         BookDecisionIngestBatch((ulong)from,(ulong)through,ticks,copied);
// HOST_CPP_INACTIVE | #endif
         // A full bounded CopyTicks result does not prove its suffix complete.
         // The next incremental query must catch up before any authorization.
         if(copied==BOOK_DECISION_TAPE_CAP) gBookDecisionAcquisitionIncomplete=true;
      }
   }
   ArrayFree(ticks);
   BookDecisionAccountCost(began,2);
}
bool BookDecisionSourceFresh()
{
   if(!gBookDecisionReady || gBookDecisionFault || gBookDecisionAcquisitionIncomplete || gBookDecisionLastTradeMSC<=0 ||
      Symbol()!=gBookDecisionSymbol) return false;
   long now=(long)TimeTradeServer()*1000;
   return now-gBookDecisionLastTradeMSC<=BOOK_DECISION_SOURCE_AGE_MS &&
      gBookDecisionLastTradeMSC-now<=1000 &&
      now-gBookDecisionCoveredMSC<=BOOK_DECISION_SOURCE_AGE_MS;
}
bool BookDecisionReaction(const BookDecisionWindow &test,BookDecisionWindow &reaction)
{
   if(gBookDecisionReactionCached && gBookDecisionReactionTestTo==test.flow.to_msc &&
      gBookDecisionReactionEpoch==gBookDecisionEpoch &&
      gBookDecisionReactionVersion==gBookDecisionDataVersion)
   { reaction=gBookDecisionReactionCache; return gBookDecisionReactionAvailable; }
   gBookDecisionReactionCached=true;
   gBookDecisionReactionTestTo=test.flow.to_msc;
   gBookDecisionReactionEpoch=gBookDecisionEpoch;
   gBookDecisionReactionVersion=gBookDecisionDataVersion;
   gBookDecisionReactionAvailable=false; gBookDecisionReactionRebuilds++;
   long from=test.flow.to_msc+1,to=gBookDecisionCoveredMSC;
   if(from>to || from<gBookDecisionTapeFromMSC ||
      to-test.flow.to_msc>(long)gBookDecisionConfig.window_sec*2000) return false;
   BookDecisionWindowReset(reaction,from,to,test.flow.level,gBookDecisionConfig.tick_size,
      test.flow.to_msc,test.previous_vwap,test.previous_available,
      gBookDecisionConfig.source,test.bucket,gBookDecisionEpoch);
   reaction.source_ok=true;
   for(int i=0;i<gBookDecisionTapeCount;i++)
   {
      MqlTick tick=gBookDecisionTape[(gBookDecisionTapeHead+i)%BOOK_DECISION_TAPE_CAP];
      gBookDecisionReactionRows++;
      if(tick.time_msc<from || tick.time_msc>to) continue;
      int direction=0;
      bool buy=(tick.flags&TICK_FLAG_BUY)!=0,sell=(tick.flags&TICK_FLAG_SELL)!=0;
      if(buy && sell) direction=2; else if(buy) direction=1; else if(sell) direction=-1;
      BookDecisionWindowTick(reaction,tick.last,(double)tick.volume,tick.time_msc,direction);
   }
   reaction.complete=true; // complete KNOWN prefix, not a completed future window
   gBookDecisionReactionCache=reaction;
   gBookDecisionReactionAvailable=reaction.flow.count>0;
   return gBookDecisionReactionAvailable;
}
void BookDecisionEvidenceFor(const int direction,const bool cont,const bool bound,
                            BookDecisionEvidence &evidence)
{
   ZeroMemory(evidence);
   evidence.now_msc=gBookDecisionCoveredMSC;
   evidence.original_subtype=bound?gBookDecisionSubtype:gBookDecisionCandidateSubtype;
   long max_age=(long)gBookDecisionConfig.window_sec*2000;
   for(int i=gBookDecisionClosedCount-1;i>=0;i--)
   {
      BookDecisionClosedWindow closed=gBookDecisionClosed[(gBookDecisionClosedHead+i)%BOOK_DECISION_WINDOW_CAP];
      if(gBookDecisionCoveredMSC-closed.window.flow.to_msc>max_age) break;
      BookDecisionRanks forward,reverse;
      if(direction==1) { forward=closed.buy_ranks; reverse=closed.sell_ranks; }
      else { forward=closed.sell_ranks; reverse=closed.buy_ranks; }
      if(!evidence.have_current)
      { evidence.have_current=true; evidence.current=closed.window; evidence.current_ranks=forward; }
      if(!evidence.have_forward && BookDecisionForwardPredicate(gBookDecisionConfig,closed.window,forward,direction))
      { evidence.have_forward=true; evidence.forward=closed.window; evidence.forward_ranks=forward; }
      if(!evidence.have_test && !cont &&
         BookDecisionTestPredicate(gBookDecisionConfig,closed.window,reverse,direction))
      { evidence.have_test=true; evidence.test=closed.window; evidence.test_ranks=reverse; }
   }
   if(bound && gBookDecisionHaveFrozenTest)
   {
      evidence.have_test=true; evidence.test=gBookDecisionFrozenTest;
      evidence.test_ranks=gBookDecisionFrozenTestRanks;
   }
   else if(bound && evidence.have_test)
   {
      gBookDecisionFrozenTest=evidence.test; gBookDecisionFrozenTestRanks=evidence.test_ranks;
      gBookDecisionHaveFrozenTest=true;
   }
   if(evidence.have_test)
      evidence.have_reaction=BookDecisionReaction(evidence.test,evidence.reaction);
   // A known live prefix can demonstrate rejection immediately; it need not
   // wait for another regular close. With fewer than two trades retain the
   // already completed evidence instead of manufacturing an observed interval.
   if(gBookDecisionWindow.flow.count>=2 &&
      gBookDecisionCoveredMSC>=gBookDecisionWindow.flow.from_msc)
   {
      evidence.have_current=true; evidence.current=gBookDecisionWindow;
      evidence.current.flow.to_msc=gBookDecisionCoveredMSC;
      evidence.current.complete=true;
      BookDecisionCompare(gBookDecisionConfig,gBookDecisionHistory,evidence.current,
         direction,evidence.current_ranks);
   }
}
void BookDecisionAssessCurrent(const int direction,const bool cont,const bool bound)
{
   ulong began=GetMicrosecondCount();
   if(!BookDecisionSourceFresh())
   {
      ZeroMemory(gBookDecisionVerdict);
      gBookDecisionVerdict.result=DECISION_DADOS_INSUFICIENTES;
      if(!gBookDecisionReady) gBookDecisionVerdict.reason="DECISION_COLLECTOR_NOT_READY";
      else if(gBookDecisionFault) gBookDecisionVerdict.reason=gBookDecisionFaultReason;
      else if(gBookDecisionAcquisitionIncomplete) gBookDecisionVerdict.reason="COLLECTION_BACKLOG_OR_THROTTLED";
      else gBookDecisionVerdict.reason="TRADED_DATA_STALE_OR_UNAVAILABLE";
   }
   else
   {
      BookDecisionEvidence evidence;
      BookDecisionEvidenceFor(direction,cont,bound,evidence);
      BookDecisionAssess(gBookDecisionConfig,evidence,direction,cont,bound,gBookDecisionVerdict);
   }
   gBookDecisionResult=gBookDecisionVerdict.result;
   gBookDecisionReason=gBookDecisionVerdict.reason;
   BookDecisionAccountCost(began,1);
}
bool BookDecisionCandidate(const MatrixSnapshot &snapshot,const int direction,
                           const bool cont,const datetime signal_bar)
{
   if(Inp_DecisionMode==DECISION_ORIGINAL) return true;
   gBookDecisionCandidateSubtype=snapshot.absDivergence?1:(snapshot.absFollowingReaction?2:0);
   bool eligible=snapshot.status==MSS_OK && !(snapshot.absValid && snapshot.contValid) &&
      (cont?snapshot.contValid:snapshot.absValid) && signal_bar>0 &&
      direction==(cont?snapshot.dirCont:snapshot.dir);
   if(!eligible)
   {
      gBookDecisionResult=DECISION_VETAR_CANDIDATO;
      gBookDecisionReason="ORIGINAL_CANDIDATE_INELIGIBLE"; BookDecisionReport(); return false;
   }
   BookDecisionAssessCurrent(direction,cont,false); BookDecisionReport();
   return gBookDecisionResult!=DECISION_VETAR_CANDIDATO &&
          gBookDecisionResult!=DECISION_INVALIDAR_ARMED;
}
void BookDecisionBind()
{
   if(Inp_DecisionMode==DECISION_ORIGINAL) return;
   gBookDecisionSignalGeneration++;
   gBookDecisionBound=armed; gBookDecisionBoundActive=armed.active;
   gBookDecisionBoundEpoch=gBookDecisionEpoch;
   gBookDecisionHaveFrozenTest=false; gBookDecisionSubtype=gBookDecisionCandidateSubtype;
   gBookDecisionProofGeneration=0;
   BookDecisionEvidence evidence;
   BookDecisionEvidenceFor(armed.dir,armed.route=="CONT",true,evidence);
}
ENUM_BOOK_DECISION_RESULT BookDecisionEvaluateArmed()
{
   if(Inp_DecisionMode==DECISION_ORIGINAL)
   { gBookDecisionResult=DECISION_VALIDAR; gBookDecisionReason="ORIGINAL_COMPATIBILITY"; return gBookDecisionResult; }
   gBookDecisionProofGeneration=0;
   if(!BookDecisionIdentityCurrent(gBookDecisionBound))
   {
      gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;
      gBookDecisionReason="ARMED_IDENTITY_NOT_BOUND"; BookDecisionReport(); return gBookDecisionResult;
   }
   if(gBookDecisionBoundEpoch!=gBookDecisionEpoch)
   {
      // A recovered collector may warm again, but cannot inherit its old T/R.
      gBookDecisionBoundEpoch=gBookDecisionEpoch; gBookDecisionHaveFrozenTest=false;
   }
   BookDecisionAssessCurrent(armed.dir,armed.route=="CONT",true);
   if(gBookDecisionResult==DECISION_VALIDAR)
   {
      gBookDecisionProofSignalBar=iTime(Symbol(),Inp_SignalTF,0);
      gBookDecisionProofContextBar=iTime(Symbol(),Inp_ContextTF,0);
      gBookDecisionProofSignalSeconds=PeriodSeconds(Inp_SignalTF);
      gBookDecisionProofContextSeconds=PeriodSeconds(Inp_ContextTF);
      datetime now=TimeTradeServer();
      if(gBookDecisionProofSignalBar<=0 || gBookDecisionProofContextBar<=0 ||
         gBookDecisionProofSignalSeconds<=0 || gBookDecisionProofContextSeconds<=0 ||
         now<gBookDecisionProofSignalBar || now<gBookDecisionProofContextBar ||
         now>=gBookDecisionProofSignalBar+gBookDecisionProofSignalSeconds ||
         now>=gBookDecisionProofContextBar+gBookDecisionProofContextSeconds)
      { gBookDecisionResult=DECISION_DADOS_INSUFICIENTES;gBookDecisionReason="PROOF_BAR_CLOCK_UNAVAILABLE"; }
      else
      {
         gBookDecisionProofGeneration=gBookDecisionSignalGeneration;
         gBookDecisionProofEpoch=gBookDecisionEpoch;
         gBookDecisionProofVersion=gBookDecisionDataVersion;
         gBookDecisionProofLocalMS=GetTickCount64();
      }
   }
   BookDecisionReport(); return gBookDecisionResult;
}
bool BookDecisionDispatchValid(const ArmedSignal &original)
{
   if(Inp_DecisionMode==DECISION_ORIGINAL) return true;
   if(gBookDecisionResult!=DECISION_VALIDAR || !BookDecisionIdentityCurrent(original) ||
      gBookDecisionProofGeneration!=gBookDecisionSignalGeneration ||
      gBookDecisionProofEpoch!=gBookDecisionEpoch ||
      gBookDecisionProofVersion!=gBookDecisionDataVersion || !BookDecisionSourceFresh()) return false;
   datetime server_now=TimeTradeServer();
   if(original.armedAt<=0 || server_now<original.armedAt ||
      server_now-original.armedAt>=(datetime)Inp_ArmedTimeoutSec ||
      gBookDecisionProofSignalBar<=0 || gBookDecisionProofContextBar<=0 ||
      server_now<gBookDecisionProofSignalBar || server_now<gBookDecisionProofContextBar ||
      server_now>=gBookDecisionProofSignalBar+gBookDecisionProofSignalSeconds ||
      server_now>=gBookDecisionProofContextBar+gBookDecisionProofContextSeconds) return false;
   MqlDateTime clock; TimeToStruct(server_now,clock);
   int hhmm=clock.hour*100+clock.min;
   if(hhmm<Inp_StartHHMM || hhmm>=Inp_StopEntryHHMM) return false;
   ulong now=GetTickCount64();
   return now>=gBookDecisionProofLocalMS && now-gBookDecisionProofLocalMS<=BOOK_DECISION_PROOF_AGE_MS;
}
void BookDecisionDeinit()
{
   if(Inp_DecisionMode==DECISION_ORIGINAL) return;
   PrintFormat("[BOOK_DECISION][COST] core_calls=%I64u core_total_us=%I64u core_max_us=%I64u ingest_calls=%I64u ingest_total_us=%I64u ingest_max_us=%I64u incremental_queries=%I64u incremental_total_us=%I64u incremental_max_us=%I64u tape_drops=%I64u borrowed_oversize=%I64u data_errors=%I64u reaction_rebuilds=%I64u reaction_scanned_rows=%I64u process_memory_mb=%I64d; local measurements, not proven MT5 latency",
      gBookDecisionCoreCalls,gBookDecisionCoreUS,gBookDecisionCoreMaxUS,
      gBookDecisionIngestCalls,gBookDecisionIngestUS,gBookDecisionIngestMaxUS,
      gBookDecisionPollCalls,gBookDecisionPollUS,gBookDecisionPollMaxUS,
      gBookDecisionTapeDrops,gBookDecisionBorrowedOversize,gBookDecisionDataErrors,
      gBookDecisionReactionRebuilds,gBookDecisionReactionRows,
      MQLInfoInteger(MQL_MEMORY_USED));
}
#endif
// END_INCORPORATED Include/BookDecisionRuntime.mqh
