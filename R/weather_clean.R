# Weather Data Cleaning and Validation 

# Load Required Libraries
library(dplyr)      # Data manipulation and filtering
library(readr)      # Efficient CSV reading
library(purrr)      # Iterate over multiple files
library(stringr)    # String validation
library(lubridate)  # Date handling

# Define File Paths
input_path <- "C:/Users/student/Downloads/Assessment/Dataset/weather_data" # Directory for  CSV files
output_path <- "C:/Users/student/Downloads/Assessment/DI_Results"         # Directory for quality check outputs
cleaned_path <- "C:/Users/student/Downloads/Assessment/Cleaned_data"      # Directory for cleaned data

# List Weather Files 
weather_files <- list.files(input_path, pattern = "weather_.*\\.csv", full.names = TRUE)

# Read All Files (treat as character to avoid parsing errors)
weather_all_raw <- map_dfr(weather_files, ~ read_csv(.x, col_types = cols(.default = col_character())))

# Define Column Types
numeric_cols <- c("tmpf", "dwpf", "drct", "sknt", "mslp", "p01i", "vsby", "gust")
string_cols <- c("station", "wxcodes")
date_cols <- c("valid")

# Step 1: Initial Data Transformation
weather_all <- weather_all_raw %>%
  # Convert empty strings or 'null' to NA
  mutate(across(all_of(string_cols), ~ ifelse(. == "" | . == "null", NA, .))) %>%
  # Convert numeric fields
  mutate(across(all_of(numeric_cols), as.numeric)) %>%
  # Parse valid as datetime
  mutate(valid = ymd_hm(valid, tz = "UTC")) %>%
  # Add valid_date (for FL_DATE join) and valid_hour (for flight_time join)
  mutate(
    valid_date = as.Date(valid),
    valid_hour = floor_date(valid, "hour")
  ) %>%
  # Filter for NY airport stations (JFK, LGA, EWR)
  filter(station %in% c("JFK", "LGA", "EWR"))

# Step 2: Data Quality Checks (pre-cleaning)

# Completeness Check 
weather_missing_counts <- colSums(is.na(weather_all))
weather_missing_percent <- round(weather_missing_counts / nrow(weather_all) * 100, 2)
weather_missing_summary <- data.frame(
  Field = names(weather_missing_counts),
  Missing_Count = weather_missing_counts,
  Missing_Percent = weather_missing_percent
)

# Consistency Checks
# Station counts
weather_station_summary <- table(weather_all$station, useNA = "always")
# Duplicate timestamps per station
weather_duplicate_check <- weather_all %>%
  group_by(station, valid) %>%
  summarise(Count = n(), .groups = "drop") %>%
  filter(Count > 1)

# Validity Checks 
# Range checks
weather_ranges <- weather_all %>%
  summarise(across(all_of(numeric_cols), ~ c(min(., na.rm = TRUE), max(., na.rm = TRUE))))
# String validation
weather_string_check <- weather_all %>%
  summarise(
    station_invalid = sum(!station %in% c("JFK", "LGA", "EWR") & !is.na(station)),
    wxcodes_invalid = sum(!str_detect(wxcodes, "^[A-Z+\\-, ]+$") & !is.na(wxcodes))
  )
# Date validation
weather_date_check <- weather_all %>%
  summarise(valid_invalid = sum(is.na(valid) | valid < ymd("2015-01-01") | valid > ymd("2024-12-31")))

# Identify Outlier Detection 
weather_outliers <- weather_all %>%
  filter(
    tmpf < -40 | tmpf > 120 |
      p01i < 0 | p01i > 10 |
      vsby < 0 | vsby > 10
  )

# Step 3: Data Cleansing and Imputation
weather_cleaned <- weather_all %>%
  # Remove invalid valid dates
  filter(!is.na(valid) & valid >= ymd("2015-01-01") & valid <= ymd("2024-12-31")) %>%
  # Impute missing numerics with NA
  mutate(across(all_of(numeric_cols), ~ ifelse(is.na(.), NA, .))) %>%
  # Validate station
  mutate(station = ifelse(station %in% c("JFK", "LGA", "EWR"), station, NA)) %>%
  # Validate wxcodes
  mutate(wxcodes = ifelse(str_detect(wxcodes, "^[A-Z+\\-, ]+$"), wxcodes, NA)) %>%
  # Remove duplicates
  distinct(station, valid, .keep_all = TRUE) %>%
  # Cap outliers
  mutate(
    tmpf = pmin(pmax(tmpf, -40), 120),
    p01i = pmin(pmax(p01i, 0), 10),
    vsby = pmin(pmax(vsby, 0), 10)
  )

# Step 4: Final Validation and Export

# Log Removed Rows
invalid_date_rows <- weather_all %>%
  filter(is.na(valid) | valid < ymd("2015-01-01") | valid > ymd("2024-12-31"))
duplicate_rows <- weather_all %>%
  filter(duplicated(weather_all[, c("station", "valid")]) |
           duplicated(weather_all[, c("station", "valid")], fromLast = TRUE))

# Validation Check
weather_validation <- weather_cleaned %>%
  group_by(year(valid)) %>%
  summarise(Total_Observations = n(), .groups = "drop")

# Export Results
write_csv(weather_missing_summary, file.path(output_path, "weather_missing_summary.csv"))
write_csv(as.data.frame(weather_station_summary), file.path(output_path, "weather_station_summary.csv"))
write_csv(weather_duplicate_check, file.path(output_path, "weather_duplicate_check.csv"))
write_csv(weather_ranges, file.path(output_path, "weather_ranges.csv"))
write_csv(weather_string_check, file.path(output_path, "weather_string_check.csv"))
write_csv(weather_date_check, file.path(output_path, "weather_date_check.csv"))
write_csv(weather_outliers, file.path(output_path, "weather_outliers.csv"))
write_csv(invalid_date_rows, file.path(output_path, "weather_invalid_dates.csv"))
write_csv(duplicate_rows, file.path(output_path, "weather_duplicates.csv"))
write_csv(weather_validation, file.path(output_path, "weather_yearly_totals.csv"))
write_csv(weather_cleaned, file.path(cleaned_path, "weather_cleaned_data.csv"))

# Print Summary
cat("\n=== Weather Data Quality Summary ===\n")
cat("Input Rows:", nrow(weather_all_raw), "\n")
cat("Cleaned Rows:", nrow(weather_cleaned), "\n")
cat("Missing Values Summary:\n")
print(weather_missing_summary)
cat("\nYearly Observation Totals:\n")
print(weather_validation)
