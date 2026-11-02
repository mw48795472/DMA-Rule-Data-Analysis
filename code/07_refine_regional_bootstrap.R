# Hold y, X, W and fitted coefficients fixed. Extend the SAME random stream from B=199.
B<-as.integer(cfg$regional_sdm_residual_bootstrap);stopifnot(B>=199L)
od<-file.path(out,"regional");save_new<-function(x,nm)write.csv(x,file.path(out,nm),row.names=FALSE,na="",fileEncoding="UTF-8")
fits<-readRDS(file.path(od,"models.rds"));f<-fits$SDM_full
d<-read.csv(file.path(od,"sample.csv"),check.names=FALSE)
ww<-read.csv(file.path(od,"weights.csv"),check.names=FALSE);stopifnot(identical(ww$id,d$id))
W<-as.matrix(ww[,-1]);n<-nrow(W);stopifnot(n==218,all(abs(rowSums(W)-1)<1e-12))
zvars<-read.csv(file.path(od,"scaling.csv"))$term;Z<-design_matrix(d,zvars,"SDM_full",W)
rho<-as.numeric(f$rho);beta<-f$coefficients[colnames(Z)];signal<-as.vector(Z%*%beta)
observed_e<-d$outcome-rho*as.vector(W%*%d$outcome)-signal
I_observed<-moran_value(observed_e,W);s2<-mean(observed_e^2)
ev<-Re(eigen(W,only.values=TRUE)$values);H<-solve(diag(n)-rho*W)
base_draw<-read.csv("reference/v3/regional_bootstrap_draws.csv")
base_draw<-base_draw[base_draw$model=="SDM_full",];stopifnot(nrow(base_draw)==199)
RNGkind("Mersenne-Twister","Inversion","Rejection");set.seed(cfg$seed+1004L)
eps<-matrix(rnorm(n*B,sd=sqrt(s2)),nrow=n)
I_sim<-parameters<-rep(NA_real_,B);check_fits<-list()
for(b in seq_len(B)){
 ys<-as.vector(H%*%(signal+eps[,b]))
 bt<-tryCatch(fast_fit(ys,Z,W,"lag",ev),error=function(e)NULL)
 if(is.null(bt))next
 I_sim[b]<-moran_value(bt$innovation,W);parameters[b]<-bt$par
 if(b%in%c(1L,199L,999L,B)){
  dd<-d;dd$outcome<-ys
  ref<-spatialreg::lagsarlm(reformulate(zvars,response="outcome"),data=dd,
   listw=spdep::mat2listw(W,row.names=d$id,style="W"),Durbin=TRUE,method="eigen",interval=interval,control=list(pre_eig=ev),quiet=TRUE)
  check_fits[[length(check_fits)+1L]]<-data.frame(replicate=b,logLik_difference=abs(bt$ll-as.numeric(logLik(ref))),rho_difference=abs(bt$par-ref$rho))
 }
 if(b%%1000L==0L)cat(sprintf("Regional SDM residual bootstrap: %d/%d\n",b,B))
}
valid<-is.finite(I_sim);nv<-sum(valid);stopifnot(nv==B)
same_I<-max(abs(I_sim[1:199]-base_draw$I));same_rho<-max(abs(parameters[1:199]-base_draw$parameter))
saveRDS(list(I_sim=I_sim,parameters=parameters,observed_I=I_observed,validation=check_fits,same_I=same_I,same_rho=same_rho),file.path(out,"regional_refinement_checkpoint.rds"))
cat(sprintf("First 199 numerical differences: I %.12g, rho %.12g\n",same_I,same_rho))
stopifnot(same_I<1e-5,same_rho<1e-5)
validation<-do.call(rbind,check_fits);stopifnot(all(validation$logLik_difference<1e-6),all(validation$rho_difference<1e-4))
save_new(validation,"regional_refinement_ML_validation.csv")
save_new(data.frame(first_199_max_I_diff=same_I,first_199_max_rho_diff=same_rho,passed=TRUE),"regional_refinement_stream_validation.csv")
summarise_B<-function(m){
 vals<-I_sim[seq_len(m)];a<-sum(vals<=I_observed);b<-sum(vals>=I_observed);s<-min(a,b)
 p<-min(1,2*(s+1)/(m+1));prob<-(s+1)/(m+1)
 ci<-binom.test(s,m)$conf.int
 data.frame(simulations=m,I=I_observed,smaller_tail_count=s,p_bootstrap=p,
 MC_SE_approx=2*sqrt(prob*(1-prob)/(m+1)),MC_lower=max(0,2*ci[1]),MC_upper=min(1,2*ci[2]),
 successful=m,failed=0,boundary_fraction=mean(abs(parameters[seq_len(m)])>.98))
}
checks<-do.call(rbind,lapply(unique(c(199L,999L,1999L,4999L,B)[c(199L,999L,1999L,4999L,B)<=B]),summarise_B))
old_boot<-read.csv("reference/v3/regional_residual_bootstrap.csv")
stopifnot(abs(checks$p_bootstrap[1]-old_boot$p_bootstrap[old_boot$model=="SDM_full"])<1e-12)
save_new(checks,"regional_sdm_bootstrap_comparison.csv")
save_new(data.frame(replicate=seq_len(B),I=I_sim,parameter=parameters),"regional_sdm_bootstrap_extended_draws.csv")
last<-checks[nrow(checks),]
boot<-read.csv(file.path(od,"residual_bootstrap.csv"));j<-which(boot$model=="SDM_full")
for(v in intersect(names(boot),names(last)))boot[j,v]<-last[[v]]
write.csv(boot,file.path(od,"residual_bootstrap.csv"),row.names=FALSE,fileEncoding="UTF-8")
cmp<-read.csv(file.path(od,"model_comparison.csv"));j<-cmp$model=="SDM_full"
cmp$p_bootstrap[j]<-last$p_bootstrap;cmp$boundary_fraction[j]<-last$boundary_fraction
cmp$residual_simulations<-ifelse(cmp$model=="SDM_full",B,cfg$bootstrap_regional)
cmp$impact_simulations<-cfg$bootstrap_regional
write.csv(cmp,file.path(od,"model_comparison.csv"),row.names=FALSE,fileEncoding="UTF-8")
res<-readRDS(file.path(out,"all_results.rds"));res$regional$comparison<-cmp
saveRDS(res,file.path(out,"all_results.rds"))
ac<-read.csv(file.path(out,"all_model_comparisons.csv"));j<-ac$group=="regional" & ac$model=="SDM_full"
ac$p_bootstrap[j]<-last$p_bootstrap;ac$boundary_fraction[j]<-last$boundary_fraction
ac$residual_simulations<-ifelse(ac$group=="regional",ifelse(ac$model=="SDM_full",B,cfg$bootstrap_regional),cfg$bootstrap_national)
ac$impact_simulations<-ifelse(ac$group=="regional",cfg$bootstrap_regional,cfg$bootstrap_national)
save_new(ac,"all_model_comparisons.csv")
writeLines(c(paste("B:",B),paste("seed:",cfg$seed+1004L),paste("observed I:",I_observed),paste("updated p:",last$p_bootstrap),"Only the SDM innovation test was extended; effect intervals and other regional models retain 199 draws.",capture.output(sessionInfo())),file.path(out,"regional_refinement_session.txt"))
print(checks)
