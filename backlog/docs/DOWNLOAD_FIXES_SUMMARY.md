# Download System Fixes Summary

## Issue
All 144 queue items were stuck in "processing" status with 0 attempts, and no downloads were completing.

## Root Causes Found

### 1. **RateLimiter Timeout** (lib/ohdio/scraper/rate_limiter.ex:44-46)
- **Problem**: GenServer.call had default 5-second timeout
- **Impact**: With 2s delay between OHdio requests and 15+ concurrent workers, calls queued up and timed out
- **Fix**: Increased timeout to 60,000ms (60 seconds)

### 2. **JSON Decoding Error** (lib/ohdio/scraper/playlist_extractor.ex:134-171)
- **Problem**: Req library automatically decodes JSON responses into maps, but code called `Jason.decode` on already-decoded map
- **Impact**: All downloads failed with `ArgumentError: not an iodata term` when trying to decode a map
- **Fix**: Added conditional logic to handle both pre-decoded maps and JSON strings

### 3. **Validation & Error Handling** (lib/ohdio/workers/download_worker.ex)
- **Problem**: Download worker crashed before incrementing attempt counters
- **Impact**: Jobs retried infinitely without proper error tracking
- **Fix**: Added input validation for yt-dlp arguments with detailed error messages

## Files Modified

1. **lib/ohdio/scraper/rate_limiter.ex**
   - Line 44-46: Added 60-second timeout to GenServer.call

2. **lib/ohdio/scraper/playlist_extractor.ex**
   - Lines 134-171: Conditional JSON handling for Req auto-decoded responses
   - Lines 37-47: Added binary type validation for playlist URLs

3. **lib/ohdio/workers/download_worker.ex**
   - Lines 128-145: Enhanced logging for download debugging
   - Lines 161-206: Input validation for yt-dlp arguments
   - Lines 399-400: Added :invalid_arguments error message

4. **lib/ohdio/scraper/category_scraper.ex**
   - Line 188: Filter to exclude category URLs from audiobook results

## Scripts Created

1. **reset_download_queue.exs** - Reset stuck queue and create fresh Oban jobs
2. **retry_failed_downloads.exs** - Cleanup invalid audiobooks and retry failed items
3. **enqueue_missing_downloads.exs** - Create jobs for queue items without Oban jobs

## Results

**Before fixes:**
- 144 items stuck in processing
- 0 completions
- Jobs failing with ArgumentError
- Retry delays up to 3 days due to exponential backoff

**After fixes:**
- Downloads completing successfully (9+ in first 2 minutes)
- Proper error handling and logging
- Rate limiting working correctly
- Queue processing normally

## Current Status (as of 2025-10-14 15:20 UTC)
- Total: 144
- Queued: 129
- Processing: 6
- Completed: 9
- Failed: 0

✓ System healthy and processing downloads
