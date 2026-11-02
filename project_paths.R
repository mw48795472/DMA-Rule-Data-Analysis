# Shared path handling. No analysis or package installation is performed here.
dma_initialize <- function(project_dir) {
  project_dir <- normalizePath(path.expand(project_dir), winslash="/", mustWork=TRUE)
  if (!file.exists(file.path(project_dir, "config.json"))) {
    stop("설정 파일이 없습니다: ", file.path(project_dir, "config.json"),
         "\nZIP 전체를 풀고 config.json과 R 파일을 같은 프로젝트 폴더에 두세요.", call.=FALSE)
  }
  for (nm in c("code", "inputs", "outputs")) {
    if (!dir.exists(file.path(project_dir, nm)))
      stop("프로젝트 폴더가 불완전합니다: ", file.path(project_dir, nm),
           "\nR 파일만 따로 옮기지 말고 ZIP 전체를 풀어 주세요.", call.=FALSE)
  }
  old_root <- getOption("dma.project_root")
  options(dma.project_root=project_dir)
  # Existing analysis modules use project-relative file names; pin them to this root.
  setwd(project_dir)
  libs <- c(file.path(project_dir, ".Rlibrary"),
            file.path(dirname(project_dir), "dma_poc_20261028", ".Rlibrary"))
  libs <- libs[dir.exists(libs)]
  if (length(libs)) .libPaths(c(libs, .libPaths()))
  if (!identical(old_root, project_dir)) message("DMA 프로젝트: ", project_dir)
  invisible(project_dir)
}

dma_path <- function(..., must_exist=FALSE) {
  project_dir <- getOption("dma.project_root")
  if (is.null(project_dir)) stop("프로젝트 경로가 초기화되지 않았습니다. CHECK_PATHS.R을 Source 하세요.", call.=FALSE)
  result <- file.path(project_dir, ...)
  if (must_exist && !file.exists(result))
    stop("파일이 없습니다: ", result, "\n현재 작업 폴더: ", getwd(), call.=FALSE)
  normalizePath(result, winslash="/", mustWork=FALSE)
}

dma_read_json <- function(file, ...) {
  # Read a file explicitly, never let jsonlite guess whether a missing path is JSON text/URL.
  absolute <- grepl("^([A-Za-z]:|/)", file) || startsWith(file, "\\\\")
  json_file <- if (absolute) normalizePath(file, winslash="/", mustWork=FALSE) else dma_path(file)
  if (!file.exists(json_file) || dir.exists(json_file))
    stop("JSON 파일을 찾을 수 없습니다: ", json_file,
         "\n프로젝트: ", getOption("dma.project_root"),
         "\nZIP을 모두 풀었는지 확인하고 CHECK_PATHS.R을 실행하세요.", call.=FALSE)
  if (!requireNamespace("jsonlite", quietly=TRUE))
    stop("jsonlite 패키지가 필요합니다. 프로젝트의 setup.R을 먼저 Source 하세요.", call.=FALSE)
  text <- paste(readLines(json_file, encoding="UTF-8", warn=FALSE), collapse="\n")
  text <- sub("^\ufeff", "", text)
  if (!jsonlite::validate(text))
    stop("JSON 파일은 있지만 내용 형식이 올바르지 않습니다: ", json_file,
         "\n따옴표·쉼표를 확인하거나 원래 config.json을 복원하세요.", call.=FALSE)
  jsonlite::fromJSON(text, ...)
}
