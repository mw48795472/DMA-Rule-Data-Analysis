# New values are rebuilt from source CSV. The delivered derived table is a cross-check.
read_add <- function(nm,sub="csv") read.csv(file.path(root,"inputs","additional",sub,nm),
 fileEncoding="UTF-8-BOM",na.strings=c("",":"),check.names=FALSE,colClasses="character")
pop <- read_add("population_single_age.csv")
pop$value<-as.numeric(pop$value); pop$time<-as.integer(pop$time)
stopifnot(!anyDuplicated(pop[c("geo","time","age","sex","unit")]))
additions<-unique(panel[c("country","year")]);additions<-additions[order(additions$country,additions$year),]
pop_value<-function(cc,yy,age=NULL){
 rr<-pop[pop$geo==cc & pop$time==yy & pop$age %in% if(is.null(age)) paste0("Y",15:64) else age,]
 need<-if(is.null(age))50L else 1L
 if(nrow(rr)==need && all(is.finite(rr$value)))sum(rr$value) else NA_real_
}
additions$population_15_64_jan1<-mapply(pop_value,additions$country,additions$year)
next_pop<-mapply(pop_value,additions$country,additions$year+1L)
additions$population_15_64_annual_mean_approx<-(additions$population_15_64_jan1+next_pop)/2
additions$population_total_jan1<-mapply(function(c,y)pop_value(c,y,"TOTAL"),additions$country,additions$year)
add_series<-function(file,filters,name,mult=1){
 rr<-read_add(file)
 for(k in names(filters))rr<-rr[!is.na(rr[[k]]) & rr[[k]]==filters[[k]],,drop=FALSE]
 stopifnot(!anyDuplicated(rr[c("geo","time")]))
 z<-data.frame(country=rr$geo,year=as.integer(rr$time),v=as.numeric(rr$value)*mult,flag=ifelse(is.na(rr$status),"",rr$status))
 names(z)[3:4]<-c(name,paste0(name,"_flag"))
 additions<<-merge(additions,z,by=c("country","year"),all.x=TRUE,sort=FALSE)
}
add_series("employment_lfs.csv",list(age="Y15-64",sex="T",citizen="TOTAL",unit="THS_PER"),"employment_lfs_15_64_persons",1000)
add_series("employment_lfs.csv",list(age="Y_GE15",sex="T",citizen="TOTAL",unit="THS_PER"),"employment_lfs_15plus_persons",1000)
add_series("employment_national_accounts.csv",list(nace_r2="TOTAL",na_item="EMP_DC",unit="THS_PER"),"employment_na_total_persons",1000)
add_series("employment_national_accounts.csv",list(nace_r2="J",na_item="EMP_DC",unit="THS_PER"),"employment_na_j_persons",1000)
additions$employment_na_j_share_pct<-100*additions$employment_na_j_persons/additions$employment_na_total_persons
delivered<-read_add("country_year_additions.csv","derived")
delivered$year<-as.integer(delivered$year)
checkvars<-names(additions)[vapply(additions,is.numeric,logical(1))]
rebuild_new<-merge(additions,delivered,by=c("country","year"),suffixes=c("_new","_delivered"))
checks<-do.call(rbind,lapply(setdiff(checkvars,"year"),function(v){
 a<-rebuild_new[[paste0(v,"_new")]]; b<-as.numeric(rebuild_new[[paste0(v,"_delivered")]])
 data.frame(variable=v,matching=isTRUE(all.equal(a,b,tolerance=1e-10,check.attributes=FALSE)))
}))
save_csv(checks,"additional_rebuild_validation.csv");stopifnot(all(checks$matching))
before<-panel
stopifnot(nrow(additions)==288L,!anyDuplicated(additions[c("country","year")]))
panel<-merge(panel,additions,by=c("country","year"),all.x=TRUE,sort=FALSE)
panel<-panel[order(panel$country,panel$year),];rownames(panel)<-NULL
stopifnot(nrow(panel)==288L,!anyDuplicated(panel[c("country","year")]))
bb<-split(panel[panel$year %in% 2017:2019,],panel$country[panel$year %in% 2017:2019])
pre_j<-sapply(bb,function(x)if(nrow(x)==3 && all(is.finite(x$employment_na_j_share_pct)))mean(x$employment_na_j_share_pct) else NA_real_)
panel$pre_j_share_pct<-unname(pre_j[panel$country])
for(def in c("complet","reach"))for(direction in c("immigration","emigration")){
 v<-paste0(direction,"_15_64_",def)
 panel[[paste0(v,"_per1000")]]<-1000*panel[[v]]/panel$population_15_64_annual_mean_approx
 panel[[paste0("asinh_",v,"_per1000")]]<-asinh(panel[[paste0(v,"_per1000")]])
}
save_csv(panel,"combined_country_year.csv")
join_audit<-data.frame(country=panel$country,year=panel$year,base_present=TRUE,
 additional_key_present=paste(panel$country,panel$year)%in%paste(additions$country,additions$year),
 country_geometry_present=panel$country%in%g$COUNTRY)
save_csv(join_audit,"country_join_audit.csv")
focusvars<-c("ict_share_pct","exposure_pre_2017_2019_pct","gdp_pc_pps","hourly_labour_cost_j_eur","unemployment_pct","pre_j_share_pct","employment_na_j_share_pct","population_15_64_annual_mean_approx","immigration_15_64_complet_per1000","immigration_15_64_reach_per1000","fdi_inward_j_pct_gdp")
coverage<-do.call(rbind,lapply(c("EU27","Europe32"),function(scope)do.call(rbind,lapply(2017:2025,function(y){
 dd<-panel[panel$year==y & (scope=="Europe32" | panel$sample_eu27==1),]
 data.frame(scope=scope,year=y,variable=focusvars,n=nrow(dd),observed=sapply(dd[focusvars],function(x)sum(is.finite(x))),
 missing=sapply(dd[focusvars],function(x)sum(!is.finite(x))))
}))))
save_csv(coverage,"combined_missingness.csv")
missing_cells<-do.call(rbind,lapply(focusvars,function(v)data.frame(country=panel$country,year=panel$year,variable=v,missing=!is.finite(panel[[v]]))))
save_csv(missing_cells,"country_missing_cells.csv")

# Region-level variables remain region-level; no national value is copied into regional records.
region_names<-c("regional_gdp.csv","regional_hightech_employment.csv","regional_tertiary_education.csv")
region_sources<-lapply(region_names,read_add);names(region_sources)<-region_names
reg_codes<-sort(unique(unlist(lapply(region_sources,function(x)x$geo))))
regional<-expand.grid(geo=reg_codes,year=2017:2025,stringsAsFactors=FALSE)
reg_add<-function(file,filters,name){
 rr<-region_sources[[file]]
 for(k in names(filters))rr<-rr[!is.na(rr[[k]]) & rr[[k]]==filters[[k]],,drop=FALSE]
 stopifnot(!anyDuplicated(rr[c("geo","time")]))
 z<-data.frame(geo=rr$geo,year=as.integer(rr$time),v=as.numeric(rr$value),flag=ifelse(is.na(rr$status),"",rr$status))
 names(z)[3:4]<-c(name,paste0(name,"_flag"))
 regional<<-merge(regional,z,by=c("geo","year"),all.x=TRUE,sort=FALSE)
}
reg_add("regional_gdp.csv",list(unit="PPS_EU27_2020_HAB"),"regional_gdp_pc_pps")
reg_add("regional_tertiary_education.csv",list(age="Y25-64",sex="T",isced11="ED5-8",unit="PC"),"tertiary_pct")
reg_add("regional_hightech_employment.csv",list(nace_r2="J",sex="T",unit="PC_EMP"),"regional_j_share_pct")
reg_add("regional_hightech_employment.csv",list(nace_r2="HTC",sex="T",unit="PC_EMP"),"regional_hightech_share_pct")
regional$country<-substr(regional$geo,1,2)
eu27<-unique(panel$country[panel$sample_eu27==1]); regional$sample_eu27<-regional$country%in%eu27
shp<-list.files(file.path(root,"inputs","additional","spatial","nuts2_2024"),"[.]shp$",full.names=TRUE,recursive=TRUE)
rg<-sf::st_read(shp[1],quiet=TRUE); stopifnot(!anyDuplicated(rg$NUTS_ID))
rg_valid<-data.frame(geo=rg$NUTS_ID,valid_before=sf::st_is_valid(rg),empty_before=sf::st_is_empty(rg))
rg<-sf::st_make_valid(rg);rg_valid$valid_after<-sf::st_is_valid(rg);save_csv(rg_valid,"region_geometry_validity.csv")
stopifnot(all(rg_valid$valid_after),!any(sf::st_is_empty(rg)))
rp<-suppressWarnings(sf::st_cast(sf::st_transform(rg,3035),"POLYGON"))
rp$area<-as.numeric(sf::st_area(rp))
rp<-rp[unlist(lapply(split(seq_len(nrow(rp)),rp$NUTS_ID),function(ix)ix[which.max(rp$area[ix])])),]
rc<-suppressWarnings(sf::st_centroid(rp));ll<-sf::st_coordinates(sf::st_transform(rc,4326));xy<-sf::st_coordinates(rc)
rcoords<-data.frame(geo=rc$NUTS_ID,x_m=xy[,1],y_m=xy[,2],lon=ll[,1],lat=ll[,2])
rcoords$in_europe_window<-with(rcoords,lon>=-25 & lon<=45 & lat>=34 & lat<=72)
regional<-merge(regional,rcoords,by="geo",all.x=TRUE,sort=FALSE)
regional$geometry_match<-regional$geo%in%rg$NUTS_ID
regional$log_regional_gdp_pc_pps<-ifelse(regional$regional_gdp_pc_pps>0,log(regional$regional_gdp_pc_pps),NA_real_)
regional<-regional[order(regional$geo,regional$year),];save_csv(regional,"combined_region_year.csv")
region_audit<-do.call(rbind,lapply(names(region_sources),function(nm){
 rr<-region_sources[[nm]]
 do.call(rbind,lapply(split(rr,rr$geo),function(x){
  cc<-x$geo[1];obs<-is.finite(as.numeric(x$value));matched<-cc%in%rg$NUTS_ID
  data.frame(dataset=nm,geo=cc,has_geometry=matched,nonmissing=sum(obs),
    nonmissing_2024=sum(obs & x$time=="2024"),
    reason=if(matched)"code_match_only" else if(grepl("ZZ$",cc))"extra_regio_no_polygon" else if(substr(cc,1,2)=="UK")"UK_not_in_2024_boundary" else "old_or_noncurrent_code_requires_crosswalk")
 }))
}))
save_csv(region_audit,"region_code_audit.csv")
policy_audit<-data.frame(file=c("dma_service_calendar.csv","erm_offshoring_pilot.csv","erm_event_destinations.csv","uk_regulatory_events_selected.csv","platform_scope_pilot.csv"),
 use=c("descriptive_calendar_only","case_context_only","case_context_only","descriptive_legal_context_only","descriptive_scope_only"),
 reason=c("EU-wide service dates lack national exposure variation; iPadOS exact date missing","3 purposively selected events; no exhaustive denominator or DMA causal evidence","destination jobs unallocated; no duplication of event counts","selected UK events do not measure DMA alignment","EU-only announcement does not measure cross-country feature diffusion"))
save_csv(policy_audit,"non_statistical_input_decisions.csv")
note(sprintf("Join audit: %d country-years; %d region-years; %d unmatched distinct regional codes.",nrow(panel),nrow(regional),length(unique(region_audit$geo[!region_audit$has_geometry]))))
