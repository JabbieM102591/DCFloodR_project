# Step 4 - Factor B: water-level gauges physically inside Washington, DC.
#   * USGS gauges (gage height and elevation-type water levels; 15-minute and daily values)
#   * NOAA CO-OPS tide / water-level stations (6-minute, or hourly where 6-minute data are not offered)
# Gauges are DISCOVERED (USGS site catalogue + NOAA station list + a short seed list), then tested against the DC
# outline; only gauges inside the District are downloaded. Everything searched is written to reports/gauge_search.md.
# Only the event windows are requested (overlapping windows are merged into one request).
# Writes data/interim/ts_<source>.csv + meta_<source>.csv and log_gauges.csv
source("R/setup.R")
ensure_dirs()
if (!USE_GAUGES) stop("USE_GAUGES is FALSE in config.R", call. = FALSE)
ev <- load_events_index()
log <- new_log("gauges")
PARAM_NAMES <- USGS_LEVEL_PARAMS
if (INCLUDE_DISCHARGE) PARAM_NAMES <- c(PARAM_NAMES, "00060" = "discharge")
params <- names(PARAM_NAMES)
wins <- merge_intervals(ev$window_start, ev$window_end)
cat(sprintf("%d merged request windows from %d events\n", nrow(wins), nrow(ev)))
rep_lines <- c("# Search for water-level gauges inside Washington, DC", "",
               "## Method", "",
               "1. USGS: site catalogue searched inside the DC bounding box (old waterservices site service and the new Water Data API monitoring-locations collection), plus a short list of known candidate ids.",
               "2. NOAA CO-OPS: list of all water-level stations, filtered to the DC box.",
               "3. Every candidate is tested against the DC outline (point-in-polygon). Only gauges **inside** the outline are used; others are listed as nearby.",
               sprintf("4. DC outline: %s", load_dc_boundary()$note), "")

# 1. USGS discovery
safe <- function(expr) tryCatch(expr, error = function(e) list(sites = NULL, url = "", status = paste("failed:", conditionMessage(e))))
cand <- list()
for (s in list(list(lab = "legacy site search", f = function() safe(usgs_sites_legacy(DC_BBOX, params))),
               list(lab = "Water Data API monitoring-locations search", f = function() safe(usgs_sites_ogc(DC_BBOX))))) {
  if (USGS_BACKEND == "legacy" && grepl("Water Data API", s$lab)) next
  if (USGS_BACKEND == "ogc" && grepl("legacy", s$lab)) next
  r <- s$f()
  log_add(log, "gauge_search", s$lab, r$url, r$status, nrow(r$sites) %||% 0)
  rep_lines <- c(rep_lines, sprintf("- %s: %s; %d site(s) returned", s$lab, r$status, nrow(r$sites) %||% 0))
  if (!is.null(r$sites)) cand[[length(cand) + 1]] <- r$sites[, c("site_no", "name", "lat", "lon", "found_by")]
}
have <- if (length(cand)) unique(unlist(lapply(cand, `[[`, "site_no"))) else character()
seeds <- setdiff(USGS_SEED_SITES, have)
if (length(seeds)) {
  for (f in list(function() safe(usgs_sites_by_id_legacy(seeds)), function() safe(usgs_sites_by_id_ogc(seeds)))) {
    r <- f(); log_add(log, "gauge_search", "seed ids", r$url, r$status, nrow(r$sites) %||% 0)
    if (!is.null(r$sites)) { cand[[length(cand) + 1]] <- r$sites[, c("site_no", "name", "lat", "lon", "found_by")]; seeds <- setdiff(seeds, r$sites$site_no) }
    if (!length(seeds)) break
  }
  if (length(seeds)) rep_lines <- c(rep_lines, sprintf("- seed ids with no coordinates found (not used): %s", paste(seeds, collapse = ", ")))
}
cand <- if (length(cand)) do.call(rbind, cand) else data.frame(site_no = character(), name = character(), lat = numeric(), lon = numeric(), found_by = character())
cand <- cand[!duplicated(cand$site_no), , drop = FALSE]
cand$inside_dc <- vapply(seq_len(nrow(cand)), function(i) in_dc(cand$lat[i], cand$lon[i]), TRUE)
usgs_in <- cand[cand$inside_dc, , drop = FALSE]
rep_lines <- c(rep_lines, "", "## USGS candidates", "", "| site | name | lat | lon | found by | inside DC outline |", "|---|---|---|---|---|---|",
               sprintf("| %s | %s | %s | %s | %s | %s |", cand$site_no, cand$name, cand$lat, cand$lon, cand$found_by, ifelse(cand$inside_dc, "**yes**", "no (nearby only)")))
cat(sprintf("USGS: %d candidate site(s), %d inside DC\n", nrow(cand), nrow(usgs_in)))

# 2. USGS data
state <- c(ogc = TRUE, legacy = TRUE); fails <- c(ogc = 0, legacy = 0)
if (USGS_BACKEND == "legacy") state["ogc"] <- FALSE
if (USGS_BACKEND == "ogc") state["legacy"] <- FALSE
for (service in c("iv", "dv")) {
  src <- paste0("usgs_", service); acc <- list(); tally <- list(); unit <- list()
  if (nrow(usgs_in)) for (k in seq_len(nrow(wins))) {
    be <- names(state)[state]
    if (!length(be)) { log_add(log, src, as.character(k), "", "skipped", 0, "no USGS backend answering"); next }
    res <- fetch_usgs(service, usgs_in$site_no, params, wins$start[k], wins$end[k], backends = be)
    item <- sprintf("%s %s..%s", src, iso_z(wins$start[k]), iso_z(wins$end[k]))
    log_add(log, src, item, res$url, res$status, sum(vapply(res$series, function(s) nrow(s$records), 1L)), paste(res$attempts, collapse = " | "))
    for (a in res$attempts) {
      b <- sub(":.*", "", a); okk <- grepl("^[a-z]+: ok \\(", a)
      if (okk) fails[b] <- 0 else if (grepl("HTTP (4|5)|failed", a) && !grepl("HTTP 404", a)) fails[b] <- fails[b] + 1
      if (fails[b] >= 3) state[b] <- FALSE
    }
    for (s in res$series) {
      v <- PARAM_NAMES[s$param_cd]; v <- if (is.na(v)) s$param_cd else unname(v)
      key <- paste(s$site, v, sep = "|")
      acc[[key]] <- c(acc[[key]], list(usgs_to_long(s, src, v, service)))
      tally[[key]] <- c(tally[[key]], res$backend); unit[[key]] <- s$unit
    }
  }
  parts <- list(); metas <- list()
  for (i in seq_len(nrow(usgs_in))) for (pc in params) {
    v <- unname(PARAM_NAMES[pc]); key <- paste(usgs_in$site_no[i], v, sep = "|")
    n <- if (!is.null(acc[[key]])) sum(vapply(acc[[key]], nrow, 1L)) else 0
    if (n > 0) parts <- c(parts, acc[[key]])
    metas[[length(metas) + 1]] <- meta_row(
      source = src, station_id = usgs_in$site_no[i], variable = v, unit = unit[[key]] %||% "",
      station_name = usgs_in$name[i], latitude = usgs_in$lat[i], longitude = usgs_in$lon[i], in_dc = "yes",
      request_status = if (n > 0) "ok" else "no series returned for any event window", n_records = n,
      semantics = if (service == "iv") "instantaneous reading at time_utc" else "daily mean for the local calendar day",
      nominal_step_min = if (service == "iv") 15 else 1440,
      note = sprintf("USGS parameter %s; retrieved via %s", pc, if (n > 0) paste(names(table(tally[[key]])), table(tally[[key]]), collapse = ", ") else "(nothing)"))
  }
  save_source(src, parts, metas)
}

# 3. NOAA CO-OPS
cs <- tryCatch(coops_stations(), error = function(e) list(stations = NULL, url = "", status = paste("failed:", conditionMessage(e))))
log_add(log, "gauge_search", "NOAA CO-OPS station list", cs$url, cs$status, nrow(cs$stations) %||% 0)
rep_lines <- c(rep_lines, "", "## NOAA CO-OPS water-level stations", "", sprintf("- station list: %s; %d station(s) returned", cs$status, nrow(cs$stations) %||% 0))
coops_all <- data.frame(id = character(), name = character(), lat = numeric(), lon = numeric(), found_by = character())
if (!is.null(cs$stations)) {
  s <- cs$stations
  b <- s[s$lat >= DC_BBOX[["south"]] & s$lat <= DC_BBOX[["north"]] & s$lon >= DC_BBOX[["west"]] & s$lon <= DC_BBOX[["east"]], , drop = FALSE]
  if (nrow(b)) coops_all <- data.frame(id = b$id, name = b$name, lat = b$lat, lon = b$lon, found_by = "CO-OPS station list (bbox)", stringsAsFactors = FALSE)
  for (id in setdiff(COOPS_SEED_STATIONS, coops_all$id)) {
    m <- s[s$id == id, , drop = FALSE]
    if (nrow(m)) coops_all <- rbind(coops_all, data.frame(id = id, name = m$name, lat = m$lat, lon = m$lon, found_by = "seed id", stringsAsFactors = FALSE))
  }
} else {
  for (id in COOPS_SEED_STATIONS) coops_all <- rbind(coops_all, data.frame(id = id, name = "(from seed list; station list unavailable)", lat = NA_real_, lon = NA_real_, found_by = "seed id", stringsAsFactors = FALSE))
}
coops_all$inside_dc <- vapply(seq_len(nrow(coops_all)), function(i) is.na(coops_all$lat[i]) || in_dc(coops_all$lat[i], coops_all$lon[i]), TRUE)
rep_lines <- c(rep_lines, "", "| station | name | lat | lon | found by | inside DC outline |", "|---|---|---|---|---|---|",
               sprintf("| %s | %s | %s | %s | %s | %s |", coops_all$id, coops_all$name, coops_all$lat, coops_all$lon, coops_all$found_by,
                       ifelse(is.na(coops_all$lat), "unknown (used, unverified)", ifelse(coops_all$inside_dc, "**yes**", "no (nearby only)"))))
coops_in <- coops_all[coops_all$inside_dc, , drop = FALSE]
cat(sprintf("CO-OPS: %d station(s) inside DC\n", nrow(coops_in)))

acc <- list(); meta_info <- list(); status_tx <- list(); datum_used <- list()
for (i in seq_len(nrow(coops_in))) {
  id <- coops_in$id[i]; datum <- COOPS_DATUM
  for (k in seq_len(nrow(wins))) {
    b <- wins$start[k]
    while (b < wins$end[k]) {
      e <- min(b + 30 * 86400, wins$end[k])
      for (prod in c("water_level", "hourly_height")) {
        res <- tryCatch(fetch_coops(id, b, e, prod, datum), error = function(x) list(ok = FALSE, message = paste("failed:", conditionMessage(x)), data = NULL, meta = NULL, url = ""))
        if (!res$ok && grepl("datum", res$message, ignore.case = TRUE) && datum != "STND") {
          datum <- "STND"; res <- tryCatch(fetch_coops(id, b, e, prod, datum), error = function(x) list(ok = FALSE, message = paste("failed:", conditionMessage(x)), data = NULL, meta = NULL, url = ""))
        }
        log_add(log, "noaa_coops", sprintf("%s %s %s..%s", id, prod, iso_z(b), iso_z(e)), res$url, if (res$ok) "ok" else "no data", nrow(res$data) %||% 0, substr(res$message, 1, 120))
        v <- if (prod == "water_level") "water_level_6min" else "water_level_hourly"
        key <- paste(id, v, sep = "|")
        status_tx[[key]] <- c(status_tx[[key]], if (res$ok) "ok" else substr(res$message, 1, 60))
        if (res$ok) {
          acc[[key]] <- c(acc[[key]], list(coops_to_long(res$data, id, v, if (prod == "water_level") 0.1 else 1)))
          datum_used[[key]] <- datum
          if (!is.null(res$meta) && is.null(meta_info[[id]])) meta_info[[id]] <- res$meta
          break      # 6-minute data found: do not also ask for hourly for this chunk
        }
      }
      b <- e
    }
  }
}
parts <- list(); metas <- list()
for (i in seq_len(nrow(coops_in))) for (v in c("water_level_6min", "water_level_hourly")) {
  id <- coops_in$id[i]; key <- paste(id, v, sep = "|")
  n <- if (!is.null(acc[[key]])) sum(vapply(acc[[key]], nrow, 1L)) else 0
  if (n > 0) parts <- c(parts, acc[[key]])
  mi <- meta_info[[id]]
  stt <- status_tx[[key]]
  metas[[length(metas) + 1]] <- meta_row(
    source = "noaa_coops", station_id = id, variable = v, unit = "m", station_name = if (!is.null(mi$name)) mi$name else coops_in$name[i],
    latitude = if (!is.na(coops_in$lat[i])) coops_in$lat[i] else as.numeric(mi$lat %||% NA), longitude = if (!is.na(coops_in$lon[i])) coops_in$lon[i] else as.numeric(mi$lon %||% NA),
    in_dc = if (is.na(coops_in$lat[i])) "unverified" else "yes",
    request_status = if (n > 0) "ok" else paste("no data:", paste(head(unique(stt), 2), collapse = " / ")), n_records = n,
    semantics = if (v == "water_level_6min") "6-minute water level at time_utc (metres above the named datum)" else "hourly water level height at time_utc (metres above the named datum)",
    nominal_step_min = if (v == "water_level_6min") 6 else 60,
    note = sprintf("NOAA CO-OPS product %s; datum %s; %d request(s) ok of %d", if (v == "water_level_6min") "water_level" else "hourly_height",
                   datum_used[[key]] %||% COOPS_DATUM, sum(stt == "ok"), length(stt)))
}
save_source("noaa_coops", parts, metas)
rep_lines <- c(rep_lines, "", "## Limits", "",
               "- USGS 15-minute data exist only from about October 2007 in the national archive; older events can only have daily values (if the gauge computes them).",
               "- Gauge height and water-surface elevation are not rainfall: a gauge can stay flat during a short urban flood or react hours later.",
               "- A missing record is not a water level of zero.")
write_md(rep_lines, file.path(DIR$reports, "gauge_search.md"))
invisible(log_save(log))
cat("gauge search written to reports/gauge_search.md\n")
