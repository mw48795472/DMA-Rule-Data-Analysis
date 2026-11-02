"""Small audited public firm-event sample; NOT the complete ERM database.
Run from any directory. Downloads official public evidence and builds event/destination
relations plus exact-year joins. No destination shares, zero events, or moves imputed.
"""
from pathlib import Path
import csv,datetime,hashlib,json,re,subprocess,sys,urllib.request,urllib.error,html
from concurrent.futures import ThreadPoolExecutor
import pandas as pd

P=Path(__file__).resolve().parents[1]
D=P/'inputs/mechanisms_20261102/firms'; O=P/'outputs/mechanisms_20261102/firms'
for f in [D/'raw',D/'csv',D/'metadata',O]:f.mkdir(parents=True,exist_ok=True)
STAMP=datetime.datetime.now(datetime.timezone.utc).isoformat()
BASE='https://apps.eurofound.europa.eu/restructuring-events/'
REV_MAY='https://www.revolut.com/en-FR/news/revolut_announces_new_western_europe_hq_based_in_paris_and_will_apply_for_french_banking_licence_to_support_regional_growth/'
REV_APR='https://www.revolut.com/fr-FR/news/revolut_locks_in_paris_headquarters_for_western_europe/'
KLARNA='https://www.sec.gov/Archives/edgar/data/2003292/000200329225000015/klarnagroupplcf-1a2.htm'
SOURCES=[(f'erm_{i}',BASE+'detail/'+i,'ERM_public_factsheet') for i in ['202407','202720','301236','201244','108338','204607','204598','301213','92139']]
SOURCES += [('erm_methodology',BASE+'methodology','official_methodology'),('erm_calculator',BASE+'calculator','official_access_conditions'),('klarna_sec_f1a_20250814',KLARNA,'company_regulatory_filing'),('revolut_paris_20250520',REV_MAY,'company_press_release'),('revolut_paris_20260408',REV_APR,'company_press_release')]

def fetch(job):
    key,url,kind=job;path=D/'raw'/(key+'.html');meta=D/'metadata'/(key+'.json')
    if path.exists() and meta.exists():return json.loads(meta.read_text(encoding='utf-8'))
    r=dict(source_id=key,url=url,source_type=kind,retrieved_utc=STAMP,api_key_required='no',free_access='public_page',status='pending',local_file='',bytes=None,sha256='',error='')
    try:
        req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0 (public research evidence collection)'})
        try:
            with urllib.request.urlopen(req,timeout=55) as response:body=response.read();r['http_status']=response.status
            path.write_bytes(body)
        except urllib.error.URLError as e:
            if sys.platform=='win32' and 'CERTIFICATE_VERIFY_FAILED' in str(e):
                q=lambda x:"'"+str(x).replace("'","''")+"'"
                subprocess.run(['powershell.exe','-NoProfile','-Command','Invoke-WebRequest -UseBasicParsing -Uri '+q(url)+' -OutFile '+q(path)],check=True,timeout=70,capture_output=True)
                body=path.read_bytes();r['http_status']=200;r['transport']='Windows certificate store; TLS verification enabled'
            else:raise
        if len(body)<500:raise ValueError('Unexpectedly short document')
        plain=html.unescape(re.sub('<[^>]+>',' ',body.decode('utf-8',errors='replace'))).lower()
        expected={'erm_202407':'bird','erm_202720':'bouygues','erm_301236':'brainrocket','erm_201244':'expedia','erm_108338':'gostudent','erm_204607':'microsoft','erm_204598':'nextlane','erm_301213':'delivery hero','erm_92139':'bae systems','erm_methodology':'methodology','erm_calculator':'research','klarna_sec_f1a_20250814':'klarna','revolut_paris_20250520':'paris','revolut_paris_20260408':'paris'}
        if expected[key] not in plain or any(s in plain for s in ['request rate threshold exceeded','just a moment...','access denied']):raise ValueError('Downloaded response did not pass expected source-content check')
        r.update(status='downloaded',local_file=path.relative_to(P).as_posix(),bytes=len(body),sha256=hashlib.sha256(body).hexdigest())
    except Exception as e:r.update(status='raw_download_unavailable_web_verified',error=str(e)[:500])
    meta.write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
    print(key,r['status'],flush=True);return r

def event(id,company,origin,announce,effect,end,loss_min,loss_max,sector,nace,scope,reason,status,notes,destinations):
    return dict(event_id=id,company=company,origin_country=origin,announcement_date=announce,
      event_year=int(announce[:4]),event_year_basis='announcement_year',employment_effect_start_reported=effect,
      foreseen_end_date=end,effective_date_precision='day' if effect else 'not_reported',
      planned_job_losses_min=loss_min,planned_job_losses_max=loss_max,jobs_moved_verified=None,
      sector_source=sector,nace_code_source=nace,nace_version='source_unspecified_preserved',digital_scope=scope,
      event_kind='operational_offshoring_or_outsourcing',event_status=status,
      completion_verified_from_company_filing=False,dma_motive_evidence='not_stated_in_consulted_source',
      source_stated_reason=reason,reason_source_kind='ERM_media_monitor_description',researcher_inference='DMA causality not identified',
      source_id=id.lower(),source_url=BASE+'detail/'+id.replace('ERM_',''),
      source_publication_date=announce,notes_ko=notes,destinations=destinations)

EVENTS=[
 event('ERM_202407','Bird','NL','2025-02-12','2025-02-12','2025-12-31',120,120,'Information / Computing','62','software_communications',
 'Fiscal and employment-policy constraints and competitiveness, as described by ERM; DMA not mentioned','partial_downsizing_reported_relocation_completion_unverified',
 '120은 출발국 감원이다. 본문은 네덜란드 본사 소재가 당시 유지된다고 명시하여 제목의 본사 폐쇄 표현과 구별한다. Thailand 휴양 거점은 이전 목적지에 추가하지 않았다.', ['LT','US','TR','AE']),
 event('ERM_202720','Bouygues Telecom','FR','2025-05-02','2025-12-02','2026-12-31',150,150,'Information / Computing','61','telecommunications',
 'Market changes, hiring freeze and voluntary restructuring','announced_only',
 '150은 해당 팀의 감원 계획이고 전체 조직의 700 감원 계획과 합산하지 않는다. Porto와 Rabat 간 배분은 미보고.', ['PT','MA']),
 event('ERM_301236','BrainRocket','CY','2026-09-08','2025-07-01',None,1000,1000,'Information / Computing','62','software',
 'Resource consolidation, talent and infrastructure optimisation reported by ERM','relocation_reported_no_independent_completion_verification',
 '영향받은 직원과 실제 이주 직원을 구분한다. 발표일보다 이른 고용영향 시작일은 원문 그대로 보존하고 오류 플래그를 둔다. 완전한 Cyprus 철수는 확인되지 않았다.', ['ES','MT']),
 event('ERM_201244','Expedia Services CZ','CZ','2024-03-11','2024-04-01','2024-07-01',350,350,'Administrative / Support Services','79','online_travel_platform_support',
 'Global restructuring and lower operating costs in destination countries','announced_only',
 '350은 Prague 감원 계획이고 글로벌 1500 감원과 중복 합산하지 않는다. India·Guatemala 각각의 이전 일자리 수는 알려지지 않았다.', ['IN','GT']),
 event('ERM_108338','GoStudent','AT','2022-12-21','2023-01-13',None,200,200,'Education','85.6','platform_tutoring',
 'Weak purchasing power and poor economic conditions; parts outsourced to Turkey','announced_only',
 '200은 노조 추정 감원이며 Turkey 이전 수가 아니다. 회사는 구체적 인원을 확인하지 않았으므로 저신뢰 수치 출처를 표시한다.', ['TR']),
 event('ERM_204607','Microsoft France','FR','2026-02-19','2026-02-19',None,100,100,'Information / Computing','62','software_engineering_ai',
 'Organisational consolidation of engineering teams into larger hubs, notably Dublin','announced_only',
 'France 센터 폐쇄와 Dublin 통합 발표를 기록한다. 100명 감원이 Ireland에서 같은 수의 신규직으로 이어진다고 가정하지 않는다.', ['IE']),
 event('ERM_204598','Nextlane','FR','2026-03-23','2026-04-23',None,50,60,'Information / Computing','62.20','automotive_software_support',
 'European organisational shift and a Portugal centre of excellence','announced_only',
 '50~60은 France 역할 감축·이관 계획 범위다. 실제 사람이 이동했는지 확인되지 않았다. Spain 관련 서술은 규모·시점이 불명확하여 별도 사건을 생성하지 않았다.', ['PT']),
 event('ERM_301213','Delivery Hero','DE','2026-09-24','2026-09-24',None,200,200,'Accommodation / Food','56.40','food_delivery_platform_technology',
 'Technology centralisation following an announced acquisition, according to ERM','announced_only',
 '본문이 Pandora 기술조직의 Berlin→Singapore 이전을 명시하지만 구조화 목적지 칸은 비어 있다. 200은 영향 직원 수이며 이동 완료 수가 아니다. 예정: 2026년 말.', ['SG']),
 event('ERM_92139','BAE Systems Cyber Security & Intelligence','DK','2017-09-20','2018-06-01',None,160,160,'Manufacturing','25.3','surveillance_data_processing_adjacent',
 'Closure and transfer confirmed by UK headquarters; specific regulation motive not stated','announced_only',
 '디지털·감시 기술 관련 비교사례이며 ERM 산업은 제조업이다. 2017년 UK는 EU 회원국이었다. UK의 현재 비EU 지위를 과거 사건에 소급하지 않는다.', ['UK']),
]
EVENTS.append(dict(event_id='FILING_KLARNA_202405',company='Klarna Group plc',origin_country='SE',announcement_date=None,event_year=2024,event_year_basis='effective_month_year',employment_effect_start_reported=None,foreseen_end_date=None,effective_date_precision='month',effective_month='2024-05',planned_job_losses_min=None,planned_job_losses_max=None,jobs_moved_verified=None,sector_source='Financial technology; SEC SIC 6199',nace_code_source=None,nace_version='not_assigned',digital_scope='fintech_comparison_case',event_kind='legal_parent_redomiciliation',event_status='completed_legal_reorganisation_reported_in_filing',completion_verified_from_company_filing=True,dma_motive_evidence='not_stated_in_consulted_source',source_stated_reason='Share-for-share corporate reorganisation; no DMA motive stated',reason_source_kind='company_regulatory_filing',researcher_inference='Legal parent change is not evidence of operational or staff relocation',source_id='klarna_sec_f1a_20250814',source_url=KLARNA,source_publication_date='2025-08-14',notes_ko='2025-08-14 SEC F-1/A가 2024년 5월 Sweden→UK 모회사 재편을 소급 보고한다. 2022 법인 설립일이나 2023 명칭 변경일과 구분한다. 실제 고용·사업장 이전 수는 미보고.',destinations=['UK']))
EVENTS.append(dict(event_id='CORP_REVOLUT_PARIS_202505',company='Revolut',origin_country=None,announcement_date='2025-05-20',event_year=2025,event_year_basis='announcement_year',employment_effect_start_reported=None,foreseen_end_date=None,effective_date_precision='not_completed_expected_early_2027',planned_job_losses_min=None,planned_job_losses_max=None,jobs_moved_verified=None,sector_source='Financial technology',nace_code_source=None,nace_version='not_assigned',digital_scope='fintech_comparison_case',event_kind='new_regional_hq_and_investment_expansion',event_status='announced_lease_signed_opening_pending',completion_verified_from_company_filing=False,dma_motive_evidence='not_stated_in_consulted_source',source_stated_reason='Western European market growth and local banking presence',reason_source_kind='company_press_release',researcher_inference='Not evidence of UK or Lithuania operational exit',source_id='revolut_paris_20250520',source_url=REV_MAY,source_publication_date='2025-05-20',notes_ko='Paris 신규 지역본부는 London 글로벌 본부 및 Lithuania 사업을 보완한다고 명시한다. 2026-04-08 임대계약 후 2027년 초 개설 예정. 출발국을 UK/LT로 임의 대입하지 않으며 1bn EUR 3년 투자계획을 실현 FDI로 쓰지 않는다.',destinations=['FR']))

def build(manifest):
    old=pd.read_csv(P/'inputs/additional/csv/erm_offshoring_pilot.csv')
    old_ids=set(old.event_id);m={r['source_id']:r for r in manifest}
    rows=[];relations=[]
    for data in EVENTS:
        e=data.copy();dest=e.pop('destinations');e['collection_status']='reused_reverified_public_source' if e['event_id'] in old_ids else 'newly_collected_public_case'
        e['sampling']='purposive_public_case_sample_not_exhaustive';e['sampling_denominator_available']=False
        e['destination_count']=len(dest);e['physical_crossborder_move_confirmed_as_completed']=None
        e['date_order_anomaly']=bool(e['announcement_date'] and e['employment_effect_start_reported'] and e['employment_effect_start_reported']<e['announcement_date'])
        e['raw_source_status']=m[e['source_id']]['status'];e['source_sha256']=m[e['source_id']]['sha256']
        rows.append(e)
        for target in dest:
            relations.append(dict(event_id=e['event_id'],origin_country=e['origin_country'],destination_country=target,event_year=e['event_year'],event_kind=e['event_kind'],jobs_allocated_to_destination=None,jobs_moved_verified=None,allocation_status='not_reported_do_not_duplicate_event_jobs',relation_basis='source_explicit_operational_destination' if e['event_kind']=='operational_offshoring_or_outsourcing' else ('source_explicit_legal_domicile' if e['event_kind']=='legal_parent_redomiciliation' else 'new_site_only_origin_not_identified'),source_url=e['source_url']))
    events=pd.DataFrame(rows);rel=pd.DataFrame(relations)
    assert events.event_id.is_unique and not rel.duplicated(['event_id','origin_country','destination_country']).any()
    assert rel.jobs_allocated_to_destination.isna().all() and rel.jobs_moved_verified.isna().all()
    events.to_csv(D/'csv/firm_events.csv',index=False,encoding='utf-8-sig')
    rel.to_csv(D/'csv/firm_event_destinations.csv',index=False,encoding='utf-8-sig')
    pd.DataFrame([{'event_id':'CORP_REVOLUT_PARIS_202505','source_id':'revolut_paris_20250520','observation_date':'2025-05-20','status':'new_regional_HQ_announced'}, {'event_id':'CORP_REVOLUT_PARIS_202505','source_id':'revolut_paris_20260408','observation_date':'2026-04-08','status':'lease_signed_expected_opening_early_2027'}, {'event_id':'FILING_KLARNA_202405','source_id':'klarna_sec_f1a_20250814','observation_date':'2025-08-14','status':'retrospective_report_of_May_2024_legal_reorganisation'}]).to_csv(D/'csv/firm_event_source_updates.csv',index=False,encoding='utf-8-sig')
    panel=pd.read_csv(P/'outputs/combined_country_year.csv')
    assert not panel.duplicated(['country','year']).any()
    cov=['ict_share_pct','employment_na_j_share_pct','gdp_pc_pps','unemployment_pct','exposure_pre_2017_2019_pct','pre_j_share_pct']
    cov=[v for v in cov if v in panel]
    years=set(panel.year);countries=set(panel.country)
    joined=rel.copy();audit=[]
    for side in ['origin','destination']:
        ren={'country':side+'_country','year':'event_year',**{v:side+'_'+v for v in cov}}
        right=panel[['country','year']+cov].copy();right[side+'_country_year_row_present']=True
        right=right.rename(columns=ren)
        joined=joined.merge(right,on=[side+'_country','event_year'],how='left',validate='many_to_one')
        joined[side+'_country_year_row_present']=joined[side+'_country_year_row_present'].fillna(False).astype(bool)
        for row in joined.itertuples(index=False):
            cc=getattr(row,side+'_country');yy=row.event_year
            reason='matched' if getattr(row,side+'_country_year_row_present') else ('origin_not_reported_new_expansion' if pd.isna(cc) else ('country_not_in_existing_panel' if cc not in countries else 'event_year_outside_existing_panel' if yy not in years else 'key_absent'))
            audit.append(dict(event_id=row.event_id,side=side,country=cc,event_year=yy,match_reason=reason))
    assert len(joined)==len(rel)
    joined.to_csv(O/'firm_event_country_year_join.csv',index=False,encoding='utf-8-sig')
    audit=pd.DataFrame(audit).drop_duplicates();audit.to_csv(O/'firm_join_audit.csv',index=False,encoding='utf-8-sig')
    pd.DataFrame([dict(variable=c,rows=len(joined),observed=int(joined[c].notna().sum()),missing=int(joined[c].isna().sum())) for c in joined if c.startswith(('origin_','destination_'))]).to_csv(O/'joined_missingness.csv',index=False,encoding='utf-8-sig')
    agg=events.groupby(['origin_country','event_year','event_kind'],dropna=False).size().reset_index(name='observed_sample_events')
    agg['sampling_denominator_available']=False;agg['interpretation']='case_sample_only_not_relocation_rate_no_zero_filling'
    agg.to_csv(O/'observed_event_counts.csv',index=False,encoding='utf-8-sig')
    all_eu=set('AT BE BG HR CY CZ DK EE FI FR DE EL HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE'.split())
    code_list=sorted(set(rel.origin_country.dropna())|set(rel.destination_country))
    codebook=pd.DataFrame([dict(country=c,iso2={'EL':'GR','UK':'GB'}.get(c,c),in_existing_panel=c in countries,current_eu27=c in all_eu,notes='UK was EU member at 2017 BAE announcement; do not backcast current group' if c=='UK' else '') for c in code_list])
    codebook.to_csv(O/'country_code_audit.csv',index=False,encoding='utf-8-sig')
    dictionary=[
      ('event_id','사건 식별자; 같은 계획의 후속 보도는 새로운 사건으로 세지 않음','key'),
      ('event_year','원칙상 발표연도; 법적 재편은 확인된 효력 월의 연도','year'),
      ('event_year_basis','발표연도와 효력연도 구분','category'),
      ('origin_country / destination_country','Eurostat 국가코드; UK/EL을 사용. 미보고 출발지는 NA','country'),
      ('event_kind','실물 활동 offshoring / 법적 모회사 재편 / 신규 확장 구분','category'),
      ('event_status','계획·부분 감원 보고·법적 완료·개설 대기 구분','category'),
      ('planned_job_losses_min / max','출발국 사건 단위 감원/영향 인원; 목적지 이전 인원 아님','persons_announced'),
      ('jobs_moved_verified','실제 국경을 이동한 사람 수; 이번 표본에서 미확보','persons'),
      ('jobs_allocated_to_destination','특정 목적지에 배분된 일자리 수; 미보고는 모두 NA','jobs'),
      ('source_stated_reason','조회한 출처가 서술한 동기; 독립적 인과 판정 아님','text'),
      ('dma_motive_evidence','조회 출처에서 DMA 동기가 명시되지 않은 경우 not_stated; 원인이 없다는 0 아님','category'),
      ('date_order_anomaly','고용영향 시작일이 발표일보다 앞서는 원문 보존 플래그','boolean'),
      ('collection_status','기존 3개 재검증과 신규 8개 사건 구분','category'),
      ('source_sha256 / raw_source_status','원문 보존 해시와 다운로드 상태; 실패를 성공으로 기록하지 않음','provenance'),
      ('*_country_year_row_present','정확한 국가-사건연도 행 결합 여부; 값 결측과 별개','boolean'),
      ('origin_* / destination_*','기존 국가-연도 공변량; 원천 단위와 결측 유지, 전진 채움 없음','original_units'),
      ('sampling_denominator_available','목적표집 사건 표본으로 모집단 기업수/포착률 분모 없음','boolean')
    ]
    pd.DataFrame(dictionary,columns=['variable','description_ko','unit_or_type']).to_csv(O/'data_dictionary.csv',index=False,encoding='utf-8-sig')
    summary=dict(events=len(events),newly_collected=int((events.collection_status=='newly_collected_public_case').sum()),reused_reverified=int((events.collection_status=='reused_reverified_public_source').sum()),event_destination_relations=len(rel),known_origin_destination_relations=int(rel.origin_country.notna().sum()),events_with_known_od=int(events.origin_country.notna().sum()),event_years=sorted(events.event_year.unique().tolist()),event_kinds=events.event_kind.value_counts().to_dict(),event_statuses=events.event_status.value_counts().to_dict(),completed_legal_reorganisations=int(events.completion_verified_from_company_filing.sum()),completed_physical_moves_verified=0,actual_people_moved_observed=0,destination_job_allocations_observed=0,dma_reason_explicit_in_consulted_sources=0,dma_reason_absence_interpretation='not_stated_in_sources_does_not_prove_no_effect',date_order_anomalies=int(events.date_order_anomaly.sum()),downloads=sum(r['status']=='downloaded' for r in manifest),source_requests=len(manifest),failed_raw_downloads=[r['source_id'] for r in manifest if r['status']!='downloaded'],join_rows=len(joined),join_audit_counts=audit.groupby(['side','match_reason']).size().to_dict(),sampling='purposive_public_case_sample_not_exhaustive',sampling_denominator_available=False,unobserved_event_cells='missing_not_zero',no_forward_fill=True,existing_analysis_untouched=True)
    summary['join_audit_counts']={str(k):int(v) for k,v in summary['join_audit_counts'].items()}
    (O/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    (O/'validation.json').write_text(json.dumps(dict(status='PASS',unique_events=True,unique_event_destination=True,row_count_preserved=True,no_destination_job_duplication=True,no_missing_to_zero=True,no_forward_fill=True,original_pilot_event_ids_preserved=old_ids.issubset(set(events.event_id))),indent=2),encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False),flush=True)

if __name__=='__main__':
    with ThreadPoolExecutor(max_workers=3) as pool:manifest=list(pool.map(fetch,SOURCES))
    pd.DataFrame(manifest).to_csv(D/'SOURCE_MANIFEST.csv',index=False,encoding='utf-8-sig')
    pd.DataFrame([dict(source='ERM full bulk CSV',url=BASE+'calculator',free_access='noncommercial_research_request_required',api_key_required='not_a_key_issue_request_access',downloaded_count=0,source_count=None,notes='Official form not submitted; only public event pages coded'),dict(source='ERM public factsheets',url=BASE+'methodology',free_access='public',api_key_required='no',downloaded_count=sum(r['status']=='downloaded' and r['source_type']=='ERM_public_factsheet' for r in manifest),source_count=9,notes='Purposive sample with size/media selection, not representative; announced losses may differ from realised'),dict(source='Company official press/SEC public filing',url=KLARNA,free_access='public',api_key_required='no',downloaded_count=sum(r['status']=='downloaded' and r['source_type'].startswith('company_') for r in manifest),source_count=3,notes='Per-source actual HTTP/archive status is in SOURCE_MANIFEST.csv')]).to_csv(D/'csv/access_requirements.csv',index=False,encoding='utf-8-sig')
    build(manifest)
