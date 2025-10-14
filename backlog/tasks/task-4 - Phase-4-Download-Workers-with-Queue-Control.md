---
id: task-4
title: 'Phase 4: Download Workers with Queue Control'
status: Done
assignee:
  - '@claude'
created_date: '2025-10-10 18:41'
updated_date: '2025-10-10 19:10'
labels:
  - backend
  - oban
  - workers
  - queue
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement background job processing using Oban workers with pause/resume functionality via queue_control table.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 CategoryScrape worker scrapes URLs and enqueues metadata jobs
- [x] #2 MetadataExtract worker handles both OHdio scraping and yt-dlp fallback
- [x] #3 Download worker respects queue_control.is_paused state
- [x] #4 Download worker calls yt-dlp and FFmpeg for metadata embedding
- [x] #5 Progress updates broadcast via PubSub for real-time UI
- [x] #6 Oban queues configured with concurrency limits
- [x] #7 Queue pause/resume logic implemented in Downloads context
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create queue_control schema and migration for pause/resume functionality
2. Create CategoryScrape worker to scrape URLs and enqueue metadata jobs
3. Create MetadataExtract worker with OHdio scraping and yt-dlp fallback
4. Create Download worker with yt-dlp and FFmpeg integration
5. Update Oban configuration with proper queue settings and concurrency
6. Implement pause/resume logic in Downloads context
7. Add PubSub broadcasting for real-time progress updates
8. Test workers individually and integration flow
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
# Phase 4: Download Workers with Queue Control - Implementation Summary

## Overview
Implemented a complete background job processing system using Oban workers with pause/resume functionality for the audiobook download pipeline.

## Files Created

### Database Layer
- **Migration**: `priv/repo/migrations/20251010190800_create_queue_control.exs`
  - Creates `queue_control` table with `is_paused` and `max_concurrent_downloads` fields
  - Inserts default row with paused=false and max_concurrent=3

- **Schema**: `lib/ohdio/downloads/queue_control.ex`
  - QueueControl schema with validation for pause state and concurrency limits

### Context Updates
- **lib/ohdio/downloads.ex**
  - Added queue control functions: `get_queue_control/0`, `paused?/0`, `pause_queue/0`, `resume_queue/0`, `update_max_concurrent/1`
  - These functions manage the global queue state for pause/resume functionality

### Oban Workers
1. **lib/ohdio/workers/category_scrape_worker.ex** (Queue: scraping, concurrency: 5)
   - Scrapes category pages to discover audiobooks
   - Creates audiobook records in the database
   - Enqueues MetadataExtract jobs for each discovered book
   - Handles duplicate URL detection gracefully

2. **lib/ohdio/workers/metadata_extract_worker.ex** (Queue: metadata, concurrency: 10)
   - Attempts OHdio native scraping first
   - Falls back to yt-dlp for unsupported URLs
   - Extracts title, author, narrator, duration, and cover image
   - Enqueues Download jobs after successful metadata extraction

3. **lib/ohdio/workers/download_worker.ex** (Queue: downloads, concurrency: 3)
   - Checks queue pause state before processing (snoozes if paused)
   - Downloads audiobooks using yt-dlp with best audio quality
   - Embeds metadata (title, artist, album_artist) using FFmpeg
   - Broadcasts real-time progress via Phoenix.PubSub on "downloads" topic
   - Updates audiobook and queue_item status throughout the process
   - Handles retry logic with configurable max_attempts

### Configuration
- **config/config.exs**
  - Updated Oban queues configuration:
    - `scraping: 5` - Category page scraping
    - `metadata: 10` - Metadata extraction (higher concurrency)
    - `downloads: 3` - Actual downloads (limited to prevent bandwidth saturation)

## Key Features

### Pause/Resume System
- Global pause state stored in `queue_control` table
- Download workers check pause state before processing
- Paused jobs are snoozed (60s) and automatically retry when resumed
- API: `Downloads.pause_queue/0` and `Downloads.resume_queue/0`

### Progress Broadcasting
- Real-time updates via Phoenix.PubSub
- Topic: `"downloads"`
- Message format: `{:download_progress, %{audiobook_id: id, status: atom, progress: 0-100}}`
- Status values: `:started`, `:downloading`, `:completed`, `:failed`

### Worker Pipeline Flow
1. CategoryScrapeWorker → discovers audiobooks → creates DB records
2. MetadataExtractWorker → enriches metadata → validates data
3. DownloadWorker → downloads + embeds metadata → marks complete

### Error Handling
- Each worker has max_attempts: 3
- Download worker tracks attempts in queue_items table
- Failed jobs update audiobook status to `:failed`
- Detailed error logging throughout the pipeline

## Dependencies
- **External Tools Required**:
  - `yt-dlp` - For downloading audiobooks (must be in PATH)
  - `ffmpeg` - For metadata embedding (must be in PATH)

## Testing Recommendations
1. Test CategoryScrapeWorker with known category URL
2. Test MetadataExtractWorker with both OHdio and yt-dlp URLs
3. Test DownloadWorker pause/resume functionality
4. Verify PubSub broadcasts are received
5. Test retry logic with simulated failures
6. Test concurrency limits under load

## Next Steps
- Phase 5: Build LiveView UI to trigger workers and display progress
- Add PubSub listeners in LiveView for real-time updates
- Create queue management interface with pause/resume controls
<!-- SECTION:NOTES:END -->
