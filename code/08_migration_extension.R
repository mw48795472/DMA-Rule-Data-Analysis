source(dma_path("code","00_plot_helpers.R"),encoding="UTF-8")
library(sf);library(ggplot2);sf::sf_use_s2(FALSE)
ext<-file.path(root,"inputs","extension_20261102");mo<-file.path(out,"migration_extension");dir.create(mo,showWarnings=FALSE)
rd<-function(nm){z<-read.csv(file.path(ext,"csv",nm),fileEncoding="UTF-8-BOM",stringsAsFactors=FALSE,check.names=FALSE,colClasses="character");for(v in intersect(c("time","value","immigration_all_ages","population_midyear"),names(z)))z[[v]]<-as.numeric(z[[v]]);z}
sv<-function(x,nm)write.csv(x,file.path(mo,nm),row.names=FALSE,na="",fileEncoding="UTF-8")
imm<-rd("migr_imm5prv_world_2024.csv");single<-rd("migr_imm8_2024.csv");ctz<-rd("migr_imm1ctz_total_2024.csv");pop<-rd("demo_pjan_2024_2025.csv")
stopifnot(all(imm$sex=="T"),all(imm$unit=="NR"),all(imm$partner=="TOTAL"),all(imm$time==2024))
stopifnot(!anyDuplicated(imm[c("geo","time","agedef","age")]),!anyDuplicated(single[c("geo","time","agedef","age")]),!anyDuplicated(pop[c("geo","time","age")]))
old<-read.csv(file.path(out,"combined_country_year.csv"));old<-old[old$year==2024,]
eu<-sort(old$country[old$sample_eu27==1]);ne<-c("UK","IS","LI","NO","CH","AL","BA","ME","MK","RS","XK","MD","UA","TR","BY","RU")
countries<-c(eu,ne);stopifnot(length(countries)==43,!anyDuplicated(countries))
labels<-dma_read_json(file.path(ext,"metadata","demo_pjan_2024_2025_dimensions.json"))$dimension$geo$category$label
one<-function(z,ages){
 z<-z[z$age%in%ages,];if(nrow(z)!=length(ages)||anyDuplicated(z$age)||any(!is.finite(z$value)))return(NA_real_)
 sum(z$value)
}
age_sum<-function(z){
 a<-one(z,"Y15-64");if(is.finite(a))return(a)
 a<-one(z,paste0("Y",seq(15,60,5),"-",seq(19,64,5)));if(is.finite(a))return(a)
 one(z,paste0("Y",15:64))
}
flags<-function(z){v<-sort(unique(z$status[!is.na(z$status)&nzchar(z$status)]));paste(v,collapse=";")}
gettotal<-function(z){v<-unique(z$value[z$age=="TOTAL" & is.finite(z$value)]);if(length(v)>1)stop("Conflicting all-age totals across age definitions");if(length(v))v else NA_real_}
rows<-lapply(countries,function(cc){
 a<-imm[imm$geo==cc,];b<-single[single$geo==cc,];c<-ctz[ctz$geo==cc,];p<-pop[pop$geo==cc,]
 complete<-age_sum(a[a$agedef=="COMPLET",]);reach<-age_sum(a[a$agedef=="REACH",])
 single_c<-age_sum(b[b$agedef=="COMPLET",]);single_r<-age_sum(b[b$agedef=="REACH",])
 # Fallback only between equivalent datasets within exactly the same age definition.
 cs<-if(is.finite(complete))"migr_imm5prv" else if(is.finite(single_c))"migr_imm8" else NA_character_
 rs<-if(is.finite(reach))"migr_imm5prv" else if(is.finite(single_r))"migr_imm8" else NA_character_
 if(!is.finite(complete))complete<-single_c;if(!is.finite(reach))reach<-single_r
 p24<-one(p[p$time==2024,],paste0("Y",15:64));p25<-one(p[p$time==2025,],paste0("Y",15:64))
 t24<-one(p[p$time==2024,],"TOTAL");t25<-one(p[p$time==2025,],"TOTAL")
 t8<-gettotal(b);tctz<-gettotal(c);t5<-gettotal(a)
 tt<-if(is.finite(t8))t8 else if(is.finite(tctz))tctz else t5
 ts<-if(is.finite(t8))"Eurostat migr_imm8" else if(is.finite(tctz))"Eurostat migr_imm1ctz" else if(is.finite(t5))"Eurostat migr_imm5prv" else NA_character_
 data.frame(country=cc,country_name=if(cc%in%names(labels))labels[[cc]] else cc,year=2024,eu27=cc%in%eu,
  immigration_complet=complete,immigration_reach=reach,complet_source=cs,reach_source=rs,
  single_complet=single_c,single_reach=single_r,immigration_all_ages=tt,total_source=ts,total_migr_imm8=t8,total_migr_imm1ctz=tctz,total_migr_imm5prv=t5,
  population_15_64_jan2024=p24,population_15_64_jan2025=p25,population_15_64_mean=(p24+p25)/2,
  population_total_jan2024=t24,population_total_jan2025=t25,population_total_mean=(t24+t25)/2,
  denominator_method="Eurostat mean of Jan 2024 and Jan 2025",flow_flags=flags(rbind(a[c("status")],b[c("status")],c[c("status")])),population_flags=flags(p))
})
dat<-do.call(rbind,rows)
uk<-rd("uk_ons_2024_all_ages.csv");j<-dat$country=="UK"
dat$immigration_all_ages[j]<-uk$immigration_all_ages;dat$population_total_mean[j]<-uk$population_midyear
dat$total_source[j]<-"ONS LTIM 2026-05-21";dat$denominator_method[j]<-"ONS mid-2024 population, revised 2026-10-01"
dat$flow_flags[j]<-"official_statistics_in_development;rounded_to_1000";dat$population_flags[j]<-"rounded_to_100"
dat$rate_complet<-1000*dat$immigration_complet/dat$population_15_64_mean
dat$rate_reach<-1000*dat$immigration_reach/dat$population_15_64_mean
dat$rate_all_ages<-1000*dat$immigration_all_ages/dat$population_total_mean
dat$age_definition_selected<-ifelse(is.finite(dat$rate_complet),"COMPLET",ifelse(is.finite(dat$rate_reach),"REACH",NA))
dat$rate_15_64_coverage<-ifelse(is.finite(dat$rate_complet),dat$rate_complet,dat$rate_reach)
dat$coverage_note<-ifelse(is.finite(dat$rate_complet),"COMPLET available",ifelse(is.finite(dat$rate_reach),"REACH available; not identical to COMPLET","2024 age-specific numerator or denominator unavailable"))
dat$all_age_note<-ifelse(is.finite(dat$rate_all_ages),ifelse(dat$country=="UK","ONS national estimate; different denominator convention","Eurostat flow and population available"),"2024 comparable numerator or denominator unavailable")
# Keep the harmonised columns unchanged; add the INE revision as an explicit sensitivity.
pt<-read.csv(file.path(ext,"csv","pt_ine_2024_supplement.csv"),fileEncoding="UTF-8-BOM",stringsAsFactors=FALSE)
pt$immigration_indicator<-sprintf("%07d",as.integer(pt$immigration_indicator));pt$population_indicator<-sprintf("%07d",as.integer(pt$population_indicator))
pt$population_15_64_mean<-(pt$population_15_64_end2023+pt$population_15_64_end2024)/2
pt$population_total_mean<-(pt$population_total_end2023+pt$population_total_end2024)/2
pt$rate_15_64<-1000*pt$immigration_15_64/pt$population_15_64_mean
pt$rate_all_ages<-1000*pt$immigration_all_ages/pt$population_total_mean
pt$eurostat_population_15_64_mean<-dat$population_15_64_mean[dat$country=="PT"]
pt$eurostat_population_total_mean<-dat$population_total_mean[dat$country=="PT"]
sv(pt,"portugal_revision_audit.csv")
dat$rate_15_64_plus_PT<-dat$rate_15_64_coverage;dat$rate_all_ages_plus_PT<-dat$rate_all_ages
dat$rate_15_64_plus_PT[dat$country=="PT"]<-pt$rate_15_64;dat$rate_all_ages_plus_PT[dat$country=="PT"]<-pt$rate_all_ages
dat$national_supplement_note<-ifelse(dat$country=="PT","INE 2026 revised flow + revised end-year population; sensitivity only","")
oldtest<-merge(old[c("country","immigration_15_64_complet","immigration_15_64_reach","population_15_64_annual_mean_approx")],dat,by="country")
oldtest$complet_count_change<-oldtest$immigration_complet-oldtest$immigration_15_64_complet
oldtest$reach_count_change<-oldtest$immigration_reach-oldtest$immigration_15_64_reach
oldtest$population_change<-oldtest$population_15_64_mean-oldtest$population_15_64_annual_mean_approx
sv(oldtest[c("country","complet_count_change","reach_count_change","population_change")],"v3_source_comparison.csv")
checks<-dat[c("country","immigration_complet","single_complet","immigration_reach","single_reach","total_migr_imm8","total_migr_imm1ctz","total_migr_imm5prv")]
checks$complet_difference<-checks$immigration_complet-checks$single_complet
checks$reach_difference<-checks$immigration_reach-checks$single_reach
checks$total_difference<-checks$total_migr_imm8-checks$total_migr_imm1ctz
sv(checks,"cross_dataset_checks.csv")
stopifnot(all(abs(checks$complet_difference[is.finite(checks$complet_difference)])<1e-8),all(abs(checks$reach_difference[is.finite(checks$reach_difference)])<1e-8),all(abs(checks$total_difference[is.finite(checks$total_difference)])<1e-8))
g<-sf::st_read(file.path(ext,"raw","CNTR_RG_20M_2024_4326.geojson"),quiet=TRUE)
g$country<-ifelse(g$CNTR_ID=="GR","EL",ifelse(g$CNTR_ID=="GB","UK",g$CNTR_ID))
g<-g[g$country%in%countries,];g<-sf::st_make_valid(g);stopifnot(!anyDuplicated(g$country),all(sf::st_is_valid(g)),setequal(g$country,setdiff(countries,"XK")))
clip<-suppressWarnings(sf::st_crop(g,c(xmin=-25,ymin=34,xmax=45,ymax=72)))
parts<-suppressWarnings(sf::st_cast(sf::st_transform(clip,3035),"POLYGON"));parts$area<-as.numeric(sf::st_area(parts))
parts<-parts[unlist(lapply(split(seq_len(nrow(parts)),parts$country),function(ii)ii[which.max(parts$area[ii])])),]
cent<-suppressWarnings(sf::st_centroid(parts));xy<-sf::st_coordinates(cent)
coords<-data.frame(country=cent$country,x_m=xy[,1],y_m=xy[,2]);dat<-merge(dat,coords,by="country",all.x=TRUE,sort=FALSE)
dat$geometry_present<-dat$country%in%g$country
sv(dat,"migration_europe_2024.csv")
missing_old<-old$country[old$sample_eu27==1 & !is.finite(old$immigration_15_64_complet)]
sv(dat[dat$country%in%missing_old,],"figure7_missing_country_audit.csv")
sv(data.frame(country=countries,geometry_present=countries%in%g$country,note=ifelse(countries%in%g$country,"matched","No separate XK polygon in this downloaded GISCO country layer")),"geometry_audit.csv")
sf::st_write(g,file.path(mo,"EUROPE42_2024.gpkg"),delete_dsn=TRUE,quiet=TRUE)
shpdir<-file.path(mo,"shapefile");dir.create(shpdir,showWarnings=FALSE)
sf::st_write(g[c("country","geometry")],file.path(shpdir,"EUROPE42_2024.shp"),delete_layer=TRUE,quiet=TRUE)
maps<-merge(clip,dat,by="country",all.x=TRUE,sort=FALSE)
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
# Spatial descriptives use fresh W for each explicitly defined sample; no national regression is expanded silently.
specs<-list(EU_COMPLET=list(var="rate_complet",keep=dat$eu27),EU_REACH=list(var="rate_reach",keep=dat$eu27),
 EU_mixed_age=list(var="rate_15_64_coverage",keep=dat$eu27),EU_all_ages=list(var="rate_all_ages",keep=dat$eu27),
 Europe_all_ages=list(var="rate_all_ages",keep=rep(TRUE,nrow(dat))),Europe_without_UK=list(var="rate_all_ages",keep=dat$country!="UK"),
 EU_age_plus_PT=list(var="rate_15_64_plus_PT",keep=dat$eu27),Europe_plus_PT=list(var="rate_all_ages_plus_PT",keep=rep(TRUE,nrow(dat))))
mor<-list()
for(nm in names(specs)){
 s<-specs[[nm]];dd<-dat[s$keep & complete.cases(dat[c(s$var,"x_m","y_m")]),];dd<-dd[order(dd$country),];dd$id<-dd$country
 dd$outcome<-asinh(dd[[s$var]]);stopifnot(nrow(dd)>5)
 sv(dd,paste0("sample_",nm,".csv"))
 for(k in 3:5){w<-make_weights(dd,k);set.seed(cfg$seed)
  mc<-spdep::moran.mc(dd$outcome,w$lw,nsim=9999,alternative="two.sided")
  mor[[length(mor)+1L]]<-data.frame(sample=nm,k=k,n=nrow(dd),I=unname(mc$statistic),p=mc$p.value,simulations=9999,components=spdep::n.comp.nb(w$nb)$nc)
  if(k==4)sv(data.frame(id=dd$id,w$W,check.names=FALSE),paste0("weights_",nm,".csv"))
 }
}
mor<-do.call(rbind,mor);mor$p_BH_k4<-NA_real_;mor$p_BH_k4[mor$k==4]<-p.adjust(mor$p[mor$k==4],"BH");sv(mor,"migration_moran_tests.csv")
mr<-mor[mor$k==4,]
p<-ggplot(mr,aes(I,reorder(sample,I)))+geom_vline(xintercept=0,linetype=2,color="grey60")+geom_point(size=3,color="#126e82")+
 geom_text(aes(label=sprintf("n=%d; p=%.4f",n,p),hjust=ifelse(I>mean(range(I)),1,0)),nudge_y=.25,size=3.5)+
 labs(title="Spatial autocorrelation under alternative coverage choices",subtitle="asinh(rate), k=4 symmetric union, 9,999 permutations; samples and W differ",x="Moran's I",y=NULL)
savefig(p,"18_migration_moran_comparison",11,6)
print(dat[c("country","rate_complet","rate_reach","rate_all_ages","coverage_note")]);print(mor)
