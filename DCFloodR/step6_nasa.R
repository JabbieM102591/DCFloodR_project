# Step 6 (extra credit) - search NASA OPERA surface-water products (DSWx) near the event dates.
# Uses the public NASA CMR granule search (no login). It lists which scenes exist; downloading images needs a free
# NASA Earthdata login, which this project does NOT store or use. Each scene is reported with its acquisition time and
# the time lag after the event. Writes data/interim/nasa_granules.csv and reports/nasa_search.md.
source("R/setup.R")
ensure_dirs()
ev <- load_events_index()
log <- new_log("nasa")
bbox <- c(west = DC_BBOX[["west"]] - 0.02, south = DC_BBOX[["south"]] - 0.02, east = DC_BBOX[["east"]] + 0.02, north = DC_BBOX[["north"]] + 0.02)
rows <- list(); summ <- list()
for (i in seq_len(nrow(ev))) for (coll in NASA_COLLECTIONS) {
  t0 <- ev$begin_t[i] - NASA_DAYS_BEFORE * 86400; t1 <- ev$end_t[i] + (NASA_DAYS_AFTER + 1) * 86400
  res <- tryCatch(cmr_search(coll, bbox, iso_z(t0), iso_z(t1)), error = function(e) list(df = parse_cmr_granules(list()), url = "", status = paste("failed:", conditionMessage(e))))
  log_add(log, "nasa_cmr", paste(ev$event_id[i], coll), res$url, res$status, nrow(res$df))
  summ[[length(summ) + 1]] <- data.frame(event = ev$event_id[i], date = substr(ev$begin_local[i], 1, 10), collection = coll, status = res$status, n = nrow(res$df), stringsAsFactors = FALSE)
  if (nrow(res$df)) {
    d <- res$df; d$event_id <- ev$event_id[i]; d$event_begin_utc <- ev$begin_utc[i]; d$search_collection <- coll
    ts <- as.POSIXct(sub("\\.[0-9]+Z$", "Z", d$time_start), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    d$lag_days_after_event_end <- round(as.numeric(difftime(ts, ev$end_t[i], units = "days")), 2)
    rows[[length(rows) + 1]] <- d
  }
  Sys.sleep(0.15)
}
out <- if (length(rows)) do.call(rbind, rows) else data.frame(granule_id = character(), time_start = character(), time_end = character(),
        cloud_cover = character(), collection = character(), data_links = character(), event_id = character(), event_begin_utc = character(),
        search_collection = character(), lag_days_after_event_end = numeric())
utils::write.csv(out, file.path(DIR$interim, "nasa_granules.csv"), row.names = FALSE)
S <- do.call(rbind, summ); n <- sum(S$n); bad <- S[S$status != "ok", ]
yrs <- table(substr(S$date[S$n > 0], 1, 4))
lines <- c("# NASA surface-water (extra credit) - search report", "",
           sprintf("Products searched: %s (OPERA DSWx, 30 m; HLS optical and Sentinel-1 radar).", paste(NASA_COLLECTIONS, collapse = ", ")),
           sprintf("Window: %d day before event begin to %d days after event end; area: DC bounding box (+0.02 degree).", NASA_DAYS_BEFORE, NASA_DAYS_AFTER),
           sprintf("Events searched: %d; searches made: %d; searches that failed: %d; total scenes listed: %d.", nrow(ev), nrow(S), nrow(bad), n), "",
           if (n > 0) sprintf("Events with at least one scene: %d.", length(unique(S$event[S$n > 0]))) else "No scene was found for any event (the OPERA DSWx products start in 2023, so earlier events cannot have a scene).", "",
           "| event | date | collection | search status | scenes found |", "|---|---|---|---|---|",
           sprintf("| %s | %s | %s | %s | %d |", S$event[S$n > 0 | S$status != "ok"], S$date[S$n > 0 | S$status != "ok"], S$collection[S$n > 0 | S$status != "ok"], S$status[S$n > 0 | S$status != "ok"], S$n[S$n > 0 | S$status != "ok"]),
           "", "(Only searches that found scenes or failed are listed in the table; all others returned zero scenes.)", "",
           "A scene found after the event shows water that was still present then; a scene without detected water does not show that a short urban flood did not occur. Scenes were NOT downloaded (Earthdata login required); only their metadata are stored in the HDF5 file under /nasa.")
write_md(lines, file.path(DIR$reports, "nasa_search.md"))
invisible(log_save(log))
cat(sprintf("NASA search: %d scene(s) listed for %d event(s)\n", n, nrow(ev)))
