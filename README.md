# OHdio Audiobook Downloader

A Python-based tool to scrape and download audiobooks from Radio-Canada's OHdio platform, specifically targeting the youth category (Jeunesse).

## Features

- **Web Scraping**: Automatically discovers audiobooks from the OHdio Jeunesse category
- **Playlist Detection**: Extracts m3u8 playlist URLs from audiobook pages
- **High-Quality Downloads**: Uses yt-dlp to download audio content as MP3 files
- **Metadata Embedding**: Automatically embeds book metadata including title, author, and artwork
- **Smart Naming**: Renames files with proper formatting based on book information
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
4. Test functionality: `uv run python test_ohdio.py --use-defaults`
5. Download a single audiobook: `uv run python main.py --url https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine`
6. Download all audiobooks: `uv run python main.py`

## Usage Examples

```bash
# Download a single audiobook
uv run python main.py --url https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine

# Download all audiobooks from the default Jeunesse category
uv run python main.py

# Use custom configuration
uv run python main.py --config my_config.json

# Enable debug logging
uv run python main.py --log-level DEBUG
```

## Testing

Use the dedicated test script to verify functionality without downloading:

```bash
# Run all tests with default URLs
uv run python test_ohdio.py --use-defaults

# Test category discovery (shows how many audiobooks found)
uv run python test_ohdio.py --test-category https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse

# Test skip existing logic (shows what would be downloaded vs skipped)
uv run python test_ohdio.py --test-skip https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse

# Test single URL extraction
uv run python test_ohdio.py --test-url https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine

# Test playlist extraction only
uv run python test_ohdio.py --test-playlist https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine

# Test complete pipeline (dry run)
uv run python test_ohdio.py --test-pipeline https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine
```

## Documentation

- [Product Guide](docs/PRODUCT_GUIDE.md) - Complete feature overview and usage instructions
- [Development Guide](docs/DEVELOPMENT_GUIDE.md) - Technical implementation details and development setup
- [Commit Guidelines](docs/COMMIT_GUIDELINES.md) - Git commit message standards with Angular convention and emojis

## Legal Notice

This tool is for educational purposes only. Please respect copyright laws and Radio-Canada's terms of service. Only download content you have the right to access.

## License

MIT License - see LICENSE file for details 