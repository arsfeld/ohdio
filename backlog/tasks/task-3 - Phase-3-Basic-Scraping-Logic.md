---
id: task-3
title: 'Phase 3: Basic Scraping Logic'
status: Done
assignee:
  - '@claude'
created_date: '2025-10-10 18:41'
updated_date: '2025-10-10 19:01'
labels:
  - backend
  - scraping
  - http
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port Python scraping logic to pure Elixir using Req and Floki for OHdio category/audiobook pages and pass-through support for any yt-dlp compatible URL.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Category scraper detects and parses OHdio category pages
- [x] #2 Audiobook scraper extracts metadata from OHdio pages
- [x] #3 Playlist scraper extracts m3u8 URLs with fallback strategies
- [x] #4 URL detection logic routes to appropriate scraper or yt-dlp
- [x] #5 HTTP retry logic with exponential backoff implemented
- [x] #6 Tests written for each scraper module
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create lib/ohdio/scraper/ directory structure
2. Implement HTTP client module with Req, exponential backoff retry logic
3. Port CategoryScraper with Floki for HTML parsing
4. Port AudiobookScraper with metadata extraction using Floki
5. Port PlaylistExtractor (extract mediaId, call Radio-Canada API)
6. Implement URL detection router (OHdio vs yt-dlp passthrough)
7. Write ExUnit tests for each scraper module
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Summary

Ported Python scraping logic to pure Elixir, implementing the complete scraping subsystem for OHdio audiobooks.

## Implementation Details

### Created Modules

1. **HttpClient** (`lib/ohdio/scraper/http_client.ex`)
   - HTTP client using Req library
   - Exponential backoff retry logic (configurable max_retries and base_delay)
   - Handles 404, 429 (rate limiting), 5xx errors with appropriate retry strategies
   - Default headers matching Radio-Canada requirements

2. **PlaylistExtractor** (`lib/ohdio/scraper/playlist_extractor.ex`)
   - Extracts mediaId from HTML using multiple fallback strategies (regex patterns, data attributes, script tags)
   - Calls Radio-Canada media validation API to get m3u8 playlist URLs
   - Recursive search through API response to find playlist URLs

3. **CategoryScraper** (`lib/ohdio/scraper/category_scraper.ex`)
   - Scrapes OHdio category pages to discover audiobooks
   - Multiple parsing strategies: index-grid-items, book-items, livre-audio sections, generic links
   - Deduplicates results by URL
   - Extracts title, author, URL, thumbnail for each audiobook

4. **AudiobookScraper** (`lib/ohdio/scraper/audiobook_scraper.ex`)
   - Extracts comprehensive metadata from individual audiobook pages
   - Handles French-specific patterns ("Écrit par", "Lu par")
   - Cleans titles (removes " | ICI OHdio" suffixes)
   - Extracts: title, author, description, duration, genre, thumbnail, ISBN, publisher, narrator, series info
   - Defaults genre to "Jeunesse" and language to "fr"

5. **UrlDetector** (`lib/ohdio/scraper/url_detector.ex`)
   - Detects URL types: :ohdio_category, :ohdio_audiobook, :ytdlp_passthrough, :unknown
   - Routes to appropriate handler based on URL pattern
   - Supports common yt-dlp domains (YouTube, Vimeo, SoundCloud, etc.)

6. **Scraper Context** (`lib/ohdio/scraper.ex`)
   - Public API for scraping operations
   - Delegates to specialized modules
   - Clean interface for library and downloads contexts to use

### Testing

Created comprehensive test suites:
- `url_detector_test.exs` - Unit tests for URL detection logic
- `http_client_test.exs` - Integration tests using httpbin.org
- `playlist_extractor_test.exs` - Tests for mediaId extraction
- `category_scraper_test.exs` - Parser tests with sample HTML
- `audiobook_scraper_test.exs` - Metadata extraction tests

Tests use `:integration` tag for real HTTP requests, allowing CI to skip them if needed.

## Technical Decisions

- **Req over HTTPoison**: Following Phoenix best practices, used Req library with built-in retry support
- **Floki for HTML parsing**: Elixir-native HTML parser, equivalent to BeautifulSoup
- **Multiple fallback strategies**: HTML structure varies, so implemented multiple parsing methods to maximize success rate
- **Structured errors**: Return tagged tuples {:ok, result} / {:error, reason} for clean error handling

## Files Changed

- Created: `lib/ohdio/scraper.ex`
- Created: `lib/ohdio/scraper/http_client.ex`
- Created: `lib/ohdio/scraper/playlist_extractor.ex`
- Created: `lib/ohdio/scraper/category_scraper.ex`
- Created: `lib/ohdio/scraper/audiobook_scraper.ex`
- Created: `lib/ohdio/scraper/url_detector.ex`
- Created: `test/ohdio/scraper/url_detector_test.exs`
- Created: `test/ohdio/scraper/http_client_test.exs`
- Created: `test/ohdio/scraper/playlist_extractor_test.exs`
- Created: `test/ohdio/scraper/category_scraper_test.exs`
- Created: `test/ohdio/scraper/audiobook_scraper_test.exs`

## Next Steps

Scraping logic is complete and ready for integration with:
- Download workers (Phase 4)
- LiveView UI (Phases 5-7)

## Testing Instructions

Run tests with:
```bash
mix test                          # Unit tests only
mix test --only integration       # Include integration tests
```
<!-- SECTION:NOTES:END -->
