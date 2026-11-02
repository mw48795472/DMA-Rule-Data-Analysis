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

source(dma_path("code","00_plot_helpers.R"),encoding="UTF-8")

# Data preparation and study design only: no latent states or transition probabilities estimated.
root<-normalizePath(".");out<-file.path(root,"outputs");fig<-file.path(root,"figures")
ld<-file.path(out,"lta_design");dir.create(ld,showWarnings=FALSE)
save_lta<-function(d,nm)write.csv(d,file.path(ld,nm),row.names=FALSE,na="",fileEncoding="UTF-8")
nn<-read.csv(file.path(out,"combined_country_year.csv"),stringsAsFactors=FALSE)
rr<-read.csv(file.path(out,"combined_region_year.csv"),stringsAsFactors=FALSE)
nn<-nn[nn$sample_eu27==1,];nn$id<-nn$country
rr<-rr[rr$sample_eu27 & rr$geometry_match & !is.na(rr$in_europe_window) & rr$in_europe_window,];rr$id<-rr$geo
stopifnot(!anyDuplicated(nn[c("id","year")]),!anyDuplicated(rr[c("id","year")]))
items<-list(country=c("ict_share_pct","employment_na_j_share_pct","unemployment_pct"),
 regional=c("regional_j_share_pct","tertiary_pct","log_regional_gdp_pc_pps"))
units<-list(country=nn,regional=rr);waves<-2021:2024
cover<-summary_rows<-pairs<-list()
for(scope in names(units)){
 d<-units[[scope]];vv<-items[[scope]];d<-d[order(d$id,d$year),]
 d$complete_indicators<-complete.cases(d[vv]);d$selected_wave<-d$year%in%waves
 # A fixed 2021 reference scale preserves year-to-year shifts; do not re-standardize annually.
 scaling<-data.frame(variable=vv,baseline_year=2021,
  center=sapply(d[d$year==2021,vv],mean,na.rm=TRUE),sd=sapply(d[d$year==2021,vv],sd,na.rm=TRUE))
 stopifnot(all(is.finite(scaling$center)),all(scaling$sd>0))
 for(j in seq_along(vv))d[[paste0("lta_z_",vv[j])]]<-(d[[vv[j]]]-scaling$center[j])/scaling$sd[j]
 save_lta(scaling,paste0(scope,"_2021_scaling.csv"))
 save_lta(d,paste0(scope,"_long_2017_2025.csv"))
 dd<-d[d$selected_wave,];save_lta(dd,paste0(scope,"_waves_2021_2024.csv"))
 ww<-reshape(dd[c("id","country","year",vv,"complete_indicators")],idvar=c("id","country"),timevar="year",direction="wide")
 save_lta(ww,paste0(scope,"_wide_2021_2024.csv"))
 z<-aggregate(complete_indicators~id,dd,sum);full<-z$id[z$complete_indicators==length(waves)]
 save_lta(data.frame(id=unique(d$id),complete_all_four=unique(d$id)%in%full),paste0(scope,"_balanced_sample_audit.csv"))
 flagcols<-intersect(paste0(vv,"_flag"),names(d))
 if(scope=="regional")flagcols<-unique(c(flagcols,"regional_gdp_pc_pps_flag"))
 if(length(flagcols)){
  flags<-do.call(rbind,lapply(flagcols,function(v)data.frame(scope=scope,id=d$id,year=d$year,variable=v,flag=d[[v]])))
  save_lta(flags[!is.na(flags$flag)&nzchar(flags$flag),],paste0(scope,"_source_flags.csv"))
 }
 for(y in sort(unique(d$year))){a<-d[d$year==y,]
  cover[[length(cover)+1L]]<-data.frame(scope=scope,year=y,units=nrow(a),complete_three=sum(a$complete_indicators),
   indicator1=sum(is.finite(a[[vv[1]]])),indicator2=sum(is.finite(a[[vv[2]]])),indicator3=sum(is.finite(a[[vv[3]]])),selected_wave=y%in%waves)
 }
 for(y in waves[-length(waves)]){
  a<-dd[dd$year==y,c("id","complete_indicators")];b<-dd[dd$year==y+1,c("id","complete_indicators")]
  ab<-merge(a,b,by="id",suffixes=c("_from","_to"));ab$from_year<-y;ab$to_year<-y+1
  ab$both_complete<-ab$complete_indicators_from & ab$complete_indicators_to
  save_lta(ab,paste0(scope,"_pair_",y,"_",y+1,".csv"))
  pairs[[length(pairs)+1L]]<-data.frame(scope=scope,from_year=y,to_year=y+1,matched_units=nrow(ab),complete_pairs=sum(ab$both_complete))
 }
 summary_rows[[length(summary_rows)+1L]]<-data.frame(scope=scope,unique_units=length(unique(d$id)),countries=length(unique(d$country)),
  selected_years="2021,2022,2023,2024",rows_four_waves=nrow(dd),complete_rows=sum(dd$complete_indicators),balanced_units=length(full),
  incomplete_rows=sum(!dd$complete_indicators),latent_model_fitted=FALSE)
}
cover<-do.call(rbind,cover);sm<-do.call(rbind,summary_rows);pa<-do.call(rbind,pairs)
save_lta(cover,"wave_coverage.csv");save_lta(sm,"panel_summary.csv");save_lta(pa,"transition_pair_coverage.csv")
design<-data.frame(
 항목=c("연구질문","단위","연도","상태 의미","국가 측정지표","지역 측정지표","측정모형","상태 수","시간 비교","전이모형","공변량","결측","분류오차","공간의존","DMA 해석","검증과 보고","추가자료","이번 산출 범위"),
 계획=c("지역의 디지털 고용·인적자본·소득 구성 유형이 시간에 따라 유지/전환되는가",
 "국가 EU27은 보조적 기술분석; 동일 NUTS2024 코드 지역은 확장 후보. 같은 코드라도 영토 변경 가능성이 있어 공식 변환표 검토 필요. 국가·연도 행을 독립 표본으로 계산하지 않음",
 "원자료 2017–2025 보존; 우선 동간격 2021–2024 네 시점. 2025 지역 GDP 미확보로 주 파동에서 제외",
 "낮음/높음은 가설적 이름; 결과를 본 뒤 지표 프로파일로 명명. 규제 수용형/회피형으로 선결정하지 않음",
 "ICT 직업 비중, 국민계정 J산업 고용비중, 실업률; 첫 두 지표의 국소의존·중복을 반드시 점검",
 "J산업 고용비중, 25–64세 고등교육 비율, 1인당 PPS GDP 로그; 지역 경제·인적자본 구조를 측정",
 "현재 지표가 연속형이므로 연속형 지표 LTA/잠재프로파일 전이(LPTA)를 우선 검토. 임의 이분화하지 않음",
 "K=1 기준모형, K=2 시작, K=3 민감도. BIC·반복 초기값 안정성·작은 집단·실질 해석을 함께 확인",
 "2021 기준 고정 표준화. 시점별 평균/분산(범주형이면 응답확률)의 동일성 및 부분동일성 검토; 원천 조사단절도 별도 감사",
 "P(S[t+1]=j | S[t]=i) 행렬. 시간동질 전이부터 검토하고 자유 전이와 비교. 관측쌍 수는 전이 추정값이 아님",
 "기준시점 노출도와 시차 통제 후보. 지표로 쓴 GDP를 같은 식에서 설명변수로 중복 사용하지 않음",
 "NA 보존, 0대체/직전값 채움 없음. 관측자료 우도·MAR 가정 검토, 완전사례는 민감도이며 자동 기본표본 아님",
 "최빈 사후상태를 정답처럼 회귀하지 않음. 공동추정 또는 분류오차 보정 절차, entropy는 보조 기준",
 "같은 국가 내 지역 및 공간상관을 고려. NUTS 수를 독립 국가 수로 해석하지 않음; 공간/국가 블록 기반 안정성 점검",
 "2024년 한 시점의 변화로 DMA 인과효과를 식별할 수 없음. 노출도 차이, 비교군, 더 긴 시행 후 자료 필요",
 "Monte Carlo 표본설계·분리도·희소 전이·다중 시작 수렴 확인 후 상태비중·전이확률과 구간 보고",
 "ICT 인력 OD, 기업/투자 이전 이벤트, 연속 지역코드 변환표, 장기간 플랫폼 규제 노출·준수 자료",
 "종단 long/wide 표와 관측가능성·연구설계표 생성. 잠재상태, entropy, BIC, 전이확률은 아직 추정하지 않음"),
 check.names=FALSE)
save_lta(design,"LTA_research_design.csv")
map<-data.frame(scope=rep(c("country","regional"),each=3),
 variable=c(items$country,items$regional),
 source=c("Eurostat isoc_sks_itspt","Eurostat nama_10_a10_e","Eurostat une_rt_a","Eurostat htec_emp_reg2","Eurostat edat_lfse_04","Eurostat nama_10r_2gdp"),
 role="candidate continuous latent-state indicator",scale="original plus fixed-2021 z; not categorical state")
save_lta(map,"indicator_dictionary.csv")
library(ggplot2)
p<-ggplot(cover,aes(factor(year),complete_three,fill=selected_wave))+geom_col(width=.7)+
 geom_text(aes(label=paste0(complete_three,"/",units)),vjust=-.3,size=3.2)+facet_wrap(~scope,ncol=1,scales="free_y")+
 scale_fill_manual(values=c("FALSE"="#a7b4ba","TRUE"="#126e82"),labels=c("Other stored years","Proposed 2021-2024 waves"))+
 scale_y_continuous(expand=expansion(mult=c(0,.16)))+theme_minimal(base_size=12)+theme(legend.position="bottom")+
 labs(title="Longitudinal readiness for a future latent transition study",subtitle="Observed indicator triples, not latent classes or estimated transitions",x="Year",y="Units with all three indicators",fill=NULL)
dma_save_plot(p,"20_lta_longitudinal_coverage",11,7)
print(sm);print(pa)
