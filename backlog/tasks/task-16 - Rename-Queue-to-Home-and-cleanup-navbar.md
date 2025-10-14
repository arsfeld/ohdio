---
id: task-16
title: Rename Queue to Home and cleanup navbar
status: Done
assignee:
  - '@claude'
created_date: '2025-10-14 13:49'
updated_date: '2025-10-14 19:22'
labels:
  - ui
  - navigation
  - refactor
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The current navigation has 'Queue' as the main page, but it should be renamed to 'Home' since it serves as the main landing page with the download form and queue management. The navbar also needs cleanup to ensure consistent naming and better UX.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Main route '/' is labeled as 'Home' instead of 'Queue' in the navbar
- [x] #2 Page title is updated from 'Download Queue' to 'Home' or appropriate alternative
- [x] #3 All references to 'queue page' in code/UI are updated to 'home page' where appropriate
- [x] #4 Navbar styling and layout is clean and consistent
- [x] #5 Navigation links are clearly labeled and easy to understand
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Search codebase for all "queue" references to identify what needs changing
2. Update navbar label from "Queue" to "Home" in layouts.ex:50
3. Update page title from "Download Queue" to "Home" in queue_live.ex:20
4. Update icon from "hero-queue-list" to "hero-home" in layouts.ex:49 for better semantic meaning
5. Review and test the changes to ensure consistency
6. Run precommit checks
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Summary

Renamed the main navigation item from "Queue" to "Home" to better reflect its purpose as the main landing page.

## Changes Made

- **layouts.ex:49-50**: Updated navbar label from "Queue" to "Home"
- **layouts.ex:49**: Changed icon from "hero-queue-list" to "hero-home" for better semantic meaning
- **queue_live.ex:20**: Updated page title from "Download Queue" to "Home"

## Testing

- ✅ Code compiles cleanly with no warnings
- ✅ Code formatting passes
- ✅ All UI text references updated appropriately
- ✅ Backend queue functionality references preserved (not changed)

## Notes

The term "queue" is still used throughout the codebase for the download queue functionality (e.g., pause_queue, clear_queue, queue_items), which is correct. Only the page/navigation labels were updated to "Home" to better communicate that this is the main landing page.
<!-- SECTION:NOTES:END -->
