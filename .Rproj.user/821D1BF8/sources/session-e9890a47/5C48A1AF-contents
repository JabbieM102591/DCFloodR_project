# Step 3 - Factor A: Daymet V4 daily precipitation (1 km), cut to DC plus a small buffer.
# Only the days whose 24 h interval overlaps an event window are requested (one request per run of consecutive days).
# Cells stay on the native 1 km grid (rectangle crop only: no resampling, no reprojection).
# A day that cannot be obtained stays in the array as all-NaN with a status text, so "no data" is never read as 0 mm.
# Writes data/interim/raster_daymet_prcp_1km.rds and data/interim/log_daymet.csv. Raw NetCDF files are cached in
# data/interim/raw/daymet/ (not committed) so a re-run does not download them again.
source("R/setup.R")
ensure_dirs()
if (!USE_DAYMET) stop("USE_DAYMET is FALSE in config.R", call. = FALSE)
ev <- load_events_index()
log <- new_log("daymet")

# which Daymet days are needed
utc_date <- function(t) as.Date(format(t, "%Y-%m-%d", tz = "UTC"))
days <- as.Date(sort(unique(unlist(lapply(seq_len(nrow(ev)), function(i)
  as.character(seq(utc_date(ev$window_start[i]), utc_date(ev$window_end[i] - 1), by = "day")))))))
cat(sprintf("%d distinct Daymet days needed for %d events (%s .. %s)\n", length(days), nrow(ev), min(days), max(days)))

# group into runs of consecutive days within one calendar year
yr <- as.integer(format(days, "%Y"))
brk <- c(TRUE, diff(as.numeric(days)) != 1 | diff(yr) != 0)
run_id <- cumsum(brk)
runs <- lapply(split(seq_along(days), run_id), function(ix) list(year = yr[ix[1]], d0 = days[ix[1]], d1 = days[ix[length(ix)]]))
cat(length(runs), "requests will be made (cached files are reused)\n")
if (!nzchar(Sys.getenv("EARTHDATA_USER")) || !nzchar(Sys.getenv("EARTHDATA_PASS")))
  stop("Daymet needs a free NASA Earthdata login. In the Console run: Sys.setenv(EARTHDATA_USER = \"your_username\", EARTHDATA_PASS = \"your_password\") and then source(\"step3_daymet.R\") again.", call. = FALSE)

bbox <- c(west = DC_BBOX[["west"]] - RASTER_BUFFER_DEG, south = DC_BBOX[["south"]] - RASTER_BUFFER_DEG,
          east = DC_BBOX[["east"]] + RASTER_BUFFER_DEG, north = DC_BBOX[["north"]] + RASTER_BUFFER_DEG)
cache_dir <- file.path(DIR$interim, "raw", "daymet"); dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

slices <- list(); grid <- NULL; status <- setNames(rep("not requested", length(days)), as.character(days))
src_file <- setNames(rep("", length(days)), as.character(days)); vs <- list(); ve <- list(); meta_nc <- NULL

for (k in seq_along(runs)) {
  r <- runs[[k]]
  item <- sprintf("%s..%s", r$d0, r$d1)
  url <- daymet_url(r$year)
  fn <- file.path(cache_dir, sprintf("daymet_prcp_%s_%s.nc", r$d0, r$d1))
  keys <- as.character(seq(r$d0, r$d1, by = "day"))
  if (!file.exists(fn)) {
    resp <- tryCatch(fetch_daymet_run(r$year, as.character(r$d0), as.character(r$d1), bbox), error = function(e) e)
    if (inherits(resp, "error")) {
      status[keys] <- paste("download failed:", substr(conditionMessage(resp), 1, 100))
      log_add(log, "daymet", item, url, "failed", 0, conditionMessage(resp)); next
    }
    magic <- if (length(resp$content) >= 3) rawToChar(resp$content[1:3]) else ""
    if (resp$status != 200 || !(startsWith(magic, "CDF") || resp$content[1] == as.raw(0x89))) {
      msg <- substr(gsub("\\s+", " ", tryCatch(resp_text(resp), error = function(e) "")), 1, 120)
      status[keys] <- sprintf("not available from the service (HTTP %d)", resp$status)
      log_add(log, "daymet", item, resp$url, paste("HTTP", resp$status), 0, msg); next
    }
    writeBin(resp$content, fn); Sys.sleep(0.3)
  }
  pr <- tryCatch(parse_daymet_nc(fn), error = function(e) e)
  if (inherits(pr, "error")) {
    status[keys] <- paste("could not read file:", substr(conditionMessage(pr), 1, 100))
    log_add(log, "daymet", item, url, "parse error", 0, conditionMessage(pr)); next
  }
  if (is.null(grid)) { grid <- list(lon = pr$lon, lat = pr$lat, x = pr$x, y = pr$y); meta_nc <- pr }
  if (!any(abs(pr$lon - mean(DC_BBOX[c("west", "east")])) < 0.02 & abs(pr$lat - mean(DC_BBOX[c("south", "north")])) < 0.02, na.rm = TRUE))
    stop("the downloaded Daymet window does not contain the centre of DC - the cell selection is wrong (see data/interim/log_daymet.csv)", call. = FALSE)
  same <- identical(dim(pr$lon), dim(grid$lon)) && isTRUE(all.equal(pr$lon, grid$lon, tolerance = 1e-6))
  for (j in seq_along(pr$dates)) {
    key <- as.character(pr$dates[j])
    if (!key %in% names(status)) next
    if (!same) { status[key] <- "grid differs from the first request (skipped)"; next }
    slices[[key]] <- pr$prcp[j, , ]; status[key] <- "ok"; src_file[key] <- basename(fn)
    vs[[key]] <- pr$start_utc[j]; ve[[key]] <- pr$end_utc[j]
  }
  log_add(log, "daymet", item, url, "ok", length(pr$prcp), sprintf("%d day(s) returned; time bounds %s", length(pr$dates),
                                                                   if (pr$bounds_from_file) "read from the file" else "not in the file (assumed 00:00-24:00 UTC)"))
  if (k %% 10 == 0) cat(sprintf("  %d / %d requests done\n", k, length(runs)))
}
if (is.null(grid)) { log_save(log); stop("Daymet: no day could be retrieved - nothing saved (see data/interim/log_daymet.csv).", call. = FALSE) }

# assemble [time, y, x] with NaN for missing days
ny <- nrow(grid$lon); nx <- ncol(grid$lon); n <- length(days)
data <- array(NA_real_, dim = c(n, ny, nx))
leap <- function(y) (y %% 4 == 0 & y %% 100 != 0) | y %% 400 == 0
for (i in seq_len(n)) {
  key <- as.character(days[i])
  if (!is.null(slices[[key]])) data[i, , ] <- slices[[key]]
  else if (status[key] %in% c("not requested", "not returned") || startsWith(status[key], "not available") ) {
    d <- days[i]
    if (format(d, "%m-%d") == "12-31" && leap(as.integer(format(d, "%Y"))))
      status[key] <- "not in Daymet: 31 December of a leap year is dropped (365-day calendar)"
  }
  if (status[key] == "not requested") status[key] <- "not returned by the service"
}
start_utc <- vapply(seq_len(n), function(i) { v <- vs[[as.character(days[i])]]; if (is.null(v)) as.numeric(as.POSIXct(as.character(days[i]), tz = "UTC")) else as.numeric(v) }, 0)
end_utc   <- vapply(seq_len(n), function(i) { v <- ve[[as.character(days[i])]]; if (is.null(v)) as.numeric(as.POSIXct(as.character(days[i] + 1), tz = "UTC")) else as.numeric(v) }, 0)
meta <- list(key = "daymet_prcp_1km", units = if (!is.null(meta_nc$attrs$units)) as.character(meta_nc$attrs$units) else "mm/day",
             crs = meta_nc$crs, prcp_attributes = meta_nc$attrs, time_units = meta_nc$time_units,
             time_bounds_from_file = meta_nc$bounds_from_file, bbox_requested = as.list(bbox),
             nodata_stored = "NaN (service fill value converted)")
saveRDS(list(data = data, lon = grid$lon, lat = grid$lat, x = grid$x, y = grid$y, dates = as.character(days),
             status = unname(status[as.character(days)]), source_file = unname(src_file[as.character(days)]),
             valid_start_utc = iso_z(from_epoch(start_utc)), valid_end_utc = iso_z(from_epoch(end_utc)), meta = meta),
        file.path(DIR$interim, "raster_daymet_prcp_1km.rds"))
log_save(log)
ok <- sum(status == "ok")
cat(sprintf("Daymet: %d / %d days retrieved, grid %d x %d cells (rows x columns)\n", ok, n, ny, nx))
bad <- table(status[status != "ok"]); if (length(bad)) { cat("Not retrieved:\n"); print(bad) }