# === BTS Flight Data Cleaning and Validation ===

# Load Required Libraries
library(dplyr)      # Data manipulation and filtering
library(readr)      # Efficient CSV reading
library(purrr)      # Iterate over multiple files
library(stringr)    # String validation
library(lubridate)  # Date handling

# Define File Paths
input_path <- "C:/Users/student/Downloads/Assessment/Dataset/bts_data" # Directory for CSV files
output_path <- "C:/Users/student/Downloads/Assessment/DI_Results"      # Directory for quality check outputs
cleaned_path <- "C:/Users/student/Downloads/Assessment/Cleaned_data"   # Directory for cleaned data

# List BTS Files 
bts_files <- list.files(input_path, pattern = "bts_.*\\.csv", full.names = TRUE)

# Read All Files (treat as character to avoid parsing errors)
bts_all_raw <- map_dfr(bts_files, ~ read_csv(.x, col_types = cols(.default = col_character())))

# Define Column Types
numeric_cols <- c("YEAR", "MONTH", "DAY_OF_MONTH", "DEP_DELAY", "DEP_DELAY_NEW",
                  "ARR_DELAY", "ARR_DELAY_NEW", "CARRIER_DELAY", "WEATHER_DELAY",
                  "NAS_DELAY", "LATE_AIRCRAFT_DELAY")
boolean_cols <- c("DEP_DEL15", "ARR_DEL15", "CANCELLED", "DIVERTED")
string_cols <- c("OP_UNIQUE_CARRIER", "OP_CARRIER_AIRLINE_ID", "TAIL_NUM",
                 "OP_CARRIER_FL_NUM", "ORIGIN_AIRPORT_ID", "ORIGIN",
                 "DEST_AIRPORT_ID", "DEST", "CANCELLATION_CODE",
                 "DIV1_AIRPORT", "DIV1_AIRPORT_ID", "CRS_DEP_TIME",
                 "DEP_TIME", "CRS_ARR_TIME", "ARR_TIME")
date_cols <- c("FL_DATE")

# Initial Data Transformation
bts_all <- bts_all_raw %>%
  # Convert empty strings or 'null' to NA
  mutate(across(all_of(string_cols), ~ ifelse(. == "" | . == "null", NA, .))) %>%
  # Convert numeric and boolean fields
  mutate(across(all_of(numeric_cols), as.numeric)) %>%
  mutate(across(all_of(boolean_cols), ~ as.logical(as.numeric(.)))) %>%
  # Parse FL_DATE with multiple formats
  mutate(FL_DATE = as.Date(FL_DATE, tryFormats = c("%m-%d-%Y", "%m/%d/%Y", "%Y-%m-%d"))) %>%
  # Add flight_hour for weather data join
  mutate(
    flight_time = as.POSIXct(
      paste(FL_DATE, sprintf("%04d", as.numeric(DEP_TIME))),
      format = "%Y-%m-%d %H%M",
      tz = "UTC"
    ),
    flight_hour = floor_date(flight_time, "hour")
  ) %>%
  # Filter for NY airports (JFK, LGA, EWR)
  filter(ORIGIN %in% c("JFK", "LGA", "EWR"))

# Data Quality Checks (pre-cleaning)

# Completeness Check 
bts_missing_counts <- colSums(is.na(bts_all))
bts_missing_percent <- round(bts_missing_counts / nrow(bts_all) * 100, 2)
bts_missing_summary <- data.frame(
  Field = names(bts_missing_counts),
  Missing_Count = bts_missing_counts,
  Missing_Percent = bts_missing_percent
)

# Consistency Checks 
# Airport ID consistency
bts_origin_id_check <- bts_all %>%
  summarise(Inconsistent = sum(!str_detect(ORIGIN_AIRPORT_ID, "^[0-9]+$") | is.na(ORIGIN_AIRPORT_ID)))
bts_dest_id_check <- bts_all %>%
  summarise(Inconsistent = sum(!str_detect(DEST_AIRPORT_ID, "^[0-9]+$") | is.na(DEST_AIRPORT_ID)))
# Duplicate flights (FL_DATE, OP_CARRIER_FL_NUM, ORIGIN)
bts_duplicate_check <- bts_all %>%
  group_by(FL_DATE, OP_CARRIER_FL_NUM, ORIGIN) %>%
  summarise(Count = n(), .groups = "drop") %>%
  filter(Count > 1)
# Cancellation code alignment
bts_cancellation_summary <- table(bts_all$CANCELLED, bts_all$CANCELLATION_CODE, useNA = "always")
# Diversion alignment
bts_diversion_summary <- table(bts_all$DIVERTED, bts_all$DIV1_AIRPORT, useNA = "always")
# Carrier ID consistency
bts_carrier_check <- bts_all %>%
  summarise(Inconsistent = sum(!str_detect(OP_CARRIER_AIRLINE_ID, "^[0-9]+$") | is.na(OP_CARRIER_AIRLINE_ID)))

# Validity Checks 
# Range checks
bts_ranges <- bts_all %>%
  summarise(across(all_of(numeric_cols), ~ c(min(., na.rm = TRUE), max(., na.rm = TRUE))))
# Boolean field validation
bts_boolean_check <- bts_all %>%
  summarise(
    DEP_DEL15_Invalid = sum(!DEP_DEL15 %in% c(TRUE, FALSE, NA), na.rm = TRUE),
    ARR_DEL15_Invalid = sum(!ARR_DEL15 %in% c(TRUE, FALSE, NA), na.rm = TRUE),
    CANCELLED_Invalid = sum(!CANCELLED %in% c(TRUE, FALSE, NA), na.rm = TRUE),
    DIVERTED_Invalid = sum(!DIVERTED %in% c(TRUE, FALSE, NA), na.rm = TRUE)
  )
# String field validation
bts_string_check <- bts_all %>%
  summarise(
    TAIL_NUM_Invalid = sum(!str_detect(TAIL_NUM, "^[A-Z0-9]+$") | is.na(TAIL_NUM), na.rm = TRUE),
    OP_CARRIER_FL_NUM_Invalid = sum(!str_detect(OP_CARRIER_FL_NUM, "^[0-9]+$") | is.na(OP_CARRIER_FL_NUM), na.rm = TRUE),
    CANCELLATION_CODE_Invalid = sum(!CANCELLATION_CODE %in% c("A", "B", "C", "D", NA), na.rm = TRUE),
    CRS_DEP_TIME_Invalid = sum(!str_detect(CRS_DEP_TIME, "^[0-9]{4}$") | is.na(CRS_DEP_TIME), na.rm = TRUE)
  )
# Date validation
bts_date_check <- bts_all %>%
  summarise(FL_DATE_Invalid = sum(is.na(FL_DATE) | FL_DATE < as.Date("2015-01-01") | FL_DATE > as.Date("2024-12-31")))

# Identify Outliers 
bts_outliers <- bts_all %>%
  filter(
    DEP_DELAY < (quantile(DEP_DELAY, 0.25, na.rm = TRUE) - 1.5 * IQR(DEP_DELAY, na.rm = TRUE)) |
      DEP_DELAY > (quantile(DEP_DELAY, 0.75, na.rm = TRUE) + 1.5 * IQR(DEP_DELAY, na.rm = TRUE)) |
      WEATHER_DELAY < 0 | WEATHER_DELAY > (quantile(WEATHER_DELAY, 0.75, na.rm = TRUE) + 1.5 * IQR(WEATHER_DELAY, na.rm = TRUE))
  )

# Step 3: Data Cleansing and Imputation
bts_cleaned <- bts_all %>%
  # Remove invalid FL_DATE rows
  filter(!is.na(FL_DATE) & FL_DATE >= as.Date("2015-01-01") & FL_DATE <= as.Date("2024-12-31")) %>%
  # Handle terminal events (CANCELLED, DIVERTED)
  mutate(
    CANCELLATION_CODE = ifelse(CANCELLED == FALSE | is.na(CANCELLED), NA, 
                               ifelse(CANCELLATION_CODE %in% c("A", "B", "C", "D"), CANCELLATION_CODE, NA)),
    DIV1_AIRPORT = ifelse(DIVERTED == FALSE | is.na(DIVERTED), NA, DIV1_AIRPORT),
    DIV1_AIRPORT_ID = ifelse(DIVERTED == FALSE | is.na(DIVERTED), NA, DIV1_AIRPORT_ID)
  ) %>%
  # Impute delays for non-cancelled, non-diverted flights
  mutate(
    DEP_DELAY = ifelse(CANCELLED == FALSE & DIVERTED == FALSE & is.na(DEP_DELAY), 0, DEP_DELAY),
    DEP_DELAY_NEW = ifelse(CANCELLED == FALSE & DIVERTED == FALSE & is.na(DEP_DELAY_NEW), 0, DEP_DELAY_NEW),
    ARR_DELAY = ifelse(CANCELLED == FALSE & DIVERTED == FALSE & is.na(ARR_DELAY), 0, ARR_DELAY),
    ARR_DELAY_NEW = ifelse(CANCELLED == FALSE & DIVERTED == FALSE & is.na(ARR_DELAY_NEW), 0, ARR_DELAY_NEW),
    CARRIER_DELAY = ifelse(CANCELLED == FALSE & DIVERTED == FALSE & is.na(CARRIER_DELAY), 0, CARRIER_DELAY),
    WEATHER_DELAY = ifelse(CANCELLED == FALSE & DIVERTED == FALSE & is.na(WEATHER_DELAY), 0, WEATHER_DELAY),
    NAS_DELAY = ifelse(CANCELLED == FALSE & DIVERTED == FALSE & is.na(NAS_DELAY), 0, NAS_DELAY),
    LATE_AIRCRAFT_DELAY = ifelse(CANCELLED == FALSE & DIVERTED == FALSE & is.na(LATE_AIRCRAFT_DELAY), 0, LATE_AIRCRAFT_DELAY)
  ) %>%
  # Ensure valid booleans
  mutate(across(all_of(boolean_cols), ~ ifelse(. %in% c(TRUE, FALSE), ., NA))) %>%
  # Validate strings
  mutate(
    TAIL_NUM = ifelse(str_detect(TAIL_NUM, "^[A-Z0-9]+$"), TAIL_NUM, NA),
    OP_CARRIER_FL_NUM = ifelse(str_detect(OP_CARRIER_FL_NUM, "^[0-9]+$"), OP_CARRIER_FL_NUM, NA),
    CRS_DEP_TIME = ifelse(str_detect(CRS_DEP_TIME, "^[0-9]{4}$"), CRS_DEP_TIME, NA)
  ) %>%
  # Cap outliers for delays
  mutate(
    DEP_DELAY = pmin(pmax(DEP_DELAY, quantile(DEP_DELAY, 0.25, na.rm = TRUE) - 1.5 * IQR(DEP_DELAY, na.rm = TRUE)),
                     quantile(DEP_DELAY, 0.75, na.rm = TRUE) + 1.5 * IQR(DEP_DELAY, na.rm = TRUE)),
    WEATHER_DELAY = pmin(pmax(WEATHER_DELAY, 0), quantile(WEATHER_DELAY, 0.75, na.rm = TRUE) + 1.5 * IQR(WEATHER_DELAY, na.rm = TRUE))
  ) %>%
  # Remove duplicates
  distinct(FL_DATE, OP_CARRIER_FL_NUM, ORIGIN, .keep_all = TRUE)

# Step 4: Final Validation and Export

# Log Removed Rows
invalid_date_rows <- bts_all %>%
  filter(is.na(FL_DATE) | FL_DATE < as.Date("2015-01-01") | FL_DATE > as.Date("2024-12-31"))
duplicate_rows <- bts_all %>%
  filter(duplicated(bts_all[, c("FL_DATE", "OP_CARRIER_FL_NUM", "ORIGIN")]) |
           duplicated(bts_all[, c("FL_DATE", "OP_CARRIER_FL_NUM", "ORIGIN")], fromLast = TRUE))

# Validation Check
bts_validation <- bts_cleaned %>%
  group_by(YEAR) %>%
  summarise(Total_Flights = n(), .groups = "drop")

# Export Results
write_csv(bts_missing_summary, file.path(output_path, "bts_missing_summary.csv"))
write_csv(bts_origin_id_check, file.path(output_path, "bts_origin_id_summary.csv"))
write_csv(bts_dest_id_check, file.path(output_path, "bts_dest_id_summary.csv"))
write_csv(bts_duplicate_check, file.path(output_path, "bts_duplicate_check.csv"))
write_csv(as.data.frame(bts_cancellation_summary), file.path(output_path, "bts_cancellation_summary.csv"))
write_csv(as.data.frame(bts_diversion_summary), file.path(output_path, "bts_diversion_summary.csv"))
write_csv(bts_carrier_check, file.path(output_path, "bts_carrier_check.csv"))
write_csv(bts_ranges, file.path(output_path, "bts_ranges.csv"))
write_csv(bts_boolean_check, file.path(output_path, "bts_boolean_check.csv"))
write_csv(bts_string_check, file.path(output_path, "bts_string_check.csv"))
write_csv(bts_date_check, file.path(output_path, "bts_date_check.csv"))
write_csv(bts_outliers, file.path(output_path, "bts_outliers.csv"))
write_csv(invalid_date_rows, file.path(output_path, "bts_invalid_dates.csv"))
write_csv(duplicate_rows, file.path(output_path, "bts_duplicates.csv"))
write_csv(bts_validation, file.path(output_path, "bts_yearly_totals.csv"))
write_csv(bts_cleaned, file.path(cleaned_path, "bts_cleaned_data.csv"))

# Print Summary
cat("\n=== BTS Data Quality Summary ===\n")
cat("Input Rows:", nrow(bts_all_raw), "\n")
cat("Cleaned Rows:", nrow(bts_cleaned), "\n")
cat("Missing Values Summary:\n")
print(bts_missing_summary)
cat("\nYearly Flight Totals:\n")
print(bts_validation)
