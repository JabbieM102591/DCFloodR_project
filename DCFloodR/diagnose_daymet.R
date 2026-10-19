# Daymet access check: one script that tests every way of reaching Daymet and prints what happens.
# Run in the RStudio Console from the project folder:
#   Sys.setenv(EARTHDATA_USER = "my_username", EARTHDATA_PASS = "my_password")
#   source("diagnose_daymet.R")
# The password is only read from the environment and is never printed.
source("R/setup.R")

u <- Sys.getenv("EARTHDATA_USER"); p <- Sys.getenv("EARTHDATA_PASS")
if (!nzchar(u) || !nzchar(p)) stop("Set EARTHDATA_USER and EARTHDATA_PASS first (see the top of this file).", call. = FALSE)
bbox <- c(west = -77.2, south = 38.7, east = -76.8, north = 39.0)
peek <- function(r, n = 300) substr(gsub("\\s+", " ", gsub("<[^>]+>", " ", rawToChar(r$content[seq_len(min(n, length(r$content)))]))), 1, n)
run <- function(label, expr) {
  cat("\n", label, "\n", sep = "")
  tryCatch(expr, error = function(e) cat("  error:", conditionMessage(e), "\n"))
}

run("1. Earthdata login (is the username and password accepted?)", {
  r <- httr::GET("https://urs.earthdata.nasa.gov/api/users/tokens", httr::authenticate(u, p, "basic"), httr::timeout(60))
  cat("  HTTP", httr::status_code(r), "(200 means the login is valid)\n")
})

run("2. Old THREDDS subset address (expected to redirect or fail; kept to show what ORNL does now)", {
  old <- "https://thredds.daac.ornl.gov/thredds/ncss/ornldaac/2129/daymet_v4_daily_na_prcp_2000.nc"
  r <- httr::GET(old, query = list(var = "prcp", north = bbox[["north"]], south = bbox[["south"]], west = bbox[["west"]], east = bbox[["east"]],
                                   time_start = "2000-01-01T12:00:00Z", time_end = "2000-01-01T12:00:00Z", accept = "netcdf"),
                 httr::timeout(60), httr::user_agent(UA), httr::config(followlocation = FALSE))
  cat("  HTTP", httr::status_code(r), "\n  redirect location:", httr::headers(r)[["location"]] %||% "(none)", "\n")
})

run("3. NASA OPeNDAP file description (.dmr), with login", {
  url <- paste0(sprintf(DAYMET_OPENDAP, 2000), ".dmr")
  r <- http_get(url, auth = list(u, p), timeout = 120)
  cat("  HTTP", r$status, "\n  final url:", r$url, "\n  preview:", peek(r, 200), "\n")
})

run("4. The real request used by step 3 (one day, DC window)", {
  r <- fetch_daymet_run(2000, "2000-01-01", "2000-01-01", bbox)
  ok <- r$status == 200 && length(r$content) > 8 && r$content[1] == as.raw(0x89)
  cat("  HTTP", r$status, "| bytes", length(r$content), "| NetCDF-4 file:", ok, "\n")
  if (!ok) cat("  message:", peek(r, 300), "\n")
})

run("5. Daymet single-pixel service (public, one point only; backup option)", {
  r <- httr::GET("https://daymet.ornl.gov/single-pixel/api/data", query = list(lat = 38.9, lon = -77.0, vars = "prcp", start = "2000-01-01", end = "2000-01-03", format = "csv"),
                 httr::timeout(60), httr::user_agent(UA))
  cat("  HTTP", httr::status_code(r), "\n")
  if (httr::status_code(r) == 200) cat(substr(rawToChar(httr::content(r, "raw")), 1, 400), "\n")
})

run("6. Does a .netrc file exist? (not needed: this project uses environment variables)", {
  cat("  _netrc:", file.exists(file.path(path.expand("~"), "_netrc")), "| .netrc:", file.exists(file.path(path.expand("~"), ".netrc")), "\n")
})
cat("\nDone. Paste everything above, without the line where you typed your password.\n")