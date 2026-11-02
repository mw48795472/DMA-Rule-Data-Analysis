"""Download official 2024 immigration and 2024/25 populations, with full provenance."""
from pathlib import Path
import json,csv,itertools,urllib.request,urllib.parse,hashlib,datetime,concurrent.futures,re,subprocess,sys
import pandas as pd
ROOT=Path(__file__).resolve().parent;D=ROOT/'inputs'/'extension_20261102'
for s in ['raw','csv','metadata']:(D/s).mkdir(parents=True,exist_ok=True)
BASE='https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/'
JOBS=[
 ('migr_imm8_2024','json',BASE+'migr_imm8?'+urllib.parse.urlencode(dict(lang='en',time='2024',sex='T',unit='NR'))),
 ('demo_pjan_2024_2025','json',BASE+'demo_pjan?'+urllib.parse.urlencode(dict(lang='en',sinceTimePeriod='2024',untilTimePeriod='2025',sex='T',unit='NR'))),
 ('migr_imm1ctz_total_2024','json',BASE+'migr_imm1ctz?'+urllib.parse.urlencode(dict(lang='en',time='2024',sex='T',unit='NR',age='TOTAL',citizen='TOTAL'))),
 ('eurostat_migration_metadata','html','https://ec.europa.eu/eurostat/cache/metadata/en/migr_immi_esms.htm'),
 ('ons_ltim_2026may','html','https://www.ons.gov.uk/peoplepopulationandcommunity/populationandmigration/internationalmigration/bulletins/longterminternationalmigrationprovisional/yearendingdecember2025'),
 ('ons_population_2026oct','html','https://www.ons.gov.uk/peoplepopulationandcommunity/populationandmigration/populationestimates/bulletins/annualmidyearpopulationestimates/mid2025'),
 ('migr_imm5prv_world_2024','json',BASE+'migr_imm5prv?'+urllib.parse.urlencode(dict(lang='en',time='2024',sex='T',unit='NR',partner='TOTAL'))),
 ('CNTR_RG_20M_2024_4326','geojson','https://gisco-services.ec.europa.eu/distribution/v2/countries/geojson/CNTR_RG_20M_2024_4326.geojson'),
 ('ine_immigration_2024_S7A','inejson','https://www.ine.pt/ine/json_indicador/pindica.jsp?op=2&varcd=0006055&Dim1=S7A2024&Dim2=PT&Dim3=T&lang=EN'),
 ('ine_population_nuts2024','inejson','https://www.ine.pt/ine/json_indicador/pindica.jsp?op=2&varcd=0012905&Dim1=S7A2023,S7A2024&Dim2=PT&Dim3=T&lang=EN'),
 ('ine_immigration_metadata','html','https://www.ine.pt/bddXplorer/htdocs/minfo.jsp?var_cd=0006055&lingua=EN'),
 ('ine_population_nuts2024_metadata','html','https://www.ine.pt/bddXplorer/htdocs/minfo.jsp?var_cd=0012905&lingua=EN'),
]
def jsonstat(j):
 ids=j['id'];cats=[]
 for k in ids:
  ix=j['dimension'][k]['category']['index']
  cats.append([k for k,v in sorted(ix.items(),key=lambda x:x[1])] if isinstance(ix,dict) else ix)
 vals=j.get('value',{});flags=j.get('status',{})
 def item(obj,i):return obj.get(str(i)) if isinstance(obj,dict) else (obj[i] if i<len(obj) else None)
 rows=[]
 for i,t in enumerate(itertools.product(*cats)):
  rows.append(dict(zip(ids,t),value=item(vals,i),status=item(flags,i)))
 return pd.DataFrame(rows)
def download(job):
 name,ext,url=job;p=D/'raw'/(name+'.'+ext)
 if not p.exists():
  req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 (research data collection)'})
  try:
   with urllib.request.urlopen(req,timeout=90) as r:body=r.read()
   p.write_bytes(body)
  except urllib.error.URLError as e:
   if sys.platform!='win32' or 'CERTIFICATE_VERIFY_FAILED' not in str(e):raise
   # Windows certificate store fallback; certificate verification remains enabled.
   q=lambda x:"'"+str(x).replace("'","''")+"'"
   subprocess.run(['powershell.exe','-NoProfile','-Command','Invoke-WebRequest -UseBasicParsing -Uri '+q(url)+' -OutFile '+q(p)],check=True)
 body=p.read_bytes();record=dict(file=str(p.relative_to(ROOT)),url=url,sha256=hashlib.sha256(body).hexdigest(),bytes=len(body),api_key_required='no',retrieved_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
 if ext=='json':
  j=json.loads(body);assert 'id'in j,j
  df=jsonstat(j);df.to_csv(D/'csv'/(name+'.csv'),index=False,encoding='utf-8-sig')
  record.update(rows=len(df),observed=int(df.value.notna().sum()),source_updated=j.get('updated'))
  (D/'metadata'/(name+'_dimensions.json')).write_text(json.dumps({k:j[k] for k in ['id','size','dimension','updated'] if k in j},ensure_ascii=False,indent=2),encoding='utf-8')
 if ext=='inejson':
  j=json.loads(body);rows=[]
  for dataset in j:
   for period,values in dataset.get('Dados',{}).items():
    for val in values:rows.append(dict(time=period,**val))
  pd.DataFrame(rows).to_csv(D/'csv'/(name+'.csv'),index=False,encoding='utf-8-sig')
  if not rows:raise ValueError('No data returned by INE: '+str(j)[:400])
  record.update(rows=len(rows),source_updated=j[0].get('DataUltimoAtualizacao'))
 print(name,record.get('rows','document'),flush=True)
 return record
if __name__=='__main__':
 records=[]
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
  for r in pool.map(download,JOBS):records.append(r)
 pd.DataFrame(records).to_csv(D/'SOURCE_MANIFEST.csv',index=False,encoding='utf-8-sig')
 # Public rounded figures, transparently transcribed from the two archived ONS bulletins.
 a=(D/'raw/ons_ltim_2026may.html').read_text(encoding='utf-8')
 b=(D/'raw/ons_population_2026oct.html').read_text(encoding='utf-8')
 assert '1,012,000' in a and '69,256,300' in b
 uk=dict(country='UK',year=2024,immigration_all_ages=1012000,population_midyear=69256300,
  immigration_release='2026-05-21',population_release='2026-10-01',
  immigration_url=JOBS[4][2],population_url=JOBS[5][2],
  immigration_rounding='nearest 1000 as published in bulletin',population_rounding='nearest 100 as published in bulletin',
  extraction='manual transcription checked against archived official HTML',
  definition='long-term immigration, all citizenships, all ages, year ending December 2024; not net migration',
  denominator='mid-2024 ONS population, not two-January mean',
  caveat='national methods differ from Eurostat; 15-64 comparable numerator unavailable in this collection')
 pd.DataFrame([uk]).to_csv(D/'csv/uk_ons_2024_all_ages.csv',index=False,encoding='utf-8-sig')
 pt=pd.read_csv(D/'csv/ine_immigration_2024_S7A.csv',dtype=str);pt=pt[(pt.dim_3=='T')&(pt.dim_5=='T')]
 pp=pd.read_csv(D/'csv/ine_population_nuts2024.csv',dtype=str);pp=pp[pp.dim_3=='T']
 def age_count(df):
  aa=df.dim_4_t.str.extract(r'^(\d+) years?$')[0].astype(float)
  ss=df[aa.between(15,64)];assert len(ss)==50
  return pd.to_numeric(ss.valor).sum()
 def total(df):
  ss=df[df.dim_4=='T'];assert len(ss)==1
  return float(ss.iloc[0].valor)
 pt15=age_count(pt);bands=[f'{a} - {a+4} years' for a in range(15,65,5)]
 assert pt15==pd.to_numeric(pt[pt.dim_4_t.isin(bands)].valor).sum()
 p23=pp[pp.time=='2023'];p24=pp[pp.time=='2024']
 rr=dict(country='PT',year=2024,immigration_15_64=pt15,immigration_all_ages=total(pt),population_15_64_end2023=age_count(p23),population_15_64_end2024=age_count(p24),population_total_end2023=total(p23),population_total_end2024=total(p24),immigration_indicator='0006055',population_indicator='0012905',immigration_updated='2026-09-30',population_updated='2026-06-22',age_definition='INE national reference-date age; not assigned Eurostat COMPLET or REACH',population_method='mean of end-2023 and end-2024 revised resident population',definition='permanent immigrants: national or foreign, previous residence abroad >=1 year, intended stay >=1 year')
 pd.DataFrame([rr]).to_csv(D/'csv/pt_ine_2024_supplement.csv',index=False,encoding='utf-8-sig')
 print('PT national supplement:',rr,flush=True)
 imm=pd.read_csv(D/'csv/migr_imm8_2024.csv');pop=pd.read_csv(D/'csv/demo_pjan_2024_2025.csv')
 print('Migrant ages:',sorted(imm.age.unique()),flush=True)
 print('Observed immigration countries:',sorted(imm.loc[imm.value.notna(),'geo'].unique()),flush=True)
 print('Population countries:',sorted(pop.geo.unique()),flush=True)
