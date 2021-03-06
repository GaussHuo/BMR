DSGEVAR.default <- function(dsgedata,chains=1,cores=1,lambda=Inf,p=2,
                            constant=FALSE,ObserveMat,initialvals,partomats,
                            priorform,priorpars,parbounds,parnames=NULL,
                            optimMethod="Nelder-Mead",
                            optimLower=NULL,optimUpper=NULL,
                            optimControl=list(),
                            IRFs=TRUE,irf.periods=20,scalepar=1,
                            keep=50000,burnin=10000){
  #
  cat('Trying to solve the model with your initial values... ')
  dsgemats1t <- partomats(initialvals)
  dsgesolved1t <- SDSGE(dsgemats1t$A,dsgemats1t$B,dsgemats1t$C,dsgemats1t$D,dsgemats1t$F,dsgemats1t$G,dsgemats1t$H,dsgemats1t$J,dsgemats1t$K,dsgemats1t$L,dsgemats1t$M,dsgemats1t$N)
  StateMats1t <- .DSGEstatespace(dsgesolved1t$N,dsgesolved1t$P,dsgesolved1t$Q,dsgesolved1t$R,dsgesolved1t$S)
  cat('Done. \n')
  #
  dsgedataRet <- dsgedata; priorformRet <- priorform
  #
  prelimwork <- .dsgevarPrelimWork(dsgedata,lambda,p,constant,dsgemats1t$shocks,IRFs,ObserveMat,partomats,priorform,priorpars,parbounds)
  kdata <- prelimwork$kdata; dsgedata <- kdata$Y; 
  lambda <- prelimwork$lambda; IRFs <- prelimwork$IRFs
  priorform <- prelimwork$priorform; parbounds <- prelimwork$parbounds
  #
  #
  #
  Mode <- .DSGEVARModeEstimate(kdata,lambda,p,ObserveMat,initialvals,partomats,priorform,priorpars,parbounds,parnames,optimMethod,optimLower,optimUpper,optimControl)
  #
  dsgemode <- Mode$dsgemode; parMode <- Mode$parMode; parModeSEs <- Mode$parModeSEs
  #
  dsgeret <- 0
  if(keep==0){
    parRet <- matrix(0,nrow=0,ncol=length(parMode))
    if(class(parnames)=="character"){
      colnames(parRet) <- parnames
    }
    #
    dsgevarret <- list(Parameters=parRet,Beta=NULL,Sigma=NULL,DSGEIRFs=NULL,DSGEVARIRFs=NULL,lambda=lambda,p=p,parMode=parMode,ModeHessian=dsgemode$hessian,logMargLikelihood=Mode$logMargLikelihood,scalepar=scalepar,AcceptanceRate=NULL,RootRConvStats=NULL,ObserveMat=ObserveMat,data=dsgedataRet,partomats=partomats,priorform=priorformRet,priorpars=priorpars,parbounds=parbounds)
    class(dsgevarret) <- "DSGEVAR"
    #
    return(dsgevarret)
  }
  #
  cat(' \n', sep="")
  cat('Trying to Compute DSGE-VAR Prior at the Posterior Mode... ', sep="")
  dsgeprior <- .DSGEVARPrior(c(parMode),dsgedata,kdata$X,p,ObserveMat,partomats,priorform,priorpars,parbounds)
  cat('Done. \n')
  #
  #
  #
  #
  #
  cat(' \n', sep="")
  cat('Beginning DSGE-VAR MCMC run, ', date(),'. \n', sep="")
  DSGEVARMCMCRes <- 0; DSGEVARMCMCRes <- 0
  if(chains==1){
    if(is.finite(lambda)==TRUE){
      DSGEVARMCMCRes <- .DSGEVARMCMC(dsgemode,scalepar,keep,burnin,parMode,kdata,lambda,p,ObserveMat,partomats,priorform,priorpars,parbounds,parallel=FALSE)
    }else{
      DSGEVARMCMCRes <- .DSGEVARMCMCInf(dsgemode,scalepar,keep,burnin,parMode,kdata,lambda,p,ObserveMat,partomats,priorform,priorpars,parbounds,parallel=FALSE)
    }
  }else{
    DSGEVARMCMCRes <- .DSGEVARMCMCMulti(dsgemode,scalepar,keep,burnin,parMode,kdata,lambda,p,ObserveMat,partomats,priorform,priorpars,parbounds,chains,cores)
  }
  cat('MCMC run finished, ', date(),'. \n', sep="")
  #
  if(class(parnames)=="character"){
    colnames(DSGEVARMCMCRes$parameters) <- parnames
  }
  #
  PostMCMCInfo <- .DSGEVARMCMCPrint(DSGEVARMCMCRes,chains,parMode,parModeSEs,parnames)
  #
  #
  #
  kcons <- constant*constant
  IRFDVs <- NULL; DSGEVARImpact <- NULL; 
  IRFDs <- NULL
  dsgemats1t <- NULL; dsgesolved1t <- NULL; StateMats1t <- NULL
  if(IRFs == TRUE){
    cat(' \n')
    cat('Computing DSGE IRFs now... ')
    dsgemats1t <- partomats(c(parMode))
    dsgesolved1t <- SDSGE(dsgemats1t$A,dsgemats1t$B,dsgemats1t$C,dsgemats1t$D,dsgemats1t$F,dsgemats1t$G,dsgemats1t$H,dsgemats1t$J,dsgemats1t$K,dsgemats1t$L,dsgemats1t$M,dsgemats1t$N)
    StateMats1t <- .DSGEstatespace(dsgesolved1t$N,dsgesolved1t$P,dsgesolved1t$Q,dsgesolved1t$R,dsgesolved1t$S)
    IRFDs <- array(0,dim=c(irf.periods,ncol(StateMats1t$F),nrow(dsgemats1t$N),keep))
    for(i in 1:keep){
      dsgemats <- partomats(DSGEVARMCMCRes$parameters[i,])
      dsgesolved <- SDSGE(dsgemats$A,dsgemats$B,dsgemats$C,dsgemats$D,dsgemats$F,dsgemats$G,dsgemats$H,dsgemats$J,dsgemats$K,dsgemats$L,dsgemats$M,dsgemats$N)
      iIRF <- IRF(dsgesolved,sqrt(diag(dsgemats$shocks)),irf.periods,varnames=NULL,plot=FALSE,save=FALSE)
      IRFDs[,,,i] <- iIRF$IRFs
    }
    cat('Done. \n') 
    #
    cat(' \n')
    cat('Starting DSGE-VAR IRFs, ',date(),'. \n', sep="")
    #
    IRFDVs <- array(NA,dim=c(ncol(dsgedata),ncol(dsgedata),irf.periods*keep))
    #
    DSGEVARImpact <- .DSGEVARIRFMatrices(DSGEVARMCMCRes$parameters,DSGEVARMCMCRes$Sigma,p,ObserveMat,partomats,priorform,priorpars,parbounds)
    IRFDVs <- .Call("DSGEVARIRFs", ncol(dsgedata),ncol(dsgedata)*p+kcons,kcons,keep,irf.periods,DSGEVARMCMCRes$Beta,DSGEVARImpact,IRFDVs, PACKAGE = "BMR", DUP = FALSE)
    IRFDVs <- IRFDVs$ImpStore
    IRFStore <- array(NA,dim=c(ncol(dsgedata),ncol(dsgedata),irf.periods,keep))
    for(i in 1:keep){
      IRFStore[,,,i] <- IRFDVs[,,((i-1)*irf.periods+1):(i*irf.periods)]
    }
    #
    IRFDVs <- 0
    IRFDVs <- apply(IRFStore,c(3,1,2),sort)
    #
    IRFDVs <- aperm(IRFDVs,c(2,3,1,4)); IRFDVs <- aperm(IRFDVs,c(1,2,4,3))
    #
    cat('DSGEVAR IRFs finished, ', date(),'. \n', sep="")
  }
  #
  dsgevarret <- list(Parameters=DSGEVARMCMCRes$parameters,Beta=DSGEVARMCMCRes$Beta,Sigma=DSGEVARMCMCRes$Sigma,DSGEIRFs=IRFDs,DSGEVARIRFs=IRFDVs,lambda=lambda,p=p,parMode=parMode,ModeHessian=dsgemode$hessian,logMargLikelihood=Mode$logMargLikelihood,scalepar=scalepar,AcceptanceRate=DSGEVARMCMCRes$acceptRate,RootRConvStats=PostMCMCInfo$Diagnostics,constant=constant,ObserveMat=ObserveMat,data=dsgedataRet,partomats=partomats,priorform=priorformRet,priorpars=priorpars,parbounds=parbounds)
  class(dsgevarret) <- "DSGEVAR"
  #
  return(dsgevarret)
}

.dsgevardata <- function(mydata,p,constant){
  #
  Tr <- as.numeric(dim(mydata)[1])
  M <- as.numeric(dim(mydata)[2])
  Tp <- Tr - p
  #
  Yraw <- as.matrix(mydata,ncol=M)
  #
  X <- embed(Yraw,p+1); X <- X[,(M+1):ncol(X)]
  if(constant == TRUE){X<-cbind(rep(1,(Tp)),X)}
  #
  K <- as.numeric(dim(X)[2])
  #
  Y <- Yraw[(p+1):nrow(Yraw),]
  #
  YY <- (1/nrow(Y))*t(Y)%*%Y
  XY <- (1/nrow(Y))*t(X)%*%Y
  XX <- (1/nrow(Y))*t(X)%*%X
  #
  return=list(Y=Y,X=X,M=M,K=K,Yraw=Yraw,Tp=Tp,YY=YY,XY=XY,XX=XX)
}

.dsgevarPrelimWork <- function(dsgedata,lambda,p,constant,shocks,IRFs,ObserveMat,partomats,priorform,priorpars,parbounds){
  #
  kcons <- constant*constant
  #
  kdata <- .dsgevardata(dsgedata,p,constant)
  #
  # Set a lower bound on lambda:
  if(lambda < (ncol(dsgedata)*(p+1) + kcons)/nrow(dsgedata)){
    lambda <- (ncol(dsgedata)*(p+1) + kcons)/nrow(dsgedata)
  }
  #
  # Check if there are as many structural shocks as observables
  if(IRFs==TRUE){
    if(ncol(dsgedata)!=ncol(shocks)){
      warning('The number of observable series and structural shocks do not coincide. IRFs will not be computed.', call.=FALSE)
      IRFs <- FALSE
    }
  }
  #
  # Change from character to numeric
  priorformNum <- numeric(length(priorform))
  # Normal = 1, Gamma = 2, IGamma = 3, Beta = 4, Uniform = 5
  for(i in 1:length(priorform)){
    if(priorform[i]=="Normal"){
      priorformNum[i] <- 1
    }else if(priorform[i]=="Gamma"){
      priorformNum[i] <- 2
    }else if(priorform[i]=="IGamma"){
      priorformNum[i] <- 3
    }else if(priorform[i]=="Beta"){
      priorformNum[i] <- 4
    }else if(priorform[i]=="Uniform"){
      priorformNum[i] <- 5
    }else{
      stop("Parameter ", i ," does not have a valid prior form.\n",call.=FALSE)
    }
  }
  #
  # Check if parbounds is set correctly for uniform priors
  for(i in 1:length(priorform)){
    if(priorform[i]=="Uniform"){
      parbounds[i,] <- priorpars[i,]
    }
  }
  #
  return=list(kdata=kdata,lambda=lambda,IRFs=IRFs,priorform=priorformNum,parbounds=parbounds)
}

.DSGEVARLogPosterior <- function(dsgeparTrans,kdata,lambda,p,YY,XY,XX,ObserveMat,partomats,priorform,priorpars,parbounds){
  #
  Y <- kdata$Y; X <- kdata$X
  kcons <- (ncol(X)%%p!=0)*(ncol(X)%%p!=0)
  #
  dsgepar <- .DSGEParTransform(dsgeparTrans,priorform,parbounds,2)
  #
  logGPR <- .LGPR(ncol(Y),((1+lambda)*nrow(Y))-ncol(Y)*p-kcons,(lambda*nrow(Y))-ncol(Y)*p-kcons)
  #
  dsgeprior <- .DSGEVARPrior(dsgepar,Y,X,p,ObserveMat,partomats,priorform,priorpars,parbounds)
  GammaYY <- dsgeprior$GammaYY; GammaXY <- dsgeprior$GammaXY; GammaXX <- dsgeprior$GammaXX
  #
  tau <- lambda/(1+lambda);
  GammaBarYY <- tau*GammaYY + (1-tau)*YY
  GammaBarXY <- tau*t(GammaXY) + (1-tau)*XY
  GammaBarXX <- tau*GammaXX + (1-tau)*XX
  #
  logLikelihood <- -.Call("DSGEVARLikelihood", logGPR,XX,GammaYY,GammaXY,GammaXX,GammaBarYY,GammaBarXY,GammaBarXX,lambda,nrow(Y),ncol(Y),p,kcons, PACKAGE = "BMR", DUP = FALSE)$logLikelihood
  #
  logPosterior <- .DSGEPriors(dsgepar,dsgeparTrans,priorform,priorpars,parbounds,logLikelihood)
  #
  return(logPosterior)
}

.DSGEVARLogPosteriorInf <- function(dsgeparTrans,kdata,lambda,p,YY,XY,XX,ObserveMat,partomats,priorform,priorpars,parbounds){
  #
  Y <- kdata$Y; X <- kdata$X
  #
  dsgepar <- .DSGEParTransform(dsgeparTrans,priorform,parbounds,2)
  #
  dsgeprior <- .DSGEVARPrior(dsgepar,Y,X,p,ObserveMat,partomats,priorform,priorpars,parbounds)
  GammaYY <- dsgeprior$GammaYY; GammaXY <- dsgeprior$GammaXY; GammaXX <- dsgeprior$GammaXX
  #
  logLikelihood <- -.Call("DSGEVARLikelihoodInf", YY,XY,XX,GammaYY,GammaXY,GammaXX,nrow(Y),ncol(Y),p, PACKAGE = "BMR", DUP = FALSE)$logLikelihood
  #
  logPosterior <- .DSGEPriors(dsgepar,dsgeparTrans,priorform,priorpars,parbounds,logLikelihood)
  #
  return(logPosterior)
}

.LGPR <- function(n,a,b){
  logGPR = 0
  for(i in 1:n){
    logGPR = logGPR + lgamma((a-i+1)/2) - lgamma((b-i+1)/2)
  }
  return(logGPR)
}

.DSGEVARPrior <- function(parameters,dsgedata,X,p,ObserveMat,partomats,priorform,priorpars,parbounds){
  #
  dsgemats <- partomats(parameters)
  dsgesolved <- SDSGE(dsgemats$A,dsgemats$B,dsgemats$C,dsgemats$D,dsgemats$F,dsgemats$G,dsgemats$H,dsgemats$J,dsgemats$K,dsgemats$L,dsgemats$M,dsgemats$N)
  #
  StateMats <- .DSGEstatespace(dsgesolved$N,dsgesolved$P,dsgesolved$Q,dsgesolved$R,dsgesolved$S)
  #
  SigmaX <- .Call("DSGEVARPriorC", dsgedata,ObserveMat,dsgemats$ObsCons,StateMats$F,StateMats$G,dsgesolved$N,dsgemats$shocks,dsgemats$MeasErrs,p,500, PACKAGE = "BMR", DUP = FALSE)$SigmaX
  #
  GammaYY <- SigmaX[,,1]
  #
  #
  #
  GammaXX <- matrix(0,ncol(dsgedata)*p,ncol(dsgedata)*p)
  GammaXY <- matrix(0,ncol(dsgedata),ncol(dsgedata)*p)
  GammaCY <- matrix(0,1,ncol(dsgedata)*p)
  #
  for(i in 1:p){
    NR <- (1:ncol(dsgedata))+((i-1)*ncol(dsgedata))
    for(j in 1:p){
      NC <- (1:ncol(dsgedata))+((j-1)*ncol(dsgedata))
      if(i==j){
        GammaXX[NR,NC] <- SigmaX[,,1]
      }else if(i<j){
        GammaXX[NR,NC] <- SigmaX[,,1+j-i]
      }else{
        GammaXX[NR,NC] <- SigmaX[,,1+i-j]
      }
    }
    GammaCY[,NR] <- t(dsgemats$ObsCons)
    GammaXY[,NR] <- SigmaX[,,1+i]
  }
  #
  if(ncol(X)%%p != 0){
    GammaXY = cbind(dsgemats$ObsCons, GammaXY);
    GammaXX = rbind(cbind(1,GammaCY), cbind(t(GammaCY), GammaXX))
  }
  #
  return(list(GammaYY=GammaYY,GammaXX=GammaXX,GammaXY=GammaXY))
}

.DSGEVARModeEstimate <- function(kdata,lambda,p,ObserveMat,initialvals,partomats,
                                 priorform,priorpars,parbounds,parnames,
                                 optimMethod,optimLower,optimUpper,optimControl){
  #
  parametersTrans <- .DSGEParTransform(initialvals,priorform,parbounds,1)
  #
  OptimMethods <- optimMethod
  #
  dsgemode <- NULL
  prevlogpost <- 0
  cat(' \n', sep="")
  cat('Beginning optimization, ', date(),'. \n', sep="")
  if(is.finite(lambda)==TRUE){
    for(jj in 1:length(OptimMethods)){
      #
      optimMethod <- OptimMethods[jj]
      #
      if(jj==1){
        cat('Using Optimization Method: ',optimMethod,'. \n', sep="")
      }else{
        cat('Using Optimization Method: ',optimMethod,'. ', sep="")
      }
      #
      if(optimMethod=="Nelder-Mead"){
        dsgemode <- optim(par=parametersTrans,fn=.DSGEVARLogPosterior,method="Nelder-Mead",control=optimControl,kdata=kdata,lambda=lambda,p=p,YY=kdata$YY,XY=kdata$XY,XX=kdata$XX,ObserveMat=ObserveMat,partomats=partomats,priorform=priorform,priorpars=priorpars,parbounds=parbounds,hessian=TRUE)
      }else if(optimMethod=="BFGS"){
        dsgemode <- optim(par=parametersTrans,fn=.DSGEVARLogPosterior,method="BFGS",control=optimControl,kdata=kdata,lambda=lambda,p=p,YY=kdata$YY,XY=kdata$XY,XX=kdata$XX,ObserveMat=ObserveMat,partomats=partomats,priorform=priorform,priorpars=priorpars,parbounds=parbounds,hessian=TRUE)
      }else if(optimMethod=="CG"){
        dsgemode <- optim(par=parametersTrans,fn=.DSGEVARLogPosterior,method="CG",control=optimControl,kdata=kdata,lambda=lambda,p=p,YY=kdata$YY,XY=kdata$XY,XX=kdata$XX,ObserveMat=ObserveMat,partomats=partomats,priorform=priorform,priorpars=priorpars,parbounds=parbounds,hessian=TRUE)
      }else if(optimMethod=="L-BFGS-B"){
        dsgemode <- optim(par=parametersTrans,fn=.DSGEVARLogPosterior,method="L-BFGS-B",lower=optimLower,upper=optimUpper,control=optimControl,kdata=kdata,lambda=lambda,p=p,YY=kdata$YY,XY=kdata$XY,XX=kdata$XX,ObserveMat=ObserveMat,partomats=partomats,priorform=priorform,priorpars=priorpars,parbounds=parbounds,hessian=TRUE)
      }else if(optimMethod=="SANN"){
        dsgemode <- optim(par=parametersTrans,fn=.DSGEVARLogPosterior,method="SANN",control=optimControl,kdata=kdata,lambda=lambda,p=p,YY=kdata$YY,XY=kdata$XY,XX=kdata$XX,ObserveMat=ObserveMat,partomats=partomats,priorform=priorform,priorpars=priorpars,parbounds=parbounds,hessian=TRUE)
      }else{
        stop("You have entered an unrecognized optimization method.\n",call.=FALSE)
      }
      #
      if(jj>1){
        cat('Change in the log posterior: ',-dsgemode$value - prevlogpost,'. \n', sep="")
      }
      #
      parametersTrans <- dsgemode$par
      prevlogpost <- -dsgemode$value
    }
  }else{
    for(jj in 1:length(OptimMethods)){
      #
      optimMethod <- OptimMethods[jj]
      #
      if(jj==1){
        cat('Using Optimization Method: ',optimMethod,'. \n', sep="")
      }else{
        cat('Using Optimization Method: ',optimMethod,'. ', sep="")
      }
      #
      if(optimMethod=="Nelder-Mead"){
        dsgemode <- optim(par=parametersTrans,fn=.DSGEVARLogPosteriorInf,method="Nelder-Mead",control=optimControl,kdata=kdata,lambda=lambda,p=p,YY=kdata$YY,XY=kdata$XY,XX=kdata$XX,ObserveMat=ObserveMat,partomats=partomats,priorform=priorform,priorpars=priorpars,parbounds=parbounds,hessian=TRUE)
      }else if(optimMethod=="BFGS"){
        dsgemode <- optim(par=parametersTrans,fn=.DSGEVARLogPosteriorInf,method="BFGS",control=optimControl,kdata=kdata,lambda=lambda,p=p,YY=kdata$YY,XY=kdata$XY,XX=kdata$XX,ObserveMat=ObserveMat,partomats=partomats,priorform=priorform,priorpars=priorpars,parbounds=parbounds,hessian=TRUE)
      }else if(optimMethod=="CG"){
        dsgemode <- optim(par=parametersTrans,fn=.DSGEVARLogPosteriorInf,method="CG",control=optimControl,kdata=kdata,lambda=lambda,p=p,YY=kdata$YY,XY=kdata$XY,XX=kdata$XX,ObserveMat=ObserveMat,partomats=partomats,priorform=priorform,priorpars=priorpars,parbounds=parbounds,hessian=TRUE)
      }else if(optimMethod=="L-BFGS-B"){
        dsgemode <- optim(par=parametersTrans,fn=.DSGEVARLogPosteriorInf,method="L-BFGS-B",lower=optimLower,upper=optimUpper,control=optimControl,kdata=kdata,lambda=lambda,p=p,YY=kdata$YY,XY=kdata$XY,XX=kdata$XX,ObserveMat=ObserveMat,partomats=partomats,priorform=priorform,priorpars=priorpars,parbounds=parbounds,hessian=TRUE)
      }else if(optimMethod=="SANN"){
        dsgemode <- optim(par=parametersTrans,fn=.DSGEVARLogPosteriorInf,method="SANN",control=optimControl,kdata=kdata,lambda=lambda,p=p,YY=kdata$YY,XY=kdata$XY,XX=kdata$XX,ObserveMat=ObserveMat,partomats=partomats,priorform=priorform,priorpars=priorpars,parbounds=parbounds,hessian=TRUE)
      }else{
        stop("You have entered an unrecognized optimization method.\n",call.=FALSE)
      }
      #
      if(jj>1){
        cat('Change in the log posterior: ',-dsgemode$value - prevlogpost,'. \n', sep="")
      }
      #
      parametersTrans <- dsgemode$par
      prevlogpost <- -dsgemode$value
    }
  }
  #
  ConvCode <- dsgemode$convergence
  ConvReport <- 0
  if(ConvCode==0){
    ConvReport <- "successful completion"
  }else if(ConvCode==1){
    ConvReport <- "maximum number of iterations reached"
  }else if(ConvCode==10){
    ConvReport <- "degeneracy of the Nelder-Mead simplex"
  }else if(ConvCode==51){
    ConvReport <- "warning from L-BFGS-B"
  }else if(ConvCode==52){
    ConvReport <- "error from L-BFGS-B"
  }else{
    ConvReport <- "unknown"
  }
  #
  cat('Optimization over, ', date(),'. \n', sep="")
  cat(' \n', sep="")
  cat('Optimizer Convergence Code: ',dsgemode$convergence,'; ',ConvReport,'. \n', sep="")
  cat(' \n', sep="")
  cat('Optimizer Iterations: \n', sep="")
  print(dsgemode$counts)
  #
  parMode <- .DSGEParTransform(dsgemode$par,priorform,parbounds,2)
  #
  logMargLikelihood <- .LaplaceMargLikelihood(dsgemode)
  #
  cat(' \n', sep="")
  cat('Log Marginal Likelihood: ',logMargLikelihood,'. \n', sep="")
  #
  parModeHessian <- solve(dsgemode$hessian)
  parModeHessian <- diag(parModeHessian)
  parModeHessian <- sqrt(parModeHessian)
  #
  parModeSEs <- .DSGEParTransform(dsgemode$par,priorform,parbounds,2) - .DSGEParTransform(dsgemode$par - parModeHessian,priorform,parbounds,2)
  #
  parMode <- matrix(parMode,nrow=1)
  parModeSEs <- matrix(parModeSEs,nrow=1)
  parModeHessian <- matrix(parModeHessian,nrow=1)
  #
  ModeTable <- matrix(NA,nrow=length(dsgemode$par),ncol=2)
  ModeTable[,1] <- parMode
  ModeTable[,2] <- parModeSEs
  #
  colnames(ModeTable) <- c("Estimate","SE")
  if(class(parnames)=="character"){
    rownames(ModeTable) <- parnames
  }
  cat(' \n', sep="")
  cat('Parameter Estimates and Standard Errors (SE) at the Posterior Mode: \n', sep="")
  cat(' \n', sep="")
  print(ModeTable)
  #
  rownames(parMode) <- "Parameter:"
  rownames(parModeSEs) <- "Parameter:"
  rownames(parModeHessian) <- "Parameter:"
  if(class(parnames)=="character"){
    colnames(parMode) <- parnames
    colnames(parModeHessian) <- parnames
    colnames(parModeSEs) <- parnames
  }
  #
  #
  return=list(dsgemode=dsgemode,parMode=parMode,parModeSEs=parModeSEs,logMargLikelihood=logMargLikelihood)
}

.DSGEVARMCMC <- function(dsgeopt,scalepar,keep,burnin,parMode,kdata,lambda,p,ObserveMat,partomats,priorform,priorpars,parbounds,parallel=FALSE){
  #
  Y <- kdata$Y; X <- kdata$X; YY <- kdata$YY; XY <- kdata$XY; XX <- kdata$XX;
  #
  DSGEDraws <- matrix(NA,nrow=(keep+1),ncol=length(dsgeopt$par))
  #
  InitialDraw <- dsgeopt$par
  if(parallel==TRUE){
    InitialDraw <- dsgeopt$par + runif(1,-1,1)*c(sqrt(diag(solve(dsgeopt$hessian))))
  }
  #
  PrevLP <- (-1)*dsgeopt$value
  if(parallel==TRUE){
    PrevLP <- (-1)*.DSGEVARLogPosterior(c(InitialDraw),kdata,lambda,p,YY,XY,XX,ObserveMat,partomats,priorform,priorpars,parbounds)
  }
  #
  PickMeInstead <- matrix(c(InitialDraw))
  #
  CovM <- scalepar*(solve(dsgeopt$hessian))
  CovMChol <- t(chol(CovM))
  #
  Acceptances <- 0
  #
  for (i in 1:burnin){
    #
    proposal <- PickMeInstead + CovMChol%*%matrix(rnorm(length(dsgeopt$par)))
    #
    PropLP <- (-1)*.DSGEVARLogPosterior(c(proposal),kdata,lambda,p,YY,XY,XX,ObserveMat,partomats,priorform,priorpars,parbounds)
    if(is.nan(PropLP)){
      PropLP <- -1000000
    }
    #
    if(runif(1) < exp(PropLP-PrevLP)){
      PickMeInstead <- proposal
      PrevLP <- PropLP
    }
  }
  #
  DSGEDraws[1,] <- t(PickMeInstead)
  #
  for (i in 1:keep){
    #
    proposal <- PickMeInstead + CovMChol%*%matrix(rnorm(length(dsgeopt$par)))
    #
    PropLP <- (-1)*.DSGEVARLogPosterior(c(proposal),kdata,lambda,p,YY,XY,XX,ObserveMat,partomats,priorform,priorpars,parbounds)
    if(is.nan(PropLP)){
      PropLP <- -1000000
    }
    #
    if(runif(1) < exp(PropLP-PrevLP)){
      DSGEDraws[i+1,] <- t(proposal)
      Acceptances <- Acceptances + 1
      #
      PickMeInstead <- proposal
      PrevLP <- PropLP
    }else{
      DSGEDraws[i+1,] <- DSGEDraws[i,]
    }
  }
  #
  DSGEDraws <- DSGEDraws[-1,]
  accept <- Acceptances/keep
  #
  for(i in 1:keep){
    DSGEDraws[i,] <- .DSGEParTransform(DSGEDraws[i,],priorform,parbounds,2)
  }
  #
  #
  # VAR Sampling
  #
  #
  dsgeprior <- .DSGEVARPrior(parMode,Y,X,p,ObserveMat,partomats,priorform,priorpars,parbounds)
  GammaYY <- dsgeprior$GammaYY; GammaXY <- dsgeprior$GammaXY; GammaXX <- dsgeprior$GammaXX
  #
  tau <- lambda/(1+lambda)
  GammaBarYY <- tau*GammaYY + (1-tau)*YY
  GammaBarXY <- tau*t(GammaXY) + (1-tau)*XY
  GammaBarXX <- tau*GammaXX + (1-tau)*XX
  #
  GammaBarYY <- array(0,dim=c(c(dim(YY)),nrow(DSGEDraws)))
  GammaBarXY <- array(0,dim=c(c(dim(XY)),nrow(DSGEDraws)))
  GammaBarXX <- array(0,dim=c(c(dim(XX)),nrow(DSGEDraws)))
  GXX <- array(0,dim=c(c(dim(XX)),nrow(DSGEDraws)))
  #
  for(t in 1:nrow(DSGEDraws)){
    dsgeparameters <- DSGEDraws[t,]
    dsgeprior <- .DSGEVARPrior(dsgeparameters,Y,X,p,ObserveMat,partomats,priorform,priorpars,parbounds)
    GammaYY <- dsgeprior$GammaYY; GammaXY <- dsgeprior$GammaXY; GammaXX <- dsgeprior$GammaXX
    #
    GammaBarYY[,,t] <- tau*GammaYY + (1-tau)*YY
    GammaBarXY[,,t] <- tau*t(GammaXY) + (1-tau)*XY
    GammaBarXX[,,t] <- tau*GammaXX + (1-tau)*XX
    #
    GXX[,,t] <- GammaXX
    #
  }
  #
  kcons <- (ncol(X)%%p!=0)*(ncol(X)%%p!=0)
  RepsRun <- .Call("DSGEVARReps", GammaBarYY,GammaBarXY,GammaBarXX,GXX,XX,lambda,nrow(DSGEDraws),nrow(Y),ncol(Y),p,kcons, PACKAGE = "BMR", DUP = FALSE)
  #
  if(parallel==FALSE){
    return=list(parameters=DSGEDraws,acceptRate=accept,Beta=RepsRun$Beta,Sigma=RepsRun$Sigma)
  }else{
    return(list(DSGEDraws,accept,RepsRun$Beta,RepsRun$Sigma))
  }
}

.DSGEVARMCMCInf <- function(dsgeopt,scalepar,keep,burnin,parMode,kdata,lambda,p,ObserveMat,partomats,priorform,priorpars,parbounds,parallel=FALSE){
  #
  Y <- kdata$Y; X <- kdata$X; YY <- kdata$YY; XY <- kdata$XY; XX <- kdata$XX;
  #
  DSGEDraws <- matrix(NA,nrow=(keep+1),ncol=length(dsgeopt$par))
  #
  InitialDraw <- dsgeopt$par
  if(parallel==TRUE){
    InitialDraw <- dsgeopt$par + runif(1,-1,1)*c(sqrt(diag(solve(dsgeopt$hessian))))
  }
  #
  PrevLP <- (-1)*dsgeopt$value
  if(parallel==TRUE){
    PrevLP <- (-1)*.DSGEVARLogPosteriorInf(c(InitialDraw),kdata,lambda,p,YY,XY,XX,ObserveMat,partomats,priorform,priorpars,parbounds)
  }
  #
  PickMeInstead <- matrix(c(InitialDraw))
  #
  CovM <- scalepar*(solve(dsgeopt$hessian))
  CovMChol <- t(chol(CovM))
  #
  Acceptances <- 0
  #
  for (i in 1:burnin){
    #
    proposal <- PickMeInstead + CovMChol%*%matrix(rnorm(length(dsgeopt$par)))
    #
    PropLP <- (-1)*.DSGEVARLogPosteriorInf(c(proposal),kdata,lambda,p,YY,XY,XX,ObserveMat,partomats,priorform,priorpars,parbounds)
    if(is.nan(PropLP)){
      PropLP <- -1000000
    }
    #
    if(runif(1) < exp(PropLP-PrevLP)){
      PickMeInstead <- proposal
      PrevLP <- PropLP
    }
  }
  #
  DSGEDraws[1,] <- t(PickMeInstead)
  #
  for (i in 1:keep){
    #
    proposal <- PickMeInstead + CovMChol%*%matrix(rnorm(length(dsgeopt$par)))
    #
    PropLP <- (-1)*.DSGEVARLogPosteriorInf(c(proposal),kdata,lambda,p,YY,XY,XX,ObserveMat,partomats,priorform,priorpars,parbounds)
    if(is.nan(PropLP)){
      PropLP <- -1000000
    }
    #
    if(runif(1) < exp(PropLP-PrevLP)){
      DSGEDraws[i+1,] <- t(proposal)
      Acceptances <- Acceptances + 1
      #
      PickMeInstead <- proposal
      PrevLP <- PropLP
    }else{
      DSGEDraws[i+1,] <- DSGEDraws[i,]
    }
  }
  #
  DSGEDraws <- DSGEDraws[-1,]
  accept <- Acceptances/keep
  #
  for(i in 1:keep){
    DSGEDraws[i,] <- .DSGEParTransform(DSGEDraws[i,],priorform,parbounds,2)
  }
  #
  #
  # VAR Sampling
  #
  #
  dsgeprior <- .DSGEVARPrior(parMode,Y,X,p,ObserveMat,partomats,priorform,priorpars,parbounds)
  GammaYY <- dsgeprior$GammaYY; GammaXY <- dsgeprior$GammaXY; GammaXX <- dsgeprior$GammaXX
  #
  GammaBarYY <- array(0,dim=c(c(dim(GammaYY)),nrow(DSGEDraws)))
  GammaBarXY <- array(0,dim=c(c(dim(t(GammaXY))),nrow(DSGEDraws)))
  GammaBarXX <- array(0,dim=c(c(dim(GammaXX)),nrow(DSGEDraws)))
  #
  for(t in 1:nrow(DSGEDraws)){
    dsgeparameters <- DSGEDraws[t,]
    dsgeprior <- .DSGEVARPrior(dsgeparameters,Y,X,p,ObserveMat,partomats,priorform,priorpars,parbounds)
    GammaYY <- dsgeprior$GammaYY; GammaXY <- dsgeprior$GammaXY; GammaXX <- dsgeprior$GammaXX
    #
    GammaBarYY[,,t] <- GammaYY
    GammaBarXY[,,t] <- t(GammaXY)
    GammaBarXX[,,t] <- GammaXX
    #
  }
  #
  kcons <- (ncol(X)%%p!=0)*(ncol(X)%%p!=0)
  RepsRun <- .Call("DSGEVARRepsInf", GammaBarYY,GammaBarXY,GammaBarXX,lambda,nrow(DSGEDraws),nrow(Y),ncol(Y),p,kcons, PACKAGE = "BMR", DUP = FALSE)
  #
  if(parallel==FALSE){
    return=list(parameters=DSGEDraws,acceptRate=accept,Beta=RepsRun$Beta,Sigma=RepsRun$Sigma)
  }else{
    return(list(DSGEDraws,accept,RepsRun$Beta,RepsRun$Sigma))
  }
}

.DSGEVARMCMCMulti <- function(dsgemode,scalepar,keep,burnin,parMode,kdata,lambda,p,ObserveMat,partomats,priorform,priorpars,parbounds,chains,cores){
  #
  cl <- makeCluster(cores)
  registerDoSNOW(cl)
  #
  parallelsol <- 0
  if(is.finite(lambda)==TRUE){
    parallelsol <- foreach(jj=1:chains, .packages=c("BMR")) %dopar% {
      .DSGEVARMCMC(dsgemode,scalepar,keep,burnin,parMode,kdata,lambda,p,ObserveMat,partomats,priorform,priorpars,parbounds,parallel=TRUE)
    }
  }else{
    parallelsol <- foreach(jj=1:chains, .packages=c("BMR")) %dopar% {
      .DSGEVARMCMCInf(dsgemode,scalepar,keep,burnin,parMode,kdata,lambda,p,ObserveMat,partomats,priorform,priorpars,parbounds,parallel=TRUE)
    }
  }
  #
  stopCluster(cl)
  #
  DSGEDraws <- matrix(NA,nrow=keep*chains,ncol=length(dsgemode$par))
  accept <- numeric(chains)
  Beta <- array(NA,dim=c(nrow(kdata$XY),ncol(kdata$XY),keep*chains))
  Sigma <- array(NA,dim=c(ncol(kdata$XY),ncol(kdata$XY),keep*chains))
  #
  for(j in 1:chains){
    DSGEDraws[((j-1)*keep+1):(j*keep),] <- parallelsol[[j]][[1]]
    accept[j] <- parallelsol[[j]][[2]]
    Beta[,,((j-1)*keep+1):(j*keep)] <- parallelsol[[j]][[3]]
    Sigma[,,((j-1)*keep+1):(j*keep)] <- parallelsol[[j]][[4]]
  }
  #
  return=list(parameters=DSGEDraws,acceptRate=accept,Beta=Beta,Sigma=Sigma)
}

.DSGEVARMCMCPrint <- function(DSGEVARMCMCRes,chains,parMode,parModeSEs,parnames){
  #
  Diagnostics <- NULL
  if(chains==1){
    cat('Acceptance Rate: ', DSGEVARMCMCRes$acceptRate,'. \n', sep="")
  }else{
    cat('Acceptance Rate: ', sep="")
    for(kk in 1:(chains-1)){
      cat('Chain ',kk,': ', DSGEVARMCMCRes$acceptRate[kk],'; ', sep="")
    }
    cat('Chain ',chains,': ', DSGEVARMCMCRes$acceptRate[chains],'. \n', sep="")
    #
    # Chain convergence statistics:
    #
    Diagnostics <- matrix(.MCMCDiagnostics(DSGEVARMCMCRes$parameters,chains),nrow=1)
    #
    rownames(Diagnostics) <- "Stat:"
    if(class(parnames)=="character"){
      colnames(Diagnostics) <- parnames
    }
    #
    cat(' \n', sep="")
    cat('Root-R Chain-Convergence Statistics: \n', sep="")
    print(Diagnostics)
    cat(' \n', sep="")
  }
  #
  PostTable <- matrix(NA,nrow=length(parMode),ncol=4)
  PostTable[,1] <- parMode
  PostTable[,2] <- parModeSEs
  PostTable[,3] <- apply(DSGEVARMCMCRes$parameters,2,mean)
  PostTable[,4] <- apply(DSGEVARMCMCRes$parameters,2,sd)
  #
  colnames(PostTable) <- c("Posterior.Mode","SE.Mode","Posterior.Mean","SE.Posterior")
  if(class(parnames)=="character"){
    rownames(PostTable) <- parnames
  }
  cat(' \n', sep="")
  cat('Parameter Estimates and Standard Errors: \n', sep="")
  cat(' \n', sep="")
  print(PostTable)
  #
  return=list(Diagnostics=Diagnostics)
}

.DSGEVARIRFMatrices <- function(dsgepars,Sigma,p,ObserveMat,partomats,priorform,priorpars,parbounds){
  #
  DSGEVARImpact <- array(0,dim=dim(Sigma))
  #
  parameters <- c(dsgepars[1,]); NewImpact <- matrix(0,dim(Sigma)[1],dim(Sigma)[2])
  #
  for(i in 1:(dim(Sigma)[3])){
    parameters <- c(dsgepars[i,])
    SigmaEpsilon <- Sigma[,,i]
    #
    dsgemats <- partomats(parameters)
    dsgesolved <- SDSGE(dsgemats$A,dsgemats$B,dsgemats$C,dsgemats$D,dsgemats$F,dsgemats$G,dsgemats$H,dsgemats$J,dsgemats$K,dsgemats$L,dsgemats$M,dsgemats$N)
    #
    StateMats <- .DSGEstatespace(dsgesolved$N,dsgesolved$P,dsgesolved$Q,dsgesolved$R,dsgesolved$S)
    #
    Shocks <- matrix(0,nrow(StateMats$G),nrow(StateMats$G))
    Shocks[(nrow(StateMats$G)-nrow(dsgemats$shocks)+1):nrow(StateMats$G),(nrow(StateMats$G)-nrow(dsgemats$shocks)+1):nrow(StateMats$G)] <- sqrt(dsgemats$shocks)
    #
    Shocks <- StateMats$G%*%Shocks
    #
    GMatShocks <- Shocks[,(nrow(StateMats$G)-nrow(dsgemats$shocks)+1):nrow(StateMats$G)]
    #
    SigmaChol <- t(chol(SigmaEpsilon))
    #
    DSGEObservImpact <- t(ObserveMat)%*%GMatShocks
    #
    QR.DSGEObservImpact <- qr(t(DSGEObservImpact))
    Q <- (-1)*qr.Q(QR.DSGEObservImpact)
    R <- (-1)*qr.R(QR.DSGEObservImpact)
    #
    RDiag <- diag(R)
    RDiagPositive <- (RDiag>0)*matrix(1:ncol(ObserveMat))
    RDiagPositive <- RDiagPositive[RDiagPositive>0,]
    #
    S <- matrix(-1,ncol(ObserveMat),1)
    if(length(RDiagPositive)>0){
      S[RDiagPositive,] <- 1
    }
    S <- diag(c(S))
    Q <- Q%*%S
    #
    NewImpact <- SigmaChol%*%t(Q)
    #
    DSGEVARImpact[,,i] <- NewImpact
    #
  }
  #
  return(DSGEVARImpact)
}