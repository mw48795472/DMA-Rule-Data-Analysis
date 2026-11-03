무료 원천자료·메커니즘 설계 확장 (2026-11-02)
MECHANISMS_README_ko.txt : 이번 추가 자료와 실행 안내
reports/DMA_Mechanisms_Research_Design_20261102.pdf : 15쪽 연구설계 보고서
RUN_MECHANISMS.R : 새 자료 로딩과 ggplot 그림 3개 출력
MECHANISMS_REVIEW.ipynb : 데이터 결합 감사와 그림 확인
새 수집 흐름은 outputs/mechanisms_20261102/flows/fresh/가 기준입니다.

20개 그림 해석 보고서 업데이트 (2026-11-02)
reports/DMA_PoC_20plots_Report.pdf : 30쪽, 그림별 결과·브뤼셀 효과·티부 효과·한계
reports/DMA_PoC_20plots_Report.md : GitHub에서 읽는 Markdown 본문(figures/ PNG 참조)
REPORT_UPDATE_README.txt : 변경 내용과 재현 안내

## RStudio에서 그림 보기 (2026-11-02 보완)

압축을 모두 풀고 `DMA_PoC_v4.Rproj`를 연 다음 `RUN_PLOTS.R` 전체를 **Source**하세요.
저장된 분석 결과와 공간자료로 ggplot 그래프 20개를 만들며, RStudio **Plots** 창과
`figures/`의 PNG/PDF 파일에 출력합니다. 분석과 9,999회 부트스트랩은 재실행하지 않습니다.

```r
show_dma_plot(3)   # VIF 비교
show_dma_plot(17)  # 영국 및 주변 비EU국
show_dma_plot(20)  # LTA 종단자료 관측률
list_dma_plots()   # 전체 그림 목록
p <- dma_plots[["03_vif_comparison"]] + ggplot2::labs(title="VIF 비교")
print(p)          # 직접 수정한 그림 표시
```

다른 그림은 Plots의 이전/다음 화살표 또는 `show_dma_plot(번호)`로 확인하세요.
자세한 사용법: `PLOTS_README.txt`. `RUN_PLOTS.R` 단독이 아닌 프로젝트 전체가 필요합니다.

경로 수정본: CHECK_PATHS.R을 먼저 Source하여 JSON 읽기 성공을 확인하세요.
R 파일 위치에서 프로젝트 폴더를 자동으로 찾습니다. 자세한 안내: PATH_FIX_README.txt

DMA 공간분석 PoC v4 | 2026-11-02

가장 먼저 reports/DMA_PoC_20plots_Report.md를 읽으세요. 이전 v4 요약은 reference/before_20plots/DMA_PoC_v4_Report.md, v3는 reference/v3/DMA_PoC_v3_Report.md에 Markdown으로 보존했습니다.
RStudio에서 DMA_PoC_v4.Rproj를 연 뒤 START_HERE.R을 Source 하세요.

실행 경로
- START_HERE.R: 이번 갱신 전체. 지역 SDM 잔차 9,999회, 국가별 자료 결합/지도/Moran, 보고서.
- REFRESH_OUTPUTS.R: 저장 결과로 보고서와 그림 09/13 및 LTA 테이블/그림20을 빠르게 다시 작성.
- REFINE_REGIONAL.R: 지역 SDM 잔차 검정만. 효과 구간은 기존 199회 유지.
- MIGRATION_EXTENSION.R: 새 국가자료 전처리/누락 감사/공간검정/그림 14–19.
- RUN_FULL_ANALYSIS.R: 기본 원자료 전처리와 기존 국가·지역 모형을 모두 재적합하고 v4까지 실행.
- collect_extension.py: 공식 원문/CSV 재수집. Python pandas 필요. 이미 받은 파일은 재사용.
- PREPARE_LTA.R: LTA 종단연구 테이블 생성. 2021–2024 네 시점 후보이며 잠재상태 모형을 적합하지 않습니다.

필요 R 패키지: sf, spdep, spatialreg, car, jsonlite, ggplot2.
setup.R이 설치 여부를 확인하고 없으면 CRAN에서 설치합니다. 최초 설치에는 인터넷이 필요합니다.
재현에는 API 키가 필요 없습니다. 원문과 CSV를 동봉해 일반 R 재실행은 다운로드가 불필요합니다.
Windows에서는 압축 내부 파일을 직접 실행하지 말고 모두 풀어 주세요. 경로에 한글이 있으면 UTF-8로 엽니다.
검증 환경: R 4.5.3, Windows. 초기 C.UTF-8 경고 뒤 LC_CTYPE을 Windows UTF-8로 설정했습니다.
보고서 문장은 이번 고정 설정(B=9999, seed=20262032, k=4)에 맞춥니다. 설정 변경 실험은 별도 폴더에서 하고 보고서 문장도 검토하세요.

핵심 결과
지역 SDM: p 0.0700(B199) -> 0.0526(B9999), MC SE 0.0032. 5% 경계이므로 무상관으로 단정 금지.
계수/AIC/VIF는 변동 없음. 직접·간접효과 구간과 다른 지역모형 검정은 B199.
기존 그림7의 COMPLET 누락 7개국 중 6개는 REACH 자료가 있습니다.
포르투갈 INE 2024 개정 자료와 개정 인구분모는 별도 보완 열/지도/민감도로 처리합니다.
영국은 전체 연령 ONS 이입과 중간인구. 15–64세 지도에 억지로 섞지 않습니다.
43개국 감사: 34개국 기본 전체연령 비율, PT 포함35. GISCO 경계42; XK 별도 도형 없음.

파일 안내
- outputs/regional_sdm_bootstrap_comparison.csv: 반복 수별 p와 Monte Carlo 오차.
- outputs/regional_sdm_bootstrap_extended_draws.csv: 실제 9999개 SDM 재적합 잔차 I/rho.
- outputs/regional/{sample,weights,model_comparison,residual_bootstrap}.csv: 지역 분석과 갱신 결과.
- outputs/regional/bootstrap_draws.csv: v3의 모든 지역모형 199회 기록; 연장 SDM 파일과 구분.
- outputs/migration_extension/migration_europe_2024.csv: 43개국 결합자료, 정의별 결측 보존.
- figure7_missing_country_audit.csv: 원래 누락 EU7개국 감사.
- portugal_revision_audit.csv: INE 분자·분모·비율과 Eurostat 분모의 차이.
- cross_dataset_checks.csv: migr_imm5prv/imm8/imm1ctz 교차 대조.
- v3_source_comparison.csv: 새 Eurostat 자료와 기존 값 대조.
- geometry_audit.csv: 43개국과 42개 경계의 코드 일치 감사.
- migration_moran_tests.csv: 8개 범위 × k3/4/5, 각 9999회 순열.
- sample_*.csv, weights_*.csv: 범위별 k4 재현 표본과 W.
- EUROPE42_2024.gpkg, shapefile/EUROPE42_2024.*: country 코드로 결합하는 경계.
- inputs/extension_20261102: 공식 원문 raw, 원문 변환 csv, 메타데이터와 SOURCE_MANIFEST.csv.
- figures: PNG/PDF. 그림13–20 신규. 그림09도 새 p로 갱신. 기타 그림은 기존 분석.
- reference/v3: 이전 보고서·비교 결과·모형의 보존본.
- outputs/summary_v3.json: 이전 분석의 스냅샷. 현재 결과는 CSV와 v4 보고서를 사용하세요.
- outputs/v4_validation.json: 독립 수치 검증, outputs/v4_report_session.txt: R 실행 환경.
- outputs/lta_design/LTA_research_design.csv: LTA 연구 질문·측정지표·상태 수·동일성·전이·결측 처리 계획.
- outputs/lta_design/*_long_2017_2025.csv: EU27 및 현재 코드 지역의 실제 종단 원값과 고정 2021 표준화.
- outputs/lta_design/*_waves_2021_2024.csv, *_wide_2021_2024.csv: 4시점 후보의 long/wide 테이블.
- outputs/lta_design/panel_summary.csv: 국가27개, 지역236개; 네 시점 완전 지역205개.
- outputs/lta_design/transition_pair_coverage.csv: 연속 시점 관측쌍 수; 잠재 전이확률이 아닙니다.
- figures/20_lta_longitudinal_coverage.png: 시점별 후보 지표 완전관측 수.

해석 범위
PoC 단면 연관성 분석입니다. DMA의 인과효과·브뤼셀 효과·기업의 규제회피 이전을 입증하지 않습니다.
전체 인구 이입은 ICT 인력만의 이동이 아니고, 이입은 순이동이 아닙니다.
연령/통계작성방법이 다른 보완 자료는 별도 열로 보존하며 기존 국가 회귀를 자동 확장하지 않습니다.
공간 경계 출처: © EuroGeographics for the administrative boundaries, GISCO/Eurostat.
지도 창은 유럽 본토 주변(-25~45E,34~72N)으로 제한합니다. 지리적 W는 실제 이동 네트워크가 아닙니다.
