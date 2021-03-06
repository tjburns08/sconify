% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/knn.and.statistics.R
\name{MakeKnnList}
\alias{MakeKnnList}
\title{Make list of cells by features for each KNN member}
\usage{
MakeKnnList(cell.data, nn.matrix)
}
\arguments{
\item{cell.data}{tibble of cells by features}

\item{nn.matrix}{list of 2. First element is cells x 100 nearest neighbor
indices. Second element is cells x 100 nearest neighbor distances}
}
\value{
a list where each element is the cell number from the
original cell.data tibble and a matrix of cells x feautures for its KNN
}
\description{
Takes the KNN function output and the cell data, and
makes list where each element is a matrix of cells in the KNN and features.
}
\examples{
ex.knn <- Fnn(wand.combined, input.markers, k = 30)
knn.list <- MakeKnnList(wand.combined, ex.knn)
}
