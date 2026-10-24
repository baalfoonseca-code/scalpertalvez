"""Actual financial CSV producer/index/append/recovery + accounting blocker.

Terminal file operations are deterministic adapters. These tests do not repair
the unavailable real WDO ledger or prove native MT5 durability/locking behavior.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest
from test_compatibility import function, declaration

ROOT = Path(__file__).resolve().parents[1]


def fixture():
    source = (ROOT / 'scalpertalvez.mq5').read_text()
    module = (ROOT / 'Include/BookCsvDiagnostics.mqh').read_text()
    support = (ROOT / 'tests/research_noop_hooks.hpp').read_text() + '\n' + (ROOT / 'tests/corrective_csv_support.hpp').read_text()
    types = '\n'.join(declaration(source, 'struct', name) for name in ['BreakEvenState', 'TradeRecord'])
    support = support.replace('// CSV_PRODUCTION_TYPES', types) + '\n' + function(source, 'DirStr')
    module_functions = ['BookCsvCanCreateMissing', 'BookCsvReject', 'BookCsvParse',
                        'InitializeTradeCsvIndex', 'BookCsvBeforeAppend',
                        'BookCsvRecoveryPathAllowed', 'BookCsvOpenInitialFile']
    main_functions = ['BStr', 'CsvCell', 'CsvAdd', 'CsvD', 'CsvTime', 'TradeCsvContainsPID',
                      'TradeCsvAddPID', 'CsvParsePID', 'CsvColumnIndex', 'CsvConfigHeader',
                      'CsvConfigRow', 'CsvTradeHeader', 'CsvTradeRow', 'WriteTradeHeader',
                      'WriteTradeRow', 'RecoverTradeCsvInfrastructure', 'RecomputeAccountingBlock']
    # Actual production bodies; only MQL dynamic array declarations/arguments
    # map mechanically to std::vector for the host compiler.
    bodies = '\n'.join(function(source, name) for name in main_functions[:14])
    bodies += '\n' + '\n'.join(function(module, name) for name in module_functions)
    bodies += '\n' + '\n'.join(function(source, name) for name in main_functions[14:])
    replacements = {
        'string &fields[]': 'std::vector<string> &fields',
        'string &headers[]': 'std::vector<string> &headers',
        'uchar bytes[];': 'std::vector<uchar> bytes;',
        'uchar encoded[];': 'std::vector<uchar> encoded;',
        'string expected[],headers[],reason="";': 'std::vector<string> expected,headers;string reason="";',
        'ulong candidatePIDs[],unresolvedPIDs[];': 'std::vector<ulong> candidatePIDs,unresolvedPIDs;',
        'long positionRows[];': 'std::vector<long> positionRows;',
        'string fields[];': 'std::vector<string> fields;',
        'ulong sorted[];': 'std::vector<ulong> sorted;',
    }
    for old, new in replacements.items():
        bodies = bodies.replace(old, new)
    globals_ = '''
bool gTradeCsvInfrastructureUnresolved=true;
string gBookCsvLastDiagnostic="";
ulong gBookCsvVerifiedSize=0;
bool gBookCsvObservedEver=false;
bool gBookCsvSentinelWarning=false;
'''
    cases = r'''
TradeRecord record(ulong pid,bool resolved=true){
 TradeRecord r{};r.positionID=pid;r.direction=1;r.route="ABS";r.mode="BASE";
 r.entryTime=900;r.exitTime=990;r.totalVolumeIn=2;r.totalVolumeOut=2;
 r.weightedEntryPrice=5500;r.weightedExitPrice=5505;r.slPrice=5495;r.tpPrice=5510;
 r.netProfit=17.5;r.grossProfit=20;r.commission=-2.5;r.initialRiskMoney=20;r.PnL_R=.875;
 r.closed=true;r.accountingResolved=resolved;r.riskValid=true;r.pnlRValid=resolved;
 r.volumeClosedComplete=true;r.exitReason="SL, \"protected\"\r\nconfirmed";
 return r;
}
string header(){string value="";CsvConfigHeader(value);CsvTradeHeader(value);return value+"\r\n";}
string row(ulong pid,bool resolved=true){string value="";CsvConfigRow(value);CsvTradeRow(value,record(pid,resolved));return value+"\r\n";}
void open_source(const string &bytes){
 csvFiles[gTradeCsvFileName]=bytes;csvTradeHandle=BookCsvOpenInitialFile();assert(csvTradeHandle!=INVALID_HANDLE);
}
void assert_money_unchanged(){assert(dailyNetPnL==17.5&&dailyPnLR==.7&&ordersEnteredToday==1);}
void valid(){
 const ulong pid=9007199254740993UL;string original=header()+row(pid);
 open_source(original);assert(InitializeTradeCsvIndex(gTradeCsvFileName));
 assert(gTradeCsvIndexLoaded&&gTradeCsvAppendSafe&&!gTradeCsvInfrastructureUnresolved);
 assert(gTradeCsvWrittenPIDs.size()==1&&gTradeCsvWrittenPIDs[0]==pid);
 assert(csvFiles[gTradeCsvFileName]==original&&csvWrites==0);
 assert(WriteTradeRow(record(pid)));assert(csvWrites==0);
 assert(WriteTradeRow(record(pid+1)));assert(csvWrites==1);
 string written=csvFiles[gTradeCsvFileName];assert(written==original+row(pid+1));
 assert(WriteTradeRow(record(pid+1)));assert(csvWrites==1);
 assert(InitializeTradeCsvIndex(gTradeCsvFileName));assert(gTradeCsvWrittenPIDs.size()==2);
 assert(csvFiles[gTradeCsvFileName]==written);assert_money_unchanged();
 std::cout<<"WDO actual producer/index/append: quoted multiline52columns, exact64bitPID, one append, repeat no duplicate\n";
}
void corrupt_prefix(){
 string original=header()+row(9001,false)+"RC1,partial";open_source(original);
 assert(!InitializeTradeCsvIndex(gTradeCsvFileName));
 assert(gBookCsvLastDiagnostic.find("UNTERMINATED_RECORD")!=std::string::npos);
 assert(gTradeCsvWrittenPIDs.empty()&&csvMarkers.empty()&&gDeferredAccountingPIDs.empty());
 assert(csvMarkerCalls==0&&csvDeferredCalls==0&&csvWrites==0&&csvCreates==0);
 assert(csvTradeHandle==INVALID_HANDLE&&!gTradeCsvIndexLoaded&&!gTradeCsvAppendSafe);
 assert(csvFiles[gTradeCsvFileName]==original);RecomputeAccountingBlock();assert(gAccountingUnresolved);
 assert(!WriteTradeRow(record(9002))&&csvWrites==0);assert_money_unchanged();
 std::cout<<"Rejected truncated ledger publishes no partial PID index/accounting work; source byte-identical and execution blocker retained\n";
}
void duplicate_prefix(){
 string original=header()+row(9001,false)+row(9001,false);open_source(original);
 assert(!InitializeTradeCsvIndex(gTradeCsvFileName));
 assert(gBookCsvLastDiagnostic.find("DUPLICATE_POSITION_ID_9001")!=std::string::npos);
 assert(gTradeCsvWrittenPIDs.empty()&&csvMarkers.empty()&&gDeferredAccountingPIDs.empty());
 assert(csvMarkerCalls==0&&csvDeferredCalls==0&&csvFiles[gTradeCsvFileName]==original);
 assert_money_unchanged();std::cout<<"Duplicate complete rows rejected before any economic marker or deferred PID mutation\n";
}
void incomplete(){
 string good=row(9001);auto final=good.rfind(',');assert(final!=std::string::npos);
 string original=header()+string(good.substr(0,final))+"\r\n";open_source(original);
 assert(!InitializeTradeCsvIndex(gTradeCsvFileName));
 assert(gBookCsvLastDiagnostic.find("ROW_COLUMN_COUNT")!=std::string::npos);
 assert(csvFiles[gTradeCsvFileName]==original&&csvMarkers.empty()&&csvWrites==0);
 original=header()+"\"unterminated,quoted\r\n";csvFiles[gTradeCsvFileName]=original;
 assert(!InitializeTradeCsvIndex(gTradeCsvFileName));
 assert(gBookCsvLastDiagnostic.find("UNTERMINATED_QUOTED_TAIL")!=std::string::npos);
 assert(csvFiles[gTradeCsvFileName]==original&&csvMarkers.empty());
 std::cout<<"Missing columns and unterminated quoted tails identified distinctly; no invented repair\n";
}
void recovery(){
 string original=header()+row(9001,false)+"RC1,partial";open_source(original);
 RecoverTradeCsvInfrastructure();assert(csvTradeHandle==INVALID_HANDLE);
 assert(gTradeCsvInfrastructureUnresolved&&csvFiles[gTradeCsvFileName]==original);
 // Explicit fixture action simulates authoritative external restoration. The
 // production recovery routine never writes, truncates or guesses these bytes.
 string restored=header()+row(9001,false);csvFiles[gTradeCsvFileName]=restored;csvNow+=31;
 RecoverTradeCsvInfrastructure();assert(gTradeCsvIndexLoaded&&gTradeCsvAppendSafe);
 assert(gTradeCsvWrittenPIDs.size()==1&&csvMarkers.size()==1&&gDeferredAccountingPIDs.size()==1);
 RecoverTradeCsvInfrastructure();assert(gTradeCsvWrittenPIDs.size()==1&&gDeferredAccountingPIDs.size()==1);
 assert(InitializeTradeCsvIndex(gTradeCsvFileName));assert(csvMarkers.size()==1&&gDeferredAccountingPIDs.size()==1);
 assert(WriteTradeRow(record(9001))&&csvWrites==0);
 RecomputeAccountingBlock();assert(gAccountingUnresolved); // economic recovery still outstanding
 assert(csvFiles[gTradeCsvFileName]==restored&&csvCreates==0);assert_money_unchanged();
 std::cout<<"Recovery verifies entire externally restored ledger, deduplicates retry, retains unresolved accounting and source bytes\n";
}
void exclusive(){
 string original=header()+row(9001);open_source(original);
 int first=csvTradeHandle;assert(!(csvHandles[first].flags&FILE_SHARE_WRITE));
 ResetLastError();int second=FileOpen(gTradeCsvFileName,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
 assert(second==INVALID_HANDLE&&GetLastError()!=0);
 assert(InitializeTradeCsvIndex(gTradeCsvFileName)); // independent read scan remains allowed
 assert(csvFiles[gTradeCsvFileName]==original&&csvWrites==0);
 std::cout<<"Exclusive writer contract rejects second writer; read validation remains compatible (host locking adapter)\n";
}
void failures(){
 string original=header()+row(9001,false);open_source(original);csvPartialRead=true;
 assert(!InitializeTradeCsvIndex(gTradeCsvFileName));csvPartialRead=false;
 assert(csvMarkers.empty()&&gTradeCsvWrittenPIDs.empty()&&csvFiles[gTradeCsvFileName]==original);
 csvTradeHandle=BookCsvOpenInitialFile();csvPublicationFailure=true;
 assert(!InitializeTradeCsvIndex(gTradeCsvFileName));csvPublicationFailure=false;
 assert(gBookCsvLastDiagnostic.find("PID_INDEX_PUBLICATION_FAILED")!=std::string::npos);
 assert(csvMarkers.empty()&&gDeferredAccountingPIDs.empty()&&gTradeCsvWrittenPIDs.empty());
 csvTradeHandle=BookCsvOpenInitialFile();csvMarkerFailure=true;
 assert(InitializeTradeCsvIndex(gTradeCsvFileName));
 RecomputeAccountingBlock();assert(gAccountingUnresolved&&gEconomicMarkerScanUnresolved);
 assert(csvFiles[gTradeCsvFileName]==original&&csvWrites==0);assert_money_unchanged();
 std::cout<<"Read/publication failures cannot commit partial recovery; marker persistence failure retains accounting block\n";
}
void partial_append(){
 string original=header()+row(9001);open_source(original);assert(InitializeTradeCsvIndex(gTradeCsvFileName));
 csvPartialWrite=true;assert(!WriteTradeRow(record(9002)));csvPartialWrite=false;
 string partial=csvFiles[gTradeCsvFileName];assert(partial.substr(0,original.size())==original);
 assert(!gTradeCsvIndexLoaded&&!gTradeCsvAppendSafe&&csvTradeHandle==INVALID_HANDLE);
 csvNow+=31;RecoverTradeCsvInfrastructure();assert(!gTradeCsvIndexLoaded);
 assert(csvFiles[gTradeCsvFileName]==partial&&csvWrites==1);
 assert(!WriteTradeRow(record(9002))&&csvWrites==1);RecomputeAccountingBlock();assert(gAccountingUnresolved);
 assert_money_unchanged();std::cout<<"Interrupted append retained unmodified and append-disabled; recovery cannot duplicate or erase partial row\n";
}
void uncertain_append(){
 string original=header()+row(9001);open_source(original);assert(InitializeTradeCsvIndex(gTradeCsvFileName));
 csvFlushFailure=true;assert(!WriteTradeRow(record(9002)));csvFlushFailure=false;
 string complete=csvFiles[gTradeCsvFileName];assert(complete==original+row(9002));
 assert(!gTradeCsvIndexLoaded&&csvTradeHandle==INVALID_HANDLE);csvNow+=31;
 RecoverTradeCsvInfrastructure();assert(gTradeCsvIndexLoaded&&gTradeCsvWrittenPIDs.size()==2);
 assert(WriteTradeRow(record(9002))&&csvWrites==1);
 assert(csvFiles[gTradeCsvFileName]==complete);assert_money_unchanged();
 std::cout<<"Uncertain flush with complete row recovered by full readback; no repeated append or financial fabrication\n";
}
int main(int argc,char **argv){assert(argc==2);string name=argv[1];
 if(name=="valid")valid();else if(name=="corrupt_prefix")corrupt_prefix();
 else if(name=="duplicate_prefix")duplicate_prefix();else if(name=="incomplete")incomplete();
 else if(name=="recovery")recovery();else if(name=="exclusive")exclusive();
 else if(name=="failures")failures();else if(name=="partial_append")partial_append();else if(name=="uncertain_append")uncertain_append();else return 2;
}
'''
    return support + globals_ + bodies + '\n' + cases


class CorrectiveCsvIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory(prefix='book-corrective-csv-')
        source = Path(cls.directory.name) / 'csv.cpp'
        cls.binary = source.with_suffix('')
        source.write_text(fixture())
        result = subprocess.run(['g++', '-std=c++17', '-O2', '-Wall', '-Wextra', '-Werror', '-Wno-error=misleading-indentation',
                                 '-I', str(ROOT / 'tests'), str(source), '-o', str(cls.binary)],
                                capture_output=True, text=True)
        if result.returncode:
            raise AssertionError(result.stderr)

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

    def run_case(self, name):
        result = subprocess.run([str(self.binary), name], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        print('CORRECTIVE_CSV ' + result.stdout.strip())

    def test_valid_actual_wdo_producer_and_idempotent_append(self):
        self.run_case('valid')

    def test_corrupt_tail_has_no_prefix_recovery_side_effects(self):
        self.run_case('corrupt_prefix')

    def test_duplicate_rows_have_no_prefix_recovery_side_effects(self):
        self.run_case('duplicate_prefix')

    def test_incomplete_rows_identified_without_repair(self):
        self.run_case('incomplete')

    def test_full_readonly_recovery_and_accounting_obligation_retained(self):
        self.run_case('recovery')

    def test_exclusive_writer_and_shared_reader_contract(self):
        self.run_case('exclusive')

    def test_read_allocation_and_marker_failures_preserve_history(self):
        self.run_case('failures')

    def test_interrupted_append_cannot_be_erased_or_duplicated(self):
        self.run_case('partial_append')

    def test_uncertain_complete_write_recovers_without_duplicate_append(self):
        self.run_case('uncertain_append')


if __name__ == '__main__':
    unittest.main(verbosity=2)
