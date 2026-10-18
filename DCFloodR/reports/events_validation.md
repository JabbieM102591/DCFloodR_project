# Event CSV validation

- Input file: `DC_flood_times.csv` (MD5 `5c67161242bc404198356028c78f3a27`, left unchanged)
- Rows: 125; valid: 125; invalid: 0
- Columns: begin_date, begin_time, end_date, end_time
- The CSV has no time zone: begin/end are read as America/New_York local time (EST/EDT as in effect on that date) and also stored in UTC.
- No event ids are supplied: ids EV001, EV002, ... were generated in row order (row 2 of the file = EV001).
- Analysis window = begin - 24 h to end + 24 h (config.R: PAD_BEFORE_H / PAD_AFTER_H).
- Events with a note (still valid): 5

## Notes on valid rows

- EV031 (row 32): the written local time does not exist (clock moved forward that morning); read as standard time (UTC-5), which is one hour later on the daylight-saving clock
- EV072 (row 73): starts exactly when EV071 ends
- EV075 (row 76): overlaps EV074
- EV094 (row 95): begin equals end (instantaneous report; window comes from the padding only)
- EV112 (row 113): overlaps EV111
