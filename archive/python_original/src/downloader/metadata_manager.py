"""Metadata manager for embedding metadata and artwork into audio files."""

import logging
from pathlib import Path
from typing import Optional

from mutagen.id3 import ID3, APIC, TIT2, TPE1, TALB, TDRC, TCON, TPE3, TPOS, TRCK
from mutagen.mp3 import MP3
from mutagen.id3._util import ID3NoHeaderError
from PIL import Image
import io

from ..scraper.audiobook_scraper import AudiobookMetadata


class MetadataManager:
    """Manages metadata embedding for audio files."""
    
    def __init__(self, config):
        """Initialize the metadata manager.
        
        Args:
            config: Configuration object
        """
        self.config = config
        self.logger = logging.getLogger(__name__)
    
    def embed_metadata(
        self, 
        audio_file_path: str, 
        metadata: AudiobookMetadata
    ) -> bool:
        """Embed metadata into an audio file.
        
        Args:
            audio_file_path: Path to the audio file
            metadata: AudiobookMetadata object
            
        Returns:
            True if successful, False otherwise
        """
        if not self.config.embed_metadata:
            self.logger.debug("Metadata embedding disabled in config")
            return True
        
        try:
            audio_path = Path(audio_file_path)
            if not audio_path.exists():
                self.logger.error(f"Audio file not found: {audio_file_path}")
                return False
            
            self.logger.info(f"Embedding metadata for: {audio_path.name}")
            
            # Load the MP3 file
            audio = MP3(str(audio_path))
            
            # Create ID3 tag if it doesn't exist
            try:
                audio.tags = ID3(str(audio_path))
            except ID3NoHeaderError:
                audio.add_tags()
                audio.tags = audio.tags
            
            # Clear existing tags
            audio.tags.clear()
            
            # Add basic metadata
            self._add_basic_tags(audio.tags, metadata)
            
            # Add extended metadata
            self._add_extended_tags(audio.tags, metadata)
            
            # Add artwork if available
            if metadata.thumbnail_data:
                self._add_artwork(audio.tags, metadata.thumbnail_data)
            
            # Save the changes
            audio.save()
            self.logger.info(f"Successfully embedded metadata for: {audio_path.name}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to embed metadata for {audio_file_path}: {e}")
            return False
    
    def _add_basic_tags(self, tags, metadata: AudiobookMetadata) -> None:
        """Add basic ID3 tags.
        
        Args:
            tags: ID3 tags object
            metadata: AudiobookMetadata object
        """
        # Title
        if metadata.title:
            tags.add(TIT2(encoding=3, text=[metadata.title]))
        
        # Artist (Author)
        if metadata.author:
            tags.add(TPE1(encoding=3, text=[metadata.author]))
        
        # Album (also use title for audiobooks)
        album_name = metadata.title or "Unknown Audiobook"
        tags.add(TALB(encoding=3, text=[album_name]))
        
        # Date/Year
        if metadata.publication_date:
            # Try to extract year from date
            year = self._extract_year(metadata.publication_date)
            if year:
                tags.add(TDRC(encoding=3, text=[str(year)]))
        
        # Genre
        if metadata.genre:
            tags.add(TCON(encoding=3, text=[metadata.genre]))
        else:
            tags.add(TCON(encoding=3, text=["Audiobook"]))
    
    def _add_extended_tags(self, tags, metadata: AudiobookMetadata) -> None:
        """Add extended ID3 tags.
        
        Args:
            tags: ID3 tags object
            metadata: AudiobookMetadata object
        """
        # Narrator (using TPE3 - Conductor/Performer)
        if metadata.narrator:
            tags.add(TPE3(encoding=3, text=[metadata.narrator]))
        
        # Series information
        if metadata.series:
            # Use TPOS (Part of set) for series
            if metadata.series_number:
                series_text = f"{metadata.series} #{metadata.series_number}"
            else:
                series_text = metadata.series
            tags.add(TPOS(encoding=3, text=[series_text]))
        
        # Track number (set to 1 for audiobooks)
        tags.add(TRCK(encoding=3, text=["1/1"]))
        
        # Add custom tags for additional metadata
        self._add_custom_tags(tags, metadata)
    
    def _add_custom_tags(self, tags, metadata: AudiobookMetadata) -> None:
        """Add custom tags for audiobook-specific metadata.
        
        Args:
            tags: ID3 tags object
            metadata: AudiobookMetadata object
        """
        from mutagen.id3 import TXXX, COMM
        
        # Publisher
        if metadata.publisher:
            tags.add(TXXX(encoding=3, desc="PUBLISHER", text=[metadata.publisher]))
        
        # ISBN
        if metadata.isbn:
            tags.add(TXXX(encoding=3, desc="ISBN", text=[metadata.isbn]))
        
        # Duration
        if metadata.duration:
            tags.add(TXXX(encoding=3, desc="DURATION", text=[metadata.duration]))
        
        # Source URL
        if metadata.url:
            tags.add(TXXX(encoding=3, desc="SOURCE_URL", text=[metadata.url]))
        
        # Language
        if metadata.language:
            tags.add(TXXX(encoding=3, desc="LANGUAGE", text=[metadata.language]))
        
        # Description/Summary as comment
        if metadata.description:
            # Truncate if too long
            description = metadata.description[:1000] if len(metadata.description) > 1000 else metadata.description
            tags.add(COMM(encoding=3, lang="fra", desc="Description", text=[description]))
    
    def _add_artwork(self, tags, image_data: bytes) -> None:
        """Add artwork to ID3 tags.
        
        Args:
            tags: ID3 tags object
            image_data: Raw image data
        """
        try:
            # Process the image
            processed_image = self._process_image(image_data)
            
            if processed_image:
                # Add as cover art (front cover)
                tags.add(
                    APIC(
                        encoding=3,  # UTF-8
                        mime='image/jpeg',
                        type=3,  # Front cover
                        desc='Cover',
                        data=processed_image
                    )
                )
                self.logger.debug("Added artwork to metadata")
            
        except Exception as e:
            self.logger.warning(f"Failed to add artwork: {e}")
    
    def _process_image(self, image_data: bytes) -> Optional[bytes]:
        """Process and optimize image for embedding.
        
        Args:
            image_data: Raw image data
            
        Returns:
            Processed image data or None if failed
        """
        try:
            # Open image with PIL
            image = Image.open(io.BytesIO(image_data))
            
            # Convert to RGB if necessary
            if image.mode in ('RGBA', 'P'):
                image = image.convert('RGB')
            
            # Resize if too large (max 500x500 for audiobooks)
            max_size = (500, 500)
            if image.size[0] > max_size[0] or image.size[1] > max_size[1]:
                image.thumbnail(max_size, Image.Resampling.LANCZOS)
                self.logger.debug(f"Resized image to {image.size}")
            
            # Save as JPEG with good quality
            output = io.BytesIO()
            image.save(output, format='JPEG', quality=85, optimize=True)
            
            processed_data = output.getvalue()
            self.logger.debug(f"Processed image: {len(processed_data)} bytes")
            
            return processed_data
            
        except Exception as e:
            self.logger.warning(f"Image processing failed: {e}")
            return None
    
    def _extract_year(self, date_string: str) -> Optional[int]:
        """Extract year from a date string.
        
        Args:
            date_string: Date string in various formats
            
        Returns:
            Year as integer or None
        """
        import re
        
        # Try to find a 4-digit year
        year_match = re.search(r'\b(19|20)\d{2}\b', date_string)
        if year_match:
            try:
                return int(year_match.group())
            except ValueError:
                pass
        
        return None
    
    def verify_metadata(self, audio_file_path: str) -> dict:
        """Verify metadata in an audio file.
        
        Args:
            audio_file_path: Path to the audio file
            
        Returns:
            Dictionary with metadata information
        """
        try:
            audio = MP3(audio_file_path)
            
            if not audio.tags:
                return {"status": "no_tags"}
            
            metadata_info = {
                "status": "success",
                "title": self._get_tag_value(audio.tags, TIT2),
                "artist": self._get_tag_value(audio.tags, TPE1),
                "album": self._get_tag_value(audio.tags, TALB),
                "date": self._get_tag_value(audio.tags, TDRC),
                "genre": self._get_tag_value(audio.tags, TCON),
                "narrator": self._get_tag_value(audio.tags, TPE3),
                "has_artwork": any(isinstance(tag, APIC) for tag in audio.tags.values()),
                "duration": audio.info.length if audio.info else None,
                "bitrate": audio.info.bitrate if audio.info else None,
            }
            
            return metadata_info
            
        except Exception as e:
            self.logger.error(f"Failed to verify metadata for {audio_file_path}: {e}")
            return {"status": "error", "error": str(e)}
    
    def _get_tag_value(self, tags, tag_class):
        """Get value from ID3 tag.
        
        Args:
            tags: ID3 tags object
            tag_class: Tag class to look for
            
        Returns:
            Tag value or None
        """
        try:
            for tag in tags.values():
                if isinstance(tag, tag_class):
                    return str(tag.text[0]) if tag.text else None
        except (IndexError, AttributeError):
            pass
        return None
    
    def remove_metadata(self, audio_file_path: str) -> bool:
        """Remove all metadata from an audio file.
        
        Args:
            audio_file_path: Path to the audio file
            
        Returns:
            True if successful, False otherwise
        """
        try:
            audio = MP3(audio_file_path)
            if audio.tags:
                audio.tags.clear()
                audio.save()
                self.logger.info(f"Removed metadata from: {audio_file_path}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to remove metadata from {audio_file_path}: {e}")
            return False
    
    def copy_metadata(self, source_file: str, target_file: str) -> bool:
        """Copy metadata from one audio file to another.
        
        Args:
            source_file: Source audio file path
            target_file: Target audio file path
            
        Returns:
            True if successful, False otherwise
        """
        try:
            source = MP3(source_file)
            target = MP3(target_file)
            
            if not source.tags:
                self.logger.warning(f"No metadata to copy from: {source_file}")
                return False
            
            # Copy all tags
            target.tags.clear()
            for key, value in source.tags.items():
                target.tags[key] = value
            
            target.save()
            self.logger.info(f"Copied metadata from {source_file} to {target_file}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to copy metadata: {e}")
            return False 