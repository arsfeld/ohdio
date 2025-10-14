---
id: task-26
title: Add Spotify track/playlist/album download support
status: To Do
assignee: []
created_date: '2025-10-14 15:54'
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
- [ ] #1 System detects Spotify URLs (tracks, playlists, albums)
- [ ] #2 Spotify downloads work through yt-dlp integration
- [ ] #3 Metadata extracted from Spotify (title, artist, album, artwork)
- [ ] #4 Spotify playlists are scraped and individual tracks queued
- [ ] #5 Spotify albums are scraped and individual tracks queued
- [ ] #6 Downloaded tracks stored with proper naming convention
- [ ] #7 UI shows Spotify as a supported URL type
- [ ] #8 Error handling for Spotify-specific issues (region locks, premium content)
<!-- AC:END -->
