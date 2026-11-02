# Source() does not auto-print ggplot objects. Explicitly print to the active device
# (normally RStudioGD in RStudio), then export the same object to PNG/PDF.
if (!exists("dma_plots", envir=.GlobalEnv, inherits=FALSE)) assign("dma_plots", list(), envir=.GlobalEnv)

dma_save_plot <- function(p, name, width=10, height=6, dpi=170,
                          show=getOption("dma.show_plots", interactive()),
                          save=getOption("dma.save_plots", TRUE)) {
  stopifnot(inherits(p,"ggplot"), length(name)==1L, nzchar(name))
  registry <- get("dma_plots", envir=.GlobalEnv)
  registry[[name]] <- p
  assign("dma_plots", registry, envir=.GlobalEnv)
  if (isTRUE(show)) print(p)  # This line draws in RStudio's Plots pane.
  if (isTRUE(save)) {
    destination <- dma_path("figures")
    dir.create(destination, showWarnings=FALSE, recursive=TRUE)
    ggplot2::ggsave(file.path(destination,paste0(name,".png")), plot=p,
                   width=width,height=height,dpi=dpi,bg="white")
    ggplot2::ggsave(file.path(destination,paste0(name,".pdf")), plot=p,
                   width=width,height=height,bg="white")
  }
  invisible(p)
}

show_dma_plot <- function(number_or_name) {
  plots <- get("dma_plots", envir=.GlobalEnv)
  key <- if (is.numeric(number_or_name) && length(number_or_name)==1L)
    grep(sprintf("^%02d_",as.integer(number_or_name)),names(plots),value=TRUE) else number_or_name
  if (length(key)!=1L || !key%in%names(plots))
    stop("그림 번호/이름을 확인하세요. 먼저 RUN_PLOTS.R을 Source한 뒤 list_dma_plots()를 실행하세요.",call.=FALSE)
  print(plots[[key]])
  invisible(plots[[key]])
}

list_dma_plots <- function() {
  plots <- get("dma_plots", envir=.GlobalEnv)
  keys <- sort(names(plots))
  data.frame(figure=as.integer(substr(keys,1,2)), name=keys,
    title=vapply(plots[keys],function(p)if(is.null(p$labels$title))"" else as.character(p$labels$title),character(1)),
    png=paste0("figures/",keys,".png"),pdf=paste0("figures/",keys,".pdf"),row.names=NULL)
}

show_all_dma_plots <- function(pause=FALSE) {
  for (key in sort(names(get("dma_plots",envir=.GlobalEnv)))) {
    show_dma_plot(key)
    if (isTRUE(pause) && interactive()) readline("다음 그림: Enter ")
  }
  invisible(NULL)
}
