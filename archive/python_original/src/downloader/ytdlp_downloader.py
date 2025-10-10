"""yt-dlp based downloader for audiobook playlists."""

import asyncio
import logging
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Optional, Dict, Any, Callable

import yt_dlp

from ..utils.file_utils import sanitize_filename, get_safe_path, ensure_directory_exists


class YtDlpDownloader:
    """Downloads audiobook playlists using yt-dlp."""
    
    def __init__(self, config):
        """Initialize the downloader.
        
        Args:
            config: Configuration object
        """
        self.config = config
        self.logger = logging.getLogger(__name__)
    
    async def download_audiobook(
        self,
        playlist_url: str,
        title: str,
        author: str,
        output_directory: Optional[str] = None,
        progress_callback: Optional[Callable] = None
    ) -> Optional[str]:
        """Download an audiobook from its playlist URL.
        
        Args:
            playlist_url: M3U8 playlist URL
            title: Book title for filename
            author: Book author for filename
            output_directory: Custom output directory (optional)
            progress_callback: Callback for progress updates
            
        Returns:
            Path to downloaded file or None if failed
        """
        if not playlist_url:
            self.logger.error("No playlist URL provided")
            return None
        
        # Prepare output path
        output_dir = output_directory or self.config.output_directory
        ensure_directory_exists(output_dir)
        
        # Generate filename
        filename = self._generate_filename(title, author)
        output_path = get_safe_path(output_dir, filename)
        
        # Check if file already exists and skip if configured
        if self.config.skip_existing and output_path.exists():
            self.logger.info(f"File already exists, skipping: {output_path}")
            return str(output_path)
        
        self.logger.info(f"Downloading '{title}' by {author} to {output_path}")
        
        try:
            # Download using yt-dlp
            success = await self._download_with_ytdlp(
                playlist_url, 
                output_path, 
                progress_callback
            )
            
            if success and output_path.exists():
                self.logger.info(f"Successfully downloaded: {output_path}")
                return str(output_path)
            else:
                self.logger.error(f"Download failed for {playlist_url}")
                return None
                
        except Exception as e:
            self.logger.error(f"Error downloading {playlist_url}: {e}")
            return None
    
    async def _download_with_ytdlp(
        self,
        url: str,
        output_path: Path,
        progress_callback: Optional[Callable] = None
    ) -> bool:
        """Download using yt-dlp library.
        
        Args:
            url: URL to download
            output_path: Path where to save the file
            progress_callback: Progress callback function
            
        Returns:
            True if successful, False otherwise
        """
        # Prepare yt-dlp options
        ydl_opts = self._get_ytdlp_options(output_path, progress_callback)
        
        try:
            # Run yt-dlp in executor to avoid blocking
            loop = asyncio.get_event_loop()
            success = await loop.run_in_executor(
                None, 
                self._run_ytdlp, 
                url, 
                ydl_opts
            )
            return success
            
        except Exception as e:
            self.logger.error(f"yt-dlp execution failed: {e}")
            return False
    
    def _run_ytdlp(self, url: str, ydl_opts: Dict[str, Any]) -> bool:
        """Run yt-dlp with given options.
        
        Args:
            url: URL to download
            ydl_opts: yt-dlp options
            
        Returns:
            True if successful, False otherwise
        """
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([url])
            return True
        except Exception as e:
            self.logger.error(f"yt-dlp download error: {e}")
            return False
    
    def _get_ytdlp_options(
        self, 
        output_path: Path, 
        progress_callback: Optional[Callable] = None
    ) -> Dict[str, Any]:
        """Get yt-dlp configuration options.
        
        Args:
            output_path: Output file path
            progress_callback: Progress callback function
            
        Returns:
            Dictionary of yt-dlp options
        """
        # Base filename without extension
        output_template = str(output_path.parent / output_path.stem)
        
        ydl_opts = {
            'outtmpl': output_template + '.%(ext)s',
            'format': self._get_format_selector(),
            'writesubtitles': False,
            'writeautomaticsub': False,
            'writeinfojson': False,
            'writedescription': False,
            'writethumbnail': False,
            'writecomments': False,
            'writeannotations': False,
            'ignoreerrors': False,
            'no_warnings': False,
            'extractflat': False,
            'concurrent_fragment_downloads': self.config.max_concurrent_downloads,
            'retries': self.config.retry_attempts,
            'fragment_retries': self.config.retry_attempts,
            'http_headers': self.config.get_headers(),
        }
        
        # Add progress hook if callback provided
        if progress_callback:
            ydl_opts['progress_hooks'] = [
                lambda d: self._progress_hook(d, progress_callback)
            ]
        
        # Post-processing to convert to MP3
        ydl_opts['postprocessors'] = [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': self._get_audio_quality(),
        }]
        
        return ydl_opts
    
    def _get_format_selector(self) -> str:
        """Get the format selector for yt-dlp.
        
        Returns:
            Format selector string
        """
        if self.config.audio_quality == "best":
            return "bestaudio/best"
        elif self.config.audio_quality == "worst":
            return "worstaudio/worst"
        else:
            # Try to parse as specific quality
            try:
                quality = int(self.config.audio_quality)
                return f"bestaudio[abr<={quality}]/bestaudio/best"
            except ValueError:
                return "bestaudio/best"
    
    def _get_audio_quality(self) -> str:
        """Get audio quality for post-processing.
        
        Returns:
            Audio quality string for FFmpeg
        """
        quality_map = {
            "best": "0",      # VBR best quality
            "high": "2",      # VBR high quality  
            "medium": "4",    # VBR medium quality
            "low": "7",       # VBR low quality
            "worst": "9",     # VBR worst quality
        }
        
        if self.config.audio_quality in quality_map:
            return quality_map[self.config.audio_quality]
        
        # Try to parse as bitrate
        try:
            bitrate = int(self.config.audio_quality)
            return str(bitrate)
        except ValueError:
            return "0"  # Default to best quality
    
    def _progress_hook(self, d: Dict[str, Any], callback: Callable) -> None:
        """Progress hook for yt-dlp.
        
        Args:
            d: Progress data from yt-dlp
            callback: Progress callback function
        """
        try:
            if d['status'] == 'downloading':
                # Extract progress information
                total_bytes = d.get('total_bytes') or d.get('total_bytes_estimate')
                downloaded_bytes = d.get('downloaded_bytes', 0)
                speed = d.get('speed', 0)
                eta = d.get('eta', 0)
                
                if total_bytes and downloaded_bytes:
                    progress_percent = (downloaded_bytes / total_bytes) * 100
                    
                    # Format speed
                    if speed:
                        if speed > 1024 * 1024:
                            speed_str = f"{speed / (1024 * 1024):.1f} MB/s"
                        elif speed > 1024:
                            speed_str = f"{speed / 1024:.1f} KB/s"
                        else:
                            speed_str = f"{speed:.0f} B/s"
                    else:
                        speed_str = "unknown"
                    
                    # Call the callback
                    callback(progress_percent, speed_str, eta)
            elif d['status'] == 'finished':
                callback(100.0, "completed", 0)
        except Exception as e:
            self.logger.debug(f"Progress hook error: {e}")
    
    def _generate_filename(self, title: str, author: str) -> str:
        """Generate a safe filename for the audiobook.
        
        Args:
            title: Book title
            author: Book author
            
        Returns:
            Safe filename with .mp3 extension
        """
        from ..utils.file_utils import format_audiobook_filename
        return format_audiobook_filename(title, author, "mp3")
    
    async def check_url_accessibility(self, url: str) -> bool:
        """Check if a URL is accessible by yt-dlp.
        
        Args:
            url: URL to check
            
        Returns:
            True if URL is accessible, False otherwise
        """
        try:
            # Create minimal yt-dlp options for testing
            ydl_opts = {
                'quiet': True,
                'no_warnings': True,
                'extract_flat': True,
                'http_headers': self.config.get_headers(),
            }
            
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                None,
                self._test_url_extraction,
                url,
                ydl_opts
            )
            return result
            
        except Exception as e:
            self.logger.debug(f"URL accessibility check failed for {url}: {e}")
            return False
    
    def _test_url_extraction(self, url: str, ydl_opts: Dict[str, Any]) -> bool:
        """Test URL extraction with yt-dlp.
        
        Args:
            url: URL to test
            ydl_opts: yt-dlp options
            
        Returns:
            True if extraction successful, False otherwise
        """
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                return info is not None
        except Exception:
            return False
    
    def get_media_info(self, url: str) -> Optional[Dict[str, Any]]:
        """Get media information from URL without downloading.
        
        Args:
            url: URL to analyze
            
        Returns:
            Dictionary with media info or None if failed
        """
        try:
            ydl_opts = {
                'quiet': True,
                'no_warnings': True,
                'http_headers': self.config.get_headers(),
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                
                if info:
                    return {
                        'title': info.get('title'),
                        'duration': info.get('duration'),
                        'uploader': info.get('uploader'),
                        'upload_date': info.get('upload_date'),
                        'formats': len(info.get('formats', [])),
                        'filesize': info.get('filesize'),
                        'format_id': info.get('format_id'),
                    }
        except Exception as e:
            self.logger.debug(f"Failed to get media info for {url}: {e}")
        
        return None


class DownloadProgress:
    """Progress tracker for downloads."""
    
    def __init__(self, title: str, author: str):
        """Initialize progress tracker.
        
        Args:
            title: Book title
            author: Book author
        """
        self.title = title
        self.author = author
        self.logger = logging.getLogger(__name__)
        self.last_progress = -1
    
    def update(self, progress: float, speed: str, eta: int) -> None:
        """Update progress.
        
        Args:
            progress: Progress percentage (0-100)
            speed: Download speed string
            eta: Estimated time remaining in seconds
        """
        # Only log every 5% to avoid spam
        if int(progress) % 5 == 0 and int(progress) != self.last_progress:
            eta_str = f"{eta//60}:{eta%60:02d}" if eta > 0 else "unknown"
            self.logger.info(
                f"Downloading '{self.title}': {progress:.1f}% "
                f"at {speed} (ETA: {eta_str})"
            )
            self.last_progress = int(progress) 