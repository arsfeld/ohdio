---
id: task-31
title: Reduce or remove page header spacing for more compact layout
status: Done
assignee:
  - '@claude'
created_date: '2025-10-14 19:32'
updated_date: '2025-10-14 19:52'
labels:
  - ui
  - layout
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Currently there is excessive spacing between the page headers (e.g., 'OHdio Downloader') and the navbar, making the UI feel unnecessarily spacious. Consider making headers more compact or removing them entirely if they don't add value.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Evaluate if page headers are necessary or can be removed
- [x] #2 If keeping headers, significantly reduce spacing between navbar and header
- [x] #3 Ensure compact, efficient use of vertical space
- [x] #4 Maintain visual hierarchy and readability
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Analyze current spacing - main container has py-20 (5rem) vertical padding
2. Reduce main container padding from py-20 to more compact value (py-6)
3. Slightly reduce page header sizes for more compact feel
4. Test both Home and Library pages for proper spacing
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Removed page headers entirely and reorganized navbar for a cleaner, more compact layout:

**Navbar Reorganization (layouts.ex:38-62):**
- Moved Home and Library links to the left side next to the logo
- Reduced navigation button sizes to btn-sm for compactness
- Reduced icon sizes in nav buttons from size-5 to size-4
- Theme toggle moved to the right side by itself
- Added proper gap-6 spacing between logo and navigation links

**Page Headers Removed:**
- Removed "OHdio Downloader" header from QueueLive (lines 430-438)
- Removed "Library" header from LibraryLive (lines 291-299)
- Headers were redundant since navbar now clearly indicates the current page

**Main Container Spacing:**
- Kept py-6 vertical padding (previously reduced from py-20)

**Result:**
- Much cleaner, more professional navigation layout
- Navigation follows standard web patterns (links on left, utilities on right)
- Significantly reduced vertical space usage
- Current page context is clear from navbar active state
- Content starts immediately without redundant headers
<!-- SECTION:NOTES:END -->
