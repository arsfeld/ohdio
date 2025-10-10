---
id: task-3
title: 'Phase 3: Basic Scraping Logic'
status: To Do
assignee: []
created_date: '2025-10-10 18:41'
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
- [ ] #1 Category scraper detects and parses OHdio category pages
- [ ] #2 Audiobook scraper extracts metadata from OHdio pages
- [ ] #3 Playlist scraper extracts m3u8 URLs with fallback strategies
- [ ] #4 URL detection logic routes to appropriate scraper or yt-dlp
- [ ] #5 HTTP retry logic with exponential backoff implemented
- [ ] #6 Tests written for each scraper module
<!-- AC:END -->
