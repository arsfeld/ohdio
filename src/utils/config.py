"""Configuration management for the OHdio audiobook downloader."""

import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass
class Config:
    """Configuration settings for the audiobook downloader."""
    
    output_directory: str = "downloads"
    max_concurrent_downloads: int = 3
    retry_attempts: int = 3
    delay_between_requests: float = 1.0
    audio_quality: str = "best"
    embed_metadata: bool = True
    skip_existing: bool = True
    user_agent: str = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    
    def __post_init__(self) -> None:
        """Validate configuration after initialization."""
        if self.max_concurrent_downloads < 1:
            raise ValueError("max_concurrent_downloads must be at least 1")
        if self.retry_attempts < 0:
            raise ValueError("retry_attempts must be non-negative")
        if self.delay_between_requests < 0:
            raise ValueError("delay_between_requests must be non-negative")

        # Ensure output directory exists
        try:
            Path(self.output_directory).mkdir(parents=True, exist_ok=True)
        except PermissionError:
            # If we can't create the directory (e.g., /data in HF Spaces),
            # try using a relative path in the current directory
            logging.warning(f"Cannot create directory {self.output_directory}, using relative path")
            self.output_directory = "downloads"
            Path(self.output_directory).mkdir(parents=True, exist_ok=True)
    
    @classmethod
    def from_file(cls, config_file: str) -> 'Config':
        """Load configuration from JSON file.
        
        Args:
            config_file: Path to the JSON configuration file
            
        Returns:
            Config instance with loaded settings
            
        Raises:
            FileNotFoundError: If config file doesn't exist
            json.JSONDecodeError: If config file is invalid JSON
        """
        config_path = Path(config_file)
        if not config_path.exists():
            logging.warning(f"Config file {config_file} not found, using defaults")
            return cls()
        
        try:
            with open(config_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            return cls(**data)
        except json.JSONDecodeError as e:
            logging.error(f"Invalid JSON in config file {config_file}: {e}")
            raise
    
    def save_to_file(self, config_file: str) -> None:
        """Save current configuration to JSON file.
        
        Args:
            config_file: Path where to save the configuration
        """
        config_path = Path(config_file)
        config_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Convert dataclass to dict, excluding non-serializable fields
        data = {
            'output_directory': self.output_directory,
            'max_concurrent_downloads': self.max_concurrent_downloads,
            'retry_attempts': self.retry_attempts,
            'delay_between_requests': self.delay_between_requests,
            'audio_quality': self.audio_quality,
            'embed_metadata': self.embed_metadata,
            'skip_existing': self.skip_existing,
            'user_agent': self.user_agent,
        }
        
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        
        logging.info(f"Configuration saved to {config_file}")
    
    def get_headers(self) -> dict[str, str]:
        """Get HTTP headers for requests.
        
        Returns:
            Dictionary of HTTP headers
        """
        return {
            'User-Agent': self.user_agent,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'fr-CA,fr;q=0.9,en;q=0.8',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        } 