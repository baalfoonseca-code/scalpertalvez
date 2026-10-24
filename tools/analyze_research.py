#!/usr/bin/env python3
"""Combine versioned Rêmora research CSVs without changing any source file.

Only the Python standard library is used. Counterfactual barrier observations
are never converted into real trades or an executable portfolio return.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
import hashlib
import json
import math
from pathlib import Path
import re
import sys

SUPPORTED_SCHEMAS = {"REMORA_RESEARCH_V1"}
KINDS = ("candidates", "decisions", "outcomes", "health", "dailysummary")
DECISIONS = {"VALIDAR", "AGUARDAR", "VETAR_CANDIDATO", "INVALIDAR_ARMED", "DADOS_INSUFICIENTES", "NOT_EVALUATED"}
DECISION_NUMBERS = {"0": "VALIDAR", "1": "AGUARDAR", "2": "VETAR_CANDIDATO", "3": "INVALIDAR_ARMED", "4": "DADOS_INSUFICIENTES"}
DIMENSIONS = ("account", "symbol", "route", "mode", "direction", "bucket", "quality", "actual_mode", "trading_preset_hash")


def value(row, *keys, default=""):
    """Headers are case insensitive; a missing value remains missing."""
    for key in keys:
        if row.get(key.lower(), "") != "":
            return row[key.lower()]
    return default


def finite(raw):
    try:
        result = float(raw)
        return result if math.isfinite(result) else None
    except (TypeError, ValueError, OverflowError):
        return None


def truth(raw):
    return str(raw).strip().upper() in {"1", "TRUE", "YES"}


def timestamp(row):
    return finite(value(row, "market_msc", "observed_msc", "time_msc", "end_msc", "at_msc", "timestamp_msc")) or 0


def key(row):
    return (value(row, "run_id"), value(row, "candidate_id"))


def discover(paths):
    files = set()
    for raw in paths:
        path = Path(raw)
        if path.is_dir():
            files.update(p for p in path.rglob("*.csv") if "research" in p.name.lower())
        elif path.is_file():
            files.add(path)
        else:
            raise ValueError(f"Input does not exist: {path}")
    return sorted(files)


def file_kind(path):
    normalized = re.sub(r"[^a-z]", "", path.stem.lower())
    for kind in KINDS:
        if kind in normalized:
            return kind
    return None


def read_events(paths):
    """Deduplicate identical events; conflicting IDs are excluded completely."""
    unique, conflicted = {}, set()
    stats = {"files": [], "rows_read": 0, "identical_duplicates": 0, "rejected": [], "conflicting_event_ids": []}
    for path in discover(paths):
        kind = file_kind(path)
        if kind is None:
            continue
        stats["files"].append(str(path))
        try:
            with path.open("r", encoding="utf-8-sig", newline="") as handle:
                reader = csv.DictReader(handle, strict=True)
                if not reader.fieldnames or len(set(n.lower() for n in reader.fieldnames)) != len(reader.fieldnames):
                    raise ValueError("missing or duplicate CSV headers")
                for number, original in enumerate(reader, 2):
                    stats["rows_read"] += 1
                    if None in original or any(v is None for v in original.values()):
                        stats["rejected"].append({"file": str(path), "line": number, "reason": "ROW_COLUMN_COUNT"})
                        continue
                    row = {k.lower(): v for k, v in original.items()}
                    schema = value(row, "schema", "schema_version")
                    event_id, run_id = value(row, "event_id"), value(row, "run_id")
                    reason = ""
                    if schema not in SUPPORTED_SCHEMAS:
                        reason = "UNSUPPORTED_SCHEMA"
                    elif not event_id or not run_id:
                        reason = "MISSING_STABLE_EVENT_OR_RUN_ID"
                    if reason:
                        stats["rejected"].append({"file": str(path), "line": number, "reason": reason})
                        continue
                    identity = (run_id, event_id)
                    row["_kind"] = kind
                    if identity in conflicted:
                        continue
                    if identity in unique:
                        if row == unique[identity]:
                            stats["identical_duplicates"] += 1
                        else:
                            conflicted.add(identity)
                            unique.pop(identity)
                            stats["conflicting_event_ids"].append({"run_id": run_id, "event_id": event_id})
                    else:
                        unique[identity] = row
        except (OSError, UnicodeError, csv.Error, ValueError) as exc:
            stats["rejected"].append({"file": str(path), "reason": "READ_OR_CSV_ERROR", "detail": str(exc)})
    stats["unique_events"] = len(unique)
    return list(unique.values()), stats


def candidate_eligible(row):
    raw = value(row, "original_candidate_eligible", "candidate_eligible", "matrix_eligible", "eligible", "eligibility")
    if raw:
        return truth(raw) or raw.upper() in {"VALID_CANDIDATE", "ORIGINAL_ELIGIBLE", "MATRIX_ELIGIBLE", "ELIGIBLE"}
    return value(row, "candidate_class", "classification", "status").upper() in {"VALID_CANDIDATE", "ORIGINAL_ELIGIBLE", "MATRIX_ELIGIBLE", "CANDIDATE"}


def decision_name(row):
    name = value(row, "result", "decision", "verdict", "apply_result").upper()
    return DECISION_NUMBERS.get(name, name) if name else "NOT_EVALUATED"


def outcome_name(row):
    return value(row, "outcome", "status", "result", "event").upper()


def is_real(row):
    return value(row, "scope", "kind", "outcome_kind", "track", "event_type").upper() in {"REAL", "REAL_TRADE", "ACTUAL", "RECONCILED_REAL"} or outcome_name(row).startswith("REAL_")


def dimension(row, candidate):
    aliases = {"mode": ("mode", "base_turbo"), "quality": ("quality", "data_quality", "integrity"), "bucket": ("bucket", "bucket_30m"), "trading_preset_hash": ("trading_preset_hash", "preset_hash")}
    return tuple(value(candidate, *aliases.get(name, (name,)), default=value(row, *aliases.get(name, (name,)), default="UNAVAILABLE")) for name in DIMENSIONS)


def fresh_summary():
    return {"matrix_candidates": 0, "matrix_ineligible_snapshots": 0, "assessed_candidates": 0,
            "approved_candidates": 0, "waited_candidates": 0, "vetoed_candidates": 0,
            "invalidated_candidates": 0, "insufficient_data_candidates": 0,
            "not_evaluated_candidates": 0, "decision_state_events": {}, "decision_reasons": {}, "final_decision_states": {},
            "timeout_candidates": 0, "overshoot_candidates": 0, "ineligible_for_operational_state": 0,
            "original_market_entry_eligible": 0, "original_dispatch_eligible_observed": 0, "conditional_reference_entries": 0, "original_entry_not_reconstructable": 0,
            "hypothetical_entries": 0, "hypothetical_tp_first": 0, "hypothetical_sl_first": 0,
            "hypothetical_horizon_unresolved": 0, "hypothetical_ambiguous": 0,
            "hypothetical_insufficient_market_data": 0, "hypothetical_interrupted": 0,
            "collision_candidates": 0, "rejected_tp_barrier_opportunities": 0,
            "rejected_sl_barrier_opportunities": 0, "actual_original_dispatch_attempts": 0, "actual_confirmed_closed_trades": 0,
            "actual_confirmed_net_pnl": None, "actual_confirmed_expectancy": None,
            "hypothetical_reference_net_points": None, "hypothetical_reference_expectancy_points": None,
            "hypothetical_cost_qualified_samples": 0, "actual_exposure_seconds": 0.0,
            "hypothetical_exposure_seconds": 0.0}


def summarize(events, cost_points=None):
    if cost_points is not None and (not math.isfinite(cost_points) or cost_points < 0):
        raise ValueError("hypothetical cost points must be finite and non-negative")
    candidates, candidate_conflicts, seen_real = {}, set(), set()
    decisions, outcomes, health = defaultdict(list), defaultdict(list), []
    for row in events:
        kind = row["_kind"]
        if kind == "candidates":
            # Candidate snapshots are immutable. Multiple different candidate
            # events for the same identity are surfaced rather than double counted.
            identity = key(row)
            if identity not in candidate_conflicts:
                if identity in candidates:
                    semantic = lambda r: {k: v for k, v in r.items() if k not in {"event_id", "observed_msc"}}
                    if semantic(row) != semantic(candidates[identity]):
                        candidate_conflicts.add(identity)
                        candidates.pop(identity)
                else:
                    candidates[identity] = row
        elif kind == "decisions":
            decisions[key(row)].append(row)
        elif kind == "outcomes":
            outcomes[key(row)].append(row)
        elif kind == "health":
            health.append(row)
    all_keys = set(candidates) | set(decisions) | set(outcomes)
    aggregate = fresh_summary()
    groups = defaultdict(fresh_summary)
    reason_counters, final_counters = defaultdict(Counter), defaultdict(Counter)
    audits = []
    state_counters = defaultdict(Counter)
    net_totals, net_counts, hypo_totals = defaultdict(float), Counter(), defaultdict(float)
    orphan_keys = []
    for candidate_key in sorted(all_keys):
        candidate = candidates.get(candidate_key, {})
        evidence_rows = sorted(decisions[candidate_key], key=timestamp)
        authorization_rows=[row for row in evidence_rows if 'AT_PRICING_QUOTE_NOT_DISPATCH' not in value(row,'evaluation_scope')]

        assessments = {}
        for d in authorization_rows:
            assessment_key = value(d, "assessment_id") or (timestamp(d), decision_name(d), value(d, "reason"))
            assessments[assessment_key] = d
        ds = list(assessments.values())
        os = sorted(outcomes[candidate_key], key=timestamp)
        dims = dimension((ds or os or [{}])[-1], candidate)
        if not candidate:
            orphan_keys.append({"run_id": candidate_key[0], "candidate_id": candidate_key[1]})
        names = [decision_name(d) for d in ds]
        rejected = any(n in {"VETAR_CANDIDATO", "INVALIDAR_ARMED", "DADOS_INSUFICIENTES", "AGUARDAR"} for n in names) and not any(is_real(o) and (outcome_name(o)=="REAL_RECONCILED" or (value(o,"position_id")!="" and value(o,"deal_id")!="0" and finite(value(o,"actual_price")) is not None)) for o in os)
        collision = any(truth(value(r, "collision", "capital_collision", "operational_collision")) for r in [candidate, *os])
        audits.append({"run_id": candidate_key[0], "candidate_id": candidate_key[1],
                       "matrix_eligible": candidate_eligible(candidate) if candidate else None,
                       "decision_states": names, "decision_reasons": [value(d, "reason") for d in ds],
                       "evidence_event_ids": [value(d, "event_id") for d in evidence_rows],
                       "outcomes": [{k: v for k, v in o.items() if k != "_kind"} for o in os]})
        for target_key, target in (("ALL", aggregate), (dims, groups[dims])):
            if candidate:
                target["matrix_candidates" if candidate_eligible(candidate) else "matrix_ineligible_snapshots"] += 1
            for name, field in (("VALIDAR", "approved_candidates"), ("AGUARDAR", "waited_candidates"), ("VETAR_CANDIDATO", "vetoed_candidates"), ("INVALIDAR_ARMED", "invalidated_candidates"), ("DADOS_INSUFICIENTES", "insufficient_data_candidates"), ("NOT_EVALUATED", "not_evaluated_candidates")):
                target[field] += name in names
            target["assessed_candidates"] += any(name in DECISIONS - {"NOT_EVALUATED"} for name in names)
            state_counters[target_key].update(names)
            final_counters[target_key].update(names[-1:] or ["NOT_EVALUATED"])
            reason_counters[target_key].update(value(d, "reason", default="UNAVAILABLE") for d in ds)
            target["collision_candidates"] += collision
            labels = {outcome_name(o) for o in os if not is_real(o)}
            entry_rows = [o for o in os if not is_real(o) and (truth(value(o, "original_market_entry_eligible", "stage2_eligible", "market_eligible")) or outcome_name(o) in {"HYPOTHETICAL_ENTRY_ELIGIBLE", "ORIGINAL_ENTRY_ELIGIBLE", "HYPOTHETICAL_ENTRY", "ENTRY_OBSERVED", "TP_FIRST", "SL_FIRST", "TP_OBSERVED_FIRST", "SL_OBSERVED_FIRST"})]
            actual_dispatches=[o for o in os if outcome_name(o)=="REAL_ENTRY_API_RESULT"]
            target["actual_original_dispatch_attempts"] += len(actual_dispatches)
            target["original_market_entry_eligible"] += bool(entry_rows) or bool(actual_dispatches)
            target["original_dispatch_eligible_observed"] += any(truth(value(o,"dispatch_eligible_observed")) for o in os if not is_real(o))
            target["conditional_reference_entries"] += any(value(o,"reference_kind")=="CONDITIONAL_MARKET_REFERENCE" for o in os)
            target["original_entry_not_reconstructable"] += "ORIGINAL_ENTRY_NOT_RECONSTRUCTABLE" in labels or any(value(o,"reference_kind")=="CONDITIONAL_MARKET_REFERENCE" for o in os)
            target["timeout_candidates"] += any("TIMEOUT" in name for name in labels)
            target["overshoot_candidates"] += any("OVERSHOOT" in name for name in labels)
            target["ineligible_for_operational_state"] += candidate_eligible(candidate) and value(candidate, "operational_possible") != "" and not truth(value(candidate, "operational_possible"))
            has_entry = any(finite(value(o, "entry_price", "hypothetical_entry_price")) is not None for o in os if not is_real(o))
            target["hypothetical_entries"] += has_entry
            touches = {value(o, "first_touch").upper() for o in os if not is_real(o)}
            tp = bool(labels & {"TP_FIRST", "TP_OBSERVED_FIRST", "TP_TOUCHED_FIRST"}) or "TP" in touches
            sl = bool(labels & {"SL_FIRST", "SL_OBSERVED_FIRST", "SL_TOUCHED_FIRST"}) or "SL" in touches
            ambiguous = "AMBIGUOUS_PATH" in labels or (tp and sl)
            target["hypothetical_ambiguous"] += ambiguous
            target["hypothetical_tp_first"] += tp and not ambiguous
            target["hypothetical_sl_first"] += sl and not ambiguous
            target["hypothetical_horizon_unresolved"] += bool(labels & {"HORIZON", "HORIZON_EXPIRED", "HORIZON_NO_BARRIER", "NO_BARRIER", "EOD_INCOMPLETE"})
            target["hypothetical_insufficient_market_data"] += "INSUFFICIENT_MARKET_DATA" in labels
            target["hypothetical_interrupted"] += bool(labels & {"INTERRUPTED", "RESTART_INTERRUPTED", "INTERRUPTED_RESTART", "DEINIT_INCOMPLETE"})
            target["rejected_tp_barrier_opportunities"] += rejected and tp and not ambiguous
            target["rejected_sl_barrier_opportunities"] += rejected and sl and not ambiguous
            # Close rows are deduplicated again by exact position identity: an
            # EA restart may reconcile the same historical trade in another run.
            real_rows = [o for o in os if is_real(o) and truth(value(o, "pnl_confirmed", "accounting_resolved", "reconciled")) and finite(value(o, "net_pnl", "net_profit", "pnl_net", "net")) is not None]
            if real_rows:
                last = real_rows[-1]
                pid = value(last, "position_id")
                position_key = (target_key, value(last, "account", default=value(candidate, "account")), value(last, "server", default=value(candidate, "server")), value(last, "symbol", default=value(candidate, "symbol")), pid)
                if pid and position_key not in seen_real:
                    seen_real.add(position_key)
                    target["actual_confirmed_closed_trades"] += 1
                    net_totals[target_key] += finite(value(last, "net_pnl", "net_profit", "pnl_net", "net"))
                    net_counts[target_key] += 1
                    duration = finite(value(last, "duration_seconds", "duration_sec"))
                    if duration is not None and duration >= 0:
                        target["actual_exposure_seconds"] += duration
            hypothetical_rows = [o for o in os if not is_real(o)]
            if hypothetical_rows:
                last = hypothetical_rows[-1]
                duration = finite(value(last, "duration_seconds", "duration_sec", "exposure_seconds"))
                if duration is not None and duration >= 0:
                    target["hypothetical_exposure_seconds"] += duration
                if cost_points is not None and not collision and not ambiguous and (tp ^ sl) and not any(value(o,"reference_kind")=="CONDITIONAL_MARKET_REFERENCE" for o in hypothetical_rows):
                    matched = next((o for o in reversed(hypothetical_rows) if outcome_name(o) in ({"TP_FIRST", "TP_OBSERVED_FIRST", "TP_TOUCHED_FIRST"} if tp else {"SL_FIRST", "SL_OBSERVED_FIRST", "SL_TOUCHED_FIRST"})), {})
                    distance = finite(value(matched, "tp_distance_points" if tp else "sl_distance_points", "tp_distance" if tp else "sl_distance", default=value(candidate, "tp_distance" if tp else "sl_distance")))
                    if distance is not None and distance > 0:
                        hypo_totals[target_key] += (distance if tp else -distance) - cost_points
                        target["hypothetical_cost_qualified_samples"] += 1
    for group_key, target in [("ALL", aggregate), *groups.items()]:
        target["decision_state_events"] = dict(sorted(state_counters[group_key].items()))
        target["final_decision_states"] = dict(sorted(final_counters[group_key].items()))
        target["decision_reasons"] = dict(sorted(reason_counters[group_key].items()))
        count = net_counts[group_key]
        if count:
            target["actual_confirmed_net_pnl"] = net_totals[group_key]
            target["actual_confirmed_expectancy"] = net_totals[group_key] / count
        hypo_count = target["hypothetical_cost_qualified_samples"]
        if hypo_count:
            target["hypothetical_reference_net_points"] = hypo_totals[group_key]
            target["hypothetical_reference_expectancy_points"] = hypo_totals[group_key] / hypo_count
    symbols = {value(c, "symbol") for c in candidates.values() if value(c, "symbol")}
    accounts = {value(c, "account") for c in candidates.values() if value(c, "account")}
    if len(symbols) > 1:
        aggregate["hypothetical_reference_net_points"] = None
        aggregate["hypothetical_reference_expectancy_points"] = None
    if len(accounts) > 1:
        aggregate["actual_confirmed_net_pnl"] = None
        aggregate["actual_confirmed_expectancy"] = None
    return {"aggregate": aggregate,
            "candidate_audit": audits,
            "mixed_symbol_points_not_aggregated": len(symbols) > 1,
            "mixed_account_pnl_not_aggregated": len(accounts) > 1,
            "groups": [{**dict(zip(DIMENSIONS, dims)), **summary} for dims, summary in sorted(groups.items())],
            "health": {"events": len(health), "reasons": dict(Counter(value(r, "reason", "status", default="UNAVAILABLE") for r in health))},
            "orphan_candidate_identities": orphan_keys,
            "conflicting_candidate_identities": [{"run_id": k[0], "candidate_id": k[1]} for k in sorted(candidate_conflicts)],
            "hypothetical_round_trip_cost_points": cost_points,
            "warnings": [
                "Research events and deterministic examples do not prove native MT5 behavior or trading advantage.",
                "Approval/wait/veto counts are overlapping candidate sets, not additive partitions.",
                "ORIGINAL market eligibility is separate from finance, book confirmation and actual execution.",
                "TP/SL are observed reference-price barriers, never confirmed fills or real PnL.",
                "Rejected TP/SL counts are potential sacrificed/avoided barrier observations, not money earned/saved.",
                "No price-point expectancy is aggregated across different symbols; no monetary PnL is aggregated across different accounts.",
                "Hypothetical reference expectancy uses declared cost points only; excludes known collisions, does not model a tradable portfolio, sizing, latency or slippage.",
                "Missing outcomes, research gaps, unmatched candidates and unqualified feeds limit denominators and statistical inference.",
                "No automatic input optimization or claim of statistical significance is produced."]}


def canonical_input_fields(payload):
    """Read native UTF-16-code-unit length prefixes, including embedded newlines."""
    encoded=payload.encode('utf-16-le');position=0
    def field():
        nonlocal position
        digits=[]
        while position+2<=len(encoded):
            ch=encoded[position:position+2].decode('utf-16-le');position+=2
            if ch==':':break
            if not ch.isascii() or not ch.isdigit():raise ValueError('invalid canonical length')
            digits.append(ch)
        else:raise ValueError('unterminated canonical length')
        if not digits:raise ValueError('empty canonical length')
        count=int(''.join(digits));end=position+count*2
        if end>len(encoded) or count>65536:raise ValueError('canonical field length')
        result=encoded[position:end].decode('utf-16-le');position=end;return result
    rows=[];names=set()
    while position<len(encoded):
        kind,name,loaded=field(),field(),field()
        if encoded[position:position+2]!=b'\n\x00':raise ValueError('canonical record separator')
        position+=2
        if name in names:raise ValueError('duplicate canonical input')
        names.add(name);rows.append((kind,name,loaded))
    return rows


def comparison_groups(events):
    """Mode is the comparison axis; every other loaded trading input must match.

    Equal settings do not imply the same market exposure, execution, or a causal
    experiment. No candidate or result is manufactured when config is missing.
    """
    configs={};unavailable=[]
    for row in events:
        if row['_kind']!='health' or value(row,'reason')!='OBSERVATION_ONLY':continue
        try:
            fields=canonical_input_fields(value(row,'details'))
            values={name:loaded for _,name,loaded in fields}
            if len(fields)!=104 or 'Inp_DecisionMode' not in values or 'Inp_ResearchEnable' not in values:
                raise ValueError('expected 103 trading inputs plus research bool')
            normalized=[field for field in fields if field[1] not in {'Inp_DecisionMode','Inp_ResearchEnable'}]
            digest=hashlib.sha256(json.dumps(normalized,ensure_ascii=False,separators=(',',':')).encode()).hexdigest()
            mode={'0':'ORIGINAL','1':'APLICAR'}.get(values['Inp_DecisionMode'],'UNKNOWN')
            configs[value(row,'run_id')]=(digest,mode)
        except (ValueError,UnicodeError) as error:
            unavailable.append({'run_id':value(row,'run_id'),'reason':str(error)})
    decisions=defaultdict(set);outcomes=defaultdict(list)
    for row in events:
        if row['_kind']=='decisions' and 'AT_PRICING_QUOTE_NOT_DISPATCH' not in value(row,'evaluation_scope'):decisions[key(row)].add(decision_name(row))
        if row['_kind']=='outcomes':outcomes[key(row)].append(row)
    groups={};seen=set()
    for row in events:
        if row['_kind']!='candidates' or not candidate_eligible(row) or key(row) in seen:continue
        seen.add(key(row));configuration=configs.get(value(row,'run_id'))
        if configuration is None:continue
        digest,mode=configuration
        identity=(digest,value(row,'account'),value(row,'server'),value(row,'symbol'),value(row,'route'),value(row,'mode'),value(row,'direction'))
        group=groups.setdefault(identity,{'comparison_input_sha256':digest,'account':identity[1],'server':identity[2],
            'symbol':identity[3],'route':identity[4],'mode':identity[5],'direction':identity[6],'modes':{}})
        counts=group['modes'].setdefault(mode,{'candidates':0,'validar':0,'aguardar':0,'veto':0,'invalidation':0,
            'data_insufficient':0,'original_dispatch_hypotheses':0,'conditional_references':0,'run_ids':[]})
        counts['candidates']+=1
        if value(row,'run_id') not in counts['run_ids']:counts['run_ids'].append(value(row,'run_id'))
        names=decisions[key(row)]
        for name,label in [('VALIDAR','validar'),('AGUARDAR','aguardar'),('VETAR_CANDIDATO','veto'),('INVALIDAR_ARMED','invalidation'),('DADOS_INSUFICIENTES','data_insufficient')]:counts[label]+=name in names
        os=outcomes[key(row)]
        counts['original_dispatch_hypotheses']+=any(truth(value(o,'dispatch_eligible_observed')) for o in os if not is_real(o))
        counts['conditional_references']+=any(value(o,'reference_kind')=='CONDITIONAL_MARKET_REFERENCE' for o in os)
    return {'groups':list(groups.values()),'configuration_unavailable':unavailable,
            'axis':'Inp_DecisionMode; only research enable and mode excluded from comparison fingerprint',
            'warning':'Matching loaded parameters do not establish matched market windows, fills, portfolio feasibility, or statistical superiority.'}


def analyze(paths, cost_points=None):
    events, ingestion = read_events(paths)
    report = summarize(events, cost_points)
    report["mode_comparison"] = comparison_groups(events)
    report["schema"] = "BOOK_RESEARCH_ANALYSIS_V1"
    report["ingestion"] = ingestion
    return report


def markdown(report):
    a = report["aggregate"]
    lines = ["# Rêmora Decision Research — análise offline", "", "Observações reais e contrafactuais são apresentadas separadamente.", "", "| Métrica | Quantidade |", "|---|---:|"]
    labels = {"matrix_candidates": "Candidaturas originalmente elegíveis", "matrix_ineligible_snapshots": "Snapshots de inelegibilidade", "assessed_candidates": "Candidaturas avaliadas por APLICAR", "approved_candidates": "Aprovação APLICAR observada", "vetoed_candidates": "Veto APLICAR observado", "waited_candidates": "Espera APLICAR observada", "insufficient_data_candidates": "Dados insuficientes", "original_market_entry_eligible": "Stage 2 ORIGINAL elegível demonstrado", "original_entry_not_reconstructable": "ORIGINAL não reconstruível", "hypothetical_entries": "Referências de entrada hipotética", "hypothetical_tp_first": "TP observado primeiro", "hypothetical_sl_first": "SL observado primeiro", "hypothetical_ambiguous": "Caminhos ambíguos", "hypothetical_horizon_unresolved": "Horizonte inconclusivo", "collision_candidates": "Candidaturas com colisão", "actual_confirmed_closed_trades": "Trades reais reconciliados"}
    lines.extend(f"| {label} | {a[field]} |" for field, label in labels.items())
    lines += ["", f"PnL real reconciliado: {a['actual_confirmed_net_pnl'] if a['actual_confirmed_net_pnl'] is not None else 'INDISPONÍVEL'}.",
              f"Expectativa real por trade: {a['actual_confirmed_expectancy'] if a['actual_confirmed_expectancy'] is not None else 'INDISPONÍVEL'}.",
              f"Custo hipotético declarado (pontos, ida e volta): {report['hypothetical_round_trip_cost_points'] if report['hypothetical_round_trip_cost_points'] is not None else 'NÃO INFORMADO'}.",
              f"Média líquida de barreiras de referência em pontos: {a['hypothetical_reference_expectancy_points'] if a['hypothetical_reference_expectancy_points'] is not None else 'NÃO CALCULADA'}; amostras {a['hypothetical_cost_qualified_samples']}.", "", "## Motivos APLICAR", ""]
    lines.extend(f"- `{reason}`: {count}" for reason, count in a["decision_reasons"].items())
    lines += ["", "## Cobertura da coleta", "", f"Arquivos: {len(report['ingestion']['files'])}; linhas lidas: {report['ingestion']['rows_read']}; eventos únicos: {report['ingestion']['unique_events']}; duplicatas idênticas: {report['ingestion']['identical_duplicates']}; conflitos de ID: {len(report['ingestion']['conflicting_event_ids'])}; rejeições de leitura: {len(report['ingestion']['rejected'])}; identidades sem candidatura: {len(report['orphan_candidate_identities'])}.", "", "## Limitações", ""]
    lines.extend(f"- {warning}" for warning in report["warnings"])
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", help="CSV files or directories (recursive research CSV discovery)")
    parser.add_argument("--json", dest="json_path", type=Path, help="JSON report destination")
    parser.add_argument("--markdown", type=Path, help="Markdown report destination")
    parser.add_argument("--hypothetical-cost-points", type=float, default=None, help="Explicit round-trip reference cost, in asset price points, never real PnL")
    args = parser.parse_args(argv)
    try:
        report = analyze(args.inputs, args.hypothetical_cost_points)
    except ValueError as exc:
        parser.error(str(exc))
    encoded = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
    if args.json_path:
        args.json_path.write_text(encoded, encoding="utf-8")
    else:
        sys.stdout.write(encoded)
    if args.markdown:
        args.markdown.write_text(markdown(report), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
