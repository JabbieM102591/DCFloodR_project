# Step 5 - independent investigation: precipitation stations physically INSIDE Washington, DC.
# Strategy (all written to reports/in_dc_search.md so the search itself is documented):
#  1. NOAA GHCN-Daily station list + inventory: every station with a PRCP record whose coordinates fall in the DC box,
#     then an exact point-in-polygon test against the DC outline. (CoCoRaHS volunteer gauges and NWS cooperative
#     stations are distributed through GHCN-Daily, so this one search covers them.)
#  2. USGS site catalogue: any DC site that reports precipitation (parameter 00045).
#  3. Stations outside the polygon are listed but NOT used as in-DC stations.
# Data: one request per station and calendar year (the days between the first and last event window of that year);
# rows outside the event windows are dropped before storing.
source("R/setup.R")
ensure_dirs()
ev <- load_events_index()
log <- new_log("in_dc")
wins <- merge_intervals(ev$window_start, ev$window_end)
ev_years <- as.integer(format(ev$begin_t, "%Y", tz = EVENT_TZ))
win_days <- data.frame(d0 = as.Date(substr(ev$window_start_local, 1, 10)), d1 = as.Date(substr(ev$window_end_local, 1, 10)))
in_windows <- function(d) vapply(d, function(x) any(x >= win_days$d0 & x <= win_days$d1), TRUE)

lines <- c("# Independent search: precipitation stations inside Washington, DC", "", "## Search strategy", "",
           "1. NOAA GHCN-Daily station list and inventory (includes CoCoRaHS volunteer gauges and NWS cooperative stations), filtered to the DC bounding box and then to the DC outline (point-in-polygon).",
           "2. USGS site catalogue: sites in the DC box reporting precipitation (parameter 00045).",
           "3. Airports (DCA, IAD, BWI) are outside DC and are not counted as in-DC stations.", "",
           sprintf("DC outline used: %s", load_dc_boundary()$note), "", "## Results", "")

# 1. GHCN-Daily
box <- NULL
cat("Downloading the NOAA station list and inventory (large files, can take a few minutes)...\n")
st <- tryCatch({ a <- http_get(GHCND_STATIONS_URL); b <- http_get(GHCND_INVENTORY_URL); list(a = a, b = b) }, error = function(e) e)
if (inherits(st, "error")) {
  log_add(log, "in_dc_search", "ghcnd station list", GHCND_STATIONS_URL, "failed", 0, conditionMessage(st))
  lines <- c(lines, sprintf("- GHCN-Daily station list could not be downloaded (%s).", conditionMessage(st)))
} else if (st$a$status != 200 || st$b$status != 200) {
  log_add(log, "in_dc_search", "ghcnd station list", GHCND_STATIONS_URL, sprintf("HTTP %d/%d", st$a$status, st$b$status), 0)
  lines <- c(lines, sprintf("- GHCN-Daily station list returned HTTP %d/%d.", st$a$status, st$b$status))
} else {
  cat("Station files downloaded; reading them...\n")
  stn <- parse_ghcnd_stations(resp_text(st$a)); inv <- parse_ghcnd_inventory(resp_text(st$b)); inv <- inv[inv$element == "PRCP", ]
  log_add(log, "in_dc_search", "ghcnd station list", GHCND_STATIONS_URL, "ok", nrow(stn))
  bx <- stn[stn$longitude >= DC_BBOX[["west"]] & stn$longitude <= DC_BBOX[["east"]] & stn$latitude >= DC_BBOX[["south"]] & stn$latitude <= DC_BBOX[["north"]], ]
  box <- merge(bx, inv[, c("id", "first_year", "last_year")], by = "id")
  if (nrow(box)) box$inside <- vapply(seq_len(nrow(box)), function(i) in_dc(box$latitude[i], box$longitude[i]), TRUE)
  lines <- c(lines, sprintf("- GHCN-Daily: %d stations worldwide read; %d have PRCP records inside the DC bounding box; %d of them are inside the DC outline.",
                            nrow(stn), nrow(box), sum(box$inside)))
}
parts <- list(); metas <- list(); chosen <- NULL
if (!is.null(box) && nrow(box)) {
  box <- box[order(box$id), ]
  lines <- c(lines, "", "### All PRCP stations found in the DC bounding box", "",
             "| station | name | lat | lon | state label | years of record | inside DC outline |", "|---|---|---|---|---|---|---|",
             sprintf("| %s | %s | %.4f | %.4f | %s | %d-%d | %s |", box$id, box$name, box$latitude, box$longitude, box$state, box$first_year, box$last_year, ifelse(box$inside, "yes", "NO")))
  ins <- box[box$inside, , drop = FALSE]
  if (nrow(ins)) {
    ins$events_covered <- vapply(seq_len(nrow(ins)), function(i) sum(ev_years >= ins$first_year[i] & ev_years <= ins$last_year[i]), 1L)
    chosen <- ins[ins$events_covered > 0, , drop = FALSE]
    chosen <- head(chosen[order(-chosen$events_covered, chosen$id), , drop = FALSE], IN_DC_MAX_STATIONS)
  }
  lines <- c(lines, "", sprintf("Stations inside DC whose record period covers at least one event year: %d (at most %d are downloaded).", nrow(chosen) %||% 0, IN_DC_MAX_STATIONS))
}
if (!is.null(chosen) && nrow(chosen)) for (i in seq_len(nrow(chosen))) {
  id <- chosen$id[i]; pieces <- list(); stat <- character()
  cat(sprintf("Downloading daily precipitation for station %s (%d of %d)...\n", id, i, nrow(chosen)))
  yrs <- sort(unique(unlist(lapply(seq_len(nrow(win_days)), function(k) as.integer(format(win_days$d0[k], "%Y")):as.integer(format(win_days$d1[k], "%Y"))))))
  yrs <- yrs[yrs >= chosen$first_year[i] & yrs <= chosen$last_year[i]]
  whole <- tryCatch(fetch_ghcnd_dly(id), error = function(e) list(df = empty_ghcnd(), url = "", status = paste("failed:", conditionMessage(e))))
  log_add(log, "ghcnd_dc", paste(id, "station history file"), whole$url, whole$status, nrow(whole$df))
  if (whole$status == "ok") {
    cat(sprintf("  %s: whole station file downloaded (%d daily values)\n", id, nrow(whole$df)))
    df <- whole$df
    if (nrow(df)) { df$latitude <- chosen$latitude[i]; df$longitude <- chosen$longitude[i]; df$name <- chosen$name[i]
    df <- df[in_windows(as.Date(substr(df$date, 1, 10))), , drop = FALSE] }
    stat <- "ok (station history file)"; pieces[[1]] <- df; yrs <- integer()
  } else cat(sprintf("  station file not available (%s); trying year by year\n", whole$status))
  for (y in yrs) {
    cat(sprintf("  %s year %d\n", id, y))
    inside <- win_days$d1 >= as.Date(sprintf("%d-01-01", y)) & win_days$d0 <= as.Date(sprintf("%d-12-31", y))
    s0 <- max(min(win_days$d0[inside]), as.Date(sprintf("%d-01-01", y))); s1 <- min(max(win_days$d1[inside]), as.Date(sprintf("%d-12-31", y)))
    res <- tryCatch(fetch_ghcnd(id, as.character(s0), as.character(s1)), error = function(e) list(df = empty_ghcnd(), url = "", status = paste("failed:", conditionMessage(e))))
    df <- res$df; if (nrow(df)) df <- df[in_windows(as.Date(substr(df$date, 1, 10))), , drop = FALSE]
    log_add(log, "ghcnd_dc", sprintf("%s %s..%s", id, s0, s1), res$url, res$status, nrow(df))
    stat <- c(stat, res$status); pieces[[length(pieces) + 1]] <- df; Sys.sleep(0.3)
  }
  df <- if (length(pieces)) do.call(rbind, pieces) else empty_ghcnd()
  if (nrow(df)) parts[[length(parts) + 1]] <- ghcnd_to_long(df, "ghcnd_dc", id)
  metas[[length(metas) + 1]] <- meta_row(source = "ghcnd_dc", station_id = id, variable = "precip_daily_mm", unit = "mm",
                                         station_name = chosen$name[i], latitude = chosen$latitude[i], longitude = chosen$longitude[i], in_dc = "yes",
                                         request_status = paste(sort(unique(stat)), collapse = "; "), n_records = nrow(df),
                                         semantics = "24 h accumulation ending at observation time (see TOBS in quality)", nominal_step_min = 1440,
                                         note = sprintf("record period %d-%d per GHCN-Daily inventory", chosen$first_year[i], chosen$last_year[i]))
}
save_source("ghcnd_dc", parts, metas)
cat("GHCN-Daily part finished. Now checking USGS precipitation sites...\n")

# 2. USGS precipitation sites inside DC (parameter 00045)
parts <- list(); metas <- list()
sr <- tryCatch(usgs_sites_legacy(DC_BBOX, "00045"), error = function(e) list(sites = NULL, url = "", status = paste("failed:", conditionMessage(e))))
log_add(log, "in_dc_search", "USGS sites with 00045 in DC box", sr$url, sr$status, nrow(sr$sites) %||% 0)
ids <- character()
if (!is.null(sr$sites)) {
  sr$sites$inside <- vapply(seq_len(nrow(sr$sites)), function(i) in_dc(sr$sites$lat[i], sr$sites$lon[i]), TRUE)
  lines <- c(lines, "", "### USGS precipitation sites (parameter 00045) in the DC box", "",
             sprintf("- %s: %s (%s, %s) inside DC outline: %s", sr$sites$site_no, sr$sites$name, sr$sites$lat, sr$sites$lon, ifelse(sr$sites$inside, "yes", "no")))
  ids <- sr$sites$site_no[sr$sites$inside]
} else lines <- c(lines, "", sprintf("### USGS precipitation sites (parameter 00045) in the DC box: none found (status: %s).", sr$status))
if (length(ids)) {
  acc <- list(); unit <- list(); bad_in_row <- 0
  for (k in seq_len(nrow(wins))) {
    if (bad_in_row >= 3) { cat("USGS is not answering; skipping the remaining USGS precipitation requests.\n"); break }
    if (k %% 10 == 1) cat(sprintf("  USGS precipitation window %d of %d\n", k, nrow(wins)))
    res <- fetch_usgs("iv", ids, "00045", wins$start[k], wins$end[k])
    bad_in_row <- if (res$status == "ok") 0 else bad_in_row + 1
    log_add(log, "usgs_dc_precip", sprintf("%s..%s", iso_z(wins$start[k]), iso_z(wins$end[k])), res$url, res$status, sum(vapply(res$series, function(s) nrow(s$records), 1L)), paste(res$attempts, collapse = " | "))
    for (s in res$series) { acc[[s$site]] <- c(acc[[s$site]], list(usgs_to_long(s, "usgs_dc_precip", "precip_usgs", "iv"))); unit[[s$site]] <- s$unit }
  }
  for (id in ids) {
    n <- if (!is.null(acc[[id]])) sum(vapply(acc[[id]], nrow, 1L)) else 0
    if (n > 0) parts <- c(parts, acc[[id]])
    r <- sr$sites[sr$sites$site_no == id, ]
    metas[[length(metas) + 1]] <- meta_row(source = "usgs_dc_precip", station_id = id, variable = "precip_usgs", unit = unit[[id]] %||% "in",
                                           station_name = r$name, latitude = r$lat, longitude = r$lon, in_dc = "yes", request_status = if (n > 0) "ok" else "no series returned",
                                           n_records = n, semantics = "reading/accumulation at time_utc; see unit", nominal_step_min = 15, note = "USGS parameter 00045")
  }
}
save_source("usgs_dc_precip", parts, metas)
lines <- c(lines, "", "## Limitations", "",
           "- A station is 'inside DC' only if its published coordinates fall inside the outline; coordinates can be rounded.",
           "- Volunteer (CoCoRaHS) gauges are not quality-assured to the same standard as airport instruments.",
           "- Many in-DC gauges report one daily total at a fixed observation hour, so they cannot resolve the timing of a short urban flood.",
           "- Sources such as DC Water, Weather Underground personal stations or MADIS/Synoptic were not accessed automatically (licence terms or API tokens); see the manual checklist in the README.", "")
write_md(lines, file.path(DIR$reports, "in_dc_search.md"))
invisible(log_save(log))
cat(sprintf("in-DC search written to reports/in_dc_search.md; %d GHCN-D station(s) and %d USGS precipitation site(s) inside DC\n", nrow(chosen) %||% 0, length(ids)))
