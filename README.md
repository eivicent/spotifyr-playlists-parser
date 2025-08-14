# Spotify Playlists Parser

A comprehensive project to parse and analyze personal Spotify playlists and store historical recommendations.

## Project Structure

```
spotifyr-playlists-parser/
├── src/                    # Source code
│   ├── scripts/           # R scripts for data processing
│   │   ├── daily_parsing.R
│   │   ├── daily_parsing_json.R
│   │   └── daily_parsing_original.R
│   └── utils/             # Utility functions
│       └── decrypt_secret.sh
├── data/                  # All data files
│   ├── daily/            # Daily listening data (CSV files)
│   ├── weekly/           # Weekly discover data (CSV files)
│   └── raw/              # Raw data files
├── dashboard/             # Dashboard files
│   ├── static/           # Static assets (CSS, JS, images)
│   ├── templates/        # HTML templates
│   │   ├── dashboard.html
│   │   └── dashboard.qmd
│   ├── libs/             # Library files
│   └── figure-html/      # Generated figures
├── config/               # Configuration files
│   ├── .httr-oauth       # OAuth credentials
│   └── my_secret.gpg     # Encrypted secrets
├── docs/                 # Documentation
│   ├── WORKFLOW_IMPROVEMENTS.md
│   └── IMPROVEMENTS_SUMMARY.md
├── .github/              # GitHub workflows
├── .gitignore
├── README.md
└── spotifyr-playlists-parser.Rproj
```

## Directory Descriptions

### `src/`
Contains all source code for the project:
- **`scripts/`**: R scripts for data processing and analysis
- **`utils/`**: Utility scripts and helper functions

### `data/`
Organized data storage:
- **`daily/`**: Daily listening history data in CSV format
- **`weekly/`**: Weekly discover playlist data in CSV format
- **`raw/`**: Raw data files before processing

### `dashboard/`
Dashboard and visualization components:
- **`templates/`**: HTML and Quarto templates for the dashboard
- **`static/`**: Static assets (CSS, JavaScript, images)
- **`libs/`**: External libraries and dependencies
- **`figure-html/`**: Generated figures and charts

### `config/`
Configuration and credential files:
- OAuth tokens for Spotify API
- Encrypted secret files

### `docs/`
Project documentation and improvement notes

## Getting Started

1. Ensure you have R and the required packages installed
2. Set up your Spotify API credentials in the `config/` directory
3. Run the data processing scripts from `src/scripts/`
4. Generate the dashboard using the templates in `dashboard/templates/`

## Data Processing

The project processes two main types of Spotify data:
- **Daily listening history**: Tracks your daily listening patterns
- **Weekly discover playlists**: Analyzes your weekly discover recommendations

## Dashboard

The dashboard provides visualizations and insights into your listening patterns and playlist recommendations.
