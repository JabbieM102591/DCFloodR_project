# Step 1 - read and validate the instructor's flood-event CSV (the original file is never changed).
# Writes: data/interim/events_index.csv, data/interim/events_input_md5.txt, reports/events_validation.md
source("R/setup.R")
ensure_dirs()
if (!file.exists(EVENTS_CSV)) stop("Put the instructor's CSV at ", EVENTS_CSV, " (unchanged) and run again.", call. = FALSE)

raw <- utils::read.csv(EVENTS_CSV, colClasses = "character", na.strings = character(0), check.names = FALSE,
                       strip.white = TRUE)
need <- c("begin_date", "begin_time", "end_date", "end_time")
if (!all(need %in% names(raw)))
  stop("Expected columns ", paste(need, collapse = ", "), ". Found: ", paste(names(raw), collapse = ", "), call. = FALSE)

parse_local <- function(d, t) {
  txt <- paste(d, t)
  x <- as.POSIXct(txt, format = "%Y-%m-%d %H:%M", tz = EVENT_TZ)
  est <- as.POSIXct(txt, format = "%Y-%m-%d %H:%M", tz = "Etc/GMT+5")        # fixed UTC-5 reading of the same text
  back <- ifelse(is.na(x), "", format(x, "%Y-%m-%d %H:%M", tz = EVENT_TZ))
  gap <- !is.na(est) & (is.na(x) | back != format(est, "%Y-%m-%d %H:%M", tz = "Etc/GMT+5"))
  x[gap] <- est[gap]                                                          # time skipped by the spring-forward clock change
  out <- as.POSIXct(as.numeric(x), origin = "1970-01-01", tz = EVENT_TZ)
  attr(out, "gap") <- gap
  out
}
ambiguous_dst <- function(t) {
  # TRUE when the local wall-clock time occurs twice (end of daylight saving time)
  f <- function(x) format(x, "%Y-%m-%d %H:%M", tz = EVENT_TZ)
  !is.na(t) & (f(t + 3600) == f(t) | f(t - 3600) == f(t))
}

n <- nrow(raw)
bt <- parse_local(raw$begin_date, raw$begin_time)
et <- parse_local(raw$end_date, raw$end_time)
gap_b <- attr(bt, "gap"); gap_e <- attr(et, "gap")
notes <- character(n); status <- rep("ok", n)
add_note <- function(i, txt, invalid = FALSE) {
  notes[i] <<- if (nzchar(notes[i])) paste(notes[i], txt, sep = "; ") else txt
  if (invalid) status[i] <<- "invalid"
}
for (i in seq_len(n)) {
  if (is.na(bt[i])) add_note(i, sprintf("cannot parse begin '%s %s' (or the local time does not exist)", raw$begin_date[i], raw$begin_time[i]), TRUE)
  if (is.na(et[i])) add_note(i, sprintf("cannot parse end '%s %s' (or the local time does not exist)", raw$end_date[i], raw$end_time[i]), TRUE)
  if (status[i] == "ok") {
    if (et[i] < bt[i]) add_note(i, "end is before begin", TRUE)
    else if (et[i] == bt[i]) add_note(i, "begin equals end (instantaneous report; window comes from the padding only)")
    if (as.numeric(difftime(et[i], bt[i], units = "days")) > 7) add_note(i, "event longer than 7 days")
    if (as.integer(format(bt[i], "%Y")) < 1980 || bt[i] > Sys.time()) add_note(i, "begin outside 1980..today", TRUE)
    if (isTRUE(gap_b[i]) || isTRUE(gap_e[i]))
      add_note(i, "the written local time does not exist (clock moved forward that morning); read as standard time (UTC-5), which is one hour later on the daylight-saving clock")
    if (ambiguous_dst(bt[i]) || ambiguous_dst(et[i])) add_note(i, "time falls in the repeated hour at the end of daylight saving time (ambiguous)")
  }
}
dup <- duplicated(raw[, need]); for (i in which(dup)) add_note(i, "exact duplicate of an earlier row", TRUE)

ids <- sprintf("EV%03d", seq_len(n))
ok_idx <- which(status == "ok")
ord <- ok_idx[order(bt[ok_idx])]
prev_end <- NULL; prev_id <- NULL
for (i in ord) {
  if (!is.null(prev_end)) {
    if (bt[i] < prev_end) add_note(i, sprintf("overlaps %s", prev_id))
    else if (bt[i] == prev_end) add_note(i, sprintf("starts exactly when %s ends", prev_id))
  }
  if (is.null(prev_end) || et[i] > prev_end) { prev_end <- et[i]; prev_id <- ids[i] }
}

lf <- function(t, fmt) ifelse(is.na(t), "", format(t, fmt, tz = EVENT_TZ))
uf <- function(t) ifelse(is.na(t), "", iso_z(t))
ws <- bt - PAD_BEFORE_H * 3600; we <- et + PAD_AFTER_H * 3600
good <- status == "ok"
idx <- data.frame(
  event_id = ids, begin_local = lf(bt, "%Y-%m-%d %H:%M"), begin_tz = lf(bt, "%Z"),
  end_local = lf(et, "%Y-%m-%d %H:%M"), end_tz = lf(et, "%Z"),
  begin_utc = uf(bt), end_utc = uf(et),
  duration_h = ifelse(good, round(as.numeric(difftime(et, bt, units = "hours")), 3), NA),
  window_start_utc = ifelse(good, uf(ws), ""), window_end_utc = ifelse(good, uf(we), ""),
  window_start_local = ifelse(good, lf(ws, "%Y-%m-%d %H:%M"), ""), window_end_local = ifelse(good, lf(we, "%Y-%m-%d %H:%M"), ""),
  status = status, notes = notes, original_row = seq_len(n) + 1, stringsAsFactors = FALSE)
for (cn in names(raw)) idx[[paste0("orig__", cn)]] <- raw[[cn]]
utils::write.csv(idx, file.path(DIR$interim, "events_index.csv"), row.names = FALSE)
md5 <- unname(tools::md5sum(EVENTS_CSV))
writeLines(md5, file.path(DIR$interim, "events_input_md5.txt"))

nn <- sum(nzchar(notes) & good)
L <- c("# Event CSV validation", "",
       sprintf("- Input file: `%s` (MD5 `%s`, left unchanged)", basename(EVENTS_CSV), md5),
       sprintf("- Rows: %d; valid: %d; invalid: %d", n, sum(good), sum(!good)),
       sprintf("- Columns: %s", paste(names(raw), collapse = ", ")),
       sprintf("- The CSV has no time zone: begin/end are read as %s local time (EST/EDT as in effect on that date) and also stored in UTC.", EVENT_TZ),
       sprintf("- No event ids are supplied: ids EV001, EV002, ... were generated in row order (row 2 of the file = EV001)."),
       sprintf("- Analysis window = begin - %g h to end + %g h (config.R: PAD_BEFORE_H / PAD_AFTER_H).", PAD_BEFORE_H, PAD_AFTER_H),
       sprintf("- Events with a note (still valid): %d", nn), "")
if (sum(!good)) L <- c(L, "## Invalid rows", "", sprintf("- row %d (%s): %s", idx$original_row[!good], ids[!good], notes[!good]), "")
if (nn) L <- c(L, "## Notes on valid rows", "", sprintf("- %s (row %d): %s", ids[good & nzchar(notes)], idx$original_row[good & nzchar(notes)], notes[good & nzchar(notes)]))
write_md(L, file.path(DIR$reports, "events_validation.md"))
cat(sprintf("events: %d rows, %d valid, %d invalid -> data/interim/events_index.csv\n", n, sum(good), sum(!good)))
if (sum(!good)) cat(sprintf("  INVALID row %d: %s\n", idx$original_row[!good], notes[!good]), sep = "")
cat(sprintf("  first event begins %s; last event ends %s (local)\n", min(idx$begin_local[good]), max(idx$end_local[good])))