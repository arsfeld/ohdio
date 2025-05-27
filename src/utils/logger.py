"""Logging setup and utilities for the OHdio audiobook downloader."""

import json
import logging
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict


class JSONFormatter(logging.Formatter):
    """Custom formatter that outputs logs in JSON format."""
    
    def format(self, record: logging.LogRecord) -> str:
        """Format log record as JSON.
        
        Args:
            record: The log record to format
            
        Returns:
            JSON-formatted log string
        """
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }
        
        # Add extra fields if they exist
        if hasattr(record, 'url'):
            log_entry['url'] = record.url
        if hasattr(record, 'duration'):
            log_entry['duration'] = record.duration
        if hasattr(record, 'status_code'):
            log_entry['status_code'] = record.status_code
        
        return json.dumps(log_entry, ensure_ascii=False)


class ColoredConsoleFormatter(logging.Formatter):
    """Custom formatter with colored output for console."""
    
    # Color codes
    COLORS = {
        'DEBUG': '\033[36m',    # Cyan
        'INFO': '\033[32m',     # Green
        'WARNING': '\033[33m',  # Yellow
        'ERROR': '\033[31m',    # Red
        'CRITICAL': '\033[35m', # Magenta
    }
    RESET = '\033[0m'
    
    def format(self, record: logging.LogRecord) -> str:
        """Format log record with colors for console output.
        
        Args:
            record: The log record to format
            
        Returns:
            Colored log string
        """
        # Get color for log level
        color = self.COLORS.get(record.levelname, '')
        
        # Format timestamp
        timestamp = datetime.fromtimestamp(record.created).strftime('%H:%M:%S')
        
        # Format the message
        formatted = (
            f"{color}[{timestamp}] {record.levelname:8s}{self.RESET} "
            f"{record.module}:{record.funcName}:{record.lineno} - "
            f"{record.getMessage()}"
        )
        
        return formatted


def setup_logging(
    log_level: str = "INFO",
    log_file: str = "logs/scraper.log",
    console_output: bool = True,
    json_format: bool = False
) -> None:
    """Setup structured logging for the application.
    
    Args:
        log_level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_file: Path to log file
        console_output: Whether to output to console
        json_format: Whether to use JSON format for console output
    """
    # Create logs directory if it doesn't exist
    log_path = Path(log_file)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Remove existing handlers
    logger = logging.getLogger()
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)
    
    # Set log level
    logger.setLevel(getattr(logging, log_level.upper()))
    
    # File handler with JSON format
    file_handler = logging.FileHandler(log_file, encoding='utf-8')
    file_handler.setFormatter(JSONFormatter())
    logger.addHandler(file_handler)
    
    # Console handler
    if console_output:
        console_handler = logging.StreamHandler(sys.stdout)
        if json_format:
            console_handler.setFormatter(JSONFormatter())
        else:
            console_handler.setFormatter(ColoredConsoleFormatter())
        logger.addHandler(console_handler)
    
    # Reduce noise from external libraries
    logging.getLogger('urllib3').setLevel(logging.WARNING)
    logging.getLogger('requests').setLevel(logging.WARNING)
    logging.getLogger('aiohttp').setLevel(logging.WARNING)
    
    logging.info(f"Logging initialized with level {log_level}")


def log_request(url: str, status_code: int, duration: float) -> None:
    """Log HTTP request details.
    
    Args:
        url: The requested URL
        status_code: HTTP status code
        duration: Request duration in seconds
    """
    logger = logging.getLogger(__name__)
    extra = {
        'url': url,
        'status_code': status_code,
        'duration': duration
    }
    
    if status_code < 400:
        logger.info(f"HTTP {status_code} - {url} ({duration:.2f}s)", extra=extra)
    else:
        logger.warning(f"HTTP {status_code} - {url} ({duration:.2f}s)", extra=extra)


def log_download_progress(title: str, progress: float, speed: str = "") -> None:
    """Log download progress.
    
    Args:
        title: Title of the item being downloaded
        progress: Progress percentage (0-100)
        speed: Download speed string
    """
    logger = logging.getLogger(__name__)
    speed_info = f" at {speed}" if speed else ""
    logger.info(f"Downloading '{title}': {progress:.1f}%{speed_info}")


def log_error_with_context(error: Exception, context: Dict[str, Any]) -> None:
    """Log error with additional context.
    
    Args:
        error: The exception that occurred
        context: Additional context information
    """
    logger = logging.getLogger(__name__)
    context_str = ", ".join(f"{k}={v}" for k, v in context.items())
    logger.error(f"{type(error).__name__}: {error} (Context: {context_str})")


class LoggingContext:
    """Context manager for adding extra information to logs."""
    
    def __init__(self, **kwargs: Any):
        """Initialize with extra fields to add to log records.
        
        Args:
            **kwargs: Extra fields to add to log records
        """
        self.extra = kwargs
        self.old_factory = None
    
    def __enter__(self) -> 'LoggingContext':
        """Enter the context and modify log record factory."""
        self.old_factory = logging.getLogRecordFactory()
        
        def record_factory(*args, **kwargs):
            record = self.old_factory(*args, **kwargs)
            for key, value in self.extra.items():
                setattr(record, key, value)
            return record
        
        logging.setLogRecordFactory(record_factory)
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        """Exit the context and restore original log record factory."""
        if self.old_factory:
            logging.setLogRecordFactory(self.old_factory) 