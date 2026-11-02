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

# DMA 공간분석 PoC v3 — 기존 원천자료 재구성 모듈
# 1) DMA_PoC_v4.Rproj를 엽니다.
# 2) 최초 실행: source("setup.R", encoding="UTF-8")
# 3) 전체 분석: source("analysis.R", encoding="UTF-8")
# 입력은 inputs/, 표와 검정은 outputs/, 플롯은 figures/에 저장됩니다.
# 전체 실행은 analysis.R, 단계별 코드는 code/에 있습니다.
# 원자료 파일을 함께 두어야 합니다. .R 파일 하나만 다른 폴더로 옮기면 실행되지 않습니다.
# 전체 계산에는 수 분이 걸릴 수 있습니다. 결과는 DMA 인과효과를 뜻하지 않습니다.

if (.Platform$OS.type == "windows") suppressWarnings(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))
# DMA spatial PoC. Run source("analysis.R", encoding="UTF-8") in this RStudio project,
# or Rscript --vanilla <project-folder>/analysis.R. Outputs are descriptive, not DMA causal effects.
root <- getOption("dma.project_root") # resolved from script location, not unrelated command arguments
if(!file.exists(file.path(root,"inputs","base","csv","country_year_core.csv"))) stop("Open DMA_PoC_v4.Rproj, then source analysis.R.")
local_lib <- file.path(root, ".Rlibrary")
if(dir.exists(local_lib)) .libPaths(c(local_lib,.libPaths()))
previous_lib <- file.path(dirname(root),"dma_poc_20261028",".Rlibrary")
if(dir.exists(previous_lib)) .libPaths(c(previous_lib,.libPaths()))
req <- c("sf","spdep","spatialreg","car","jsonlite","ggplot2")
missing_pkgs <- req[!vapply(req,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing_pkgs)) stop("Install first: install.packages(c(",paste(sprintf("'%s'",missing_pkgs),collapse=","),"))")
options(stringsAsFactors=FALSE, scipen=8)
sf::sf_use_s2(FALSE)
cfg <- dma_read_json("config.json")
out <- file.path(root,"outputs"); dir.create(out,showWarnings=FALSE,recursive=TRUE)
fig <- file.path(root,"figures"); dir.create(fig,showWarnings=FALSE)
save_csv <- function(x,nm) write.csv(x,file.path(out,nm),row.names=FALSE,na="",fileEncoding="UTF-8")
read_input <- function(nm) read.csv(file.path(root,"inputs","base","csv",nm),fileEncoding="UTF-8-BOM",na.strings=c("",":"),check.names=FALSE,colClasses="character")
loglines <- character()
note <- function(s) {cat(s,"\n"); loglines <<- c(loglines,s)}
note(paste("Analysis started:", format(Sys.time(),tz="Asia/Seoul")))
# Rebuild the core from the individual source CSVs rather than relying only on the earlier merge.
old <- read_input("country_year_core.csv")
old_numeric <- setdiff(names(old),c("country","country_iso2",grep("_flag$",names(old),value=TRUE)))
old[old_numeric] <- lapply(old[old_numeric],as.numeric)
stopifnot(nrow(old)==288L,!anyDuplicated(old[c("country","year")]))
panel <- old[c("country","country_iso2","year","sample_eu27")]
series <- function(file,filters,name,mult=1) {
 d <- read_input(file)
 for(k in names(filters)) d <- d[!is.na(d[[k]]) & d[[k]]==filters[[k]],,drop=FALSE]
 stopifnot(!anyDuplicated(d[c("geo","time")]))
 z <- data.frame(country=d$geo,year=as.integer(d$time),value=as.numeric(d$value)*mult,
                 flag=ifelse(is.na(d$status),"",d$status))
 names(z)[3:4] <- c(name,paste0(name,"_flag"))
 z
}
add <- function(file,filters,name,mult=1) {
 panel <<- merge(panel,series(file,filters,name,mult),by=c("country","year"),all.x=TRUE,sort=FALSE)
}
add("ict_specialists.csv",list(unit="THS_PER"),"ict_specialists_persons",1000)
add("ict_specialists.csv",list(unit="PC_EMP"),"ict_share_pct")
add("fdi_inward_j.csv",list(nace_r2="J",entity="TOTAL",partner="WRL_REST",stk_flow="NI",fdi_item="DI__D__F"),"fdi_inward_j_meur")
add("fdi_outward_j.csv",list(nace_r2="J",entity="TOTAL",partner="WRL_REST",stk_flow="NO",fdi_item="DO__D__F"),"fdi_outward_j_meur")
for(pair in list(c("EMP_NR","foreign_employment_j"),c("ENT_NR","foreign_enterprises_j"),c("AV_MEUR","foreign_value_added_j_meur")))
 add("foreign_affiliates_j.csv",list(nace_r2="J",c_ctrl="WRL_REST",indic_sbs=pair[1]),pair[2])
for(pair in list(c("E_AWS_CMP","marketplace_firm_share_pct"),c("E_AWS_CMP_GE20","marketplace20_firm_share_pct")))
 add("marketplace_exposure.csv",list(nace_r2="C10-S951_X_K",size_emp="GE10",unit="PC_ENT",indic_is=pair[1]),pair[2])
for(pair in list(c("CP_EUR_HAB","gdp_pc_eur"),c("CP_PPS_EU27_2020_HAB","gdp_pc_pps"),c("CLV20_EUR_HAB","gdp_pc_real2020_eur")))
 add("gdp_per_capita.csv",list(unit=pair[1],na_item="B1GQ"),pair[2])
add("gdp_total.csv",list(unit="CP_MEUR",na_item="B1GQ"),"gdp_meur")
add("labour_cost_j.csv",list(nace_r2="J",lcstruct="D1_D4_MD5",unit="EUR"),"hourly_labour_cost_j_eur")
add("unemployment.csv",list(age="Y15-74",sex="T",unit="PC_ACT"),"unemployment_pct")
for(dir in c("inward","outward")) for(def in c("REACH","COMPLET"))
 add(paste0("migration_",dir,".csv"),list(partner="TOTAL",age="Y15-64",agedef=def,sex="T",unit="NR"),
     paste0(if(dir=="inward") "immigration" else "emigration","_15_64_",tolower(def)))
panel$fdi_inward_j_pct_gdp <- ifelse(panel$gdp_meur>0,100*panel$fdi_inward_j_meur/panel$gdp_meur,NA_real_)
panel$fdi_outward_j_pct_gdp <- ifelse(panel$gdp_meur>0,100*panel$fdi_outward_j_meur/panel$gdp_meur,NA_real_)
baseline <- sapply(split(panel[panel$year %in% 2017:2019,],panel$country[panel$year %in% 2017:2019]),
 function(d) if(nrow(d)==3 && all(is.finite(d$marketplace_firm_share_pct))) mean(d$marketplace_firm_share_pct) else NA_real_)
panel$exposure_pre_2017_2019_pct <- unname(baseline[panel$country])
panel <- panel[order(panel$country,panel$year),]; rownames(panel)<-NULL
old <- old[order(old$country,old$year),]
numeric_common <- intersect(names(panel)[vapply(panel,is.numeric,logical(1))],names(old))
rebuild_checks <- do.call(rbind,lapply(numeric_common,function(v) data.frame(variable=v,
 equal=isTRUE(all.equal(panel[[v]],old[[v]],tolerance=1e-8,check.attributes=FALSE)))))
save_csv(rebuild_checks,"rebuild_validation.csv"); stopifnot(all(rebuild_checks$equal))
stopifnot(all(panel$ict_share_pct[!is.na(panel$ict_share_pct)]>=0),
 all(panel$ict_share_pct[!is.na(panel$ict_share_pct)]<=100))
panel$log_gdp_pc_pps <- ifelse(panel$gdp_pc_pps>0,log(panel$gdp_pc_pps),NA_real_)
panel$log_labour_cost_j <- ifelse(panel$hourly_labour_cost_j_eur>0,log(panel$hourly_labour_cost_j_eur),NA_real_)
panel$asinh_fdi_inward_pct_gdp <- asinh(panel$fdi_inward_j_pct_gdp)
panel$asinh_fdi_outward_pct_gdp <- asinh(panel$fdi_outward_j_pct_gdp)
panel$log1p_foreign_employment_j <- log1p(panel$foreign_employment_j)
save_csv(panel,"clean_panel.csv")
numvars <- names(panel)[vapply(panel,is.numeric,logical(1))]
coverage <- do.call(rbind,lapply(split(panel,panel$year),function(d)
 data.frame(year=d$year[1],variable=numvars,nonmissing=sapply(d[numvars],function(x)sum(is.finite(x))),n=nrow(d))))
save_csv(coverage,"coverage_year.csv")
# SHP join, geometry checks and explicit treatment of overseas territories.
g <- sf::st_read(file.path(root,"inputs","base","spatial","EUROPE32_2024_4326.shp"),quiet=TRUE)
stopifnot(nrow(g)==32,!anyDuplicated(g$COUNTRY),setequal(g$COUNTRY,unique(panel$country)))
geometry_audit <- data.frame(country=g$COUNTRY,valid_before=sf::st_is_valid(g),empty_before=sf::st_is_empty(g))
g <- sf::st_make_valid(g)
geometry_audit$valid_after <- sf::st_is_valid(g)
stopifnot(all(geometry_audit$valid_after),!any(sf::st_is_empty(g)))
save_csv(geometry_audit,"geometry_audit.csv")
# Europe window only for distance representatives/display; country economic values are unchanged.
clip <- suppressWarnings(sf::st_crop(g,c(xmin=-25,ymin=34,xmax=45,ymax=72)))
gp <- sf::st_transform(clip,3035)
parts <- suppressWarnings(sf::st_cast(gp,"POLYGON"))
parts$area_m2 <- as.numeric(sf::st_area(parts))
main_parts <- parts[unlist(lapply(split(seq_len(nrow(parts)),parts$COUNTRY),
 function(ix) ix[which.max(parts$area_m2[ix])])),]
cent <- suppressWarnings(sf::st_centroid(main_parts))
xy <- sf::st_coordinates(cent)
coords <- data.frame(country=cent$COUNTRY,x_m=xy[,1],y_m=xy[,2])
coords <- coords[order(coords$country),]
stopifnot(nrow(coords)==32,all(is.finite(as.matrix(coords[,2:3]))))
save_csv(coords,"country_centroids_3035.csv")
panel <- merge(panel,coords,by="country",all.x=TRUE,sort=FALSE)
panel <- panel[order(panel$country,panel$year),]
save_csv(panel,"joined_country_year.csv")
target <- panel[panel$year==cfg$year,]
joined <- merge(g,target,by.x="COUNTRY",by.y="country",all.x=TRUE,sort=FALSE)
sf::st_write(joined,file.path(out,"joined_2024.geojson"),delete_dsn=TRUE,quiet=TRUE)
