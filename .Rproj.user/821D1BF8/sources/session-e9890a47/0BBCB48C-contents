# Run once:  source("install_packages.R")
pkgs <- c("httr", "jsonlite", "ncdf4", "hdf5r", "ggplot2")
new  <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(new)) install.packages(new)
for (p in pkgs) cat(sprintf("%-10s %s\n", p, as.character(packageVersion(p))))
