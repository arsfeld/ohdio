# OHdio Phoenix Migration Guide

## Overview

Converting the Python OHdio audiobook downloader into a Phoenix Framework web application. The Python code will be fully archived as reference only - all new functionality will be implemented in pure Elixir/Phoenix.

## Target Features

### Core Functionality
1. **Download Single URL** - Paste any URL (OHdio or any yt-dlp compatible URL) and queue for download
2. **Category Queue** - Queue entire OHdio category of audiobooks for batch download
3. **Queue Management** - View, pause, resume, cancel, clear queue
4. **Library Browser** - Browse downloaded audiobooks with thumbnails and metadata

### Feature Scope (Confirmed)
- ✅ Real-time download progress updates (Phoenix LiveView)
- ✅ Audio playback in browser (simple HTML5 player)
- ✅ Search/filter library
- ✅ Support any yt-dlp compatible URL (not just OHdio)
- ❌ No user authentication (single-user app)
- ❌ No resumable downloads (queue control only)
- ❌ No audio streaming (download then play)

## Architecture

### Tech Stack

```
┌─────────────────────────────────────────────────────────────┐
│                     Phoenix Web App                         │
├─────────────────────────────────────────────────────────────┤
│  LiveView UI                                                │
│  ├─ Home (Add URLs)                                         │
│  ├─ Queue (Manage downloads)                                │
│  └─ Library (Browse files)                                  │
├─────────────────────────────────────────────────────────────┤
│  Phoenix Contexts                                           │
│  ├─ Downloads (queue, jobs)                                 │
│  ├─ Audiobooks (metadata, files)                            │
│  └─ Scrapers (category, metadata extraction)                │
├─────────────────────────────────────────────────────────────┤
│  Background Jobs (Oban)                                     │
│  ├─ CategoryScrapeWorker                                    │
│  ├─ MetadataExtractWorker                                   │
│  └─ DownloadWorker                                          │
├─────────────────────────────────────────────────────────────┤
│  External Tools                                             │
│  ├─ yt-dlp (download m3u8)                                  │
│  └─ FFmpeg (audio processing)                               │
├─────────────────────────────────────────────────────────────┤
│  Storage                                                    │
│  ├─ PostgreSQL (metadata, queue)                            │
│  └─ Filesystem (audio files, artwork)                       │
└─────────────────────────────────────────────────────────────┘
```

### Key Technologies
- **Phoenix 1.7+** with LiveView for reactive UI
- **Oban** for reliable background job processing
- **Ecto/PostgreSQL** for data persistence
- **HTTPoison/Req** for HTTP requests
- **Floki** for HTML parsing (replaces BeautifulSoup)
- **yt-dlp** via System.cmd for downloads
- **FFmpeg** for audio processing (same as Python)

## Database Schema

### Tables

```elixir
# Audiobooks table
audiobooks
  - id (uuid, primary key)
  - title (string)
  - author (string)
  - description (text)
  - duration (integer, seconds)
  - series (string, nullable)
  - series_number (integer, nullable)
  - narrator (string, nullable)
  - genre (string, nullable)
  - original_url (string)
  - file_path (string, nullable)
  - artwork_path (string, nullable)
  - file_size (bigint, nullable)
  - status (enum: pending, downloading, completed, failed)
  - downloaded_at (timestamp, nullable)
  - inserted_at (timestamp)
  - updated_at (timestamp)

# Download Queue table
download_queue
  - id (uuid, primary key)
  - audiobook_id (uuid, foreign key)
  - status (enum: queued, processing, paused, completed, failed, cancelled)
  - priority (integer, default 0)
  - retry_count (integer, default 0)
  - error_message (text, nullable)
  - progress (integer, 0-100)
  - queued_at (timestamp)
  - started_at (timestamp, nullable)
  - completed_at (timestamp, nullable)
  - inserted_at (timestamp)
  - updated_at (timestamp)

# Queue Control table (singleton for global queue state)
queue_control
  - id (integer, primary key, always 1)
  - is_paused (boolean, default false)
  - updated_at (timestamp)

# Categories table (optional, for tracking batch imports)
categories
  - id (uuid, primary key)
  - name (string)
  - url (string)
  - audiobook_count (integer)
  - last_scraped_at (timestamp, nullable)
  - inserted_at (timestamp)
  - updated_at (timestamp)
```

## Application Structure

```
ohdio_phoenix/
├── lib/
│   ├── ohdio/                      # Business logic context
│   │   ├── audiobooks.ex           # Audiobooks context
│   │   ├── audiobooks/
│   │   │   ├── audiobook.ex        # Schema
│   │   │   └── metadata.ex         # Metadata struct
│   │   ├── downloads.ex            # Downloads context
│   │   ├── downloads/
│   │   │   └── queue_item.ex       # Schema
│   │   ├── scrapers/
│   │   │   ├── category.ex         # Category scraping
│   │   │   ├── audiobook.ex        # Metadata extraction
│   │   │   └── playlist.ex         # m3u8 URL extraction
│   │   └── workers/
│   │       ├── category_scrape.ex  # Oban worker
│   │       ├── metadata_extract.ex # Oban worker
│   │       └── download.ex         # Oban worker
│   ├── ohdio_web/                  # Web interface
│   │   ├── live/
│   │   │   ├── home_live.ex        # Add URL form
│   │   │   ├── queue_live.ex       # Queue management
│   │   │   └── library_live.ex     # Browse downloads
│   │   ├── components/
│   │   │   ├── core_components.ex
│   │   │   └── audiobook_card.ex   # Reusable card component
│   │   ├── controllers/
│   │   │   └── file_controller.ex  # Serve audio/artwork
│   │   └── router.ex
│   └── ohdio.ex                    # Application supervisor
├── priv/
│   ├── repo/migrations/
│   └── static/
└── config/
```

## Implementation Phases

### Phase 1: Bootstrap Phoenix App (1-2 hours)
**Goal**: Get basic Phoenix app running with database

- [ ] Create new Phoenix project: `mix phx.new ohdio_phoenix --database postgres`
- [ ] Add dependencies to `mix.exs`:
  - `{:oban, "~> 2.17"}`
  - `{:req, "~> 0.4"}` or `{:httpoison, "~> 2.2"}`
  - `{:floki, "~> 0.35"}`
- [ ] Configure Oban in `config/config.exs`
- [ ] Run database setup: `mix ecto.create`
- [ ] Verify app starts: `mix phx.server`

**Success Criteria**: Phoenix welcome page loads at http://localhost:4000

---

### Phase 2: Database Schema & Contexts (2-3 hours)
**Goal**: Create data models and business logic layer

- [ ] Generate Audiobooks context:
  ```bash
  mix phx.gen.context Audiobooks Audiobook audiobooks \
    title:string author:string description:text duration:integer \
    series:string series_number:integer narrator:string genre:string \
    original_url:string file_path:string artwork_path:string \
    file_size:bigint status:string downloaded_at:utc_datetime
  ```
- [ ] Generate Downloads context:
  ```bash
  mix phx.gen.context Downloads QueueItem download_queue \
    audiobook_id:references:audiobooks status:string priority:integer \
    retry_count:integer error_message:text progress:integer \
    queued_at:utc_datetime started_at:utc_datetime completed_at:utc_datetime
  ```
- [ ] Run migrations: `mix ecto.migrate`
- [ ] Add Ecto Enums for status fields
- [ ] Test CRUD operations in IEx: `iex -S mix`

**Success Criteria**: Can create/read audiobook and queue records in database

---

### Phase 3: Basic Scraping Logic (3-4 hours)
**Goal**: Port Python scraping logic to pure Elixir

- [ ] Implement `Ohdio.Scrapers.Category`:
  - Detect if URL is OHdio category page
  - Fetch category page HTML
  - Parse audiobook URLs using Floki (port Python fallback strategies)
  - Return list of URLs
- [ ] Implement `Ohdio.Scrapers.Audiobook`:
  - Detect if URL is OHdio audiobook page
  - Fetch audiobook page HTML
  - Extract metadata (title, author, description, etc.)
  - Return metadata struct
- [ ] Implement `Ohdio.Scrapers.Playlist`:
  - Extract m3u8 URL from page scripts (OHdio-specific)
  - Use multiple fallback strategies (port from Python)
- [ ] Add URL detection logic:
  - OHdio category → scrape category
  - OHdio audiobook → scrape metadata
  - Other URL → pass directly to yt-dlp (let yt-dlp handle it)
- [ ] Add HTTP retry logic with exponential backoff
- [ ] Write tests for each scraper module

**Success Criteria**: Can scrape OHdio categories/audiobooks and pass-through non-OHdio URLs

---

### Phase 4: Download Workers (3-4 hours)
**Goal**: Implement background job processing with Oban and queue control

- [ ] Create `Ohdio.Workers.CategoryScrape`:
  - Takes category URL
  - Scrapes all audiobook URLs (OHdio only)
  - Creates audiobook records
  - Enqueues metadata extraction jobs
- [ ] Create `Ohdio.Workers.MetadataExtract`:
  - Takes audiobook ID and URL
  - If OHdio URL: Extract full metadata via scraping
  - If non-OHdio URL: Use yt-dlp --dump-json for basic metadata
  - Updates audiobook record
  - Enqueues download job
- [ ] Create `Ohdio.Workers.Download`:
  - Check queue_control.is_paused before starting
  - Takes audiobook ID
  - Uses System.cmd to call yt-dlp with progress hooks
  - Saves file to configured output directory
  - Embeds metadata using FFmpeg (pure Elixir via System.cmd)
  - Updates progress via PubSub for real-time UI updates
  - Handles pause signals (check periodically)
- [ ] Configure Oban queues with concurrency limits
- [ ] Add job error handling and retry logic
- [ ] Implement queue pause/resume logic in Downloads context

**Success Criteria**: Can queue and process downloads end-to-end with pause/resume control

---

### Phase 5: LiveView UI - Home Page (2-3 hours)
**Goal**: Create interface for adding downloads

- [ ] Create `OhdioWeb.HomeLive`:
  - URL input form (text input)
  - URL detection logic (client-side hint)
  - Submit button (detects URL type automatically)
  - Examples section showing supported URLs
  - Basic validation (URL format)
- [ ] Handle form submission with URL detection:
  - **OHdio category URL** → Enqueue CategoryScrape worker
  - **OHdio audiobook URL** → Enqueue MetadataExtract worker
  - **Other URL** → Create audiobook record, enqueue Download worker (skip scraping)
- [ ] Show appropriate feedback:
  - Success message with detected type
  - Error message for invalid URLs
  - Link to queue page to see progress
- [ ] Add basic styling with Tailwind CSS
- [ ] Add real-time notifications via put_flash

**Success Criteria**: Can add OHdio categories, OHdio audiobooks, and arbitrary URLs via web UI

---

### Phase 6: LiveView UI - Queue Management (3-4 hours)
**Goal**: View and manage download queue with full control

- [ ] Create `OhdioWeb.QueueLive`:
  - List all queue items with status badges
  - Show download progress bars with percentage
  - Filter by status (queued, processing, paused, completed, failed, cancelled)
  - Sort by priority/date/status
- [ ] Add global queue controls:
  - **Pause All** - Pause queue processing (sets queue_control.is_paused)
  - **Resume All** - Resume queue processing
  - **Clear Queue** - Remove all queued (not processing) items
  - **Clear Completed** - Remove completed/failed/cancelled items
- [ ] Add per-item actions:
  - Cancel individual download
  - Retry failed download
  - Delete from queue
  - Move up/down priority (optional)
- [ ] Subscribe to PubSub for real-time updates:
  - Progress updates (live percentage)
  - Status changes (queued → processing → completed)
  - New items added
  - Queue pause state changes
- [ ] Show live statistics:
  - Total items / Queued / Processing / Completed / Failed
  - Overall progress percentage
  - Estimated time remaining (optional)

**Success Criteria**: Can view queue, see real-time progress, and pause/resume/clear queue

---

### Phase 7: LiveView UI - Library Browser (3-4 hours)
**Goal**: Browse and play downloaded audiobooks

- [ ] Create `OhdioWeb.LibraryLive`:
  - Grid view of audiobooks with thumbnails
  - Show title, author, duration, file size
  - Search/filter by title or author
  - Sort by download date, title, author
- [ ] Create `OhdioWeb.FileController`:
  - Serve audio files with proper MIME types
  - Serve artwork images
  - Add range request support for audio seeking
- [ ] Add audiobook detail modal:
  - Full metadata display
  - Simple HTML5 audio player with controls
  - Direct download link
  - Delete option (removes file and database record)
- [ ] Implement thumbnail generation:
  - Extract artwork during download
  - Generate placeholder for missing artwork
  - Cache thumbnails for performance

**Success Criteria**: Can browse library and play audiobooks in browser

---

### Phase 8: Polish & Testing (2-3 hours)
**Goal**: Production readiness

- [ ] Add comprehensive error handling
- [ ] Add loading states and skeleton screens
- [ ] Add download rate limiting (respect OHdio servers)
- [ ] Add file size limits and disk space checks
- [ ] Write integration tests for workflows
- [ ] Add config for output directory, concurrent downloads
- [ ] Create Docker/deployment configuration
- [ ] Add logging and monitoring

**Success Criteria**: App is stable and ready for use

---

## Migration Strategy

### Archiving Python Code
```bash
# Create archive directory
mkdir -p archive/python_original

# Move all Python code to archive
git mv src/ archive/python_original/
git mv main.py test_ohdio.py test_setup.py archive/python_original/
git mv config.json archive/python_original/
git mv requirements.txt pyproject.toml archive/python_original/

# Keep documentation in root for reference
# (CLAUDE.md, README.md, etc. stay in root)

# Commit the archival
git commit -m "Archive original Python implementation

All Python code moved to archive/python_original for reference.
Next commit will bootstrap Phoenix application."
```

### Configuration Mapping
Python `config.json` → Phoenix `config/runtime.exs`:
- `output_directory` → `config :ohdio, :storage_path`
- `max_concurrent_downloads` → Oban queue concurrency
- `retry_attempts` → Oban max_attempts
- `audio_quality` → yt-dlp options

## Key Differences from Python

### Concurrency Model
- **Python**: asyncio with semaphores
- **Phoenix**: Oban workers with database-backed queue
- **Benefit**: More reliable, survives app restarts, better monitoring

### Scraping
- **Python**: BeautifulSoup with multiple fallback parsers
- **Elixir**: Floki for HTML parsing
- **Note**: May need to port fallback logic carefully

### Metadata Embedding
- **Python**: mutagen library
- **Elixir**: Use FFmpeg via System.cmd for ID3 tags
- **Alternative**: Port Python script and call it

### Real-time Updates
- **Python**: Async logging
- **Phoenix**: LiveView + PubSub for live UI updates
- **Benefit**: Users see progress in browser without polling

## Testing Strategy

### Unit Tests
- Scraper modules (mock HTTP responses)
- Context functions (database operations)
- Worker logic (use Oban.Testing)

### Integration Tests
- Full download pipeline
- Queue management workflows
- LiveView interactions

### Manual Testing Checklist
- [ ] Add single OHdio URL → Downloads successfully
- [ ] Add category URL → All audiobooks queued
- [ ] Cancel in-progress download → Stops cleanly
- [ ] Retry failed download → Works
- [ ] Browse library → Shows all downloads
- [ ] Play audiobook → Plays in browser
- [ ] Search library → Finds results

## Resources

### Documentation
- [Phoenix Framework](https://hexdocs.pm/phoenix/overview.html)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
- [Oban Background Jobs](https://hexdocs.pm/oban/Oban.html)
- [Floki HTML Parser](https://hexdocs.pm/floki/Floki.html)

### Similar Projects
- Look for Phoenix file upload/management apps
- Study Oban examples for download queue patterns

## Timeline Estimate

**Total: 20-28 hours** across 8 phases

- **Minimum Viable Product** (Phases 1-5): ~12 hours
  - Can add URLs and download audiobooks
- **Full Feature Set** (Phases 1-7): ~20 hours
  - Complete queue management and library browser
- **Production Ready** (All Phases): ~24 hours
  - Polished, tested, deployable

## Next Steps

### Immediate Actions
1. **Archive Python code** using the migration script above
2. **Set up development environment**:
   - Install Elixir 1.15+ and Erlang/OTP 26+
   - Install PostgreSQL 14+
   - Install yt-dlp and FFmpeg (external dependencies)
   - Install Phoenix: `mix archive.install hex phx_new`
3. **Start Phase 1**: Bootstrap Phoenix application

### Development Approach
- **Incremental**: Complete each phase fully before moving to next
- **Test-driven**: Write tests for scrapers and workers as we build
- **Commit often**: Each completed phase should be a commit
- **Reference Python**: Use archived Python code to understand scraping logic

### Ready to Begin?
When ready, we'll start with:
```bash
# Phase 1: Bootstrap
cd /home/arosenfeld/Code/ohdio
mix phx.new ohdio_phoenix --database postgres --no-dashboard --no-mailer
cd ohdio_phoenix
mix deps.get
mix ecto.create
mix phx.server
```

---

## Scope Decisions (Confirmed)
✅ Pure Elixir/Phoenix (no Python scripts)
✅ Single-user app (no authentication)
✅ Queue control (pause/resume/clear)
✅ Non-resumable downloads (Oban handles retries)
✅ No streaming (download-then-play)
✅ Support any yt-dlp compatible URL
