if(!require(spotifyr)){install.packages("spotifyr")}
if(!require(jsonlite)){install.packages("jsonlite")}
library(spotifyr)
library(dplyr)
library(lubridate)
library(jsonlite)

clean_api_call_output <- function(output_from_get_my_recently_played) {
  
  df <- output_from_get_my_recently_played %>% select(played_at, track.name) %>% 
    bind_cols(output_from_get_my_recently_played$track.artists %>% 
                bind_rows(.id = "song_id") %>% 
                slice_head(n = 1, by = "song_id") %>% 
                select(name)) %>% 
    mutate(played = as_datetime(played_at),
           day = date(played))
  return(df)
}

# Function to safely read a daily JSON file
read_daily_json_safe <- function(file_path) {
  if (!file.exists(file_path)) {
    return(data.frame())
  }
  
  tryCatch({
    json_data <- fromJSON(file_path)
    # Convert back to proper data types
    df <- json_data %>%
      mutate(played = as.POSIXct(played, "GMT"),
             day = as.Date(day))
    return(df)
  }, error = function(e) {
    cat("Warning: Could not read", file_path, "- Error:", e$message, "\n")
    return(data.frame())
  })
}

# Function to safely write a daily JSON file
write_daily_json_safe <- function(df, file_path) {
  tryCatch({
    # Convert to character for JSON storage
    df_for_json <- df %>%
      mutate(played = as.character(played),
             day = as.character(day))
    
    # Write as pretty JSON with proper UTF-8 encoding
    write_json(df_for_json, file_path, pretty = TRUE, auto_unbox = TRUE)
    cat("Successfully wrote", nrow(df), "entries to", file_path, "\n")
  }, error = function(e) {
    cat("Error writing to", file_path, "- Error:", e$message, "\n")
  })
}

# Function to get the most recent listening timestamp from daily files
get_latest_timestamp_json <- function() {
  # Look for recent daily files (last 7 days)
  recent_dates <- seq(Sys.Date() - 7, Sys.Date(), by = "day")
  latest_timestamp <- NULL
  
  for (date in rev(recent_dates)) {
    file_path <- paste0("./daily_listen/", date, ".json")
    if (file.exists(file_path)) {
      df <- read_daily_json_safe(file_path)
      if (nrow(df) > 0) {
        latest_timestamp <- max(df$played, na.rm = TRUE)
        break
      }
    }
  }
  
  return(latest_timestamp)
}

# Main execution
access_token <- get_spotify_access_token(client_id = Sys.getenv("SPOTIFY_CLIENT_ID"),
                                         client_secret = Sys.getenv("SPOTIFY_CLIENT_SECRET"))

# Get the latest timestamp from existing data
latest_timestamp <- get_latest_timestamp_json()

if (is.null(latest_timestamp)) {
  cat("No existing JSON data found, fetching from beginning...\n")
  start_time <- NULL
} else {
  start_time <- format(as.integer(latest_timestamp)*1000, scientific = FALSE)
  cat("Latest timestamp found:", as.character(latest_timestamp), "\n")
  cat("Starting from:", start_time, "\n")
}

mytoken <- readRDS("secrets/my_secret")[[1]]

# Fetch new data
output <- list(); ii <- 1
repeat{
  aux <- get_my_recently_played(authorization = mytoken,
                                after = as.character(start_time), limit = 50)
  
  df <- clean_api_call_output(aux)
  
  if (nrow(df) == 0) {
    cat("No new data found.\n")
    break
  }
  
  output[[ii]] <- df
  start_time <- max(as.character(as.integer(df$played)*1000)); ii <- ii + 1
  Sys.sleep(5)
  if(nrow(df) < 50) break
}

if (length(output) == 0) {
  cat("No new listening data to process.\n")
} else {
  # Combine all new data
  new_data <- bind_rows(output) %>% 
    arrange(played) %>% 
    mutate(played = as.character(played),
           day = as.character(day)) %>%
    unique()
  
  cat("Fetched", nrow(new_data), "new listening entries\n")
  
  # Group by day and save to individual JSON files
  daily_groups <- new_data %>% group_split(day)
  
  for (daily_data in daily_groups) {
    current_day <- daily_data$day[1]
    file_path <- paste0("./daily_listen/", current_day, ".json")
    
    # Read existing data for this day if it exists
    existing_data <- read_daily_json_safe(file_path)
    
    # Combine with new data and remove duplicates
    if (nrow(existing_data) > 0) {
      # Convert existing data back to character for comparison
      existing_data <- existing_data %>%
        mutate(played = as.character(played),
               day = as.character(day))
      
      combined_data <- bind_rows(existing_data, daily_data) %>%
        arrange(played) %>%
        unique()
      
      cat("Day", current_day, ": Combined", nrow(existing_data), "existing +", 
          nrow(daily_data), "new =", nrow(combined_data), "total entries\n")
    } else {
      combined_data <- daily_data
      cat("Day", current_day, ": New file with", nrow(combined_data), "entries\n")
    }
    
    # Save the daily file as JSON
    write_daily_json_safe(combined_data, file_path)
  }
  
  cat("\nDaily parsing completed successfully!\n")
  cat("Data is now stored in individual daily JSON files in ./daily_listen/\n")
  cat("JSON format completely avoids CSV parsing issues with special characters.\n")
} 