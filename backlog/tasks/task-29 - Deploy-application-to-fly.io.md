---
id: task-29
title: Deploy application to fly.io
status: Done
assignee:
  - '@claude'
created_date: '2025-10-14 17:18'
updated_date: '2025-10-14 17:40'
labels:
  - deployment
  - infrastructure
  - fly.io
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up deployment pipeline to fly.io platform for production hosting. Configure fly.io app with persistent volumes for the /config directory, environment variables, and proper scaling settings.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 fly.io app created and configured
- [x] #2 Persistent volume created and mounted to /config
- [x] #3 Environment variables configured (SECRET_KEY_BASE, DATABASE_PATH, etc.)
- [x] #4 Dockerfile optimized for fly.io deployment
- [x] #5 fly.toml configuration file created with health checks and resource limits
- [x] #6 Deployment successfully tested and application is accessible
- [x] #7 Documentation updated with fly.io deployment instructions
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Research current setup - check Dockerfile, Phoenix config, and environment requirements
2. Install/verify fly.io CLI is available
3. Initialize fly.io app using fly launch
4. Create persistent volume for /config directory
5. Configure environment variables (SECRET_KEY_BASE, DATABASE_PATH, PHX_HOST, etc.)
6. Optimize Dockerfile for fly.io if needed
7. Configure fly.toml with health checks, resource limits, and volume mounts
8. Deploy and test the application
9. Update README with fly.io deployment instructions
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Successfully deployed OHdio to fly.io with full production configuration.

Key accomplishments:
- Created fly.io app in Toronto (yyz) region
- Created 10GB persistent volume mounted at /config
- Set up SECRET_KEY_BASE and PHX_HOST secrets
- Created Dockerfile.prod optimized for production (separate from dev Dockerfile)
- Configured fly.toml with health checks, volume mounts, and all env vars
- App successfully deployed and accessible at https://ohdio.fly.dev/
- Added comprehensive deployment documentation to README.md

Technical details:
- Used Dockerfile.prod to avoid conflicts with development Dockerfile
- Removed npm asset compilation (Phoenix 1.7+ uses esbuild managed by mix)
- Removed user-switching entrypoint script for production (ran into permission issues)
- Database setup runs on container start (mix ecto.create && mix ecto.migrate)
- Health checks on port 4000 with 30s intervals
- Auto-stop/auto-start enabled for cost optimization

The deployment is fully functional with all acceptance criteria met.
<!-- SECTION:NOTES:END -->
