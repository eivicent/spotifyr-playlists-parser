# Data processing runner — delegates to the targets pipeline defined in _targets.R.
# Run with: Rscript src/scripts/process_data.R
# Targets only re-runs compute functions whose inputs have changed.

library(targets)
tar_make()
