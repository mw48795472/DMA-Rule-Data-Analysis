from pathlib import Path
import json
import pandas as pd
R=Path(__file__).resolve().parents[1]
O=R/'outputs/mechanisms_20261102/flows'
for o in [O,O/'fresh']:
 if not (o/'summary.json').exists():continue
 s=json.loads((o/'summary.json').read_text(encoding='utf-8'))
 print(o.name,s.get('status'),s.get('source_snapshot'),flush=True)
 if s.get('status')!='complete':continue
 print('country-year',s['joined_country_year_rows'],s['joined_country_year_columns'],'fresh probe',s['fresh_validation'],flush=True)
 for x in s['sources']:
  print(x['source_id'], 'raw',x['source_rows'],'od',x['od_rows'],'obs',x['od_observed'],'missing',x['od_missing'],'zeros',x['od_observed_zeros'],'negative',x['od_negative_values'],'years',x['years'],flush=True)
 print(pd.read_csv(o/'join_coverage_audit.csv').to_string(index=False),flush=True)
 print(pd.read_csv(o/'mirror_summary.csv').to_string(index=False),flush=True)
 print('MANIFEST',pd.read_csv(o/'SOURCE_MANIFEST.csv')[['source_id','source_url']].to_string(index=False),flush=True)
 if (o/'plot_error.json').exists():print((o/'plot_error.json').read_text(encoding='utf8'),flush=True)
 print('PLOTS',s['plots'],flush=True)
