% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/experimental.R
\name{drop_category}
\alias{drop_category}
\title{Validate and coerce any object as a non-categorical variable.}
\usage{
drop_category(x)
}
\arguments{
\item{x}{object to be coerced.}
}
\value{
A R object.
}
\description{
\ifelse{html}{\href{https://lifecycle.r-lib.org/articles/stages.html#experimental}{\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}}}{\strong{[Experimental]}}
Converts a vector object to a non-categorical object, typically a column in a
data frame. The categories come from non-missing values present in the
object and are suppressed from an associated data dictionary (when present).
}
\examples{
{

head(iris[['Species']])
head(drop_category(iris[['Species']]))

}

}
