---
id: task-28
title: Refactor Docker setup to follow linuxserver.io conventions
status: Done
assignee:
  - '@claude'
created_date: '2025-10-14 16:18'
updated_date: '2025-10-14 16:24'
labels:
  - docker
  - infrastructure
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Restructure the Docker configuration to align with linuxserver.io standards for better portability, easier backups, and production deployment. Current setup uses named volumes and scattered data locations (/data/db, /data/downloads, /data/logs). Need to consolidate into /config directory with bind mount support and PUID/PGID user mapping.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Database path moved from /data/db to /config directory
- [x] #2 All persistent data (DB, logs, app config) stored under /config directory
- [x] #3 Dockerfile supports PUID and PGID environment variables for user/group mapping
- [x] #4 Development compose.yml updated to use new /config structure
- [x] #5 Production compose.prod.yml example created with bind mounts instead of named volumes
- [x] #6 Application config (runtime.exs, dev.exs) updated to reference new paths
- [x] #7 Documentation updated with examples for both dev and prod deployments
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Study linuxserver.io conventions and current Docker setup
2. Create entrypoint script for PUID/PGID support
3. Update Dockerfile: add PUID/PGID support, change /data/* to /config structure
4. Update compose.yml: replace named volumes with /config bind mount, update env vars
5. Create compose.prod.yml: production example with bind mounts
6. Update config files (runtime.exs, dev.exs) if needed for new paths
7. Create migration documentation for existing users
8. Test the changes: build, run, verify data persistence
9. Update main README with deployment examples
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Refactored Docker setup to follow linuxserver.io conventions for better portability and easier backups.

## Changes Made

### 1. Entrypoint Script (docker-entrypoint.sh)
- Created new entrypoint script with PUID/PGID support
- Dynamically creates/updates user and group based on environment variables
- Automatically creates /config directory structure (db, logs, downloads)
- Uses gosu for secure user switching

### 2. Dockerfile Updates
- Added gosu package for user switching
- Replaced /data/* structure with /config structure
- Added PUID/PGID environment variables (default: 1000)
- Integrated entrypoint script for runtime user configuration
- Removed hardcoded dev user in favor of dynamic user creation

### 3. Development Compose (compose.yml)
- Replaced named volumes with bind mount to ./config
- Updated all path environment variables (/data/* -> /config/*)
- Added PUID/PGID environment variables with defaults
- Removed volume definitions (no longer using named volumes)

### 4. Production Compose (compose.prod.yml)
- Created new production example with bind mounts
- Documented all required environment variables
- Added resource limits and security options
- Included comprehensive comments and usage instructions
- Example uses /opt/ohdio/config for production data

### 5. Documentation (README.md)
- Added comprehensive deployment section following linuxserver.io conventions
- Documented PUID/PGID usage and benefits
- Added backup/migration examples
- Included production deployment instructions
- Documented all environment variables with descriptions

## Benefits

- **Better Portability**: Single /config directory for all data
- **Easier Backups**: Just backup /config directory
- **Proper Permissions**: PUID/PGID ensures files match host user
- **Production Ready**: Clear path for production deployments
- **Standard Convention**: Follows widely-adopted linuxserver.io pattern
<!-- SECTION:NOTES:END -->
