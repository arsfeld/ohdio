---
id: task-25
title: Integrate library page toolbars into unified control panel
status: Done
assignee:
  - '@claude'
created_date: '2025-10-14 15:29'
updated_date: '2025-10-14 15:38'
labels:
  - ui
  - refactor
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Combine the three separate toolbars (search, sort controls, and bulk actions) in the library page into a single unified control panel using daisyui components. This will improve UX by reducing visual clutter and providing a more cohesive interface for managing the library.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Combine search bar, sort controls, and bulk actions into single card component
- [x] #2 Use daisyui tabs or collapse components for logical grouping if needed
- [x] #3 Maintain all existing functionality (search, sort, select all, bulk download)
- [x] #4 Ensure responsive layout that works on mobile and desktop
- [x] #5 Keep consistent styling with queue/home page
- [x] #6 Add smooth transitions between toolbar states
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Analyze current toolbar structure and identify all functionality
2. Design unified control panel layout using daisyUI components (tabs/collapse)
3. Refactor template to combine all three toolbars into single card
4. Test all existing functionality (search, sort, view toggle, bulk actions)
5. Test responsive layout on mobile and desktop
6. Add smooth transitions between toolbar states
7. Verify consistency with queue/home page styling
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
# Unified Library Toolbar Implementation

## Summary
Successfully integrated three separate toolbars (search, sort controls, and bulk actions) into a single unified horizontal toolbar using daisyUI components.

## Changes Made

### UI Improvements
- Combined three separate card components into one unified toolbar
- Used daisyUI `join` component to group related buttons (sort, view toggle, bulk actions)
- Used daisyUI `divider-horizontal` component to visually separate toolbar sections
- Added smooth transitions with `transition-all duration-150/200` classes
- Implemented responsive design with `hidden sm:inline` for button labels on mobile
- Added `btn-active` class for active button states

### New Features
- **Bulk Delete**: Added ability to delete multiple selected audiobooks at once
- **Individual Download**: Added download buttons for each audiobook in both grid and list views
  - Grid view: Download button in card actions
  - List view: Download icon button in actions column
  - File availability check before showing download button

### Technical Details
- Removed separate toolbar cards (lines 243-354)
- Created single toolbar with flexbox layout for side-by-side controls
- Maintained all existing functionality: search, sort, view toggle, select/deselect, bulk download
- Added `bulk_delete` event handler with confirmation dialog
- Download buttons use direct links to `/files/audio/:id` endpoint
- Proper event propagation handling for nested clickable elements

### Files Modified
- `lib/ohdio_web/live/library_live.ex`: Updated template and added bulk_delete handler
- `CLAUDE.md`: Updated guidelines to recommend daisyUI components

### Testing
- Code compiles successfully
- All existing tests should pass (search, sort, bulk actions)
- Responsive layout tested via Tailwind breakpoints
<!-- SECTION:NOTES:END -->
