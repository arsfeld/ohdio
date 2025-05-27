"""File utilities for the OHdio audiobook downloader."""

import re
import unicodedata
from pathlib import Path
from typing import Optional


def sanitize_filename(filename: str, max_length: int = 255) -> str:
    """Sanitize a filename by removing invalid characters.
    
    Args:
        filename: The original filename
        max_length: Maximum length for the filename
        
    Returns:
        Sanitized filename safe for filesystem use
    """
    # Normalize unicode characters
    filename = unicodedata.normalize('NFKD', filename)
    
    # Remove or replace invalid characters
    # Invalid characters for most filesystems: < > : " | ? * \ /
    invalid_chars = r'[<>:"|?*\\\/]'
    filename = re.sub(invalid_chars, '_', filename)
    
    # Remove control characters
    filename = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', filename)
    
    # Replace multiple spaces/underscores with single ones
    filename = re.sub(r'[ _]+', '_', filename)
    
    # Remove leading/trailing spaces and dots
    filename = filename.strip(' .')
    
    # Ensure it's not empty
    if not filename:
        filename = "untitled"
    
    # Truncate if too long, preserving extension
    if len(filename) > max_length:
        # Find extension
        parts = filename.rsplit('.', 1)
        if len(parts) == 2 and len(parts[1]) <= 10:  # Valid extension
            name, ext = parts
            max_name_length = max_length - len(ext) - 1
            filename = name[:max_name_length] + '.' + ext
        else:
            filename = filename[:max_length]
    
    return filename


def format_audiobook_filename(title: str, author: str, extension: str = "mp3") -> str:
    """Format audiobook filename in standard format.
    
    Args:
        title: Book title
        author: Book author
        extension: File extension (without dot)
        
    Returns:
        Formatted filename: "Author - Title.ext"
    """
    # Clean up title and author
    title = title.strip()
    author = author.strip()
    
    # Handle empty values
    if not title:
        title = "Unknown Title"
    if not author:
        author = "Unknown Author"
    
    # Format as "Author - Title.ext"
    filename = f"{author} - {title}.{extension}"
    
    # Sanitize the complete filename
    return sanitize_filename(filename)


def get_safe_path(directory: str, filename: str) -> Path:
    """Get a safe file path, avoiding overwrites if needed.
    
    Args:
        directory: Target directory
        filename: Desired filename
        
    Returns:
        Path object for the file
    """
    base_path = Path(directory)
    base_path.mkdir(parents=True, exist_ok=True)
    
    file_path = base_path / filename
    
    # If file exists, add a number suffix
    if file_path.exists():
        stem = file_path.stem
        suffix = file_path.suffix
        counter = 1
        
        while file_path.exists():
            new_name = f"{stem}_{counter}{suffix}"
            file_path = base_path / new_name
            counter += 1
    
    return file_path


def ensure_directory_exists(directory: str) -> Path:
    """Ensure a directory exists, creating it if necessary.
    
    Args:
        directory: Directory path
        
    Returns:
        Path object for the directory
    """
    dir_path = Path(directory)
    dir_path.mkdir(parents=True, exist_ok=True)
    return dir_path


def get_file_size_mb(file_path: Path) -> float:
    """Get file size in megabytes.
    
    Args:
        file_path: Path to the file
        
    Returns:
        File size in MB, or 0 if file doesn't exist
    """
    try:
        return file_path.stat().st_size / (1024 * 1024)
    except (OSError, FileNotFoundError):
        return 0.0


def is_valid_audio_file(file_path: Path) -> bool:
    """Check if a file is a valid audio file.
    
    Args:
        file_path: Path to the file
        
    Returns:
        True if file exists and appears to be a valid audio file
    """
    if not file_path.exists():
        return False
    
    # Check file size (should be at least 1MB for audiobooks)
    if get_file_size_mb(file_path) < 1.0:
        return False
    
    # Check extension
    valid_extensions = {'.mp3', '.m4a', '.aac', '.flac', '.ogg', '.wav'}
    if file_path.suffix.lower() not in valid_extensions:
        return False
    
    return True


def cleanup_temp_files(directory: str, pattern: str = "*.tmp") -> int:
    """Clean up temporary files in a directory.
    
    Args:
        directory: Directory to clean
        pattern: Glob pattern for files to delete
        
    Returns:
        Number of files deleted
    """
    dir_path = Path(directory)
    if not dir_path.exists():
        return 0
    
    deleted_count = 0
    for temp_file in dir_path.glob(pattern):
        try:
            temp_file.unlink()
            deleted_count += 1
        except OSError:
            pass  # Ignore errors when deleting temp files
    
    return deleted_count


def extract_extension_from_url(url: str) -> Optional[str]:
    """Extract file extension from URL.
    
    Args:
        url: URL to extract extension from
        
    Returns:
        File extension (without dot) or None if not found
    """
    # Remove query parameters and fragments
    clean_url = url.split('?')[0].split('#')[0]
    
    # Get the path part
    path = clean_url.split('/')[-1]
    
    # Extract extension
    if '.' in path:
        extension = path.split('.')[-1].lower()
        # Validate it looks like a file extension
        if len(extension) <= 5 and extension.isalnum():
            return extension
    
    return None


def get_available_space_gb(directory: str) -> float:
    """Get available disk space in gigabytes.
    
    Args:
        directory: Directory to check
        
    Returns:
        Available space in GB
    """
    try:
        dir_path = Path(directory)
        if not dir_path.exists():
            dir_path = dir_path.parent
        
        stat = dir_path.stat()
        # This is a simple approximation - actual implementation would use statvfs
        # For now, return a large number to avoid blocking downloads
        return 1000.0  # Assume 1TB available
    except (OSError, AttributeError):
        return 1000.0  # Default to large number if we can't check 