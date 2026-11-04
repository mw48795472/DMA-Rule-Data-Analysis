# ============================================================================
# 00_plot_helpers.R : 그림 등록(registry)·지연 로딩·표시·저장 공통 함수
# ----------------------------------------------------------------------------
# 설계 원칙
#  * 그림 하나 = 함수 하나. dma_register("NN_name", width, height, function() ggplot)
#    로 등록만 하고, 실제 그리기는 dma_show_plots()가 번호 순서대로 수행합니다.
#  * 자료는 dma_data("key")로 필요할 때 한 번만 읽습니다(메모이즈).
#    첫 그림이 공간자료 로딩을 기다리지 않도록 하기 위한 것입니다.
#  * 그림마다 tryCatch로 격리합니다. 한 그림이 실패해도 나머지는 계속 표시됩니다.
#  * source()는 ggplot을 자동 출력하지 않으므로 print()를 명시적으로 호출합니다.
#  * 화면 표시(1차)와 PNG/PDF 저장(2차)을 분리해 Plots 창에 그림이 먼저 나옵니다.
# 기존 API(dma_save_plot, show_dma_plot, list_dma_plots, show_all_dma_plots, dma_plots)는
# 그대로 유지합니다. 04/08/09/10 분석 코드가 dma_save_plot을 사용합니다.
# ============================================================================

if (!exists("dma_plots", envir=.GlobalEnv, inherits=FALSE)) assign("dma_plots", list(), envir=.GlobalEnv)
if (!exists("dma_figures", envir=.GlobalEnv, inherits=FALSE)) assign("dma_figures", list(), envir=.GlobalEnv)
if (!exists(".dma_data_cache", envir=.GlobalEnv, inherits=FALSE)) assign(".dma_data_cache", new.env(parent=emptyenv()), envir=.GlobalEnv)
if (!exists(".dma_data_loaders", envir=.GlobalEnv, inherits=FALSE)) assign(".dma_data_loaders", new.env(parent=emptyenv()), envir=.GlobalEnv)

# ---- 자료 지연 로딩 ---------------------------------------------------------
dma_data_loader <- function(key, loader) {
  stopifnot(is.character(key), length(key)==1L, is.function(loader))
  assign(key, loader, envir=get(".dma_data_loaders", envir=.GlobalEnv))
  invisible(key)
}
dma_data <- function(key) {
  cache <- get(".dma_data_cache", envir=.GlobalEnv)
  if (!exists(key, envir=cache, inherits=FALSE)) {
    loaders <- get(".dma_data_loaders", envir=.GlobalEnv)
    if (!exists(key, envir=loaders, inherits=FALSE))
      stop("등록되지 않은 자료 키입니다: ", key, call.=FALSE)
    assign(key, get(key, envir=loaders)(), envir=cache)
  }
  get(key, envir=cache)
}
dma_clear_data <- function() {
  cache <- get(".dma_data_cache", envir=.GlobalEnv)
  rm(list=ls(cache, all.names=TRUE), envir=cache)
  invisible(NULL)
}

# ---- 그림 등록 ----------------------------------------------------------------
dma_register <- function(name, width=10, height=6, build, dpi=170) {
  stopifnot(is.character(name), length(name)==1L, grepl("^[0-9]{2}_", name), is.function(build))
  registry <- get("dma_figures", envir=.GlobalEnv)
  registry[[name]] <- list(name=name, width=width, height=height, dpi=dpi, build=build)
  registry <- registry[order(names(registry))]
  assign("dma_figures", registry, envir=.GlobalEnv)
  invisible(name)
}
.dma_figure_key <- function(number_or_name, registry=get("dma_figures", envir=.GlobalEnv)) {
  if (is.numeric(number_or_name) && length(number_or_name)==1L) {
    key <- grep(sprintf("^%02d_", as.integer(number_or_name)), names(registry), value=TRUE)
  } else key <- as.character(number_or_name)
  if (length(key)!=1L || !key %in% names(registry))
    stop("그림 번호/이름을 확인하세요: ", paste(number_or_name, collapse=", "),
         "\n등록된 그림: ", paste(names(registry), collapse=", "), call.=FALSE)
  key
}
dma_figure_numbers <- function() as.integer(substr(names(get("dma_figures", envir=.GlobalEnv)), 1, 2))

# 그림 하나를 자료에서 새로 만듭니다(화면 표시·저장 없음). 수정 출발점으로 사용하세요.
dma_build_plot <- function(number_or_name) {
  spec <- get("dma_figures", envir=.GlobalEnv)[[.dma_figure_key(number_or_name)]]
  p <- spec$build()
  if (!inherits(p, "ggplot")) stop("그림 ", spec$name, "의 build 함수가 ggplot을 반환하지 않았습니다.", call.=FALSE)
  registry <- get("dma_plots", envir=.GlobalEnv)
  registry[[spec$name]] <- p
  assign("dma_plots", registry[order(names(registry))], envir=.GlobalEnv)
  invisible(p)
}

# ---- 1차: 화면 표시 ---------------------------------------------------------
# which: 번호 벡터(기본 전체). 그림마다 build -> print 를 순서대로 수행합니다.
dma_show_plots <- function(which=dma_figure_numbers(), show=getOption("dma.show_plots", interactive()),
                           quiet=FALSE) {
  registry <- get("dma_figures", envir=.GlobalEnv)
  if (!length(registry)) stop("등록된 그림이 없습니다. code/11_plot_saved_results.R을 먼저 source 하세요.", call.=FALSE)
  keys <- vapply(which, function(w) .dma_figure_key(w, registry), character(1))
  status <- data.frame(figure=as.integer(substr(keys,1,2)), name=keys, ok=NA, seconds=NA_real_,
                       message="", stringsAsFactors=FALSE)
  for (i in seq_along(keys)) {
    t0 <- proc.time()[["elapsed"]]
    res <- tryCatch({
      p <- dma_build_plot(keys[i])
      if (isTRUE(show)) print(p)   # RStudio Plots 창에 그립니다.
      "OK"
    }, error=function(e) paste0("ERROR: ", conditionMessage(e)))
    status$ok[i] <- identical(res, "OK")
    status$seconds[i] <- round(proc.time()[["elapsed"]] - t0, 2)
    status$message[i] <- if (status$ok[i]) "" else res
    if (!quiet) cat(sprintf("[%2d/%d] %-34s %s (%.1fs)\n", i, length(keys), keys[i],
                            if (status$ok[i]) "표시" else "실패", status$seconds[i]))
    if (!status$ok[i] && !quiet) cat("        ", status$message[i], "\n")
  }
  invisible(status)
}

# ---- 2차: 파일 저장 -----------------------------------------------------------
.dma_pdf_device <- function() if (capabilities("cairo")) grDevices::cairo_pdf else grDevices::pdf
dma_export_plots <- function(which=dma_figure_numbers(), combined=TRUE, quiet=FALSE) {
  registry <- get("dma_figures", envir=.GlobalEnv); plots <- get("dma_plots", envir=.GlobalEnv)
  keys <- vapply(which, function(w) .dma_figure_key(w, registry), character(1))
  keys <- keys[keys %in% names(plots)]
  destination <- dma_path("figures"); dir.create(destination, showWarnings=FALSE, recursive=TRUE)
  saved <- character()
  for (key in keys) {
    spec <- registry[[key]]
    ok <- tryCatch({
      ggplot2::ggsave(file.path(destination, paste0(key, ".png")), plot=plots[[key]],
                      width=spec$width, height=spec$height, dpi=spec$dpi, bg="white")
      ggplot2::ggsave(file.path(destination, paste0(key, ".pdf")), plot=plots[[key]], device=.dma_pdf_device(),
                      width=spec$width, height=spec$height, bg="white")
      TRUE
    }, error=function(e) { if (!quiet) cat("저장 실패:", key, "-", conditionMessage(e), "\n"); FALSE })
    if (ok) saved <- c(saved, key)
  }
  if (isTRUE(combined) && length(keys)) {
    all_pdf <- file.path(destination, "ALL_PLOTS.pdf")
    tryCatch({
      .dma_pdf_device()(all_pdf, width=11, height=7, onefile=TRUE)
      on.exit(grDevices::dev.off(), add=TRUE)
      for (key in keys) print(plots[[key]])
    }, error=function(e) if (!quiet) cat("통합 PDF 저장 실패:", conditionMessage(e), "\n"))
  }
  if (!quiet) cat(sprintf("저장: PNG/PDF %d개 -> %s%s\n", length(saved), destination,
                          if (isTRUE(combined)) " (통합본 figures/ALL_PLOTS.pdf)" else ""))
  invisible(saved)
}

# ---- 전체 축소판 한 장 --------------------------------------------------------
# 마지막에 호출하면 Plots 창의 최신 그림이 전체 축소판이 됩니다.
dma_plot_overview <- function(which=dma_figure_numbers(), ncol=NULL, title="DMA plots: overview") {
  plots <- get("dma_plots", envir=.GlobalEnv)
  keys <- vapply(which, function(w) .dma_figure_key(w), character(1)); keys <- keys[keys %in% names(plots)]
  n <- length(keys); if (!n) return(invisible(NULL))
  if (is.null(ncol)) ncol <- ceiling(sqrt(n))
  nrow <- ceiling(n/ncol)
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(layout=grid::grid.layout(nrow+1, ncol,
    heights=grid::unit(c(2, rep(1, nrow)), c("lines", rep("null", nrow))))))
  grid::grid.text(title, vp=grid::viewport(layout.pos.row=1, layout.pos.col=1:ncol), gp=grid::gpar(fontsize=14, fontface="bold"))
  for (i in seq_len(n)) {
    small <- plots[[keys[i]]]
    # 축소판에서는 mm 단위 고정 크기인 geom_text 라벨이 너무 커지므로 제외합니다.
    small$layers <- Filter(function(l) !inherits(l$geom, c("GeomText","GeomLabel")), small$layers)
    small <- small + ggplot2::labs(subtitle=NULL, caption=NULL, title=keys[i]) +
      ggplot2::theme(text=ggplot2::element_text(size=6), legend.position="none",
                     plot.title=ggplot2::element_text(size=7, face="bold"), axis.text=ggplot2::element_text(size=4))
    tryCatch(print(small, vp=grid::viewport(layout.pos.row=1 + (i-1) %/% ncol + 1, layout.pos.col=(i-1) %% ncol + 1)),
             error=function(e) NULL)
  }
  grid::upViewport(0)
  invisible(keys)
}

# ---- 기존 API ----------------------------------------------------------------
# 분석 스크립트(04/08/09/10)와 수동 사용을 위한 즉시 표시·저장 함수입니다.
dma_save_plot <- function(p, name, width=10, height=6, dpi=170,
                          show=getOption("dma.show_plots", interactive()),
                          save=getOption("dma.save_plots", TRUE)) {
  stopifnot(inherits(p,"ggplot"), length(name)==1L, nzchar(name))
  registry <- get("dma_plots", envir=.GlobalEnv)
  registry[[name]] <- p
  assign("dma_plots", registry[order(names(registry))], envir=.GlobalEnv)
  if (isTRUE(show)) print(p)
  if (isTRUE(save)) {
    destination <- dma_path("figures")
    dir.create(destination, showWarnings=FALSE, recursive=TRUE)
    ggplot2::ggsave(file.path(destination,paste0(name,".png")), plot=p, width=width,height=height,dpi=dpi,bg="white")
    ggplot2::ggsave(file.path(destination,paste0(name,".pdf")), plot=p, device=.dma_pdf_device(),
                    width=width,height=height,bg="white")
  }
  invisible(p)
}

show_dma_plot <- function(number_or_name, rebuild=FALSE) {
  plots <- get("dma_plots", envir=.GlobalEnv)
  key <- if (is.numeric(number_or_name) && length(number_or_name)==1L)
    grep(sprintf("^%02d_",as.integer(number_or_name)),names(plots),value=TRUE) else as.character(number_or_name)
  if (isTRUE(rebuild) || length(key)!=1L || !key%in%names(plots)) {
    # 아직 만들지 않은 그림이면 등록된 build 함수로 새로 만듭니다.
    if (length(get("dma_figures", envir=.GlobalEnv))) { p <- dma_build_plot(number_or_name); print(p); return(invisible(p)) }
    stop("그림 번호/이름을 확인하세요. 먼저 RUN_ALL.R을 실행한 뒤 list_dma_plots()를 실행하세요.",call.=FALSE)
  }
  print(plots[[key]])
  invisible(plots[[key]])
}

list_dma_plots <- function() {
  plots <- get("dma_plots", envir=.GlobalEnv)
  keys <- sort(names(plots))
  data.frame(figure=as.integer(substr(keys,1,2)), name=keys,
    title=vapply(plots[keys],function(p)if(is.null(p$labels$title))"" else as.character(p$labels$title),character(1)),
    png=paste0("figures/",keys,".png"),pdf=paste0("figures/",keys,".pdf"),row.names=NULL, stringsAsFactors=FALSE)
}

show_all_dma_plots <- function(pause=FALSE) {
  for (key in sort(names(get("dma_plots",envir=.GlobalEnv)))) {
    show_dma_plot(key)
    if (isTRUE(pause) && interactive()) readline("다음 그림: Enter ")
  }
  invisible(NULL)
}

dma_open_figures <- function() {
  destination <- dma_path("figures")
  if (interactive() && dir.exists(destination)) utils::browseURL(destination)
  invisible(destination)
}
