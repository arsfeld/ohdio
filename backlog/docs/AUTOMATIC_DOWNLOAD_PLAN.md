# Automatic Queue Download Implementation Plan

## Problem Statement

Currently, audiobooks discovered via category scraping are added to the queue but not automatically downloaded. The system has the following issues:

1. **CategoryScrapeWorker** explicitly avoids enqueueing DownloadWorker jobs (line 156-161)
2. **MetadataExtractWorker** creates queue items and enqueues downloads, but may create duplicate queue items
3. **Oban downloads queue** concurrency is hardcoded to 3, not using the configurable `max_concurrent` value
4. **No automatic processing** of items added by category scrapes

## Current State Analysis

### Oban Queue Configuration
**Location**: `config/config.exs:60-65`
```elixir
queues: [
  default: 10,
  scraping: 5,
  metadata: 10,
  downloads: 3  # ← HARDCODED, should use config
]
```

### Download Concurrency Config
**Location**: `config/config.exs:68-76`
```elixir
config :ohdio, :downloads,
  max_concurrent: String.to_integer(System.get_env("MAX_CONCURRENT_DOWNLOADS") || "3")
  # ↑ This is NOT being used by Oban queue concurrency
```

### Flow Issues

**Individual Audiobook URL Flow** (WORKS):
```
QueueLive → MetadataExtractWorker → creates QueueItem → enqueues DownloadWorker ✓
```

**Category Scrape Flow** (BROKEN):
```
QueueLive → CategoryScrapeWorker → creates QueueItem → enqueues MetadataExtractWorker
            ↓
MetadataExtractWorker → tries to create ANOTHER QueueItem → enqueues DownloadWorker
                        ↑ Potential duplicate queue items!
```

## Solution Design

### Approach: Fix Existing Flow + Configure Concurrency

Rather than adding a new polling worker, fix the existing worker flow to properly handle all cases:

1. **Make Oban downloads queue respect configured concurrency**
2. **Fix MetadataExtractWorker to handle existing queue items**
3. **Enable automatic DownloadWorker enqueueing for all sources**
4. **Add unique constraint to prevent duplicate queue items**

### Implementation Steps

#### Step 1: Add Unique Constraint to QueueItem
**File**: New migration
**Action**: Add unique index on `audiobook_id` to prevent duplicates

```elixir
defmodule Ohdio.Repo.Migrations.AddUniqueIndexToQueueItems do
  use Ecto.Migration

  def change do
    create unique_index(:queue_items, [:audiobook_id])
  end
end
```

#### Step 2: Fix MetadataExtractWorker to Handle Existing QueueItems
**File**: `lib/ohdio/workers/metadata_extract_worker.ex:18-36`
**Current Code**:
```elixir
{:ok, updated_audiobook} ->
  # Create queue item and enqueue download job
  {:ok, queue_item} = Downloads.create_queue_item(%{audiobook_id: updated_audiobook.id})

  %{queue_item_id: queue_item.id, audiobook_id: updated_audiobook.id}
  |> DownloadWorker.new()
  |> Oban.insert()
```

**New Code**:
```elixir
{:ok, updated_audiobook} ->
  # Get or create queue item
  queue_item =
    case Ohdio.Repo.get_by(Downloads.QueueItem, audiobook_id: updated_audiobook.id) do
      nil ->
        # Create new queue item
        {:ok, qi} = Downloads.create_queue_item(%{
          audiobook_id: updated_audiobook.id,
          status: :queued,
          priority: 5
        })
        qi

      existing_item ->
        # Use existing queue item (created by CategoryScrapeWorker)
        existing_item
    end

  # Only enqueue download if file doesn't exist
  file_exists? = case updated_audiobook.file_path do
    nil -> false
    path -> File.exists?(path)
  end

  if not file_exists? and queue_item.status == :queued do
    %{queue_item_id: queue_item.id, audiobook_id: updated_audiobook.id}
    |> DownloadWorker.new()
    |> Oban.insert()
  end
```

#### Step 3: Configure Oban Downloads Queue with Dynamic Concurrency
**File**: `config/config.exs:55-65`
**Current Code**:
```elixir
config :ohdio, Oban,
  repo: Ohdio.Repo,
  engine: Oban.Engines.Lite,
  notifier: Oban.Notifiers.PG,
  plugins: [Oban.Plugins.Pruner],
  queues: [
    default: 10,
    scraping: 5,
    metadata: 10,
    downloads: 3
  ]
```

**New Code**:
```elixir
# Get max concurrent downloads from env or use default
max_concurrent_downloads = String.to_integer(System.get_env("MAX_CONCURRENT_DOWNLOADS") || "3")

config :ohdio, Oban,
  repo: Ohdio.Repo,
  engine: Oban.Engines.Lite,
  notifier: Oban.Notifiers.PG,
  plugins: [Oban.Plugins.Pruner],
  queues: [
    default: 10,
    scraping: 5,
    metadata: 10,
    downloads: max_concurrent_downloads
  ]
```

#### Step 4: Remove Download Prevention in CategoryScrapeWorker
**File**: `lib/ohdio/workers/category_scrape_worker.ex:150-161`
**Action**: Remove the NOTE comment about not enqueueing downloads - this is now handled properly by MetadataExtractWorker

**Current Code**:
```elixir
# Enqueue metadata extraction job
%{audiobook_id: audiobook.id, url: book_info.url}
|> MetadataExtractWorker.new()
|> Oban.insert()

# NOTE: DownloadWorker jobs are NOT enqueued here to avoid flooding
# the queue. Instead, downloads are triggered:
# 1. Manually via UI/API
# 2. Or by a separate polling mechanism (future enhancement)
```

**New Code**:
```elixir
# Enqueue metadata extraction job
# MetadataExtractWorker will automatically enqueue DownloadWorker
# respecting the configured max_concurrent_downloads limit
%{audiobook_id: audiobook.id, url: book_info.url}
|> MetadataExtractWorker.new()
|> Oban.insert()
```

#### Step 5: Update QueueItem Schema for Unique Constraint
**File**: `lib/ohdio/downloads/queue_item.ex:20-28`
**Current Code**:
```elixir
def changeset(queue_item, attrs) do
  queue_item
  |> cast(attrs, [:audiobook_id, :status, :priority, :attempts, :max_attempts, :error_message])
  |> validate_required([:audiobook_id])
  |> foreign_key_constraint(:audiobook_id)
  |> validate_number(:priority, greater_than_or_equal_to: 0)
  |> validate_number(:attempts, greater_than_or_equal_to: 0)
  |> validate_number(:max_attempts, greater_than: 0)
end
```

**New Code**:
```elixir
def changeset(queue_item, attrs) do
  queue_item
  |> cast(attrs, [:audiobook_id, :status, :priority, :attempts, :max_attempts, :error_message])
  |> validate_required([:audiobook_id])
  |> foreign_key_constraint(:audiobook_id)
  |> unique_constraint(:audiobook_id)  # ← ADD THIS
  |> validate_number(:priority, greater_than_or_equal_to: 0)
  |> validate_number(:attempts, greater_than_or_equal_to: 0)
  |> validate_number(:max_attempts, greater_than: 0)
end
```

#### Step 6: Add Tests
**Files to create/update**:
- `test/ohdio/workers/metadata_extract_worker_test.exs` - Test handling of existing queue items
- `test/ohdio_web/live/queue_live_test.exs` - Test category scrape → automatic download flow

## Expected Behavior After Implementation

### Category Scrape Flow
1. User submits category URL
2. CategoryScrapeWorker discovers 50 audiobooks
3. For each audiobook:
   - Creates Audiobook record (or uses existing)
   - Creates QueueItem with status=:queued, priority=5 (or uses existing)
   - Enqueues MetadataExtractWorker
4. MetadataExtractWorker runs for each audiobook:
   - Extracts metadata
   - Updates Audiobook record
   - Finds existing QueueItem (created in step 3)
   - Enqueues DownloadWorker if file doesn't exist
5. DownloadWorker processes jobs:
   - **Maximum 3 concurrent downloads** (or configured value)
   - Additional jobs wait in Oban queue
   - Respects pause/resume controls

### Individual Audiobook URL Flow
1. User submits single audiobook URL
2. QueueLive enqueues MetadataExtractWorker
3. MetadataExtractWorker:
   - Extracts metadata
   - Creates QueueItem (no existing one)
   - Enqueues DownloadWorker
4. Download starts automatically

## Benefits

1. **Automatic Downloads**: No manual intervention needed after category scrape
2. **Respects Concurrency**: Oban queue limit prevents overwhelming the system
3. **No Duplicates**: Unique constraint prevents duplicate queue items
4. **Configurable**: MAX_CONCURRENT_DOWNLOADS env var controls concurrency
5. **Backwards Compatible**: Existing flows continue to work
6. **Pause/Resume Works**: DownloadWorker already checks queue pause state

## Testing Strategy

### Unit Tests
- MetadataExtractWorker with existing queue item
- MetadataExtractWorker without existing queue item
- Unique constraint violation handling

### Integration Tests
- Category scrape → metadata extraction → download
- Verify max 3 concurrent downloads
- Verify pause/resume interrupts downloads
- Verify no duplicate queue items created

### Manual Testing
1. Scrape category with 10+ audiobooks
2. Verify 3 downloads start immediately
3. Verify remaining items wait in queue
4. Verify downloads complete and next batch starts
5. Test pause/resume functionality
6. Test with different MAX_CONCURRENT_DOWNLOADS values

## Rollback Plan

If issues arise:
1. Revert migration adding unique constraint
2. Revert MetadataExtractWorker changes
3. Revert config.exs Oban queue configuration
4. System returns to current "manual download" behavior

## Success Criteria

- [ ] Category scrape automatically downloads all discovered audiobooks
- [ ] Maximum of 3 (or configured) concurrent downloads at any time
- [ ] No duplicate queue items created
- [ ] Pause/resume controls work correctly
- [ ] Individual audiobook URLs still work
- [ ] All tests pass
- [ ] Documentation updated

## Timeline Estimate

- Step 1 (Migration): 15 minutes
- Step 2 (MetadataExtractWorker): 45 minutes
- Step 3 (Oban config): 15 minutes
- Step 4 (CategoryScrapeWorker): 10 minutes
- Step 5 (Schema update): 10 minutes
- Step 6 (Tests): 90 minutes
- Manual testing: 30 minutes
- **Total**: ~3.5 hours

## References

- Current analysis: `/home/arosenfeld/Code/ohdio/CATEGORY_SCRAPING_FLOW_ANALYSIS.md`
- Oban docs: https://hexdocs.pm/oban/Oban.html
- Related issues:
  - task-15: Fix category scrape not populating queue
  - task-18: Fix download worker not processing queued items
