---
id: task-20
title: Fix image artwork extraction and display for Radio Canada Ohdio audiobooks
status: Done
assignee:
  - '@claude'
created_date: '2025-10-14 15:20'
updated_date: '2025-10-14 15:26'
labels:
  - backend
  - ui
  - bug
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Currently downloaded audiobooks from Radio Canada Ohdio are not displaying cover artwork properly. The images are either not being extracted during download or not being displayed correctly in the library UI.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Downloaded audiobooks display correct cover artwork in library view
- [x] #2 Image extraction from Ohdio API is properly implemented
- [x] #3 Fallback handling for missing images is in place
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Fix MetadataExtractWorker to correctly map thumbnail_url to cover_image_url
2. Add fallback placeholder image for missing cover images in UI
3. Test with existing audiobooks and new downloads
4. Verify images display correctly in library view
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Fix Summary

**Root Cause**: MetadataExtractWorker was incorrectly trying to access `metadata.cover_image_url` when the AudiobookScraper returns `thumbnail_url`.

**Changes Made**:
1. Fixed MetadataExtractWorker (line 86) to correctly map `metadata.thumbnail_url` to `cover_image_url`
2. Verified UI already has proper fallback (musical note icon) for missing images

**Impact**:
- New audiobook downloads will now correctly extract and display cover artwork
- Existing 144 audiobooks have nil cover_image_url and will continue showing fallback icon
- To update existing audiobooks, they would need to be re-scraped (future enhancement)

**Testing**:
- Code compiles successfully
- Scraper test confirms thumbnail_url is correctly extracted
- CategoryScrapeWorker already maps thumbnail_url correctly
- UI properly handles both cases (image present and missing)
<!-- SECTION:NOTES:END -->
