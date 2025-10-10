#!/usr/bin/env python3
"""
Test script for OHdio audiobook downloader.

This script provides various testing capabilities for the OHdio audiobook downloader:
- Test single URL extraction
- Test category discovery
- Test skip existing logic
- Test playlist extraction
- Test metadata extraction
"""

import asyncio
import logging
import sys
from pathlib import Path
from typing import List, Optional

from src.utils.config import Config
from src.utils.logger import setup_logging, LoggingContext
from src.scraper.category_scraper import CategoryScraper, AudiobookInfo
from src.scraper.audiobook_scraper import AudiobookScraper, AudiobookMetadata
from src.downloader.ytdlp_downloader import YtDlpDownloader, DownloadProgress
from src.downloader.metadata_manager import MetadataManager


class OHdioTester:
    """Test class for OHdio audiobook downloader functionality."""
    
    def __init__(self, config_file: str = "config.json"):
        """Initialize the tester.
        
        Args:
            config_file: Path to configuration file
        """
        self.config = Config.from_file(config_file)
        self.logger = logging.getLogger(__name__)
        
        # Initialize components
        self.category_scraper = CategoryScraper(self.config)
        self.audiobook_scraper = AudiobookScraper(self.config)
        self.downloader = YtDlpDownloader(self.config)
        self.metadata_manager = MetadataManager(self.config)
    
    async def test_single_url(self, book_url: str) -> None:
        """Test extraction and download for a single URL without downloading.
        
        Args:
            book_url: URL to test
        """
        self.logger.info(f"Testing URL: {book_url}")
        
        try:
            # Test metadata extraction
            metadata = await self.audiobook_scraper.scrape_audiobook(book_url)
            
            if metadata:
                self.logger.info(f"✓ Title: {metadata.title}")
                self.logger.info(f"✓ Author: {metadata.author}")
                self.logger.info(f"✓ Playlist URL: {metadata.playlist_url}")
                
                if metadata.playlist_url:
                    # Test URL accessibility
                    accessible = await self.downloader.check_url_accessibility(metadata.playlist_url)
                    self.logger.info(f"✓ Playlist accessible: {accessible}")
                    
                    if accessible:
                        # Get media info
                        media_info = self.downloader.get_media_info(metadata.playlist_url)
                        if media_info:
                            self.logger.info(f"✓ Media duration: {media_info.get('duration')} seconds")
                            self.logger.info(f"✓ Available formats: {media_info.get('formats')}")
                    
                self.logger.info("✅ Single URL test completed successfully")
            else:
                self.logger.error("❌ Failed to extract metadata")
                
        except Exception as e:
            self.logger.error(f"❌ Single URL test failed: {e}")

    async def test_category_discovery(self, category_url: Optional[str] = None) -> None:
        """Test category discovery without downloading.
        
        Args:
            category_url: Category URL to test
        """
        self.logger.info(f"Testing category discovery: {category_url or 'default jeunesse category'}")
        
        try:
            # Test category scraping
            audiobooks = await self.category_scraper.scrape_category(category_url)
            
            if audiobooks:
                self.logger.info(f"✓ Found {len(audiobooks)} audiobooks")
                
                # Show first 10 audiobooks
                for i, book in enumerate(audiobooks[:10]):
                    self.logger.info(f"  {i+1:2d}. '{book.title}' by {book.author}")
                    self.logger.info(f"      URL: {book.url}")
                
                if len(audiobooks) > 10:
                    self.logger.info(f"  ... and {len(audiobooks) - 10} more audiobooks")
                    
                self.logger.info("✅ Category discovery test completed successfully")
            else:
                self.logger.error("❌ No audiobooks discovered")
                
        except Exception as e:
            self.logger.error(f"❌ Category test failed: {e}")

    async def test_skip_existing(self, category_url: Optional[str] = None) -> None:
        """Test which files would be skipped vs downloaded.
        
        Args:
            category_url: Category URL to test
        """
        self.logger.info(f"Testing skip existing logic for: {category_url or 'default jeunesse category'}")
        
        try:
            # Discover audiobooks
            audiobooks = await self.category_scraper.scrape_category(category_url)
            
            if not audiobooks:
                self.logger.error("❌ No audiobooks discovered")
                return
            
            would_skip = 0
            would_download = 0
            existing_files = []
            missing_files = []
            
            self.logger.info("Checking existing files...")
            
            for book in audiobooks:
                # Check if file exists in downloads directory
                output_dir = Path(self.config.output_directory)
                
                # Look for any MP3 file that might match this book
                # Since we don't have the exact metadata, we'll check for title matches
                found_file = None
                for mp3_file in output_dir.glob("*.mp3"):
                    # Simple check if the title appears in the filename
                    if book.title.lower().replace(" ", "_").replace("'", "") in mp3_file.stem.lower():
                        found_file = mp3_file
                        break
                
                if found_file:
                    would_skip += 1
                    existing_files.append((book.title, found_file.name))
                    if len(existing_files) <= 5:  # Show first 5 existing
                        self.logger.info(f"  ✓ SKIP: '{book.title}' → {found_file.name}")
                else:
                    would_download += 1
                    missing_files.append(book.title)
                    if len(missing_files) <= 5:  # Show first 5 missing
                        self.logger.info(f"  → DOWNLOAD: '{book.title}' by {book.author}")
            
            if len(existing_files) > 5:
                self.logger.info(f"  ... and {len(existing_files) - 5} more would be skipped")
            
            if len(missing_files) > 5:
                self.logger.info(f"  ... and {len(missing_files) - 5} more would be downloaded")
            
            self.logger.info(f"\n✅ Skip Existing Summary:")
            self.logger.info(f"  Total discovered: {len(audiobooks)}")
            self.logger.info(f"  Would skip (existing): {would_skip}")
            self.logger.info(f"  Would download (missing): {would_download}")
            self.logger.info(f"  Skip rate: {(would_skip/len(audiobooks)*100):.1f}%")
            self.logger.info(f"  Download efficiency: Only {would_download} new downloads needed!")
                
        except Exception as e:
            self.logger.error(f"❌ Skip test failed: {e}")

    async def test_playlist_extraction(self, book_url: str) -> None:
        """Test playlist URL extraction from a single audiobook page.

        Args:
            book_url: URL of audiobook page to test
        """
        self.logger.info(f"Testing playlist extraction for: {book_url}")

        try:
            # First fetch the page HTML
            from src.scraper.playlist_extractor import PlaylistExtractor
            from src.utils.network_utils import safe_request

            self.logger.info("Fetching page HTML...")
            html_content = await safe_request(book_url)

            if not html_content:
                self.logger.error("❌ Failed to fetch page content")
                return

            # Extract the playlist URL
            extractor = PlaylistExtractor()
            playlist_url = extractor.extract_playlist_url(html_content, book_url)

            if playlist_url:
                self.logger.info(f"✓ Playlist URL found: {playlist_url}")

                # Test if the playlist is accessible
                accessible = await self.downloader.check_url_accessibility(playlist_url)
                self.logger.info(f"✓ Playlist accessible: {accessible}")

                if accessible:
                    # Get basic info about the media
                    media_info = self.downloader.get_media_info(playlist_url)
                    if media_info:
                        duration = media_info.get('duration', 'unknown')
                        self.logger.info(f"✓ Media duration: {duration} seconds")

                self.logger.info("✅ Playlist extraction test completed successfully")
            else:
                self.logger.error("❌ No playlist URL found")

        except Exception as e:
            self.logger.error(f"❌ Playlist extraction test failed: {e}")

    async def test_metadata_extraction(self, book_url: str) -> None:
        """Test complete metadata extraction from a single audiobook page.
        
        Args:
            book_url: URL of audiobook page to test
        """
        self.logger.info(f"Testing metadata extraction for: {book_url}")
        
        try:
            metadata = await self.audiobook_scraper.scrape_audiobook(book_url)
            
            if metadata:
                self.logger.info("✅ Metadata extraction successful:")
                self.logger.info(f"  Title: {metadata.title}")
                self.logger.info(f"  Author: {metadata.author}")
                self.logger.info(f"  Narrator: {metadata.narrator or 'Not found'}")
                self.logger.info(f"  Description: {metadata.description[:100] + '...' if metadata.description and len(metadata.description) > 100 else metadata.description or 'Not found'}")
                self.logger.info(f"  Duration: {metadata.duration or 'Not found'}")
                self.logger.info(f"  Genre: {metadata.genre or 'Not found'}")
                self.logger.info(f"  Playlist URL: {metadata.playlist_url}")
                self.logger.info(f"  Thumbnail URL: {metadata.thumbnail_url or 'Not found'}")
            else:
                self.logger.error("❌ Failed to extract metadata")
                
        except Exception as e:
            self.logger.error(f"❌ Metadata extraction test failed: {e}")

    async def test_full_pipeline_dry_run(self, book_url: str) -> None:
        """Test the complete pipeline without actually downloading.
        
        Args:
            book_url: URL of audiobook page to test
        """
        self.logger.info(f"Testing full pipeline (dry run) for: {book_url}")
        
        try:
            # Step 1: Extract metadata
            self.logger.info("Step 1: Extracting metadata...")
            metadata = await self.audiobook_scraper.scrape_audiobook(book_url)
            
            if not metadata:
                self.logger.error("❌ Metadata extraction failed")
                return
            
            self.logger.info(f"✓ Metadata extracted: '{metadata.title}' by {metadata.author}")
            
            # Step 2: Check playlist accessibility
            self.logger.info("Step 2: Checking playlist accessibility...")
            if not metadata.playlist_url:
                self.logger.error("❌ No playlist URL found")
                return
            
            accessible = await self.downloader.check_url_accessibility(metadata.playlist_url)
            if not accessible:
                self.logger.error("❌ Playlist not accessible")
                return
            
            self.logger.info("✓ Playlist is accessible")
            
            # Step 3: Check if file would be skipped
            self.logger.info("Step 3: Checking if file exists...")
            filename = self.downloader._generate_filename(metadata.title, metadata.author)
            output_path = Path(self.config.output_directory) / filename
            
            if output_path.exists():
                self.logger.info(f"✓ File already exists and would be skipped: {filename}")
            else:
                self.logger.info(f"✓ File doesn't exist, would download as: {filename}")
            
            # Step 4: Simulate download info
            self.logger.info("Step 4: Getting download info...")
            media_info = self.downloader.get_media_info(metadata.playlist_url)
            if media_info:
                duration = media_info.get('duration', 'unknown')
                formats = media_info.get('formats', 'unknown')
                self.logger.info(f"✓ Would download {duration}s audio in format: {formats}")
            
            self.logger.info("✅ Full pipeline dry run completed successfully")
            
        except Exception as e:
            self.logger.error(f"❌ Full pipeline test failed: {e}")


async def main():
    """Main test script entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description="OHdio Audiobook Downloader - Test Suite")
    parser.add_argument("--config", default="config.json", help="Configuration file path")
    parser.add_argument("--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"])
    
    # Test type arguments
    parser.add_argument("--test-url", help="Test single URL extraction")
    parser.add_argument("--test-category", help="Test category discovery")
    parser.add_argument("--test-skip", help="Test skip existing logic")
    parser.add_argument("--test-playlist", help="Test playlist extraction for URL")
    parser.add_argument("--test-metadata", help="Test metadata extraction for URL")
    parser.add_argument("--test-pipeline", help="Test full pipeline (dry run) for URL")
    
    # Default URLs for testing
    parser.add_argument("--use-defaults", action="store_true", help="Use default test URLs")
    
    args = parser.parse_args()
    
    # Setup logging
    setup_logging(
        log_level=args.log_level,
        console_output=True,
        json_format=False
    )
    
    try:
        # Initialize tester
        tester = OHdioTester(args.config)
        
        # Default test URLs
        default_audiobook_url = "https://ici.radio-canada.ca/ohdio/livres-audio/105729/augustine"
        default_category_url = "https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse"
        
        if args.use_defaults:
            print("🧪 Running all tests with default URLs...")
            await tester.test_single_url(default_audiobook_url)
            print("\n" + "="*60 + "\n")
            await tester.test_category_discovery(default_category_url)
            print("\n" + "="*60 + "\n")
            await tester.test_skip_existing(default_category_url)
            print("\n" + "="*60 + "\n")
            await tester.test_playlist_extraction(default_audiobook_url)
            print("\n" + "="*60 + "\n")
            await tester.test_metadata_extraction(default_audiobook_url)
            print("\n" + "="*60 + "\n")
            await tester.test_full_pipeline_dry_run(default_audiobook_url)
        
        elif args.test_url:
            await tester.test_single_url(args.test_url)
        elif args.test_category:
            await tester.test_category_discovery(args.test_category)
        elif args.test_skip:
            await tester.test_skip_existing(args.test_skip)
        elif args.test_playlist:
            await tester.test_playlist_extraction(args.test_playlist)
        elif args.test_metadata:
            await tester.test_metadata_extraction(args.test_metadata)
        elif args.test_pipeline:
            await tester.test_full_pipeline_dry_run(args.test_pipeline)
        else:
            parser.print_help()
            print("\n🧪 Quick start examples:")
            print(f"  python {sys.argv[0]} --use-defaults")
            print(f"  python {sys.argv[0]} --test-category {default_category_url}")
            print(f"  python {sys.argv[0]} --test-url {default_audiobook_url}")
            
    except KeyboardInterrupt:
        print("\nTests interrupted by user")
        sys.exit(1)
    except Exception as e:
        logging.error(f"Test error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main()) 