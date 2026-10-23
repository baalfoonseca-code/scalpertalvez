// Included after the extracted production functions by test_risk_journal.py.
static int checked=0;
void check(bool pass,const char* message) {
   ++checked;
   if(!pass) { std::cerr<<"FAIL "<<message<<'\n'; std::exit(1); }
}
string edit(string row,int index,string value,bool checksum=true) {
   std::vector<string> fields; StringSplit(row,'|',fields); fields.at(index)=value;
   string prefix=fields[0]; for(int i=1;i<39;i++) prefix+="|"+fields.at(i);
   if(checksum) fields[39]=RJChecksum(prefix);
   return prefix+"|"+fields[39]+"|"+fields[40];
}
BookRiskState validState() {
   BookRiskState s{};
   s.pid=12345678901234567UL; s.direction=1; s.route="ABS"; s.mode="BASE";
   s.sentAt=1792713600; s.requestEntry=5500; s.requestSL=5495; s.initialTP=5525;
   s.requestedLots=2; s.sigma=5; s.multiplier=1; s.cap=5; s.raw=5; s.normalized=5;
   s.tpMultiplier=5; s.slMode=SL_SIGMA_COM_TETO; s.tpMode=TP_MODE_BY_ROUTE_R;
   s.stage=BR_WAIT_FILL; return s;
}
int main() {
   BookRiskState s=validState(),parsed{};
   string row=BookRiskRow(s);
   check(BookRiskParse(row,s.pid,parsed),"entry provenance exact roundtrip");
   check(parsed.pid==s.pid,"PID above double exact-integer range retained");
   check(BookRiskRow(parsed)==row,"canonical serialization stable");
   check(parsed.sigma==s.sigma && parsed.normalized==5,"frozen sigma preserved");
   check(!BookRiskParse(row,s.pid+1,parsed),"wrong PID rejected");
   ++testAccount; check(!BookRiskParse(row,s.pid,parsed),"wrong account rejected"); --testAccount;
   testSymbol="WINZ26"; check(!BookRiskParse(row,s.pid,parsed),"wrong symbol rejected"); testSymbol="WDOX26";
   ++gMagicCore; check(!BookRiskParse(row,s.pid,parsed),"wrong magic rejected"); --gMagicCore;
   check(!BookRiskParse(row.substr(0,row.size()-1),s.pid,parsed),"truncated completion rejected");
   check(!BookRiskParse(edit(row,13,"9",false),s.pid,parsed),"checksum corruption rejected");
   check(!BookRiskParse(edit(row,0,"SCALPER_BE1"),s.pid,parsed),"legacy BE is never reinterpreted as lock");
   check(!BookRiskParse(edit(row,5,"0"),s.pid,parsed),"invalid direction rejected");
   check(!BookRiskParse(edit(row,6,"OTHER"),s.pid,parsed),"invalid route rejected");
   check(!BookRiskParse(edit(row,9,"NaN"),s.pid,parsed),"NaN rejected");
   check(!BookRiskParse(edit(row,10,"inf"),s.pid,parsed),"infinity rejected");
   check(!BookRiskParse(edit(row,17,"5.5"),s.pid,parsed),"requested stop over sigma cap rejected");
   check(!BookRiskParse(edit(row,13,"0"),s.pid,parsed),"sigma mode cannot fabricate missing sigma");
   check(!BookRiskParse(edit(row,31,"4294967296"),s.pid,parsed),"request ID overflow rejected");
   check(!BookRiskParse(edit(row,8,"18446744073709551615"),s.pid,parsed),"timestamp overflow rejected");
   check(!BookRiskParse(edit(row,22,"18446744073709551616"),s.pid,parsed),"ticket overflow rejected");
   for(int stage=BR_IDLE;stage<=BR_CLOSED;stage++) {
      s=validState(); s.stage=stage; s.ticket=9001; s.entry=5500.5; s.initialSL=5495;
      s.initialR=5.5; s.volume=2; s.operation=2; s.step=2; s.targetSL=5511.5;
      s.targetTP=5528; s.requestMSC=1792713600010L; s.confirmedMSC=s.requestMSC+100;
      s.requestID=42; s.retcode=(stage==BR_ACK || stage==BR_CONFIRMED?TRADE_RETCODE_DONE:0);
      s.serverSL=s.targetSL; s.serverTP=s.targetTP;
      check(BookRiskParse(BookRiskRow(s),s.pid,parsed),"financial stage restart roundtrip");
      check(parsed.stage==stage,"financial stage not downgraded on restart");
      check(parsed.initialR==5.5 && parsed.initialSL==5495,"initial R never reconstructed from moved SL");
   }
   s.stage=BR_CLOSED; s.realizedNet=-37.5;
   check(BookRiskParse(BookRiskRow(s),s.pid,parsed),"closed losing trade signed net roundtrip");
   check(parsed.realizedNet==-37.5,"negative realized PnL preserved");
   s.realizedNet=12.75;
   check(BookRiskParse(BookRiskRow(s),s.pid,parsed),"closed winning trade roundtrip");
   s=validState(); s.slMode=SL_ORIGINAL_PONTOS; s.sigma=0; s.raw=0;
   check(BookRiskParse(BookRiskRow(s),s.pid,parsed),"legacy fixed stop permits explicitly unavailable sigma");
   s=validState(); s.stage=BR_PENDING; s.ticket=9001; s.entry=5500; s.initialSL=5495;
   s.initialR=5; s.volume=2; s.operation=2; s.step=1; s.targetSL=5505; s.targetTP=5525;
   s.requestMSC=1792713600010L;
   check(BookRiskParse(BookRiskRow(s),s.pid,parsed),"pending with request ID zero retained uncertain after crash barrier");
   check(!BRMayDispatch(parsed.stage),"restored pending zero-ID is not retransmitted");
   row=BookRiskRow(s);
   check(!BookRiskParse(edit(row,29,"0"),s.pid,parsed),"pending invalid target rejected");
   check(!BookRiskParse(edit(row,25,"4"),s.pid,parsed),"initial R inconsistent with confirmed entry stop rejected");
   check(!BookRiskParse(edit(row,21,"4"),s.pid,parsed),"confirmed without DONE acknowledgement rejected");
   // Exercise actual input validation, including disabled optional ladder.
   Inp_SL_Mode=SL_ORIGINAL_PONTOS; Inp_TP_Mode=TP_MODE_ORIGINAL; EnableProfitLocks=false;
   check(BookRiskInputsValid(),"default options valid");
   BE_Trigger_R=3;
   check(BookRiskInputsValid(),"standalone configurable BE 3R with dormant locks allowed");
   EnableProfitLocks=true;
   check(!BookRiskInputsValid(),"active BE/lock trigger ordering rejected");
   Inp_EnableBreakEven=false;
   check(BookRiskInputsValid(),"disabled BE cannot block active locks with earlier trigger");
   Inp_EnableBreakEven=true; BE_Trigger_R=1;
   Lock2_Protected_R=Lock1_Protected_R;
   check(!BookRiskInputsValid(),"active protection levels must increase");
   Lock2_Protected_R=2; EnableProfitLocks=false; Inp_Mult_SL=std::numeric_limits<double>::quiet_NaN();
   check(!BookRiskInputsValid(),"inactive numerical configuration still finite");
   std::cout<<"risk journal/input extraction: "<<checked<<" assertions passed (ASCII host conversions; no MT5 file/server execution)\n";
}
