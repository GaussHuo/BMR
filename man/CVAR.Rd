\name{CVAR}

\alias{CVAR}

\title{Classical VAR.}

\description{
  OLS estimation of a VAR model with bootstrapped IRFs.
}

\usage{
CVAR(mydata,p=4,constant=TRUE,irf.periods=20,boot=10000)
}

\arguments{
  \item{mydata}{
  A matrix or data frame containing the series to be used in estimation, and should be of size T x m.}
	\item{p}{
	The number of lags to include of each variable. The default value is 4.}
	\item{constant}{
	A logical statement on whether to include a constant vector in the model. The default is `TRUE', and the alternative is `FALSE'.}
	\item{irf.periods}{
	An integer value for the horizon of the impulse response calculations; this value must be greater than zero. The default value is 20.}
	\item{boot}{
	The number of bootstrapped replications to run for the IRFs. The default is 10,000.}
}

\details{
  For technical details of the model, see the accompanying vignette.
}

\value{
The function returns an object of class CVAR, which contains:

  \item{Beta}{
	A matrix of size (m p + 1_c) x m containing the OLS estimate of the coefficient matrix, beta.}
	\item{BDraws}{
	An array of size (m p + 1_c) x m x keep which contains the beta draws from the bootstrapped run.}
	\item{Sigma}{
	A matrix of size m x m containing the OLS estimate of the residual covariance matrix, Sigma.}
	\item{SDraws}{
	An array of size m x m x keep which contains Sigma draws from the bootstrapped run.}
	\item{IRFs}{
	A four-dimensional object of size irf.periods x m x boot x m containing the impulse response function calculations; the first m refers to the responses to the last m shock. Note: IRF calculations are based on a one standard deviation shock to each variable.}
	\item{data}{
	The data used for estimation.}
	\item{constant}{
	A logical value, TRUE or FALSE, indicating whether the user chose to include a vector of constants in the model.}
}

\author{Keith O'Hara}

\examples{
\dontrun{
data(BMRVARData)
testcvar <- CVAR(USMacroData[,2:4],p=4,constant=TRUE,irf.periods=20,boot=10000)
}
}

\keyword{VAR}
\concept{VAR}