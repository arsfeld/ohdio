# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OHdio Audiobook Downloader is a Python-based web scraper and downloader for Radio-Canada's OHdio platform audiobooks. It uses BeautifulSoup for scraping, yt-dlp for downloading m3u8 playlists, and mutagen for metadata embedding.

## Development Commands

### Environment Setup
```bash
# Install dependencies (creates .venv automatically)
uv sync

# Install with development dependencies
uv sync --dev
```

### Running the Application
```bash
# Run main application (download all audiobooks from Jeunesse category)
uv run python main.py

# Download single audiobook
uv run python main.py --url <audiobook-url>

# Custom configuration
uv run python main.py --config my_config.json --log-level DEBUG
```

### Testing
```bash
# Run comprehensive tests (includes all test modes)
uv run python test_ohdio.py --use-defaults

# Test category scraping (discovery only)
uv run python test_ohdio.py --test-category <category-url>

# Test single audiobook metadata extraction
uv run python test_ohdio.py --test-url <audiobook-url>

# Test playlist extraction
uv run python test_ohdio.py --test-playlist <audiobook-url>

# Test skip-existing logic
uv run python test_ohdio.py --test-skip <category-url>

# Test complete download pipeline (dry run)
uv run python test_ohdio.py --test-pipeline <audiobook-url>

# Verify setup and dependencies
uv run python test_setup.py
```

### Code Quality (if dev dependencies installed)
```bash
# Format code
uv run black src/ tests/

# Run linter
uv run flake8 src/ tests/

# Type checking
uv run mypy src/

# Run all pre-commit checks
uv run pre-commit run --all-files
```

## Architecture

### Component Structure
```
src/
├── scraper/           # Web scraping components
│   ├── category_scraper.py    # Discovers audiobooks from category page
│   ├── audiobook_scraper.py   # Extracts metadata from individual pages
│   └── playlist_extractor.py  # Finds m3u8 playlist URLs
├── downloader/        # Download and metadata management
│   ├── ytdlp_downloader.py    # yt-dlp wrapper for downloads
│   └── metadata_manager.py    # Embeds ID3 tags with mutagen
├── utils/             # Shared utilities
│   ├── config.py              # Configuration management (dataclass)
│   ├── logger.py              # Structured logging with JSON support
│   ├── file_utils.py          # File operations and sanitization
│   └── network_utils.py       # HTTP utilities with retry logic
└── main.py            # Application entry point with OHdioDownloader class
```

### Key Design Patterns

**Async/Concurrent Processing**: Uses asyncio with semaphores to control concurrent downloads (`max_concurrent_downloads` in config). The main orchestrator in `src/main.py` manages task scheduling.

**Multi-Strategy Parsing**: Category and audiobook scrapers use multiple fallback parsing methods to handle different page structures. Each parser tries various CSS selectors and regex patterns.

**Retry Logic**: Network requests use exponential backoff retry logic (configured via `retry_attempts` and `delay_between_requests`).

**Configuration-Driven**: All behavior controlled through `config.json` (loaded via `Config.from_file()`). Configuration uses dataclass with validation.

## Important Implementation Details

### Scraping Strategy

The scrapers use multiple parsing methods in priority order. For example, `category_scraper.py` tries:
1. `_parse_index_grid_items()` - OHdio-specific grid layout
2. `_parse_book_items()` - Common CSS selectors
3. `_parse_livre_audio_sections()` - Text-based search
4. `_parse_generic_links()` - Fallback URL extraction

Each method is wrapped in try-except to allow graceful fallback.

### Playlist Extraction

`playlist_extractor.py` searches for m3u8 URLs using multiple strategies:
- JavaScript variable extraction from `<script>` tags
- Regex pattern matching for various URL formats
- Special handling for Radio-Canada's CDN patterns

### Download Pipeline

1. `CategoryScraper` discovers audiobooks → List[AudiobookInfo]
2. `AudiobookScraper` extracts detailed metadata → AudiobookMetadata
3. Check if file exists (if `skip_existing=True`)
4. `YtDlpDownloader` downloads using yt-dlp with FFmpeg post-processing
5. `MetadataManager` embeds ID3 tags (title, author, artwork, etc.)

Downloads are orchestrated by `OHdioDownloader` in `src/main.py` with concurrent task management.

### Error Handling

- Network errors: Automatic retry with exponential backoff via `safe_request()` in `network_utils.py`
- Parsing errors: Multiple fallback strategies, graceful degradation
- Download errors: Logged but don't stop batch processing
- All errors logged with context (book title/author) via `LoggingContext`

## Configuration

Configuration is loaded from `config.json` (JSON format):
- `output_directory`: Where to save downloads (default: "downloads")
- `max_concurrent_downloads`: Concurrent download limit (default: 3)
- `retry_attempts`: Number of retries for failed operations (default: 3)
- `delay_between_requests`: Rate limiting delay in seconds (default: 1.0)
- `audio_quality`: Quality setting for yt-dlp (default: "best")
- `embed_metadata`: Whether to embed ID3 tags (default: true)
- `skip_existing`: Skip files that already exist (default: true)
- `user_agent`: User agent string for HTTP requests

## Common Tasks

### Adding New Metadata Field
1. Add field to `AudiobookMetadata` dataclass in `audiobook_scraper.py`
2. Add extraction method in `AudiobookScraper` class
3. Update `_extract_metadata()` to call new method
4. Update `MetadataManager.embed_metadata()` to write new ID3 tag

### Adding New Parsing Method
1. Add method to `CategoryScraper` or `AudiobookScraper` class
2. Add to `parsing_methods` list in appropriate `_parse_*()` method
3. Methods should return List[AudiobookInfo] or raise exceptions

### Debugging Scraping Issues
1. Run with `--log-level DEBUG` for detailed output
2. Use test scripts to isolate issue: `test_ohdio.py --test-url <url>`
3. Check logs in `logs/` directory for structured JSON logs
4. Examine HTML structure with browser DevTools to identify new selectors

## Dependencies

**Core Runtime**:
- Python 3.8+
- requests, beautifulsoup4, lxml - Web scraping
- yt-dlp - Media download engine
- mutagen - Audio metadata (ID3 tags)
- aiohttp - Async HTTP operations
- Pillow - Image processing for artwork

**Dev Tools** (optional):
- pytest, pytest-asyncio - Testing
- black - Code formatting
- flake8 - Linting
- mypy - Type checking
- pre-commit - Git hooks

## Notes

- This tool is for educational purposes only and must respect Radio-Canada's terms of service
- The default target is the Jeunesse (youth) audiobook category at `https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse`
- Files are named as `{Author} - {Title}.mp3` with sanitization for filesystem safety
- Logs are written to `logs/` directory with both human-readable and JSON formats
- Downloads are saved to `downloads/` by default
- The application uses structured logging with context (book title, author, phase) for debugging
