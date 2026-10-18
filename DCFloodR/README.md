# DC flood events: one reproducible HDF5 database

STAT 6289, individual project, assignment version 4. Factor A is Daymet gridded precipitation and Factor B is water-level gauges inside DC (GW ID 41452795).

I read the instructor's list of 125 flood events (`data/input/DC_flood_times.csv`, 1996 to 2025, never modified). For every event I download Daymet precipitation rasters and gauge records for a window around the event, store everything in one HDF5 file, and provide R functions that read and plot straight from that file. Everything is written in R and uses public APIs only.

## 1. How to reproduce

I used R 4.6.1 on Windows with RStudio. R 4.1 or newer should work.

1. Clone this repository and open `DCFloodR.Rproj` in RStudio. This sets the working directory to the project folder.
2. Daymet is now served by NASA Earthdata, so a free Earthdata account is needed (https://urs.earthdata.nasa.gov). Approve the ORNL DAAC application once under Applications, Authorized Apps. The login is never written to a file; I type it into the Console each session:
```r
Sys.setenv(EARTHDATA_USER = "my_username", EARTHDATA_PASS = "my_password")
```
3. Install packages once and run the steps:
```r
source("install_packages.R")   # httr, jsonlite, ncdf4, hdf5r, ggplot2
source("run_all.R")            # steps 1 to 8 in order
```
The steps can also be run one at a time, `source("step1_events.R")` through `source("step8_demo.R")`. Downloads are cached in `data/interim/`, so a repeat run only fetches what is missing. Settings (window length, bounding box, station limits) are in `config.R`. A USGS API key is optional; if I use one it goes in the environment variable `USGS_API_KEY`, never in a file. Most of the run time is waiting for the servers.

## 2. Files

| file | purpose |
|---|---|
| `config.R` | all settings and the source descriptions written into the HDF5 file |
| `R/utils.R`, `R/fetchers.R`, `R/setup.R` | HTTP with retries, request log, time helpers, download and parse functions |
| `step1_events.R` | validate the event CSV, give each event an id, build analysis windows |
| `step2_boundary.R` | DC outline (OpenStreetMap Nominatim) for maps and the inside-DC test |
| `step3_daymet.R` | Daymet V4R1 daily precipitation, 1 km, cut to DC through NASA Earthdata OPeNDAP |
| `step4_gauges.R` | water-level gauges inside DC: USGS (Water Data OGC API, legacy service as fallback) and NOAA CO-OPS |
| `step5_in_dc_precip.R` | independent search for rain stations physically inside DC (GHCN-Daily, USGS) |
| `step6_nasa.R` | extra credit: NASA OPERA surface-water scene search through CMR |
| `step7_build_h5.R` | build `data/output/dc_flood_database.h5` and the availability tables |
| `dcflood_h5.R` | reusable functions that read and plot from the HDF5 file |
| `step8_demo.R` | demonstration on one event, figures, `reports/availability_report.md` |
| `reports/` | validation, gauge search, in-DC search, NASA search, availability report, CSV tables |
| `figures/` | maps, time series and the coverage heat map |

## 3. Data sources

| data | source | notes |
|---|---|---|
| Daymet daily precipitation | ORNL DAAC Daymet Daily V4R1, doi:10.3334/ORNLDAAC/2129, read through NASA Earthdata OPeNDAP (collection C2532426483-ORNL_CLOUD) | 1 km, Lambert Conformal Conic, mm/day |
| USGS water level | USGS Water Data OGC API (`/collections/continuous`, `/daily`); fallback `waterservices.usgs.gov` | gage height and related water-level variables in ft, kept separate from streamflow |
| NOAA tide gauge | CO-OPS Data API, station 8594900 (Washington, DC) | 6-minute water level in metres; hourly fallback |
| Stations inside DC | NOAA GHCN-Daily (station list, inventory, station history files), USGS parameter 00045 | point-in-polygon test against the DC outline |
| DC outline | OpenStreetMap Nominatim (retrieval date stored in the file) | context layer only |
| NASA (extra credit) | NASA CMR granule search, OPERA_L3_DSWX-HLS_V1 and _S1_V1 | search only; imagery needs an Earthdata login |

## 4. Method and conventions

* **Event times.** The CSV has no time zone, so begin and end are read as Washington local time (America/New_York, EST or EDT as in effect on that date) and also stored in UTC. Each event gets an analysis window from 24 h before its begin to 24 h after its end. Overlapping events stay as separate rows and are noted. One event (EV031, written as 2005-04-03 02:10) falls in the hour that does not exist when clocks move forward; I read it as standard time, which is 03:10 on the daylight clock, and it is flagged in `reports/events_validation.md`. The CSV has no events in 2000 or 2002; that is how the instructor's list is, not a download problem.
* **Daymet.** The native 1 km grid is kept, with no resampling or reprojection. I take the rectangle of grid cells (in the Daymet projection) that covers the DC bounding box plus 0.05 degrees, which gives a 40 by 36 cell window. Each day is stamped 12:00 UTC and covers the UTC day, read from `time_bnds`. Daymet uses a 365-day calendar, so 31 December does not exist in leap years; such days are stored as missing with a reason. Units are mm/day. NaN means no data, never zero. A raster slice is selected by its UTC date label.
* **Gauges.** Coordinates are checked against the DC outline. Units, time stamps (kept as published and also converted to UTC), sampling interval and quality codes are stored with each series. Gage height, tide-gauge water level and streamflow are separate variables. USGS instantaneous data exist only from about 2007 onward, so older events can only have daily values.
* **Missing versus zero.** A missing record is never turned into 0. For every event window and series the availability table records expected, valid, zero, flagged and missing counts and the longest gap.
* **Temporal compatibility.** Daily Daymet and GHCN values are 24 h accumulations (UTC day for Daymet, local day for GHCN-Daily), while gauge values are instants or short intervals. They are kept on their own native time axes and never merged silently.

## 5. HDF5 layout (`data/output/dc_flood_database.h5`)

```
/events                              one dataset per column: ids, local and UTC begin/end, windows, status, original CSV fields
/rasters/daymet_prcp_1km/            precip[time,y,x] (float32, gzip), lon[y,x], lat[y,x], x_proj_m, y_proj_m,
                                     date_utc, valid_start_utc, valid_end_utc, slice_status, slice_has_data, source_file
/timeseries/<source>/<station>__<variable>/   time_utc (epoch seconds), value, period_hours, quality, original_timestamp
/context/dc_boundary                 DC outline
/nasa/granules                       NASA scenes found (metadata only)
/metadata/{sources, series, availability, retrieval_log, processing_notes}
```
Compression is gzip level 4 with chunking. Every group and dataset carries attributes (units, source URL, time convention, missing-value rule). The file is about 64 MB. It can also be opened from Python with `h5py.File("data/output/dc_flood_database.h5")` or in any HDF5 viewer.

## 6. Reading the database

```r
source("dcflood_h5.R"); h5 <- "data/output/dc_flood_database.h5"
list_events(h5); list_sources(h5); list_stations(h5); list_variables(h5); date_ranges(h5); describe(h5)
r  <- get_raster(h5, "EV125", "daymet_prcp_1km", "2025-07-19")     # matrix, lon/lat, units, valid interval
plot_raster(h5, "EV125", "daymet_prcp_1km", "2025-07-19")
ts <- get_timeseries(h5, "noaa_coops", "8594900", "water_level_6min", event_id = "EV125")
plot_timeseries(h5, "noaa_coops", "8594900", "water_level_6min", event_id = "EV125")
plot_timeseries(h5, "usgs_iv", "01648000", "gage_height", event_id = "EV125")
coverage_summary(h5, event_id = "EV125"); plot_coverage_heatmap(h5)
```
`step8_demo.R` runs this on EV125 (2025-07-19, 17:00 to 18:34 local), the event with the most valid observations, and writes the figures to `figures/`.

## 7. What was retrieved and what is missing

All counts below are from my run; the full tables are in `reports/availability_report.md` and `reports/coverage_summary.csv`.

| source | what I got |
|---|---|
| Daymet 1 km precipitation | 375 of 375 needed days, so all 125 events are covered; 40 by 36 cells |
| NOAA CO-OPS 8594900 | 60,329 six-minute water-level records, from 1996 to 2025 |
| USGS instantaneous gage height | 01648000 (17,111 records, from 2008) and 01647600 (39,593 records, from 2010); 116 USGS sites were found inside DC, but only these two returned usable records in the event windows |
| USGS daily values | 0 records returned |

Limits I want to be clear about:
* USGS instantaneous data before about 2007 do not exist, so older events have no USGS gauge data, only the NOAA tide gauge.
* Daymet is a daily total per 1 km cell, so it cannot resolve the timing of a flood that lasted an hour or two; the gauges can, but they are single points.
* In EV125 the in-DC rain gauges recorded 0 to 0.3 mm for 19 July while Daymet shows up to about 75 mm in the DC window. Gauge and grid values are not interchangeable, and a missing or zero gauge value does not prove it did not rain nearby.
* The USGS daily-values requests returned nothing, so the USGS part of the database is the instantaneous series only.

## 8. Independent in-DC precipitation search

`reports/in_dc_search.md` lists the stations I found inside the DC outline and what I could retrieve. I searched GHCN-Daily and USGS precipitation parameter 00045. GHCN-Daily had 12 stations inside DC; 11 have data in the event windows. Two are cooperative stations (USC00182325 and USC00186350, records from 1996); the rest are volunteer CoCoRaHS gauges (US1DCDC00xx) that only start between 2008 and 2023. No USGS precipitation site inside DC was found. Daily values were taken from each station's full history file because the NCEI daily-summaries service returned errors during my run.

Sources I did not query (licence terms or access tokens needed), listed so the search is documented: DC Water rain gauges, Weather Underground personal stations, MADIS and Synoptic. The airports (DCA, IAD, BWI) are outside the District and are not counted.

## 9. Extra credit (NASA)

`reports/nasa_search.md` and `data/interim/nasa_granules.csv` list OPERA surface-water (DSWx) scenes near each event; 441 scenes were found in my search. OPERA only exists from 2023 onward, so older events have none, and no scene for an event does not mean there was no flooding. I did not download or plot the imagery.

## 10. AI-use acknowledgment

I used Claude (Anthropic) as an assistant for planning the project, writing and debugging the R code, and drafting this README. I ran every step myself on my own computer, checked the outputs against the data, and I am responsible for the work I am submitting.