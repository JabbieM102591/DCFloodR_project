# Loaded by every step script. Runs once per R session.
if (!exists(".dc_setup_done", inherits = TRUE)) {
  need <- c("httr", "jsonlite", "ncdf4", "hdf5r", "ggplot2")
  miss <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
  if (length(miss)) stop("Missing R packages: ", paste(miss, collapse = ", "),
                         "\nRun first:  source('install_packages.R')", call. = FALSE)
  source("config.R")
  source("R/utils.R")
  source("R/fetchers.R")
  .dc_setup_done <- TRUE
}
