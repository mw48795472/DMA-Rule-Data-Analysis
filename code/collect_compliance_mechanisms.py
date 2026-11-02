"""Archive public official compliance evidence. No credentials or API keys used."""
from pathlib import Path
import concurrent.futures,csv,datetime,hashlib,html,json,re,subprocess,sys,urllib.request,urllib.error
from pypdf import PdfReader
ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'inputs/mechanisms_20261102/compliance'
for x in ['raw','csv','metadata','text']:(D/x).mkdir(parents=True,exist_ok=True)
SOURCES=json.loads((D/"metadata/selected_sources.json").read_text(encoding="utf-8"))
def clean(x):return re.sub(r'\s+',' ',html.unescape(re.sub('<[^>]+>',' ',x)))
def run(job):
    sid,url,ext,phrase=job;f=D/'raw'/(sid+'.'+ext)
    rec=dict(source_id=sid,url=url,api_key_required='no',retrieved_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),status='',file='',sha256='',bytes=0,validation_phrase=phrase)
    try:
        if not f.exists():
            req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 (public academic research data collection)'})
            try:
                with urllib.request.urlopen(req,timeout=25) as response:data=response.read()
                f.write_bytes(data)
            except urllib.error.URLError as ex:
                if 'CERTIFICATE_VERIFY_FAILED' not in str(ex):raise
                q=lambda s:"'"+str(s).replace("'","''")+"'"
                subprocess.run(['powershell.exe','-NoProfile','-Command','Invoke-WebRequest -UseBasicParsing -Uri '+q(url)+' -OutFile '+q(f)],check=True,capture_output=True,timeout=80)
        data=f.read_bytes()
        text='\n'.join(p.extract_text() or '' for p in PdfReader(str(f)).pages) if ext=='pdf' else clean(data.decode('utf-8','replace'))
        (D/'text'/(sid+'.txt')).write_text(text,encoding='utf-8')
        rec.update(file=f.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(data).hexdigest(),bytes=len(data),status='downloaded_content_verified' if clean(phrase).casefold() in clean(text).casefold() else 'downloaded_needs_review')
    except Exception as ex:
        rec['status']='access_failed';rec['error']=str(ex)[:700]
    print(sid,rec['status'],rec['bytes'],flush=True)
    return rec
if __name__=='__main__' and '--build-only' not in sys.argv:
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:rows=list(pool.map(run,SOURCES))
    cols=['source_id','url','api_key_required','retrieved_utc','status','file','sha256','bytes','validation_phrase','error']
    with (D/'SOURCE_MANIFEST.csv').open('w',encoding='utf-8-sig',newline='') as stream:
        w=csv.DictWriter(stream,fieldnames=cols);w.writeheader();w.writerows(rows)
    print(json.dumps({'sources':len(rows),'content_verified':sum(r['status']=='downloaded_content_verified' for r in rows),'failed':sum(r['status']=='access_failed' for r in rows)}))
    if not any(r['status']=='downloaded_content_verified' for r in rows):sys.exit(2)


def write_csv(path, rows, fields=None):
    path.parent.mkdir(parents=True,exist_ok=True)
    if fields is None: fields=list(rows[0]) if rows else []
    with path.open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields,extrasaction='ignore');w.writeheader();w.writerows(rows)

def build_tables():
    out=ROOT/'outputs/mechanisms_20261102/compliance';out.mkdir(parents=True,exist_ok=True)
    basepath=ROOT/'outputs/combined_country_year.csv'
    basehash=hashlib.sha256(basepath.read_bytes()).hexdigest()
    with basepath.open(encoding='utf-8-sig',newline='') as f: base=list(csv.DictReader(f))
    canonical=lambda c: {'GR':'EL','GB':'UK'}.get(c,c)
    basekeys={(canonical(r['country']),int(r['year'])) for r in base}
    assert len(basekeys)==len(base),'Duplicate base country-year keys'
    eu=set('AT BE BG HR CY CZ DK EE FI FR DE EL HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE'.split())
    eea=eu|{'IS','LI','NO'}
    universe={canonical(r['country']) for r in base}|eea|{'CH','UK'}
    scopes={'EU27':eu,'EEA':eea,'EEA_CH':eea|{'CH'},'EEA_UK':eea|{'UK'},'WORLDWIDE':universe}
    src={s[0]:s for s in SOURCES}
    manifest={}
    if (D/'SOURCE_MANIFEST.csv').exists():
        with (D/'SOURCE_MANIFEST.csv').open(encoding='utf-8-sig',newline='') as f: manifest={r['source_id']:r for r in csv.DictReader(f)}
    events=json.loads((D/'metadata/events_seed.json').read_text(encoding='utf-8'))
    scope_rows=[];bridge=[]
    for e in events:
        ids=e['source_ids'].split(';')
        e['source_urls']=';'.join(src[i][1] for i in ids)
        e['source_sha256']=';'.join(i+':'+manifest.get(i,{}).get('sha256','') for i in ids if manifest.get(i,{}).get('sha256'))
        e['source_access_status']=';'.join(i+':'+manifest.get(i,{}).get('status','raw_download_pending') for i in ids)
        e['web_verification_status']='official_source_text_opened_and_read_2026-11-02'
        if e['record_kind']=='scope_snapshot':
            year=int(e['observation_date'][:4]); basis='scope_observed_year_not_adoption'; eligible='no'
        else:
            dated=e['effective_date'] or e['effective_not_after'] or e['announced_date']
            year=int(dated[:4]);basis='company_reported_implementation' if e['effective_date'] else ('implemented_by_upper_bound' if e['effective_not_after'] else 'announcement_year_only');eligible='yes'
        for c in sorted(scopes[e['geographic_scope_code']]):
            s={'event_id':e['event_id'],'country':c,'scope_confirmation':'included_by_explicit_scope','geographic_scope_code':e['geographic_scope_code'],'mapping_basis':'worldwide_expanded_only_over_panel_and_explicit_European_universe' if e['geographic_scope_code']=='WORLDWIDE' else 'explicit_region_membership','source_ids':e['source_ids']}
            scope_rows.append(s)
            bridge.append({**s,'year':year,'year_basis':basis,'historical_change_join_eligible':eligible,'matched_existing_country_year':'yes' if (c,year) in basekeys and eligible=='yes' else 'no','implementation_status':e['implementation_status'],'dma_attribution':e['dma_attribution'],'evidence_authority':e['evidence_authority']})
    eligible=[r for r in bridge if r['matched_existing_country_year']=='yes']
    index={}
    byid={e['event_id']:e for e in events}
    for r in eligible:index.setdefault((r['country'],r['year']),[]).append(r['event_id'])
    joined=[]
    for r in base:
        ids=index.get((canonical(r['country']),int(r['year'])),[])
        impl=[i for i in ids if byid[i]['implementation_status'].startswith('company_reported')]
        ann=[i for i in ids if i not in impl]
        joined.append({**r,'compliance_event_ids':';'.join(ids),'compliance_company_implemented_ids':';'.join(impl),'compliance_announcement_only_ids':';'.join(ann),'compliance_evidence_coverage':'documented_records_in_this_year' if ids else 'not_observed_in_collected_sources','compliance_use_limit':'mechanism_evidence_not_country_treatment_index'})
    write_csv(D/'csv/compliance_events.csv',events)
    write_csv(out/'compliance_events.csv',events)
    write_csv(out/'compliance_event_country_scope.csv',scope_rows)
    write_csv(out/'compliance_event_country_year_bridge.csv',bridge)
    write_csv(out/'combined_country_year_compliance.csv',joined)
    guard=[{'assessment_id':'R001','decision_date':'2025-04-23','authority':'European Commission','gatekeeper':'Apple','finding':'breach_of_DMA_anti_steering_obligation','purpose':'Regulatory determination; not a certification that collected company measures comply','source_url':src['ec_breach_20250423'][1]}, {'assessment_id':'R002','decision_date':'2025-04-23','authority':'European Commission','gatekeeper':'Meta','finding':'breach_of_DMA_obligation_to_offer_less_personal_data_service_choice','purpose':'Regulatory determination; do not equate self_report with lawful_compliance','source_url':src['ec_breach_20250423'][1]}]
    write_csv(out/'regulatory_context.csv',guard)
    audit={'events':len(events),'change_records':sum(e['record_kind']=='change' for e in events),'scope_snapshots':sum(e['record_kind']=='scope_snapshot' for e in events),'gatekeepers':sorted({e['gatekeeper'] for e in events}),'source_urls':len(src),'exact_effective_date_rows':sum(bool(e['effective_date']) for e in events),'implementation_upper_bound_rows':sum(bool(e['effective_not_after']) for e in events),'unknown_exact_effective_date_rows':sum(not e['effective_date'] for e in events),'scope_bridge_rows':len(scope_rows),'country_year_bridge_rows':len(bridge),'matched_change_bridge_rows':len(eligible),'base_country_year_rows':len(base),'joined_country_year_rows':len(joined),'base_year_min':min(int(r['year']) for r in base),'base_year_max':max(int(r['year']) for r in base),'country_years_with_documented_records':sum(bool(r['compliance_event_ids']) for r in joined),'duplicate_event_id':len(events)-len(byid),'duplicate_scope_key':len(scope_rows)-len({(r['event_id'],r['country']) for r in scope_rows}),'duplicate_event_country_year_key':len(bridge)-len({(r['event_id'],r['country'],r['year']) for r in bridge}),'snapshot_backdated_rows':sum(r['event_id']=='C011' and r['year']!=2026 for r in bridge),'unknown_as_zero':False,'national_event_count_treatment_index_created':False,'base_file_sha256':basehash,'base_file_unchanged':basehash==hashlib.sha256(basepath.read_bytes()).hexdigest(),'raw_download_status':{i:manifest.get(i,{}).get('status','pending') for i in src},'missing_raw_hash_source_ids':[i for i in src if not manifest.get(i,{}).get('sha256')]}
    assert audit['duplicate_event_id']==audit['duplicate_scope_key']==audit['duplicate_event_country_year_key']==audit['snapshot_backdated_rows']==0
    assert audit['base_file_unchanged'] and len(joined)==len(base)
    (out/'JOIN_AUDIT.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(audit,ensure_ascii=False,indent=2))

if __name__=='__main__' and '--build-only' in sys.argv:
    build_tables()
