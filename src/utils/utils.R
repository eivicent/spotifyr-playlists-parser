# Spotify Playlists Parser - Utility Functions
# Standardized functions for use across all .qmd files

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
  library(scales)
  library(ggiraph)
}

# ── Processed data loaders (fast, pre-aggregated) ────────────────────────────

# Daily summary: date, total_songs, unique_songs, unique_artists, repetition_kpi
load_daily_processed <- function() {
  path <- here("data", "processed", "daily.rds")
  if (!file.exists(path)) stop("daily.rds not found. Run src/scripts/process_data.R first.")
  readRDS(path) %>% arrange(date)
}

# Weekly summary: year_week, week_start, total_songs, unique_songs, unique_artists,
#   days_in_data, avg_songs_per_day, repetition_kpi, daily_cumulative (list-col)
load_weekly_processed <- function() {
  path <- here("data", "processed", "weekly.rds")
  if (!file.exists(path)) stop("weekly.rds not found. Run src/scripts/process_data.R first.")
  readRDS(path) %>% arrange(week_start)
}

# Monthly summary: year_month, total_songs, unique_songs, unique_artists,
#   days_in_data, avg_songs_per_day, avg_songs_per_week, repetition_kpi,
#   daily_cumulative (list-col)
load_monthly_processed <- function() {
  path <- here("data", "processed", "monthly.rds")
  if (!file.exists(path)) stop("monthly.rds not found. Run src/scripts/process_data.R first.")
  readRDS(path) %>% arrange(year_month)
}

# Discovery data: date, total_songs, new_artists, new_tracks,
#   discovery_artist_rate, discovery_track_rate,
#   cumulative_new_artists, cumulative_new_tracks
load_discovery <- function() {
  path <- here("data", "processed", "discovery.rds")
  if (!file.exists(path)) stop("discovery.rds not found. Run src/scripts/process_data.R first.")
  readRDS(path) %>% arrange(date)
}

# Intraday hourly: date, hour (0-23), total_plays, unique_tracks, unique_artists
load_intraday_hourly <- function() {
  path <- here("data", "processed", "intraday_hourly.rds")
  if (!file.exists(path)) stop("intraday_hourly.rds not found. Run src/scripts/process_data.R first.")
  readRDS(path) %>% arrange(date, hour)
}

# Sessions: date, session_id, session_start, session_start_hour,
#   session_songs, session_unique_tracks, session_unique_artists
load_sessions <- function() {
  path <- here("data", "processed", "sessions.rds")
  if (!file.exists(path)) stop("sessions.rds not found. Run src/scripts/process_data.R first.")
  readRDS(path) %>% arrange(date, session_id)
}

# Lifecycle: artist, first_listen, last_listen, total_plays, total_days,
#   max_gap_days, comeback_count, is_active, stickiness
load_lifecycle <- function() {
  path <- here("data", "processed", "lifecycle.rds")
  if (!file.exists(path)) stop("lifecycle.rds not found. Run src/scripts/process_data.R first.")
  readRDS(path) %>% arrange(desc(total_plays))
}

# ── Backwards-compatible aliases ─────────────────────────────────────────────

# Kept for any remaining callers; returns daily processed data with legacy
# column name `songs` mapped to `total_songs`.
load_daily_summary <- function() {
  load_daily_processed() %>%
    rename(songs = total_songs, unique_tracks = unique_songs)
}

load_daily_summary_simple <- function() {
  load_daily_processed() %>%
    select(date, songs = total_songs)
}

# ── Raw artist loader (used by artists.qmd) ───────────────────────────────────

get_daily_files <- function() {
  list.files(here("data", "daily"), pattern = "\\.csv$", full.names = TRUE)
}

read_daily_file_artist <- function(file_path) {
  if (!file.exists(file_path)) return(NULL)
  daily_data <- tryCatch(
    read.csv(file_path, sep = ";", stringsAsFactors = FALSE),
    error = function(e) NULL
  )
  if (is.null(daily_data) || nrow(daily_data) == 0) return(NULL)

  date_str <- basename(file_path) %>%
    stringr::str_remove("\\.csv$")

  if ("day" %in% colnames(daily_data) && !all(is.na(daily_data$day))) {
    daily_data$date <- as.Date(daily_data$day)
  } else if ("played_at" %in% colnames(daily_data)) {
    daily_data$date <- as.Date(substr(daily_data$played_at, 1, 10))
  } else {
    daily_data$date <- as.Date(date_str)
  }

  daily_data %>%
    dplyr::select(name, date, track.name) %>%
    dplyr::filter(!is.na(name), !is.na(date)) %>%
    dplyr::rename(song = track.name) %>%
    as_tibble()
}

load_artist_data <- function() {
  daily_files <- get_daily_files()
  purrr::map_dfr(daily_files, read_daily_file_artist) %>%
    dplyr::arrange(date) %>%
    dplyr::filter(!is.na(date), !is.na(name)) %>%
    dplyr::distinct() %>%
    dplyr::mutate(
      year_month     = lubridate::floor_date(date, "month"),
      year_month_str = format(year_month, "%Y-%m")
    )
}

# ── Weekday helper ────────────────────────────────────────────────────────────

add_weekday_info <- function(daily_summary) {
  daily_summary %>%
    dplyr::mutate(
      weekday     = lubridate::wday(date, label = TRUE, abbr = FALSE, week_start = 1),
      weekday_num = lubridate::wday(date, week_start = 1),
      year        = lubridate::year(date),
      week_num    = lubridate::week(date),
      year_week   = paste(year, sprintf("%02d", week_num), sep = "-W")
    ) %>%
    dplyr::mutate(
      weekday = factor(
        weekday,
        levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
      )
    )
}

# ── ggiraph helpers ───────────────────────────────────────────────────────────

# Standard girafe options for consistent interactivity across all charts
girafe_opts <- function() {
  list(
    opts_hover(css = "stroke-width:2;opacity:1;"),
    opts_hover_inv(css = "opacity:0.3;"),
    opts_tooltip(
      css = "background-color:#1e1e2e;color:#cdd6f4;padding:8px 12px;border-radius:6px;font-size:13px;",
      use_fill = FALSE
    )
  )
}

make_girafe <- function(gg, width_svg = 10, height_svg = 5) {
  girafe(
    ggobj    = gg,
    width_svg = width_svg,
    height_svg = height_svg,
    options  = girafe_opts()
  )
}
