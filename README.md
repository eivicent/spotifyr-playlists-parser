# Spotify Listening Dashboard

A comprehensive dashboard for analyzing personal Spotify listening habits, built with Quarto and R.

## 🎵 Features

- **Daily Listening Patterns**: Track your daily song consumption over time
- **Monthly Summaries**: Analyze monthly trends and averages  
- **Weekly Patterns**: Discover your listening habits by day of the week
- **Recent Activity**: View your most recent listening activity
- **Comprehensive Statistics**: Detailed metrics about your listening behavior

## 🚀 Live Dashboard

Visit the live dashboard: [https://vicent.boned.github.io/spotifyr-playlists-parser/](https://vicent.boned.github.io/spotifyr-playlists-parser/)

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

## 📈 Dashboard Sections

1. **Value Boxes**: Key statistics at a glance
2. **Daily Song Count**: Time series visualization
3. **Monthly Summary**: Trends and averages by month
4. **Weekly Patterns**: Day-of-week analysis
5. **Recent Activity**: Last 30 days of listening
6. **Summary Statistics**: Comprehensive metrics

## 🔧 Local Development

To run the dashboard locally:

1. Clone the repository
2. Install R and required packages
3. Run `quarto render` to build the site
4. Open `docs/index.html` in your browser

## 📝 License

This project is for personal use and educational purposes.