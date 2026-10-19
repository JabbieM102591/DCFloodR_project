# DC Flood Events: One Reproducible HDF5 Database

**Course:** STAT 6289  
**Project:** Individual Project - Assignment Version 4  
**Factor A:** Daymet Gridded Precipitation  
**Factor B:** Water-Level Gauges Inside Washington, DC (GW ID 41452795)

## Project Overview

For this project, I developed an R workflow to study the 125 flood events provided by my instructor, covering 1996–2025. The original event file, `data/input/DC_flood_times.csv`, was not modified.

I retrieved Daymet precipitation data and available water-level gauge observations for each event. I organized the data into a single HDF5 database and developed reusable R functions to read, summarize, and plot the results.

The project uses R and publicly available data sources and APIs.

## 1. How to Run the Project

I developed and tested the workflow using R 4.6.1 on Windows with RStudio. R 4.1 or later may work, depending on package and API compatibility.

**Setup**

1. Clone the repository and open `DCFloodR.Rproj` in RStudio.
2. Create a NASA Earthdata account at https://urs.earthdata.nasa.gov/ and authorize the required ORNL DAAC application for Daymet access.
3. Set your Earthdata credentials in the RStudio Console:

   ```r
   Sys.setenv(
     EARTHDATA_USER = "my_username",
     EARTHDATA_PASS = "my_password"
   )
   ```

   Replace the example values with your credentials. Do not save passwords in project files or commit them to the repository.

4. Install the required packages and run the workflow:

   ```r
   source("install_packages.R")
   source("run_all.R")
   ```

I can also run the scripts individually, from `step1_events.R` through `step8_demo.R`. Downloads are cached in `data/interim/` and reused on subsequent runs. Project settings are defined in `config.R`.

If needed, a USGS API key can be supplied through the `USGS_API_KEY` environment variable.

## 2. Repository Structure

- `config.R` - Project settings and data-source descriptions.
- `R/utils.R` - Utility functions, logging, and time helpers.
- `R/fetchers.R` - Data retrieval and parsing functions.
- `R/setup.R` — Project setup functions.
- `step1_events.R` - Validates events and creates analysis windows.
- `step2_boundary.R` - Retrieves the DC boundary for mapping and spatial checks.
- `step3_daymet.R` - Retrieves and processes Daymet precipitation data.
- `step4_gauges.R` - Retrieves USGS and NOAA CO-OPS gauge observations.
- `step5_in_dc_precip.R` - Searches for precipitation stations inside DC.
- `step6_nasa.R` — Searches for NASA OPERA surface-water scenes.
- `step7_build_h5.R` - Builds the HDF5 database.
- `dcflood_h5.R` - Provides functions for reading, summarizing, and plotting database contents.
- `step8_demo.R` - Demonstrates the database functions and generates reports.
- `data/input/` - Original input data.
- `data/interim/` - Cached downloads and intermediate data.
- `data/output/` - Final HDF5 database.
- `reports/` - Validation reports, search results, and availability tables.
- `figures/` - Maps, time-series plots, and coverage heat maps.

## 3. Data Sources

- **Daymet:** ORNL DAAC Daymet Daily V4 R1, DOI: https://doi.org/10.3334/ORNLDAAC/2129. Daily precipitation at approximately 1 km resolution, accessed through NASA Earthdata OPeNDAP. Units: mm/day.
- **USGS:** Water Data OGC API, with the legacy Water Services API as a fallback. Gage height and related observations are stored separately from streamflow.
- **NOAA CO-OPS:** Water-level observations from station `8594900`, using six-minute measurements where available and hourly data as a fallback.
- **NOAA GHCN-Daily and USGS precipitation:** Used to search independently for precipitation observations at stations inside DC, including USGS parameter `00045`.
- **DC boundary:** OpenStreetMap Nominatim-derived geographic information used for mapping and spatial checks.
- **NASA OPERA:** NASA Common Metadata Repository (CMR), used to search for OPERA Level-3 Dynamic Surface Water Extent (`OPERA_L3_DSWX`) scenes. I searched scene metadata but did not download or analyse imagery.

## 4. Methods and Data Conventions

### Event times

The original event file does not specify a time zone. I interpreted event times as Washington, DC, local time (EST/EDT) and stored corresponding UTC timestamps.

Each analysis window extends from 24 hours before an event begins to 24 hours after it ends. Overlapping events remain separate records.

EV031, dated April 3, 2005, at 02:10, falls within the hour skipped when daylight saving time began. I interpreted it as standard time (03:10 on the daylight-saving clock) and documented this decision in `reports/events_validation.md`.

The instructor's list contains no events in 2000 or 2002. I retained the original event list without adding events for those years.

### Daymet precipitation

I retained the native Daymet grid without resampling. The extracted area covers DC with a 0.05-degree margin and contains 40 × 36 grid cells.

Each daily layer is timestamped at 12:00 UTC and represents a UTC day. Daymet uses a 365-day calendar, so December 31 is unavailable in leap years. I recorded these dates as missing, together with the reason.

### Gauge observations

I checked gauge coordinates against the DC boundary and retained the units, timestamps, sampling intervals, and available quality information for each series.

Gage height, tidal water level, and streamflow are treated as separate variables.

### Missing values and coverage

I never replaced missing observations with zero. For each event window and series, the database records expected, valid, zero, flagged, and missing observation counts, along with the longest gap.

Daymet and GHCN-Daily provide daily precipitation totals, while gauge observations are instantaneous or interval-based. Each source retains its own time axis, and incompatible time resolutions are not silently combined.

## 5. HDF5 Database

**File:** `data/output/dc_flood_database.h5`  
**Approximate size:** 64 MB in my reported run.

The database contains the following groups:

```text
/events
/rasters/daymet_prcp_1km
/timeseries/<source>/<station>__<variable>
/context/dc_boundary
/nasa/granules
/metadata
```

The groups store event information, precipitation arrays, gauge time series, DC boundary geometry, NASA scene metadata, and database metadata.

I used chunked datasets and gzip level 4 compression. The relevant groups and datasets include attributes describing units, data sources, time conventions, and missing-value rules.

The database can also be opened in Python using the `h5py` package.

## 6. Reading and Plotting the Database

Load the database functions and specify the file path:

```r
source("dcflood_h5.R")

h5 <- "data/output/dc_flood_database.h5"

list_events(h5)
list_sources(h5)
list_stations(h5)
list_variables(h5)
date_ranges(h5)
describe(h5)
```

To retrieve and plot Daymet precipitation for EV125:

```r
get_raster(
  h5,
  "EV125",
  "daymet_prcp_1km",
  "2025-07-19"
)

plot_raster(
  h5,
  "EV125",
  "daymet_prcp_1km",
  "2025-07-19"
)
```

To plot water-level and gauge-height observations:

```r
plot_timeseries(
  h5,
  "noaa_coops",
  "8594900",
  "water_level_6min",
  event_id = "EV125"
)

plot_timeseries(
  h5,
  "usgs_iv",
  "01648000",
  "gage_height",
  event_id = "EV125"
)
```

To summarize and visualize data coverage:

```r
coverage_summary(h5, event_id = "EV125")
plot_coverage_heatmap(h5)
```

The demonstration script, `step8_demo.R`, uses EV125, which occurred on July 19, 2025, from 17:00 to 18:34 local time. This event had the most valid observations in my reported run.

## 7. Results and Limitations

The following counts are from my project run. Detailed results are available in `reports/availability_report.md` and `reports/coverage_summary.csv`.

- **Flood events:** All 125 events passed validation.
- **Daymet:** All 375 required daily layers were retrieved, covering all 125 events.
- **NOAA CO-OPS:** I stored 60,329 six-minute records from station `8594900`, spanning 1996–2025.
- **USGS:** I identified 171 candidate sites, of which 116 were inside DC. I stored 380,238 instantaneous records, including gage height at 10 stations and NAVD88 water level at 7 stations. Daily-value requests returned no records.
- **NASA OPERA:** I found 441 scene records. No scenes were available before 2023 in my search results.

### Limitations

- USGS instantaneous observations in my dataset generally begin around 2007–2008. Older events therefore have limited USGS gauge coverage and rely on other available sources, including the NOAA tide gauge.
- Daymet provides daily precipitation totals at approximately 1 km resolution. It cannot resolve rainfall timing during a flood lasting only one or two hours. Gauge observations provide finer temporal detail but represent individual locations.
- For EV125, the in-DC precipitation gauges recorded approximately 0–0.3 mm on July 19, while Daymet showed values reaching approximately 75 mm within the DC grid window. These measurements represent different spatial and temporal scales and should not be treated as directly interchangeable. A zero reading at one gauge does not prove that no rainfall occurred nearby.

## 8. Independent Precipitation Search Inside DC

I documented the search results in `reports/in_dc_search.md`.

The search identified 12 GHCN-Daily stations inside DC, 11 of which had data within the event windows. Two are cooperative stations (`USC00182325` and `USC00186350`) with records dating to 1996. The remaining stations are volunteer CoCoRaHS gauges whose records begin between 2008 and 2023.

I did not identify any USGS precipitation sites inside DC. Because the NOAA NCEI Daily Summaries service returned errors during my run, I used the full-history station files instead.

I did not query DC Water rain gauges, Weather Underground personal stations, MADIS, or Synoptic because of access, licensing, or token requirements. I excluded Washington National Airport (DCA), Dulles (IAD), and Baltimore/Washington International (BWI) from the in-DC station count because they are outside the District.

## 9. Extra Credit: NASA OPERA Search

I documented the NASA search results in `reports/nasa_search.md` and `data/interim/nasa_granules.csv`.

The search identified 441 OPERA surface-water scene records near the flood events. No scenes were available before 2023 in my retrieved results. The absence of a scene does not necessarily mean that flooding did not occur.

I searched for scene metadata only; I did not download or analyse the imagery.

## 10. AI-Use Acknowledgment

I used Claude solely to help debug my R code. I completed the rest of the project myself, including project planning, data retrieval, processing, analysis, interpretation of results, and preparation of this README. I ran the code on my own computer, checked the outputs against the data, and take full responsibility for the work I am submitting.
