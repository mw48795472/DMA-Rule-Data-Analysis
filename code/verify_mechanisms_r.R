invisible(suppressWarnings(Sys.setlocale('LC_CTYPE', 'English_United States.utf8')))
warning_log <- character()
grDevices::cairo_pdf('outputs/mechanisms_20261102/integration/r_graphics_smoke.pdf',
                    width=10, height=5.5, family='Malgun Gothic')
invisible(capture.output(withCallingHandlers(
  source('RUN_MECHANISMS.R', encoding='UTF-8'),
  warning=function(w) {
    warning_log <<- c(warning_log, conditionMessage(w))
    invokeRestart('muffleWarning')
  }
)))
grDevices::dev.off()
stopifnot(length(mechanism_plots)==3L, nrow(mechanism_bridge)==288L,
          nrow(compliance_events)==13L, nrow(firm_events)==11L,
          sum(vapply(mechanism_flows,nrow,integer(1)))==205784L)
writeLines(unique(warning_log), 'outputs/mechanisms_20261102/integration/r_warnings.txt', useBytes=TRUE)
cat('PASS: three plots, 288 bridge rows, 13 compliance records, 11 firm cases, 205784 flow rows.\n')
cat('Warnings: ',length(warning_log),'\n')
print(unique(warning_log))
