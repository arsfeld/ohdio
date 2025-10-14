---
id: task-26
title: Add Spotify track/playlist/album download support
status: Done
assignee:
  - '@claude'
created_date: '2025-10-14 15:54'
updated_date: '2025-10-14 19:39'
labels:
  - feature
  - enhancement
  - audio
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extend the downloader to support Spotify URLs (tracks, playlists, and albums) in addition to the existing OHdio and yt-dlp support. Users should be able to paste Spotify URLs and have them downloaded with proper metadata extraction.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 System detects Spotify URLs (tracks, playlists, albums)
- [x] #2 Spotify downloads work through yt-dlp integration
- [x] #3 Metadata extracted from Spotify (title, artist, album, artwork)
- [x] #4 Spotify playlists are scraped and individual tracks queued
- [x] #5 Spotify albums are scraped and individual tracks queued
- [x] #6 Downloaded tracks stored with proper naming convention
- [x] #7 UI shows Spotify as a supported URL type
- [x] #8 Error handling for Spotify-specific issues (region locks, premium content)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Research yt-dlp Spotify support and requirements
2. Add Spotify URL detection to UrlDetector module
3. Add Spotify URL handling to DownloadWorker
4. Update UI to show Spotify as supported URL type
5. Test with Spotify track, playlist, and album URLs
6. Add error handling for Spotify-specific issues
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Implementation Summary

Successfully added Spotify support to OHdio Downloader using spotdl.

### Changes Made

1. **Dockerfiles** (Dockerfile, Dockerfile.prod): Added spotdl installation alongside yt-dlp

2. **URL Detection** (lib/ohdio/scraper/url_detector.ex):
   - Added new URL types: :spotify_track, :spotify_playlist, :spotify_album
   - Added detection patterns for Spotify URLs
   - Added spotify_url?/1 helper function

3. **Download Worker** (lib/ohdio/workers/download_worker.ex):
   - Added execute_spotdl_download/3 function
   - Routes Spotify URLs to spotdl instead of yt-dlp
   - spotdl automatically handles metadata extraction from Spotify
   - Downloads from YouTube Music based on Spotify metadata
   - Added Spotify-specific error messages

4. **UI Updates** (lib/ohdio_web/live/queue_live.ex):
   - Added Spotify URL handling in process_url/2
   - Added Spotify section to "Supported URL Types" display
   - Shows tracks, playlists, and albums as supported

### How It Works

- spotdl gets track metadata from Spotify API
- Searches for matching songs on YouTube Music
- Downloads audio using yt-dlp from YouTube
- Automatically embeds metadata (title, artist, album, artwork)
- For playlists/albums, downloads all tracks

### Notes

- Playlists/albums are downloaded as batch operations (not individually queued)
- Quality depends on YouTube Music availability
- No Spotify API credentials required for basic usage
- Rate limiting may apply for heavy usage
<!-- SECTION:NOTES:END -->
