# Category Scraping Flow Analysis

## Overview

The OHdio category scraping mechanism is a multi-stage asynchronous process that discovers audiobooks from category pages, extracts their metadata, and manages their download lifecycle. The system uses Oban job queues, Phoenix PubSub for real-time updates, and a state machine architecture.

## Architecture Components

### Core Modules

1. **OhdioWeb.QueueLive** - Phoenix LiveView handling UI interactions and real-time updates
2. **Ohdio.Scraper.CategoryScraper** - HTML parsing and audiobook discovery
3. **Ohdio.Workers.CategoryScrapeWorker** - Oban worker orchestrating category scraping
4. **Ohdio.Workers.MetadataExtractWorker** - Oban worker extracting detailed metadata
5. **Ohdio.Workers.DownloadWorker** - Oban worker handling audiobook downloads
6. **Ohdio.Library** - Context for audiobooks and category scrapes
7. **Ohdio.Downloads** - Context for queue management

### Database Tables

- **audiobooks** - Stores audiobook records with metadata and file paths
- **queue_items** - Tracks download queue with status, priority, and attempts
- **category_scrapes** - Tracks category scraping operations and status
- **queue_control** - Global queue settings (pause/resume, concurrency)

---

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        USER SUBMITS CATEGORY URL                            │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: URL DETECTION & SCRAPE RECORD CREATION                           │
├─────────────────────────────────────────────────────────────────────────────┤
│  Component: OhdioWeb.QueueLive                                              │
│  Location: lib/ohdio_web/live/queue_live.ex:256-339                        │
│                                                                             │
│  1. User enters URL in form → handle_event("submit")                       │
│  2. Detect URL type via Scraper.detect_url_type(url)                       │
│     └─ Returns: :ohdio_category | :ohdio_audiobook | :ytdlp_passthrough    │
│  3. For category URLs → enqueue_category_scrape(url)                       │
│     a. Create CategoryScrape record (status: :scraping)                    │
│        Location: lib/ohdio/library/category_scrape.ex                      │
│     b. Insert CategoryScrapeWorker Oban job with scrape_id                 │
│     c. Update scrape record with oban_job_id                               │
│     d. Show flash: "Scraping audiobooks from category..."                  │
│     e. Subscribe to PubSub: "category_scrapes"                             │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 2: CATEGORY SCRAPING (Asynchronous - Oban Job)                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  Component: Ohdio.Workers.CategoryScrapeWorker                              │
│  Location: lib/ohdio/workers/category_scrape_worker.ex:18-54               │
│  Queue: :scraping (max_attempts: 3)                                        │
│                                                                             │
│  1. Oban picks up job and calls perform/1                                  │
│  2. Load scrape record by scrape_id                                        │
│  3. Call Scraper.scrape_category(category_url)                             │
│     └─ Delegates to CategoryScraper.scrape_category/2                      │
│        Location: lib/ohdio/scraper/category_scraper.ex:45-61               │
│                                                                             │
│        a. Fetch HTML via HttpClient.get(url)                               │
│        b. Parse HTML with Floki.parse_document/1                           │
│        c. Apply multiple parsing strategies:                               │
│           • parse_index_grid_items/2                                       │
│           • parse_book_items/2                                             │
│           • parse_livre_audio_sections/2                                   │
│           • parse_generic_links/2                                          │
│        d. Extract for each audiobook:                                      │
│           • title (from span.text, h1-h4, .title, etc.)                    │
│           • author (from .author, .book-author)                            │
│           • url (href from a[href*='livres-audio'])                        │
│           • thumbnail_url (from img src or data-src)                       │
│        e. Deduplicate by URL → Returns list of AudiobookInfo structs      │
│                                                                             │
│  4. For each discovered audiobook → enqueue_metadata_jobs/1                │
│     Location: lib/ohdio/workers/category_scrape_worker.ex:94-165          │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 3: AUDIOBOOK RECORD CREATION & QUEUE ITEM CREATION                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  For EACH audiobook discovered:                                            │
│                                                                             │
│  1. Create or get existing Audiobook record                                │
│     Location: lib/ohdio/library/audiobook.ex                               │
│     Schema: audiobooks table                                               │
│     Fields:                                                                │
│       • title, author, narrator                                            │
│       • url (unique constraint)                                            │
│       • cover_image_url                                                    │
│       • duration, file_size, file_path                                     │
│       • status: :pending (initial)                                         │
│                                                                             │
│  2. Check if file already exists on filesystem                             │
│     • If audiobook.file_path exists AND File.exists?(path) → SKIP         │
│     • Only proceed if file doesn't exist                                   │
│                                                                             │
│  3. Check for existing queue item                                          │
│     • Query: Repo.get_by(QueueItem, audiobook_id: audiobook.id)            │
│     • If exists → reuse it                                                 │
│     • If not → create new queue item                                       │
│                                                                             │
│  4. Create QueueItem record                                                │
│     Location: lib/ohdio/downloads/queue_item.ex                            │
│     Schema: queue_items table                                              │
│     Fields:                                                                │
│       • audiobook_id (foreign key)                                         │
│       • status: :queued (initial)                                          │
│       • priority: 5 (default for category scrapes)                         │
│       • attempts: 0, max_attempts: 3                                       │
│                                                                             │
│  5. Enqueue MetadataExtractWorker Oban job                                 │
│     • Job args: {audiobook_id, url}                                        │
│     • Queue: :metadata                                                     │
│                                                                             │
│  ⚠️  NOTE: DownloadWorker is NOT automatically enqueued                    │
│     • Queue items created with status=:queued                              │
│     • Downloads triggered manually via UI or separate polling              │
│     • This prevents overwhelming the download queue                        │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 4: METADATA EXTRACTION (Asynchronous - Oban Job)                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  Component: Ohdio.Workers.MetadataExtractWorker                             │
│  Location: lib/ohdio/workers/metadata_extract_worker.ex:18-36              │
│  Queue: :metadata (max_attempts: 3)                                        │
│                                                                             │
│  1. Oban picks up job for each audiobook                                   │
│  2. Load audiobook by audiobook_id                                         │
│  3. Call extract_metadata(url, audiobook)                                  │
│                                                                             │
│     Strategy Selection:                                                    │
│     • detect_url_type(url) determines handler                              │
│                                                                             │
│     ┌─────────────────────────────────────────────────────────┐            │
│     │  For OHdio URLs (:ohdio_audiobook, :ohdio_category)    │            │
│     ├─────────────────────────────────────────────────────────┤            │
│     │  • Call Scraper.scrape_audiobook(url)                   │            │
│     │    Location: lib/ohdio/scraper/audiobook_scraper.ex     │            │
│     │  • Extract from HTML:                                   │            │
│     │    - Title, Author, Narrator                            │            │
│     │    - Cover image URL                                    │            │
│     │    - Duration (from metadata or playlist)               │            │
│     │  • Update audiobook with rich metadata                  │            │
│     │  • On failure → fallback to yt-dlp                      │            │
│     └─────────────────────────────────────────────────────────┘            │
│                                                                             │
│     ┌─────────────────────────────────────────────────────────┐            │
│     │  For non-OHdio URLs (:ytdlp_passthrough, :unknown)     │            │
│     ├─────────────────────────────────────────────────────────┤            │
│     │  • Call extract_ytdlp_metadata(url, audiobook)          │            │
│     │  • Execute: yt-dlp --dump-json --no-playlist url        │            │
│     │  • Parse JSON output for:                               │            │
│     │    - title, duration, thumbnail                         │            │
│     │  • Update audiobook with available metadata             │            │
│     └─────────────────────────────────────────────────────────┘            │
│                                                                             │
│  4. Update Audiobook with extracted metadata                               │
│  5. Create QueueItem if not exists (from earlier phase)                    │
│  6. Enqueue DownloadWorker Oban job                                        │
│     • Job args: {queue_item_id, audiobook_id}                              │
│     • Queue: :downloads                                                    │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 5: DOWNLOAD EXECUTION (Asynchronous - Oban Job)                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  Component: Ohdio.Workers.DownloadWorker                                    │
│  Location: lib/ohdio/workers/download_worker.ex:28-103                     │
│  Queue: :downloads (max_attempts: 3)                                       │
│                                                                             │
│  1. Oban picks up job                                                      │
│  2. Load queue_item and audiobook by IDs                                   │
│  3. Check if queue is paused                                               │
│     • If Downloads.paused?() → return {:snooze, 60} (retry in 60s)        │
│                                                                             │
│  4. Update statuses                                                        │
│     • QueueItem.status → :processing                                       │
│     • Audiobook.status → :downloading                                      │
│     • Broadcast PubSub: {:download_progress, started, 0}                  │
│                                                                             │
│  5. Validate download prerequisites                                        │
│     a. Ensure download directory exists (mkdir -p)                         │
│     b. Check directory is writable (test file write)                       │
│     c. Check sufficient disk space (df command)                            │
│        • Require min_disk_space_mb (default: 100MB)                        │
│        • On failure → handle_error and mark as failed                      │
│                                                                             │
│  6. Download with yt-dlp                                                   │
│     Location: lib/ohdio/workers/download_worker.ex:105-166                │
│     • Sanitize filename (remove special chars, limit 200 chars)           │
│     • Output path: {download_dir}/{sanitized_title}.m4a                   │
│     • Execute yt-dlp command:                                              │
│       - For OHdio URLs:                                                    │
│         yt-dlp -f bestaudio -o {output} --no-playlist \                    │
│                --extract-audio --audio-format m4a {url}                    │
│       - For other URLs: same but without --no-playlist                     │
│     • Broadcast progress: {:download_progress, downloading, 50}           │
│                                                                             │
│  7. Embed metadata with FFmpeg                                             │
│     Location: lib/ohdio/workers/download_worker.ex:168-204                │
│     • Create temporary file: {file_path}.tmp.m4a                           │
│     • Execute ffmpeg:                                                      │
│       ffmpeg -i {input} \                                                  │
│              -metadata title={title} \                                     │
│              -metadata artist={author} \                                   │
│              -metadata album_artist={narrator} \                           │
│              -codec copy {temp_output}                                     │
│     • Replace original with metadata-embedded version                      │
│                                                                             │
│  8. Update records on success                                              │
│     • Audiobook updates:                                                   │
│       - status → :completed                                                │
│       - file_path → final_path                                             │
│       - file_size → File.stat!(path).size                                  │
│     • QueueItem.status → :completed                                        │
│     • Broadcast: {:download_progress, completed, 100}                     │
│                                                                             │
│  9. Error handling                                                         │
│     Location: lib/ohdio/workers/download_worker.ex:206-237                │
│     • Increment QueueItem.attempts                                         │
│     • If attempts >= max_attempts (3):                                     │
│       - QueueItem.status → :failed                                         │
│       - Audiobook.status → :failed                                         │
│       - Store error_message                                                │
│       - Broadcast failure                                                  │
│     • If attempts < max_attempts:                                          │
│       - Oban will retry automatically                                      │
└─────────────────────────────┬───────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  PHASE 6: SCRAPE COMPLETION & UI UPDATE                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  Back in CategoryScrapeWorker after all metadata jobs enqueued:            │
│                                                                             │
│  1. Update CategoryScrape record                                           │
│     • status → :completed                                                  │
│     • total_count → length(audiobooks)                                     │
│                                                                             │
│  2. Broadcast PubSub message                                               │
│     Phoenix.PubSub.broadcast(                                              │
│       Ohdio.PubSub,                                                        │
│       "category_scrapes",                                                  │
│       {:category_scrape_updated, scrape}                                   │
│     )                                                                      │
│                                                                             │
│  3. UI receives update via handle_info                                     │
│     Location: lib/ohdio_web/live/queue_live.ex:212-227                    │
│     • Show flash: "Category scraped! Found N audiobooks"                   │
│     • Update active_scrapes display                                        │
│     • Reload queue data to show new items                                  │
└─────────────────────────────────────────────────────────────────────────────┘


                    ┌───────────────────────────┐
                    │   ALL DOWNLOADS COMPLETE  │
                    └───────────────────────────┘
```

---

## State Transitions

### CategoryScrape States
```
:scraping → :completed  (success)
         ↘ :failed      (error during scraping)
```

### Audiobook States
```
:pending → :downloading → :completed  (success)
                       ↘ :failed      (error)
```

### QueueItem States
```
:queued → :processing → :completed  (success)
                     ↘ :failed      (max retries exceeded)
        ↺ (retry on failure, up to max_attempts)
```

---

## PubSub Topics & Events

### "category_scrapes"
- **Subscribers**: OhdioWeb.QueueLive
- **Messages**:
  - `{:category_scrape_updated, scrape}` - Scrape status changed

### "queue_updates"
- **Subscribers**: OhdioWeb.QueueLive
- **Messages**:
  - `{:queue_updated, data}` - Queue item created/updated/deleted

### "downloads"
- **Subscribers**: OhdioWeb.QueueLive
- **Messages**:
  - `{:download_progress, %{audiobook_id, status, progress}}` - Download progress

---

## Error Handling & Recovery

### CategoryScrapeWorker Errors
- HTTP fetch failure → update scrape status to :failed with error_message
- Parsing errors → logged but continue with partial results
- Job failure → Oban retries up to 3 times

### MetadataExtractWorker Errors
- OHdio scraping fails → fallback to yt-dlp metadata extraction
- yt-dlp fails → audiobook status set to :failed
- Job failure → Oban retries up to 3 times

### DownloadWorker Errors
- Queue paused → job snoozed for 60 seconds
- Directory/disk space issues → immediate failure with descriptive error
- yt-dlp download fails → retry up to max_attempts
- FFmpeg metadata embed fails → retry up to max_attempts
- Max attempts reached → queue_item and audiobook marked as :failed

### Duplicate Handling
- Audiobooks have unique constraint on URL
- If duplicate found during category scrape → use existing record
- Check if file exists on filesystem before queueing download
- Check for existing queue item before creating new one

---

## Key Design Decisions

### 1. Asynchronous Job Processing
- Uses Oban for reliable background job execution
- Separate queues for different phases: :scraping, :metadata, :downloads
- Each phase can scale independently

### 2. Real-time UI Updates
- Phoenix PubSub broadcasts status changes
- LiveView subscriptions enable real-time feedback
- Users see progress without polling

### 3. Metadata Before Download
- Two-phase approach: metadata extraction → download
- Ensures rich metadata available before/during download
- Allows filtering/prioritization based on metadata

### 4. Deferred Download Execution
- Category scrape creates queue items but doesn't auto-download
- Prevents overwhelming the system with hundreds of concurrent downloads
- User can manually trigger downloads or implement polling mechanism
- Allows prioritization and queue management

### 5. Multiple Fallback Strategies
- Category scraping: 4 different HTML parsing strategies
- Metadata extraction: OHdio scraper → yt-dlp fallback
- Robust against HTML structure changes

### 6. File System as Source of Truth
- Check `File.exists?(audiobook.file_path)` before queueing
- Prevents re-downloading existing files
- Database records may be out of sync, filesystem is authoritative

### 7. Queue Control
- Global pause/resume functionality
- Workers check pause state and snooze if paused
- Allows system maintenance without job loss

---

## Performance Characteristics

### Concurrent Processing
- **Scraping**: 1 category page at a time per job
- **Metadata**: Multiple audiobooks processed concurrently (Oban config)
- **Downloads**: Controlled by queue_control.max_concurrent_downloads

### Typical Timeline (for 50 audiobooks)
1. **URL submission → Scrape completion**: 5-15 seconds
2. **Metadata extraction per audiobook**: 2-5 seconds
3. **Download per audiobook**: 30 seconds - 5 minutes (depends on file size)

### Resource Usage
- **Memory**: Minimal - streaming downloads, no large buffers
- **Disk**: Configurable minimum free space check (default 100MB)
- **Network**: Throttled by yt-dlp and Oban concurrency

---

## Code References

### Entry Point
- `lib/ohdio_web/live/queue_live.ex:41-50` - Form submission handler
- `lib/ohdio_web/live/queue_live.ex:256-339` - URL processing logic

### Scraping
- `lib/ohdio/scraper/category_scraper.ex:45-112` - Category scraping
- `lib/ohdio/scraper/audiobook_scraper.ex` - Audiobook metadata extraction

### Workers
- `lib/ohdio/workers/category_scrape_worker.ex:18-93` - Category scrape orchestration
- `lib/ohdio/workers/metadata_extract_worker.ex:18-97` - Metadata extraction
- `lib/ohdio/workers/download_worker.ex:28-359` - Download execution

### Contexts
- `lib/ohdio/library.ex` - Audiobook and CategoryScrape operations
- `lib/ohdio/downloads.ex` - QueueItem and QueueControl operations

### Schemas
- `lib/ohdio/library/audiobook.ex` - Audiobook model
- `lib/ohdio/library/category_scrape.ex` - CategoryScrape model
- `lib/ohdio/downloads/queue_item.ex` - QueueItem model

---

## Future Enhancements

Based on the codebase analysis, potential improvements:

1. **Automatic Download Polling**
   - Currently downloads are not automatically triggered from category scrapes
   - Could implement periodic worker to process :queued items

2. **Progress Tracking**
   - Add percentage completion to download_worker
   - Parse yt-dlp output for real-time progress

3. **Batch Operations**
   - Bulk priority changes
   - Bulk retry for failed items

4. **Smart Retry**
   - Exponential backoff for transient failures
   - Different max_attempts based on error type

5. **Advanced Queue Management**
   - Priority-based worker assignment
   - Time-based scheduling (download during off-peak hours)

6. **Monitoring & Metrics**
   - Track success/failure rates
   - Average download times
   - Disk usage trends
