# ============================================================================
# RUN_PLOTS.R — 기존 그림 01~20만 ggplot으로 만들어 Plots 창에 표시하고 figures/에 저장합니다.
# Source(Ctrl+Shift+S) / Run All(Ctrl+Alt+R) / 아무 줄에서 Run(Ctrl+Enter) 모두 전체 실행됩니다.
# 23개 전체는 RUN_ALL.R 을 실행하세요. 모형·부트스트랩은 재실행하지 않습니다.
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

  # 기존 그림 01–20만 표시·저장합니다. 전체 23개는 RUN_ALL.R을 실행하세요.
  .dma_needed <- c("ggplot2","sf","jsonlite")
  if (any(!vapply(.dma_needed, requireNamespace, logical(1), quietly=TRUE))) source(dma_path("setup.R"), encoding="UTF-8")
  if (interactive() || is.null(getOption("dma.show_plots"))) options(dma.show_plots=interactive())
  if (is.null(getOption("dma.save_plots"))) options(dma.save_plots=TRUE)
  source(dma_path("code","00_plot_helpers.R"), encoding="UTF-8")
  dma_plots <- list(); dma_figures <- list(); dma_clear_data()
  source(dma_path("code","11_plot_saved_results.R"), encoding="UTF-8")
  cat("\n== 그림 표시 (1–20) ==\n")
  run_plots_status <- dma_show_plots(1:20)
  if (isTRUE(getOption("dma.save_plots"))) dma_export_plots(1:20, combined=FALSE)
  plot_index <- list_dma_plots()
  write.csv(plot_index, dma_path("outputs","plot_index.csv"), row.names=FALSE, fileEncoding="UTF-8")
  print(plot_index[c("figure","name")], row.names=FALSE)
  if (!all(run_plots_status$ok)) print(run_plots_status[!run_plots_status$ok, c("figure","name","message")], row.names=FALSE)
  cat(sprintf("완료: ggplot 객체 %d개가 dma_plots에 있습니다.\n", length(dma_plots)))
  cat("show_dma_plot(3), show_dma_plot(17) 등으로 다시 보거나 p <- dma_build_plot(3) 으로 수정하세요.\n")
  rm(.dma_needed)
}
