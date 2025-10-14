---
id: task-22
title: Make library page styles consistent with queue/home page
status: Done
assignee:
  - '@claude'
created_date: '2025-10-14 15:22'
updated_date: '2025-10-14 15:27'
labels:
  - ui
  - polish
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The library page should have consistent styling, layout, and visual design with the queue/home page to provide a cohesive user experience across the application.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Library page uses same color scheme and typography as queue/home
- [x] #2 Card layouts and spacing match queue/home page style
- [x] #3 Navigation and header styling is consistent
- [x] #4 Responsive breakpoints match between pages
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Analyze differences between queue_live.ex and library_live.ex styling
2. Update library page header to match queue page style (size, layout)
3. Update search bar card styling (bg-base-100, shadow-sm, border)
4. Update sort buttons to use btn-sm and consistent styling
5. Update audiobook grid cards (shadow-sm, borders)
6. Update empty state styling to match queue page
7. Ensure consistent spacing and padding throughout
8. Test responsive breakpoints
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Updated library page styling to match queue/home page for consistent UI:

- Changed header from .header component to inline layout with size-7 icon and text-2xl title
- Updated search card: bg-base-200 → bg-base-100, shadow-xl → shadow-sm, added border-base-300
- Wrapped sort buttons in card container with p-3 padding
- Changed sort buttons: btn → btn-sm, btn-primary → btn-sm (active), btn-outline → btn-sm btn-outline
- Updated empty state: reduced icon size to size-10, simplified text, changed padding to p-12
- Updated audiobook cards: shadow-xl → shadow-sm, added border-base-300, changed hover effect
- Reduced card body padding from default to p-3, updated text sizes (card-title → font-medium text-sm)
- Updated modal styling: added border, reduced spacing (gap-6 → gap-4, space-y-4 → space-y-3)
- Reduced modal text sizes and button sizes to match queue page
- Changed main container spacing from space-y-6 to space-y-4

All pages now use consistent spacing, borders, shadows, and responsive breakpoints.
<!-- SECTION:NOTES:END -->
