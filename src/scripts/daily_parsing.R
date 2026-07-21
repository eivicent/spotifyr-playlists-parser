if (!requireNamespace("spotifyr", quietly = TRUE)) {
  install.packages("spotifyr")
}
library(spotifyr)
library(dplyr)
library(lubridate)

source("src/R/daily_io.R")

clean_api_call_output <- function(output_from_get_my_recently_played) {
  artists_long <- output_from_get_my_recently_played$track.artists %>%
    bind_rows(.id = "song_id") %>%
    mutate(song_id = as.integer(.data$song_id))

  primary <- artists_long %>%
    slice_head(n = 1, by = "song_id") %>%
    transmute(
      song_id,
      name = as.character(.data$name),
      artist.id = as.character(.data$id)
    )

  featured <- artists_long %>%
    group_by(song_id) %>%
    filter(dplyr::n() > 1, dplyr::row_number() > 1) %>%
    summarise(
      featured_artists = collapse_featured(.data$name),
      featured_artist_ids = collapse_featured(.data$id),
      .groups = "drop"
    )

  artists <- primary %>%
    left_join(featured, by = "song_id") %>%
    arrange(song_id) %>%
    select(-song_id)

  output_from_get_my_recently_played %>%
    transmute(
      played_at = as.character(.data$played_at),
      track.name = as.character(.data$track.name),
      track.id = as.character(.data$track.id)
    ) %>%
    bind_cols(artists) %>%
    mutate(
      played = as_datetime(played_at),
      day = date(played)
    ) %>%
    normalize_daily_df()
}

# Most recent listening timestamp from daily files (last 7 days), else history.txt
get_latest_timestamp <- function() {
  recent_dates <- seq(Sys.Date() - 7, Sys.Date(), by = "day")
  latest_timestamp <- NULL

  for (date in rev(recent_dates)) {
    file_path <- paste0("./data/daily/", date, ".csv")
    if (file.exists(file_path)) {
      df <- read_daily_csv(file_path)
      if (nrow(df) > 0) {
        latest_timestamp <- max(df$played, na.rm = TRUE)
        break
      }
    }
  }

  if (is.null(latest_timestamp)) {
    history_file <- "./data/daily/history.txt"
    if (file.exists(history_file)) {
      message("No recent daily files found, reading from history.txt...")
      last_lines <- utils::tail(readLines(history_file), 10)
      if (length(last_lines) > 1) {
        last_entry <- strsplit(last_lines[length(last_lines)], ";", fixed = TRUE)[[1]]
        if (length(last_entry) >= 4) {
          played_str <- gsub('"', "", last_entry[4])
          latest_timestamp <- as.POSIXct(played_str, tz = "GMT")
        }
      }
    }
  }

  latest_timestamp
}

# Main execution — uses user OAuth token (decrypted RDS), not client-credentials
latest_timestamp <- get_latest_timestamp()

if (is.null(latest_timestamp)) {
  message("No existing data found, fetching from beginning...")
  start_time <- NULL
} else {
  start_time <- format(as.integer(latest_timestamp) * 1000, scientific = FALSE)
  message("Latest timestamp found: ", as.character(latest_timestamp))
  message("Starting from: ", start_time)
}

mytoken <- readRDS("secrets/my_secret")[[1]]

output <- list()
ii <- 1
repeat {
  aux <- get_my_recently_played(
    authorization = mytoken,
    after = as.character(start_time),
    limit = 50
  )

  df <- clean_api_call_output(aux)

  if (nrow(df) == 0) {
    message("No new data found.")
    break
  }

  output[[ii]] <- df
  start_time <- max(as.character(as.integer(df$played) * 1000))
  ii <- ii + 1
  Sys.sleep(5)
  if (nrow(df) < 50) break
}

if (length(output) == 0) {
  message("No new listening data to process.")
} else {
  new_data <- bind_rows(output) %>%
    arrange(played) %>%
    dedupe_daily_plays()

  message("Fetched ", nrow(new_data), " new listening entries")

  daily_groups <- new_data %>%
    mutate(day_chr = as.character(day)) %>%
    group_split(day_chr, .keep = TRUE)

  for (daily_data in daily_groups) {
    current_day <- as.character(daily_data$day[1])
    file_path <- paste0("./data/daily/", current_day, ".csv")

    existing_data <- read_daily_csv(file_path)

    if (nrow(existing_data) > 0) {
      combined_data <- bind_rows(existing_data, daily_data) %>%
        arrange(played) %>%
        dedupe_daily_plays()

      message(
        "Day ", current_day, ": Combined ", nrow(existing_data),
        " existing + ", nrow(daily_data), " new = ", nrow(combined_data),
        " total entries"
      )
    } else {
      combined_data <- daily_data
      message("Day ", current_day, ": New file with ", nrow(combined_data), " entries")
    }

    write_daily_csv(combined_data, file_path)
  }

  message("\nDaily parsing completed successfully!")
  message("Data is now stored in individual daily files in ./data/daily/")
  message("Schema includes track.id and artist.id when provided by Spotify.")
}
