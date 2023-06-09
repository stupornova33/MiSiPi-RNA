% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_max_si_heat.R
\name{get_max_si_heat}
\alias{get_max_si_heat}
\title{function to find max_si heatmap cell values
takes a matrix created from siRNA function
finds max row, column, and count of highest cell
returns highest_si_row, highest_si_col, second_si_row, second_si_col, highest_si_count, second_si_count as a data frame}
\usage{
get_max_si_heat(si_res)
}
\arguments{
\item{si_res}{a data table}
}
\value{
max_si_df
}
\description{
function to find max_si heatmap cell values
takes a matrix created from siRNA function
finds max row, column, and count of highest cell
returns highest_si_row, highest_si_col, second_si_row, second_si_col, highest_si_count, second_si_count as a data frame
}
