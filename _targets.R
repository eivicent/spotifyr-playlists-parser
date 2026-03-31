library(targets)
library(here)

source(here("src", "R", "pipeline_functions.R"))

# Pipeline:
# 1. csv_files tracks the input directory — always re-checked so new CSVs trigger downstream.
# 2. Each compute_* target produces a tibble; save_processed() writes to data/processed/.
# 3. format = "file" means targets tracks the output file hash — skips re-runs when
#    both inputs and outputs are unchanged.
# 4. _targets/ stores metadata only (gitignored); data/processed/ is the committed output.

list(
  tar_target(
    csv_files,
    list.files(here("data", "daily"), pattern = "\\.csv$", full.names = TRUE),
    cue = tar_cue(mode = "always")
  ),

  tar_target(file_df, get_file_df(csv_files)),

  tar_target(
    daily_file,
    save_processed(compute_daily(file_df), "daily"),
    format = "file"
  ),

  tar_target(
    weekly_file,
    save_processed(compute_weekly(file_df), "weekly"),
    format = "file"
  ),

  tar_target(
    monthly_file,
    save_processed(compute_monthly(file_df), "monthly"),
    format = "file"
  ),

  tar_target(
    discovery_file,
    save_processed(compute_discovery(file_df), "discovery"),
    format = "file"
  ),

  tar_target(
    intraday_hourly_file,
    save_processed(compute_intraday_hourly(file_df), "intraday_hourly"),
    format = "file"
  ),

  tar_target(
    sessions_file,
    save_processed(compute_sessions(file_df), "sessions"),
    format = "file"
  ),

  tar_target(
    lifecycle_file,
    save_processed(compute_lifecycle(file_df), "lifecycle"),
    format = "file"
  )
)
