---
id: task-18
title: Fix download worker not processing queued items from category scrapes
status: In Progress
assignee:
  - '@claude'
created_date: '2025-10-14 14:13'
updated_date: '2025-10-14 14:14'
labels:
  - downloads
  - worker
  - queue
  - bug
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Category scraping successfully adds audiobooks to the queue with status 'queued', but no download worker is processing them. Items remain in queued state indefinitely. The CategoryScrapeWorker was modified to enqueue DownloadWorker jobs, but downloads still do not start automatically. Root cause needs investigation.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Category scrape creates audiobooks in database
- [ ] #2 Category scrape creates queue_items with status 'queued'
- [ ] #3 Category scrape enqueues Oban DownloadWorker jobs
- [ ] #4 DownloadWorker jobs are actually executed by Oban
- [ ] #5 Downloads respect concurrency limit (max 3 concurrent)
- [ ] #6 File existence check on filesystem is used as source of truth
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Trigger a category scrape and verify audiobooks are created
2. Check that queue_items are created with correct status
3. Query oban_jobs table to verify DownloadWorker jobs are enqueued
4. Check Oban logs for any errors or issues with job execution
5. Verify Oban configuration and queue settings
6. Test manual Oban job execution to isolate the issue
7. Fix the root cause and test end-to-end flow
<!-- SECTION:PLAN:END -->
