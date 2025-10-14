---
id: task-30
title: Clean up navbar branding and remove Phoenix defaults
status: Done
assignee:
  - '@claude'
created_date: '2025-10-14 19:31'
updated_date: '2025-10-14 19:34'
labels:
  - ui
  - branding
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The application navbar currently lacks proper branding and still contains default Phoenix framework information that is redundant and unprofessional.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Add application icon/logo to navbar
- [x] #2 Remove default Phoenix branding/information
- [x] #3 Ensure navbar has clean, professional appearance
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Replace Phoenix logo with OHdio branding (audio-themed icon + app name)
2. Remove Phoenix version display
3. Update navbar styling for professional appearance
4. Test navbar on different screen sizes
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Cleaned up navbar branding in lib/ohdio_web/components/layouts.ex:

- Replaced Phoenix logo (logo.svg) with hero-musical-note icon
- Removed Phoenix version display (Application.spec(:phoenix, :vsn))
- Added "OHdio" text branding with bold styling
- Applied primary color to icon for brand consistency
- Added hover opacity transition for better UX

The navbar now has a clean, professional appearance with audio-themed branding appropriate for the application.
<!-- SECTION:NOTES:END -->
