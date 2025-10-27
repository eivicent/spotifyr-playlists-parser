# GitHub Pages Deployment Guide

## Prerequisites

1. **Quarto Installation**: Install Quarto from [quarto.org](https://quarto.org/docs/get-started/)
2. **R Packages**: Ensure required R packages are installed:
   ```r
   install.packages(c("tidyverse", "lubridate", "gt", "patchwork", "here", "shiny", "bslib"))
   ```

## Deployment Steps

### 1. Enable GitHub Pages

1. Go to your repository settings on GitHub
2. Navigate to "Pages" section
3. Set source to "GitHub Actions"

### 2. Build and Deploy

The GitHub Actions workflow (`.github/workflows/deploy.yml`) will automatically:
- Install Quarto
- Render the website
- Deploy to GitHub Pages

### 3. Manual Build (Local Testing)

```bash
# Install Quarto (if not already installed)
# Visit: https://quarto.org/docs/get-started/

# Render the site
quarto render

# Preview locally
quarto preview
```

## File Structure

```
├── _quarto.yml          # Quarto configuration
├── index.qmd           # Home page
├── dashboard.qmd       # Main dashboard
├── styles.css          # Custom styling
├── .github/
│   └── workflows/
│       └── deploy.yml  # GitHub Actions workflow
└── docs/               # Generated site (auto-created)
```

## Customization

- **Styling**: Edit `styles.css` for custom colors and layout
- **Content**: Modify `index.qmd` and `dashboard.qmd` for content changes
- **Configuration**: Update `_quarto.yml` for site settings

## Troubleshooting

- **Build Errors**: Check R package dependencies
- **Data Issues**: Verify CSV files are in `data/daily/` directory
- **Styling**: Ensure `styles.css` is properly linked in `_quarto.yml`
