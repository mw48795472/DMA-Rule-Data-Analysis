"""Public Eurostat bilateral migration/FDI/FATS refresh; no API key required."""
from pathlib import Path
import concurrent.futures,datetime,hashlib,itertools,json,subprocess,sys,urllib.request,urllib.error,urllib.parse
import pandas as pd

ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'inputs/mechanisms_20261102/flows'
for n in ['raw','csv','metadata']:(D/n).mkdir(parents=True,exist_ok=True)
EU='AT BE BG HR CY CZ DK EE FI FR DE EL HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE'.split()
NEIGHBOURS='UK IS LI NO CH AL BA ME MK RS XK MD UA TR BY RU'.split()
COMPARATORS='US CN IN JP'.split()
PARTNERS=EU+NEIGHBOURS+COMPARATORS
BASE='https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/'
def query(dataset,params):return BASE+dataset+'?'+urllib.parse.urlencode(params,doseq=True)
common=dict(lang='EN',freq='A',sinceTimePeriod=2017,untilTimePeriod=2025)
JOBS=[
 ('migration_inward_refresh','migr_imm5prv',query('migr_imm5prv',dict(common,age=['TOTAL','Y15-64'],sex='T',unit='NR',partner=PARTNERS+['TOTAL']))),
 ('migration_outward_refresh','migr_emi3nxt',query('migr_emi3nxt',dict(common,age=['TOTAL','Y15-64'],sex='T',unit='NR',partner=PARTNERS+['TOTAL']))),
 ('fdi_inward_j_refresh','bop_fdi6_flow',query('bop_fdi6_flow',dict(common,nace_r2='J',currency='MIO_EUR',stk_flow='NI',entity=['TOTAL','SPE'],fdi_item='DI__D__F',partner=PARTNERS+['WRL_REST']))),
 ('fdi_outward_j_refresh','bop_fdi6_flow',query('bop_fdi6_flow',dict(common,nace_r2='J',currency='MIO_EUR',stk_flow='NO',entity=['TOTAL','SPE'],fdi_item='DO__D__F',partner=PARTNERS+['WRL_REST']))),
 ('foreign_affiliates_j_refresh','fats_activ',query('fats_activ',dict(lang='EN',freq='A',sinceTimePeriod=2021,untilTimePeriod=2025,nace_r2='J',indic_sbs=['EMP_NR','ENT_NR','AV_MEUR']))),
]
DOCS=[
 ('migration_metadata','migr_immi','https://ec.europa.eu/eurostat/cache/metadata/en/migr_immi_esms.htm'),
 ('fdi_metadata','bop_fdi6','https://ec.europa.eu/eurostat/cache/metadata/en/bop_fdi6_esms.htm'),
 ('fats_metadata','fats','https://ec.europa.eu/eurostat/cache/metadata/en/fats_sims.htm'),
]
def read_jsonstat(j):
    ids=j['id']; cats=[]
    for k in ids:
        ix=j['dimension'][k]['category']['index']
        cats.append([a for a,b in sorted(ix.items(),key=lambda z:z[1])] if isinstance(ix,dict) else ix)
    vals=j.get('value',{});flags=j.get('status',{})
    def get(o,i):return o.get(str(i)) if isinstance(o,dict) else (o[i] if i<len(o) else None)
    return pd.DataFrame([dict(zip(ids,t),value=get(vals,i),status=get(flags,i)) for i,t in enumerate(itertools.product(*cats))])
def download(job,doc=False):
    name,ds,url=job;p=D/'raw'/(name+('.html' if doc else '.json'))
    record=dict(source_id=name,dataset=ds,source_url=url,api_key_required='no',relative_raw_file=p.relative_to(ROOT).as_posix(),retrieved_utc=None)
    try:
        if not p.exists():
            req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 (public statistics research)'})
            try:
                with urllib.request.urlopen(req,timeout=90) as response:raw=response.read()
                p.write_bytes(raw)
            except urllib.error.URLError as error:
                if sys.platform!='win32' or 'CERTIFICATE_VERIFY_FAILED' not in str(error):raise
                quote=lambda s:"'"+str(s).replace("'","''")+"'"
                subprocess.run(['powershell.exe','-NoProfile','-Command','Invoke-WebRequest -UseBasicParsing -TimeoutSec 90 -Uri '+quote(url)+' -OutFile '+quote(p)],check=True)
            record['retrieved_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
        else:
            record['retrieved_utc']=datetime.datetime.fromtimestamp(p.stat().st_mtime,datetime.timezone.utc).isoformat()
        raw=p.read_bytes();record.update(download_status='downloaded',bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())
        if not doc:
            j=json.loads(raw);assert 'id' in j,j
            df=read_jsonstat(j)
            df.to_csv(D/'csv'/(name+'.csv'),index=False,encoding='utf-8-sig')
            meta={k:j[k] for k in ['id','size','dimension','updated','label'] if k in j}
            (D/'metadata'/(name+'_dimensions.json')).write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
            record.update(rows=len(df),observed=int(df.value.notna().sum()),source_updated=j.get('updated'),min_year=int(df.time.min()),max_year=int(df.time.max()),csv_file=(D/'csv'/(name+'.csv')).relative_to(ROOT).as_posix())
        print(name,record['download_status'],record.get('rows','document'),flush=True)
    except Exception as error:
        record.update(download_status='failed',error=str(error));print(name,'FAILED',str(error)[:250],flush=True)
    return record
if __name__=='__main__':
    records=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        for r in pool.map(download,JOBS):records.append(r)
    for job in DOCS:records.append(download(job,True))
    pd.DataFrame(records).to_csv(D/'SOURCE_MANIFEST.csv',index=False,encoding='utf-8-sig')
    (D/'metadata/request_scope.json').write_text(json.dumps(dict(requested_years=[2017,2025],fats_years=[2021,2025],europe43=EU+NEIGHBOURS,extra_global_comparators=COMPARATORS,selected_partner_countries=PARTNERS,notes='A selected 47-country partner frame, not all world; all returned reporters retained in raw then explicitly filtered. EU27 grouping is fixed analytical scope, not historical EU membership.'),indent=2),encoding='utf-8')
    if any(x['download_status']!='downloaded' for x in records[:len(JOBS)]):raise SystemExit('Required data download failed; inspect SOURCE_MANIFEST.csv and rerun after resolving access.')
