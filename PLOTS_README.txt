RStudio에서 ggplot2 그림까지 생성하는 방법

1. ZIP 전체를 풀고 DMA_PoC_v4.Rproj를 엽니다.
2. RUN_PLOTS.R 파일을 연 뒤 Source를 누릅니다.
3. ggplot2 그림 20개가 RStudio의 Plots 창에 차례로 그려집니다.
   마지막 그림이 보이면 Plots 창의 이전/다음 화살표로 다른 그림을 볼 수 있습니다.
4. 같은 그림은 figures/에 PNG와 PDF로 저장됩니다.

이 실행은 outputs/의 실제 CSV와 SHP/GPKG를 읽어 ggplot을 새로 만듭니다.
기존 PNG를 화면에 띄우는 방식이 아니며 부트스트랩·모형 적합을 다시 실행하지 않습니다.
그래프 작성 코드는 code/11_plot_saved_results.R, 화면 표시/저장 함수는 code/00_plot_helpers.R입니다.
기존 분석 스크립트들도 이제 RStudio에서 실행하면 그림을 표시하고 저장합니다.

원하는 그림만 다시 보기 — RUN_PLOTS.R 실행 후 Console에서:
show_dma_plot(3)   # VIF 비교
show_dma_plot(4)   # SAR·SEM·SDM 모형 비교
show_dma_plot(5)   # 원자료 Moran's I
show_dma_plot(9)   # 모형 잔차 Moran's I
show_dma_plot(13)  # 지역 SDM 부트스트랩 반복 횟수 비교
show_dma_plot(16)  # 영국 포함 유럽 이입 지도
show_dma_plot(17)  # 영국·비EU 8개국 비교
show_dma_plot(19)  # 포르투갈 국가자료 보완 지도
show_dma_plot(20)  # LTA 종단 자료 가용성
list_dma_plots()   # 전체 목록
show_all_dma_plots(pause=TRUE)  # Enter를 누르며 한 장씩 보기

그림 직접 수정하기:
p_vif <- dma_plots[["03_vif_comparison"]] + ggplot2::labs(title="VIF 비교")
print(p_vif)
ggplot2::ggsave("figures/my_vif.png", plot=p_vif, width=12, height=5, dpi=300)

Environment 창의 dma_plots는 수정 가능한 ggplot 객체 목록입니다.
Source() 안에서는 p만 작성하거나 ggsave()만 호출하면 Plots 창에 자동 표시되지 않을 수 있습니다.
이번 수정본은 명시적으로 print(p)를 호출합니다.

화면 표시를 꺼 두었던 세션에서는 다음을 실행한 뒤 다시 Source 하세요:
options(dma.show_plots=TRUE)

그림 파일 저장 없이 화면만 보고 싶으면:
options(dma.save_plots=FALSE)
source("RUN_PLOTS.R", encoding="UTF-8")

RStudio가 아닌 Rscript 실행은 기본적으로 PNG/PDF만 저장합니다.
새 분석까지 모두 수행하려면 START_HERE.R, 그림만 다시 만들려면 RUN_PLOTS.R을 사용하세요.
경로 확인은 CHECK_PATHS.R, 패키지 설치 확인은 setup.R로 할 수 있습니다.
