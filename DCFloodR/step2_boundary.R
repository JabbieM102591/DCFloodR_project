# Step 2a - download the outline of Washington, DC (map context and the inside-DC test for gauges/stations).
# If the download fails the project still runs with a rectangle (DC bounding box) and says so.
source("R/setup.R")
ensure_dirs()
log <- new_log("boundary")
res <- tryCatch(fetch_dc_boundary(), error = function(e) e)
if (inherits(res, "error")) {
  log_add(log, "dc_boundary", "DC outline", "https://nominatim.openstreetmap.org/search", "failed", 0, substr(conditionMessage(res), 1, 200))
  cat("Could not download the DC outline (", conditionMessage(res), ") - a bounding-box rectangle will be used instead.\n")
} else {
  utils::write.csv(data.frame(lon = res$lon, lat = res$lat), file.path(DIR$interim, "dc_boundary.csv"), row.names = FALSE)
  writeLines(res$note, file.path(DIR$interim, "dc_boundary_source.txt"))
  log_add(log, "dc_boundary", "DC outline", "https://nominatim.openstreetmap.org/search", "ok", length(res$lon), res$note)
  cat("DC boundary saved:", length(res$lon), "points\n")
}
invisible(log_save(log))
