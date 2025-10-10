"""Main application entry point for the OHdio audiobook downloader."""

import asyncio
import logging
import sys
from pathlib import Path
from typing import List, Optional

from .utils.config import Config
from .utils.logger import setup_logging, LoggingContext
from .scraper.category_scraper import CategoryScraper, AudiobookInfo
from .scraper.audiobook_scraper import AudiobookScraper, AudiobookMetadata
from .downloader.ytdlp_downloader import YtDlpDownloader, DownloadProgress
from .downloader.metadata_manager import MetadataManager


class OHdioDownloader:
    """Main application class for downloading OHdio audiobooks."""
    
    def __init__(self, config_file: str = "config.json"):
        """Initialize the downloader.
        
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
        
        # Statistics
        self.stats = {
            'discovered': 0,
            'processed': 0,
            'downloaded': 0,
            'failed': 0,
            'skipped': 0
        }
    
    async def download_all_audiobooks(self, category_url: Optional[str] = None) -> None:
        """Download all audiobooks from the category page.
        
        Args:
            category_url: Custom category URL (optional)
        """
        self.logger.info("Starting OHdio audiobook download process")
        
        try:
            # Step 1: Discover audiobooks
            audiobooks = await self._discover_audiobooks(category_url)
            if not audiobooks:
                self.logger.error("No audiobooks discovered")
                return
            
            # Step 2: Process each audiobook
            await self._process_audiobooks(audiobooks)
            
            # Step 3: Print summary
            self._print_summary()
            
        except Exception as e:
            self.logger.error(f"Download process failed: {e}")
            raise
    
    async def download_single_audiobook(self, book_url: str) -> bool:
        """Download a single audiobook from its URL.
        
        Args:
            book_url: URL of the audiobook page
            
        Returns:
            True if successful, False otherwise
        """
        self.logger.info(f"Downloading single audiobook: {book_url}")
        
        try:
            # Create AudiobookInfo from URL
            audiobook_info = AudiobookInfo(
                title="Unknown",
                author="Unknown",
                url=book_url
            )
            
            success = await self._process_single_audiobook(audiobook_info)
            
            if success:
                self.logger.info("Single audiobook download completed successfully")
            else:
                self.logger.error("Single audiobook download failed")
            
            return success
            
        except Exception as e:
            self.logger.error(f"Single audiobook download failed: {e}")
            return False
    
    async def _discover_audiobooks(self, category_url: Optional[str] = None) -> List[AudiobookInfo]:
        """Discover audiobooks from the category page.
        
        Args:
            category_url: Custom category URL
            
        Returns:
            List of discovered audiobooks
        """
        self.logger.info("Discovering audiobooks...")
        
        with LoggingContext(phase="discovery"):
            audiobooks = await self.category_scraper.scrape_category(category_url)
            self.stats['discovered'] = len(audiobooks)
            
            self.logger.info(f"Discovered {len(audiobooks)} audiobooks")
            
            # Log sample of discovered books
            for i, book in enumerate(audiobooks[:5]):
                self.logger.info(f"  {i+1}. '{book.title}' by {book.author}")
            
            if len(audiobooks) > 5:
                self.logger.info(f"  ... and {len(audiobooks) - 5} more")
            
            return audiobooks
    
    async def _process_audiobooks(self, audiobooks: List[AudiobookInfo]) -> None:
        """Process all discovered audiobooks.
        
        Args:
            audiobooks: List of audiobooks to process
        """
        self.logger.info(f"Processing {len(audiobooks)} audiobooks...")
        
        # Create semaphore to limit concurrent downloads
        semaphore = asyncio.Semaphore(self.config.max_concurrent_downloads)
        
        # Create tasks for concurrent processing
        tasks = []
        for audiobook in audiobooks:
            task = asyncio.create_task(
                self._process_with_semaphore(semaphore, audiobook)
            )
            tasks.append(task)
        
        # Wait for all tasks to complete
        await asyncio.gather(*tasks, return_exceptions=True)
    
    async def _process_with_semaphore(
        self, 
        semaphore: asyncio.Semaphore, 
        audiobook: AudiobookInfo
    ) -> None:
        """Process a single audiobook with semaphore control.
        
        Args:
            semaphore: Asyncio semaphore for concurrency control
            audiobook: Audiobook to process
        """
        async with semaphore:
            await self._process_single_audiobook(audiobook)
            
            # Add delay between requests
            if self.config.delay_between_requests > 0:
                await asyncio.sleep(self.config.delay_between_requests)
    
    async def _process_single_audiobook(self, audiobook: AudiobookInfo) -> bool:
        """Process a single audiobook through the complete pipeline.
        
        Args:
            audiobook: Audiobook to process
            
        Returns:
            True if successful, False otherwise
        """
        with LoggingContext(book_title=audiobook.title, book_author=audiobook.author):
            try:
                self.stats['processed'] += 1
                
                # Step 1: Extract metadata and playlist URL
                self.logger.info(f"Processing '{audiobook.title}' by {audiobook.author}")
                metadata = await self.audiobook_scraper.scrape_audiobook(audiobook.url)
                
                if not metadata:
                    self.logger.error("Failed to extract metadata")
                    self.stats['failed'] += 1
                    return False
                
                if not metadata.playlist_url:
                    self.logger.error("No playlist URL found")
                    self.stats['failed'] += 1
                    return False
                
                # Step 2: Check if file already exists
                filename = self.downloader._generate_filename(metadata.title, metadata.author)
                output_path = Path(self.config.output_directory) / filename
                
                if self.config.skip_existing and output_path.exists():
                    self.logger.info("File already exists, skipping")
                    self.stats['skipped'] += 1
                    return True
                
                # Step 3: Download the audiobook
                progress_tracker = DownloadProgress(metadata.title, metadata.author)
                downloaded_file = await self.downloader.download_audiobook(
                    metadata.playlist_url,
                    metadata.title,
                    metadata.author,
                    progress_callback=progress_tracker.update
                )
                
                if not downloaded_file:
                    self.logger.error("Download failed")
                    self.stats['failed'] += 1
                    return False
                
                # Step 4: Embed metadata
                if self.config.embed_metadata:
                    success = self.metadata_manager.embed_metadata(downloaded_file, metadata)
                    if success:
                        self.logger.info("Metadata embedded successfully")
                    else:
                        self.logger.warning("Failed to embed metadata")
                
                self.stats['downloaded'] += 1
                self.logger.info(f"Successfully completed '{metadata.title}'")
                return True
                
            except Exception as e:
                self.logger.error(f"Error processing audiobook: {e}")
                self.stats['failed'] += 1
                return False
    
    def _print_summary(self) -> None:
        """Print download summary statistics."""
        self.logger.info("=== DOWNLOAD SUMMARY ===")
        self.logger.info(f"Discovered: {self.stats['discovered']}")
        self.logger.info(f"Processed: {self.stats['processed']}")
        self.logger.info(f"Downloaded: {self.stats['downloaded']}")
        self.logger.info(f"Skipped: {self.stats['skipped']}")
        self.logger.info(f"Failed: {self.stats['failed']}")
        
        success_rate = (self.stats['downloaded'] / self.stats['processed'] * 100) if self.stats['processed'] > 0 else 0
        self.logger.info(f"Success rate: {success_rate:.1f}%")
    

async def main():
    """Main application entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description="OHdio Audiobook Downloader")
    parser.add_argument("--config", default="config.json", help="Configuration file path")
    parser.add_argument("--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"])
    parser.add_argument("--url", help="Download single audiobook from URL")
    parser.add_argument("--category", help="Custom category URL to scrape")
    
    args = parser.parse_args()

    # Setup logging with correct path for Docker/local
    log_path = "/data/logs/scraper.log" if Path("/data/logs").exists() else "logs/scraper.log"
    setup_logging(
        log_level=args.log_level,
        log_file=log_path,
        console_output=True,
        json_format=False
    )
    
    try:
        # Initialize downloader
        downloader = OHdioDownloader(args.config)
        
        if args.url:
            # Single URL download
            success = await downloader.download_single_audiobook(args.url)
            sys.exit(0 if success else 1)
        else:
            # Download all audiobooks
            await downloader.download_all_audiobooks(args.category)
            
    except KeyboardInterrupt:
        print("\nDownload interrupted by user")
        sys.exit(1)
    except Exception as e:
        logging.error(f"Application error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main()) 