# Step 8 - demonstrate the access functions on one representative event and write the availability report.
# Everything below reads ONLY data/output/dc_flood_database.h5 (through dcflood_h5.R).
# RStudio Console:  source("step8_demo.R")                         (picks the event with the most valid observations)
#                   EVENT_ID <- "EV094"; source("step8_demo.R")    (choose an event yourself)
source("R/setup.R")
source("dcflood_h5.R")
ensure_dirs()
h5 <- H5_PATH
if (!file.exists(h5)) stop("Build the database first: source(\"step7_build_h5.R\")", call. = FALSE)

cov <- coverage_summary(h5)
ev_id <- if (exists("EVENT_ID")) EVENT_ID else { v <- tapply(cov$valid, cov$event_id, sum); names(v)[which.max(v)] }

cat("Database description\n"); describe(h5)
cat("\nVariables\n"); print(list_variables(h5), row.names = FALSE)
cat("\nCoverage by source for", ev_id, "\n"); print(coverage_summary(h5, event_id = ev_id), row.names = FALSE)
ev <- list_events(h5); ev <- ev[ev$event_id == ev_id, ]
cat(sprintf("\nRepresentative event %s: %s to %s (local)\n", ev_id, ev$begin_local, ev$end_local))

# rasters (Daymet day = UTC date label; use the UTC date of the event start)
src <- list_sources(h5); rsrc <- src$source[src$kind == "raster"]
d <- substr(ev$begin_utc, 1, 10)
for (s in rsrc) {
  r <- tryCatch(get_raster(h5, ev_id, s, d), error = function(e) { message("get_raster: ", conditionMessage(e)); NULL })
  if (!is.null(r)) cat(sprintf("raster %s %s: %d x %d cells, units %s, max %s, valid %s .. %s\n", s, r$date_utc, nrow(r$data), ncol(r$data),
      r$units, format(suppressWarnings(max(r$data, na.rm = TRUE))), r$valid_start_utc, r$valid_end_utc))
  tryCatch(plot_raster(h5, ev_id, s, d, save = file.path(DIR$figures, sprintf("%s_%s_%s.png", ev_id, s, d))),
           error = function(e) message("plot_raster: ", conditionMessage(e)))
}

# time series: every stored series with records in this window
st <- list_stations(h5); st <- st[st$stored == "yes", , drop = FALSE]
n <- 0
for (i in seq_len(nrow(st))) {
  df <- get_timeseries(h5, st$source[i], st$station_id[i], st$variable[i], event_id = ev_id)
  if (!nrow(df)) next
  plot_timeseries(h5, st$source[i], st$station_id[i], st$variable[i], event_id = ev_id,
                  save = file.path(DIR$figures, sprintf("%s_%s_%s_%s.png", ev_id, st$source[i], st$station_id[i], st$variable[i])))
  n <- n + 1
  if (n <= 3) {
    cat(sprintf("\nseries %s/%s/%s: %d records; unit %s\n", st$source[i], st$station_id[i], st$variable[i], nrow(df), attr(df, "meta")$unit))
    print(utils::head(df[, c("time_utc", "value", "quality")], 4), row.names = FALSE)
  }
}
cat(sprintf("\n%d time-series figure(s) written to figures/\n", n))
plot_coverage_heatmap(h5, save = file.path(DIR$figures, "coverage_heatmap.png"))

# availability report (from the HDF5 file only)
a <- .with_h5(h5, function(f) read_table(f[["metadata/availability"]]))
for (cn in c("expected", "n_valid", "n_zero", "n_present_not_valid", "n_missing", "max_gap_steps")) a[[cn]] <- as.numeric(a[[cn]])
ser <- list_stations(h5)
lg <- .with_h5(h5, function(f) read_table(f[["metadata/retrieval_log"]]))
evs <- list_events(h5); ok <- evs[evs$status == "ok", ]
L <- c("# Data availability and missingness report", "",
       sprintf("Generated from `%s`. Events in the CSV: %d, valid: %d. Assignment: Version %s (%s + %s).", basename(h5), nrow(evs), nrow(ok),
               ASSIGNMENT$version, ASSIGNMENT$factor_a, ASSIGNMENT$factor_b),
       sprintf("Each event window runs from %d h before the begin time to %d h after the end time (America/New_York local time).", PAD_BEFORE_H, PAD_AFTER_H), "",
       "Reading guide: *expected* = values that would exist if the source were complete in the window; *valid* = present and usable; *zero* = valid values equal to 0 (real dry or flat intervals); *missing* = expected but absent; *flagged* = a record exists but its value was removed (quality flag / NoData). Missing is never converted to zero.", "",
       "## Summary by source", "", "| source | series | event windows with any valid data | valid / expected | zero values | flagged | longest gap (steps) |", "|---|---|---|---|---|---|---|")
for (s in unique(a$source)) {
  g <- a[a$source == s, ]; w <- tapply(g$n_valid, g$event_id, sum)
  L <- c(L, sprintf("| %s | %d | %d of %d | %d / %d (%.1f%%) | %d | %d | %d |", s, nrow(unique(g[, c("station_id", "variable")])), sum(w > 0), length(w),
                    sum(g$n_valid), sum(g$expected), 100 * sum(g$n_valid) / max(sum(g$expected), 1), sum(g$n_zero), sum(g$n_present_not_valid), max(g$max_gap_steps)))
}
L <- c(L, "", "## By event and source", "", "| event | begin (local) | source | expected | valid | missing | % valid |", "|---|---|---|---|---|---|---|",
       sprintf("| %s | %s | %s | %d | %d | %d | %s |", cov$event_id, ok$begin_local[match(cov$event_id, ok$event_id)], cov$source, cov$expected, cov$valid, cov$missing, cov$pct_valid))
if (nrow(ser)) L <- c(L, "", "## Stations and gauges requested", "", "| source | station | variable | name | lat | lon | inside DC | records stored | request status |", "|---|---|---|---|---|---|---|---|---|",
       sprintf("| %s | %s | %s | %s | %s | %s | %s | %s | %s |", ser$source, ser$station_id, ser$variable, ser$station_name, ser$latitude, ser$longitude, ser$in_dc, ser$n_records, substr(ser$request_status, 1, 60)))
bad <- lg[!startsWith(lg$status, "ok"), , drop = FALSE]
L <- c(L, "", "## Unsuccessful or partial retrievals", "")
if (nrow(bad)) {
  t <- as.data.frame(table(bad$source, substr(bad$status, 1, 50)), stringsAsFactors = FALSE); t <- t[t$Freq > 0, ]
  L <- c(L, sprintf("%d of %d logged requests did not return normally.", nrow(bad), nrow(lg)), "", "| source | status | requests |", "|---|---|---|", sprintf("| %s | %s | %d |", t$Var1, t$Var2, t$Freq))
} else L <- c(L, "None recorded.")
miss <- a[a$status != "complete", , drop = FALSE]; miss <- utils::head(miss[order(-miss$expected), ], 60)
if (nrow(miss)) L <- c(L, "", "## Windows that are not complete (first 60 by size)", "", "| event | source | station | variable | status | valid/expected | longest gap |", "|---|---|---|---|---|---|---|",
       sprintf("| %s | %s | %s | %s | %s | %d/%d | %d |", miss$event_id, miss$source, miss$station_id, miss$variable, miss$status, miss$n_valid, miss$expected, miss$max_gap_steps))
L <- c(L, "", "## Interpretation notes", "",
       "- Daymet gives one nominal daily total per grid cell, so it cannot resolve the timing of a flood that lasted a few hours; the gauges can.",
       "- Gage height, tide-gauge water level and streamflow are different quantities and are stored separately; zero streamflow is a real value, a missing record is not.",
       "- Gridded values are 1 km cell values; gauge values are point measurements; they are not interchangeable.",
       "- Daymet has no 31 December in leap years and may not yet cover the most recent year; such days appear as missing slices with a reason.",
       "- A NASA scene that does not exist for an event means no suitable acquisition, not that no flooding occurred.")
writeLines(L, file.path(DIR$reports, "availability_report.md"), useBytes = TRUE)
utils::write.csv(cov, file.path(DIR$reports, "coverage_summary.csv"), row.names = FALSE)
cat("reports/availability_report.md and reports/coverage_summary.csv written\n")
