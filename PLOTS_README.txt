RStudio 그림 일괄 출력 재설정 — 2026-11-04 (2차 업데이트)

[무엇이 달라졌나]
- RUN_ALL.R 하나를 실행하면 ggplot 그림 23개가 Plots 창에 "먼저" 차례로 뜹니다.
  파일 저장(PNG/PDF)은 그림이 모두 화면에 나온 뒤 2단계에서 수행합니다.
- 그림마다 독립된 함수로 정의했습니다(code/11_plot_saved_results.R, code/mechanism_plots.R).
  한 그림이 실패해도 나머지 22개는 계속 표시되고, 끝에 실패 목록이 출력됩니다.
- 자료는 처음 필요한 그림에서 한 번만 읽습니다. 첫 그림이 1~2초 안에 나옵니다.
- 실행 파일 전체가 하나의 { } 블록이므로 Source, Run All, 아무 줄에서 Run(Ctrl+Enter)
  어느 쪽을 눌러도 파일 전체가 실행됩니다.
- 마지막에 23개 전체 축소판 한 장을 그리고, figures/ALL_PLOTS.pdf 통합본도 저장합니다.

[설치]
1. 이 ZIP을 기존 DMA 프로젝트 최상위 폴더(DMA_PoC_v4.Rproj가 있는 폴더)에 폴더 구조 그대로 덮어씁니다.
   RUN_ALL.R, config.json, project_paths.R, inputs/, outputs/, code/ 가 같은 폴더에 있어야 합니다.
   이 ZIP은 코드 업데이트입니다. 원자료가 들어 있는 기존 프로젝트가 필요합니다.
2. DMA_PoC_v4.Rproj 를 열고 RUN_ALL.R 을 엽니다.
3. Source(Ctrl+Shift+S) 또는 Run All(Ctrl+Alt+R)을 누릅니다.
   필요한 패키지(ggplot2, sf, jsonlite)가 없을 때만 setup.R이 자동 설치합니다.

[실행 순서와 콘솔 출력]
== 1/3 그림 표시: 23개 ==      [ 1/23] 01_missingness  표시 (0.9s) ... 그림이 하나씩 Plots 창에 나타남
== 2/3 파일 저장 ==            figures/NN_name.png, .pdf, ALL_PLOTS.pdf
== 3/3 요약 ==                 그림 번호·이름 표, 실패 목록(있을 때), 전체 축소판 1장
RStudio Plots 창은 한 번에 한 장만 보이므로 끝나면 마지막(축소판)이 보입니다.
이전/다음 화살표 또는 아래 명령으로 원하는 그림을 다시 봅니다.

[그림 다시 보기 / 수정]
show_dma_plot(3)                      # VIF 비교
show_dma_plot(13)                     # 지역 SDM 부트스트랩 검정
show_dma_plot(21)                     # 게이트키퍼 준수 자료 지리적 범위
list_dma_plots()                      # 23개 목록(번호·이름·제목·파일)
show_all_dma_plots(pause=TRUE)        # Console에서 Enter로 한 장씩
dma_plot_overview()                   # 전체 축소판
p <- dma_build_plot(3)                # 자료에서 그림 3을 새로 만듦(화면 표시 없음)
p + ggplot2::labs(title="VIF 비교")   # 수정해서 표시
dma_plots[["03_vif_comparison"]]      # 이미 만든 ggplot 객체
dma_show_plots(c(7, 8, 11))           # 원하는 번호만 다시 만들어 표시
dma_export_plots(1:23)                # 파일만 다시 저장
dma_open_figures()                    # figures/ 폴더 열기

[옵션]
options(dma.save_plots=FALSE)   # 화면만 보고 파일 저장 생략(실행 전에)
options(dma.show_plots=FALSE)   # 화면 표시 없이 파일만(Rscript 비대화형은 기본이 이 동작)
Rscript RUN_ALL.R               # 터미널에서 실행하면 화면 대신 figures/ 파일만 생성

[실행 파일 구분]
- RUN_ALL.R           : 그림 01~23 전부(권장). 모형은 재적합하지 않음.
- RUN_PLOTS.R         : 기존 그림 01~20만.
- RUN_MECHANISMS.R    : 추가 자료 로딩 + 그림 21~23만. mechanism_plots 객체 생성.
- RUN_FULL_ANALYSIS.R : 원자료 처리·모형 재적합 뒤 RUN_ALL.R 실행(9,999회 부트스트랩 때문에 오래 걸림).
- START_HERE.R        : 지역 SDM 잔차 9,999회·국가분석 재실행 뒤 RUN_ALL.R 실행.

[파일]
code/00_plot_helpers.R        : 등록(dma_register)·지연 로딩(dma_data)·표시(dma_show_plots)·저장(dma_export_plots)·축소판
code/11_plot_saved_results.R  : 그림 01~20 정의. dma_register("NN_name", 폭, 높이, function(){ ggplot ... })
code/mechanism_plots.R        : 추가 자료 로딩 + 그림 21~23 정의
code/build_pages.py           : 문서 생성기. 새 dma_register 블록을 발췌하도록 수정
tests/test_run_all.R          : 검증(실제 자료, Cairo PDF 장치 49쪽, PNG/PDF 23쌍 + ALL_PLOTS.pdf, 분석 결과 불변)
outputs/run_all_display_validation.json : 이번 검증 결과

[검증 기록 2026-11-04]
Rscript tests/test_run_all.R → PASS. 그림 23/23 생성·표시·재선택·재생, PNG 23 + PDF 23 + ALL_PLOTS.pdf 저장,
outputs/ 주요 CSV 해시 불변. 첫 그림은 1초 안에 표시, 23개 표시까지 약 25~50초, 파일 저장 포함 전체 1~2분
(공간자료 포함, Windows 11 / R 4.5.3 / ggplot2 4.0.3 / sf 1.1.3).
