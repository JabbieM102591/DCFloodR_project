# Step 7 - build ONE HDF5 database from everything in data/interim/ and compute the availability tables.
#
# Layout of data/output/dc_flood_database.h5
#   /events                         event index (one dataset per column): begin/end local + UTC, analysis windows, status
#   /rasters/<source>/              precip[time,y,x] (float32, NaN = no data), lon[y,x], lat[y,x], x_proj_m, y_proj_m,
#                                   date_utc, valid_start_utc, valid_end_utc, slice_status, slice_has_data, source_file
#   /timeseries/<source>/<station>__<variable>/   time_utc (epoch s, UTC), value, period_hours, quality, original_timestamp
#   /context/dc_boundary            outline of DC for maps
#   /nasa/granules                  NASA scenes found by the search (metadata only)
#   /metadata/{sources, series, availability, retrieval_log, processing_notes}
# Note on array order: R writes an array with dim c(x, y, time) as an HDF5 dataset of shape (time, y, x), so the
# file reads as precip[time, y, x] in Python, R (through dcflood_h5.R) and other tools.
source("R/setup.R")
suppressPackageStartupMessages(library(hdf5r))
ensure_dirs()

F32 <- h5types$H5T_IEEE_F32LE; I64 <- h5types$H5T_STD_I64LE; U8 <- h5types$H5T_STD_U8LE
STR <- H5T_STRING$new(size = Inf)

set_attrs <- function(obj, lst) {
  for (nm in names(lst)) {
    v <- lst[[nm]]
    if (is.null(v) || (length(v) == 1 && is.na(v))) next
    if (is.list(v)) v <- as.character(jsonlite::toJSON(v, auto_unbox = TRUE, null = "null", na = "null"))
    if (is.logical(v)) v <- as.integer(v)
    h5attr(obj, nm) <- v
  }
}
write_table <- function(parent, name, df, note = NULL) {
  g <- parent$create_group(name)
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  if (nrow(df) > 0) for (cn in names(df)) {
    col <- df[[cn]]
    if (is.numeric(col) && !is.integer(col)) g$create_dataset(cn, robj = as.numeric(col))
    else if (is.integer(col) || is.logical(col)) g$create_dataset(cn, robj = as.integer(col))
    else g$create_dataset(cn, robj = ifelse(is.na(col), "", as.character(col)), dtype = STR)
  }
  set_attrs(g, list(columns = names(df), n_rows = nrow(df), description = note,
                    column_types = vapply(df, function(c) if (is.numeric(c)) "number" else "string", "")))
  g
}
longest_gap <- function(present) { r <- rle(!present); if (!any(r$values)) 0L else max(r$lengths[r$values]) }
leaf <- function(src) { i <- SOURCE_INFO[[src]]; i }

h5 <- H5File$new(H5_PATH, mode = "w")
avail <- list(); sources <- list(); series_rows <- list()
ev_all <- load_events_index(valid_only = FALSE)
events <- ev_all[ev_all$status == "ok", , drop = FALSE]

set_attrs(h5, list(title = "DC flood-event environmental database (STAT 6289), assignment version 4",
  created_utc = utc_now_iso(), local_time_zone = EVENT_TZ,
  event_window = sprintf("event begin - %g h to event end + %g h", PAD_BEFORE_H, PAD_AFTER_H),
  time_convention = "all stored time stamps are UTC unless a dataset says otherwise; local times are America/New_York (EST/EDT)",
  input_events_md5 = readLines(file.path(DIR$interim, "events_input_md5.txt"), warn = FALSE)[1],
  r_version = R.version.string, hdf5r = as.character(packageVersion("hdf5r")), platform = R.version$platform,
  array_order = "precip[time, y, x]", readme = "see README.md for the layout of this file"))

evw <- ev_all[, !(names(ev_all) %in% c("window_start", "window_end", "begin_t", "end_t")), drop = FALSE]
for (cn in c("duration_h", "original_row")) evw[[cn]] <- suppressWarnings(as.numeric(evw[[cn]]))
write_table(h5, "events", evw, "event index from the instructor CSV with validation status and analysis windows (times in UTC and local)")

# rasters
rds <- list.files(DIR$interim, pattern = "^raster_.*\\.rds$", full.names = TRUE)
if (length(rds)) rg <- h5$create_group("rasters")
for (p in rds) {
  z <- readRDS(p); key <- z$meta$key; info <- SOURCE_INFO[[key]]
  n <- dim(z$data)[1]; ny <- dim(z$data)[2]; nx <- dim(z$data)[3]
  g <- rg$create_group(key)
  g$create_dataset("precip", robj = aperm(z$data, c(3, 2, 1)), dtype = F32, chunk_dims = c(nx, ny, 1), gzip_level = 4)
  g$create_dataset("lon", robj = t(z$lon)); g$create_dataset("lat", robj = t(z$lat))
  g$create_dataset("x_proj_m", robj = as.numeric(z$x)); g$create_dataset("y_proj_m", robj = as.numeric(z$y))
  for (nm in c("date_utc", "valid_start_utc", "valid_end_utc", "slice_status", "source_file"))
    g$create_dataset(nm, robj = as.character(z[[switch(nm, date_utc = "dates", slice_status = "status", nm)]]), dtype = STR)
  has <- vapply(seq_len(n), function(i) any(is.finite(z$data[i, , ])), TRUE)
  g$create_dataset("slice_has_data", robj = as.integer(has), dtype = U8)
  set_attrs(g, list(title = info$title, units = z$meta$units, source_url = info$url, reference = info$reference,
    spatial_support = info$support, spatial_resolution = info$spatial_resolution, crs = info$crs, crs_variable = z$meta$crs,
    temporal_meaning = info$temporal, time_bounds_from_file = z$meta$time_bounds_from_file,
    missing_value_encoding = info$missing, processing = info$processing,
    dimension_order = "precip[time, y, x]; y runs north to south (as stored by the source); lon/lat are the cell centres",
    array_shape = c(n, ny, nx), extent_lon_lat = c(min(z$lon), min(z$lat), max(z$lon), max(z$lat)),
    request_bbox = z$meta$bbox_requested, source_variable_attributes = z$meta$prcp_attributes,
    retrieved_utc = utc_now_iso(), compression = "gzip level 4; one chunk per daily slice"))
  sources[[length(sources) + 1]] <- data.frame(source = key, kind = "raster", title = info$title, units = z$meta$units, support = info$support,
    temporal = info$temporal, spatial_resolution = info$spatial_resolution, crs = info$crs, missing_value_encoding = info$missing,
    processing = info$processing, url = info$url, reference = info$reference, stringsAsFactors = FALSE)
  vs <- parse_iso_z(z$valid_start_utc); ve <- parse_iso_z(z$valid_end_utc)
  for (e in seq_len(nrow(events))) {
    idx <- which(vs < events$window_end[e] & ve > events$window_start[e])
    present <- has[idx]
    part <- sum(vapply(idx[has[idx]], function(i) anyNA(z$data[i, , ]), TRUE))
    zero <- sum(vapply(idx[has[idx]], function(i) max(z$data[i, , ], na.rm = TRUE) == 0, TRUE))
    why <- sort(unique(z$status[idx][!has[idx]]))
    got <- z$dates[idx][has[idx]]
    avail[[length(avail) + 1]] <- data.frame(event_id = events$event_id[e], source = key, station_id = "(grid)", variable = "precipitation",
      kind = "raster", expected = length(idx), n_valid = sum(present), n_zero = zero, n_present_not_valid = part,
      n_missing = length(idx) - sum(present), max_gap_steps = if (length(idx)) longest_gap(present) else 0L,
      first_valid = if (length(got)) min(got) else "", last_valid = if (length(got)) max(got) else "",
      status = if (!length(idx)) "no Daymet day overlaps the window" else if (all(present)) "complete" else if (any(present)) "partial" else "no data",
      note = paste(why, collapse = "; "), stringsAsFactors = FALSE)
  }
}

# station / gauge time series
metaf <- list.files(DIR$interim, pattern = "^meta_.*\\.csv$", full.names = TRUE)
if (length(metaf)) tg <- h5$create_group("timeseries")
for (mf in metaf) {
  m <- utils::read.csv(mf, colClasses = "character", na.strings = character(0))
  if (!nrow(m)) next
  src <- m$source[1]; info <- SOURCE_INFO[[src]]
  tsf <- file.path(DIR$interim, paste0("ts_", src, ".csv"))
  ts <- if (file.exists(tsf)) utils::read.csv(tsf, colClasses = "character", na.strings = character(0)) else empty_long()
  ts$value <- suppressWarnings(as.numeric(ts$value)); ts$period_hours <- suppressWarnings(as.numeric(ts$period_hours))
  ts$epoch <- epoch_s(parse_iso_z(ts$time_utc))
  sg <- tg$create_group(src)
  sources[[length(sources) + 1]] <- data.frame(source = src, kind = "timeseries", title = info$title, units = info$units, support = info$support,
    temporal = info$temporal, spatial_resolution = info$spatial_resolution, crs = info$crs, missing_value_encoding = info$missing,
    processing = info$processing, url = info$url, reference = info$reference, stringsAsFactors = FALSE)
  for (i in seq_len(nrow(m))) {
    r <- m[i, ]; gname <- paste0(r$station_id, "__", r$variable)
    sub <- ts[ts$station_id == r$station_id & ts$variable == r$variable, , drop = FALSE]
    sub <- sub[order(sub$epoch), , drop = FALSE]
    stored <- nrow(sub) > 0
    lat <- suppressWarnings(as.numeric(r$latitude)); lon <- suppressWarnings(as.numeric(r$longitude))
    step <- suppressWarnings(as.integer(as.numeric(r$nominal_step_min))); if (is.na(step) || step == 0) step <- 60L
    series_rows[[length(series_rows) + 1]] <- data.frame(source = src, station_id = r$station_id, variable = r$variable, unit = r$unit,
      station_name = r$station_name, latitude = lat, longitude = lon, in_dc = r$in_dc, n_records = nrow(sub),
      request_status = r$request_status, semantics = r$semantics, nominal_step_min = step, stored = if (stored) "yes" else "no",
      hdf5_path = if (stored) sprintf("/timeseries/%s/%s", src, gname) else "", note = r$note, stringsAsFactors = FALSE)
    if (stored) {
      g <- sg$create_group(gname); ck <- min(nrow(sub), 4096L)
      g$create_dataset("time_utc", robj = sub$epoch, dtype = I64, chunk_dims = ck, gzip_level = 4)
      g$create_dataset("value", robj = sub$value, dtype = F32, chunk_dims = ck, gzip_level = 4)
      g$create_dataset("period_hours", robj = sub$period_hours, dtype = F32, chunk_dims = ck, gzip_level = 4)
      g$create_dataset("quality", robj = sub$quality, dtype = STR)
      g$create_dataset("original_timestamp", robj = sub$original_timestamp, dtype = STR)
      set_attrs(g, list(source = src, station_id = r$station_id, variable = r$variable, unit = r$unit, station_name = r$station_name,
        latitude = lat, longitude = lon, in_dc = r$in_dc, crs = "EPSG:4326", semantics = r$semantics, nominal_step_min = step,
        original_timezone = sub$original_tz[1], time_utc = "seconds since 1970-01-01T00:00:00Z",
        missing_value_encoding = info$missing, processing = info$processing, source_url = info$url,
        retrieval_status = r$request_status, note = r$note, retrieved_utc = utc_now_iso()))
    }
    # availability per event window
    for (e in seq_len(nrow(events))) {
      ev <- events[e, ]
      if (step == 1440) {
        d0 <- as.Date(substr(ev$window_start_local, 1, 10)); d1 <- as.Date(substr(ev$window_end_local, 1, 10))
        n_exp <- as.integer(d1 - d0) + 1L
        k <- if (stored) as.integer(as.Date(substr(sub$original_timestamp, 1, 10)) - d0) else integer()
      } else {
        n_exp <- as.integer(floor(as.numeric(difftime(ev$window_end, ev$window_start, units = "mins")) / step))
        k <- if (stored) as.integer(floor((sub$epoch - as.numeric(ev$window_start)) / (step * 60))) else integer()
      }
      inw <- if (stored) !is.na(k) & k >= 0 & k < n_exp else logical()
      kk <- k[inw]; vals <- sub$value[inw]
      present <- rep(FALSE, n_exp); present[unique(kk[!is.na(vals)]) + 1L] <- TRUE
      zero <- length(unique(kk[!is.na(vals) & vals == 0 & present[kk + 1L]]))
      notvalid <- length(setdiff(unique(kk), which(present) - 1L))
      vt <- sub$time_utc[inw][!is.na(vals)]
      avail[[length(avail) + 1]] <- data.frame(event_id = ev$event_id, source = src, station_id = r$station_id, variable = r$variable,
        kind = "timeseries", expected = n_exp, n_valid = sum(present), n_zero = zero, n_present_not_valid = notvalid,
        n_missing = n_exp - sum(present), max_gap_steps = longest_gap(present),
        first_valid = if (length(vt)) min(vt) else "", last_valid = if (length(vt)) max(vt) else "",
        status = if (n_exp > 0 && all(present)) "complete" else if (any(present)) "partial" else if (stored) "no data in window" else "no data returned",
        note = if (stored) "" else r$request_status, stringsAsFactors = FALSE)
    }
  }
}

# context, NASA, metadata
b <- load_dc_boundary(); cg <- h5$create_group("context")$create_group("dc_boundary")
cg$create_dataset("lon", robj = as.numeric(b$lon)); cg$create_dataset("lat", robj = as.numeric(b$lat))
set_attrs(cg, list(source_note = b$note, crs = "EPSG:4326", ring_separator = "NaN"))
ng <- file.path(DIR$interim, "nasa_granules.csv")
if (file.exists(ng)) {
  d <- utils::read.csv(ng, colClasses = "character", na.strings = character(0))
  write_table(h5$create_group("nasa"), "granules", d, "NASA OPERA DSWx scenes found near the events (metadata only; imagery not downloaded)")
}
mg <- h5$create_group("metadata")
src_df <- do.call(rbind, sources); src_df <- src_df[!duplicated(src_df$source), ]
write_table(mg, "sources", src_df, "one row per data source")
ser_df <- if (length(series_rows)) do.call(rbind, series_rows) else data.frame(source = character(), station_id = character(), variable = character(),
  unit = character(), station_name = character(), latitude = numeric(), longitude = numeric(), in_dc = character(), n_records = integer(),
  request_status = character(), semantics = character(), nominal_step_min = integer(), stored = character(), hdf5_path = character(), note = character())
write_table(mg, "series", ser_df, "every requested station/variable, including those that returned nothing")
av <- do.call(rbind, avail)
write_table(mg, "availability", av, "expected vs available values per event window")
logs <- lapply(list.files(DIR$interim, pattern = "^log_.*\\.csv$", full.names = TRUE), utils::read.csv, colClasses = "character", na.strings = character(0))
logs <- Filter(function(x) nrow(x) > 0, logs)
write_table(mg, "retrieval_log", if (length(logs)) do.call(rbind, logs) else data.frame(note = character()), "every request made, with its status (successes and failures)")
mg$create_dataset("processing_notes", dtype = STR, robj = c(
  sprintf("Event windows: begin - %g h to end + %g h (local event times from the CSV, read as %s).", PAD_BEFORE_H, PAD_AFTER_H, EVENT_TZ),
  "Rasters: native Daymet 1 km grid, rectangular crop around DC plus buffer, no resampling and no reprojection.",
  "Daily products are never joined to sub-daily gauge series by printed date; each series keeps its own time stamps and period.",
  "See README.md for the full description."))
h5$close_all()
utils::write.csv(av, file.path(DIR$reports, "availability_by_event_and_series.csv"), row.names = FALSE)
utils::write.csv(ser_df, file.path(DIR$reports, "series_inventory.csv"), row.names = FALSE)
cat(sprintf("wrote %s (%.2f MB); %d availability rows\n", H5_PATH, file.size(H5_PATH) / 1e6, nrow(av)))
