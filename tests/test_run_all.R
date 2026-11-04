# Integration check: real data -> 23 individually built ggplots -> graphics device -> PNG/PDF export.
# Run from the project root or anywhere:  Rscript tests/test_run_all.R
if(.Platform$OS.type=="windows")invisible(suppressWarnings(Sys.setlocale("LC_CTYPE","English_United States.utf8")))
this_file<-normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]),winslash="/",mustWork=TRUE)
project<-dirname(dirname(this_file))
critical<-file.path(project,"outputs",c("all_model_comparisons.csv","regional_sdm_bootstrap_extended_draws.csv","combined_country_year.csv","combined_region_year.csv"))
before<-tools::md5sum(critical)
capture<-file.path(project,"outputs","run_all_display_smoke.pdf")
stopifnot(capabilities("cairo"))
grDevices::cairo_pdf(capture,width=12,height=9,onefile=TRUE)
options(dma.show_plots=TRUE,dma.save_plots=FALSE)
# Source from a different working directory to also exercise path discovery.
setwd(tempdir())
t0<-proc.time()[["elapsed"]]
source(file.path(project,"RUN_ALL.R"),encoding="UTF-8")
elapsed_run_all<-proc.time()[["elapsed"]]-t0
# 23 registered builders, 23 built ggplots, every build succeeded.
stopifnot(length(dma_figures)==23L,identical(dma_figure_numbers(),1:23))
stopifnot(length(dma_plots)==23L,all(vapply(dma_plots,inherits,logical(1),what="ggplot")))
stopifnot(nrow(run_all_status)==23L,all(run_all_status$ok))
idx<-list_dma_plots()
stopifnot(identical(idx$figure,1:23),!anyDuplicated(idx$name))
# Individual rebuild from data works and returns a fresh ggplot.
p3<-dma_build_plot(3);stopifnot(inherits(p3,"ggplot"),identical(p3$data,dma_plots[["03_vif_comparison"]]$data))
stopifnot(nrow(dma_plots[["17_non_eu_migration_rates"]]$data)==8L)
boot<-dma_plots[["13_regional_bootstrap_precision"]]$data
stopifnot(tail(boot$simulations,1)==9999L,abs(tail(boot$p_bootstrap,1)-.0526)<1e-12)
stopifnot(sum(dma_plots[["21_compliance_scope"]]$data$count)==13L)
stopifnot(sum(dma_plots[["22_firm_case_types"]]$data$count)==11L)
stopifnot(length(mechanism_plots)==3L)
stopifnot(inherits(show_dma_plot(1),"ggplot"),inherits(show_dma_plot(23),"ggplot"))
show_all_dma_plots(pause=FALSE)
grDevices::dev.off() # 23 initial + 1 overview + 2 selections + 23 replay = 49 pages.
# Exercise PNG/PDF export (second pass), including the Windows-font plots and the combined PDF.
test_figure_dir<-file.path(project,"outputs","run_all_export_smoke")
original_dma_path<-dma_path
dma_path<-function(...) {
  args<-list(...)
  if(length(args)>=1L && identical(args[[1L]],"figures"))return(do.call(file.path,c(list(test_figure_dir),args[-1L])))
  original_dma_path(...)
}
saved<-dma_export_plots(1:23,combined=TRUE,quiet=TRUE)
dma_path<-original_dma_path
stopifnot(length(saved)==23L)
stopifnot(all(file.exists(file.path(test_figure_dir,basename(idx$png)))),all(file.exists(file.path(test_figure_dir,basename(idx$pdf)))))
stopifnot(file.exists(file.path(test_figure_dir,"ALL_PLOTS.pdf")))
stopifnot(identical(unname(before),unname(tools::md5sum(critical))))
jsonlite::write_json(list(status="PASS",ggplot_objects=23L,registered_builders=23L,expected_graphics_pages=49L,
 run_all_seconds=round(elapsed_run_all,1),
 source_invocation="Source from outside the project",analysis_outputs_unchanged=TRUE,
 display_test="Explicit print() per figure on a Cairo PDF graphics device; native RStudio UI not automated",
 export_test="dma_export_plots(): 23 PNG + 23 PDF + ALL_PLOTS.pdf",
 file=capture),file.path(project,"outputs","run_all_display_validation.json"),auto_unbox=TRUE,pretty=TRUE)
cat(sprintf("PASS: 23 ggplots built, displayed, selected, replayed and exported in %.0fs; analysis data unchanged.\n",elapsed_run_all))
