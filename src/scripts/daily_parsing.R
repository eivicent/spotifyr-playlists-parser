if(!require(spotifyr)){install.packages("spotifyr")}
library(spotifyr)
library(dplyr)
library(lubridate)

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

# Function to safely read a daily CSV file
read_daily_file_safe <- function(file_path) {
  if (!file.exists(file_path)) {
    return(data.frame())
  }
  
  tryCatch({
    # Use proper CSV reading with quote handling
    df <- read.table(file_path, sep = ";", stringsAsFactors = FALSE, 
                     encoding = "UTF-8", quote = '"', na.strings = "", header = TRUE)
    names(df) <- c("played_at", "track.name", "name", "played", "day")
    
    df <- df %>% 
      mutate(played = as.POSIXct(played, "GMT"),
             day = as.Date(day))
    return(df)
  }, error = function(e) {
    cat("Warning: Could not read", file_path, "- Error:", e$message, "\n")
    return(data.frame())
  })
}

# Function to safely write a daily CSV file with proper escaping
write_daily_file_safe <- function(df, file_path) {
  tryCatch({
    # Write with proper CSV escaping - this handles special characters correctly
    write.table(df, file = file_path, row.names = FALSE, sep = ";", 
                quote = TRUE, fileEncoding = "UTF-8", na = "", col.names = TRUE)
    cat("Successfully wrote", nrow(df), "entries to", file_path, "\n")
  }, error = function(e) {
    cat("Error writing to", file_path, "- Error:", e$message, "\n")
    # Fallback: save as RDS file which handles all characters perfectly
    backup_file <- gsub("\\.csv$", ".rds", file_path)
    saveRDS(df, backup_file)
    cat("Saved backup as RDS:", backup_file, "\n")
  })
}

# Function to get the most recent listening timestamp from daily files
get_latest_timestamp <- function() {
  # Look for recent daily files (last 7 days)
  recent_dates <- seq(Sys.Date() - 7, Sys.Date(), by = "day")
  latest_timestamp <- NULL
  
  for (date in rev(recent_dates)) {
    file_path <- paste0("./daily_listen/", date, ".csv")
    if (file.exists(file_path)) {
      df <- read_daily_file_safe(file_path)
      if (nrow(df) > 0) {
        latest_timestamp <- max(df$played, na.rm = TRUE)
        break
      }
    }
  }
  
  # Fallback: try to read from history.txt if no daily files found
  if (is.null(latest_timestamp)) {
    history_file <- "./daily_listen/history.txt"
    if (file.exists(history_file)) {
      cat("No recent daily files found, reading from history.txt...\n")
      # Read last few lines to get latest timestamp
      last_lines <- tail(readLines(history_file), 10)
      if (length(last_lines) > 1) {
        # Parse the last line (skip header)
        last_entry <- strsplit(last_lines[length(last_lines)], ";")[[1]]
        if (length(last_entry) >= 4) {
          played_str <- gsub('"', '', last_entry[4])
          latest_timestamp <- as.POSIXct(played_str, "GMT")
        }
      }
    }
  }
  
  return(latest_timestamp)
}

# Main execution
access_token <- get_spotify_access_token(client_id = Sys.getenv("SPOTIFY_CLIENT_ID"),
                                         client_secret = Sys.getenv("SPOTIFY_CLIENT_SECRET"))

# Get the latest timestamp from existing data
latest_timestamp <- get_latest_timestamp()

if (is.null(latest_timestamp)) {
  cat("No existing data found, fetching from beginning...\n")
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
  Sys.sleep(5)  # Reduced sleep time since we're fetching more per request
  if(nrow(df) < 50) break  # Updated to match new limit
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
  
  # Group by day and save to individual daily files
  daily_groups <- new_data %>% group_split(day)
  
  for (daily_data in daily_groups) {
    current_day <- daily_data$day[1]
    file_path <- paste0("./daily_listen/", current_day, ".csv")
    
    # Read existing data for this day if it exists
    existing_data <- read_daily_file_safe(file_path)
    
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
    
    # Save the daily file using safer CSV writing
    write_daily_file_safe(combined_data, file_path)
  }
  
  cat("\nDaily parsing completed successfully!\n")
  cat("Data is now stored in individual daily files in ./daily_listen/\n")
  cat("Special characters in song names are properly escaped.\n")
}
