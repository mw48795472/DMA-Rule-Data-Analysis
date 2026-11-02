make_weights <- function(dat,k=4){
 nb<-spdep::knn2nb(spdep::knearneigh(as.matrix(dat[c("x_m","y_m")]),k=k),row.names=dat$id,sym=TRUE)
 lw<-spdep::nb2listw(nb,style="W",zero.policy=FALSE);W<-spdep::listw2mat(lw)
 dimnames(W)<-list(dat$id,dat$id)
 stopifnot(all(abs(rowSums(W)-1)<1e-12),all(diag(W)==0),all(W>=0))
 list(W=W,lw=lw,nb=nb)
}
moran_value<-function(y,W){z<-y-mean(y);length(y)/sum(W)*as.numeric(crossprod(z,W%*%z))/sum(z*z)}
vif_values<-function(Z){
 v<-sapply(seq_len(ncol(Z)),function(j){
  e<-lm.fit(cbind(1,Z[,-j,drop=FALSE]),Z[,j])$residuals
  if(sum(e^2)<1e-20)Inf else sum((Z[,j]-mean(Z[,j]))^2)/sum(e^2)
 });setNames(v,colnames(Z))
}
interval<-c(-.999,.999)
design_matrix<-function(d,zvars,m,W){
 Z<-model.matrix(reformulate(zvars),d)
 lags<-if(m=="SDM_full")zvars else if(m=="SDM_exposure")"z_exposure" else character()
 if(length(lags)){wx<-W%*%as.matrix(d[lags]);colnames(wx)<-paste0("lag.",lags);Z<-cbind(Z,wx)}
 Z
}
model_type<-function(m)if(m=="OLS")"ols" else if(m=="SEM")"error" else "lag"
fast_fit<-function(y,Z,W,type,ev){
 n<-length(y);wy<-as.vector(W%*%y);wz<-W%*%Z
 if(type!="error"){
  qrZ<-qr(Z);b0<-qr.coef(qrZ,y);b1<-qr.coef(qrZ,wy)
  e0<-qr.resid(qrZ,y);e1<-qr.resid(qrZ,wy)
  q0<-sum(e0^2);q1<-sum(e0*e1);q2<-sum(e1^2)
 }
 evaluate<-function(a,details=FALSE){
  if(type=="error"){
   ff<-lm.fit(Z-a*wz,y-a*wy);e<-ff$residuals;b<-ff$coefficients;s2<-sum(e^2)/n
  }else{
   s2<-(q0-2*a*q1+a*a*q2)/n
   if(details){e<-e0-a*e1;b<-b0-a*b1}
  }
  if(!is.finite(s2)||s2<=0)return(if(details)stop("Invalid ML variance") else -Inf)
  ll<-if(type=="ols")0 else sum(log(1-a*ev))
  ll<-ll-n/2*(log(2*pi)+1+log(s2))
  if(details)list(par=a,beta=setNames(b,colnames(Z)),innovation=e,s2=s2,ll=ll,type=type,Z=Z) else ll
 }
 if(type=="ols")return(evaluate(0,TRUE))
 grid<-seq(interval[1],interval[2],length.out=31)
 score<-vapply(grid,evaluate,numeric(1));ix<-order(score,decreasing=TRUE)[1:3]
 opts<-lapply(ix,function(i)optimize(evaluate,c(grid[max(1,i-1)],grid[min(length(grid),i+1)]),maximum=TRUE,tol=1e-9))
 best<-opts[[which.max(vapply(opts,function(x)x$objective,numeric(1)))]]
 evaluate(best$maximum,TRUE)
}
impact_values<-function(pt,W,zvars,ev){
 # W is row stochastic: total multiplier=1/(1-rho).
 # Trace formulas avoid a matrix inversion for every bootstrap replicate.
 a<-if(pt$type=="lag")pt$par else 0
 trS<-mean(1/(1-a*ev));trSW<-mean(ev/(1-a*ev))
 do.call(rbind,lapply(zvars,function(v){
  beta<-unname(pt$beta[v]);theta<-if(paste0("lag.",v)%in%names(pt$beta))unname(pt$beta[paste0("lag.",v)]) else 0
  direct<-trS*beta+trSW*theta;total<-(beta+theta)/(1-a)
  data.frame(term=v,direct=direct,indirect=total-direct,total=total)
 }))
}
run_group<-function(dat,id,y,xvars,zvars,restricted=TRUE,B=999L,primary=FALSE){
 od<-file.path(out,id);dir.create(od,showWarnings=FALSE)
 save<-function(x,nm)write.csv(x,file.path(od,nm),row.names=FALSE,na="",fileEncoding="UTF-8")
 needed<-c(y,xvars,"x_m","y_m")
 audit<-data.frame(id=dat$id,complete=complete.cases(dat[needed]),
  missing_variables=apply(is.na(dat[needed]),1,function(z)paste(needed[z],collapse=";")))
 save(audit,"sample_audit.csv")
 d<-dat[complete.cases(dat[needed]),];d<-d[order(d$id),];rownames(d)<-d$id
 if(nrow(d)<cfg$min_n_national){note(paste("Skipped",id,"n",nrow(d)));return(NULL)}
 scales<-data.frame(term=zvars,source=xvars,center=sapply(d[xvars],mean),sd=sapply(d[xvars],sd))
 stopifnot(all(scales$sd>0))
 for(j in seq_along(xvars))d[[zvars[j]]]<-(d[[xvars[j]]]-scales$center[j])/scales$sd[j]
 d$outcome<-d[[y]];w<-make_weights(d,cfg$k);W<-w$W;n<-nrow(d);ev<-Re(eigen(W,only.values=TRUE)$values)
 save(d,"sample.csv");save(scales,"scaling.csv");save(data.frame(id=d$id,W,check.names=FALSE),"weights.csv")
 save(data.frame(id=d$id,neighbours=spdep::card(w$nb),component=spdep::n.comp.nb(w$nb)$comp.id),"neighbours.csv")
 models<-c("OLS","SAR","SEM","SDM_full",if(restricted)"SDM_exposure")
 fit_one<-function(dd,m,ww){
  ff<-reformulate(zvars,response="outcome");lw<-spdep::mat2listw(ww,row.names=dd$id,style="W")
  eig<-Re(eigen(ww,only.values=TRUE)$values)
  if(m=="OLS")return(lm(ff,dd))
  if(m=="SEM")return(spatialreg::errorsarlm(ff,data=dd,listw=lw,method="eigen",interval=interval,control=list(pre_eig=eig),quiet=TRUE))
  du<-if(m=="SDM_full")TRUE else if(m=="SDM_exposure")~z_exposure else FALSE
  spatialreg::lagsarlm(ff,data=dd,listw=lw,Durbin=du,method="eigen",interval=interval,control=list(pre_eig=eig),quiet=TRUE)
 }
 fits<-setNames(lapply(models,function(m)fit_one(d,m,W)),models)
 points<-list();validation<-list();comparison<-list();vifs<-list();coefs<-list()
 for(m in models){
  Z<-design_matrix(d,zvars,m,W);f<-fits[[m]];pt<-fast_fit(d$outcome,Z,W,model_type(m),ev)
  b<-if(m=="OLS")coef(f) else f$coefficients
  a<-if(m=="OLS")0 else if(m=="SEM")f$lambda else f$rho
  validation[[m]]<-data.frame(model=m,logLik_difference=abs(pt$ll-as.numeric(logLik(f))),
    parameter_difference=abs(pt$par-a),max_beta_difference=max(abs(pt$beta-b[colnames(Z)])))
  stopifnot(validation[[m]]$logLik_difference<1e-6,validation[[m]]$parameter_difference<1e-4,validation[[m]]$max_beta_difference<1e-3)
  # Use spatialreg point estimates, matching the original v2 engine.
  pt$par<-as.numeric(a);pt$beta<-b[colnames(Z)];pt$ll<-as.numeric(logLik(f))
  signal<-as.vector(Z%*%pt$beta)
  pt$innovation<-if(m=="SEM")as.vector((diag(n)-pt$par*W)%*%(d$outcome-signal)) else if(m=="OLS")d$outcome-signal else d$outcome-pt$par*as.vector(W%*%d$outcome)-signal
  pt$s2<-mean(pt$innovation^2);points[[m]]<-pt
  K<-attr(logLik(f),"df");ac<-AIC(f);aicc<-if(n>K+1)ac+2*K*(K+1)/(n-K-1) else NA_real_
  comparison[[m]]<-data.frame(group=id,outcome=y,model=m,n=n,k=cfg$k,parameters=K,logLik=pt$ll,AIC=ac,AICc=aicc,BIC=BIC(f),spatial_parameter=pt$par,innovation_I=moran_value(pt$innovation,W),near_boundary=abs(pt$par)>.98)
  vv<-vif_values(Z[,-1,drop=FALSE]);vifs[[m]]<-data.frame(group=id,model=m,term=names(vv),VIF=as.numeric(vv))
  coefs[[m]]<-data.frame(model=m,term=names(pt$beta),estimate_standardized_X=as.numeric(pt$beta))
  capture.output(summary(f),file=file.path(od,paste0(m,"_summary.txt")))
 }
 comp<-do.call(rbind,comparison);comp$delta_AICc<-comp$AICc-min(comp$AICc,na.rm=TRUE)
 save(do.call(rbind,validation),"ML_validation.csv");save(do.call(rbind,vifs),"vif.csv");save(do.call(rbind,coefs),"coefficients.csv")
 save(data.frame(term=zvars,cor(d[zvars]),check.names=FALSE),"correlation_X.csv")
 wx<-W%*%as.matrix(d[zvars]);save(data.frame(term=zvars,cor(wx),check.names=FALSE),"correlation_WX.csv")
 set.seed(cfg$seed);raw<-spdep::moran.mc(d$outcome,w$lw,nsim=cfg$permutations,alternative="two.sided")
 adj<-spdep::lm.morantest(fits$OLS,w$lw,alternative="two.sided")
 X<-model.matrix(fits$OLS);M<-diag(n)-X%*%solve(crossprod(X),t(X))
 set.seed(cfg$seed+1L);e<-M%*%matrix(rnorm(n*cfg$permutations),nrow=n)
 simI<-n/sum(W)*colSums(e*(W%*%e))/colSums(e^2)
 obs<-unname(adj$estimate[1]);pp<-min(1,2*min((1+sum(simI>=obs))/(cfg$permutations+1),(1+sum(simI<=obs))/(cfg$permutations+1)))
 moran<-data.frame(group=id,test=c("raw_permutation","OLS_adjusted_normal","OLS_Gaussian_projection"),I=c(unname(raw$statistic),obs,obs),p=c(raw$p.value,adj$p.value,pp),n=n,simulations=c(cfg$permutations,NA,cfg$permutations))
 save(moran,"moran.csv")
 lr_specs<-list(c("SAR","OLS"),c("SEM","OLS"),c("SDM_full","SAR"),c("SDM_full","SEM"))
 if(restricted)lr_specs<-c(lr_specs,list(c("SDM_exposure","SAR"),c("SDM_full","SDM_exposure")))
 lr<-do.call(rbind,lapply(lr_specs,function(s){
  aa<-logLik(fits[[s[1]]]);bb<-logLik(fits[[s[2]]]);stat<-2*(as.numeric(aa)-as.numeric(bb));df<-attr(aa,"df")-attr(bb,"df")
  stopifnot(stat> -1e-6,df>0)
  data.frame(unrestricted=s[1],restricted=s[2],LR=max(0,stat),df=df,p=pchisq(max(0,stat),df,lower.tail=FALSE))
 }));save(lr,"LR_tests.csv")
 rs<-spdep::lm.RStests(fits$OLS,w$lw,test="all")
 save(do.call(rbind,lapply(names(rs),function(nm)data.frame(test=nm,statistic=unname(rs[[nm]]$statistic),p=rs[[nm]]$p.value))),"RS_tests.csv")
 boot<-list();effects<-list();draws<-list();effect_check<-list()
 for(mi in seq_along(models)){
  m<-models[mi];pt<-points[[m]];set.seed(cfg$seed+1000L+mi)
  signal<-as.vector(pt$Z%*%pt$beta);H<-solve(diag(n)-pt$par*W)
  eps<-matrix(rnorm(n*B,sd=sqrt(pt$s2)),nrow=n)
  sims<-rep(NA_real_,B);pars<-rep(NA_real_,B);effs<-vector("list",B)
  for(b in seq_len(B)){
   ys<-if(pt$type=="lag")as.vector(H%*%(signal+eps[,b])) else if(pt$type=="error")signal+as.vector(H%*%eps[,b]) else signal+eps[,b]
   bt<-tryCatch(fast_fit(ys,pt$Z,W,pt$type,ev),error=function(e)NULL)
   if(is.null(bt))next
   sims[b]<-moran_value(bt$innovation,W);pars[b]<-bt$par;effs[[b]]<-impact_values(bt,W,zvars,ev)
  }
  valid<-is.finite(sims);nv<-sum(valid);stopifnot(nv>=.95*B)
  io<-moran_value(pt$innovation,W);tp<-min((1+sum(sims[valid]>=io))/(nv+1),(1+sum(sims[valid]<=io))/(nv+1))
  boot[[m]]<-data.frame(group=id,model=m,I=io,p_bootstrap=min(1,2*tp),MC_SE_approx=2*sqrt(tp*(1-tp)/(nv+1)),simulations=B,successful=nv,failed=B-nv,boundary_fraction=mean(abs(pars[valid])>.98))
  draws[[m]]<-data.frame(model=m,replicate=seq_len(B),I=sims,parameter=pars)
  ie<-impact_values(pt,W,zvars,ev)
  # Independent direct matrix multiplier check at point estimates.
  S<-if(pt$type=="lag")solve(diag(n)-pt$par*W) else diag(n)
  for(j in seq_along(zvars)){
   v<-zvars[j];theta<-if(paste0("lag.",v)%in%names(pt$beta))pt$beta[paste0("lag.",v)] else 0
   G<-S%*%(diag(n)*pt$beta[v]+W*theta)
   delta<-max(abs(c(ie$direct[j]-mean(diag(G)),ie$total[j]-mean(rowSums(G)))))
   effect_check[[length(effect_check)+1L]]<-data.frame(model=m,term=v,max_difference=delta);stopifnot(delta<1e-7)
   for(kind in c("direct","indirect","total")){
    vals<-vapply(effs[valid],function(x)x[[kind]][j],numeric(1));q<-quantile(vals,c(.025,.975),names=FALSE)
    effects[[length(effects)+1L]]<-data.frame(group=id,model=m,term=v,source=xvars[j],effect=kind,
     estimate=ie[[kind]][j]/scales$sd[j],lower=q[1]/scales$sd[j],upper=q[2]/scales$sd[j])
   }
  }
  note(sprintf("%s %s: %d/%d bootstrap fits, boundary %.1f%%",id,m,nv,B,100*boot[[m]]$boundary_fraction))
 }
 bt<-do.call(rbind,boot);comp<-merge(comp,bt[c("model","p_bootstrap","boundary_fraction")],by="model",sort=FALSE)
 save(comp,"model_comparison.csv");save(bt,"residual_bootstrap.csv");save(do.call(rbind,effects),"impacts.csv")
 save(do.call(rbind,draws),"bootstrap_draws.csv");save(do.call(rbind,effect_check),"impact_validation.csv")
 sensitivity<-list()
 for(k in c(3L,4L,5L)){
  ww<-if(k==4)W else make_weights(d,k)$W;ee<-Re(eigen(ww,only.values=TRUE)$values)
  for(m in models){
   Z<-design_matrix(d,zvars,m,ww);pt<-fast_fit(d$outcome,Z,ww,model_type(m),ee)
   K<-ncol(Z)+1+as.integer(m!="OLS");AIC<- -2*pt$ll+2*K
   sensitivity[[length(sensitivity)+1L]]<-data.frame(group=id,k=k,model=m,n=n,AIC=AIC,AICc=AIC+2*K*(K+1)/(n-K-1),spatial_parameter=pt$par)
  }
 }
 st<-do.call(rbind,sensitivity);st$delta_AICc<-ave(st$AICc,st$k,FUN=function(x)x-min(x));save(st,"k_sensitivity.csv")
 # National leave-one-out influence is not out-of-sample prediction validation.
 if(primary){
  lo<-list()
  for(omit in d$id){
   dd<-d[d$id!=omit,];ww<-make_weights(dd,4)$W;ee<-Re(eigen(ww,only.values=TRUE)$values)
   for(m in models){Z<-design_matrix(dd,zvars,m,ww);pt<-fast_fit(dd$outcome,Z,ww,model_type(m),ee)
    lo[[length(lo)+1L]]<-data.frame(omitted=omit,model=m,parameter=pt$par,exposure_direct=impact_values(pt,ww,zvars,ee)$direct[1]/scales$sd[1])}
  };save(do.call(rbind,lo),"leave_one_out_influence.csv")
 }
 saveRDS(fits,file.path(od,"models.rds"))
 save(data.frame(id=d$id,do.call(cbind,lapply(points,function(x)x$innovation)),check.names=FALSE),"innovations.csv")
 list(id=id,n=n,y=y,x=xvars,comparison=comp,moran=moran,vif=do.call(rbind,vifs),impacts=do.call(rbind,effects),sample=d,weights=W)
}
