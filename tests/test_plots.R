# Exercise the real display path on an R graphics device, including Source().
if(.Platform$OS.type=="windows")invisible(suppressWarnings(Sys.setlocale("LC_CTYPE","English_United States.utf8")))
this_file<-normalizePath(sub("^--file=","",grep("^--file=",commandArgs(FALSE),value=TRUE)[1]),winslash="/",mustWork=TRUE)
project<-dirname(dirname(this_file))
critical<-file.path(project,"outputs",c("all_model_comparisons.csv","regional_sdm_bootstrap_extended_draws.csv","combined_country_year.csv","combined_region_year.csv"))
before<-tools::md5sum(critical)
capture<-file.path(project,"outputs","plot_device_smoke.pdf")
grDevices::pdf(capture,width=12,height=9,onefile=TRUE)
options(dma.show_plots=TRUE,dma.save_plots=TRUE)
source(file.path(project,"RUN_PLOTS.R"),encoding="UTF-8")
stopifnot(length(dma_plots)==20L,all(vapply(dma_plots,inherits,logical(1),what="ggplot")))
idx<-list_dma_plots();stopifnot(identical(idx$figure,1:20))
stopifnot(all(file.exists(file.path(project,idx$png))),all(file.exists(file.path(project,idx$pdf))))
stopifnot(nrow(dma_plots[["17_non_eu_migration_rates"]]$data)==8L)
boot<-dma_plots[["13_regional_bootstrap_precision"]]$data
stopifnot(tail(boot$simulations,1)==9999L,abs(tail(boot$p_bootstrap,1)-.0526)<1e-12)
stopifnot(inherits(show_dma_plot(17),"ggplot")) # page 21: choose a previously constructed figure
edited<-dma_plots[["03_vif_comparison"]]+ggplot2::labs(title="Editable VIF plot")
stopifnot(edited$labels$title=="Editable VIF plot",dma_plots[["03_vif_comparison"]]$labels$title!="Editable VIF plot")
print(edited) # page 22: demonstrate a real editable ggplot, not a loaded PNG
grDevices::dev.off()
stopifnot(identical(unname(before),unname(tools::md5sum(critical))))
jsonlite::write_json(list(status="PASS",ggplot_objects=20L,expected_graphics_pages=22L,
 source_invocation="Source from outside the project",analysis_outputs_unchanged=TRUE,
 display_test="Explicit print() on an R PDF graphics device; native RStudio UI not automated",
 file=capture),file.path(project,"outputs","plot_display_validation.json"),auto_unbox=TRUE,pretty=TRUE)
cat("PASS: 20 ggplots built; display/selection/editing exercised; analysis data unchanged.\n")
