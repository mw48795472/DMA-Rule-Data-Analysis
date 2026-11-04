# ============================================================================
# RUN_MECHANISMS.R — 추가 자료를 읽고 그림 21~23만 ggplot으로 표시·저장합니다.
# Source(Ctrl+Shift+S) / Run All(Ctrl+Alt+R) / 아무 줄에서 Run(Ctrl+Enter) 모두 전체 실행됩니다.
# 새 자료 객체: mechanism_catalog, mechanism_bridge, compliance_events, firm_events, mechanism_flows, mechanism_plots
# 새 인과모형은 적합하지 않으며 기존 결과는 변경하지 않습니다.
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

  # 추가 자료(준수 기록·기업 사건·국가쌍 흐름)를 읽고 그림 21–23만 표시·저장합니다.
  # 새 자료 객체: mechanism_catalog, mechanism_bridge, compliance_events, firm_events, mechanism_flows, mechanism_plots
  .dma_needed <- c("ggplot2","jsonlite")
  if (any(!vapply(.dma_needed, requireNamespace, logical(1), quietly=TRUE))) source(dma_path("setup.R"), encoding="UTF-8")
  if (interactive() || is.null(getOption("dma.show_plots"))) options(dma.show_plots=interactive())
  if (is.null(getOption("dma.save_plots"))) options(dma.save_plots=TRUE)
  source(dma_path("code","00_plot_helpers.R"), encoding="UTF-8")
  source(dma_path("code","mechanism_plots.R"), encoding="UTF-8")
  cat("\n== 그림 표시 (21–23) ==\n")
  run_mechanisms_status <- dma_show_plots(21:23)
  if (isTRUE(getOption("dma.save_plots"))) { dma_export_plots(21:23, combined=FALSE); dma_export_mechanism_copies() }
  print(mechanism_catalog[c("domain","path","rows","year_min","year_max")], row.names=FALSE)
  cat("\n완료: 추가 그림은 mechanism_plots 및 dma_plots에 있습니다. show_dma_plot(21), show_dma_plot(22), show_dma_plot(23)으로 다시 볼 수 있습니다.\n")
  cat("새 인과모형은 실행하지 않았고 기존 분석 결과는 변경하지 않았습니다.\n")
  rm(.dma_needed)
}
