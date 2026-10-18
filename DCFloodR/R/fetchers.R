# Download + parse functions for each data source.
# Parsers are separate functions (text/file in, data frame/arrays out) so they can be tested offline.
# Every network call goes through http_get() from utils.R.

LONG_COLS <- c("source", "station_id", "variable", "time_utc", "period_hours", "value", "quality",
               "original_timestamp", "original_tz")
empty_long <- function() {
  d <- as.data.frame(matrix(character(), 0, length(LONG_COLS))); colnames(d) <- LONG_COLS; d$period_hours <- numeric(); d$value <- numeric(); d
}
long_df <- function(source, station_id, variable, time_utc, period_hours, value, quality, original_timestamp, original_tz) {
  n <- length(time_utc)
  if (n == 0) return(empty_long())
  data.frame(source = rep(source, n), station_id = rep(station_id, n), variable = rep(variable, n),
             time_utc = time_utc, period_hours = rep_len(period_hours, n), value = as.numeric(value),
             quality = rep_len(quality, n), original_timestamp = original_timestamp,
             original_tz = rep_len(original_tz, n), stringsAsFactors = FALSE)
}

# DC outline (context layer)
fetch_dc_boundary <- function() {
  r <- http_get("https://nominatim.openstreetmap.org/search",
                query = list(state = "District of Columbia", country = "United States", format = "geojson",
                             polygon_geojson = 1, limit = 1))
  if (r$status != 200) stop("HTTP ", r$status)
  feats <- resp_json(r)$features
  if (length(feats) == 0) stop("no feature returned")
  g <- feats[[1]]$geometry
  polys <- if (g$type == "Polygon") list(g$coordinates) else if (g$type == "MultiPolygon") g$coordinates else list()
  xs <- c(); ys <- c()
  for (poly in polys) {
    ring <- poly[[1]]
    xs <- c(xs, vapply(ring, function(p) as.numeric(p[[1]]), 0), NA)
    ys <- c(ys, vapply(ring, function(p) as.numeric(p[[2]]), 0), NA)
  }
  if (length(xs) == 0) stop("geometry type not polygon")
  list(lon = xs[-length(xs)], lat = ys[-length(ys)],
       note = paste0("OpenStreetMap Nominatim polygon for the District of Columbia, retrieved ", utc_now_iso()))
}

# Daymet V4R1 daily precipitation through NASA Earthdata OPeNDAP (Hyrax, DAP4 constraint expression)
daymet_url <- function(year) paste0(sprintf(DAYMET_OPENDAP, year), ".dap.nc4")
daymet_auth <- function() {
  u <- Sys.getenv("EARTHDATA_USER"); p <- Sys.getenv("EARTHDATA_PASS")
  if (nzchar(u) && nzchar(p)) list(u, p) else NULL
}
.dm <- new.env()   # remembers the x / y coordinate vectors of the Daymet grid for this R session

# Lambert Conformal Conic of the Daymet grid (sphere, radius 6378137 m; parallels 25 and 60, origin 42.5 N, 100 W)
daymet_lcc <- function(lon, lat) {
  R <- 6378137; rad <- pi / 180
  p1 <- 25 * rad; p2 <- 60 * rad; p0 <- 42.5 * rad; l0 <- -100 * rad
  n <- log(cos(p1) / cos(p2)) / log(tan(pi / 4 + p2 / 2) / tan(pi / 4 + p1 / 2))
  Fc <- cos(p1) * tan(pi / 4 + p1 / 2)^n / n
  rho0 <- R * Fc / tan(pi / 4 + p0 / 2)^n
  rho <- R * Fc / tan(pi / 4 + lat * rad / 2)^n
  th <- n * (lon * rad - l0)
  list(x = rho * sin(th), y = rho0 - rho * cos(th))
}

# x and y coordinate vectors (small) of the grid; returns list(x, y) or list(resp = <failed response>)
daymet_grid_xy <- function(year) {
  if (!is.null(.dm$xy)) return(.dm$xy)
  r <- http_get(daymet_url(year), query = list(dap4.ce = "/x;/y"), timeout = 300, auth = daymet_auth())
  ok <- r$status == 200 && length(r$content) > 8 && r$content[1] == as.raw(0x89)
  if (!ok) return(list(resp = r))
  f <- tempfile(fileext = ".nc"); writeBin(r$content, f)
  nc <- ncdf4::nc_open(f); on.exit({ ncdf4::nc_close(nc); unlink(f) })
  .dm$xy <- list(x = as.numeric(ncdf4::ncvar_get(nc, "x")), y = as.numeric(ncdf4::ncvar_get(nc, "y")))
  .dm$xy
}

fetch_daymet_run <- function(year, d0, d1, bbox) {
  # one request: all days from d0 to d1 (ISO dates, both inclusive) of one calendar year, rectangle of cells covering bbox
  t0 <- as.integer(format(as.Date(d0), "%j")) - 1L
  t1 <- min(as.integer(format(as.Date(d1), "%j")) - 1L, 364L)   # 365-day calendar: no 31 December in leap years
  if (t0 > 364L) return(list(status = 404L, content = charToRaw("31 December of a leap year is not in Daymet"), url = daymet_url(year)))
  xy <- daymet_grid_xy(year)
  if (!is.null(xy$resp)) return(xy$resp)
  g <- expand.grid(lon = seq(bbox[["west"]], bbox[["east"]], length.out = 7), lat = seq(bbox[["south"]], bbox[["north"]], length.out = 7))
  pj <- daymet_lcc(g$lon, g$lat)
  ix <- which(xy$x >= min(pj$x) - 1000 & xy$x <= max(pj$x) + 1000) - 1L
  iy <- which(xy$y >= min(pj$y) - 1000 & xy$y <= max(pj$y) + 1000) - 1L
  if (!length(ix) || !length(iy)) stop("the DC bounding box is outside the Daymet grid")
  x0 <- min(ix); x1 <- max(ix); y0 <- min(iy); y1 <- max(iy)
  ce <- sprintf("/prcp[%d:%d][%d:%d][%d:%d];/lat[%d:%d][%d:%d];/lon[%d:%d][%d:%d];/time[%d:%d];/time_bnds[%d:%d][0:1];/x[%d:%d];/y[%d:%d];/lambert_conformal_conic",
                t0, t1, y0, y1, x0, x1, y0, y1, x0, x1, y0, y1, x0, x1, t0, t1, t0, t1, x0, x1, y0, y1)
  http_get(daymet_url(year), query = list(dap4.ce = ce), timeout = 300, auth = daymet_auth())
}

parse_daymet_nc <- function(path) {
  # -> list(dates, prcp[time, y, x], lon[y, x], lat[y, x], x, y, start_utc, end_utc, bounds_from_file, attrs, crs)
  nc <- ncdf4::nc_open(path)
  on.exit(ncdf4::nc_close(nc))
  vars <- names(nc$var)
  if (!"prcp" %in% vars) stop("variable 'prcp' not found in the file")
  perm <- function(a, nm_have, nm_want) {
    if (length(nm_want) == 1) return(as.vector(a))
    aperm(array(a, dim = dim(a)), match(nm_want, nm_have))
  }
  dn <- vapply(nc$var$prcp$dim, function(d) d$name, "")
  a <- ncdf4::ncvar_get(nc, "prcp", collapse_degen = FALSE)
  if (length(dim(a)) != length(dn)) a <- array(a, dim = vapply(nc$var$prcp$dim, function(d) d$len, 1))
  prcp <- aperm(a, match(c("time", "y", "x"), dn))
  mat2 <- function(v) {
    d2 <- vapply(nc$var[[v]]$dim, function(d) d$name, "")
    m <- ncdf4::ncvar_get(nc, v, collapse_degen = FALSE)
    aperm(m, match(c("y", "x"), d2))
  }
  if (!all(c("lat", "lon") %in% vars)) stop("lat/lon variables missing in the Daymet subset")
  lat <- mat2("lat"); lon <- mat2("lon")
  tt <- as.numeric(ncdf4::ncvar_get(nc, "time"))
  units <- ncdf4::ncatt_get(nc, "time", "units")$value
  origin <- as.POSIXct(sub(".*since ([0-9]{4}-[0-9]{2}-[0-9]{2}).*", "\\1", units), tz = "UTC")
  stamp <- origin + tt * 86400
  if ("time_bnds" %in% vars) {
    b <- ncdf4::ncvar_get(nc, "time_bnds", collapse_degen = FALSE)
    st <- origin + as.numeric(b[1, ]) * 86400; en <- origin + as.numeric(b[2, ]) * 86400; from_file <- TRUE
  } else {
    st <- stamp - 12 * 3600; en <- stamp + 12 * 3600; from_file <- FALSE
  }
  at <- ncdf4::ncatt_get(nc, "prcp")
  crs <- if ("lambert_conformal_conic" %in% vars) ncdf4::ncatt_get(nc, "lambert_conformal_conic") else list()
  list(dates = as.Date(format(stamp, "%Y-%m-%d", tz = "UTC")), prcp = prcp, lon = lon, lat = lat,
       x = as.numeric(ncdf4::ncvar_get(nc, "x")), y = as.numeric(ncdf4::ncvar_get(nc, "y")),
       start_utc = st, end_utc = en, bounds_from_file = from_file,
       attrs = at, crs = crs, time_units = units)
}

# USGS water-level gauges
parse_rdb <- function(text) {
  lines <- strsplit(text, "\r?\n")[[1]]
  lines <- lines[nzchar(lines) & !startsWith(lines, "#")]
  if (length(lines) < 2) return(data.frame())
  hdr <- strsplit(lines[1], "\t", fixed = TRUE)[[1]]
  rows <- strsplit(lines[-(1:2)], "\t", fixed = TRUE)
  if (!length(rows)) { e <- as.data.frame(matrix(character(), 0, length(hdr)), stringsAsFactors = FALSE); names(e) <- hdr; return(e) }
  m <- do.call(rbind, lapply(rows, function(r) { length(r) <- length(hdr); r }))
  d <- as.data.frame(m, stringsAsFactors = FALSE); names(d) <- hdr; d
}

usgs_sites_legacy <- function(bbox, params) {
  q <- list(format = "rdb", bBox = sprintf("%.4f,%.4f,%.4f,%.4f", bbox[["west"]], bbox[["south"]], bbox[["east"]], bbox[["north"]]),
            parameterCd = paste(params, collapse = ","), siteStatus = "all", siteOutput = "expanded", hasDataTypeCd = "iv,dv")
  r <- http_get("https://waterservices.usgs.gov/nwis/site/", query = q)
  if (r$status != 200) return(list(sites = NULL, url = r$url, status = paste("HTTP", r$status)))
  d <- parse_rdb(resp_text(r))
  if (!nrow(d) || !"site_no" %in% names(d)) return(list(sites = NULL, url = r$url, status = "ok (no sites)"))
  list(sites = data.frame(site_no = d$site_no, name = d$station_nm, lat = as.numeric(d$dec_lat_va),
                          lon = as.numeric(d$dec_long_va), found_by = "legacy site service", stringsAsFactors = FALSE),
       url = r$url, status = "ok")
}

usgs_sites_by_id_legacy <- function(ids) {
  r <- http_get("https://waterservices.usgs.gov/nwis/site/", query = list(format = "rdb", sites = paste(ids, collapse = ","), siteOutput = "expanded"))
  if (r$status != 200) return(list(sites = NULL, url = r$url, status = paste("HTTP", r$status)))
  d <- parse_rdb(resp_text(r))
  if (!nrow(d) || !"site_no" %in% names(d)) return(list(sites = NULL, url = r$url, status = "ok (no sites)"))
  list(sites = data.frame(site_no = d$site_no, name = d$station_nm, lat = as.numeric(d$dec_lat_va),
                          lon = as.numeric(d$dec_long_va), found_by = "legacy site service (seed id)", stringsAsFactors = FALSE),
       url = r$url, status = "ok")
}

ogc_get <- function(path_or_url, query = list()) {
  key <- Sys.getenv("USGS_API_KEY", unset = "")            # optional free key; read from the environment, never stored
  if (nzchar(key)) query$api_key <- key
  url <- if (startsWith(path_or_url, "http")) path_or_url else paste0(OGC_BASE, path_or_url)
  http_get(url, query = if (length(query)) query else NULL)
}

parse_ogc_locations <- function(js, found_by = "Water Data API monitoring-locations") {
  f <- js$features
  if (length(f) == 0) return(NULL)
  rows <- lapply(f, function(x) {
    p <- x$properties; co <- x$geometry$coordinates
    id <- p$monitoring_location_number %||% sub("^USGS-", "", x$id %||% p$id %||% "")
    data.frame(site_no = as.character(id), name = as.character(p$monitoring_location_name %||% ""),
               lat = as.numeric(co[[2]] %||% NA), lon = as.numeric(co[[1]] %||% NA),
               site_type = as.character(p$site_type_code %||% ""), found_by = found_by, stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

usgs_sites_ogc <- function(bbox) {
  r <- ogc_get("/collections/monitoring-locations/items",
               list(bbox = sprintf("%.4f,%.4f,%.4f,%.4f", bbox[["west"]], bbox[["south"]], bbox[["east"]], bbox[["north"]]),
                    limit = 1000, f = "json"))
  if (r$status != 200) return(list(sites = NULL, url = r$url, status = paste("HTTP", r$status)))
  d <- parse_ogc_locations(resp_json(r))
  if (is.null(d)) return(list(sites = NULL, url = r$url, status = "ok (no sites)"))
  keep <- grepl("^(ST|ES|LK|SP|ST-TS|ST-CA|ST-DCH)", d$site_type) | d$site_type == ""    # surface-water site types
  list(sites = d[keep, , drop = FALSE], url = r$url, status = "ok")
}

usgs_sites_by_id_ogc <- function(ids) {
  r <- ogc_get("/collections/monitoring-locations/items",
               list(monitoring_location_id = paste0("USGS-", ids, collapse = ","), limit = 100, f = "json"))
  if (r$status != 200) return(list(sites = NULL, url = r$url, status = paste("HTTP", r$status)))
  d <- parse_ogc_locations(resp_json(r), "Water Data API (seed id)")
  list(sites = d, url = r$url, status = if (is.null(d)) "ok (no sites)" else "ok")
}

# legacy (waterservices) time-series JSON
parse_usgs_legacy_json <- function(js) {
  out <- list()
  for (ts in js$value$timeSeries) {
    si <- ts$sourceInfo; var <- ts$variable
    g <- si$geoLocation$geogLocation
    recs <- list()
    for (blk in ts$values) for (r in blk$value)
      recs[[length(recs) + 1]] <- data.frame(original_timestamp = r$dateTime, raw = as.character(r$value),
                                             qualifiers = paste(unlist(r$qualifiers), collapse = ","), stringsAsFactors = FALSE)
    out[[length(out) + 1]] <- list(
      site = si$siteCode[[1]]$value, name = si$siteName %||% "", latitude = as.numeric(g$latitude %||% NA),
      longitude = as.numeric(g$longitude %||% NA), param_cd = var$variableCode[[1]]$value,
      var_name = var$variableName %||% "", unit = var$unit$unitCode %||% "", nodata = var$noDataValue %||% NA,
      records = if (length(recs)) do.call(rbind, recs) else
        data.frame(original_timestamp = character(), raw = character(), qualifiers = character()))
  }
  out
}

fetch_usgs_legacy <- function(service, sites, params, start, end) {
  url <- if (service == "iv") "https://waterservices.usgs.gov/nwis/iv/" else "https://waterservices.usgs.gov/nwis/dv/"
  q <- list(format = "json", sites = paste(sites, collapse = ","), parameterCd = paste(params, collapse = ","),
            startDT = start, endDT = end, siteStatus = "all")
  if (service == "dv") q$statCd <- "00003"
  r <- http_get(url, query = q)
  if (r$status != 200) return(list(series = list(), url = r$url, status = paste("HTTP", r$status)))
  js <- tryCatch(resp_json(r), error = function(e) NULL)
  if (is.null(js)) return(list(series = list(), url = r$url, status = "response was not JSON"))
  list(series = parse_usgs_legacy_json(js), url = r$url, status = "ok")
}

# new Water Data API (OGC) time-series
parse_ogc_series <- function(features) {
  if (length(features) == 0) return(list())
  g <- lapply(features, function(f) {
    p <- f$properties
    data.frame(site = sub("^USGS-", "", as.character(p$monitoring_location_id %||% "")),
               param_cd = as.character(p$parameter_code %||% ""), unit = as.character(p$unit_of_measure %||% ""),
               original_timestamp = as.character(p$time %||% ""), raw = as.character(p$value %||% ""),
               qualifiers = paste(c(unlist(p$approval_status %||% p$approvals_status %||% ""), unlist(p$qualifier)), collapse = ","),
               stringsAsFactors = FALSE)
  })
  d <- do.call(rbind, g)
  key <- paste(d$site, d$param_cd, sep = "|")
  res <- lapply(split(seq_len(nrow(d)), key), function(ix) {
    x <- d[ix, , drop = FALSE]
    list(site = x$site[1], name = "", latitude = NA_real_, longitude = NA_real_, param_cd = x$param_cd[1],
         var_name = "", unit = x$unit[1], nodata = NA,
         records = x[, c("original_timestamp", "raw", "qualifiers")])
  })
  unname(res)
}

fetch_usgs_ogc <- function(service, sites, params, start, end) {
  coll <- if (service == "iv") "continuous" else "daily"
  dt <- if (service == "iv") paste0(start, "/", end) else paste0(substr(start, 1, 10), "/", substr(end, 1, 10))
  q <- list(monitoring_location_id = paste0("USGS-", sites, collapse = ","), parameter_code = paste(params, collapse = ","),
            datetime = dt, limit = 10000, f = "json")
  if (service == "dv") q$statistic_id <- "00003"
  feats <- list(); url <- NULL; page <- 0
  r <- ogc_get(paste0("/collections/", coll, "/items"), q)
  repeat {
    url <- r$url
    if (r$status != 200) return(list(series = list(), url = url, status = paste("HTTP", r$status)))
    js <- tryCatch(resp_json(r), error = function(e) NULL)
    if (is.null(js)) return(list(series = list(), url = url, status = "response was not JSON"))
    feats <- c(feats, js$features)
    nxt <- NULL
    for (l in js$links) if (identical(l$rel, "next")) nxt <- l$href
    page <- page + 1
    if (is.null(nxt) || page >= 30 || length(js$features) == 0) break
    r <- ogc_get(nxt)
  }
  list(series = parse_ogc_series(feats), url = url, status = "ok")
}

fetch_usgs <- function(service, sites, params, start_utc, end_utc, backends = c("ogc", "legacy")) {
  # start_utc/end_utc: POSIXct. Tries the backends in order; stops at the first one that returns series.
  # Returns list(series, url, status, backend, attempts) where attempts = one "backend: status (n series)" text per try.
  s_iso <- iso_z(start_utc); e_iso <- iso_z(end_utc)
  attempt <- function(be) {
    if (be == "ogc") fetch_usgs_ogc(service, sites, params, s_iso, e_iso)
    else {
      st <- if (service == "iv") format(start_utc, "%Y-%m-%dT%H:%MZ", tz = "UTC") else format(start_utc, "%Y-%m-%d", tz = "UTC")
      en <- if (service == "iv") format(end_utc, "%Y-%m-%dT%H:%MZ", tz = "UTC") else format(end_utc, "%Y-%m-%d", tz = "UTC")
      fetch_usgs_legacy(service, sites, params, st, en)
    }
  }
  res <- list(series = list(), url = "", status = "no backend available", backend = "none"); att <- character()
  for (be in backends) {
    r <- tryCatch(attempt(be), error = function(e) list(series = list(), url = "", status = paste("failed:", conditionMessage(e))))
    att <- c(att, sprintf("%s: %s (%d series)", be, r$status, length(r$series)))
    r$backend <- be; res <- r
    if (r$status == "ok" && length(r$series) > 0) break
  }
  res$attempts <- att
  res
}

usgs_to_long <- function(series, source, variable, service) {
  d <- series$records
  if (!nrow(d)) return(empty_long())
  val <- suppressWarnings(as.numeric(d$raw))
  if (!is.na(series$nodata)) val[!is.na(val) & val == as.numeric(series$nodata)] <- NA
  if (service == "iv") {
    t <- parse_iso_offset(d$original_timestamp)
    time_utc <- iso_z(t); period <- NA_real_; tz <- "site local time with UTC offset in the stamp (as published)"
  } else {      # daily value: label is a local date; time_utc = END of that local calendar day
    lab <- as.Date(substr(d$original_timestamp, 1, 10))
    time_utc <- iso_z(local_midnight_utc(lab + 1)); period <- 24
    tz <- "date label (local calendar day); time_utc is the end of that day"
  }
  long_df(source, series$site, variable, time_utc, period, val, d$qualifiers, d$original_timestamp, tz)
}

# NOAA CO-OPS (tide / water-level stations)
coops_stations <- function() {
  r <- http_get("https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json", query = list(type = "waterlevels"))
  if (r$status != 200) return(list(stations = NULL, url = r$url, status = paste("HTTP", r$status)))
  st <- resp_json(r)$stations
  if (!length(st)) return(list(stations = NULL, url = r$url, status = "ok (no stations)"))
  d <- do.call(rbind, lapply(st, function(s) data.frame(id = as.character(s$id), name = as.character(s$name %||% ""),
                                                        lat = as.numeric(s$lat), lon = as.numeric(s$lng),
                                                        state = as.character(s$state %||% ""), stringsAsFactors = FALSE)))
  list(stations = d, url = r$url, status = "ok")
}

parse_coops_json <- function(js) {
  if (!is.null(js$error)) return(list(ok = FALSE, message = as.character(js$error$message %||% "error"), data = NULL, meta = NULL))
  d <- js$data
  if (!length(d)) return(list(ok = FALSE, message = "no data returned", data = NULL, meta = js$metadata))
  df <- do.call(rbind, lapply(d, function(x) data.frame(t = x$t, v = x$v %||% "", s = x$s %||% "", f = x$f %||% "", q = x$q %||% "",
                                                        stringsAsFactors = FALSE)))
  list(ok = TRUE, message = "ok", data = df, meta = js$metadata)
}

fetch_coops <- function(station, begin_utc, end_utc, product = "water_level", datum = COOPS_DATUM) {
  q <- list(begin_date = format(begin_utc, "%Y%m%d %H:%M", tz = "UTC"), end_date = format(end_utc, "%Y%m%d %H:%M", tz = "UTC"),
            station = station, product = product, datum = datum, time_zone = "gmt", units = "metric", format = "json",
            application = "STAT6289_student_project")
  if (product == "hourly_height") q$datum <- datum
  r <- http_get("https://api.tidesandcurrents.noaa.gov/api/prod/datagetter", query = q)
  if (r$status != 200) return(list(ok = FALSE, message = paste("HTTP", r$status), data = NULL, meta = NULL, url = r$url))
  js <- tryCatch(resp_json(r), error = function(e) NULL)
  if (is.null(js)) return(list(ok = FALSE, message = "response was not JSON", data = NULL, meta = NULL, url = r$url))
  out <- parse_coops_json(js); out$url <- r$url; out
}

coops_to_long <- function(df, station, variable, period_hours) {
  if (is.null(df) || !nrow(df)) return(empty_long())
  t <- as.POSIXct(df$t, format = "%Y-%m-%d %H:%M", tz = "UTC")
  val <- suppressWarnings(as.numeric(df$v))
  qual <- paste0("q:", df$q, "|flags:", df$f, "|sigma:", df$s)
  long_df("noaa_coops", station, variable, iso_z(t), period_hours, val, qual, df$t, "UTC (time_zone=gmt requested)")
}

# NOAA GHCN-Daily (stations inside DC)
parse_ghcnd_stations <- function(text) {
  ln <- strsplit(text, "\r?\n")[[1]]; ln <- ln[nchar(ln) >= 41]
  data.frame(id = trimws(substr(ln, 1, 11)), latitude = as.numeric(substr(ln, 13, 20)),
             longitude = as.numeric(substr(ln, 22, 30)), elevation = trimws(substr(ln, 32, 37)),
             state = trimws(substr(ln, 39, 40)), name = trimws(substr(ln, 42, 71)), stringsAsFactors = FALSE)
}
parse_ghcnd_inventory <- function(text) {
  ln <- strsplit(text, "\r?\n")[[1]]; ln <- ln[nchar(ln) >= 40]
  p <- strsplit(trimws(ln), "\\s+")
  p <- p[vapply(p, length, 1L) >= 6]
  data.frame(id = vapply(p, `[`, "", 1), element = vapply(p, `[`, "", 4),
             first_year = as.integer(vapply(p, `[`, "", 5)), last_year = as.integer(vapply(p, `[`, "", 6)),
             stringsAsFactors = FALSE)
}

GHCND_COLS <- c("station", "date", "latitude", "longitude", "name", "value_mm", "m_flag", "q_flag", "s_flag", "obs_time")
empty_ghcnd <- function() { d <- as.data.frame(matrix(character(), 0, length(GHCND_COLS))); colnames(d) <- GHCND_COLS
d$value_mm <- numeric(); d$latitude <- numeric(); d$longitude <- numeric(); d }
parse_ghcnd_csv <- function(text) {
  if (!nzchar(trimws(text)) || substr(trimws(text), 1, 1) %in% c("{", "<", "[")) return(empty_ghcnd())
  d <- tryCatch(utils::read.csv(text = text, colClasses = "character", na.strings = character(0)), error = function(e) NULL)
  if (is.null(d) || !"PRCP" %in% names(d) || !nrow(d)) return(empty_ghcnd())
  att <- if ("PRCP_ATTRIBUTES" %in% names(d)) d$PRCP_ATTRIBUTES else rep("", nrow(d))
  parts <- do.call(rbind, lapply(strsplit(paste0(att, ",,,"), ",", fixed = TRUE), function(p) p[1:4]))
  col <- function(n) if (n %in% names(d)) d[[n]] else rep("", nrow(d))
  data.frame(station = col("STATION"), date = col("DATE"), latitude = suppressWarnings(as.numeric(col("LATITUDE"))),
             longitude = suppressWarnings(as.numeric(col("LONGITUDE"))), name = col("NAME"),
             value_mm = suppressWarnings(as.numeric(d$PRCP)), m_flag = parts[, 1], q_flag = parts[, 2],
             s_flag = parts[, 3], obs_time = parts[, 4], stringsAsFactors = FALSE)
}
fetch_ghcnd <- function(station, start, end) {
  q <- list(dataset = "daily-summaries", stations = station, startDate = start, endDate = end, dataTypes = "PRCP",
            format = "csv", includeAttributes = "true", units = "metric", includeStationName = "true", includeStationLocation = "1")
  r <- http_get("https://www.ncei.noaa.gov/access/services/data/v1", query = q)
  if (r$status != 200) return(list(df = empty_ghcnd(), url = r$url, status = paste("HTTP", r$status)))
  list(df = parse_ghcnd_csv(resp_text(r)), url = r$url, status = "ok")
}
# Whole-station history file (one static file per station, fixed-width .dly format).
# Layout: id 1-11, year 12-15, month 16-17, element 18-21, then 31 blocks of 8 characters
# (value 5, measurement flag 1, quality flag 1, source flag 1). PRCP is in tenths of mm; -9999 = missing.
parse_ghcnd_dly <- function(text, station) {
  ln <- strsplit(text, "\r?\n")[[1]]
  ln <- ln[nchar(ln) >= 269 & substr(ln, 18, 21) == "PRCP"]
  if (!length(ln)) return(empty_ghcnd())
  out <- vector("list", length(ln))
  for (i in seq_along(ln)) {
    x <- ln[i]; yr <- as.integer(substr(x, 12, 15)); mo <- as.integer(substr(x, 16, 17))
    st <- 22 + 8 * (0:30)
    v <- suppressWarnings(as.integer(substring(x, st, st + 4)))
    d <- suppressWarnings(as.Date(sprintf("%04d-%02d-%02d", yr, mo, 1:31)))
    ok <- !is.na(d) & !is.na(v) & v != -9999
    if (!any(ok)) next
    out[[i]] <- data.frame(station = station, date = as.character(d[ok]), latitude = NA_real_, longitude = NA_real_, name = "",
                           value_mm = v[ok] / 10, m_flag = substring(x, st + 5, st + 5)[ok], q_flag = substring(x, st + 6, st + 6)[ok],
                           s_flag = substring(x, st + 7, st + 7)[ok], obs_time = "", stringsAsFactors = FALSE)
  }
  out <- Filter(Negate(is.null), out)
  if (!length(out)) empty_ghcnd() else do.call(rbind, out)
}
fetch_ghcnd_dly <- function(station) {
  url <- sprintf("https://www.ncei.noaa.gov/pub/data/ghcn/daily/all/%s.dly", station)
  r <- http_get(url, timeout = 180)
  if (r$status != 200) return(list(df = empty_ghcnd(), url = r$url, status = paste("HTTP", r$status)))
  list(df = parse_ghcnd_dly(resp_text(r), station), url = r$url, status = "ok")
}
ghcnd_to_long <- function(df, source, station_id, variable = "precip_daily_mm") {
  # time_utc = END of the 24 h accumulation: obs time of day (TOBS, local standard time = UTC-5), or midnight LST
  if (!nrow(df)) return(empty_long())
  q <- trimws(df$q_flag)
  val <- ifelse(q == "", df$value_mm, NA_real_)
  tobs <- trimws(df$obs_time)
  hh <- suppressWarnings(as.numeric(substr(tobs, 1, 2))); hh[is.na(hh)] <- 24
  mm <- suppressWarnings(as.numeric(substr(tobs, 3, 4))); mm[is.na(mm)] <- 0
  d <- as.POSIXct(substr(df$date, 1, 10), tz = "UTC")
  end_utc <- d + hh * 3600 + mm * 60 + 5 * 3600
  quality <- paste0("M:", trimws(df$m_flag), "|Q:", q, "|S:", trimws(df$s_flag), "|TOBS:", tobs)
  long_df(source, station_id, variable, iso_z(end_utc), 24, val, quality, df$date,
          "date label; interval end read as local standard time (UTC-5)")
}

# NASA CMR granule search (public, no login)
parse_cmr_granules <- function(js) {
  e <- js$feed$entry
  cols <- c("granule_id", "time_start", "time_end", "cloud_cover", "collection", "data_links")
  if (!length(e)) { d <- as.data.frame(matrix(character(), 0, 6)); colnames(d) <- cols; return(d) }
  do.call(rbind, lapply(e, function(x) {
    lk <- vapply(Filter(function(l) grepl("data#$", l$rel %||% ""), x$links), function(l) l$href, "")
    data.frame(granule_id = x$title %||% "", time_start = x$time_start %||% "", time_end = x$time_end %||% "",
               cloud_cover = as.character(x$cloud_cover %||% ""), collection = x$dataset_id %||% "",
               data_links = paste(head(lk, 3), collapse = " "), stringsAsFactors = FALSE)
  }))
}
cmr_search <- function(short_name, bbox, start_iso, end_iso) {
  q <- list(short_name = short_name, bounding_box = sprintf("%s,%s,%s,%s", bbox[["west"]], bbox[["south"]], bbox[["east"]], bbox[["north"]]),
            `temporal[]` = paste0(start_iso, ",", end_iso), page_size = 200)
  r <- http_get("https://cmr.earthdata.nasa.gov/search/granules.json", query = q)
  if (r$status != 200) return(list(df = parse_cmr_granules(list()), url = r$url, status = paste("HTTP", r$status)))
  list(df = parse_cmr_granules(resp_json(r)), url = r$url, status = "ok")
}