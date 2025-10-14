---
id: task-23
title: Add bulk download functionality to library page
status: Done
assignee:
  - '@claude'
created_date: '2025-10-14 15:22'
updated_date: '2025-10-14 15:30'
labels:
  - ui
  - backend
  - feature
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Users should be able to select multiple audiobooks from the library and download them all at once, rather than downloading them one at a time. This will improve UX for users who want to download multiple items.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Users can select multiple audiobooks via checkboxes or similar UI
- [x] #2 Bulk download action triggers download for all selected items
- [x] #3 Selected audiobooks are added to download queue
- [x] #4 UI shows feedback during bulk operation (progress, success/error states)
- [x] #5 Users can select/deselect all items with a single action
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add LiveView state to track selected audiobook IDs (using MapSet)
2. Add checkbox UI to each audiobook card in the grid
3. Add "Select All/Deselect All" button in the toolbar
4. Add "Download Selected" button (visible when items selected)
5. Implement "bulk_download" event handler to create queue items
6. Add UI feedback: loading state, success flash, error handling
7. Clear selections after successful bulk operation
8. Write tests for bulk download functionality
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Summary

Implemented comprehensive bulk download functionality for the library page, allowing users to select multiple audiobooks and re-queue them for download in a single action.

## Key Changes

### Backend (lib/ohdio_web/live/library_live.ex)

- Added state management for selected audiobooks using `MapSet` for efficient lookups
- Implemented `toggle_selection` event to handle individual checkbox clicks
- Implemented `select_all` and `deselect_all` events for batch selection
- Implemented `bulk_download` event that:
  - Creates queue items for all selected audiobooks
  - Handles duplicate queue items gracefully (audiobooks already queued)
  - Shows appropriate success/error messages with counts
  - Clears selection after successful operation
  - Includes loading state to prevent double-clicks

### Frontend UI Enhancements

- Added bulk actions toolbar with:
  - Dynamic "Select All" / "Deselect All" toggle button
  - Selection counter showing number of selected items
  - "Download Selected" button with loading spinner
- Added checkboxes to each audiobook card
- Visual feedback for selected items (primary border + ring)
- Responsive layout that works on all screen sizes

### Testing (test/ohdio_web/live/library_live_test.exs)

Added comprehensive test suite covering:
- Toolbar visibility based on audiobook presence
- Individual selection/deselection
- Select all/deselect all functionality
- Bulk download with multiple items
- Error handling for empty selection
- Selection clearing after successful download
- Graceful handling of duplicate queue items

## Technical Details

- Used MapSet for O(1) lookup performance on large collections
- Implemented proper event handlers with atomic operations
- Added visual feedback with Tailwind CSS transitions
- Maintained separation between checkbox clicks and card detail clicks
- Follows Phoenix LiveView best practices for state management

## Code Quality

- All code formatted with `mix format`
- Compiles without warnings using `--warnings-as-errors`
- Follows project conventions and patterns
- Comprehensive test coverage for all user interactions
<!-- SECTION:NOTES:END -->
