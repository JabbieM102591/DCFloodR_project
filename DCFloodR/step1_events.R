# Project settings. Edit this file only - every other script reads it.
# All paths are relative to the project folder, so open DCFloodR.Rproj (or setwd() to this folder) first.
# No API keys or passwords are stored anywhere in this project.

# assignment
ASSIGNMENT <- list(version = 4,
                   factor_a = "Daymet gridded precipitation",
                   factor_b = "DC water-level gauges")

# folders and files
DIR <- list(input = "data/input", interim = "data/interim", output = "data/output",
            figures = "figures", reports = "reports")
EVENTS_CSV <- file.path(DIR$input, "DC_flood_times.csv")      # the instructor's file - never modified
H5_PATH    <- file.path(DIR$output, "dc_flood_database.h5")

# events and windows
EVENT_TZ     <- "America/New_York"   # the CSV has no time zone: dates/times are read as DC local time (EST/EDT)
PAD_BEFORE_H <- 24                   # analysis window = event begin - 24 h ...
PAD_AFTER_H  <- 24                   # ... to event end + 24 h

# geography
# Washington, DC extent (west, south, east, north), degrees, EPSG:4326 / NAD83 lon-lat
DC_BBOX <- c(west = -77.12, south = 38.79, east = -76.90, north = 38.996)
RASTER_BUFFER_DEG <- 0.05            # raster subset = DC box + about 5 km on every side (context around the District)

# which parts to run
USE_DAYMET       <- TRUE             # Factor A (assigned): Daymet V4 daily precipitation, 1 km
USE_GAUGES       <- TRUE             # Factor B (assigned): water-level gauges inside DC (USGS + NOAA CO-OPS)
USE_IN_DC_PRECIP <- TRUE             # independent search for rain stations inside DC (graded separately)
USE_NASA_SEARCH  <- TRUE             # extra credit

# Daymet
# ORNL moved Daymet to NASA Earthdata Cloud; the file is subset with OPeNDAP (DAP4) and needs a free Earthdata login
DAYMET_OPENDAP <- "https://opendap.earthdata.nasa.gov/collections/C2532426483-ORNL_CLOUD/granules/Daymet_Daily_V4R1.daymet_v4_daily_na_prcp_%d.nc"

# water-level gauges
# USGS parameter codes treated as "water level": gage height (ft) and elevation-type water levels
USGS_LEVEL_PARAMS <- c("00065" = "gage_height", "62620" = "water_surface_elevation_navd88",
                       "63160" = "stream_water_level_navd88")
INCLUDE_DISCHARGE <- FALSE           # TRUE also downloads streamflow (00060) at the same gauges
# Candidate gauge ids (checked against their coordinates; only gauges inside the DC outline are used).
# The discovery step also searches the USGS site catalogue, so this list is only a safety net.
USGS_SEED_SITES <- c("01646580", "01648000", "01651800", "01646500", "01648010")
USGS_BACKEND    <- "auto"            # "auto" = new USGS Water Data API first, old waterservices as fallback
OGC_BASE        <- "https://api.waterdata.usgs.gov/ogcapi/v0"
# NOAA CO-OPS tide/water-level stations inside DC are discovered automatically; this id is the fallback
COOPS_SEED_STATIONS <- c("8594900")  # Washington, DC (Potomac River)
COOPS_DATUM <- "MLLW"                # falls back to station datum STND if MLLW is not offered

# independent in-DC rain station search
IN_DC_MAX_STATIONS <- 12
GHCND_STATIONS_URL  <- "https://www.ncei.noaa.gov/pub/data/ghcn/daily/ghcnd-stations.txt"
GHCND_INVENTORY_URL <- "https://www.ncei.noaa.gov/pub/data/ghcn/daily/ghcnd-inventory.txt"

# NASA extra credit (public CMR search)
NASA_COLLECTIONS <- c("OPERA_L3_DSWX-HLS_V1", "OPERA_L3_DSWX-S1_V1")
NASA_DAYS_AFTER  <- 14
NASA_DAYS_BEFORE <- 1

# source descriptions written into the HDF5 file
SOURCE_INFO <- list(
  daymet_prcp_1km = list(kind = "raster",
                         title = "Daymet V4 daily precipitation, 1 km (prcp)",
                         url = "https://opendap.earthdata.nasa.gov/collections/C2532426483-ORNL_CLOUD/granules/Daymet_Daily_V4R1.daymet_v4_daily_na_prcp_YYYY.nc",
                         reference = "Thornton et al., ORNL DAAC, https://doi.org/10.3334/ORNLDAAC/2129",
                         support = "grid cell (1 km x 1 km, Lambert Conformal Conic)",
                         temporal = "daily total; time stamp 12:00 UTC; 365-day (no-leap) calendar - 31 December is dropped in leap years",
                         units = "mm/day",
                         spatial_resolution = "1 km; native Lambert Conformal Conic grid, not resampled",
                         crs = "Daymet LCC (parameters in attribute crs_variable); lon/lat of cell centres stored as 2-D arrays",
                         missing = "NaN = no data; a whole missing day has slice_has_data = 0 and a status text; 0 = real zero rain",
                         processing = "NASA Earthdata OPeNDAP (DAP4) request for the DC window only: rectangle of native grid cells covering DC plus buffer, no resampling, no reprojection"),
  usgs_iv = list(kind = "timeseries",
                 title = "USGS instantaneous water level (continuous, about 15 min)",
                 url = "https://api.waterdata.usgs.gov/ogcapi/v0/collections/continuous (fallback: https://waterservices.usgs.gov/nwis/iv/)",
                 reference = "U.S. Geological Survey National Water Information System / Water Data APIs",
                 support = "point (water-level gauge)",
                 temporal = "instantaneous reading at the time stamp (UTC stored; original stamp kept)",
                 units = "see each variable (ft)",
                 spatial_resolution = "point", crs = "EPSG:4326 lon/lat of the gauge",
                 missing = "value NaN = USGS no-data value or non-numeric reading; row absent = no record; gauge height 0 is a real value",
                 processing = "units kept as published by USGS (no conversion); time stamps converted to UTC; no aggregation"),
  usgs_dv = list(kind = "timeseries",
                 title = "USGS daily values (daily mean water level)",
                 url = "https://api.waterdata.usgs.gov/ogcapi/v0/collections/daily (fallback: https://waterservices.usgs.gov/nwis/dv/)",
                 reference = "U.S. Geological Survey National Water Information System / Water Data APIs",
                 support = "point (water-level gauge)",
                 temporal = "daily mean for the local calendar day of the site; time_utc = end of that local day",
                 units = "see each variable (ft)",
                 spatial_resolution = "point", crs = "EPSG:4326 lon/lat of the gauge",
                 missing = "value NaN = no-data value; row absent = no daily value computed",
                 processing = "units kept as published; no aggregation by this project"),
  noaa_coops = list(kind = "timeseries",
                    title = "NOAA CO-OPS water level (6-minute; hourly height for older dates)",
                    url = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter",
                    reference = "NOAA Center for Operational Oceanographic Products and Services (CO-OPS)",
                    support = "point (tide/water-level gauge)",
                    temporal = "6-minute (or hourly) water level at the UTC time stamp (time_zone=gmt requested)",
                    units = "m (relative to the datum named in the attributes)",
                    spatial_resolution = "point", crs = "EPSG:4326 lon/lat of the station",
                    missing = "value NaN = missing or flagged value; row absent = no record",
                    processing = "metric units, UTC time stamps; datum recorded in the attributes; quality flags kept in quality"),
  ghcnd_dc = list(kind = "timeseries",
                  title = "NOAA GHCN-Daily precipitation at stations located inside Washington, DC",
                  url = "https://www.ncei.noaa.gov/pub/data/ghcn/daily/all/<station>.dly (fallback: https://www.ncei.noaa.gov/access/services/data/v1?dataset=daily-summaries)",
                  reference = "NOAA NCEI GHCN-Daily (station list: ghcnd-stations.txt, ghcnd-inventory.txt)",
                  support = "point (volunteer or cooperative rain gauges)",
                  temporal = "daily total; time_utc = end of the 24 h interval (observation time read as local standard time, UTC-5)",
                  units = "mm",
                  spatial_resolution = "point", crs = "EPSG:4326 lon/lat of the station",
                  missing = "value NaN = missing or removed by a quality flag (flag kept in quality); row absent = no record; 0 = reported zero",
                  processing = "station history files; PRCP converted from tenths of mm to mm; only days inside the event windows kept; no aggregation"),
  usgs_dc_precip = list(kind = "timeseries",
                        title = "USGS precipitation gauges (parameter 00045) located inside Washington, DC",
                        url = "https://api.waterdata.usgs.gov/ogcapi/v0/collections/continuous (fallback: https://waterservices.usgs.gov/nwis/iv/)",
                        reference = "U.S. Geological Survey National Water Information System / Water Data APIs",
                        support = "point (rain gauge)",
                        temporal = "precipitation total over the reporting interval; see period_hours; UTC stored, original stamp kept",
                        units = "in (as published by USGS)",
                        spatial_resolution = "point", crs = "EPSG:4326 lon/lat of the gauge",
                        missing = "value NaN = no-data or non-numeric; row absent = no record; 0 = reported zero",
                        processing = "units kept as published; no aggregation")
)