# DMA Rule Data Analysis

EU 디지털시장법(DMA)의 브뤼셀 효과와 티부형 기업·투자·인력 이동을 구분해 검토하는 연구 PoC입니다. 무료 공개자료, 공간자료, 전처리·공간회귀 코드, 그림과 보고서를 제공합니다. 자료 수집 기준일은 **2026-11-02**입니다.

## 바로 보기

- [최신 연구설계 보고서 PDF · 15쪽](reports/DMA_Mechanisms_Research_Design_20261102.pdf)
- [최신 보고서 Markdown](reports/DMA_Mechanisms_Research_Design_20261102.md)
- [최신 보고서 HTML](reports/DMA_Mechanisms_Research_Design_20261102.html) — 내려받아 브라우저에서 열기
- [기존 20개 그림 해석 보고서 PDF](reports/DMA_PoC_20plots_Report.pdf)
- [새 자료 안내](MECHANISMS_README_ko.txt)
- [파일 목록·크기·SHA-256](FILE_MANIFEST.csv)

## RStudio에서 실행

1. 저장소 전체를 내려받거나 clone합니다.
2. `DMA_PoC_v4.Rproj`를 RStudio에서 엽니다.
3. 처음 실행하는 컴퓨터에서는 `setup.R`을 확인하고 실행하여 필요한 패키지를 준비합니다.
4. `RUN_MECHANISMS.R` 전체를 **Source**하면 새 자료를 불러오고 `ggplot2` 그림 3개를 표시·저장합니다. 그래프 객체는 `mechanism_plots`에 있습니다.
5. 기존 그림 20개는 `RUN_PLOTS.R`로 확인합니다. 전체 추정 재실행은 `RUN_FULL_ANALYSIS.R` 및 기존 안내를 참고하세요. 부트스트랩을 포함해 시간이 걸릴 수 있습니다.

경로는 `project_paths.R`가 프로젝트 폴더를 기준으로 찾습니다. 개별 R 파일만 내려받지 말고 입력자료와 하위 폴더 구조를 함께 유지하세요.

Python 검토용 노트북은 [MECHANISMS_REVIEW.ipynb](MECHANISMS_REVIEW.ipynb)입니다. 기존 실행·경로·그림 안내는 [README_ko.txt](README_ko.txt), [PATH_FIX_README.txt](PATH_FIX_README.txt), [PLOTS_README.txt](PLOTS_README.txt)에 있습니다.

## 자료 구성

| 경로 | 내용 |
|---|---|
| `inputs/` | 원천 통계, 공간자료, 공식 문서와 출처 메타데이터 |
| `inputs/mechanisms_20261102/` | 추가 수집한 준수 변화, 기업 사건, 국가쌍 흐름 |
| `outputs/mechanisms_20261102/flows/fresh/` | **새로 내려받은** Eurostat 자료의 정제·결합 결과 |
| `outputs/mechanisms_20261102/flows/` | 기존 스냅샷 및 비교 감사; `fresh/`와 구분 |
| `outputs/mechanisms_20261102/integration/` | 통합 목록, 결측·국가코드 결합 감사, 새 그림 |
| `outputs/`, `figures/` | 기존 VIF·Moran’s I·SAR·SEM·SDM 결과와 그림 |
| `reports/` | 최신 연구설계 및 기존 그림 해석 보고서 |
| `code/` | 자료 수집·결합·분석·시각화 코드 |

추가 자료는 준수 변경 12개와 현재 범위 기록 1개, 기업 사건 11건과 목적지 관계 17개, 국가쌍 자료 205,784행입니다. 국가쌍 자료 중 85,278행에 수치가 있으며, 행 수는 연령·방향·산업·지표 차원을 포함하므로 고유 이동 사건 수가 아닙니다. 기존 32개국·288개 국가-연도 행은 보존했습니다.

## 원천과 접근

- Eurostat: [이민 유입](https://ec.europa.eu/eurostat/databrowser/view/migr_imm5prv/default/table), [이출](https://ec.europa.eu/eurostat/databrowser/view/migr_emi3nxt/default/table), [FDI](https://ec.europa.eu/eurostat/databrowser/view/bop_fdi6_flow/default/table), [외국계 기업 활동](https://ec.europa.eu/eurostat/databrowser/view/fats_activ/default/table)
- 게이트키퍼 공식 준수 보고서·발표와 유럽연합 집행위원회 문서
- [Eurofound ERM](https://apps.eurofound.europa.eu/restructuring-events/methodology) 공개 사건과 기업 공식 공시
- [GISCO 공간자료](https://gisco-services.ec.europa.eu/distribution/v2/)

개별 원문 URL, 다운로드 상태와 해시는 각 자료 폴더의 `SOURCE_MANIFEST.csv`에 있습니다. 이번 공개 조회에는 개인 API 키가 필요하지 않습니다. ERM 전수 CSV는 별도 비상업적 연구 신청 대상이며 이번 수집의 공개 사례와 다릅니다. 원천자료·공식 문서는 해당 제공기관의 이용조건을 따릅니다.

## 해석과 검증 범위

브뤼셀 효과는 **비EU 이용자 시장의 동일 서비스·기능 확산**, 티부형 경로는 **기업·투자·인력의 실제 위치 변화**로 구분합니다. 기업 자기보고, 이전 발표, 법적 주소 변경과 실제 완료·이주를 구별합니다. 현재 자료만으로 DMA가 이동을 유발했다고 단정할 수 없습니다. 일반 이민은 ICT 인력 이동과 동일하지 않으며 결측을 0으로 바꾸지 않습니다.

이번 확장은 자료 수집·결합 및 연구설계 보완입니다. 기존 공간회귀·20개 그림 결과를 보존했고 새 인과회귀를 적합하지 않았습니다. R 4.5.3에서 새 그림 3개 출력·저장과 주요 행 수를 확인했으며, 노트북 코드 셀과 자료 해시·결합 감사를 검증했습니다. 검증 결과는 `outputs/mechanisms_20261102/integration/final_artifact_checks.json` 등을 참고하세요.
