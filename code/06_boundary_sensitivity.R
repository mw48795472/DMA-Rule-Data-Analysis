# Additional check triggered by fitted boundary estimates. It is a separate parameter constraint.
boundary_checks<-list();profiles<-list();original_interval<-interval
for(id in names(results)){
 res<-results[[id]];near<-res$comparison$model[res$comparison$near_boundary]
 if(!length(near))next
 d<-res$sample;W<-res$weights;ev<-Re(eigen(W,only.values=TRUE)$values)
 zvars<-read.csv(file.path(out,id,"scaling.csv"))$term
 lower<-1/min(ev)+1e-5;upper<-1/max(ev)-1e-5
 interval<-c(lower,upper)
 for(m in near){
  Z<-design_matrix(d,zvars,m,W);pt<-fast_fit(d$outcome,Z,W,model_type(m),ev)
  lw<-spdep::mat2listw(W,row.names=d$id,style="W");f<-reformulate(zvars,response="outcome")
  fit<-if(m=="SEM")spatialreg::errorsarlm(f,data=d,listw=lw,method="eigen",interval=interval,control=list(pre_eig=ev),quiet=TRUE) else
   spatialreg::lagsarlm(f,data=d,listw=lw,Durbin=if(m=="SDM_full")TRUE else if(m=="SDM_exposure")~z_exposure else FALSE,method="eigen",interval=interval,control=list(pre_eig=ev),quiet=TRUE)
  stopifnot(abs(pt$ll-as.numeric(logLik(fit)))<1e-6)
  orig<-res$comparison[res$comparison$model==m,];K<-attr(logLik(fit),"df");n<-nrow(d)
  boundary_checks[[length(boundary_checks)+1L]]<-data.frame(group=id,model=m,n=n,
   original_parameter=orig$spatial_parameter,extended_parameter=pt$par,extended_lower=lower,extended_upper=upper,
   original_logLik=orig$logLik,extended_logLik=pt$ll,original_AICc=orig$AICc,
   extended_AICc=AIC(fit)+2*K*(K+1)/(n-K-1),constraint="positive-Jacobian eigenvalue branch; |parameter|<1 not imposed")
  grid<-sort(unique(c(seq(lower+.001,upper-.001,length.out=121),-.999,pt$par)))
  for(a in grid){
   zy<-d$outcome-a*as.vector(W%*%d$outcome)
   zx<-if(m=="SEM")Z-a*W%*%Z else Z
   ee<-lm.fit(zx,zy)$residuals
   ll<-sum(log(1-a*ev))-n/2*(log(2*pi)+1+log(mean(ee^2)))
   profiles[[length(profiles)+1L]]<-data.frame(group=id,model=m,parameter=a,logLik=ll)
  }
 }
}
interval<-original_interval
if(length(boundary_checks)){
 boundary_checks<-do.call(rbind,boundary_checks);save_csv(boundary_checks,"boundary_constraint_sensitivity.csv")
 profiles<-do.call(rbind,profiles);profiles$relative_logLik<-ave(profiles$logLik,profiles$group,profiles$model,FUN=function(x)x-max(x))
 save_csv(profiles,"boundary_profile.csv")
 p<-ggplot(profiles,aes(parameter,relative_logLik))+geom_line(color="#126e82",linewidth=.7)+
  geom_vline(xintercept=-.999,linetype=2,color="#b77a37")+facet_wrap(~group+model,scales="free_x")+
  coord_cartesian(ylim=c(-10,0))+labs(title="Likelihood sensitivity to the spatial-parameter bound",
   subtitle="Separate eigenvalue-branch check; dashed line is the original -0.999 constraint",
   x="Spatial parameter",y="Log-likelihood relative to the best grid value")
 save_plot(p,"12_boundary_profiles",11,7)
 note("Boundary constraint sensitivity completed; it does not replace the original stability-constrained comparison.")
}
