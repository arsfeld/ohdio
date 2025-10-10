---
id: task-4
title: 'Phase 4: Download Workers with Queue Control'
status: To Do
assignee: []
created_date: '2025-10-10 18:41'
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
- [ ] #1 CategoryScrape worker scrapes URLs and enqueues metadata jobs
- [ ] #2 MetadataExtract worker handles both OHdio scraping and yt-dlp fallback
- [ ] #3 Download worker respects queue_control.is_paused state
- [ ] #4 Download worker calls yt-dlp and FFmpeg for metadata embedding
- [ ] #5 Progress updates broadcast via PubSub for real-time UI
- [ ] #6 Oban queues configured with concurrency limits
- [ ] #7 Queue pause/resume logic implemented in Downloads context
<!-- AC:END -->
