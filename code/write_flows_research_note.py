"""Finalize researcher notes and a compact cross-snapshot audit after both builds."""
from pathlib import Path
import json
import pandas as pd
R=Path(__file__).resolve().parents[1]
O=R/'outputs/mechanisms_20261102/flows'
F=O/'fresh'
old=json.loads((O/'summary.json').read_text(encoding='utf-8'))
new=json.loads((F/'summary.json').read_text(encoding='utf-8'))
assert old['status']=='complete' and new['status']=='complete','Both snapshots must be complete first'
def link(label,p):return f'[{label}]({p.as_posix()})'
def csvtable(s):
 rows=['| 자료 | 원자료 행 | 국제 OD 행 | 관측값 | 결측값 | 0 | 음수 | 연도 |','|---|---:|---:|---:|---:|---:|---:|---|']
 for a in s['sources']:
  rows.append(f"| {a['source_id']} | {a['source_rows']:,} | {a['od_rows']:,} | {a['od_observed']:,} | {a['od_missing']:,} | {a['od_observed_zeros']:,} | {a['od_negative_values']:,} | {min(a['years'])}–{max(a['years'])} |")
 return '\n'.join(rows)
comparison=[]
for a,b in zip(old['sources'],new['sources']):
 comparison.append(dict(source_id=a['source_id'],base_raw_rows=a['source_rows'],fresh_raw_rows=b['source_rows'],base_od_rows=a['od_rows'],fresh_od_rows=b['od_rows'],base_observed=a['od_observed'],fresh_observed=b['od_observed'],scope_comparable=False,note='Selected reporting/partner and activity frames differ; counts are not economic changes.'))
pd.DataFrame(comparison).to_csv(O/'snapshot_scope_comparison.csv',index=False,encoding='utf-8-sig')
checks=pd.read_csv(F/'join_checks.csv')
assert checks.passed.all()
aud=pd.read_csv(F/'join_coverage_audit.csv')
nonmatched=aud[aud.status.ne('matched_country_year')]
joinlines='\n'.join(f"- `{r.source_id}` {r.side}: {int(r.rows):,}행, 사유 `{r.status}`, 국가 {r.countries}." for r in nonmatched.itertuples())
mir=pd.read_csv(F/'mirror_summary.csv')
mirrorlines='\n'.join(f"- {r.measure}: 동일 차원에서 양쪽 값이 모두 있는 {int(r.both_observed):,}행 중 {int(r.unequal_when_both_observed):,}행의 값이 달랐다. 단방향만 관측된 행은 inward {int(r.inward_only_observed):,}, outward {int(r.outward_only_observed):,}개다." for r in mir.itertuples())
tot=sum(x['od_rows'] for x in new['sources']);obs=sum(x['od_observed'] for x in new['sources'])
note=f'''# 국제 기업·투자·인적 이동: 실제 무료 수집자료와 DMA PoC 연결

## 1. 무료로 확보한 자료는 무엇이며 실제 관측 범위는 어디까지인가?

### Takeaway
새로 내려받은 Eurostat 5개 CSV를 모두 사용해 {tot:,}행의 국제 국가쌍-연도-측정차원 패널을 만들었고, 그중 수치가 관측된 행은 {obs:,}개다. 기존 CSV 재현본과 신규 스냅샷은 폴더를 나눠 보존했으며 한 패널 안에서 섞지 않았다. — {link('신규 실행 요약',F/'summary.json')}; {link('신규 API·해시 매니페스트',F/'SOURCE_MANIFEST.csv')}

### Cited Findings
신규 스냅샷의 실제 크기는 다음과 같다. 빈 값도 행으로 보존하며, 표의 행수에는 연령 범주·연령 정의·SPE 범주가 각각 들어 있으므로 사람 수나 기업 수를 뜻하지 않는다. — {link('신규 summary',F/'summary.json')}; {link('차원별 커버리지',F/'coverage_by_year_dimension.csv')}

{csvtable(new)}

- 수집 지표는 `migr_imm5prv` 이전 거주국별 이민, `migr_emi3nxt` 다음 거주국별 이출, `bop_fdi6_flow` 유입/유출 직접투자 금융흐름, `fats_activ` 해외통제기업 활동이다. 자료는 무료 공개 API에서 확보했다. 실제 요청 URL·파일 SHA256·관측기간·관측값 수를 저장했다. — {link('수집 로그',R/'inputs/mechanisms_20261102/flows/SOURCE_MANIFEST.csv')}; {link('분석 매니페스트',F/'SOURCE_MANIFEST.csv')}
- 이민의 분류는 연령·성별·이전/다음 거주국이며, 직업이나 ICT 숙련 여부를 식별하지 않는다. 단위는 명이고 연간 이동이다. — [Eurostat migration metadata](https://ec.europa.eu/eurostat/cache/metadata/en/migr_immi_esms.htm)
- FDI는 순자산 취득·처분 등 금융거래이며 원자료의 음수 관측을 그대로 보존했다. 지리적 상대방은 기본적으로 직접적인 투자 상대방이다. 업종 배분도 inward/outward에서 완전히 대칭적이지 않을 수 있다. — [Eurostat FDI metadata](https://ec.europa.eu/eurostat/cache/metadata/en/bop_fdi6_esms.htm); {link('FDI 신규 패널',F/'fdi_inward_od.csv')}
- FATS는 최종통제주체 소재국과 현지 사업체 활동의 관계다. 기업수·취업자수와 연간 부가가치를 구별했으며 신규 진입 기업수 또는 이전 기업수로 해석하지 않는다. `WORLD`에는 국내통제 기업도 포함될 수 있어, foreign-only 국가집계에는 원자료의 `WRL_REST`를 사용했다. — [Eurostat FATS metadata](https://ec.europa.eu/eurostat/cache/metadata/en/fats_sims.htm); {link('집계 코드가 보존된 국가자료',F/'source_reported_country_aggregates_with_covariates.csv')}
- 별도로 내려받은 2024년 UK 이전거주국·전체연령 컷은 96행, 수치 관측 36개다. 기존 자료와 양쪽 수치가 모두 있는 36개는 동일했고, 새 컷에만 존재하는 차원 조합은 32행이었다. 이는 본 패널의 연령·국가 범위와 별도로 검증했으며 원자료를 덮어쓰지 않았다. — {link('신규 단면 대조표',F/'fresh_slice_vs_base_validation.csv')}

### Inferences
- 신규 다운로드는 특정 서비스의 준수행동에 이어 국가 간 움직임을 추적할 수 있는 보조 결과변수들을 제공한다. 다만 이동·투자·기업활동은 서로 다른 측정 대상이므로 하나의 '기업/인재 유출 지수'로 합치기보다 별도 결과변수로 설계하는 편이 타당하다.
- 새 자료의 관측 행수 변화는 경제적 변화가 아니다. 기존 FDI는 J 외 하위 업종도 포함했고, 신규 FDI/FATS 요청은 J에 집중했으며 국가·상대국 범위는 넓어졌다. 원자료 차원과 표본 범위를 맞춘 뒤에만 수치 비교가 가능하다.

### Gaps
- 이 패널로 특정 게이트키퍼의 사업체 이전, 특정 직원의 이직, 숙련 인재의 이동을 직접 식별할 수 없다. 국가·업종 집계자료와 공개 기업 사례를 연결하는 별도 식별 설계가 필요하다.
- 2025까지 요청했지만 실물 CSV에서 반환된 연도만 사용했다. 아직 관측되지 않은 연도를 0으로 생성하지 않았다.
- 기본 실행환경에 matplotlib가 없어 이 builder의 PNG 단계는 생략되었다. 통합 보고서 담당자가 R 기반 기술그림을 생성하며, 데이터 산출과 검증은 완료 상태다.

## 2. 기존 국가연도 PoC와 어떻게 연결했고 어떤 품질 점검을 통과했는가?

### Takeaway
신규 자료는 origin과 destination 각각에 기존 `combined_country_year.csv`의 국가연도 공변량을 many-to-one으로 연결했다. 국가별 원자료 총계만 뽑은 별도 left join은 기존 {new['base_country_year_rows']:,}행을 정확히 유지하며 {new['joined_country_year_columns']:,}열이다. — {link('신규 국가연도 결합본',F/'combined_country_year_with_reported_flows.csv')}; {link('결합 검증',F/'join_checks.csv')}

### Cited Findings
- 방향은 migration/FDI inward에서 partner→geo, outward에서 geo→partner이며 두 보고 방향을 별도로 저장했다. FATS는 c_ctrl→geo다. `EL→GR`, `UK→GB`를 정규화하고 원코드를 보존했다. FATS `CN_X_HK→CN`은 홍콩 제외 범위를 별도 표시했다. — {link('변수사전',F/'data_dictionary.csv')}; {link('국가코드 대응표',F/'country_code_crosswalk.csv')}
- 지역집계 상대방과 동일국가 행은 국제 국가쌍에서 제외하고 별도 감사 파일에 남겼다. 일부 파트너만 모은 합계는 국가총계로 사용하지 않았다. migration은 TOTAL, FDI/FATS는 WRL_REST의 원자료 보고 총계만 wide 결합에 썼다. 원자료의 다른 집계도 코드와 함께 별도 보존했다. — {link('제외행 감사',F/'excluded_aggregate_and_self_rows.csv')}; {link('원자료 국가집계',F/'source_reported_country_aggregates_with_covariates.csv')}
- 원자료의 전체 측정차원 키와 기존 국가연도 키는 중복 0개다. 왼쪽 결합 행수 불변과 유일성 검사를 통과했다. 0과 결측을 구분하고, 음수 FDI 및 음수 부가가치를 임의로 제거하지 않았다. — {link('키 검증',F/'join_checks.csv')}; {link('원자료 중복 감사',F/'native_duplicate_keys.csv')}; {link('신규 요약',F/'summary.json')}
- `REACH`와 `COMPLET` 연령 정의를 구분하고 TOTAL과 Y15-64를 합산하지 않았다. FDI의 TOTAL과 SPE, 중첩 NACE 업종도 합산하지 않았다. — {link('변수사전',F/'data_dictionary.csv')}
- 결합되지 않은 행의 사유는 코드 미인식, 기존 표본 외 국가, 기존 표본 외 연도, 국가연도 행 부재로 분리할 수 있도록 각 OD행에 저장했다. 실제 비매칭 요약은 다음과 같다. — {link('결합 커버리지 감사',F/'join_coverage_audit.csv')}

{joinlines}

- 키가 연결돼도 원래 GDP·노동비용·ICT 지표가 비어 있을 수 있다. 이를 결합 실패로 세지 않고 변수별 별도 결측 감사로 저장했다. — {link('공변량 결측 감사',F/'covariate_missingness_by_side.csv')}
- inward/outward는 동일 origin-destination-year와 측정차원으로 비교하되 값을 평균내거나 빈 값을 상대 방향으로 메우지 않았다. 아래 차이는 보고 통계의 비대칭 진단이며 이동을 두 번 더하는 근거가 아니다. — {link('mirror 진단 요약',F/'mirror_summary.csv')}

{mirrorlines}

### Inferences
- 기존 표본에 없는 국제 비교국의 공변량이 비는 것은 코드 오류와 다르다. 국제적 확장을 본격화하려면 같은 정의의 공변량을 추가 수집하거나 사전에 정한 공통표본 분석을 해야 한다.
- 연령 정의에 따라 한 나라가 한 방식만 보고하는 경우, 전체 격자의 결측 비율은 통계 시스템 구조도 반영한다. 모든 빈 셀을 같은 의미의 미보고 또는 실질적 이동 부재로 해석하면 안 된다.
- inward 통계를 주 결과로 선택하고 outward를 측정오차·민감도 검증용 mirror로 두는 설계가 가능하나, 이는 이번에 추정한 결론이 아니라 후속 설계 제안이다.

### Gaps
- 공변량이 누락된 국제 비교국에 수치를 대입하거나 이웃 국가 값으로 보간하지 않았다.
- 원자료 flag와 결측만으로 기밀·미보고·비적용 사유를 완전히 복원할 수 없는 행은 남아 있다. 국별 metadata 검토가 필요한 제한으로 기록한다.

## 3. DMA 규범 확산 연구에 무엇을 사용할 수 있고 어떤 해석을 피해야 하는가?

### Takeaway
자료 구축과 기술 점검만 수행했고 새로운 인과 회귀는 실행하지 않았다. 고정 EU27 표본분류·역사적 회원국 상태·서비스별 규제노출을 서로 구분하며, EU 더미로 신규 디지털규제 처치를 생성하지 않았다. — {link('실행 요약과 제한',F/'summary.json')}; {link('변수사전',F/'data_dictionary.csv')}

### Cited Findings
- 기존 `sample_eu27`와 새 `*_fixed_eu27`는 고정 EU27 구성이다. 별도 역사 구분에는 UK 2017–2019 full-year member, 2020 withdrawal/transition year, 이후 non-member를 표시해 과거를 현재 구성으로 덮어쓰지 않았다. 이 열들은 규제 처치 변수가 아니다. — {link('변수사전',F/'data_dictionary.csv')}; {link('신규 이동 OD 패널',F/'migration_inward_od.csv')}
- 기존 사전 ICT 노출도·정보통신업 고용비중·GDP·노동비용·실업률·인구와 선택한 원래 flag를 양쪽 국가에 결합했다. 새 규제변수나 처치×사후 계수는 만들지 않았다. — {link('구축 코드',R/'code/build_bilateral_panels.py')}; {link('공변량 결측 감사',F/'covariate_missingness_by_side.csv')}
- 새 주 분석 파일은 `{F.as_posix()}` 아래의 migration_inward_od.csv, migration_outward_od.csv, fdi_inward_od.csv, fdi_outward_od.csv, fats_inward_control_od.csv이다. 기존 입력 재현본은 상위 flows/ 폴더에 남아 있다. — {link('신규 파일목록',F/'summary.json')}; {link('기존 재현 파일목록',O/'summary.json')}

### Inferences
- 후속 설계에서는 서비스별 법 적용일·실제 준수조치·규제 확산의 내용/시점을 별도로 코딩한 뒤 출발국과 도착국의 규제 차이, 사전 경제적 노출과 국가쌍 결과를 연결할 수 있다. 서비스 범위와 산업 J의 불일치도 명시해야 한다.
- 인적 이동·FDI·해외기업 고용을 각각 기술적으로 살펴보고, 팬데믹·전쟁·브렉시트·거시경기와 통계개정의 공통충격을 검토해야 한다. 관측 변화만으로 DMA로 인한 이전이나 규범 확산의 효과라고 결론낼 수 없다.

### Gaps
- 규제 준수 사건과 국가별 도입/집행을 연결한 완성된 식별 전략, 동시정책 처리, 사전추세 검증은 이번 FLOWS 산출물의 범위 밖이다.
- 새 스냅샷과 기존 스냅샷의 partner·reporter·업종 범위가 다르므로 단순 관측행수 비교만 가능한 범위감사 파일을 제공했다. 경제 변화 비교는 공통차원으로 재정렬하는 후속 단계가 필요하다. — {link('스냅샷 범위 비교',O/'snapshot_scope_comparison.csv')}
'''
note_path=R.parent/'research_notes/DMA 규범 확산과 국제 이동 자료/flows.md'
note_path.parent.mkdir(parents=True,exist_ok=True)
note_path.write_text(note,encoding='utf-8')
print('NOTE',note_path,flush=True)
print('FRESH',tot,'OD rows',obs,'observed;',new['joined_country_year_rows'],'country-year rows',new['joined_country_year_columns'],'columns',flush=True)
print(pd.DataFrame([{k:x[k] for k in ['source_id','od_rows','od_observed','od_missing','od_observed_zeros','od_negative_values']} for x in new['sources']]).to_string(index=False),flush=True)
