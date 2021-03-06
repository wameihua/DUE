#' pmvnorm.mixture
#' partialCumulative
#' 
#' Cumulative probability of a lognormal mixture distribution.
#' 
#' @param DUEenv Environment object or reactive values object containing model parameters.
#' @param Rrange Range of values for response (R) thresholds.
#' @param Trange Range of values for toxicity (T) thresholds.
#' @param i (partialCumulative) Which subgroup.
#' @param RorT (partialCumulative) Which threshold dimension.
#' @param logdose (partialCumulative) Logarithm (natural) of dose.
#' @param log10dose (partialCumulative) Logarithm (base 10) of dose.
#' @param utility Utility table for treating.
#' @details Details for pmvnorm.mixture

pmvnorm.mixture = function(DUEenv, Rrange, Trange) {
  vEpsilon =  diag(rep(1e-8,2))  ### in case a variance got stuck at zero.
  sum(apply(as.array(1:DUEenv$nPops), 1, function(i)
    DUEenv$proportions[i] * pmvnorm(lower=c(Rrange[1], Trange[1]), upper=c(Rrange[2], Trange[2]), 
                                    mean=DUEenv$the.logmedians.pop[[i]],
                                    sigma=vEpsilon + DUEenv$the.variances.pop[[i]])) )
}

#' partialCumulative
#' 
#' @description Normal univariate cumulative for one subgroup
#' 
#' @details Details for pmvnorm.mixture

partialCumulative = 
  function(DUEenv, i, RorT, logdose) {
    DUEenv$proportions[i] * pnorm(logdose, 
                                  mean=DUEenv$the.logmedians.pop[[i]] [RorT], 
                                  sd=sqrt(DUEenv$the.variances.pop[[i]] [RorT,RorT]))
  }

#' calculate.probabilities
#' 
#' 
#' @description Produce a vector of probabilities and expected utility.
#' @details calculate.probabilities
#' 
#' @return A vector of length 8:
#' \code{
#' probability.vector <- c(
#' R=p.R.marginal, # marginal probability of response
#' T=p.T.marginal, # marginal probability of toxicity 
#' rt=p.rt,        # probability of non-response and non-toxicity 
#' rT=p.rT,        # probability of non-response and toxicity
#' Rt=p.Rt,        # probability of response and non-toxicity
#' RT=p.RT,        # probability of response and toxicity
#' EU=expected.utility,        # 
#' RLE=p.RLE       # probability of response-limiting toxicity event
#'                 #  (a toxicity so severe that R cannot happen, 
#'                 # or might as well not have;  RLE has occurred.)
#' )
#' }
#'
#' @examples
#'   DUEshinyHome = system.file(package='DUE'
#'   , 'DUEshiny')
#'   aFile = grep(v=T, 'Simple-One-Pop-tight-CV.rdata', dir(DUEshinyHome))
#'   load(paste(DUEshinyHome, aFile, sep='/'))
#'   calculate.probabilities(DUEsaving, log10dose = 2.3)

calculate.probabilities <-
  function(DUEenv, log10dose, logdose, utility, ...) {
    
    if(missing(utility))
      utility = DUEenv$utility
    else if(is.character(utility)) 
      utility = DUEenv$utilityChoices[utility]
    
    if(!missing(log10dose))
      logdose = log(10) * log10dose
    
    # if(! missing(changes))
    #   eval(parse(text=changes), envir = DUEenv)
    arglist = list(...)
    for(arg in names(arglist))  DUEenv[[arg]] = arglist[[arg]]
    
    
    p.R.marginal <-  sum(apply(as.array(1:DUEenv$nPops), 1, partialCumulative, DUEenv=DUEenv, RorT=1, logdose=logdose) )
    p.T.marginal <-  sum(apply(as.array(1:DUEenv$nPops), 1, partialCumulative, DUEenv=DUEenv, RorT=2, logdose=logdose) )
    
    p.rt <- pmvnorm.mixture(DUEenv=DUEenv, 
                            Rrange=c(logdose, Inf), Trange=c(logdose, Inf))
    p.rT <- pmvnorm.mixture(DUEenv=DUEenv, 
                            Rrange=c(logdose, Inf), Trange=c(-Inf, logdose))
    p.Rt <- pmvnorm.mixture(DUEenv=DUEenv, 
                            Rrange=c(-Inf, logdose), Trange=c(logdose, Inf))
    p.RT <- pmvnorm.mixture(DUEenv=DUEenv, 
                            Rrange=c(-Inf, logdose), Trange=c(-Inf, logdose))
    ## Adjustments for response-limiting events (RLE)
    p.RLE <- pmvnorm.mixture(DUEenv=DUEenv, 
                             Rrange=c(-Inf, logdose), 
                             Trange=c(-Inf, logdose - DUEenv$Kdeath/log(10)))

    ## Kdeath = 0 means that
    ## People whose tox threshold is below logdose will have toxicity.
    ## People whose tox threshold is below logdose - Kdeath will have 
    ## toxicity so severe that R cannot happen;  RLE has occurred.
    ## Thus Kdeath = 0 means that RT cannot happen.
    ## But Kdeath = Inf means that RLE never happens.
    
    #### Adjustments for response-limiting events (RLE) ####
    p.rT <- p.rT + p.RLE   #RLE converts RT events into rT events.
    p.RT <- p.RT - p.RLE
    
    negativeSanity = -1e-4
    
    #### Sanity tests ####
    if(any(c(p.RT, p.Rt, p.rT, p.rt, p.RLE) < negativeSanity))
      browser(text = 'negative probability problem')
    if( abs(p.RT + p.Rt + p.RLE - p.R.marginal)  >  0.01)
      browser(text = 'p.R problem')
    if( abs(p.RT + p.rT - p.T.marginal)  >  0.01)
      browser(text = 'p.T problem')
    
    ####  Adjustments for refractoriness: ####  
    # Every R category is converted proportionally to its corresponding "r". 
    p.rT <- p.rT + DUEenv$refractory*p.RT
    p.RT <- p.RT - DUEenv$refractory*p.RT
    p.rt <- p.rt + DUEenv$refractory*p.Rt
    p.Rt <- p.Rt - DUEenv$refractory*p.Rt
    p.RLE <- p.RLE - DUEenv$refractory*p.RLE
    p.R.marginal <- p.R.marginal - DUEenv$refractory*p.R.marginal

        #### Sanity tests ####
    if(any(c(p.RT, p.Rt, p.rT, p.rt, p.RLE) < negativeSanity))
      browser(text = 'negative probability problem')
    if( abs(p.RT + p.Rt + p.RLE - p.R.marginal)  >  0.01)
      browser(text = 'p.R problem')
    if( abs(p.RT + p.rT - p.T.marginal)  >  0.01)
      browser(text = 'p.T problem')
    
    pQuadrants <- c(p.rt,p.rT,p.Rt,p.RT)
    #read.Uvalues()  ### copies from the sliders to the vector "utility"
    expected.utility <- sum(pQuadrants*utility)
    if(	browseIf(FALSE
                 #exp(logdose) > 950
                 , message="Let's check on utility")) {
      #browser()
      cat("---- ", exp(logdose), " ----\n")
      print(pQuadrants)
      print(utility)
      print(DUEenv$utility)
      print(expected.utility)
    }
    probability.vector <- c(
      R=p.R.marginal,
      T=p.T.marginal,
      rt=p.rt,
      rT=p.rT,
      Rt=p.Rt,
      RT=p.RT,
      EU=expected.utility,
      RLE=p.RLE
    )
    return(probability.vector)
  }

calculate.probabilities.allDoses <- function(DUEenv, ...) {
    sapply(log10(DUEenv$doseValues), calculate.probabilities, DUEenv=DUEenv, ... = ...)
}

extractUtilitySummaries <- function(eightprobs, doseValues, MTDtoxicity) {
  highestprob.Rt = max(eightprobs["Rt",])
  highest.EU = max(eightprobs["EU",])
  lowestprob.Rt = min(eightprobs["Rt",])
  lowest.EU = min(eightprobs["EU",])
  best.dose.p.Rt = doseValues[eightprobs["Rt",]==highestprob.Rt]
  best.dose.EU = doseValues[eightprobs["EU",]==highest.EU] [1]
  best.dose.p.T = max(doseValues[(eightprobs["T",]-MTDtoxicity)<=0])
  return(data.frame(
    highestprob.Rt,
    highest.EU,
    lowestprob.Rt,
    lowest.EU,
    best.dose.p.Rt,
    best.dose.EU,
    best.dose.p.T
  ))  
}

#### TODO:  work needed : save extractUtilitySummaries. ####
calculate.probabilities <- function(design, DUEenvRow=DUEinits.default, ...) {
  # For each row of the design matrix, place the values in calculate the 
  sapply(1:nrow(design), function(row){
    arglist = design[row, ]
    for(arg in names(arglist))  DUEenv[[arg]] = arglist[[arg]]
    calculate.probabilities (DUEenv, log10dose=2, utility, ...) 
    ### TODO save extractUtilitySummaries
  })
  DUEenv$eightprobs <- 
    sapply(log10(DUEenv$doseValues), calculate.probabilities, DUEenv=DUEenv)
}

checkcalcs=function(...){
  p7=calculate.probabilities(DUEenv=denv, 3, ...); 
  c(sum=sum(p7[3:6]), 
    Rsum=p7['Rt']+p7['RT']+p7['RLE'],
    Tsum=p7['RT']+p7['rT'],
    p7)
}
