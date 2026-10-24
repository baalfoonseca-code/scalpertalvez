#!/usr/bin/env python3
"""Export the exact new research CSV headers; does not touch financial files."""
from pathlib import Path
import argparse
import json
import re
ROOT=Path(__file__).resolve().parents[1]

def schema():
    source=(ROOT/'Include/BookResearchRuntime.mqh').read_text()
    head=re.search(r'string head=("[^"]+");',source)
    base=json.loads(head[1])
    kinds=('Candidates','Decisions','Outcomes','Health','DailySummary')
    result={}
    for index,kind in enumerate(kinds):
        pattern=r'if\(file=='+str(index)+r'\) return head\+("[^"]+");' if index<4 else r'   return head\+("[^"]+");'
        tail=re.search(pattern,source)
        if not tail:raise ValueError('missing exact schema '+kind)
        fields=(base+json.loads(tail[1])).split(',')
        if len(set(fields))!=len(fields):raise ValueError('duplicate schema field '+kind)
        result[kind]=fields
    return {'schema':'REMORA_RESEARCH_V1','encoding':'UTF-8','separator':',','quote':'"','line_ending':'CRLF',
            'unavailable':'empty cell; not mathematical zero','event_identity':['run_id','event_id'],
            'candidate_identity':['run_id','candidate_id'],'files':result}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path)
    args=parser.parse_args();result=json.dumps(schema(),ensure_ascii=False,indent=2)+'\n'
    if args.output:args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(result)
    else:print(result,end='')
if __name__=='__main__':main()
