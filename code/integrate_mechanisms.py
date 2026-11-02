"""Audit the three measurement layers without fitting a causal model.

This script deliberately does not merge compliance changes, firm cases and
country dyads into one observation table. Source workers own their own files.
"""
from pathlib import Path
import hashlib,json
import pandas as pd

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'outputs/mechanisms_20261102/integration'
OUT.mkdir(parents=True,exist_ok=True)
def read(p): return pd.read_csv(p,low_memory=False)
def save(df,name): df.to_csv(OUT/name,index=False,encoding='utf-8-sig')
def norm(s): return s.replace({'GB':'UK','GR':'EL'})

def main():
    catalogs=[];missing=[];hashes={}
    for area in ['inputs','outputs']:
        for domain in ['compliance','firms','flows']:
            folder=ROOT/area/'mechanisms_20261102'/domain
            for p in sorted(folder.rglob('*.csv')):
                try: df=read(p)
                except pd.errors.EmptyDataError: df=pd.DataFrame()
                rel=p.relative_to(ROOT).as_posix()
                years=[]
                for col in ['year','time','event_year','join_year']:
                    if col in df:
                        v=pd.to_numeric(df[col],errors='coerce').dropna()
                        if len(v): years=list(v.astype(int));break
                units=' | '.join(map(str,df['unit'].dropna().unique())) if 'unit' in df else ''
                value='value' if 'value' in df else None
                catalogs.append(dict(domain=domain,path=rel,rows=len(df),columns=len(df.columns),
                    year_min=min(years) if years else None,year_max=max(years) if years else None,
                    units=units,value_nonmissing=int(df[value].notna().sum()) if value else None,
                    exact_duplicate_rows=int(df.duplicated().sum()),bytes=p.stat().st_size,
                    sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
                for col in df:
                    missing.append(dict(domain=domain,path=rel,column=col,rows=len(df),
                        missing=int(df[col].isna().sum()),observed=int(df[col].notna().sum())))
                hashes[rel]=hashlib.sha256(p.read_bytes()).hexdigest()
    catalog=pd.DataFrame(catalogs);save(catalog,'integration_catalog.csv')
    save(pd.DataFrame(missing),'integration_missingness.csv')
    panel=read(ROOT/'outputs/combined_country_year.csv')
    panel['country']=norm(panel['country'])
    assert not panel.duplicated(['country','year']).any(),'Nonunique legacy country-year bridge'
    keep=['country','year','ict_share_pct','employment_na_j_share_pct','gdp_pc_pps',
          'unemployment_pct','exposure_pre_2017_2019_pct','pre_j_share_pct']
    bridge=panel[keep].copy();save(bridge,'country_year_covariate_bridge.csv')
    save(pd.DataFrame([dict(key='country + year',rows=len(bridge),countries=bridge.country.nunique(),
        min_year=int(bridge.year.min()),max_year=int(bridge.year.max()),duplicate_keys=0,
        no_forward_fill=True,meaning='covariates_only_not_treatment_or_causal_identification')]),'bridge_audit.csv')
    firms=read(ROOT/'inputs/mechanisms_20261102/firms/csv/firm_events.csv')
    assert not firms.event_id.duplicated().any()
    labels={'operational_offshoring_or_outsourcing':'운영 이전·아웃소싱',
            'legal_parent_redomiciliation':'법적 지주회사 재편',
            'new_regional_hq_and_investment_expansion':'신규 지역본부·투자 확장'}
    firmplot=firms.groupby('event_kind',dropna=False).size().rename('count').reset_index()
    firmplot['label']=firmplot.event_kind.map(labels);save(firmplot,'figure_firm_case_types.csv')
    seeds=ROOT/'inputs/mechanisms_20261102/compliance/metadata/events_seed.json'
    compliance=pd.DataFrame(json.loads(seeds.read_text(encoding='utf8')))
    assert not compliance.event_id.duplicated().any()
    compplot=compliance.groupby(['geographic_scope_code','record_kind'],dropna=False).size().rename('count').reset_index()
    save(compplot,'figure_compliance_scope.csv')
    fresh=ROOT/'outputs/mechanisms_20261102/flows/fresh/summary.json'
    flows=json.loads(fresh.read_text(encoding='utf8'))
    assert flows['status']=='complete','Fresh flow outputs not complete'
    flabel={'migration_inward':'이민 유입','migration_outward':'이출 유출','fdi_inward_j':'FDI 유입 J',
            'fdi_outward_j':'FDI 유출 J','foreign_affiliates_j':'외국계 기업 J'}
    cov=[]
    for s in flows['sources']:
        cov.append(dict(source_id=s['source_id'],label=flabel.get(s['source_id'],s['source_id']),
           rows=s['od_rows'],observed=s['od_observed'],missing=s['od_missing'],
           observed_pct=100*s['od_observed']/s['od_rows'],zeros=s['od_observed_zeros'],
           negative=s['od_negative_values'],min_year=min(s['years']),max_year=max(s['years'])))
    save(pd.DataFrame(cov),'figure_flow_coverage.csv')
    (OUT/'integration_source_hashes.json').write_text(json.dumps(hashes,ensure_ascii=False,indent=2),encoding='utf8')
    summary=dict(status='PASS',source_csv_files=len(catalog),legacy_bridge_rows=len(bridge),
      legacy_bridge_countries=bridge.country.nunique(),legacy_bridge_duplicate_keys=0,
      firm_cases=len(firms),compliance_records=len(compliance),
      causal_model_fitted=False,missing_to_zero=False,forward_fill=False,
      scope='three separate measurement layers plus exact country-year covariate bridge')
    (OUT/'integration_validation.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps(summary,ensure_ascii=False))

if __name__=='__main__':main()
