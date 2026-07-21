# Spotify Playlists Parser - Utility Functions
# Standardized functions for use across all .qmd files

source(here::here("src", "R", "daily_io.R"))

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

# ── Data coverage (missing days between first and last observed date) ─────────

#' Summarise calendar coverage from daily processed data.
#' @param daily tibble with a `date` column (from load_daily_processed())
compute_data_coverage <- function(daily) {
  dates <- sort(unique(as.Date(daily$date)))
  if (length(dates) == 0) {
    return(list(
      first_date = as.Date(NA),
      last_date = as.Date(NA),
      days_with_data = 0L,
      span_days = 0L,
      missing_days = 0L,
      coverage_pct = NA_real_,
      largest_gap_days = 0L,
      missing_dates = as.Date(character())
    ))
  }

  first_date <- min(dates)
  last_date <- max(dates)
  expected <- seq(first_date, last_date, by = "day")
  missing_dates <- as.Date(setdiff(expected, dates))

  gaps <- if (length(dates) < 2) {
    0L
  } else {
    as.integer(max(diff(as.integer(dates))) - 1L)
  }

  list(
    first_date = first_date,
    last_date = last_date,
    days_with_data = length(dates),
    span_days = length(expected),
    missing_days = length(missing_dates),
    coverage_pct = round(100 * length(dates) / length(expected), 1),
    largest_gap_days = max(gaps, 0L),
    missing_dates = missing_dates
  )
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
  daily_data <- read_daily_csv(file_path)
  if (nrow(daily_data) == 0) return(NULL)

  daily_data %>%
    dplyr::mutate(date = .data$day) %>%
    dplyr::select(
      name, date, track.name, track.id, artist.id,
      featured_artists, featured_artist_ids
    ) %>%
    dplyr::filter(!is.na(name), !is.na(date)) %>%
    dplyr::rename(song = track.name) %>%
    tibble::as_tibble()
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
