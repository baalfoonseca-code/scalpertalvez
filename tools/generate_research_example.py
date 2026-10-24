#!/usr/bin/env python3
"""Produce a labelled deterministic example from integrated delivered source.

Requires g++ and the repository tests. This is not MT5 replay or broker history.
"""
from pathlib import Path
import argparse
import json
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
sys.path.insert(0,str(ROOT/'tools'))
from test_research_integration import research_acceptance_program
from test_research_runtime import run_program
from analyze_research import analyze, markdown

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=ROOT/'examples/research')
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    trace,files=run_program(research_acceptance_program())
    for name,contents in files.items():
        if name.endswith('.csv'):(args.output/name).write_text(contents,encoding='utf-8',newline='')
    (args.output/'fixture-trace.txt').write_text('DETERMINISTIC HOST FIXTURE — NOT MARKET DATA, NOT A REAL TRADE\n'+trace)
    report=analyze([args.output]);report['example_only']=True;report['not_a_loaded_live_chart_preset']=True
    (args.output/'daily-example.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    (args.output/'daily-example.md').write_text('**EXEMPLO DETERMINÍSTICO — nenhuma operação real ou lucro demonstrado.**\n\n'+markdown(report))
    print(trace.strip());print(args.output)
if __name__=='__main__':main()
