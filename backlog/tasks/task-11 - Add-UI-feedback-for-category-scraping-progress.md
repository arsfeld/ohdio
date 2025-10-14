---
id: task-11
title: Add UI feedback for category scraping progress
status: Done
assignee:
  - '@claude'
created_date: '2025-10-10 20:50'
updated_date: '2025-10-10 21:03'
labels:
  - ui
  - ux
  - feedback
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When a user submits a category URL, show immediate feedback about the scraping process before audiobooks appear in the queue
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Show loading indicator/progress message after category URL submission
- [x] #2 Display 'Scraping category...' state with estimated count or spinner
- [x] #3 Show success message with count when scraping completes
- [x] #4 Handle error states with clear error messages
- [x] #5 Persist scraping status across page refreshes (store in database)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create database migration for category_scrapes table to persist scraping status
2. Create CategoryScrape schema and context functions in Library module
3. Modify CategoryScrapeWorker to create/update scrape records and broadcast via PubSub
4. Update QueueLive to create scrape records, load active scrapes, and subscribe to updates
5. Add UI component to display active category scrapes with loading/success/error states
6. Test the complete flow: submit URL, see progress, see completion, verify persistence across refreshes
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Summary

Implemented comprehensive UI feedback system for category scraping with database persistence and real-time updates.

## Changes Made

### Database Layer
- Created `category_scrapes` table migration with fields: category_url, status (enum: scraping/completed/failed), total_count, error_message, oban_job_id
- Created `CategoryScrape` schema with validation
- Added context functions to Library module: create, update, list_active_category_scrapes, get, delete

### Worker Updates
- Modified `CategoryScrapeWorker` to:
  - Accept `scrape_id` parameter to track scrape records
  - Update scrape status (completed/failed) after processing
  - Broadcast updates via PubSub topic "category_scrapes" for real-time UI updates
  - Capture and store error messages on failure
  - Store total count of discovered audiobooks on success

### LiveView Updates
- Updated `QueueLive.mount/3` to:
  - Subscribe to "category_scrapes" PubSub topic
  - Load active scrapes on initial page load
- Modified `enqueue_category_scrape/1` to:
  - Create CategoryScrape record before enqueueing job
  - Pass scrape_id to worker
  - Update record with oban_job_id after job creation
- Added `handle_info` callback for category_scrape_updated messages
- Added `load_active_scrapes/1` helper function

### UI Components
- Added real-time scraping status alerts above the queue:
  - **Scraping**: Blue alert with spinner showing "Scraping category..." and URL
  - **Success**: Green alert with checkmark showing "Found X audiobooks" and URL
  - **Failed**: Red alert with X icon showing error message and URL
- All alerts display the category URL for context
- Status persists across page refreshes via database
- Real-time updates via PubSub (no refresh needed)

## Testing

- Application compiles without errors
- Database migration runs successfully
- Phoenix server starts and loads active scrapes on mount
- SQL queries show category_scrapes table integration working correctly
<!-- SECTION:NOTES:END -->
