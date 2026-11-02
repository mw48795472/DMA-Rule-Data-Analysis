"""Build transparent OD panels from cached actual Eurostat CSVs. No network; no models.

Run from any directory with pandas/numpy/matplotlib. Fresh one-cut JSON is used only
for validation and is never silently mixed into the frozen base snapshot.
"""
from pathlib import Path
import argparse, datetime, hashlib, itertools, json
import numpy as np
import pandas as pd

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--refresh',action='store_true');args=parser.parse_args()
REFRESH=args.refresh
OUT=ROOT/'outputs/mechanisms_20261102/flows'
if REFRESH:OUT=OUT/'fresh'
OUT.mkdir(parents=True,exist_ok=True)
BASE=ROOT/'inputs/base/csv'
INPUT=ROOT/'inputs/mechanisms_20261102/flows/csv' if REFRESH else BASE
SNAPSHOT='fresh_eurostat_20261102' if REFRESH else 'existing_base_actual_csv'
EU=set('AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU LU MT NL PL PT RO SK SI ES SE'.split())
COUNTRIES=set('AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS XK YE YT ZA ZM ZW'.split())
MAP={'EL':'GR','UK':'GB','CN_X_HK':'CN'}
def norm(s):
 if pd.isna(s): return None
 s=MAP.get(str(s).strip(),str(s).strip())
 return s if s in COUNTRIES else None
def save(df,name):
 p=OUT/name;df.to_csv(p,index=False,encoding='utf-8-sig');return str(p.relative_to(ROOT)).replace('\\','/')
def dump(obj,name):
 (OUT/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2,default=lambda v:int(v) if isinstance(v,np.integer) else float(v) if isinstance(v,np.floating) else str(v)),encoding='utf-8')
def eu_status(code,year):
 if code in EU:return 'member_full_year'
 if code=='GB' and year<=2019:return 'member_full_year'
 if code=='GB' and year==2020:return 'uk_withdrawal_transition_year'
 return 'non_member'

main=pd.read_csv(ROOT/'outputs/combined_country_year.csv',keep_default_na=False,na_values=[''])
main['year']=main['year'].astype(int)
main['country_iso2_normalized']=main['country'].map(norm)
if main['country_iso2_normalized'].isna().any():raise ValueError('Unmapped country code in base country-year panel')
base_dups=main[main.duplicated(['country_iso2_normalized','year'],keep=False)]
save(base_dups,'base_duplicate_keys.csv')
if len(base_dups):raise ValueError('Base country-year keys are not unique; refusing many-to-many joins')
keyset=set(zip(main.country_iso2_normalized,main.year)); basecountries=set(main.country_iso2_normalized); baseyears=set(main.year)
covars=['country','sample_eu27','ict_share_pct','exposure_pre_2017_2019_pct','employment_na_j_share_pct','pre_j_share_pct','gdp_pc_pps','gdp_pc_eur','gdp_meur','hourly_labour_cost_j_eur','unemployment_pct','population_15_64_annual_mean_approx','population_total_jan1','marketplace_firm_share_pct']
covars=[c for c in covars if c in main]
covars+= [c+'_flag' for c in covars if c+'_flag' in main]
def join_reason(c,y):
 if c is None or pd.isna(c):return 'unmapped_country_code'
 if c not in basecountries:return 'country_outside_base_panel'
 if y not in baseyears:return 'year_outside_base_panel'
 if (c,y) not in keyset:return 'missing_country_year_in_base'
 return 'matched_country_year'
join_audits=[];covariate_audits=[]
def attach(df,side,key):
 right=main[['country_iso2_normalized','year']+covars].rename(columns={'country_iso2_normalized':key,**{c:side+'_'+c for c in covars}})
 before=len(df);out=df.merge(right,on=[key,'year'],how='left',validate='many_to_one')
 assert len(out)==before
 out[side+'_join_status']=[join_reason(c,y) for c,y in zip(out[key],out.year)]
 out[side+'_fixed_eu27']=out[key].isin(EU).astype(int)
 out[side+'_eu_membership_status_year']=[eu_status(c,y) for c,y in zip(out[key],out.year)]
 for status,part in out.groupby(side+'_join_status',dropna=False):
  join_audits.append(dict(source_id=str(out.source_id.iloc[0]) if len(out) else '',side=side,status=status,rows=len(part),observed_values=int(part.value.notna().sum()),countries='|'.join(sorted(part[key].dropna().unique()))))
 matched=out[out[side+'_join_status'].eq('matched_country_year')]
 for c in covars:
  if c.endswith('_flag') or c in ['country','sample_eu27']:continue
  covariate_audits.append(dict(source_id=str(out.source_id.iloc[0]) if len(out) else '',side=side,covariate=c,matched_key_rows=len(matched),covariate_missing_with_matched_key=int(matched[side+'_'+c].isna().sum()),observed_flow_missing_covariate=int((matched.value.notna()&matched[side+'_'+c].isna()).sum())))
 return out

definitions=[
 ('migration_inward','migr_imm5prv','migration','inward','partner','geo','persons','flow'),
 ('migration_outward','migr_emi3nxt','migration','outward','geo','partner','persons','flow'),
 ('fdi_inward_j','bop_fdi6_flow','fdi','inward','partner','geo','million_eur','net_financial_flow'),
 ('fdi_outward_j','bop_fdi6_flow','fdi','outward','geo','partner','million_eur','net_financial_flow'),
 ('foreign_affiliates_j','fats_activ','fats','inward_control','c_ctrl','geo','indicator_specific','annual_activity_or_stock'),
]
summaries=[]; manifests=[]; coverage=[];countryrows=[]; panels={};excluded=[];duplicates=[]
links=pd.read_csv(ROOT/'inputs/base/source_links_api.csv',keep_default_na=False) if (ROOT/'inputs/base/source_links_api.csv').exists() else pd.DataFrame()
if REFRESH:links=pd.read_csv(ROOT/'inputs/mechanisms_20261102/flows/SOURCE_MANIFEST.csv',keep_default_na=False)
for source_id,dataset,kind,direction,origcol,destcol,unit,measure in definitions:
 p=INPUT/(source_id+('_refresh' if REFRESH else '')+'.csv');df=pd.read_csv(p,keep_default_na=False,na_values=[''])
 dims=[c for c in df if c not in ['value','status']]
 du=df[df.duplicated(dims,keep=False)].copy();du.insert(0,'source_id',source_id);duplicates.append(du)
 if len(du):raise ValueError(f'Duplicate native dimension key: {source_id}; inspect source before collapsing')
 df['year']=pd.to_numeric(df['time'],errors='raise').astype(int)
 df['value']=pd.to_numeric(df['value'],errors='coerce')
 df['source_id']=source_id;df['dataset']=dataset;df['source_snapshot']=SNAPSHOT
 df['measure_family']=kind;df['reporting_direction']=direction;df['measure_type']=measure;df['value_unit']=unit
 if kind=='fats':df['value_unit']=df.indic_sbs.map({'EMP_NR':'persons_employed','ENT_NR':'enterprise_count','AV_MEUR':'value_added_million_eur'})
 df['origin_code_raw']=df[origcol];df['destination_code_raw']=df[destcol]
 df['origin']=df[origcol].map(norm);df['destination']=df[destcol].map(norm);df['reporter']=df.geo.map(norm)
 df['is_value_observed']=df.value.notna().astype(int)
 df['value_is_negative']=((df.value<0)&df.value.notna()).astype(int)
 df['value_is_observed_zero']=((df.value==0)&df.value.notna()).astype(int)
 df['origin_code_scope']=np.where(df.origin_code_raw.eq('CN_X_HK'),'china_excluding_hong_kong','country_or_economy')
 valid=df.origin.notna() & df.destination.notna()
 selfmask=valid & df.origin.eq(df.destination)
 bad=df[~valid|selfmask].copy()
 bad['exclusion_reason']=np.where(~valid.loc[bad.index],'aggregate_or_non_country_partner','same_country_not_international')
 excluded.append(bad)
 od=df[valid&~selfmask].copy()
 od=attach(attach(od,'origin','origin'),'destination','destination')
 outname={'migration':'migration','fdi':'fdi','fats':'fats'}[kind]+'_'+direction+'_od.csv'
 outpath=save(od,outname);panels[source_id]=od
 # Source-native totals are preserved separately. Never sum the selected partners.
 partner='c_ctrl' if kind=='fats' else 'partner'
 total=df[df[partner].isin(['TOTAL','WRL_REST','WORLD','INT_EU27_2020','EXT_EU27_2020','EXT_EU_NAL','DOM']) & df.reporter.notna()].copy()
 total['aggregate_partner_code']=total[partner]
 total['aggregation_method']='source_reported_aggregate_no_partner_sum'
 total=attach(total,'reporter','reporter')
 countryrows.append(total)
 grpcols=['source_id','year']+[c for c in ['age','agedef','nace_r2','entity','indic_sbs'] if c in od]
 cv=od.groupby(grpcols,dropna=False).agg(rows=('value','size'),observed=('value','count'),negative=('value',lambda s:int(s.lt(0).sum())),zeros=('value',lambda s:int(s.eq(0).sum()))).reset_index()
 cv['missing']=cv.rows-cv.observed;cv['observed_fraction']=cv.observed/cv.rows;coverage.append(cv)
 summary=dict(source_id=source_id,dataset=dataset,source_rows=len(df),od_rows=len(od),od_observed=int(od.value.notna().sum()),od_missing=int(od.value.isna().sum()),od_observed_zeros=int(od.value.eq(0).sum()),od_negative_values=int(od.value.lt(0).sum()),native_duplicate_keys=len(du),years=sorted(df.year.unique().tolist()),reporter_countries=sorted(df.reporter.dropna().unique().tolist()),origin_countries=sorted(od.origin.unique().tolist()),destination_countries=sorted(od.destination.unique().tolist()),aggregate_or_self_rows_excluded=len(bad),output=outpath,dimension_values={c:df[c].dropna().unique().tolist() for c in ['agedef','age','nace_r2','entity','indic_sbs'] if c in df})
 summaries.append(summary)
 urls=[]
 for _,row in links.iterrows():
  vals=[str(v) for v in row.tolist()]
  if any(source_id+('_refresh' if REFRESH else '')==v for v in vals):urls+=[v for v in vals if v.startswith('http')]
 if not urls:
  urls=['https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/'+dataset]
 manifests.append(dict(source_id=source_id,dataset=dataset,source_url=' | '.join(urls),access='free_no_api_key',snapshot=SNAPSHOT,input_csv=str(p.relative_to(ROOT)).replace('\\','/'),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),rows=len(df),observed=int(df.value.notna().sum()),min_year=int(df.year.min()),max_year=int(df.year.max()),download_date='see_inputs/mechanisms_20261102/flows/SOURCE_MANIFEST.csv' if REFRESH else 'see_inputs/base/download_manifest.csv',build_utc=datetime.datetime.now(datetime.timezone.utc).isoformat()))
 print(source_id,len(od),'OD rows',int(od.value.notna().sum()),'observed',flush=True)
 # Incremental summary makes a partially completed build explicit and reviewable.
 dump(dict(status='building',sources=summaries),'summary.json')

save(pd.concat(excluded,ignore_index=True,sort=False),'excluded_aggregate_and_self_rows.csv')
save(pd.concat(duplicates,ignore_index=True,sort=False),'native_duplicate_keys.csv')
save(pd.concat(coverage,ignore_index=True,sort=False),'coverage_by_year_dimension.csv')
save(pd.DataFrame(join_audits),'join_coverage_audit.csv')
save(pd.DataFrame(covariate_audits),'covariate_missingness_by_side.csv')
save(pd.DataFrame([dict(raw_code=k,normalized_code=v,scope_note='mainland China excluding Hong Kong; raw scope retained' if k=='CN_X_HK' else 'Eurostat to ISO code normalization') for k,v in MAP.items()]),'country_code_crosswalk.csv')
totals=pd.concat(countryrows,ignore_index=True,sort=False)
save(totals,'source_reported_country_aggregates_with_covariates.csv')
# Two reporting systems can disagree. Keep both; diagnostic mirror comparison is not imputation.
mirror_summaries=[]
for prefix,extra in [('migration',['age','agedef','unit','sex']),('fdi',['nace_r2','entity','currency'])]:
 ins=panels['migration_inward' if prefix=='migration' else 'fdi_inward_j']
 outs=panels['migration_outward' if prefix=='migration' else 'fdi_outward_j']
 keys=['origin','destination','year']+extra
 m=ins[keys+['value','status']].rename(columns={'value':'inward_reported_value','status':'inward_status'}).merge(outs[keys+['value','status']].rename(columns={'value':'outward_reported_value','status':'outward_status'}),on=keys,how='outer',validate='one_to_one',indicator='reporting_frame_presence')
 m['both_observed']=m.inward_reported_value.notna()&m.outward_reported_value.notna()
 m['inward_minus_outward']=m.inward_reported_value-m.outward_reported_value
 m['absolute_gap']=m.inward_minus_outward.abs()
 save(m,prefix+'_mirror_diagnostics.csv')
 ms=dict(measure=prefix,comparison_rows=len(m),both_observed=int(m.both_observed.sum()),inward_only_observed=int((m.inward_reported_value.notna()&m.outward_reported_value.isna()).sum()),outward_only_observed=int((m.outward_reported_value.notna()&m.inward_reported_value.isna()).sum()),both_missing=int((m.inward_reported_value.isna()&m.outward_reported_value.isna()).sum()),unequal_when_both_observed=int((m.both_observed&m.inward_minus_outward.ne(0)).sum()))
 mirror_summaries.append(ms)
save(pd.DataFrame(mirror_summaries),'mirror_summary.csv')

# A simple country-year left join using only reported TOTAL/WRL_REST, and
# preserving each age definition, entity scope and activity group in its name.
wideparts=[]
for src,frame in totals.groupby('source_id'):
 for _,r in frame.iterrows():
  if src.startswith('migration') and r.aggregate_partner_code!='TOTAL':continue
  if src.startswith('fdi') and r.aggregate_partner_code!='WRL_REST':continue
  if src.startswith('foreign') and r.aggregate_partner_code!='WRL_REST':continue
  dim=['age','agedef'] if src.startswith('migration') else ['nace_r2','entity'] if src.startswith('fdi') else ['nace_r2','indic_sbs']
  name='flow_'+src+'_'+'_'.join(str(r[c]) for c in dim)+'_'+r.aggregate_partner_code
  wideparts.append(dict(country_iso2_normalized=r.reporter,year=r.year,series=name,value=r.value,status=r.status))
wr=pd.DataFrame(wideparts)
assert not wr.duplicated(['country_iso2_normalized','year','series']).any()
wv=wr.pivot(index=['country_iso2_normalized','year'],columns='series',values='value').reset_index()
ws=wr.pivot(index=['country_iso2_normalized','year'],columns='series',values='status').add_suffix('_status').reset_index()
wv=wv.merge(ws,on=['country_iso2_normalized','year'],validate='one_to_one')
joined=main.merge(wv,on=['country_iso2_normalized','year'],how='left',validate='one_to_one')
assert len(joined)==len(main)
save(joined,'combined_country_year_with_reported_flows.csv')
joincheck=pd.DataFrame([dict(check='base_country_year_key_unique',passed=len(base_dups)==0,value=len(base_dups)),dict(check='country_year_left_join_preserves_rows',passed=len(joined)==len(main),value=len(joined)),dict(check='base_country_codes_mapped',passed=main.country_iso2_normalized.notna().all(),value=int(main.country_iso2_normalized.isna().sum())),dict(check='source_native_keys_unique',passed=True,value=0),dict(check='no_selected_partner_sums_as_totals',passed=True,value=0)])
save(joincheck,'join_checks.csv')

# The already collected 2024/UK-origin slice validates freshness separately.
fresh=ROOT/'inputs/mechanisms_20261102/flows/network_probe_imm_uk_2024.json'
fresh_summary={'status':'not_available','new_data_merged_into_base':False}
if fresh.exists():
 j=json.loads(fresh.read_text(encoding='utf-8-sig'));ids=j['id'];cats=[]
 for k in ids:
  ix=j['dimension'][k]['category']['index'];cats.append([a for a,b in sorted(ix.items(),key=lambda z:z[1])] if isinstance(ix,dict) else ix)
 vals=j.get('value',{});flags=j.get('status',{})
 def get(x,i):return x.get(str(i)) if isinstance(x,dict) else (x[i] if i<len(x) else None)
 freshdf=pd.DataFrame([dict(zip(ids,t),value=get(vals,i),status=get(flags,i)) for i,t in enumerate(itertools.product(*cats))])
 save(freshdf,'fresh_2024_uk_origin_migration_slice.csv')
 old=pd.read_csv(BASE/'migration_inward.csv',keep_default_na=False,na_values=[''])
 keys=[c for c in ids if c in old]
 old=old[old.partner.eq('UK')&old.time.eq(2024)&old.age.eq('TOTAL')].copy()
 for c in keys:old[c]=old[c].astype(str);freshdf[c]=freshdf[c].astype(str)
 check=freshdf.merge(old,on=keys,how='outer',suffixes=('_fresh','_base'),indicator=True,validate='one_to_one')
 check['value_difference']=pd.to_numeric(check.value_fresh,errors='coerce')-pd.to_numeric(check.value_base,errors='coerce')
 check['both_observed']=check.value_fresh.notna()&check.value_base.notna()
 save(check,'fresh_slice_vs_base_validation.csv')
 fresh_summary=dict(status='downloaded_and_validated',rows=len(freshdf),observed=int(freshdf.value.notna().sum()),source_updated=j.get('updated'),both_observed=int(check.both_observed.sum()),changed_observed_values=int((check.both_observed&check.value_difference.ne(0)).sum()),fresh_only_dimension_rows=int(check._merge.eq('left_only').sum()),base_only_dimension_rows=int(check._merge.eq('right_only').sum()),new_data_merged_into_base=False)
 manifests.append(dict(source_id='fresh_2024_uk_origin_migration_slice',dataset='migr_imm5prv',source_url='https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/migr_imm5prv?lang=en&time=2024&sex=T&unit=NR&age=TOTAL&partner=UK',access='free_no_api_key',snapshot='fresh_validation_only',input_csv=str(fresh.relative_to(ROOT)).replace('\\','/'),sha256=hashlib.sha256(fresh.read_bytes()).hexdigest(),rows=len(freshdf),observed=int(freshdf.value.notna().sum()),min_year=2024,max_year=2024,download_date=datetime.datetime.fromtimestamp(fresh.stat().st_mtime,datetime.timezone.utc).isoformat(),build_utc=datetime.datetime.now(datetime.timezone.utc).isoformat()))
save(pd.DataFrame(manifests),'SOURCE_MANIFEST.csv')

dictionary=[
 ('origin / destination','Normalized ISO alpha-2 country/economy. EL→GR, UK→GB. FATS CN_X_HK→CN retains raw code and explicit scope.'),
 ('origin_code_raw / destination_code_raw','Original Eurostat geographic code, retained without substitution.'),
 ('migration inward direction','Previous residence partner → reporting country geo; people of any occupation. Does not identify skilled/ICT workers.'),
 ('migration outward direction','Reporting country geo → next-residence partner. Separate mirror report, not added to inward reports.'),
 ('FDI inward / outward direction','Partner → reporting country for inward; reporter → partner for outward. Net financial flow in million EUR, not company relocations.'),
 ('FATS direction','Country of ultimate control c_ctrl → host geo. EMP_NR/ENT_NR annual affiliate activity counts, AV_MEUR annual value added; not new entries or migration.'),
 ('agedef','REACH: age reached during reference year; COMPLET: age in completed years. Keep separate, never sum or silently pool.'),
 ('age','TOTAL all ages versus Y15-64 age 15–64; TOTAL includes the age subset, so do not add them.'),
 ('entity','TOTAL and SPE are separate source entity scopes. SPE is not an additional component to add to TOTAL; no subtraction/adjustment applied.'),
 ('nace_r2','J information and communication; J58_J62_J63 publishing, computer programming/consultancy and information services; J61 telecom; J62_J63 computer programming/consultancy and information services. Overlapping activity scopes remain separate.'),
 ('value','Original numeric observation. Blank means missing, confidential, unavailable or not reported as indicated by status. Observed zero retained; negative FDI retained.'),
 ('status','Verbatim Eurostat source status. Blank flag does not imply that a blank value is zero.'),
 ('origin_* / destination_* covariates','Many-to-one country-year joins to existing combined_country_year. Flags accompany selected source measures; no extrapolation or imputation.'),
 ('*_join_status','matched_country_year, country_outside_base_panel, year_outside_base_panel, missing_country_year_in_base, or unmapped_country_code. A matched key can still have a missing covariate.'),
 ('*_fixed_eu27 / *_sample_eu27','Fixed current EU27 analytical composition. Never interpreted as historical EU membership or DMA treatment.'),
 ('*_eu_membership_status_year','Historical broad membership descriptor. UK member_full_year 2017–2019, uk_withdrawal_transition_year 2020, non_member thereafter. Does not encode regulation exposure.'),
 ('aggregate_partner_code','Source-reported TOTAL, WRL_REST, WORLD and other aggregate codes remain distinct. No partial partner sums are country totals.'),
 ('flow_* wide columns','Only source-native TOTAL migration and WRL_REST FDI/FATS rows, each dimension and aggregate code separately named; same snapshot as input. FATS WORLD is total economy including domestic control, not foreign-only.'),
 ('reporting_frame_presence / mirror diagnostics','Outer comparison of same origin-destination-year and measurement dimensions across reporting directions. Gaps are not causal outcomes or corrected values.'),
 ('source_snapshot','existing_base_actual_csv = frozen cached input; fresh_eurostat_20261102 = five newly downloaded datasets in separate fresh folder. No source snapshots are mixed. One-cut validation remains separate.'),
]
save(pd.DataFrame(dictionary,columns=['variable_or_concept','definition']),'data_dictionary.csv')
plotfiles=[]
try:
 import matplotlib;matplotlib.use('Agg')
 import matplotlib.pyplot as plt
 fig,ax=plt.subplots(figsize=(9,5))
 for src in ['migration_inward','migration_outward','fdi_inward_j','fdi_outward_j','foreign_affiliates_j']:
  x=panels[src].copy()
  if src.startswith('migration'):x=x[x.age.eq('Y15-64')&x.agedef.eq('COMPLET')]
  if src.startswith('fdi'):x=x[x.nace_r2.eq('J')&x.entity.eq('TOTAL')]
  if src.startswith('foreign'):x=x[x.nace_r2.eq('J')&x.indic_sbs.eq('EMP_NR')]
  c=x.groupby('year').value.apply(lambda s:s.notna().mean()*100)
  ax.plot(c.index,c.values,marker='o',label=src)
 ax.set(title='Observed share within selected country-dyad frames',xlabel='Year',ylabel='Observed observations (%)',ylim=(0,100));ax.legend(fontsize=8);ax.grid(alpha=.2)
 fig.text(.02,.01,'Missing values retained. Frames differ by source; no totals or causal effects shown.',fontsize=8);fig.tight_layout(rect=(0,.04,1,1))
 fig.savefig(OUT/'01_od_coverage.png',dpi=150);plt.close(fig);plotfiles.append('01_od_coverage.png')
 f=panels['fdi_inward_j'];f=f[f.nace_r2.eq('J')&f.entity.eq('TOTAL')]
 counts=f.groupby('year').value.apply(lambda s:pd.Series({'negative':s.lt(0).sum(),'zero':s.eq(0).sum(),'positive':s.gt(0).sum(),'missing':s.isna().sum()})).unstack()
 fig,ax=plt.subplots(figsize=(9,5));counts.plot.bar(stacked=True,ax=ax,color=['#c45a51','#b7b7b7','#408caa','#e8e8e8'])
 ax.set(title='Inward FDI, information and communication: observation states',xlabel='Year',ylabel='Selected international dyad observations');ax.tick_params(axis='x',rotation=0)
 fig.text(.02,.01,'NACE J, TOTAL entity scope. Negative net financial flows are retained, not recoded.',fontsize=8);fig.tight_layout(rect=(0,.04,1,1));fig.savefig(OUT/'02_fdi_value_states.png',dpi=150);plt.close(fig);plotfiles.append('02_fdi_value_states.png')
except Exception as e:dump({'plot_error':str(e)},'plot_error.json')

summary=dict(status='complete',source_snapshot=SNAPSHOT,created_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),no_causal_models_run=True,base_country_year_rows=len(main),joined_country_year_rows=len(joined),base_country_year_columns=len(main.columns),joined_country_year_columns=len(joined.columns),base_years=sorted(baseyears),base_countries=sorted(basecountries),sources=summaries,mirror_diagnostics=mirror_summaries,fresh_validation=fresh_summary,plots=plotfiles,limitations=['Migration is not occupation-specific; working-age is not skilled migration.','FDI net financial flows do not identify firm relocation and may be negative.','FATS annual stocks/activity/value added are not establishment entry flows.','Selected partner frame differs by source; never sum it as a country total.','Fixed EU27 sample is not historical membership or DMA treatment.','No new digital regulation exposure variable was inferred from EU membership.','Matched country-year keys can have missing original covariates.','Fresh validation slice is not merged into frozen source panels.','Fresh scope is broader in migration/FDI partner countries but narrower in activity (J only); do not interpret raw observation-count differences as economic changes.'],output_files=sorted(p.name for p in OUT.iterdir() if p.is_file()))
dump(summary,'summary.json')
print('COMPLETE',OUT,'country-year rows',len(joined),flush=True)
