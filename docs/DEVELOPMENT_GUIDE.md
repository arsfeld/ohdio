# OHdio Audiobook Downloader - Development Guide

## Architecture Overview

The OHdio Audiobook Downloader follows a modular architecture designed for maintainability, extensibility, and robust error handling.

### Core Components

```
src/
├── scraper/
│   ├── __init__.py
│   ├── category_scraper.py    # Scrapes the main category page
│   ├── audiobook_scraper.py   # Extracts data from individual book pages
│   └── playlist_extractor.py  # Finds m3u8 playlists in pages
├── downloader/
│   ├── __init__.py
│   ├── ytdlp_downloader.py    # Handles yt-dlp downloads
│   └── metadata_manager.py    # Manages metadata embedding
├── utils/
│   ├── __init__.py
│   ├── config.py              # Configuration management
│   ├── logger.py              # Logging setup
│   ├── file_utils.py          # File operations and naming
│   └── network_utils.py       # Network utilities and headers
└── main.py                    # Main application entry point
```

## Technical Stack

### Primary Dependencies

- **Python 3.8+**: Core runtime
- **requests**: HTTP client for web scraping
- **BeautifulSoup4**: HTML parsing and extraction
- **yt-dlp**: Media download engine
- **mutagen**: Audio metadata manipulation
- **aiohttp**: Async HTTP for concurrent operations
- **lxml**: Fast XML/HTML parsing

### Optional Dependencies

- **Pillow**: Image processing for artwork
- **tqdm**: Progress bars
- **colorama**: Colored console output

## Implementation Details

### 1. Category Scraper (`category_scraper.py`)

Responsible for discovering all audiobooks in the Jeunesse category.

```python
class CategoryScraper:
    def __init__(self, config):
        self.config = config
        self.session = requests.Session()
        self.logger = logging.getLogger(__name__)
    
    async def scrape_category(self, category_url):
        """Scrape all audiobooks from the category page"""
        # Implementation details below
```

**Key Features:**
- Handles pagination automatically
- Extracts book URLs, titles, authors, and thumbnails
- Implements rate limiting and retry logic
- Returns structured data for downstream processing

**Implementation Strategy:**
- Parse HTML using BeautifulSoup
- Extract book links using CSS selectors
- Handle JavaScript-rendered content if necessary
- Implement robust error handling for network issues

### 2. Audiobook Scraper (`audiobook_scraper.py`)

Extracts detailed information from individual audiobook pages.

```python
class AudiobookScraper:
    def __init__(self, config):
        self.config = config
        self.playlist_extractor = PlaylistExtractor(config)
    
    async def scrape_audiobook(self, book_url):
        """Extract all metadata and playlist URL from book page"""
        # Implementation details below
```

**Key Features:**
- Extracts comprehensive metadata
- Locates playlist URLs
- Downloads cover artwork
- Validates extracted data

**Parsing Strategy:**
- Use multiple fallback methods for playlist detection
- Handle various page layouts and structures
- Extract metadata from structured data (JSON-LD, microdata)
- Implement caching for repeated requests

### 3. Playlist Extractor (`playlist_extractor.py`)

Specialized component for finding m3u8 playlist URLs.

```python
class PlaylistExtractor:
    def __init__(self, config):
        self.config = config
        self.logger = logging.getLogger(__name__)
    
    def extract_playlist_url(self, page_content, page_url):
        """Extract m3u8 playlist URL from page content"""
        # Multiple extraction methods
```

**Extraction Methods:**
1. **Script Tag Analysis**: Parse JavaScript variables
2. **Network Request Interception**: Monitor XHR requests
3. **Pattern Matching**: Regex-based URL detection
4. **DOM Analysis**: Search for media elements

**Example Detection Patterns:**
```python
PLAYLIST_PATTERNS = [
    r'https://[^"\']+\.m3u8[^"\']*',
    r'master\.m3u8',
    r'playlist\.m3u8',
    r'rcavmedias\.akamaized\.net/[^"\']+/master\.m3u8'
]
```

### 4. Download Manager (`ytdlp_downloader.py`)

Handles the actual downloading using yt-dlp.

```python
class YtdlpDownloader:
    def __init__(self, config):
        self.config = config
        self.logger = logging.getLogger(__name__)
    
    async def download_audiobook(self, playlist_url, metadata):
        """Download audiobook and embed metadata"""
        # Implementation details below
```

**Download Configuration:**
```python
ytdl_opts = {
    'format': 'bestaudio/best',
    'outtmpl': '%(title)s.%(ext)s',
    'extractaudio': True,
    'audioformat': 'mp3',
    'audioquality': '192K',
    'postprocessors': [{
        'key': 'FFmpegExtractAudio',
        'preferredcodec': 'mp3',
        'preferredquality': '192',
    }],
    'writeinfojson': False,
    'writedescription': False,
    'writesubtitles': False,
}
```

### 5. Metadata Manager (`metadata_manager.py`)

Handles metadata embedding and file organization.

```python
class MetadataManager:
    def __init__(self, config):
        self.config = config
    
    def embed_metadata(self, audio_file, metadata):
        """Embed metadata into audio file"""
        # Use mutagen to add ID3 tags
```

**Metadata Fields:**
- Title (TIT2)
- Artist/Author (TPE1)
- Album (TALB)
- Year (TYER)
- Genre (TCON)
- Cover Art (APIC)
- Description (COMM)

## Development Setup

### 1. Environment Setup

```bash
# Clone repository
git clone <repository-url>
cd ohdio-audiobook-downloader

# Install uv if not already installed
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies and create virtual environment
uv sync --dev  # Installs both production and development dependencies
```

### 2. Development Dependencies

Development dependencies are defined in `pyproject.toml` under `[project.optional-dependencies]`:

```toml
[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-asyncio>=0.21.0",
    "black>=22.0.0",
    "flake8>=4.0.0",
    "mypy>=0.991",
    "pre-commit>=2.20.0",
    "coverage>=6.0.0",
    "types-requests>=2.28.0",
    "types-beautifulsoup4>=4.11.0",
]
```

### 3. Code Quality Tools

#### Pre-commit Hooks
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/psf/black
    rev: 22.10.0
    hooks:
      - id: black
  - repo: https://github.com/PyCQA/flake8
    rev: 5.0.4
    hooks:
      - id: flake8
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v0.991
    hooks:
      - id: mypy
```

#### Running Development Tools

```bash
# Run tests
uv run pytest

# Run type checking
uv run mypy src/

# Format code
uv run black src/ tests/

# Run linter
uv run flake8 src/ tests/

# Run all checks
uv run pre-commit run --all-files
```

#### Testing Setup
```python
# tests/conftest.py
import pytest
import asyncio
from unittest.mock import Mock
from src.utils.config import Config

@pytest.fixture
def config():
    return Config('test_config.json')

@pytest.fixture
def event_loop():
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()
```

### 4. Configuration Management

```python
# src/utils/config.py
import json
from dataclasses import dataclass
from typing import Optional

@dataclass
class Config:
    output_directory: str = "downloads"
    max_concurrent_downloads: int = 3
    retry_attempts: int = 3
    delay_between_requests: float = 1.0
    audio_quality: str = "best"
    embed_metadata: bool = True
    skip_existing: bool = True
    
    @classmethod
    def from_file(cls, config_file: str) -> 'Config':
        """Load configuration from JSON file"""
        with open(config_file, 'r') as f:
            data = json.load(f)
        return cls(**data)
```

## Error Handling Strategy

### 1. Network Errors
```python
import aiohttp
from aiohttp import ClientError
import asyncio
from typing import Optional

async def safe_request(url: str, max_retries: int = 3) -> Optional[str]:
    """Make HTTP request with retry logic"""
    for attempt in range(max_retries):
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url) as response:
                    if response.status == 200:
                        return await response.text()
                    elif response.status == 429:  # Rate limited
                        await asyncio.sleep(2 ** attempt)
                        continue
        except ClientError as e:
            logger.warning(f"Request failed (attempt {attempt + 1}): {e}")
            if attempt < max_retries - 1:
                await asyncio.sleep(2 ** attempt)
    return None
```

### 2. Parsing Errors
```python
def safe_extract_text(element, selector: str, default: str = "") -> str:
    """Safely extract text from HTML element"""
    try:
        found = element.select_one(selector)
        return found.get_text(strip=True) if found else default
    except Exception as e:
        logger.warning(f"Failed to extract text with selector '{selector}': {e}")
        return default
```

### 3. Download Errors
```python
def handle_download_error(error, url: str, metadata: dict):
    """Handle various yt-dlp download errors"""
    if "HTTP Error 403" in str(error):
        logger.error(f"Access denied for {url}")
        return "access_denied"
    elif "network" in str(error).lower():
        logger.error(f"Network error downloading {url}")
        return "network_error"
    else:
        logger.error(f"Unknown download error for {url}: {error}")
        return "unknown_error"
```

## Performance Optimization

### 1. Concurrent Processing
```python
import asyncio
from asyncio import Semaphore

class ConcurrentScraper:
    def __init__(self, max_concurrent: int = 3):
        self.semaphore = Semaphore(max_concurrent)
    
    async def process_urls(self, urls: list[str]):
        """Process multiple URLs concurrently"""
        tasks = [self.process_single_url(url) for url in urls]
        return await asyncio.gather(*tasks, return_exceptions=True)
    
    async def process_single_url(self, url: str):
        async with self.semaphore:
            # Process single URL
            await asyncio.sleep(self.config.delay_between_requests)
            return await self.scrape_audiobook(url)
```

### 2. Caching Strategy
```python
import pickle
from pathlib import Path
from typing import Optional, Any

class SimpleCache:
    def __init__(self, cache_dir: str = ".cache"):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(exist_ok=True)
    
    def get(self, key: str) -> Optional[Any]:
        cache_file = self.cache_dir / f"{key}.pkl"
        if cache_file.exists():
            with open(cache_file, 'rb') as f:
                return pickle.load(f)
        return None
    
    def set(self, key: str, value: Any):
        cache_file = self.cache_dir / f"{key}.pkl"
        with open(cache_file, 'wb') as f:
            pickle.dump(value, f)
```

## Testing Strategy

### 1. Unit Tests
```python
# tests/test_playlist_extractor.py
import pytest
from src.scraper.playlist_extractor import PlaylistExtractor

class TestPlaylistExtractor:
    def test_extract_from_script_tag(self):
        html_content = '''
        <script>
        var playlistUrl = "https://rcavmedias.akamaized.net/test/master.m3u8";
        </script>
        '''
        extractor = PlaylistExtractor(config)
        result = extractor.extract_playlist_url(html_content, "test_url")
        assert "master.m3u8" in result
```

### 2. Integration Tests
```python
# tests/test_integration.py
import pytest
from src.main import AudiobookDownloader

@pytest.mark.asyncio
async def test_full_scraping_workflow():
    """Test complete workflow from scraping to download"""
    downloader = AudiobookDownloader(config)
    # Mock external dependencies
    # Test workflow
```

### 3. Mock Data
```python
# tests/fixtures/sample_data.py
SAMPLE_CATEGORY_HTML = """
<div class="audiobook-item">
    <a href="/livres-audio/123/test-book">
        <h3>Test Book</h3>
        <p>Test Author</p>
    </a>
</div>
"""

SAMPLE_AUDIOBOOK_HTML = """
<script>
var mediaData = {
    "playlistUrl": "https://rcavmedias.akamaized.net/test/master.m3u8"
};
</script>
"""
```

## Deployment and Distribution

### 1. Docker Support
```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY src/ ./src/
COPY config.json .

CMD ["python", "src/main.py"]
```

### 2. Package Distribution

With uv and pyproject.toml, package distribution is handled automatically:

```bash
# Build the package
uv build

# Install the package locally for development
uv pip install -e .

# Install from built package
uv pip install dist/ohdio_audiobook_downloader-1.0.0-py3-none-any.whl
```

The package configuration is defined in `pyproject.toml`:

```toml
[project.scripts]
ohdio-downloader = "src.main:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

## Monitoring and Logging

### 1. Structured Logging
```python
# src/utils/logger.py
import logging
import json
from datetime import datetime

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno
        }
        return json.dumps(log_entry)

def setup_logging(log_level: str = "INFO"):
    """Setup structured logging"""
    logger = logging.getLogger()
    logger.setLevel(getattr(logging, log_level.upper()))
    
    handler = logging.FileHandler("logs/scraper.log")
    handler.setFormatter(JSONFormatter())
    logger.addHandler(handler)
```

### 2. Metrics Collection
```python
# src/utils/metrics.py
from dataclasses import dataclass
from typing import Dict
import time

@dataclass
class ScrapingMetrics:
    books_discovered: int = 0
    books_downloaded: int = 0
    books_failed: int = 0
    total_duration: float = 0.0
    start_time: float = 0.0
    
    def start_timing(self):
        self.start_time = time.time()
    
    def end_timing(self):
        self.total_duration = time.time() - self.start_time
    
    def to_dict(self) -> Dict:
        return {
            "books_discovered": self.books_discovered,
            "books_downloaded": self.books_downloaded,
            "books_failed": self.books_failed,
            "success_rate": self.books_downloaded / max(self.books_discovered, 1),
            "total_duration": self.total_duration
        }
```

This development guide provides a comprehensive foundation for implementing the OHdio audiobook downloader with proper architecture, error handling, and development practices. 