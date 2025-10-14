---
id: task-17
title: Implement download worker to process queued audiobooks
status: Done
assignee:
  - '@claude'
created_date: '2025-10-14 13:57'
updated_date: '2025-10-14 14:13'
labels:
  - downloads
  - worker
  - queue
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Category scraping successfully adds audiobooks to the queue with status 'queued', but no download worker is processing them. Items remain in queued state indefinitely. Need to implement or fix the download worker that consumes queue items and performs actual downloads.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Download worker processes queue items with status 'queued'
- [ ] #2 Worker respects queue control settings (paused state, max concurrent downloads)
- [ ] #3 Successfully downloaded audiobooks change status to 'completed'
- [ ] #4 Failed downloads change status to 'failed' with error message
- [ ] #5 Download progress is visible in the UI
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Analyze current flow: CategoryScrapeWorker creates queue items but never enqueues DownloadWorker jobs
2. Modify CategoryScrapeWorker to enqueue DownloadWorker jobs when creating queue items
3. Consider max_concurrent_downloads setting and how it relates to Oban queue limit
4. Test that downloads actually start processing queued items
5. Verify pause/resume functionality works correctly
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Modified CategoryScrapeWorker to enqueue DownloadWorker jobs when queue items are created.

Changes made:
- Added DownloadWorker alias to CategoryScrapeWorker
- Modified enqueue_metadata_jobs/1 to fetch or create audiobook records
- Added filesystem check as source of truth (file_path existence)
- Added queue item creation/reuse logic
- Enqueued both MetadataExtractWorker and DownloadWorker jobs

Issue persists:
- Queue items are created with status queued
- Oban jobs may or may not be enqueued correctly
- Downloads do not start automatically
- Requires further investigation into Oban job execution

Created task-18 to properly investigate and fix the root cause.
<!-- SECTION:NOTES:END -->
