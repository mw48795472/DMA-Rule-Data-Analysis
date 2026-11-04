# ============================================================================
# mechanism_plots.R : 추가 자료 로딩 + 그림 21–23 정의(ggplot). 모형 적합 없음.
# ----------------------------------------------------------------------------
# 이 파일은 자료 객체(mechanism_catalog, compliance_events, firm_events, mechanism_flows 등)를
# 만들고 그림 21–23을 등록만 합니다. 표시·저장은 RUN_ALL.R / RUN_MECHANISMS.R이
#   dma_show_plots(21:23); dma_export_plots(21:23)
# 로 수행합니다. 세 ggplot 객체는 mechanism_plots 리스트에도 그대로 남습니다.
# ============================================================================
if (!requireNamespace('ggplot2', quietly=TRUE)) stop('ggplot2가 필요합니다. setup.R을 실행해 주세요.')
library(ggplot2)
source(dma_path('code','00_plot_helpers.R'),encoding='UTF-8')
mi <- dma_path('outputs','mechanisms_20261102','integration')
read_mech <- function(p) read.csv(p, fileEncoding='UTF-8-BOM', check.names=FALSE, stringsAsFactors=FALSE, na.strings=c('','NA'))
mechanism_catalog <- read_mech(file.path(mi,'integration_catalog.csv'))
mechanism_missingness <- read_mech(file.path(mi,'integration_missingness.csv'))
mechanism_bridge <- read_mech(file.path(mi,'country_year_covariate_bridge.csv'))
compliance_events <- read_mech(dma_path('outputs','mechanisms_20261102','compliance','compliance_events.csv'))
compliance_scope <- read_mech(dma_path('outputs','mechanisms_20261102','compliance','compliance_event_country_scope.csv'))
firm_events <- read_mech(dma_path('inputs','mechanisms_20261102','firms','csv','firm_events.csv'))
firm_destinations <- read_mech(dma_path('inputs','mechanisms_20261102','firms','csv','firm_event_destinations.csv'))
flow_dir <- dma_path('outputs','mechanisms_20261102','flows','fresh')
flow_files <- c(migration_inward='migration_inward_od.csv',migration_outward='migration_outward_od.csv',fdi_inward='fdi_inward_od.csv',fdi_outward='fdi_outward_od.csv',foreign_affiliates='fats_inward_control_od.csv')
mechanism_flows <- lapply(flow_files,function(f)read_mech(file.path(flow_dir,f)))
names(mechanism_flows)<-names(flow_files)
stopifnot(!anyDuplicated(compliance_events$event_id), !anyDuplicated(firm_events$event_id), !anyDuplicated(mechanism_bridge[c('country','year')]))
scope <- read_mech(file.path(mi,'figure_compliance_scope.csv'))
cases <- read_mech(file.path(mi,'figure_firm_case_types.csv'))
coverage <- read_mech(file.path(mi,'figure_flow_coverage.csv'))
plot_font <- if (.Platform$OS.type == 'windows') 'Malgun Gothic' else 'sans'
# Windows GDI 장치(png(), windows())에서 "font family not found" 경고가 나지 않도록 글꼴을 등록합니다.
if (.Platform$OS.type == 'windows') suppressWarnings(try(grDevices::windowsFonts(`Malgun Gothic`=grDevices::windowsFont('Malgun Gothic')), silent=TRUE))
base_theme <- theme_minimal(base_size=12, base_family=plot_font) + theme(panel.grid.major.y=element_blank(),plot.title.position='plot')
mechanism_plots <- list(
  compliance_scope = ggplot(scope,aes(x=geographic_scope_code,y=count,fill=record_kind)) + geom_col() + coord_flip() + labs(title='Observed compliance evidence by geographic scope',subtitle='13 selected records; a scope snapshot is not an adoption event',x=NULL,y='Records',fill='Evidence type') + base_theme,
  firm_case_types = ggplot(cases,aes(x=reorder(event_kind,count),y=count)) + geom_col(fill='#176b79') + geom_text(aes(label=count),hjust=-.2) + coord_flip() + scale_y_continuous(expand=expansion(mult=c(0,.15))) + labs(title='Selected firm cases by event type',subtitle='11 cases; no sampling denominator or verified physical completion',x=NULL,y='Cases') + base_theme,
  flow_coverage = ggplot(coverage,aes(x=reorder(label,observed_pct),y=observed_pct)) + geom_col(fill='#176b79') + geom_text(aes(label=sprintf('%.1f%%',observed_pct)),hjust=-.1) + coord_flip() + scale_y_continuous(limits=c(0,105)) + labs(title='Observed values within each source-specific dyad frame',subtitle='Different units and dimensions; this is data availability, not flow volume',x=NULL,y='Observed values (%)') + base_theme
)
# 기존 20개와 같은 목록에 번호 21~23으로 등록합니다. show_dma_plot(21) 등으로 선택할 수 있습니다.
for (i in seq_along(mechanism_plots)) local({
  nm <- names(mechanism_plots)[i]
  dma_register(sprintf('%02d_%s',20L+i,nm),width=10,height=5.5,dpi=160,build=function() mechanism_plots[[nm]])
})
# figures/에 저장된 21–23 PNG를 integration/r_figures/ 에도 복사합니다(기존 산출 위치 유지).
dma_export_mechanism_copies <- function() {
  dir.create(file.path(mi,'r_figures'),showWarnings=FALSE)
  for (nm in names(mechanism_plots)) {
    src <- dma_path('figures',sprintf('%02d_%s.png',20L+match(nm,names(mechanism_plots)),nm))
    if (file.exists(src)) file.copy(src,file.path(mi,'r_figures',paste0(nm,'.png')),overwrite=TRUE)
  }
  invisible(file.path(mi,'r_figures'))
}
