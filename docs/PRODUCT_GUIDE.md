# OHdio Audiobook Downloader - Product Guide

## Overview

The OHdio Audiobook Downloader is a specialized tool designed to scrape and download audiobooks from Radio-Canada's OHdio platform, specifically targeting the youth category (Jeunesse). It automates the entire process from discovery to download, including metadata embedding and proper file organization.

## Key Features

### 1. Automated Discovery
- Scrapes the OHdio Jeunesse category page to find all available audiobooks
- Extracts book URLs, titles, authors, and cover art automatically
- Handles pagination to discover all available content

### 2. Playlist Extraction
- Analyzes individual audiobook pages to locate m3u8 playlist URLs
- Uses advanced parsing techniques to find embedded media streams
- Supports various playlist formats and encoding schemes

### 3. High-Quality Downloads
- Leverages yt-dlp for reliable, high-quality audio downloads
- Downloads in MP3 format with optimal quality settings
- Supports resume functionality for interrupted downloads

### 4. Metadata Management
- Embeds comprehensive metadata into downloaded files:
  - Title
  - Author
  - Description
  - Cover artwork
  - Publication information
- Ensures files are properly tagged for media library organization

### 5. Smart File Organization
- Automatically renames files using a consistent format: `{Author} - {Title}.mp3`
- Creates organized directory structure
- Handles special characters and filename sanitization

## Usage Instructions

### Basic Usage

1. **Installation**
   ```bash
   git clone <repository-url>
   cd ohdio-audiobook-downloader
   uv sync
   ```

2. **Run the Scraper**
   ```bash
   uv run python main.py
   ```

3. **Monitor Progress**
   - The tool will display progress information in the console
   - Check the `downloads/` directory for completed files
   - Review logs in `logs/` directory for detailed information

### Configuration Options

The tool supports various configuration options through `config.json`:

```json
{
  "output_directory": "downloads",
  "max_concurrent_downloads": 3,
  "retry_attempts": 3,
  "delay_between_requests": 1.0,
  "audio_quality": "best",
  "embed_metadata": true,
  "skip_existing": true
}
```

#### Configuration Parameters

- **output_directory**: Where to save downloaded audiobooks
- **max_concurrent_downloads**: Number of simultaneous downloads (default: 3)
- **retry_attempts**: How many times to retry failed downloads
- **delay_between_requests**: Delay in seconds between web requests (be respectful)
- **audio_quality**: Audio quality preference ("best", "medium", "low")
- **embed_metadata**: Whether to embed metadata into files
- **skip_existing**: Skip files that already exist

### Advanced Usage

#### Custom URL Lists
You can provide a custom list of audiobook URLs to download:

```bash
uv run python main.py --urls urls.txt
```

#### Specific Author Filter
Download only books by specific authors:

```bash
uv run python main.py --author "Élise Gravel"
```

#### Download Range
Download only a specific range of books:

```bash
uv run python main.py --start 10 --end 20
```

## Output Structure

The tool organizes downloads in the following structure:

```
downloads/
├── Élise Gravel - Ada la grincheuse en tutu.mp3
├── François Blais - 752 lapins.mp3
├── Chloé Varin - À qui la frite.mp3
└── ...
```

Each file includes:
- Properly formatted filename
- Embedded metadata (title, author, artwork)
- High-quality MP3 audio

## Error Handling

The tool includes robust error handling for common scenarios:

- **Network Issues**: Automatic retry with exponential backoff
- **Invalid URLs**: Graceful skipping with detailed logging
- **Missing Playlists**: Fallback detection methods
- **Download Failures**: Retry mechanisms and error reporting

## Performance Considerations

### Respectful Scraping
- Built-in delays between requests to avoid overwhelming servers
- User-Agent rotation to appear as regular browser traffic
- Rate limiting to stay within reasonable usage bounds

### Efficiency Features
- Concurrent downloads (configurable limit)
- Resume capability for interrupted downloads
- Skip existing files to avoid re-downloading
- Efficient memory usage for large collections

## Legal and Ethical Considerations

### Important Notice
This tool is provided for educational purposes only. Users must:

1. **Respect Copyright**: Only download content you have legal access to
2. **Follow Terms of Service**: Comply with Radio-Canada's terms of use
3. **Personal Use Only**: Do not redistribute downloaded content
4. **Rate Limiting**: Use reasonable delays to avoid server overload

### Recommended Practices
- Run during off-peak hours to minimize server impact
- Use the tool sparingly and responsibly
- Respect the content creators and platform
- Consider supporting Radio-Canada through official channels

## Troubleshooting

### Common Issues

1. **No Playlists Found**
   - Check if the website structure has changed
   - Verify URL accessibility
   - Review debug logs for parsing errors

2. **Download Failures**
   - Ensure yt-dlp is up to date
   - Check network connectivity
   - Verify sufficient disk space

3. **Metadata Errors**
   - Some books may have incomplete metadata
   - Check source page for missing information
   - Manual metadata editing may be required

### Getting Help

- Check the logs in `logs/scraper.log` for detailed error information
- Review the development guide for technical details
- Submit issues with detailed error logs and steps to reproduce

## Future Enhancements

Planned features for future versions:

- **Multiple Categories**: Support for other OHdio categories beyond Jeunesse
- **GUI Interface**: User-friendly graphical interface
- **Playlist Management**: Create and manage custom playlists
- **Cloud Storage**: Direct upload to cloud storage services
- **Mobile App**: Mobile companion app for remote monitoring 