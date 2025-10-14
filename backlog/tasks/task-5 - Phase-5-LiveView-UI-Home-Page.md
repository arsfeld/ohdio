---
id: task-5
title: 'Phase 5: LiveView UI - Home Page'
status: Done
assignee:
  - '@claude'
created_date: '2025-10-10 18:41'
updated_date: '2025-10-10 19:16'
labels:
  - frontend
  - liveview
  - ui
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create interface for adding downloads with automatic URL type detection (OHdio category, OHdio audiobook, or generic URL).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 HomeLive created with URL input form and validation
- [x] #2 Form submission detects URL type and enqueues appropriate worker
- [x] #3 Success/error feedback shown with detected URL type
- [x] #4 Examples section shows supported URL types
- [x] #5 Tailwind CSS styling applied
- [x] #6 Real-time notifications via put_flash working
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Review existing LiveView structure and routing setup
2. Create HomeLive module with mount, handle_event, and render
3. Implement URL type detection (OHdio category/audiobook/generic)
4. Wire up Oban job enqueueing for detected URL types
5. Add form validation and flash messaging
6. Create examples section showing supported URL formats
7. Apply Tailwind CSS styling for polish
8. Test form submission and worker enqueueing
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Summary

Implemented HomeLive as the main interface for adding downloads to the queue. The page automatically detects URL types and routes them to the appropriate Oban workers.

## Changes Made

**Created Files:**
- `lib/ohdio_web/live/home_live.ex` - Main LiveView with form handling and URL type detection
- `test/ohdio_web/live/home_live_test.exs` - Comprehensive test suite covering all acceptance criteria

**Modified Files:**
- `lib/ohdio_web/router.ex` - Replaced PageController with HomeLive for root route
- `config/test.exs` - Added Oban test configuration (manual mode)
- `test/ohdio_web/controllers/page_controller_test.exs` - Updated to reference new LiveView tests

## Key Features

1. **Smart URL Detection** - Automatically identifies:
   - OHdio category pages → enqueues CategoryScrapeWorker
   - OHdio audiobook pages → creates audiobook + enqueues MetadataExtractWorker
   - yt-dlp compatible URLs (YouTube, Vimeo, etc.) → creates audiobook + enqueues MetadataExtractWorker
   - Unknown URLs → attempts download with yt-dlp as fallback

2. **User Feedback** - Real-time flash notifications show:
   - Detected URL type
   - Success/error messages
   - What action is being taken

3. **Modern UI** - Tailwind CSS styled with:
   - Card-based layout
   - Hero icons for visual clarity
   - Responsive design
   - Examples section showing supported URL formats

4. **Robust Testing** - 10 test cases covering:
   - Form display and validation
   - All URL type detection scenarios
   - Flash message functionality
   - Oban job enqueueing
   - Form reset after submission

## Testing

Run tests with: `mix test test/ohdio_web/live/home_live_test.exs`

All tests verify both functionality and user feedback.
<!-- SECTION:NOTES:END -->
