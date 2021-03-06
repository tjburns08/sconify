% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/post.processing.R
\name{StringToNumbers}
\alias{StringToNumbers}
\title{Transform strings to numbers.}
\usage{
StringToNumbers(strings)
}
\arguments{
\item{strings}{vector of strings}
}
\value{
strings: same vector with each unique element converted to a number
}
\description{
Takes a vector of strings and outputs simple numbers. This
takes care of the case where conditions are listed as strings (basal, IL7),
in which case they are converted to numbers (1, 2)
}
\examples{
ex.string <- c("unstim", "unstim", "stim", "stim", "stim")
StringToNumbers(ex.string)
}
