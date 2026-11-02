from pathlib import Path
import pandas as pd
r=Path(__file__).resolve().parents[1]
for n in ['migration_inward','migration_outward','fdi_inward_j','fdi_outward_j','foreign_affiliates_j']:
 d=pd.read_csv(r/'inputs/base/csv'/(n+'.csv'))
 print(n,d.shape,d.columns.tolist(),flush=True)
 print({c:d[c].dropna().unique().tolist()[:90] for c in d.columns if c not in ['value','status']},flush=True)
d=pd.read_csv(r/'outputs/combined_country_year.csv')
print('COMBINED',d.shape,d.columns.tolist(),flush=True)
print(d.head(2).to_string(),flush=True)
print(list((r/'inputs/base').glob('*')),flush=True)
