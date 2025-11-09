# Spotify Playlists Parser - Utility Functions
# Standardized functions for use across all .qmd files

# Load required libraries
load_common_libraries <- function() {
  library(dplyr)
  library(purrr)
  library(tidyr)
  library(stringr)
  library(ggplot2)
  library(lubridate)
  library(here)
  library(bslib)
  library(gt)
}

# Get list of daily CSV files
get_daily_files <- function() {
  list.files(here("data", "daily"), pattern = "\\.csv$", full.names = TRUE)
}

# Extract date from filename
extract_date_from_filename <- function(file_path) {
  basename(file_path) %>% 
    str_remove("\\.csv$") %>%
    as.Date()
}

# Read and process a single daily file - Summary version (with all metrics)
read_daily_file_summary <- function(file_path) {
  if (file.exists(file_path)) {
    # Read the CSV file
    daily_data <- read.csv(file_path, sep = ";", stringsAsFactors = FALSE)
    
    # Extract date from filename
    date_str <- basename(file_path) %>% 
      str_remove("\\.csv$")
    
    # Calculate metrics for this day
    song_count <- nrow(daily_data)
    unique_artists <- length(unique(daily_data$name))
    unique_tracks <- length(unique(daily_data$track.name))
    
    # Estimate minutes listened (assuming average 3.5 minutes per song)
    estimated_minutes <- song_count * 3.5
    
    # Return comprehensive summary
    data.frame(
      date = as.Date(date_str),
      songs = song_count,
      unique_artists = unique_artists,
      unique_tracks = unique_tracks,
      estimated_minutes = estimated_minutes,
      file = basename(file_path)
    )
  } else {
    return(NULL)
  }
}

# Read and process a single daily file - Simple version (date and songs only)
read_daily_file_simple <- function(file_path) {
  if (file.exists(file_path)) {
    # Read the CSV file
    daily_data <- read.csv(file_path, sep = ";", stringsAsFactors = FALSE)
    
    # Extract date from filename
    date_str <- basename(file_path) %>% 
      str_remove("\\.csv$")
    
    # Calculate metrics for this day
    song_count <- nrow(daily_data)
    
    # Return summary
    data.frame(
      date = as.Date(date_str),
      songs = song_count
    )
  } else {
    return(NULL)
  }
}

# Read and process a single daily file - Artist version (with date extraction logic)
read_daily_file_artist <- function(file_path) {
  if (file.exists(file_path)) {
    # Read the CSV file
    daily_data <- read.csv(file_path, sep = ";", stringsAsFactors = FALSE)
    
    # Extract date from filename as fallback
    date_str <- basename(file_path) %>% 
      str_remove("\\.csv$")
    
    # Use day column if available, otherwise try played_at, otherwise use filename
    if ("day" %in% colnames(daily_data) && !all(is.na(daily_data$day))) {
      daily_data$date <- as.Date(daily_data$day)
    } else if ("played_at" %in% colnames(daily_data)) {
      # Parse played_at timestamp to get date
      daily_data$date <- as.Date(substr(daily_data$played_at, 1, 10))
    } else {
      daily_data$date <- as.Date(date_str)
    }
    
    # Select relevant columns (name is artist, day or date for the date)
    artist_data <- daily_data %>%
      select(name, date, track.name) %>%
      filter(!is.na(name), !is.na(date)) %>%
      rename(song = track.name)
    
    return(artist_data)
  } else {
    return(NULL)
  }
}

# Load daily summary data (summary version)
load_daily_summary <- function() {
  daily_files <- get_daily_files()
  daily_summary <- map_dfr(daily_files, read_daily_file_summary) %>%
    arrange(date) %>%
    filter(!is.na(date))
  return(daily_summary)
}

# Load daily summary data (simple version)
load_daily_summary_simple <- function() {
  daily_files <- get_daily_files()
  daily_summary <- map_dfr(daily_files, read_daily_file_simple) %>%
    arrange(date) %>%
    filter(!is.na(date))
  return(daily_summary)
}

# Load artist data
load_artist_data <- function() {
  daily_files <- get_daily_files()
  all_artist_data <- map_dfr(daily_files, read_daily_file_artist) %>%
    arrange(date) %>%
    filter(!is.na(date), !is.na(name)) %>%
    distinct()  # Remove duplicates
  
  # Create year-month column for grouping
  all_artist_data <- all_artist_data %>%
    mutate(
      year_month = floor_date(date, "month"),
      year_month_str = format(year_month, "%Y-%m")
    )
  
  return(all_artist_data)
}

# Add weekday information to daily summary
add_weekday_info <- function(daily_summary) {
  daily_summary %>%
    mutate(
      weekday = wday(date, label = TRUE, abbr = FALSE, week_start = 1),
      weekday_num = wday(date, week_start = 1),
      year = year(date),
      week_num = week(date),
      year_week = paste(year, sprintf("%02d", week_num), sep = "-W")
    ) %>%
    mutate(
      weekday = factor(
        weekday, 
        levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
      )
    )
}

