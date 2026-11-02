# Data-only review. No regression, spatial model or bootstrap is fitted.
if (!requireNamespace('ggplot2', quietly=TRUE)) stop('ggplot2가 필요합니다. setup.R을 실행해 주세요.')
library(ggplot2)
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
base_theme <- theme_minimal(base_size=12, base_family=plot_font) + theme(panel.grid.major.y=element_blank(),plot.title.position='plot')
mechanism_plots <- list(
  compliance_scope = ggplot(scope,aes(x=geographic_scope_code,y=count,fill=record_kind)) + geom_col() + coord_flip() + labs(title='Observed compliance evidence by geographic scope',subtitle='13 selected records; a scope snapshot is not an adoption event',x=NULL,y='Records',fill='Evidence type') + base_theme,
  firm_case_types = ggplot(cases,aes(x=reorder(event_kind,count),y=count)) + geom_col(fill='#176b79') + geom_text(aes(label=count),hjust=-.2) + coord_flip() + scale_y_continuous(expand=expansion(mult=c(0,.15))) + labs(title='Selected firm cases by event type',subtitle='11 cases; no sampling denominator or verified physical completion',x=NULL,y='Cases') + base_theme,
  flow_coverage = ggplot(coverage,aes(x=reorder(label,observed_pct),y=observed_pct)) + geom_col(fill='#176b79') + geom_text(aes(label=sprintf('%.1f%%',observed_pct)),hjust=-.1) + coord_flip() + scale_y_continuous(limits=c(0,105)) + labs(title='Observed values within each source-specific dyad frame',subtitle='Different units and dimensions; this is data availability, not flow volume',x=NULL,y='Observed values (%)') + base_theme
)
dir.create(file.path(mi,'r_figures'),showWarnings=FALSE)
for(nm in names(mechanism_plots)) {
  print(mechanism_plots[[nm]])
  ggsave(file.path(mi,'r_figures',paste0(nm,'.png')),mechanism_plots[[nm]],width=10,height=5.5,dpi=160)
}
print(mechanism_catalog[c('domain','path','rows','year_min','year_max')],row.names=FALSE)
cat('\n완료: 세 자료층은 별도 객체로 로드됩니다. mechanism_plots에서 그림을 확인하세요.\n')
cat('새 인과모형은 실행하지 않았고 기존 분석 결과는 변경하지 않았습니다.\n')
