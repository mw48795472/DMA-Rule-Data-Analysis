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

# DMA PoC v3. Open DMA_PoC_v3.Rproj and source this file with UTF-8.
if(.Platform$OS.type=="windows")invisible(suppressWarnings(Sys.setlocale("LC_CTYPE","English_United States.utf8")))
source("code/01_preprocess_base.R",encoding="UTF-8")
source("code/02_join_audit.R",encoding="UTF-8")
source("code/03_models.R",encoding="UTF-8")
main<-panel[panel$year==cfg$year & panel$sample_eu27==1,];main$id<-main$country
x0<-c("exposure_pre_2017_2019_pct","log_gdp_pc_pps","log_labour_cost_j","unemployment_pct")
z0<-c("z_exposure","z_income","z_cost","z_unemployment")
specs<-list(
 legacy=list(y="ict_share_pct",x=x0,z=z0),
 augmented=list(y="ict_share_pct",x=c(x0,"pre_j_share_pct"),z=c(z0,"z_pre_j")),
 parsimonious=list(y="ict_share_pct",x=c(x0[c(1,2,4)],"pre_j_share_pct"),z=c(z0[c(1,2,4)],"z_pre_j")),
 industry=list(y="employment_na_j_share_pct",x=x0,z=z0),
 migration=list(y="asinh_immigration_15_64_complet_per1000",x=x0[c(1,2,4)],z=z0[c(1,2,4)]))
results<-list()
for(id in names(specs)){
 s<-specs[[id]];results[[id]]<-run_group(main,id,s$y,s$x,s$z,B=cfg$bootstrap_national,primary=id%in%c("legacy","augmented","parsimonious"))
}
# Regional run is exploratory: NUTS2024 code match, EU27, European representative point window.
rr<-regional[regional$year==cfg$year,];rr$id<-rr$geo
regional_audit<-data.frame(id=rr$id,eu27=rr$sample_eu27,geometry_match=rr$geometry_match,
 in_window=ifelse(is.na(rr$in_europe_window),FALSE,rr$in_europe_window),
 complete=complete.cases(rr[c("regional_j_share_pct","log_regional_gdp_pc_pps","tertiary_pct")]))
regional_audit$included<-with(regional_audit,eu27 & geometry_match & in_window & complete)
save_csv(regional_audit,"regional_sample_audit_2024.csv")
rd<-rr[regional_audit$eu27 & regional_audit$geometry_match & regional_audit$in_window,]
results$regional<-run_group(rd,"regional","regional_j_share_pct",c("log_regional_gdp_pc_pps","tertiary_pct"),c("z_income","z_education"),restricted=FALSE,B=cfg$bootstrap_regional)
saveRDS(results,file.path(out,"all_results.rds"))
source("code/04_comparisons_plots.R",encoding="UTF-8")
source("code/06_boundary_sensitivity.R",encoding="UTF-8")
capture.output(sessionInfo(),file=file.path(out,"R_sessionInfo.txt"))
writeLines(loglines,file.path(out,"run_log.txt"),useBytes=TRUE)
source("code/05_report.R",encoding="UTF-8")
note("PoC v3 COMPLETE. See outputs and figures. Report builder uses these saved results.")
