# Shared daily CSV I/O
# Single schema + reader/writer for scrape, pipeline, and Quarto pages.
#
# Schema (semicolon-separated, quoted):
#   played_at, track.name, track.id, name, artist.id,
#   featured_artists, featured_artist_ids, played, day
#
# Older files may omit newer columns — normalize_daily_df() fills NA.
# Featured multi-values use "|" so they stay unambiguous inside ";"-CSVs.

DAILY_CSV_COLS <- c(
  "played_at", "track.name", "track.id", "name", "artist.id",
  "featured_artists", "featured_artist_ids", "played", "day"
)

FEATURED_SEP <- "|"

#' Ensure a daily tibble has the full schema and typed played/day columns.
normalize_daily_df <- function(df, file_path = NULL) {
  if (is.null(df) || nrow(df) == 0) {
    return(empty_daily_df())
  }

  df <- as.data.frame(df, stringsAsFactors = FALSE)

  # Legacy files sometimes lack newer columns; never overwrite by position.
  for (col in DAILY_CSV_COLS) {
    if (!col %in% names(df)) {
      df[[col]] <- NA_character_
    }
  }

  df <- df[DAILY_CSV_COLS]

  char_cols <- c(
    "played_at", "track.name", "track.id", "name", "artist.id",
    "featured_artists", "featured_artist_ids"
  )
  for (col in char_cols) {
    df[[col]] <- as.character(df[[col]])
  }

  df$played <- as.POSIXct(df$played, tz = "GMT")
  df$day <- as.Date(df$day)

  # If day is missing, recover from filename or played_at
  if (all(is.na(df$day)) && !is.null(file_path)) {
    date_str <- sub("\\.csv$", "", basename(file_path))
    parsed <- as.Date(date_str)
    if (!is.na(parsed)) df$day <- parsed
  }
  if (any(is.na(df$day))) {
    from_played <- as.Date(substr(df$played_at, 1, 10))
    missing <- is.na(df$day)
    df$day[missing] <- from_played[missing]
  }

  df
}

empty_daily_df <- function() {
  data.frame(
    played_at = character(),
    track.name = character(),
    track.id = character(),
    name = character(),
    artist.id = character(),
    featured_artists = character(),
    featured_artist_ids = character(),
    played = as.POSIXct(double(), origin = "1970-01-01", tz = "GMT"),
    day = as.Date(double(), origin = "1970-01-01"),
    stringsAsFactors = FALSE
  )
}

#' Read one daily CSV into the normalized schema. Returns empty df on failure.
read_daily_csv <- function(file_path) {
  if (!file.exists(file_path)) {
    return(empty_daily_df())
  }

  tryCatch({
    df <- utils::read.table(
      file_path,
      sep = ";",
      stringsAsFactors = FALSE,
      encoding = "UTF-8",
      quote = "\"",
      na.strings = c("", "NA"),
      header = TRUE,
      check.names = FALSE
    )
    normalize_daily_df(df, file_path = file_path)
  }, error = function(e) {
    message("Warning: Could not read ", file_path, " — ", conditionMessage(e))
    empty_daily_df()
  })
}

#' Write a daily CSV with the canonical schema and quoting.
#' On failure, falls back to an .rds sibling (not committed by CI).
write_daily_csv <- function(df, file_path) {
  df <- normalize_daily_df(df, file_path = file_path)

  # Persist played/day as character for stable CSV round-trips
  out <- df
  out$played <- as.character(out$played)
  out$day <- as.character(out$day)
  out <- out[DAILY_CSV_COLS]

  tryCatch({
    utils::write.table(
      out,
      file = file_path,
      row.names = FALSE,
      sep = ";",
      quote = TRUE,
      fileEncoding = "UTF-8",
      na = "",
      col.names = TRUE
    )
    message("Successfully wrote ", nrow(out), " entries to ", file_path)
    invisible(file_path)
  }, error = function(e) {
    message("Error writing to ", file_path, " — ", conditionMessage(e))
    backup_file <- sub("\\.csv$", ".rds", file_path)
    saveRDS(df, backup_file)
    message("Saved backup as RDS: ", backup_file)
    invisible(backup_file)
  })
}

#' Deduplicate plays, preferring rows that already have Spotify IDs.
dedupe_daily_plays <- function(df) {
  df <- normalize_daily_df(df)
  if (nrow(df) == 0) return(df)

  df %>%
    dplyr::arrange(
      .data$played_at,
      dplyr::desc(!is.na(.data$track.id) & .data$track.id != ""),
      dplyr::desc(!is.na(.data$artist.id) & .data$artist.id != ""),
      dplyr::desc(!is.na(.data$featured_artists) & .data$featured_artists != "")
    ) %>%
    dplyr::distinct(.data$played_at, .keep_all = TRUE)
}

#' Stable identity keys: prefer Spotify IDs, fall back to display names.
track_key <- function(df) {
  tid <- if ("track.id" %in% names(df)) as.character(df$track.id) else NA_character_
  tname <- as.character(df$track.name)
  dplyr::coalesce(dplyr::na_if(tid, ""), tname)
}

artist_key <- function(df) {
  aid <- if ("artist.id" %in% names(df)) as.character(df$artist.id) else NA_character_
  aname <- as.character(df$name)
  dplyr::coalesce(dplyr::na_if(aid, ""), aname)
}

#' Join featured artist names/ids with FEATURED_SEP; NA if none.
collapse_featured <- function(values) {
  values <- as.character(values)
  values <- values[!is.na(values) & values != ""]
  if (length(values) == 0) return(NA_character_)
  paste(values, collapse = FEATURED_SEP)
}
