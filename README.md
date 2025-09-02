# Flight Data Analysis

##  About  
This project analyzes flight operations at New York airports (JFK, LGA, EWR) between 2015 and 2024 by integrating BTS flight data with Mesonet weather data.It includes data quality checks, cleansing, and integration to ensure reliable datasets. 
Using Hive, large-scale data queries are executed to answer business questions related to delays, cancellations, diversions, and their relationship with weather patterns. Tableau dashboards are then developed to visualize trends and provide actionable insights for stakeholders.
- **Primary Data**: BTS (Bureau of Transportation Statistics) flight records.  
- **Secondary Data**: Mesonet historical weather observations.  

The end-to-end workflow includes:  
- Data quality checks and cleansing in **R**.  
- Data integration and large-scale querying using **Apache Hive**.  
- Business intelligence and visual insights with **Tableau**.  

The goal is to answer key business questions related to **flight delays, cancellations, diversions, and their correlation with weather patterns**, enabling better operational insights for stakeholders.  

---

## Business Questions  
The analysis is driven by five central business questions:  

1. **Monthly Flight Departures by Destination**  
   - What is the month-by-month breakdown of total flight departures from New York airports (2015–2024)?  

2. **Delayed Departures by Airline, Weather, and Airport**  
   - How do delays vary month by month, categorized by airline, airport, and weather conditions?  

3. **Highest Cancellations by Airport & Airline**  
   - Which airport and which airline recorded the highest number of cancellations between 2015–2024?  

4. **Weather-Related Cancellations**  
   - What is the monthly total number of cancellations specifically caused by weather, broken down by airline and airport?  

5. **Monthly Diverted Flights**  
   - How many flights were diverted each month to New York airports (JFK, LGA, EWR) between 2015–2024?  

---

## Data Sources  
- **[BTS Flight Data](https://www.transtats.bts.gov/DL_SelectFields.aspx?gnoyr_VQ=FGJ&QO_fu146_anzr=b0-gvzr)**  
  Contains detailed information on flight schedules, delays, cancellations, and diversions.  

- **[Mesonet Weather Data](https://mesonet.agron.iastate.edu/request/download.phtml)**  
  Provides weather conditions including temperature, precipitation, wind, and visibility.  

These datasets were chosen to **combine operational flight records with environmental weather factors**, ensuring comprehensive analysis.  

---

## Tools & Technologies  
- **RStudio** → Data quality checks, cleansing, preprocessing  
- **HDFS (Hadoop Distributed File System)** → Large-scale storage  
- **Hive** → Data warehouse schema, querying, and integration  
- **DbSchema** → Schema modeling and visualization  
- **Tableau** → BI dashboards and visualizations   

---

##  Schema Design — Constellation Schema  

The project follows **Kimball’s dimensional modeling** approach using a **constellation schema** with shared conformed dimensions.  

###  Dimension Tables  
- **dim_time** → Date, Year, Month  
- **dim_airport** → Airport code and name (role-played as Origin/Destination)  
- **dim_airline** → Carrier code and name  
- **dim_weather** → Weather station, weather codes, precipitation, hour  
- **dim_cancellation** → Cancellation codes (A–D) with reason text  

###  Fact Tables  
- **fact_departures** → Flight departures (date, airport, airline, delay details)  
- **fact_delays** → Delayed departures (linked to weather & carrier)  
- **fact_cancellations** → Cancelled flights (linked to reasons)  
- **fact_diversions** → Diverted flights (arrival airport, carrier)  

Each fact table is linked to conformed dimensions (Time, Airport, Airline, Weather) ensuring **consistency and flexibility**.  

---

## Workflow  

1. **Data Acquisition**  
   - Downloaded BTS flight datasets (2015–2024).  
   - Collected Mesonet historical weather datasets for the same timeframe.  

2. **Data Quality & Cleansing (R)**  
   - Checked for missing values, duplicates, range, validity, outliers and inconsistencies.  
   - Standardized formats (e.g., date/time, airport codes, airline codes).  
   - Handled outliers in delay and cancellation fields.  

3. **Data Integration (Hive)**  
   - Raw and cleaned data stored in Hadoop HDFS.
   - Imported cleaned data into Hive tables.
   - Created staging tables (`bts_staging`, `weather_staging`) and performed joins to create **merged_flights**. 
   - Designed a **constellation schema** with shared conformed dimensions (Time, Airport, Airline, Weather).
   - Designed **dimension** and **fact tables** in Hive and populated them from merged data.  
   - Executed queries to directly address business questions.  

4. **Analysis & Querying**  
   - Monthly aggregates of departures, delays, cancellations, and diversions.  
   - Role-played Airport dimension as Origin and Destination.  
   - Linked weather patterns with delays and cancellations.  

5. **Visualization (Tableau)**  
   - Created dashboards for:  
     - Monthly departures and delays.  
     - Airline and airport cancellation comparisons.  
     - Weather-related disruptions.  
     - Trends in diverted flights.
 
---
       
## Deliverables
- Cleaned datasets (flight and weather).  
- Hive tables and queries for business insights.  
- Tableau dashboards for visual exploration and reporting.  
- Documentation and summary outputs for assessment.

---

## Key Insights
- Trends in flight departures and delays across 10 years.  
- Impact of weather conditions on delays and cancellations.  
- Identification of top airlines and airports with highest disruptions.  
- Seasonal and monthly variations in diversions and cancellations.

