"""Independent checks of the requested extension; does not change fitted results."""
from pathlib import Path
import json,hashlib,math
import numpy as np
import pandas as pd
def binomial_bounds(s,n):
 def solve(k,target):
  ix=np.arange(k+1);logc=np.array([math.lgamma(n+1)-math.lgamma(i+1)-math.lgamma(n-i+1) for i in ix])
  lo,hi=0.,1.
  for _ in range(60):
   p=(lo+hi)/2;v=logc+ix*np.log(p)+(n-ix)*np.log1p(-p);m=v.max();cdf=np.exp(m)*np.exp(v-m).sum()
   if cdf>target:lo=p
   else:hi=p
  return (lo+hi)/2
 return solve(s-1,.975) if s else 0.,solve(s,.025) if s<n else 1.
P=Path(__file__).resolve().parent; O=P/'outputs'; M=O/'migration_extension'
checks=[]
def ck(label,value,detail=''):
 if not bool(value):raise AssertionError(label+': '+str(detail))
 checks.append(dict(check=label,passed=True,detail=detail))
def rd(n):return pd.read_csv(O/n)
old=pd.read_csv(P/'reference/v3/regional_model_comparison.csv').set_index('model')
new=rd('regional/model_comparison.csv').set_index('model')
cols=['n','AICc','spatial_parameter','innovation_I','logLik']
ck('Regional point estimates unchanged',np.allclose(old[cols],new[cols],rtol=0,atol=1e-12))
b=rd('regional_sdm_bootstrap_extended_draws.csv');cmp=rd('regional_sdm_bootstrap_comparison.csv')
ck('9999 finite refits',len(b)==9999 and np.isfinite(b[['I','parameter']]).all().all())
for r in cmp.itertuples():
 vals=b.I.to_numpy()[:int(r.simulations)];tail=min(np.sum(vals<=r.I),np.sum(vals>=r.I))
 p=min(1,2*(tail+1)/(len(vals)+1));ci=binomial_bounds(int(tail),len(vals))
 ck(f'Bootstrap p and binomial bounds B={r.simulations}',abs(p-r.p_bootstrap)<1e-12 and abs(2*ci[0]-r.MC_lower)<1e-9 and abs(2*ci[1]-r.MC_upper)<1e-9)
ck('B199 result reproduced',cmp.iloc[0].p_bootstrap==0.07)
ck('B9999 result',cmp.iloc[-1].p_bootstrap==0.0526)
ml=rd('regional_refinement_ML_validation.csv')
ck('Independent spatialreg refits',ml.logLik_difference.max()<1e-6 and ml.rho_difference.max()<1e-4)
d=rd('migration_extension/migration_europe_2024.csv')
ck('43 unique country keys',len(d)==43 and d.country.nunique()==43)
ck('34 basic / 35 supplemented rates',d.rate_all_ages.notna().sum()==34 and d.rate_all_ages_plus_PT.notna().sum()==35)
ck('All observed countries have geometry',d.loc[d.rate_all_ages_plus_PT.notna(),'geometry_present'].all())
ck('Geometry exception recorded',set(d.loc[~d.geometry_present,'country'])=={'XK'})
uk=d.set_index('country').loc['UK']
ck('UK gross immigration rate',abs(uk.rate_all_ages-1012000/69256300*1000)<1e-10 and pd.isna(uk.rate_complet))
pt=rd('migration_extension/portugal_revision_audit.csv').iloc[0]
ck('PT revised source vintage retained',pt.immigration_all_ages==394904 and pt.immigration_15_64==324243 and pt.population_total_mean==(11204347+11387222)/2)
ck('PT harmonised columns not overwritten',pd.isna(d.set_index('country').loc['PT','rate_all_ages']))
for name in ['complet','reach']:
 v=1000*d['immigration_'+name]/d.population_15_64_mean
 ck(name+' rate recomputation',np.allclose(v,d['rate_'+name],equal_nan=True,rtol=1e-12))
src=rd('migration_extension/v3_source_comparison.csv')
ck('Overlap with v3 is unchanged',np.nanmax(np.abs(src.iloc[:,1:].to_numpy()))==0)
cross=rd('migration_extension/cross_dataset_checks.csv')
ck('Cross-dataset numerator agreement',np.nanmax(np.abs(cross.filter(like='difference').to_numpy()))==0)
mor=rd('migration_extension/migration_moran_tests.csv')
ck('Eight scope by three k choices',len(mor)==24 and set(mor.k)=={3,4,5})
for s,r in mor[mor.k==4].set_index('sample').iterrows():
 a=pd.read_csv(M/f'sample_{s}.csv');w=pd.read_csv(M/f'weights_{s}.csv');W=w.iloc[:,1:].to_numpy()
 ck(s+' W row order',a.id.tolist()==w.id.tolist()==list(w.columns[1:]))
 xy=a[['x_m','y_m']].to_numpy();dist=np.sqrt(((xy[:,None,:]-xy[None,:,:])**2).sum(axis=2));np.fill_diagonal(dist,np.inf)
 A=np.zeros_like(dist);ii=np.argsort(dist,axis=1)[:,:4];A[np.arange(len(a))[:,None],ii]=1;A=np.maximum(A,A.T);W2=A/A.sum(axis=1,keepdims=True)
 ck(s+' independently reconstructed W',np.allclose(W,W2,atol=1e-12,rtol=0))
 z=a.outcome.to_numpy()-a.outcome.mean();I=len(z)/W.sum()*(z@W@z)/(z@z)
 ck(s+' independently recomputed Moran I',abs(I-r.I)<1e-12)
 # A separate RNG gives a statistically comparable, not bit-for-bit identical, permutation p.
 rng=np.random.default_rng(20261102);perm=np.array([rng.permutation(z) for _ in range(19999)])
 sim=np.einsum('ij,ij->i',perm@W,perm)/np.dot(z,z)
 tail=min(np.sum(sim<=I),np.sum(sim>=I));p2=min(1,2*(tail+1)/20000)
 ck(s+' independent permutation check',abs(p2-r.p)<.04,dict(R_p=float(r.p),Python_p=float(p2),B_python=19999))
man=pd.read_csv(P/'inputs/extension_20261102/SOURCE_MANIFEST.csv')
for row in man.itertuples():
 ck('Source hash '+Path(row.file).name,hashlib.sha256((P/row.file).read_bytes()).hexdigest()==row.sha256)
for scope in ['country','regional']:
 a=rd(f'lta_design/{scope}_waves_2021_2024.csv')
 cols=['ict_share_pct','employment_na_j_share_pct','unemployment_pct'] if scope=='country' else ['regional_j_share_pct','tertiary_pct','log_regional_gdp_pc_pps']
 ck(scope+' LTA unique unit-wave keys',not a.duplicated(['id','year']).any() and set(a.year)=={2021,2022,2023,2024})
 complete=a[cols].notna().all(axis=1)
 ck(scope+' LTA missingness flags',np.array_equal(complete,a.complete_indicators))
 sm=rd('lta_design/panel_summary.csv').set_index('scope').loc[scope]
 nbalanced=int(complete.groupby(a.id).sum().eq(4).sum())
 ck(scope+' LTA counts',sm.unique_units==a.id.nunique() and sm.complete_rows==int(complete.sum()) and sm.balanced_units==nbalanced and not sm.latent_model_fitted)
 for y in [2021,2022,2023]:
  x=a[a.year==y].set_index('id').complete_indicators;z=a[a.year==y+1].set_index('id').complete_indicators
  expected=int((x&z).sum());obs=rd('lta_design/transition_pair_coverage.csv');obs=obs[(obs.scope==scope)&(obs.from_year==y)].iloc[0]
  ck(f'{scope} LTA observable pair {y}',expected==obs.complete_pairs)
for i in range(13,21):
 ck(f'Plot {i} PNG/PDF exists',len(list((P/'figures').glob(f'{i:02d}_*.png')))==1 and len(list((P/'figures').glob(f'{i:02d}_*.pdf')))==1)
report=P/'DMA_PoC_v4_Report.html'
if report.exists():
 t=report.read_text(encoding='utf-8');ck('Report embedded figures and updated values',t.count('data:image/png;base64,')==9 and '0.0526' in t and 'EUROPE42_2024' in t and '205' in t)
result=dict(status='PASS',checks_passed=len(checks),checks=checks)
(O/'v4_validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(status='PASS',checks_passed=len(checks)),ensure_ascii=False))
