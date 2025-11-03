# My personal Spotify Listening Dashboard

A comprehensive dashboard for analyzing personal Spotify listening habits, built with Quarto and R.

## 🎵 Features

- **Summary**: Overview of your Spotify listening patterns and trends
- **Artists**: Top artists analysis and listening streaks

## 🚀 Live Dashboard

Visit the live dashboard: [https://eivicent.github.io/spotifyr-playlists-parser/](https://eivicent.github.io/spotifyr-playlists-parser/)

## 📊 Data Structure

The dashboard processes daily CSV files from your Spotify listening history:

```
data/
├── daily/           # Daily listening data (CSV files)
│   ├── 2023-08-08.csv
│   ├── 2023-08-09.csv
│   └── ...
└── weekly/          # Weekly discover data (CSV files)
```

Each daily CSV file contains:
- `played_at`: Timestamp when the song was played
- `track.name`: Name of the track
- `name`: Artist name
- `played`: Formatted timestamp
- `day`: Date of listening

## 🛠️ Technical Details

- **Framework**: Quarto (R Markdown)
- **Visualization**: ggplot2, gt tables
- **Deployment**: GitHub Pages with GitHub Actions
- **Styling**: Custom CSS with Spotify brand colors

## 📈 Dashboard Pages

1. **Summary**: Listening patterns, trends, and comprehensive statistics
2. **Artists**: Top artists, listening streaks, and artist analysis

## 🔧 Local Development

To run the dashboard locally:

1. Clone the repository
2. Install R and required packages
3. Run `quarto render` to build the site
4. Open `docs/index.html` in your browser

## 📝 License

This project is for personal use and educational purposes.