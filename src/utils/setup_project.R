# Setup script for Spotify Playlists Parser project
# This script ensures all necessary directories exist and are properly structured

setup_project_structure <- function() {
  # Define the directory structure
  dirs <- c(
    "src/scripts",
    "src/utils", 
    "data/daily",
    "data/weekly",
    "data/raw",
    "dashboard/templates",
    "dashboard/static",
    "dashboard/libs",
    "dashboard/figure-html",
    "config",
    "docs"
  )
  
  # Create directories if they don't exist
  for (dir in dirs) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE)
      cat("Created directory:", dir, "\n")
    } else {
      cat("Directory already exists:", dir, "\n")
    }
  }
  
  cat("\nProject structure setup complete!\n")
}

# Run setup if this script is executed directly
if (!interactive()) {
  setup_project_structure()
} 