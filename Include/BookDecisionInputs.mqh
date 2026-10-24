#ifndef BOOK_DECISION_INPUTS_MQH
#define BOOK_DECISION_INPUTS_MQH
// Appended AFTER the 91 preserved BOOK inputs. These are experimental policy
// settings, not a claim about a live chart preset or statistical calibration.
enum ENUM_BOOK_DECISION_MODE { DECISION_ORIGINAL=0, DECISION_APLICAR=1 };
enum ENUM_BOOK_DECISION_SOURCE
{
   DECISION_FLAGS_UNVERIFIED=0,
   DECISION_FLAGS_PROVIDER_ASSERTED=1,
   // Hypothesis: exclusive BUY/SELL on COPY_TICKS_TRADE denotes aggressor.
   // Every operational segment must pass runtime integrity/coverage checks.
   // This does NOT certify the broker's economic classification.
   DECISION_FLAGS_RUNTIME_QUALIFIED=2
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
// An independent explicit assumption about TRADE tick BUY/SELL flags. Neither
// ASSERTED nor RUNTIME_QUALIFIED proves provider accuracy; batches need integrity.
input ENUM_BOOK_DECISION_SOURCE Inp_DecisionAggressorSource = DECISION_FLAGS_RUNTIME_QUALIFIED;
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
