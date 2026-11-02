from pathlib import Path
import json
import pandas as pd
R=Path(__file__).resolve().parents[1]
F=R/'outputs/mechanisms_20261102/flows/fresh'
s=json.loads((F/'summary.json').read_text(encoding='utf8'))
assert s['status']=='complete'
main=pd.read_csv(R/'outputs/combined_country_year.csv')
joined=pd.read_csv(F/'combined_country_year_with_reported_flows.csv')
pd.testing.assert_frame_equal(main,joined[main.columns],check_dtype=False)
checks=[dict(check='all_73_existing_columns_unchanged',passed=True,rows=len(main))]
for name in ['migration_inward','migration_outward','fdi_inward','fdi_outward','fats_inward_control']:
 p=F/(name+'_od.csv');d=pd.read_csv(p,low_memory=False)
 assert d.origin.notna().all() and d.destination.notna().all()
 assert d.origin.ne(d.destination).all()
 assert d.source_snapshot.eq('fresh_eurostat_20261102').all()
 for side in ['origin','destination']:
  matched=d[d[side+'_join_status'].eq('matched_country_year')]
  n=matched[side+'_country'].replace({'EL':'GR','UK':'GB'})
  assert matched[side].eq(n).all()
  uk=d[(d[side]=='GB')&(d.year<=2019)]
  assert uk[side+'_fixed_eu27'].eq(0).all()
  assert uk[side+'_eu_membership_status_year'].eq('member_full_year').all()
  uk2020=d[(d[side]=='GB')&(d.year==2020)]
  assert uk2020[side+'_eu_membership_status_year'].eq('uk_withdrawal_transition_year').all()
 checks.append(dict(check=name+'_direction_country_keys_snapshot_and_UK_history',passed=True,rows=len(d)))
pd.DataFrame(checks).to_csv(F/'final_value_preservation_checks.csv',index=False,encoding='utf-8-sig')
s['final_qa']={'all_original_73_columns_unchanged':True,'normalized_join_keys_match':True,'no_self_dyads':True,'uk_historical_membership_separate_from_fixed_eu27':True,'checks_file':'final_value_preservation_checks.csv'}
s['output_files']=sorted(p.name for p in F.iterdir() if p.is_file())
(F/'summary.json').write_text(json.dumps(s,ensure_ascii=False,indent=2),encoding='utf-8')
aud=pd.read_csv(F/'join_coverage_audit.csv')
print(aud[aud.status.ne('matched_country_year')].to_string(index=False),flush=True)
print(pd.read_csv(F/'mirror_summary.csv').to_string(index=False),flush=True)
print('QA PASS: all original country-year columns unchanged, normalized join keys exact, international dyads only, snapshot labels and UK history valid',flush=True)
