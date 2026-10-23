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
