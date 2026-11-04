---
layout: default
title: "재현과 원천자료"
order: 5
---

# RStudio에서 같은 자료와 그림 열기

## 빠른 실행

저장소 전체를 내려받아 `DMA_PoC_v4.Rproj`를 엽니다. 개별 R 파일만 이동하면 입력자료와 공간자료의 상대 경로가 끊길 수 있습니다.

```r
# 첫 실행에서 필요한 패키지를 준비합니다.
source("setup.R", encoding = "UTF-8")

# 자료·경로 확인
source("CHECK_PATHS.R", encoding = "UTF-8")

# 저장된 결과를 읽어 그림 23개를 생성합니다. 추가 자료와 그림 21~23만 보려면 RUN_MECHANISMS.R
source("RUN_ALL.R", encoding = "UTF-8")
```

새 그림은 `mechanism_plots`에 ggplot 객체로 남고 PNG로도 저장됩니다. `RUN_PLOTS.R`은 기존 그림 20개를 다시 만듭니다. 두 진입점은 공간회귀와 부트스트랩을 새로 실행하지 않습니다.

## 전체 분석을 다시 적합하려면

```r
source("RUN_FULL_ANALYSIS.R", encoding = "UTF-8")
```

원자료 재처리, 모형 적합, 지역 SDM 부트스트랩 9,999회 등이 포함되어 시간이 걸립니다. 저장된 결과가 갱신되므로 기존 결과를 비교하려면 별도 작업 복사본에서 실행하세요. 웹 문서에는 검증된 저장 결과를 사용하며 사이트 배포 때마다 분석을 재실행하지 않습니다.

## 실행 파일과 자료

- [RStudio 프로젝트](https://github.com/mw48795472/DMA-Rule-Data-Analysis/blob/main/DMA_PoC_v4.Rproj)
- [23개 ggplot을 Plots 창에 차례로 표시·저장](https://github.com/mw48795472/DMA-Rule-Data-Analysis/blob/main/RUN_ALL.R)
- [기존 20개 ggplot 생성](https://github.com/mw48795472/DMA-Rule-Data-Analysis/blob/main/RUN_PLOTS.R)
- [새 자료와 그림 3개](https://github.com/mw48795472/DMA-Rule-Data-Analysis/blob/main/RUN_MECHANISMS.R)
- [Python 자료 검토](https://github.com/mw48795472/DMA-Rule-Data-Analysis/blob/main/MECHANISMS_REVIEW.ipynb)
- [Python 공간분석 재현·검증 (W·Moran·VIF·ML·효과·부트스트랩)](https://github.com/mw48795472/DMA-Rule-Data-Analysis/blob/main/DMA_SPATIAL_ANALYSIS.ipynb)
- [VIF·Moran·SAR/SEM/SDM](https://github.com/mw48795472/DMA-Rule-Data-Analysis/blob/main/code/03_models.R)
- [지역 SDM 잔차 재적합 부트스트랩](https://github.com/mw48795472/DMA-Rule-Data-Analysis/blob/main/code/07_refine_regional_bootstrap.R)
- [신규 자료 목록](https://github.com/mw48795472/DMA-Rule-Data-Analysis/blob/main/outputs/mechanisms_20261102/integration/integration_catalog.csv)
- [결측 감사](https://github.com/mw48795472/DMA-Rule-Data-Analysis/blob/main/outputs/mechanisms_20261102/integration/integration_missingness.csv)
- [저장소 파일·크기·해시](https://github.com/mw48795472/DMA-Rule-Data-Analysis/blob/main/FILE_MANIFEST.csv)

## 원천과 API 키

| 원천 | 자료 | 접근 |
|---|---|---|
| [Eurostat 이민](https://ec.europa.eu/eurostat/databrowser/view/migr_imm5prv/default/table) / [이출](https://ec.europa.eu/eurostat/databrowser/view/migr_emi3nxt/default/table) | 이전·다음 거주국별 흐름 | 공개 API, 개인 키 불필요 |
| [Eurostat FDI](https://ec.europa.eu/eurostat/databrowser/view/bop_fdi6_flow/default/table) / [FATS](https://ec.europa.eu/eurostat/databrowser/view/fats_activ/default/table) | 정보통신업 투자·외국계 기업 활동 | 공개 API, 개인 키 불필요 |
| [Eurofound ERM](https://apps.eurofound.europa.eu/restructuring-events/methodology) | 공개 기업 사건 | 공개 페이지; 전수 CSV는 별도 연구 신청 |
| [GISCO](https://gisco-services.ec.europa.eu/distribution/v2/) | 국가·NUTS 공간 경계 | 공개 배포 |
| 게이트키퍼·EC 공식 문서 | 준수 변화와 적용범위 | 공개 문서, 개인 키 불필요 |

원문 URL·다운로드 상태·해시는 각 자료 폴더의 `SOURCE_MANIFEST.csv`에 있습니다. 원천자료와 공식 문서의 이용조건은 해당 제공기관을 따릅니다.

## 웹 문서를 수정하려면

웹 본문은 `docs/*.md`, 실제 분석은 `code/*.R`로 구분됩니다. `code/build_pages.py`는 저장 결과와 R 코드 발췌에서 문서와 README를 생성합니다. 통계 결과를 변경하지 않습니다.

```bash
python code/build_pages.py
```

그림·설명·분석 소스를 수정한 뒤 문서를 다시 생성하고 변경 내용을 검토합니다. GitHub Pages는 `main` 브랜치의 `/docs`를 게시합니다. 기존 HTML 보고서를 웹 본문으로 복사하지 않으며 Markdown과 코드 블록이 페이지의 원문입니다.
