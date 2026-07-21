# My personal Spotify Listening Dashboard

Personal analytics over Spotify listening history: daily API scrape → aggregated tables → Quarto website on GitHub Pages.

**Live site:** [https://eivicent.github.io/spotifyr-playlists-parser/](https://eivicent.github.io/spotifyr-playlists-parser/)

This project is for personal use and educational purposes. Full listening history is stored in this public repo.

## Features

| Page | What it shows |
|------|----------------|
| **Home** | This-week glance, data coverage, recent trends |
| **Summary** | Songs/day trends, repetition KPI, diversity |
| **Monthly** | Month-over-month comparisons and seasonality |
| **Weekly Patterns** | Day-of-week patterns and weekly cumulatives |
| **Artists** | Top artists, streaks, diversity over time |
| **Discovery** | New artists/tracks and discovery rates |
| **Intraday** | Hour-of-day heatmap and listening sessions |
| **Lifecycle** | Artist stickiness, comebacks, drift |

## Pipeline

```text
Daily parsing (cron)  →  data/daily/YYYY-MM-DD.csv
        ↓
Process Data (targets) →  data/processed/*.rds
        ↓
Deploy Quarto site     →  GitHub Pages
```

1. **Daily parsing** (`.github/workflows/daily_parsing.yml`) — runs **3×/day** (`06:00`, `14:00`, `22:00` UTC), decrypts the OAuth token, calls Spotify Recently Played, appends/dedupes into per-day CSVs.
2. **Process Data** (`.github/workflows/process_data.yml`) — runs `targets` (`_targets.R` + `src/R/pipeline_functions.R`) and commits aggregates under `data/processed/`.
3. **Deploy** (`.github/workflows/deploy.yml`) — `quarto render` after Process Data succeeds, or when site source files change. The `docs/` output is built in CI only (not committed).

### Local development

```bash
# 1. Install R packages used by the site (see deploy.yml) plus targets / spotifyr as needed
# 2. Aggregate raw CSVs (requires data/daily/)
Rscript src/scripts/process_data.R

# 3. Render the site
quarto render

# 4. Open docs/index.html
```

Scraping locally also needs `secrets/my_secret` (see below) and Spotify app credentials in the environment.

## Data layout

```text
data/
├── daily/       # Per-day listening CSVs (source of truth)
├── processed/   # Aggregates produced by targets (*.rds)
└── weekly/      # Legacy Discover Weekly archives (kept; not used by the site)
```

### Daily CSV schema

Semicolon-separated, quoted. Shared reader/writer: `src/R/daily_io.R`.

| Column | Description |
|--------|-------------|
| `played_at` | Spotify timestamp |
| `track.name` | Track title |
| `track.id` | Spotify track ID (empty on older files) |
| `name` | Primary artist name |
| `artist.id` | Primary artist Spotify ID (empty on older files) |
| `featured_artists` | Additional artists, `\|`-separated (empty if solo / older files) |
| `featured_artist_ids` | Additional artist IDs, `\|`-separated (empty if solo / older files) |
| `played` | Parsed play time |
| `day` | Calendar date |

Charts and aggregates still key off the **primary** artist (`name` / `artist.id`). Featured columns are stored for collabs without changing existing top-artist logic.

Identity for analytics currently uses display names so historical rows without IDs stay continuous. `track.id` / `artist.id` are stored going forward for enrichment and a future ID-based key switch after backfill.

## Secrets & auth

GitHub Actions secrets:

- `SPOTIFY_CLIENT_ID` / `SPOTIFY_CLIENT_SECRET` — Spotify developer app
- `LARGE_SECRET_PASSPHRASE` — decrypts `config/my_secret.gpg` → `secrets/my_secret` (user OAuth token used by the scrape)

`secrets/` and `.httr-oauth` are gitignored. Do not commit plaintext tokens.

## Tech stack

- **R** + [`spotifyr`](https://github.com/charlie86/spotifyr), [`targets`](https://books.ropensci.org/targets/), tidyverse-ish stack
- **Quarto** website (`cosmo` theme, `styles.css`)
- **Viz:** ggplot2, ggiraph, gt, bslib value boxes
- **CI:** GitHub Actions → GitHub Pages
