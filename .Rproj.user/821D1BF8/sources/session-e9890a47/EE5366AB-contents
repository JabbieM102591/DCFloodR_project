# make_zip.R - zip the project for backup (no temporary downloads, caches or credentials).  source("make_zip.R")
files <- list.files(".", recursive = TRUE, all.files = TRUE, include.dirs = FALSE)
files <- files[!grepl("^data/interim/|^\\.Rproj\\.user/|\\.zip$|^\\.git/|\\.Rhistory$|\\.RData$|\\.Renviron$", files)]
out <- file.path("..", "DCFloodR_submission.zip")
if (file.exists(out)) file.remove(out)
utils::zip(out, files = files, flags = "-q")
cat("wrote", normalizePath(out), "with", length(files), "files\n")
