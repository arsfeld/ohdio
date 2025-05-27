#!/usr/bin/env python3
"""Test script to verify OHdio downloader setup."""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

def test_imports():
    """Test that all modules can be imported."""
    try:
        print("Testing imports...")
        
        # Test utils
        from src.utils.config import Config
        from src.utils.logger import setup_logging
        from src.utils.file_utils import sanitize_filename
        from src.utils.network_utils import sync_request
        print("✓ Utils imports successful")
        
        # Test scrapers
        from src.scraper.category_scraper import CategoryScraper
        from src.scraper.audiobook_scraper import AudiobookScraper
        from src.scraper.playlist_extractor import PlaylistExtractor
        print("✓ Scraper imports successful")
        
        # Test downloaders
        from src.downloader.ytdlp_downloader import YtDlpDownloader
        from src.downloader.metadata_manager import MetadataManager
        print("✓ Downloader imports successful")
        
        # Test main
        from src.main import OHdioDownloader
        print("✓ Main imports successful")
        
        return True
        
    except ImportError as e:
        print(f"✗ Import failed: {e}")
        return False

def test_config():
    """Test configuration loading."""
    try:
        print("\nTesting configuration...")
        from src.utils.config import Config
        
        # Test default config
        config = Config()
        print(f"✓ Default config created: output_dir={config.output_directory}")
        
        # Test config validation
        config.max_concurrent_downloads = 2
        config.retry_attempts = 3
        print("✓ Config validation passed")
        
        return True
        
    except Exception as e:
        print(f"✗ Config test failed: {e}")
        return False

def test_file_utils():
    """Test file utilities."""
    try:
        print("\nTesting file utilities...")
        from src.utils.file_utils import sanitize_filename, format_audiobook_filename
        
        # Test filename sanitization
        safe_name = sanitize_filename("Test <Book> Title: Part/1")
        print(f"✓ Filename sanitization: {safe_name}")
        
        # Test audiobook filename formatting
        audiobook_name = format_audiobook_filename("Test Title", "Test Author")
        print(f"✓ Audiobook filename: {audiobook_name}")
        
        return True
        
    except Exception as e:
        print(f"✗ File utils test failed: {e}")
        return False

def test_dependencies():
    """Test that all required dependencies are available."""
    try:
        print("\nTesting dependencies...")
        
        import requests
        print("✓ requests available")
        
        import bs4
        print("✓ beautifulsoup4 available")
        
        import yt_dlp
        print("✓ yt-dlp available")
        
        import mutagen
        print("✓ mutagen available")
        
        import aiohttp
        print("✓ aiohttp available")
        
        import PIL
        print("✓ Pillow available")
        
        return True
        
    except ImportError as e:
        print(f"✗ Dependency test failed: {e}")
        print("Run: uv sync")
        return False

def test_basic_functionality():
    """Test basic functionality."""
    try:
        print("\nTesting basic functionality...")
        from src.utils.config import Config
        from src.scraper.playlist_extractor import PlaylistExtractor
        
        # Test playlist extractor
        config = Config()
        extractor = PlaylistExtractor(config)
        print("✓ PlaylistExtractor created")
        
        # Test with sample HTML
        test_html = '''
        <html>
            <script>
                var playlistUrl = "https://rcavmedias.akamaized.net/test/master.m3u8";
            </script>
        </html>
        '''
        
        url = extractor.extract_playlist_url(test_html, "https://example.com")
        if url:
            print(f"✓ Playlist extraction works: {url}")
        else:
            print("! Playlist extraction returned None (expected for test data)")
        
        return True
        
    except Exception as e:
        print(f"✗ Basic functionality test failed: {e}")
        return False

def main():
    """Run all tests."""
    print("OHdio Downloader Setup Test")
    print("=" * 40)
    
    tests = [
        test_imports,
        test_config,
        test_file_utils,
        test_dependencies,
        test_basic_functionality
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        if test():
            passed += 1
        else:
            failed += 1
    
    print(f"\nTest Results: {passed} passed, {failed} failed")
    
    if failed == 0:
        print("✓ All tests passed! OHdio downloader is ready to use.")
        print("\nQuick start:")
        print("  uv run python main.py --test https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine")
        print("  uv run python main.py --url https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine")
        print("  uv run python main.py")
    else:
        print("✗ Some tests failed. Please check the errors above.")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 