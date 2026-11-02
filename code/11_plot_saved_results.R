# 그래프 전용: 저장된 CSV/SHP에서 ggplot 객체를 새로 만듭니다.
# RUN_PLOTS.R이 이 파일을 실행합니다. 분석/부트스트랩을 재실행하지 않습니다.
library(ggplot2)
library(sf)
sf::sf_use_s2(FALSE)
source(dma_path("code","00_plot_helpers.R"),encoding="UTF-8")
out<-dma_path("outputs");fig<-dma_path("figures");cfg<-dma_read_json("config.json")
read_plot_csv<-function(nm)read.csv(dma_path("outputs",nm,must_exist=TRUE),fileEncoding="UTF-8-BOM",check.names=FALSE,stringsAsFactors=FALSE)
groups<-c("legacy","augmented","parsimonious","industry","migration","regional")
coverage<-read_plot_csv("combined_missingness.csv")
region_audit<-read_plot_csv("region_code_audit.csv")
vmax<-read_plot_csv("max_vif.csv")
comparison<-read_plot_csv("all_model_comparisons.csv")
raw_family<-read_plot_csv("raw_moran_multiple_testing.csv")
effects<-read_plot_csv("all_impacts.csv")
panel<-read_plot_csv("combined_country_year.csv")
main<-panel[panel$year==cfg$year & panel$sample_eu27==1,]
regional<-read_plot_csv("combined_region_year.csv");rr<-regional[regional$year==cfg$year,]
g<-sf::st_make_valid(sf::st_read(dma_path("inputs","base","spatial","EUROPE32_2024_4326.shp",must_exist=TRUE),quiet=TRUE))
clip<-suppressWarnings(sf::st_crop(g,c(xmin=-25,ymin=34,xmax=45,ymax=72)))
regional_shp<-list.files(dma_path("inputs","additional","spatial","nuts2_2024"),"[.]shp$",full.names=TRUE,recursive=TRUE)
stopifnot(length(regional_shp)==1L)
rg<-sf::st_make_valid(sf::st_read(regional_shp,quiet=TRUE))
theme_set(theme_minimal(base_size=12))
save_plot<-function(p,name,width=10,height=6) dma_save_plot(p,name,width,height)

# ---- 그림 01–11: 결측, VIF, 모형 비교, Moran, 효과 및 공간 분포 ----
cov<-coverage[coverage$scope=="EU27",];cov$pct<-100*cov$observed/cov$n
cov$label<-paste0(cov$observed,"/",cov$n)
p<-ggplot(cov,aes(factor(year),variable,fill=pct))+geom_tile(color="white")+geom_text(aes(label=label,color=ifelse(pct>60,"white","#18313b")),size=3)+scale_color_identity()+
 scale_fill_gradient(low="#f7e4d3",high="#126e82",limits=c(0,100))+
 labs(title="Availability after joining the additional data",subtitle="EU27 country-year observations; no imputation",x="Year",y=NULL,fill="Observed %")+
 theme(axis.text.y=element_text(size=9))
save_plot(p,"01_missingness",12,7)
ra<-region_audit[!duplicated(region_audit$geo),];bar<-as.data.frame(table(ra$reason));names(bar)<-c("reason","codes")
p<-ggplot(bar,aes(codes,reorder(reason,codes)))+geom_col(fill="#126e82")+geom_text(aes(label=codes),hjust=-.2)+
 scale_x_continuous(expand=expansion(mult=c(0,.15)))+
 labs(title="Regional code audit against NUTS 2024 boundaries",subtitle="Distinct codes, including historical and extra-regio codes",x="Distinct regional codes",y=NULL)
save_plot(p,"02_region_code_audit",11,5)
vv<-vmax[vmax$group%in%c("legacy","augmented","parsimonious") & vmax$model%in%c("OLS","SDM_full","SDM_exposure"),]
vv$group<-factor(vv$group,levels=c("legacy","augmented","parsimonious"))
p<-ggplot(vv,aes(max_VIF,model))+geom_vline(xintercept=5,linetype=2,color="#b77a37")+geom_point(size=3,color="#126e82")+
 geom_text(aes(label=sprintf("%.2f",max_VIF)),nudge_y=.22,size=3.3)+facet_wrap(~group,nrow=1)+
 scale_x_log10()+labs(title="Collinearity in local X and spatially lagged WX",subtitle="Log scale; standardization does not change VIF; 5 is a screening reference",x="Maximum VIF",y=NULL)
save_plot(p,"03_vif_comparison",12,4.8)
cc<-comparison[comparison$group%in%c("legacy","augmented","parsimonious"),]
cc$group<-factor(cc$group,levels=c("legacy","augmented","parsimonious"))
p<-ggplot(cc,aes(AICc,model,color=group,shape=near_boundary,group=group))+geom_point(position=position_dodge(width=.45),size=3)+
 scale_color_manual(values=c(legacy="#536a74",augmented="#126e82",parsimonious="#b77a37"))+
 scale_shape_manual(values=c(`FALSE`=16,`TRUE`=17),labels=c(`FALSE`="Interior",`TRUE`="Near bound"))+
 labs(title="Original and extended models on the same EU27 sample",subtitle="Same ICT outcome and k=4 W; triangles flag boundary estimates",x="AICc (heuristic; lower is better)",y=NULL,color="Specification",shape="Spatial parameter")
save_plot(p,"04_national_model_comparison",11,5.5)
p<-ggplot(raw_family,aes(I,reorder(group,I)))+geom_vline(xintercept=0,linetype=2,color="grey60")+
 geom_point(size=3,color="#126e82")+geom_text(aes(label=sprintf("n=%d; p=%.4f; BH=%.4f",n,p,p_BH),hjust=ifelse(I>.15,1,0)),nudge_y=.24,size=3.6)+
 labs(title="Raw spatial autocorrelation across distinct outcomes",subtitle="9,999 random-label permutations; four exploratory tests",x="Moran's I",y=NULL)
save_plot(p,"05_raw_moran",10,5)
ee<-effects[effects$group%in%c("legacy","augmented","parsimonious") & effects$model=="SDM_exposure" & effects$term=="z_exposure",]
ee$effect<-factor(ee$effect,levels=c("direct","indirect","total"))
ee$group<-factor(ee$group,levels=c("parsimonious","augmented","legacy"))
p<-ggplot(ee,aes(estimate,group))+geom_vline(xintercept=0,linetype=2,color="grey55")+
 geom_errorbar(aes(xmin=lower,xmax=upper),orientation="y",width=.15,color="#126e82")+geom_point(color="#126e82",size=2.8)+facet_wrap(~effect,scales="free_x",nrow=1)+
 labs(title="Exposure effects under the restricted SDM",subtitle="ICT share pp per exposure pp; 999 model-refitted bootstrap draws",caption="Conditional associations. Changing the local controls changes the estimand; model-selection uncertainty is not included.",x="Effect and 95% percentile interval",y=NULL)
save_plot(p,"06_exposure_impacts",12,5)
national<-merge(clip,main,by.x="COUNTRY",by.y="country",all.x=TRUE)
mapdata<-rbind(transform(national,value=ict_share_pct,measure="ICT occupation share"),transform(national,value=employment_na_j_share_pct,measure="Information-sector employment share"))
p<-ggplot(mapdata)+geom_sf(aes(fill=value),color="white",linewidth=.15)+coord_sf(xlim=c(-25,45),ylim=c(34,72),expand=FALSE)+
 scale_fill_viridis_c(na.value="grey85")+facet_wrap(~measure,nrow=1)+labs(title="Two different measures of the digital workforce, 2024",fill="Employment %",caption="Grey: outside the EU27 main sample or missing. Occupation and industry concepts differ.")+theme(axis.text=element_blank(),axis.title=element_blank(),panel.grid=element_blank())
save_plot(p,"07_country_outcomes",12,6)
regional_map<-merge(rg,rr,by.x="NUTS_ID",by.y="geo",all.x=TRUE)
regional_map$plot_value<-ifelse(regional_map$NUTS_ID%in%read_plot_csv("regional/sample.csv")$id,regional_map$regional_j_share_pct,NA_real_)
p<-ggplot(regional_map)+geom_sf(aes(fill=plot_value),color="white",linewidth=.08)+coord_sf(xlim=c(-25,45),ylim=c(34,72),expand=FALSE)+
 scale_fill_viridis_c(na.value="grey85")+labs(title="Regional information-sector employment, 2024",subtitle="NUTS2024 codes only; historical codes were not force-matched",fill="Employment %")+theme(axis.text=element_blank(),axis.title=element_blank(),panel.grid=element_blank())
save_plot(p,"08_regional_outcome",10,7)
bb<-do.call(rbind,lapply(groups,function(id)read.csv(file.path(out,id,"residual_bootstrap.csv"))))
p<-ggplot(bb,aes(I,model))+geom_vline(xintercept=0,linetype=2,color="grey60")+geom_point(color="#126e82",size=2.4)+
 geom_text(aes(label=sprintf("p=%.4f",p_bootstrap)),nudge_y=.25,size=3)+facet_wrap(~group,ncol=2,scales="free_x")+
 scale_x_continuous(expand=expansion(mult=.18))+
 labs(title="Spatial structure remaining in model innovations",subtitle="Bootstrap draws: national 999; regional SDM 9,999; other regional models 199",x="Innovation Moran's I",y=NULL)
save_plot(p,"09_residual_diagnostics",12,10)
ss<-do.call(rbind,lapply(groups,function(id)read.csv(file.path(out,id,"k_sensitivity.csv"))))
p<-ggplot(ss,aes(k,delta_AICc,color=model,group=model))+geom_line(linewidth=.6)+geom_point(size=2)+
 facet_wrap(~group,ncol=2,scales="free_y")+scale_x_continuous(breaks=3:5)+
 labs(title="Sensitivity to the neighbour definition",subtitle="Delta AICc is computed separately within each outcome, specification and k",x="k before symmetric union",y="Delta AICc",color="Model")
save_plot(p,"10_k_sensitivity",12,10)
# Explicit migration map on the full EU27 frame, missing countries remain grey.
p<-ggplot(national)+geom_sf(aes(fill=asinh_immigration_15_64_complet_per1000),color="white",linewidth=.15)+
 coord_sf(xlim=c(-25,45),ylim=c(34,72),expand=FALSE)+scale_fill_viridis_c(na.value="grey85")+
 labs(title="Immigration intensity, ages 15-64 (COMPLET), 2024",subtitle="asinh(immigration / two-January population mean x 1,000)",fill="asinh rate",caption="General migration, not ICT-worker mobility; grey indicates missing data or non-EU countries.")+
 theme(axis.text=element_blank(),axis.title=element_blank(),panel.grid=element_blank())
save_plot(p,"11_migration_outcome",10,7)

# ---- 그림 12: 저장된 모수 경계 민감도 ----
profiles<-read_plot_csv("boundary_profile.csv")
 p<-ggplot(profiles,aes(parameter,relative_logLik))+geom_line(color="#126e82",linewidth=.7)+
  geom_vline(xintercept=-.999,linetype=2,color="#b77a37")+facet_wrap(~group+model,scales="free_x")+
  coord_cartesian(ylim=c(-10,0))+labs(title="Likelihood sensitivity to the spatial-parameter bound",
   subtitle="Separate eigenvalue-branch check; dashed line is the original -0.999 constraint",
   x="Spatial parameter",y="Log-likelihood relative to the best grid value")
 save_plot(p,"12_boundary_profiles",11,7)

# ---- 그림 13: 부트스트랩 반복 횟수 ----
bs<-read_plot_csv("regional_sdm_bootstrap_comparison.csv")
p<-ggplot(bs,aes(simulations,p_bootstrap))+geom_hline(yintercept=.05,linetype=2,color="#c43e2e")+
 geom_errorbar(aes(ymin=MC_lower,ymax=MC_upper),width=0,color="#126e82")+geom_line(color="#126e82")+geom_point(size=3,color="#126e82")+
 geom_text(aes(label=sprintf("p = %.4f",p_bootstrap)),nudge_y=.009,size=3.6)+
 scale_x_log10(breaks=bs$simulations,labels=format(bs$simulations,big.mark=",",trim=TRUE))+
 scale_y_continuous(limits=c(0,.145))+theme_minimal(base_size=12)+
 labs(title="Regional SDM: residual Moran test with more bootstrap draws",subtitle="Same 218 regions, y, X, W and random stream; only simulation precision changes",
 x="Bootstrap repetitions (log scale)",y="Two-sided bootstrap p-value",caption="Bars: Monte Carlo uncertainty in the smaller tail (not a policy-effect confidence interval). Red: 0.05.")
dma_save_plot(p,"13_regional_bootstrap_precision",10,6)

# ---- 그림 14–19: 이입 정의, 영국/비EU, 포르투갈 및 국가별 Moran ----
dat<-read_plot_csv("migration_extension/migration_europe_2024.csv")
eu<-dat$country[dat$eu27]
g<-sf::st_read(dma_path("outputs","migration_extension","EUROPE42_2024.gpkg",must_exist=TRUE),quiet=TRUE)
clip<-suppressWarnings(sf::st_crop(g,c(xmin=-25,ymin=34,xmax=45,ymax=72)))
maps<-merge(clip,dat,by="country",all.x=TRUE,sort=FALSE)
centdata<-dat[complete.cases(dat[c("x_m","y_m")]),c("country","x_m","y_m")]
cent<-sf::st_as_sf(centdata,coords=c("x_m","y_m"),crs=3035)
theme_set(theme_minimal(base_size=12))
savefig<-function(p,nm,w=11,h=7) dma_save_plot(p,nm,w,h)
maptheme<-theme(axis.text=element_blank(),axis.title=element_blank(),panel.grid=element_blank())
eu_map<-maps[maps$eu27,]
dual<-rbind(transform(eu_map,value=asinh(rate_complet),definition="COMPLET: age at last birthday"),transform(eu_map,value=asinh(rate_reach),definition="REACH: age reached during year"))
p<-ggplot(dual)+geom_sf(aes(fill=value),color="white",linewidth=.15)+facet_wrap(~definition,nrow=1)+coord_sf(xlim=c(-25,45),ylim=c(34,72),expand=FALSE)+scale_fill_viridis_c(na.value="grey85")+maptheme+
 labs(title="Why countries were missing from Figure 7",subtitle="2024, ages 15-64; the two age definitions are kept separate",fill="asinh(rate)",caption="Rate per 1,000 residents aged 15-64. Grey means unavailable under that definition.")
savefig(p,"14_age_definition_maps",12,6.5)
eu_labels<-merge(sf::st_transform(cent,4326),dat[c("country","age_definition_selected")],by="country")
p<-ggplot(eu_map)+geom_sf(aes(fill=asinh(rate_15_64_coverage)),color="white",linewidth=.15)+
 geom_sf(data=eu_labels[eu_labels$country%in%eu & !is.na(eu_labels$age_definition_selected) & eu_labels$age_definition_selected=="REACH",],shape=21,fill="white",color="#b36b21",size=2,stroke=.8)+
 coord_sf(xlim=c(-25,45),ylim=c(34,72),expand=FALSE)+scale_fill_viridis_c(na.value="grey85")+maptheme+
 labs(title="EU coverage supplement: immigration intensity, 2024",subtitle="COMPLET where available; REACH fallback is marked by a circle",fill="asinh(rate)",caption="Exploratory mixed-definition map; it does not replace the original COMPLET regression.")
savefig(p,"15_eu_coverage_supplement",10,7)
p<-ggplot(maps)+geom_sf(aes(fill=rate_all_ages),color="white",linewidth=.16)+
 geom_sf(data=maps[!maps$eu27 & is.finite(maps$rate_all_ages),],fill=NA,color="#a65d13",linewidth=.6)+
 coord_sf(xlim=c(-25,45),ylim=c(34,72),expand=FALSE)+scale_fill_viridis_c(na.value="grey85")+maptheme+
 labs(title="Immigration intensity across Europe, including the UK",subtitle="2024, all ages and all citizenships; orange border = non-EU data",fill="Per 1,000",caption="Eurostat two-January population mean; UK uses revised ONS mid-year population. Grey: unavailable.")
savefig(p,"16_europe_all_age_migration",11,7)
nd<-dat[!dat$eu27 & is.finite(dat$rate_all_ages),];nd$source_group<-ifelse(nd$country=="UK","UK: ONS / mid-year population","Eurostat / two-January mean")
p<-ggplot(nd,aes(rate_all_ages,reorder(country_name,rate_all_ages),color=source_group))+geom_point(size=3)+
 geom_text(aes(label=sprintf(" %.2f",rate_all_ages)),hjust=0,nudge_x=.3,size=3.8,show.legend=FALSE)+scale_x_continuous(expand=expansion(mult=c(.03,.18)))+
 scale_color_manual(values=c("#126e82","#b36b21"))+theme(legend.position="bottom")+
 labs(title="Verified non-EU immigration rates, 2024",subtitle="All ages, all citizenships; only countries with an observed numerator and denominator",x="Immigrants per 1,000 residents",y=NULL,color=NULL)
savefig(p,"17_non_eu_migration_rates",11,6)
supp<-rbind(transform(maps[maps$eu27,],value=asinh(rate_15_64_plus_PT),scope="EU27: ages 15-64, mixed definitions"),
 transform(maps,value=asinh(rate_all_ages_plus_PT),scope="Europe: all ages, national supplements"))
p<-ggplot(supp)+geom_sf(aes(fill=value),color="white",linewidth=.15)+
 geom_sf(data=supp[supp$country=="PT",],fill=NA,color="#c43e2e",linewidth=.9)+facet_wrap(~scope,nrow=1)+
 coord_sf(xlim=c(-25,45),ylim=c(34,72),expand=FALSE)+scale_fill_viridis_c(na.value="grey85")+maptheme+
 labs(title="Portugal restored using revised national statistics",subtitle="Red outline: Portugal INE numerator and matching revised population series",fill="asinh(rate)",
 caption="Sensitivity only: COMPLET / REACH / INE age definitions differ. UK appears only in the all-age panel.")
savefig(p,"19_portugal_national_supplement",12,6.5)

mor<-read_plot_csv("migration_extension/migration_moran_tests.csv")
mr<-mor[mor$k==4,]
p<-ggplot(mr,aes(I,reorder(sample,I)))+geom_vline(xintercept=0,linetype=2,color="grey60")+geom_point(size=3,color="#126e82")+
 geom_text(aes(label=sprintf("n=%d; p=%.4f",n,p),hjust=ifelse(I>mean(range(I)),1,0)),nudge_y=.25,size=3.5)+
 labs(title="Spatial autocorrelation under alternative coverage choices",subtitle="asinh(rate), k=4 symmetric union, 9,999 permutations; samples and W differ",x="Moran's I",y=NULL)
savefig(p,"18_migration_moran_comparison",11,6)

# ---- 그림 20: LTA 종단 자료의 관측 가능성 (잠재상태 추정 아님) ----
cover<-read_plot_csv("lta_design/wave_coverage.csv")
p<-ggplot(cover,aes(factor(year),complete_three,fill=selected_wave))+geom_col(width=.7)+
 geom_text(aes(label=paste0(complete_three,"/",units)),vjust=-.3,size=3.2)+facet_wrap(~scope,ncol=1,scales="free_y")+
 scale_fill_manual(values=c("FALSE"="#a7b4ba","TRUE"="#126e82"),labels=c("Other stored years","Proposed 2021-2024 waves"))+
 scale_y_continuous(expand=expansion(mult=c(0,.16)))+theme_minimal(base_size=12)+theme(legend.position="bottom")+
 labs(title="Longitudinal readiness for a future latent transition study",subtitle="Observed indicator triples, not latent classes or estimated transitions",x="Year",y="Units with all three indicators",fill=NULL)
dma_save_plot(p,"20_lta_longitudinal_coverage",11,7)
