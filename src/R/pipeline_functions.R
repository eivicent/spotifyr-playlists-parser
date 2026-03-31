# Pipeline Functions
# Pure compute functions used by _targets.R (and optionally process_data.R).
# Each function takes a file_df tibble (path, date) and returns a tibble.
# No side effects — no saveRDS() calls.

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(tidyr)
  library(stringr)
  library(lubridate)
  library(here)
})

# ── Raw file helpers ──────────────────────────────────────────────────────────

#' Build a tibble of all daily CSV paths and their dates.
get_file_df <- function(csv_files = NULL) {
  if (is.null(csv_files)) {
    csv_files <- list.files(here("data", "daily"), pattern = "\\.csv$", full.names = TRUE)
  }
  tibble(
    path = csv_files,
    date = as.Date(str_remove(basename(csv_files), "\\.csv$"))
  ) %>%
    filter(!is.na(date)) %>%
    arrange(date)
}

#' Read a single daily CSV; attaches file_date column.
read_raw_day <- function(file_path) {
  date_str <- basename(file_path) %>% str_remove("\\.csv$")
  df <- tryCatch(
    read.csv(file_path, sep = ";", stringsAsFactors = FALSE),
    error = function(e) NULL
  )
  if (is.null(df) || nrow(df) == 0) return(NULL)
  df$file_date <- as.Date(date_str)
  as_tibble(df)
}

#' Read and bind all files for a period into one tibble.
read_raw_period <- function(period_file_df) {
  map_dfr(period_file_df$path, read_raw_day) %>%
    filter(!is.na(file_date), !is.na(track.name))
}

# ── Diversity helpers ─────────────────────────────────────────────────────────

#' Shannon entropy of artist distribution. Higher = more varied mix.
shannon_diversity <- function(artist_vec) {
  counts <- table(artist_vec[!is.na(artist_vec)])
  if (length(counts) == 0) return(NA_real_)
  p <- counts / sum(counts)
  round(-sum(p * log(p)), 4)
}

#' Fraction of plays by top-5 artists. Lower = more diverse.
concentration_top5 <- function(artist_vec) {
  counts <- sort(table(artist_vec[!is.na(artist_vec)]), decreasing = TRUE)
  if (length(counts) == 0) return(NA_real_)
  round(sum(head(counts, 5)) / sum(counts), 4)
}

# ── Per-period cumulative unique tracks ───────────────────────────────────────

cum_unique_tracks_by_day <- function(raw_period) {
  if (nrow(raw_period) == 0) return(tibble())
  raw_period %>%
    group_by(date = file_date) %>%
    summarise(tracks = list(unique(track.name)), .groups = "drop") %>%
    arrange(date) %>%
    mutate(
      cum_unique_tracks = accumulate(tracks, union) %>% map_int(length),
      day_of_period     = row_number()
    ) %>%
    select(date, day_of_period, cum_unique_tracks)
}

# ── save helper ───────────────────────────────────────────────────────────────

#' Save a tibble to data/processed/<name>.rds and return the file path.
#' Used by _targets.R with format = "file".
save_processed <- function(data, name) {
  path <- here("data", "processed", paste0(name, ".rds"))
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  saveRDS(data, path)
  path
}

# ── 1. compute_daily ─────────────────────────────────────────────────────────

#' One row per day: total_songs, unique_songs, unique_artists, repetition_kpi.
compute_daily <- function(file_df) {
  map_dfr(file_df$path, function(p) {
    df <- read_raw_day(p)
    if (is.null(df)) return(NULL)
    tibble(
      date           = unique(df$file_date),
      total_songs    = nrow(df),
      unique_songs   = n_distinct(df$track.name),
      unique_artists = n_distinct(df$name),
      repetition_kpi = round(nrow(df) / n_distinct(df$track.name), 3)
    )
  }) %>% arrange(date)
}

# ── 2. compute_weekly ─────────────────────────────────────────────────────────

#' One row per ISO week: summary stats + shannon_diversity + concentration_top5
#' + daily_cumulative list-column.
compute_weekly <- function(file_df) {
  file_df_w <- file_df %>%
    mutate(week_start = floor_date(date, "week", week_start = 1))

  map(sort(unique(file_df_w$week_start)), function(ws) {
    wk_files <- file_df_w %>% filter(week_start == ws)
    raw      <- read_raw_period(wk_files)
    if (nrow(raw) == 0) return(NULL)
    n_days <- n_distinct(raw$file_date)
    tibble(
      year_week         = paste0(year(ws), "-W", sprintf("%02d", isoweek(ws))),
      week_start        = ws,
      total_songs       = nrow(raw),
      unique_songs      = n_distinct(raw$track.name),
      unique_artists    = n_distinct(raw$name),
      days_in_data      = n_days,
      avg_songs_per_day = round(nrow(raw) / n_days, 2),
      repetition_kpi    = round(nrow(raw) / n_distinct(raw$track.name), 3),
      shannon_diversity = shannon_diversity(raw$name),
      concentration_top5 = concentration_top5(raw$name),
      daily_cumulative  = list(cum_unique_tracks_by_day(raw))
    )
  }) %>%
    compact() %>%
    bind_rows() %>%
    arrange(week_start)
}

# ── 3. compute_monthly ────────────────────────────────────────────────────────

#' One row per month: summary stats + shannon_diversity + concentration_top5
#' + daily_cumulative list-column.
compute_monthly <- function(file_df) {
  file_df_m <- file_df %>%
    mutate(year_month = floor_date(date, "month"))

  map(sort(unique(file_df_m$year_month)), function(ym) {
    mo_files <- file_df_m %>% filter(year_month == ym)
    raw      <- read_raw_period(mo_files)
    if (nrow(raw) == 0) return(NULL)
    n_days  <- n_distinct(raw$file_date)
    n_weeks <- n_distinct(floor_date(raw$file_date, "week", week_start = 1))
    tibble(
      year_month         = ym,
      total_songs        = nrow(raw),
      unique_songs       = n_distinct(raw$track.name),
      unique_artists     = n_distinct(raw$name),
      days_in_data       = n_days,
      avg_songs_per_day  = round(nrow(raw) / n_days, 2),
      avg_songs_per_week = round(nrow(raw) / max(n_weeks, 1), 2),
      repetition_kpi     = round(nrow(raw) / n_distinct(raw$track.name), 3),
      shannon_diversity  = shannon_diversity(raw$name),
      concentration_top5 = concentration_top5(raw$name),
      daily_cumulative   = list(cum_unique_tracks_by_day(raw))
    )
  }) %>%
    compact() %>%
    bind_rows() %>%
    arrange(year_month)
}

# ── 4. compute_discovery ──────────────────────────────────────────────────────

#' One row per day: new_artists, new_tracks, discovery rates, cumulative totals.
#' Processes all files sequentially to track first-ever appearances.
compute_discovery <- function(file_df) {
  seen <- list(artists = character(0), tracks = character(0))

  rows <- map(seq_len(nrow(file_df)), function(i) {
    df <- read_raw_day(file_df$path[i])
    if (is.null(df)) return(NULL)

    day_artists <- unique(df$name[!is.na(df$name)])
    day_tracks  <- unique(df$track.name[!is.na(df$track.name)])

    new_artists <- setdiff(day_artists, seen$artists)
    new_tracks  <- setdiff(day_tracks,  seen$tracks)

    seen$artists <<- union(seen$artists, day_artists)
    seen$tracks  <<- union(seen$tracks,  day_tracks)

    tibble(
      date                  = unique(df$file_date),
      total_songs           = nrow(df),
      new_artists           = length(new_artists),
      new_tracks            = length(new_tracks),
      discovery_artist_rate = round(length(new_artists) / max(nrow(df), 1), 4),
      discovery_track_rate  = round(length(new_tracks)  / max(nrow(df), 1), 4)
    )
  }) %>%
    compact() %>%
    bind_rows() %>%
    arrange(date) %>%
    mutate(
      cumulative_new_artists = cumsum(new_artists),
      cumulative_new_tracks  = cumsum(new_tracks)
    )

  rows
}

# ── 5. compute_intraday_hourly ────────────────────────────────────────────────

#' One row per (date, hour): total_plays, unique_tracks, unique_artists.
#' Parses played_at timestamps to extract hour of day.
compute_intraday_hourly <- function(file_df) {
  map_dfr(file_df$path, function(p) {
    df <- read_raw_day(p)
    if (is.null(df)) return(NULL)
    if (!"played_at" %in% names(df)) return(NULL)
    df %>%
      mutate(
        played_dt = ymd_hms(played_at, quiet = TRUE),
        hour      = hour(played_dt)
      ) %>%
      filter(!is.na(played_dt)) %>%
      group_by(date = file_date, hour) %>%
      summarise(
        total_plays    = n(),
        unique_tracks  = n_distinct(track.name),
        unique_artists = n_distinct(name),
        .groups        = "drop"
      )
  }) %>%
    arrange(date, hour)
}

# ── 6. compute_sessions ───────────────────────────────────────────────────────

#' One row per listening session: session_id, date, start_hour, songs, unique tracks/artists.
#' Sessions: consecutive plays with gap <= 30 minutes. A new day always starts a new session.
compute_sessions <- function(file_df) {
  map_dfr(file_df$path, function(p) {
    df <- read_raw_day(p)
    if (is.null(df)) return(NULL)
    if (!"played_at" %in% names(df)) return(NULL)
    df %>%
      mutate(played_dt = ymd_hms(played_at, quiet = TRUE)) %>%
      filter(!is.na(played_dt)) %>%
      arrange(played_dt) %>%
      mutate(
        gap_minutes = as.numeric(difftime(played_dt, lag(played_dt), units = "mins")),
        new_session = is.na(gap_minutes) | gap_minutes > 30,
        session_id  = cumsum(new_session)
      )
  }) %>%
    group_by(file_date, session_id) %>%
    summarise(
      session_start        = min(played_dt),
      session_start_hour   = hour(min(played_dt)),
      session_songs        = n(),
      session_unique_tracks  = n_distinct(track.name),
      session_unique_artists = n_distinct(name),
      .groups              = "drop"
    ) %>%
    rename(date = file_date) %>%
    arrange(date, session_id)
}

# ── 7. compute_lifecycle ──────────────────────────────────────────────────────

#' One row per artist: listening lifecycle stats.
#' Fully recomputed on every run (fast at ~3700 artists).
compute_lifecycle <- function(file_df) {
  # Load all raw artist-level plays
  all_plays <- map_dfr(file_df$path, function(p) {
    df <- read_raw_day(p)
    if (is.null(df)) return(NULL)
    df %>%
      filter(!is.na(name)) %>%
      select(artist = name, date = file_date)
  }) %>%
    distinct() %>%
    arrange(artist, date)

  max_date <- max(all_plays$date, na.rm = TRUE)

  # Per-artist gap analysis for comeback detection
  artist_stats <- all_plays %>%
    group_by(artist) %>%
    arrange(date, .by_group = TRUE) %>%
    summarise(
      first_listen = min(date),
      last_listen  = max(date),
      total_days   = n_distinct(date),
      # Max gap between consecutive listen-days
      max_gap_days = {
        d <- sort(unique(date))
        if (length(d) < 2) 0L else as.integer(max(diff(as.integer(d))))
      },
      # Comebacks: number of gaps > 90 days that were followed by a return
      comeback_count = {
        d <- sort(unique(date))
        if (length(d) < 2) 0L else sum(diff(as.integer(d)) > 90)
      },
      .groups = "drop"
    )

  # total_plays from raw (counting every song play, not just unique days)
  total_plays <- map_dfr(file_df$path, function(p) {
    df <- read_raw_day(p)
    if (is.null(df)) return(NULL)
    df %>% filter(!is.na(name)) %>% select(artist = name)
  }) %>%
    count(artist, name = "total_plays")

  artist_stats %>%
    left_join(total_plays, by = "artist") %>%
    mutate(
      total_plays = coalesce(total_plays, 0L),
      span_days   = as.integer(last_listen - first_listen) + 1L,
      stickiness  = round(total_days / span_days, 4),
      is_active   = last_listen >= max_date - days(30)
    ) %>%
    select(
      artist, first_listen, last_listen, total_plays, total_days,
      max_gap_days, comeback_count, is_active, stickiness
    ) %>%
    arrange(desc(total_plays))
}
