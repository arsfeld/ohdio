---
title: OHdio Audiobook Downloader
emoji: 🎧
colorFrom: blue
colorTo: purple
sdk: gradio
sdk_version: 4.44.0
app_file: app.py
pinned: false
license: mit
---

# OHdio Audiobook Downloader

A Python-based tool to scrape and download audiobooks from Radio-Canada's OHdio platform, specifically targeting the youth category (Jeunesse).

## Features

- **Web UI**: Modern Gradio interface for downloading and managing audiobooks
- **Universal URL Support**: Download from OHdio URLs or any yt-dlp supported site (YouTube, Vimeo, SoundCloud, and 1000+ more)
- **Web Scraping**: Automatically discovers audiobooks from the OHdio Jeunesse category
- **Playlist Detection**: Extracts m3u8 playlist URLs from audiobook pages
- **High-Quality Downloads**: Uses yt-dlp to download audio content as MP3 files
- **Metadata Embedding**: Automatically embeds book metadata including title, author, and artwork
- **Smart Caching**: Skips already downloaded files to avoid re-downloading
- **File Browser**: Browse, search, play, and download audiobooks from the web interface
- **Docker Support**: Easy self-hosting with Docker and persistent volumes
- **Error Handling**: Robust error handling and retry mechanisms
- **Logging**: Comprehensive logging for debugging and monitoring

## Status

✅ **Complete** - The OHdio audiobook downloader is fully functional!

### Features Implemented
- ✅ Complete project structure and documentation
- ✅ Configuration system with JSON support
- ✅ Structured logging with JSON output
- ✅ Robust file and network utilities
- ✅ Multi-strategy playlist URL extraction
- ✅ Category page scraping with multiple parsing methods
- ✅ Individual audiobook metadata extraction
- ✅ Full yt-dlp integration with progress tracking
- ✅ Comprehensive metadata embedding with artwork
- ✅ Complete download pipeline orchestration
- ✅ Error handling and retry logic with exponential backoff
- ✅ Concurrent processing with rate limiting
- ✅ Progress tracking and statistics
- ✅ CLI interface with multiple modes

## Requirements

- Python 3.8+
- uv (modern Python package manager)
- Required Python packages (see pyproject.toml)

## Quick Start

1. Clone the repository
2. Install dependencies: `uv sync`
3. Test the setup: `uv run python test_setup.py`
4. Test functionality: `ohdio-test --use-defaults` (or `./test_ohdio.py --use-defaults`)
5. Download a single audiobook: `ohdio --url https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine`
6. Download all audiobooks: `ohdio`

## Web UI (Gradio)

OHdio now includes a web interface powered by Gradio! The web UI provides:
- 🎯 **Download Interface**: Download single audiobooks or entire categories
- 🌐 **Universal Downloads**: Paste any OHdio URL or any yt-dlp supported URL (YouTube, Vimeo, etc.)
- 📂 **File Browser**: Browse, search, play, and download audiobooks
- 📊 **Statistics Dashboard**: View download stats and storage usage
- 🔄 **Smart Caching**: Automatically skips already downloaded files

### ⚠️ Important Note about Hugging Face Spaces

Radio-Canada content is **geo-restricted to Canada**. The public Hugging Face Space runs on US servers and **cannot download OHdio audiobooks** due to this restriction. However, it can still download from other yt-dlp supported sites (YouTube, Vimeo, etc.).

For OHdio audiobooks, please run the application:
- **Locally** on your computer (if you're in Canada)
- **On a VPS/server** located in Canada
- **Via Docker** on your own infrastructure

### Running the Web UI Locally

```bash
# Install dependencies (includes Gradio)
uv sync

# Run the web interface
uv run python app.py
```

The web interface will be available at `http://localhost:7860`

### Running with Docker

The easiest way to self-host is using Docker:

```bash
# Build and run with docker compose (recommended)
docker compose up -d

# Or build manually
docker build -t ohdio-downloader .
docker run -p 7860:7860 -v ohdio-downloads:/data/downloads ohdio-downloader
```

Access the web interface at `http://localhost:7860`

**Docker Features:**
- ✅ Persistent storage for downloads (survives container restarts)
- ✅ Automatic restart on failure
- ✅ Health checks
- ✅ Optimized multi-stage build
- ✅ Non-root user for security

**Managing Docker Volumes:**

```bash
# View downloaded files
docker compose exec ohdio-web ls -lh /data/downloads

# Backup downloads
docker run --rm -v ohdio-downloads:/data -v $(pwd):/backup alpine tar czf /backup/ohdio-backup.tar.gz /data

# Access logs
docker compose logs -f ohdio-web

# Stop the service
docker compose down

# Stop and remove volumes (deletes all downloads!)
docker compose down -v
```

## CLI Usage Examples

The application can be run in three ways:
- **Recommended**: `ohdio` (command installed by uv)
- **Direct execution**: `./main.py` (requires executable permission)
- **Via uv**: `uv run python main.py` (always works)

```bash
# Download a single audiobook
ohdio --url https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine
# or: ./main.py --url https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine

# Download all audiobooks from the default Jeunesse category
ohdio
# or: ./main.py

# Use custom configuration
ohdio --config my_config.json --log-level DEBUG

# Alternative: use uv run (no installation needed)
uv run python main.py --url https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine
```

## Testing

Use the dedicated test script to verify functionality without downloading.

The test script can be run in three ways:
- **Recommended**: `ohdio-test` (command installed by uv)
- **Direct execution**: `./test_ohdio.py` (requires executable permission)
- **Via uv**: `uv run python test_ohdio.py` (always works)

```bash
# Run all tests with default URLs
ohdio-test --use-defaults
# or: ./test_ohdio.py --use-defaults

# Test category discovery (shows how many audiobooks found)
ohdio-test --test-category https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse

# Test skip existing logic (shows what would be downloaded vs skipped)
ohdio-test --test-skip https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse

# Test single URL extraction
ohdio-test --test-url https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine

# Test playlist extraction only
ohdio-test --test-playlist https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine

# Test complete pipeline (dry run)
ohdio-test --test-pipeline https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine

# Alternative: use uv run (no installation needed)
uv run python test_ohdio.py --use-defaults
```

## Documentation

- [Product Guide](docs/PRODUCT_GUIDE.md) - Complete feature overview and usage instructions
- [Development Guide](docs/DEVELOPMENT_GUIDE.md) - Technical implementation details and development setup
- [Commit Guidelines](docs/COMMIT_GUIDELINES.md) - Git commit message standards with Angular convention and emojis

## Legal Notice

This tool is for educational purposes only. Please respect copyright laws and Radio-Canada's terms of service. Only download content you have the right to access.

## License

MIT License - see LICENSE file for details 