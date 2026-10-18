# Shared helpers: HTTP with retries, retrieval log, time helpers, geometry, merged intervals.

UA <- "STAT6289-DC-flood-project/1.0 (student coursework)"
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

# cookie file used for the NASA Earthdata sign-in redirect (kept in the R temp folder, deleted when R closes)
.cookie_jar <- file.path(tempdir(), "earthdata_cookies.txt")
http_get <- function(url, query = NULL, tries = 3, timeout = 120, headers = NULL, auth = NULL) {
  # GET with a few retries on network errors and 429/5xx. Returns list(status, content (raw), url).
  last <- "no attempt"
  for (k in seq_len(tries)) {
    r <- tryCatch(httr::GET(url, query = query, httr::timeout(timeout), httr::user_agent(UA),
                            if (!is.null(headers)) httr::add_headers(.headers = headers),
                            if (!is.null(auth)) httr::authenticate(auth[[1]], auth[[2]], type = "basic"),
                            if (!is.null(auth)) httr::config(unrestricted_auth = 1L, followlocation = 1L,
                                                             cookiefile = .cookie_jar, cookiejar = .cookie_jar)),
                  error = function(e) e)
    if (inherits(r, "error")) { last <- substr(conditionMessage(r), 1, 150); Sys.sleep(3 * k); next }
    st <- httr::status_code(r)
    if (st %in% c(429, 500, 502, 503, 504)) { last <- paste("HTTP", st); Sys.sleep(3 * k); next }
    return(list(status = st, content = httr::content(r, "raw"), url = r$url))
  }
  stop(last, call. = FALSE)
}
resp_text <- function(r) { x <- rawToChar(r$content); Encoding(x) <- "UTF-8"; x }
resp_json <- function(r) jsonlite::fromJSON(resp_text(r), simplifyVector = FALSE)

ensure_dirs <- function() {
  for (d in unlist(DIR)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# retrieval log
new_log <- function(name) { e <- new.env(); e$name <- name; e$rows <- list(); e }
log_add <- function(log, source, item, url, status, n_records = 0, note = "") {
  log$rows[[length(log$rows) + 1]] <- data.frame(
    retrieved_utc = utc_now_iso(), source = as.character(source), item = as.character(item),
    url = as.character(url %||% ""), status = as.character(status), n_records = n_records,
    note = as.character(note), stringsAsFactors = FALSE)
}
log_save <- function(log) {
  d <- if (length(log$rows)) do.call(rbind, log$rows) else
    data.frame(retrieved_utc = character(), source = character(), item = character(), url = character(),
               status = character(), n_records = numeric(), note = character())
  ensure_dirs()
  utils::write.csv(d, file.path(DIR$interim, paste0("log_", log$name, ".csv")), row.names = FALSE)
  invisible(d)
}

# time helpers
utc_now_iso <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
iso_z <- function(t) format(as.POSIXct(t, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
parse_iso_z <- function(x) as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
epoch_s <- function(t) as.numeric(as.POSIXct(t, tz = "UTC"))
from_epoch <- function(s) as.POSIXct(s, origin = "1970-01-01", tz = "UTC")

parse_iso_offset <- function(x) {
  # "2020-07-06T20:00:00.000-04:00", "...Z", "...+0000" or no offset (read as UTC) -> POSIXct UTC
  x <- as.character(x)
  has_off <- grepl("(Z|[+-][0-9]{2}:?[0-9]{2})$", x) & grepl("[T ][0-9]{2}:", x)
  off <- ifelse(has_off, sub(".*(Z|[+-][0-9]{2}:?[0-9]{2})$", "\\1", x), "")
  base <- ifelse(has_off, sub("(Z|[+-][0-9]{2}:?[0-9]{2})$", "", x), x)
  base <- sub("\\.[0-9]+$", "", gsub("T", " ", base))
  t <- as.POSIXct(base, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
  sec <- rep(0, length(x))
  m <- off != "" & off != "Z"
  if (any(m)) {
    o <- gsub(":", "", off[m])
    sec[m] <- ifelse(substr(o, 1, 1) == "-", -1, 1) *
      (as.numeric(substr(o, 2, 3)) * 3600 + as.numeric(substr(o, 4, 5)) * 60)
  }
  t - sec
}

local_midnight_utc <- function(d) {
  t <- as.POSIXct(format(as.Date(d)), tz = EVENT_TZ)
  as.POSIXct(as.numeric(t), origin = "1970-01-01", tz = "UTC")
}

merge_intervals <- function(starts, ends, gap_s = 0) {
  # merge overlapping / touching POSIXct intervals; returns data.frame(start, end)
  o <- order(starts); s <- starts[o]; e <- ends[o]
  out_s <- s[1]; out_e <- e[1]; res <- list()
  for (i in seq_along(s)[-1]) {
    if (as.numeric(s[i]) <= as.numeric(out_e) + gap_s) {
      if (e[i] > out_e) out_e <- e[i]
    } else { res[[length(res) + 1]] <- c(out_s, out_e); out_s <- s[i]; out_e <- e[i] }
  }
  res[[length(res) + 1]] <- c(out_s, out_e)
  data.frame(start = as.POSIXct(vapply(res, `[`, numeric(1), 1), origin = "1970-01-01", tz = "UTC"),
             end = as.POSIXct(vapply(res, `[`, numeric(1), 2), origin = "1970-01-01", tz = "UTC"))
}

# events index
load_events_index <- function(valid_only = TRUE) {
  p <- file.path(DIR$interim, "events_index.csv")
  if (!file.exists(p)) stop("data/interim/events_index.csv not found - run step1_events.R first.", call. = FALSE)
  ev <- utils::read.csv(p, colClasses = "character", na.strings = character(0), check.names = FALSE)
  if (valid_only) ev <- ev[ev$status == "ok", , drop = FALSE]
  rownames(ev) <- NULL
  ev$window_start <- parse_iso_z(ev$window_start_utc); ev$window_end <- parse_iso_z(ev$window_end_utc)
  ev$begin_t <- parse_iso_z(ev$begin_utc); ev$end_t <- parse_iso_z(ev$end_utc)
  ev
}

# geometry
load_dc_boundary <- function() {
  p <- file.path(DIR$interim, "dc_boundary.csv")
  if (file.exists(p)) {
    b <- utils::read.csv(p)
    sp <- file.path(DIR$interim, "dc_boundary_source.txt")
    return(list(lon = b$lon, lat = b$lat, note = if (file.exists(sp)) readLines(sp, warn = FALSE)[1] else ""))
  }
  w <- DC_BBOX[["west"]]; s <- DC_BBOX[["south"]]; e <- DC_BBOX[["east"]]; n <- DC_BBOX[["north"]]
  list(lon = c(w, e, e, w, w), lat = c(s, s, n, n, s),
       note = "approximate rectangle (DC bounding box); real boundary not downloaded")
}

point_in_polygon <- function(lon, lat, px, py) {
  # ray casting; the polygon may contain several rings separated by NA
  brk <- c(0, which(is.na(px) | is.na(py)), length(px) + 1)
  inside <- FALSE
  for (k in seq_len(length(brk) - 1)) {
    idx <- setdiff(seq(brk[k] + 1, brk[k + 1] - 1), integer(0))
    if (length(idx) < 3) next
    xs <- px[idx]; ys <- py[idx]; n <- length(xs); j <- n; ring_in <- FALSE
    for (i in seq_len(n)) {
      if (((ys[i] > lat) != (ys[j] > lat)) &&
          (lon < (xs[j] - xs[i]) * (lat - ys[i]) / (ys[j] - ys[i] + 1e-300) + xs[i])) ring_in <- !ring_in
      j <- i
    }
    inside <- xor(inside, ring_in)
  }
  inside
}
in_dc <- function(lat, lon) {
  lat <- suppressWarnings(as.numeric(lat)); lon <- suppressWarnings(as.numeric(lon))
  if (length(lat) != 1 || length(lon) != 1 || is.na(lat) || is.na(lon)) return(FALSE)
  b <- load_dc_boundary()
  point_in_polygon(lon, lat, b$lon, b$lat)
}

write_md <- function(lines, path) writeLines(enc2utf8(lines), path, useBytes = TRUE)

# station source files (long format + metadata)
META_COLS <- c("source", "station_id", "variable", "unit", "station_name", "latitude", "longitude", "in_dc",
               "request_status", "n_records", "semantics", "nominal_step_min", "note")
meta_row <- function(...) {
  kw <- list(...); row <- setNames(as.list(rep("", length(META_COLS))), META_COLS)
  for (n in names(kw)) row[[n]] <- if (is.null(kw[[n]])) "" else kw[[n]]
  as.data.frame(lapply(row, function(v) if (length(v) == 0) "" else v), stringsAsFactors = FALSE)
}
save_source <- function(name, long_parts, meta_rows) {
  long_parts <- Filter(function(p) !is.null(p) && nrow(p) > 0, long_parts)
  ts <- if (length(long_parts)) do.call(rbind, long_parts) else empty_long()
  if (nrow(ts)) {
    ts <- ts[!duplicated(ts[, c("source", "station_id", "variable", "time_utc", "period_hours")]), , drop = FALSE]
    ts <- ts[order(ts$station_id, ts$variable, ts$time_utc), , drop = FALSE]
  }
  utils::write.csv(ts, file.path(DIR$interim, paste0("ts_", name, ".csv")), row.names = FALSE)
  m <- if (length(meta_rows)) do.call(rbind, lapply(meta_rows, function(r) r[, META_COLS, drop = FALSE])) else
    as.data.frame(setNames(replicate(length(META_COLS), character(), simplify = FALSE), META_COLS))
  utils::write.csv(m, file.path(DIR$interim, paste0("meta_", name, ".csv")), row.names = FALSE)
  cat(sprintf("%s: %d records, %d station/variable entries\n", name, nrow(ts), nrow(m)))
  invisible(NULL)
}