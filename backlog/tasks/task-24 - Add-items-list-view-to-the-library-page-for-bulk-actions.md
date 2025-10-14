---
id: task-24
title: Add items list view to the library page for bulk actions
status: Done
assignee:
  - '@claude'
created_date: '2025-10-14 15:27'
updated_date: '2025-10-14 15:34'
labels:
  - ui
  - feature
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a list/table view option to the library page that allows users to quickly view and perform multiple actions on downloaded audiobooks. This complements the current grid view and enables efficient bulk operations.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Add toggle between grid and list view modes
- [x] #2 Implement table/list layout showing audiobook details in rows
- [x] #3 Add checkbox selection for multiple items
- [x] #4 Add bulk action buttons (download, delete, etc.)
- [x] #5 Preserve view mode preference in user session
- [x] #6 Maintain consistent styling with queue/home page
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add :view_mode assign to mount/3 (default to "grid")
2. Add toggle button between grid and list views in the UI
3. Implement handle_event for "toggle_view" to switch view modes
4. Create list/table view template section (similar to queue page table)
5. Update render to conditionally show grid or list view based on @view_mode
6. Add phx-hook for localStorage persistence of view preference
7. Test both views with selection and bulk actions
8. Verify styling consistency with queue page
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Implementation Summary

Successfully added a list/table view option to the library page alongside the existing grid view:

### Changes Made

1. **Added View Mode State**: Introduced `:view_mode` assign in mount/3, defaulting to "grid" view

2. **View Toggle UI**: Added toggle buttons in the control panel allowing users to switch between grid and list views using hero icons (squares-2x2 for grid, list-bullet for list)

3. **List View Implementation**: Created a comprehensive table layout for list view featuring:
   - Checkbox column for multi-selection
   - Thumbnail column showing cover images
   - Columns for Title, Author, Duration, File Size, and Date Added
   - Actions column with view details button
   - Consistent styling with the queue/home page table design

4. **View Persistence**: Implemented localStorage persistence using LiveView hooks:
   - Created ViewMode JavaScript hook in app.js
   - Hook saves view preference to localStorage on toggle
   - Hook restores saved preference on mount
   - Added handle_event callbacks for set_view_mode and save_view_mode events

5. **Unified Control Panel**: The search, sort controls, view toggle, and bulk actions are now integrated into a single card with dividers for visual separation

### Technical Details

- List view uses same selection logic as grid view (MapSet-based state)
- All existing bulk actions (select all, deselect all, bulk download) work seamlessly in both views
- Grid view maintains original behavior with clickable cards and hover effects
- List view provides more efficient scanning with tabular data presentation
- View mode persists across page reloads via localStorage

### Files Modified

- `lib/ohdio_web/live/library_live.ex`: Added view mode state and event handlers
- `assets/js/app.js`: Added ViewMode hook for localStorage persistence
<!-- SECTION:NOTES:END -->
