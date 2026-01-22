## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)

## ----extract-data-------------------------------------------------------------
# library(vald.extractor)
# 
# # Set credentials
# valdr::set_credentials(
#   client_id     = "your_client_id",
#   client_secret = "your_client_secret",
#   tenant_id     = "your_tenant_id",
#   region        = "aue"
# )
# 
# # Fetch data from 2020 onwards in chunks of 100 tests
# vald_data <- fetch_vald_batch(
#   start_date = "2020-01-01T00:00:00Z",
#   chunk_size = 100,
#   verbose = TRUE
# )
# 
# # Extract components
# tests_df <- vald_data$tests
# trials_df <- vald_data$trials
# 
# cat("Extracted", nrow(tests_df), "tests and", nrow(trials_df), "trials\n")

## ----fetch-metadata-----------------------------------------------------------
# # Fetch raw metadata
# metadata <- fetch_vald_metadata(
#   client_id     = "your_client_id",
#   client_secret = "your_client_secret",
#   tenant_id     = "your_tenant_id",
#   region        = "aue"
# )
# 
# # Standardize: unnest group memberships and create unified athlete records
# athlete_metadata <- standardize_vald_metadata(
#   profiles = metadata$profiles,
#   groups   = metadata$groups
# )
# 
# head(athlete_metadata)

## ----classify-sports----------------------------------------------------------
# athlete_metadata <- classify_sports(
#   data = athlete_metadata,
#   group_col = "all_group_names",
#   output_col = "sports_clean"
# )
# 
# # Inspect the mapping
# table(athlete_metadata$sports_clean)

## ----transform-wide-----------------------------------------------------------
# library(dplyr)
# 
# # Join trials and tests
# all_data <- left_join(trials_df, tests_df, by = c("testId", "athleteId"))
# 
# # Aggregate trials and pivot to wide format
# structured_test_data <- all_data %>%
#   group_by(athleteId, testId, testType, recordedUTC,
#            recordedDateOffset, trialLimb, definition_name) %>%
#   summarise(
#     mean_result = mean(as.numeric(value), na.rm = TRUE),
#     mean_weight = mean(as.numeric(weight), na.rm = TRUE),
#     .groups = "drop"
#   ) %>%
#   mutate(
#     TestTimestampUTC = lubridate::ymd_hms(recordedUTC),
#     TestTimestampLocal = TestTimestampUTC + lubridate::minutes(recordedDateOffset),
#     Testdate = as.Date(TestTimestampLocal)
#   ) %>%
#   select(athleteId, Testdate, testId, testType, trialLimb,
#          definition_name, mean_result, mean_weight) %>%
#   tidyr::pivot_wider(
#     id_cols = c(athleteId, Testdate, testId, mean_weight),
#     names_from = c(definition_name, trialLimb, testType),
#     values_from = mean_result,
#     names_glue = "{definition_name}_{trialLimb}_{testType}"
#   ) %>%
#   rename(Weight_on_Test_Day = mean_weight)
# 
# # Join with metadata
# final_analysis_data <- structured_test_data %>%
#   mutate(profileId = as.character(athleteId)) %>%
#   left_join(
#     athlete_metadata %>% mutate(profileId = as.character(profileId)),
#     by = "profileId"
#   ) %>%
#   mutate(
#     Testdate = as.Date(Testdate),
#     dateofbirth = as.Date(dateOfBirth),
#     age = as.numeric((Testdate - dateofbirth) / 365.25),
#     sports = sports_clean
#   )
# 
# cat("Final dataset:", nrow(final_analysis_data), "rows with",
#     ncol(final_analysis_data), "columns\n")

## ----split-tests--------------------------------------------------------------
# # Split into separate datasets per test type
# test_datasets <- split_by_test(
#   data = final_analysis_data,
#   metadata_cols = c("profileId", "sex", "Testdate", "dateofbirth",
#                     "age", "testId", "Weight_on_Test_Day", "sports")
# )
# 
# # Access individual test types
# cmj_data <- test_datasets$CMJ
# dj_data <- test_datasets$DJ
# 
# # Crucially: column names are now generic
# head(names(cmj_data))
# # "profileId", "sex", "Testdate", "PEAK_FORCE_Both", "JUMP_HEIGHT_Both", ...
# # Note: "_CMJ" suffix has been removed!

## ----generic-analysis---------------------------------------------------------
# analyze_peak_force <- function(test_data) {
#   summary(test_data$PEAK_FORCE_Both)  # Works for CMJ, DJ, ISO, etc.
# }
# 
# # Apply to all test types
# lapply(test_datasets, analyze_peak_force)

## ----patch-metadata-----------------------------------------------------------
# # Create an Excel file with: profileId, sex, dateOfBirth
# # Example: corrections.xlsx with rows like:
# #   profileId         sex       dateOfBirth
# #   abc123           Male      1995-03-15
# #   def456           Female    1998-07-22
# 
# cmj_data <- patch_metadata(
#   data = cmj_data,
#   patch_file = "corrections.xlsx",
#   patch_sheet = 1,
#   id_col = "profileId",
#   fields_to_patch = c("sex", "dateOfBirth")
# )
# 
# # Verify corrections
# table(cmj_data$sex)  # "Unknown" values should now be fixed

## ----summary-stats------------------------------------------------------------
# cmj_summary <- summary_vald_metrics(
#   data = cmj_data,
#   group_vars = c("sex", "sports"),
#   exclude_cols = c("profileId", "testId", "Testdate", "dateofbirth", "age")
# )
# 
# # View summary
# print(cmj_summary)
# 
# # Export to CSV
# write.csv(cmj_summary, "cmj_summary_by_sport_sex.csv", row.names = FALSE)

## ----plot-trends--------------------------------------------------------------
# library(ggplot2)
# 
# # Plot CMJ peak force trends by athlete
# plot_vald_trends(
#   data = cmj_data,
#   date_col = "Testdate",
#   metric_col = "PEAK_FORCE_Both",
#   group_col = "profileId",
#   facet_col = "sex",
#   title = "CMJ Peak Force Trends by Athlete",
#   smooth = TRUE
# )
# 
# # Plot sport-level averages over time
# sport_trends <- cmj_data %>%
#   group_by(Testdate, sports) %>%
#   summarise(avg_force = mean(PEAK_FORCE_Both, na.rm = TRUE), .groups = "drop")
# 
# plot_vald_trends(
#   data = sport_trends,
#   date_col = "Testdate",
#   metric_col = "avg_force",
#   group_col = "sports",
#   title = "Average CMJ Peak Force by Sport Over Time"
# )

## ----plot-compare-------------------------------------------------------------
# plot_vald_compare(
#   data = cmj_data,
#   metric_col = "PEAK_FORCE_Both",
#   group_col = "sports",
#   fill_col = "sex",
#   title = "CMJ Peak Force Comparison by Sport and Sex"
# )
# 
# # Compare jump height
# plot_vald_compare(
#   data = cmj_data,
#   metric_col = "JUMP_HEIGHT_Both",
#   group_col = "sports",
#   fill_col = "sex",
#   title = "CMJ Jump Height Comparison"
# )

## ----multi-test---------------------------------------------------------------
# # Define a function to extract a common metric across test types
# compare_metric_across_tests <- function(test_datasets, metric = "PEAK_FORCE_Both") {
# 
#   results <- lapply(names(test_datasets), function(test_name) {
#     test_data <- test_datasets[[test_name]]
# 
#     if (metric %in% names(test_data)) {
#       data.frame(
#         testType = test_name,
#         metric = metric,
#         mean = mean(test_data[[metric]], na.rm = TRUE),
#         sd = sd(test_data[[metric]], na.rm = TRUE),
#         n = sum(!is.na(test_data[[metric]]))
#       )
#     }
#   })
# 
#   do.call(rbind, results)
# }
# 
# # Compare peak force across CMJ, DJ, and ISO
# force_comparison <- compare_metric_across_tests(test_datasets, "PEAK_FORCE_Both")
# print(force_comparison)

## ----scheduled-updates, eval=FALSE--------------------------------------------
# # Weekly refresh script
# library(vald.extractor)
# 
# # Fetch only new data since last update
# last_update <- "2024-01-01T00:00:00Z"
# 
# new_data <- fetch_vald_batch(
#   start_date = last_update,
#   chunk_size = 100
# )
# 
# # Append to existing database
# load("vald_database.RData")
# updated_tests <- rbind(existing_tests, new_data$tests)
# updated_trials <- rbind(existing_trials, new_data$trials)
# 
# save(updated_tests, updated_trials, file = "vald_database.RData")

## ----error-logging------------------------------------------------------------
# # Errors are printed to console with chunk information:
# # "ERROR on chunk 23 (rows 2201-2300): API timeout"
# # "Continuing to next chunk..."
# 
# # This ensures partial data extraction even if some chunks fail

## ----taxonomy-config----------------------------------------------------------
# # sports_taxonomy.R
# sports_patterns <- list(
#   Football = "Football|FSI|TCFC|MCFC|Soccer",
#   Basketball = "Basketball|BBall",
#   Cricket = "Cricket",
#   # ... add your organization's patterns
# )
# 
# # Then use in classify_sports()

