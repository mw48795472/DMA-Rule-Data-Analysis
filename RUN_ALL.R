# ============================================================================
# RUN_ALL.R  —  이 파일 하나로 그림 23개(ggplot)를 RStudio Plots 창에 전부 띄웁니다.
# ----------------------------------------------------------------------------
# 실행 방법 (셋 중 아무거나):
#   1) Source 버튼            (Ctrl+Shift+S)
#   2) Run All                (Ctrl+Alt+R)
#   3) 아무 줄에 커서를 두고 Run (Ctrl+Enter)  <- 파일 전체가 하나의 { } 블록이라 전부 실행됩니다.
# 진행 순서:
#   1/3 그림 01~23을 하나씩 만들어 Plots 창에 표시 (파일 저장 없이 먼저 화면에)
#   2/3 figures/ 에 PNG·PDF 저장 + 통합본 figures/ALL_PLOTS.pdf
#   3/3 요약표 출력 + 전체 축소판 한 장
# 모형·부트스트랩은 재실행하지 않습니다. outputs/의 저장 결과와 inputs/의 공간자료만 읽습니다.
# 그림 하나만 다시 만들기:  p <- dma_build_plot(3);  p + ggplot2::labs(title="VIF 비교")
# 화면만 보고 파일 저장은 생략:  options(dma.save_plots=FALSE) 를 먼저 실행
# ============================================================================
{
# ---- DMA path bootstrap (works with RStudio Source and Rscript) ----
if (.Platform$OS.type == "windows") invisible(suppressWarnings(Sys.setlocale("LC_CTYPE", "English_United States.utf8")))
.dma_bootstrap <- function() {
  source_files <- as.character(unlist(lapply(sys.frames(), function(f) {
    x <- get0("ofile", envir=f, inherits=FALSE)
    if (is.character(x) && length(x)==1L && nzchar(x)) x else NULL
  }), use.names=FALSE))
  script_arg <- grep("^--file=", commandArgs(trailingOnly=FALSE), value=TRUE)
  script_file <- sub("^--file=", "", script_arg)
  editor_file <- character()
  if (interactive() && requireNamespace("rstudioapi", quietly=TRUE) && rstudioapi::isAvailable())
    editor_file <- tryCatch(rstudioapi::getSourceEditorContext()$path, error=function(e) character())
  override <- Sys.getenv("DMA_PROJECT_DIR", unset="")
  starts <- if (nzchar(override)) override else c(dirname(rev(source_files)), dirname(script_file),
    dirname(editor_file[nzchar(editor_file)]), getwd())
  find_root <- function(start) {
    d <- normalizePath(path.expand(start), winslash="/", mustWork=FALSE)
    while (dir.exists(d)) {
      if (file.exists(file.path(d,"project_paths.R")) && dir.exists(file.path(d,"code"))) return(d)
      parent <- dirname(d)
      if (identical(parent,d)) break
      d <- parent
    }
    NULL
  }
  candidates <- Filter(Negate(is.null), lapply(unique(starts), find_root))
  if (!length(candidates)) stop("DMA 프로젝트를 찾지 못했습니다. ZIP 전체를 풀고 DMA_PoC_v4.Rproj를 여세요.\n현재 작업 폴더: ",
    getwd(), "\n필요하면 Sys.setenv(DMA_PROJECT_DIR='압축을 푼 프로젝트 폴더')로 지정하세요.", call.=FALSE)
  project_dir <- candidates[[1L]]
  source(file.path(project_dir,"project_paths.R"), local=parent.frame(), encoding="UTF-8")
  get("dma_initialize", envir=parent.frame())(project_dir)
}
root <- .dma_bootstrap()
rm(.dma_bootstrap)
# ---- End path bootstrap ----

  # ---- 0. 준비: 패키지 확인(없을 때만 setup.R로 설치), 표시/저장 옵션 ----
  .dma_t0 <- proc.time()[["elapsed"]]
  .dma_needed <- c("ggplot2","sf","jsonlite")
  if (any(!vapply(.dma_needed, requireNamespace, logical(1), quietly=TRUE))) source(dma_path("setup.R"), encoding="UTF-8")
  if (interactive() || is.null(getOption("dma.show_plots"))) options(dma.show_plots=interactive())
  if (is.null(getOption("dma.save_plots"))) options(dma.save_plots=TRUE)
  source(dma_path("code","00_plot_helpers.R"), encoding="UTF-8")
  dma_plots <- list(); dma_figures <- list(); dma_clear_data()
  source(dma_path("code","11_plot_saved_results.R"), encoding="UTF-8")   # 그림 01–20 등록
  source(dma_path("code","mechanism_plots.R"), encoding="UTF-8")         # 그림 21–23 등록

  # ---- 1. 그림 23개를 하나씩 Plots 창에 표시 (파일 저장 없음 → 빠름) ----
  cat("\n== 1/3 그림 표시: ", length(dma_figures), "개 ==\n", sep="")
  run_all_status <- dma_show_plots(dma_figure_numbers())

  # ---- 2. PNG/PDF 저장 (figures/) + 통합 PDF ----
  cat("\n== 2/3 파일 저장 ==\n")
  if (isTRUE(getOption("dma.save_plots"))) {
    dma_export_plots(dma_figure_numbers())
    dma_export_mechanism_copies()
  } else cat("options(dma.save_plots=FALSE): 파일 저장을 건너뜁니다.\n")
  all_plot_index <- list_dma_plots()
  write.csv(all_plot_index, dma_path("outputs","all_plot_index.csv"), row.names=FALSE, fileEncoding="UTF-8")

  # ---- 3. 요약 + 전체 축소판 한 장 ----
  cat("\n== 3/3 요약 ==\n")
  print(all_plot_index[c("figure","name")], row.names=FALSE)
  if (!all(run_all_status$ok)) {
    cat("\n실패한 그림:\n"); print(run_all_status[!run_all_status$ok, c("figure","name","message")], row.names=FALSE)
  }
  cat(sprintf("\n완료: 그림 %d/%d개 (%.0f초). dma_plots에 ggplot 객체가 있습니다.\n",
              sum(run_all_status$ok), nrow(run_all_status), proc.time()[["elapsed"]] - .dma_t0))
  if (isTRUE(getOption("dma.show_plots"))) {
    dma_plot_overview()
    cat("Plots 창: 이전/다음 화살표로 넘기거나 show_dma_plot(1) ~ show_dma_plot(23)으로 다시 봅니다.\n")
    cat("마지막 그림은 전체 축소판입니다. 그림 하나 다시 만들기: p <- dma_build_plot(3); p + labs(title='VIF')\n")
  }
  if (isTRUE(getOption("dma.save_plots"))) cat("파일: figures/*.png, figures/*.pdf, figures/ALL_PLOTS.pdf | 목록: outputs/all_plot_index.csv\n")
  rm(.dma_t0, .dma_needed)
}
