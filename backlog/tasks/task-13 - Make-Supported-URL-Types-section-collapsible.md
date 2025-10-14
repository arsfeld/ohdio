---
id: task-13
title: Make Supported URL Types section collapsible
status: Done
assignee:
  - '@claude'
created_date: '2025-10-10 20:58'
updated_date: '2025-10-14 19:21'
labels:
  - ui
  - ux
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Supported URL Types info section is useful but takes up significant vertical space on the Queue page. Make it collapsible/hideable by default to improve page layout while keeping the information accessible when needed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Add collapse/expand toggle button to Supported URL Types section header
- [x] #2 Section is collapsed by default on page load
- [x] #3 Users can click to expand and view the full info
- [x] #4 Section state (collapsed/expanded) is maintained in component state
- [x] #5 Smooth transition animation when expanding/collapsing
- [x] #6 Appropriate icon indicator (chevron/arrow) shows current state
<!-- AC:END -->
