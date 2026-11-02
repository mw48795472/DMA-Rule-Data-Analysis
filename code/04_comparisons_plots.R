comparison<-do.call(rbind,lapply(results,function(x)x$comparison));save_csv(comparison,"all_model_comparisons.csv")
vifs<-do.call(rbind,lapply(results,function(x)x$vif));save_csv(vifs,"all_vif.csv")
vmax<-aggregate(VIF~group+model,vifs,max);names(vmax)[3]<-"max_VIF";save_csv(vmax,"max_vif.csv")
morans<-do.call(rbind,lapply(results,function(x)x$moran));save_csv(morans,"all_moran.csv")
raw_family<-morans[morans$test=="raw_permutation" & morans$group%in%c("legacy","industry","migration","regional"),]
raw_family$p_BH<-p.adjust(raw_family$p,"BH");raw_family$p_BY<-p.adjust(raw_family$p,"BY");save_csv(raw_family,"raw_moran_multiple_testing.csv")
oldcomp<-read.csv(file.path(root,"reference","spatial_model_comparison.csv"))
cmp<-merge(oldcomp,results$legacy$comparison,by="model",suffixes=c("_v2","_v3"))
reproduction<-data.frame(model=cmp$model,AIC_v2=cmp$AIC_v2,AIC_v3=cmp$AIC_v3,
 AICc_v2=cmp$AICc_v2,AICc_v3=cmp$AICc_v3,logLik_abs_difference=abs(cmp$logLik_v2-cmp$logLik_v3))
stopifnot(all(reproduction$logLik_abs_difference<1e-6));save_csv(reproduction,"legacy_reproduction.csv")
oldw<-read.csv(file.path(root,"reference","weights_main_k4.csv"),check.names=FALSE)
stopifnot(identical(oldw$country,results$legacy$sample$id))
wdiff<-max(abs(as.matrix(oldw[,-1])-results$legacy$weights));stopifnot(wdiff<1e-12)
save_csv(data.frame(test="legacy_W_max_abs_difference",value=wdiff,passed=TRUE),"weight_reproduction.csv")
effects<-do.call(rbind,lapply(results,function(x)x$impacts));save_csv(effects,"all_impacts.csv")
quality<-do.call(rbind,lapply(names(results),function(id){
 dd<-results[[id]]$sample;fcols<-grep("_flag$",names(dd),value=TRUE)
 do.call(rbind,lapply(fcols,function(v)data.frame(group=id,id=dd$id,variable=sub("_flag$","",v),flag=dd[[v]])))
}));save_csv(quality[!is.na(quality$flag)&nzchar(quality$flag),],"sample_quality_flags.csv")
library(ggplot2)
source(dma_path("code","00_plot_helpers.R"),encoding="UTF-8")
theme_set(theme_minimal(base_size=12))
save_plot<-function(p,name,width=10,height=6) dma_save_plot(p,name,width,height)
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
regional_map$plot_value<-ifelse(regional_map$NUTS_ID%in%results$regional$sample$id,regional_map$regional_j_share_pct,NA_real_)
p<-ggplot(regional_map)+geom_sf(aes(fill=plot_value),color="white",linewidth=.08)+coord_sf(xlim=c(-25,45),ylim=c(34,72),expand=FALSE)+
 scale_fill_viridis_c(na.value="grey85")+labs(title="Regional information-sector employment, 2024",subtitle="NUTS2024 codes only; historical codes were not force-matched",fill="Employment %")+theme(axis.text=element_blank(),axis.title=element_blank(),panel.grid=element_blank())
save_plot(p,"08_regional_outcome",10,7)
bb<-do.call(rbind,lapply(names(results),function(id)read.csv(file.path(out,id,"residual_bootstrap.csv"))))
p<-ggplot(bb,aes(I,model))+geom_vline(xintercept=0,linetype=2,color="grey60")+geom_point(color="#126e82",size=2.4)+
 geom_text(aes(label=sprintf("p=%.3f",p_bootstrap)),nudge_y=.25,size=3)+facet_wrap(~group,ncol=2,scales="free_x")+
 scale_x_continuous(expand=expansion(mult=.18))+
 labs(title="Spatial structure remaining in model innovations",subtitle="Residual bootstrap repetitions are reported separately in outputs/*/residual_bootstrap.csv",x="Innovation Moran's I",y=NULL)
save_plot(p,"09_residual_diagnostics",12,10)
ss<-do.call(rbind,lapply(names(results),function(id)read.csv(file.path(out,id,"k_sensitivity.csv"))))
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
summary<-list(version="3.0",analysis_date="2026-11-02",raw_data_dates=c("2026-10-28","2026-11-01"),
 country_rows=nrow(panel),region_rows=nrow(regional),regional_unmatched_codes=length(unique(region_audit$geo[!region_audit$has_geometry])),
 group_n=sapply(results,function(x)x$n),max_vif=vmax,moran=morans,raw_moran_family=raw_family,
 comparisons=comparison,legacy_reproduction=reproduction,parameter_interval=interval,
 bootstrap_national=cfg$bootstrap_national,bootstrap_regional=cfg$bootstrap_regional,
 note="Descriptive PoC, not DMA causal identification. AIC comparisons across different outcomes or samples are invalid.")
jsonlite::write_json(summary,file.path(out,"summary_v3.json"),auto_unbox=TRUE,pretty=TRUE,digits=12)
