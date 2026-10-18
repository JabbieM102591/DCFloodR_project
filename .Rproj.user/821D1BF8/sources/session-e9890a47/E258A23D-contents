# Reusable functions that READ the finished HDF5 database (no downloads, no other files needed).
#
#   source("dcflood_h5.R")
#   h5 <- "data/output/dc_flood_database.h5"
#   list_events(h5); list_sources(h5); list_stations(h5); list_variables(h5); date_ranges(h5); describe(h5)
#   r <- get_raster(h5, "EV001", "daymet_prcp_1km", "1996-01-19")         # matrix + coordinates + units
#   plot_raster(h5, "EV001", "daymet_prcp_1km", "1996-01-19")             # map with DC outline, gauges, legend
#   ts <- get_timeseries(h5, "noaa_coops", "8594900", "water_level_6min", event_id = "EV050")
#   plot_timeseries(h5, "noaa_coops", "8594900", "water_level_6min", event_id = "EV050")
#   coverage_summary(h5); plot_coverage_heatmap(h5)
#
# `h5` is a file path or an open hdf5r H5File. Times are stored in UTC; plots label America/New_York local time.
# Layout (see README): /events /rasters/<source> /timeseries/<source>/<station>__<variable> /context /nasa /metadata
suppressPackageStartupMessages({ library(hdf5r); library(ggplot2) })
if (!exists("EVENT_TZ")) EVENT_TZ <- "America/New_York"
.null_or <- function(a, b) if (is.null(a) || length(a) == 0) b else a

.with_h5 <- function(h5, fn) {
  if (inherits(h5, "H5File")) return(fn(h5))
  f <- H5File$new(as.character(h5), mode = "r"); on.exit(f$close_all()); fn(f)
}
.iso_z <- function(t) format(as.POSIXct(t, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
.parse_z <- function(x) as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
.as_utc <- function(x) {                     # string/Date/POSIXct -> POSIXct UTC; strings without a zone are EVENT_TZ local
  if (inherits(x, "POSIXct")) return(as.POSIXct(as.numeric(x), origin = "1970-01-01", tz = "UTC"))
  x <- as.character(x)
  if (grepl("Z$|[+-][0-9]{2}:?[0-9]{2}$", x)) return(as.POSIXct(sub("Z$", "", gsub("T", " ", x)), format = "%Y-%m-%d %H:%M:%S", tz = "UTC"))
  fmt <- if (nchar(x) > 16) "%Y-%m-%d %H:%M:%S" else "%Y-%m-%d %H:%M"
  t <- as.POSIXct(x, format = fmt, tz = EVENT_TZ)
  as.POSIXct(as.numeric(t), origin = "1970-01-01", tz = "UTC")
}
.attrs <- function(obj) {
  nm <- h5attr_names(obj); out <- list()
  for (n in nm) out[[n]] <- tryCatch(h5attr(obj, n), error = function(e) NA)
  out
}

read_table <- function(g) {
  cols <- h5attr(g, "columns"); n <- as.integer(h5attr(g, "n_rows"))
  d <- lapply(cols, function(cn) if (n == 0) character(0) else as.vector(g[[cn]]$read()))
  names(d) <- cols
  as.data.frame(d, stringsAsFactors = FALSE, check.names = FALSE)
}

# listing
list_events <- function(h5) .with_h5(h5, function(f) read_table(f[["events"]]))
list_sources <- function(h5) .with_h5(h5, function(f) read_table(f[["metadata/sources"]]))
list_stations <- function(h5, source = NULL) {
  t <- .with_h5(h5, function(f) read_table(f[["metadata/series"]]))
  if (is.null(source)) t else t[t$source == source, , drop = FALSE]
}
list_variables <- function(h5) {
  t <- list_stations(h5)
  out <- if (nrow(t)) aggregate(station_id ~ source + variable + unit, data = t, FUN = function(x) length(unique(x))) else
    data.frame(source = character(), variable = character(), unit = character(), station_id = integer())
  names(out)[names(out) == "station_id"] <- "n_stations"
  rs <- .with_h5(h5, function(f) if (f$exists("rasters")) f[["rasters"]]$ls()$name else character())
  for (s in rs) out <- rbind(out, data.frame(source = s, variable = "precipitation (raster)", unit = .with_h5(h5, function(f) h5attr(f[["rasters"]][[s]], "units")), n_stations = 1L))
  out
}
date_ranges <- function(h5) {
  rows <- list()
  .with_h5(h5, function(f) {
    if (f$exists("rasters")) for (s in f[["rasters"]]$ls()$name) {
      g <- f[["rasters"]][[s]]; ok <- as.logical(g[["slice_has_data"]]$read()); d <- g[["date_utc"]]$read()
      rows[[length(rows) + 1]] <<- data.frame(source = s, station_id = "(grid)", variable = "precipitation", n = sum(ok),
                                              first = if (any(ok)) min(d[ok]) else "", last = if (any(ok)) max(d[ok]) else "", stringsAsFactors = FALSE)
    }
    if (f$exists("timeseries")) for (s in f[["timeseries"]]$ls()$name) for (nm in f[["timeseries"]][[s]]$ls()$name) {
      g <- f[["timeseries"]][[s]][[nm]]; t <- as.numeric(g[["time_utc"]]$read())
      rows[[length(rows) + 1]] <<- data.frame(source = s, station_id = h5attr(g, "station_id"), variable = h5attr(g, "variable"), n = length(t),
                                              first = if (length(t)) .iso_z(as.POSIXct(min(t), origin = "1970-01-01", tz = "UTC")) else "",
                                              last = if (length(t)) .iso_z(as.POSIXct(max(t), origin = "1970-01-01", tz = "UTC")) else "", stringsAsFactors = FALSE)
    }
  })
  if (length(rows)) do.call(rbind, rows) else data.frame()
}
describe <- function(h5) {
  .with_h5(h5, function(f) {
    cat("File:", f$filename, "-", round(file.size(f$filename) / 1e6, 2), "MB\n")
    for (n in c("title", "created_utc", "local_time_zone", "event_window", "time_convention", "r_version")) cat(" ", n, ":", h5attr(f, n), "\n")
  })
  ev <- list_events(h5)
  cat("\nEvents:", nrow(ev), "(valid:", sum(ev$status == "ok"), ")\n")
  print(utils::head(ev[, c("event_id", "begin_local", "end_local", "status")], 6), row.names = FALSE)
  cat("\nSources:\n"); print(list_sources(h5)[, c("source", "kind", "units", "support")], row.names = FALSE)
  cat("\nStored ranges:\n"); print(utils::head(date_ranges(h5), 15), row.names = FALSE)
  invisible(NULL)
}

# rasters
.event_row <- function(f, event_id) {
  ev <- read_table(f[["events"]]); r <- ev[ev$event_id == event_id, , drop = FALSE]
  if (!nrow(r)) stop("event '", event_id, "' not found; first ids: ", paste(utils::head(ev$event_id, 6), collapse = ", "))
  r
}

#' One stored raster slice.
#' when: "YYYY-MM-DD" = the Daymet day with that UTC date label, or a date-time (POSIXct, or a string such as
#'       "2016-07-19 22:30"; a string without a zone is read as America/New_York) = the day whose 24 h interval contains it.
#' Returns a list: data (matrix [y, x]; NaN = no data), lon, lat (matrices [y, x] of cell centres), units, date_utc,
#' valid_start_utc, valid_end_utc, status, source, event_id, attrs.
get_raster <- function(h5, event_id, source, when) {
  .with_h5(h5, function(f) {
    if (!f$exists("rasters") || !source %in% f[["rasters"]]$ls()$name)
      stop("raster source '", source, "' not in the file")
    ev <- .event_row(f, event_id); g <- f[["rasters"]][[source]]
    dates <- g[["date_utc"]]$read(); vs <- .parse_z(g[["valid_start_utc"]]$read()); ve <- .parse_z(g[["valid_end_utc"]]$read())
    w <- if (inherits(when, "Date")) as.character(when) else if (is.character(when) && nchar(trimws(when)) == 10) trimws(when) else NULL
    idx <- if (!is.null(w)) which(dates == w) else { t <- .as_utc(when); which(vs <= t & t < ve) }
    if (!length(idx)) stop("no slice for '", format(when), "' in ", source, "; stored days: ", min(dates), " .. ", max(dates))
    i <- idx[1]
    ws <- .parse_z(ev$window_start_utc); we <- .parse_z(ev$window_end_utc)
    if (!(vs[i] < we && ve[i] > ws)) stop("Daymet day ", dates[i], " does not overlap the window of ", event_id, " (", ev$window_start_utc, " .. ", ev$window_end_utc, ")")
    list(data = t(g[["precip"]][, , i]), lon = t(g[["lon"]]$read()), lat = t(g[["lat"]]$read()), units = h5attr(g, "units"),
         date_utc = dates[i], valid_start_utc = .iso_z(vs[i]), valid_end_utc = .iso_z(ve[i]), status = g[["slice_status"]]$read()[i],
         source = source, event_id = event_id, attrs = .attrs(g))
  })
}

.grid_corners <- function(M) {
  ny <- nrow(M); nx <- ncol(M)
  P <- matrix(NA_real_, ny + 2, nx + 2); P[2:(ny + 1), 2:(nx + 1)] <- M
  P[2:(ny + 1), 1] <- 2 * M[, 1] - M[, 2]; P[2:(ny + 1), nx + 2] <- 2 * M[, nx] - M[, nx - 1]
  P[1, ] <- 2 * P[2, ] - P[3, ]; P[ny + 2, ] <- 2 * P[ny + 1, ] - P[ny, ]
  C <- matrix(NA_real_, ny + 1, nx + 1)
  for (i in seq_len(ny + 1)) for (j in seq_len(nx + 1)) C[i, j] <- mean(P[i:(i + 1), j:(j + 1)])
  C
}
.cell_polygons <- function(lon, lat, value) {
  Cx <- .grid_corners(lon); Cy <- .grid_corners(lat); ny <- nrow(lon); nx <- ncol(lon)
  ii <- rep(seq_len(ny), nx); jj <- rep(seq_len(nx), each = ny); n <- length(ii)
  at <- function(C, di, dj) C[cbind(ii + di, jj + dj)]
  d <- data.frame(id = rep(seq_len(n), 4), ord = rep(1:4, each = n),
                  lon = c(at(Cx, 0, 0), at(Cx, 0, 1), at(Cx, 1, 1), at(Cx, 1, 0)),
                  lat = c(at(Cy, 0, 0), at(Cy, 0, 1), at(Cy, 1, 1), at(Cy, 1, 0)),
                  value = rep(value[cbind(ii, jj)], 4))
  d[order(d$id, d$ord), ]
}
.boundary_df <- function(f) {
  x <- f[["context/dc_boundary/lon"]]$read(); y <- f[["context/dc_boundary/lat"]]$read()
  data.frame(lon = x, lat = y, ring = cumsum(is.na(x) | is.na(y)))[!(is.na(x) | is.na(y)), ]
}

#' Map of one stored precipitation raster with the DC outline, gauge markers, colour bar and an informative title.
plot_raster <- function(h5, event_id, source, when, vmax = NULL, show_stations = TRUE, save = NULL, title_extra = NULL) {
  r <- get_raster(h5, event_id, source, when)
  bd <- .with_h5(h5, .boundary_df)
  st <- if (show_stations) list_stations(h5) else NULL
  title_src <- .with_h5(h5, function(f) h5attr(f[["rasters"]][[source]], "title"))
  p <- ggplot()
  if (all(is.na(r$data))) {
    p <- p + annotate("text", x = mean(range(r$lon)), y = mean(range(r$lat)), label = paste0("No data stored for this slice\n(", r$status, ")"))
  } else {
    poly <- .cell_polygons(r$lon, r$lat, r$data)
    vm <- if (is.null(vmax)) max(1, max(r$data, na.rm = TRUE)) else vmax
    p <- p + geom_polygon(data = poly, aes(lon, lat, group = id, fill = value), colour = NA) +
      scale_fill_gradient(low = "#eef5ff", high = "#08306b", na.value = "grey85", limits = c(0, vm), name = paste0("Precipitation\n(", r$units, ")"))
  }
  p <- p + geom_path(data = bd, aes(lon, lat, group = ring), colour = "black", linewidth = 0.6)
  if (!is.null(st) && nrow(st)) {
    s <- st[!is.na(suppressWarnings(as.numeric(st$latitude))) & !duplicated(st$station_id), , drop = FALSE]
    s$lat <- as.numeric(s$latitude); s$lon <- as.numeric(s$longitude)
    s <- s[s$lat >= min(r$lat) & s$lat <= max(r$lat) & s$lon >= min(r$lon) & s$lon <= max(r$lon), , drop = FALSE]
    if (nrow(s)) p <- p + geom_point(data = s, aes(lon, lat, shape = source), fill = "orange", colour = "black", size = 2.8) +
      scale_shape_manual(values = rep(c(24, 21, 22, 23), length.out = length(unique(s$source))), name = "Station / gauge")
  }
  p <- p + coord_fixed(ratio = 1 / cos(38.9 * pi / 180)) +
    labs(x = "Longitude (degrees east)", y = "Latitude (degrees north)",
         title = title_src, subtitle = sprintf("%s: Daymet day %s (UTC); valid %s to %s%s", event_id, r$date_utc,
                                               substr(r$valid_start_utc, 1, 13), substr(r$valid_end_utc, 1, 13), .null_or(title_extra, "")),
         caption = "Grey/blank = no data (not zero rain). Black line = DC boundary.") +
    theme_minimal(base_size = 10)
  if (!is.null(save)) { dir.create(dirname(save), showWarnings = FALSE, recursive = TRUE); ggsave(save, p, width = 7.4, height = 6.4, dpi = 150) }
  p
}

# time series
.series_group <- function(f, source, station_id, variable) {
  path <- sprintf("timeseries/%s/%s__%s", source, station_id, variable)
  if (!f$exists(path)) {
    have <- if (f$exists(paste0("timeseries/", source))) f[[paste0("timeseries/", source)]]$ls()$name else character()
    stop("no stored series ", path, ". Stored for this source: ", paste(have, collapse = ", "))
  }
  f[[path]]
}

#' Stored station/gauge series as a data frame for an event window and/or a time range.
#' event_id: use that event's analysis window; start/end: POSIXct or strings (no zone = America/New_York).
#' Columns: time_utc, time_local, period_hours, value (NA = missing/flagged), quality, original_timestamp.
#' attr(, "meta") has unit, station name, coordinates, semantics and the missing-value rule.
get_timeseries <- function(h5, source, station_id, variable, event_id = NULL, start = NULL, end = NULL) {
  .with_h5(h5, function(f) {
    g <- .series_group(f, source, station_id, variable)
    t <- as.POSIXct(as.numeric(g[["time_utc"]]$read()), origin = "1970-01-01", tz = "UTC")
    d <- data.frame(time_utc = t, time_local = t, period_hours = as.numeric(g[["period_hours"]]$read()), value = as.numeric(g[["value"]]$read()),
                    quality = g[["quality"]]$read(), original_timestamp = g[["original_timestamp"]]$read(), stringsAsFactors = FALSE)
    attr(d$time_local, "tzone") <- EVENT_TZ
    lo <- hi <- NULL
    if (!is.null(event_id)) { ev <- .event_row(f, event_id); lo <- .parse_z(ev$window_start_utc); hi <- .parse_z(ev$window_end_utc) }
    if (!is.null(start)) lo <- .as_utc(start)
    if (!is.null(end)) hi <- .as_utc(end)
    if (!is.null(lo)) d <- d[d$time_utc >= lo, , drop = FALSE]
    if (!is.null(hi)) d <- d[d$time_utc <= hi, , drop = FALSE]
    rownames(d) <- NULL
    attr(d, "meta") <- .attrs(g)
    d
  })
}

#' Plot a stored series in local time. Precipitation = bars; water level = line. Grey bands = expected but missing;
#' red crosses = record present but value removed/NA; pink band = the reported flood event (begin to end).
plot_timeseries <- function(h5, source, station_id, variable, event_id = NULL, start = NULL, end = NULL, save = NULL) {
  d <- get_timeseries(h5, source, station_id, variable, event_id, start, end)
  m <- attr(d, "meta"); step <- as.numeric(.null_or(m$nominal_step_min, 0))
  unit <- .null_or(m$unit, ""); is_precip <- grepl("precip", variable)
  ev <- NULL; lo <- hi <- NULL
  if (!is.null(event_id)) {
    ev <- .with_h5(h5, function(f) .event_row(f, event_id)); lo <- .parse_z(ev$window_start_utc); hi <- .parse_z(ev$window_end_utc)
  }
  if (!is.null(start)) lo <- .as_utc(start)
  if (!is.null(end)) hi <- .as_utc(end)
  if (is.null(lo) && nrow(d)) lo <- min(d$time_utc)
  if (is.null(hi) && nrow(d)) hi <- max(d$time_utc)
  p <- ggplot()
  if (!is.null(ev)) p <- p + annotate("rect", xmin = .parse_z(ev$begin_utc), xmax = max(.parse_z(ev$end_utc), .parse_z(ev$begin_utc) + 600),
                                      ymin = -Inf, ymax = Inf, fill = "#f4b6c2", alpha = 0.45)
  if (!is.null(lo) && step > 0 && step <= 1440) {
    grid <- seq(lo, hi, by = step * 60); bin <- function(x) floor(as.numeric(x) / (step * 60))
    have <- unique(bin(d$time_utc[!is.na(d$value)]))
    miss <- grid[!(bin(grid) %in% have)]
    if (length(miss) > 0 && length(miss) <= 20000) {
      id <- cumsum(c(TRUE, diff(as.numeric(miss)) != step * 60))
      runs <- data.frame(xmin = tapply(as.numeric(miss), id, min), xmax = tapply(as.numeric(miss), id, max) + step * 60)
      runs$xmin <- as.POSIXct(runs$xmin, origin = "1970-01-01", tz = "UTC"); runs$xmax <- as.POSIXct(runs$xmax, origin = "1970-01-01", tz = "UTC")
      p <- p + geom_rect(data = runs, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf), fill = "grey85", alpha = 0.8)
    }
  }
  good <- d[!is.na(d$value), , drop = FALSE]; bad <- d[is.na(d$value), , drop = FALSE]
  if (nrow(good)) p <- p + (if (is_precip) geom_col(data = good, aes(time_utc, value), fill = "#1f77b4", width = max(step, 60) * 60 * 0.8)
                            else geom_line(data = good, aes(time_utc, value), colour = "#1f77b4", linewidth = 0.5))
  if (nrow(good) && !is_precip && nrow(good) < 400) p <- p + geom_point(data = good, aes(time_utc, value), colour = "#1f77b4", size = 0.8)
  if (nrow(bad) && nrow(good)) p <- p + geom_point(data = bad, aes(time_utc, min(good$value)), shape = 4, colour = "red", size = 1.8)
  if (!nrow(d)) p <- p + annotate("text", x = lo, y = 0, label = "No records stored for this window", hjust = 0)
  p <- p + scale_x_datetime(timezone = EVENT_TZ, date_labels = "%m-%d %H:%M") +
    labs(x = "Local time (America/New_York; EST/EDT as in effect)", y = sprintf("%s (%s)", variable, unit),
         title = sprintf("%s (%s)", .null_or(m$station_name, station_id), station_id),
         subtitle = sprintf("%s%s%s", source, if (!is.null(event_id)) paste0(" | ", event_id) else "", if (!is.null(m$semantics)) paste0(" | ", m$semantics) else ""),
         caption = "Grey band = expected but missing; red x = record present but value NA; pink = reported flood event") +
    theme_minimal(base_size = 10)
  if (!is.null(save)) { dir.create(dirname(save), showWarnings = FALSE, recursive = TRUE); ggsave(save, p, width = 9, height = 4, dpi = 150) }
  p
}

# coverage
#' Compact availability table. by = "source" (one row per event and source) or "series" (per station/variable).
coverage_summary <- function(h5, event_id = NULL, by = c("source", "series")) {
  by <- match.arg(by)
  a <- .with_h5(h5, function(f) read_table(f[["metadata/availability"]]))
  for (cn in c("expected", "n_valid", "n_zero", "n_present_not_valid", "n_missing", "max_gap_steps")) a[[cn]] <- as.numeric(a[[cn]])
  if (!is.null(event_id)) a <- a[a$event_id == event_id, , drop = FALSE]
  keys <- if (by == "source") c("event_id", "source") else c("event_id", "source", "station_id", "variable")
  g <- aggregate(a[, c("expected", "n_valid", "n_zero", "n_present_not_valid", "n_missing")], by = a[keys], FUN = sum)
  g$longest_gap <- aggregate(a["max_gap_steps"], by = a[keys], FUN = max)$max_gap_steps
  names(g)[names(g) == "n_valid"] <- "valid"; names(g)[names(g) == "n_zero"] <- "zero"
  names(g)[names(g) == "n_present_not_valid"] <- "flagged"; names(g)[names(g) == "n_missing"] <- "missing"
  g$pct_valid <- round(100 * g$valid / pmax(g$expected, 1), 1)
  g[order(g$event_id, g$source), ]
}
plot_coverage_heatmap <- function(h5, save = NULL) {
  # one row per source and variable (all stations pooled); fill = valid values / expected values in the event window
  a <- coverage_summary(h5, by = "series")
  a$row <- paste(a$source, a$variable, sep = " | ")
  a$expected <- as.numeric(a$expected); a$valid <- as.numeric(a$valid)
  ex <- tapply(a$expected, list(a$event_id, a$row), sum); va <- tapply(a$valid, list(a$event_id, a$row), sum)
  g <- as.data.frame(as.table(ex), stringsAsFactors = FALSE); names(g) <- c("event_id", "row", "expected")
  g$valid <- as.vector(va); g <- g[!is.na(g$expected) & g$expected > 0, ]
  g$pct_valid <- 100 * g$valid / g$expected
  p <- ggplot(g, aes(event_id, row, fill = pct_valid)) + geom_tile(colour = "white", linewidth = 0.1) +
    scale_fill_gradient2(low = "#d73027", mid = "#fee08b", high = "#1a9850", midpoint = 50, limits = c(0, 100), name = "% of expected\nvalues available") +
    labs(x = "Event", y = NULL, title = "Data availability by source and event window (all stations pooled)") +
    theme_minimal(base_size = 8) + theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1, size = 4))
  if (!is.null(save)) {
    dir.create(dirname(save), showWarnings = FALSE, recursive = TRUE)
    ggsave(save, p, width = 14, height = min(4 + 0.3 * length(unique(g$row)), 20), dpi = 150)
  }
  p
}