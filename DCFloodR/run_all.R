# run_all.R - run the whole pipeline in order.   RStudio Console:  source("run_all.R")
steps <- c("step1_events.R", "step2_boundary.R", "step3_daymet.R", "step4_gauges.R",
           "step5_in_dc_precip.R", "step6_nasa.R", "step7_build_h5.R", "step8_demo.R")
for (s in steps) {
  cat("\nRunning", s, "\n")
  ok <- tryCatch({ source(s, local = new.env()); TRUE },
                 error = function(e) { message("STEP FAILED: ", conditionMessage(e)); FALSE })
  if (!ok) stop(s, " failed - read the message above, fix it, and run again (finished steps are cached).", call. = FALSE)
}
cat("\nAll steps finished. Open reports/availability_report.md and the figures/ folder.\n")
