# BTS AND WEATHER DATA MERGING

# Load Required Libraries
library(dplyr)
library(readr)
library(lubridate)

# Define File Paths
cleaned_path <- "C:/Users/student/Downloads/Assessment/Cleaned_data"
output_path <- "C:/Users/student/Downloads/Assessment/DI_Results"
merged_path <- "C:/Users/student/Downloads/Assessment/Merged_data"

# Load Cleaned Data
bts_cleaned <- read_csv(file.path(cleaned_path, "bts_cleaned_data.csv"))
weather_cleaned <- read_csv(file.path(cleaned_path, "weather_cleaned_data.csv"))

# Ensure consistent time formats for the join keys
bts_cleaned <- bts_cleaned %>%
  mutate(flight_hour = as.POSIXct(flight_hour, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"))
weather_cleaned <- weather_cleaned %>%
  mutate(valid_hour = as.POSIXct(valid_hour, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"))

# Merge Data (Left Join)
merged_data <- bts_cleaned %>%
  left_join(weather_cleaned, by = c("FL_DATE" = "valid_date", "flight_hour" = "valid_hour", "ORIGIN" = "station")) %>%
  # Add merge status for validation
  mutate(merge_status = ifelse(is.na(wxcodes) & is.na(p01i), "No Weather Match", "Matched"))

# Summarize Merge Results
merge_summary <- merged_data %>%
  summarise(
    Total_Flights = n(),
    Matched_Weather = sum(merge_status == "Matched"),
    Unmatched_Weather = sum(merge_status == "No Weather Match"),
    Match_Rate = mean(merge_status == "Matched") * 100
  )

# Log Unmatched Rows
unmatched_rows <- merged_data %>%
  filter(merge_status == "No Weather Match") %>%
  select(flight_hour, ORIGIN, DEP_DELAY, CANCELLED, DIVERTED, wxcodes, p01i)

# Export Results
write_csv(merged_data, file.path(merged_path, "merged_flights_data.csv"))
write_csv(merge_summary, file.path(output_path, "merge_summary.csv"))
write_csv(unmatched_rows, file.path(output_path, "unmatched_weather_rows.csv"))

# Print Summary
cat("\n=== Merge Summary ===\n")
print(merge_summary)