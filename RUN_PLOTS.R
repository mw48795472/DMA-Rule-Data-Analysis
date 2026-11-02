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

# 이 파일 전체를 Source하세요. RStudio Plots 창 + PNG/PDF 파일을 만듭니다.
# 그림을 다시 그릴 때 9,999회 부트스트랩은 실행하지 않습니다.
source(dma_path("setup.R"),encoding="UTF-8")
if(is.null(getOption("dma.show_plots")))options(dma.show_plots=interactive())
source(dma_path("code","00_plot_helpers.R"),encoding="UTF-8")
assign("dma_plots",list(),envir=.GlobalEnv)
source(dma_path("code","11_plot_saved_results.R"),encoding="UTF-8")
plot_index<-list_dma_plots()
stopifnot(nrow(plot_index)==20L,identical(plot_index$figure,1:20))
write.csv(plot_index,dma_path("outputs","plot_index.csv"),row.names=FALSE,fileEncoding="UTF-8")
print(plot_index[c("figure","name")],row.names=FALSE)
cat("완료: ggplot 객체 20개가 dma_plots에 있습니다. 그림 파일은 figures/에 저장했습니다.\n")
cat("RStudio Plots 창의 이전/다음 화살표 또는 show_dma_plot(3), show_dma_plot(17), show_dma_plot(20)을 사용하세요.\n")
# 직접 수정 예시: 아래 줄만 선택하여 Run 또는 콘솔에서 실행하세요.
# p_vif <- dma_plots[["03_vif_comparison"]] + ggplot2::labs(title="VIF 비교")
# print(p_vif)
# show_all_dma_plots(pause=TRUE)
