"""Network utilities for the OHdio audiobook downloader."""

import asyncio
import logging
import time
from typing import Dict, Optional, Any

import aiohttp
import requests
from aiohttp import ClientError, ClientTimeout


class NetworkError(Exception):
    """Custom exception for network-related errors."""
    pass


class RateLimitError(NetworkError):
    """Exception raised when rate limited."""
    pass


async def safe_request(
    url: str,
    method: str = "GET",
    headers: Optional[Dict[str, str]] = None,
    max_retries: int = 3,
    delay: float = 1.0,
    timeout: float = 30.0,
    **kwargs: Any
) -> Optional[str]:
    """Make HTTP request with retry logic and error handling.
    
    Args:
        url: URL to request
        method: HTTP method (GET, POST, etc.)
        headers: HTTP headers
        max_retries: Maximum number of retry attempts
        delay: Base delay between retries in seconds
        timeout: Request timeout in seconds
        **kwargs: Additional arguments passed to aiohttp
        
    Returns:
        Response text or None if all retries failed
        
    Raises:
        NetworkError: For unrecoverable network errors
        RateLimitError: When rate limited and retries exhausted
    """
    logger = logging.getLogger(__name__)
    
    if headers is None:
        headers = {}
    
    # Add default headers if not present
    default_headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'fr-CA,fr;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
    }
    
    for key, value in default_headers.items():
        if key not in headers:
            headers[key] = value
    
    timeout_config = ClientTimeout(total=timeout)
    
    for attempt in range(max_retries + 1):
        start_time = time.time()
        
        try:
            async with aiohttp.ClientSession(timeout=timeout_config) as session:
                async with session.request(method, url, headers=headers, **kwargs) as response:
                    duration = time.time() - start_time
                    
                    # Log the request
                    from .logger import log_request
                    log_request(url, response.status, duration)
                    
                    if response.status == 200:
                        content = await response.text()
                        return content
                    elif response.status == 429:  # Rate limited
                        retry_after = response.headers.get('Retry-After', str(delay * (2 ** attempt)))
                        wait_time = float(retry_after)
                        logger.warning(f"Rate limited, waiting {wait_time}s before retry")
                        
                        if attempt < max_retries:
                            await asyncio.sleep(wait_time)
                            continue
                        else:
                            raise RateLimitError(f"Rate limited and retries exhausted for {url}")
                    elif response.status >= 500:  # Server error
                        logger.warning(f"Server error {response.status} for {url}, attempt {attempt + 1}")
                        if attempt < max_retries:
                            await asyncio.sleep(delay * (2 ** attempt))
                            continue
                        else:
                            raise NetworkError(f"Server error {response.status} for {url}")
                    elif response.status == 404:
                        logger.error(f"Resource not found: {url}")
                        return None
                    elif response.status >= 400:
                        logger.error(f"Client error {response.status} for {url}")
                        return None
                    
        except ClientError as e:
            logger.warning(f"Request failed (attempt {attempt + 1}): {e}")
            if attempt < max_retries:
                await asyncio.sleep(delay * (2 ** attempt))
                continue
            else:
                raise NetworkError(f"Network error after {max_retries} retries: {e}")
        except asyncio.TimeoutError:
            logger.warning(f"Request timeout for {url} (attempt {attempt + 1})")
            if attempt < max_retries:
                await asyncio.sleep(delay * (2 ** attempt))
                continue
            else:
                raise NetworkError(f"Timeout after {max_retries} retries for {url}")
    
    return None


def sync_request(
    url: str,
    method: str = "GET",
    headers: Optional[Dict[str, str]] = None,
    max_retries: int = 3,
    delay: float = 1.0,
    timeout: float = 30.0,
    **kwargs: Any
) -> Optional[str]:
    """Synchronous version of safe_request for non-async contexts.
    
    Args:
        url: URL to request
        method: HTTP method (GET, POST, etc.)
        headers: HTTP headers
        max_retries: Maximum number of retry attempts
        delay: Base delay between retries in seconds
        timeout: Request timeout in seconds
        **kwargs: Additional arguments passed to requests
        
    Returns:
        Response text or None if all retries failed
        
    Raises:
        NetworkError: For unrecoverable network errors
        RateLimitError: When rate limited and retries exhausted
    """
    logger = logging.getLogger(__name__)
    
    if headers is None:
        headers = {}
    
    # Add default headers if not present
    default_headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'fr-CA,fr;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
    }
    
    for key, value in default_headers.items():
        if key not in headers:
            headers[key] = value
    
    session = requests.Session()
    session.headers.update(headers)
    
    for attempt in range(max_retries + 1):
        start_time = time.time()
        
        try:
            response = session.request(method, url, timeout=timeout, **kwargs)
            duration = time.time() - start_time
            
            # Log the request
            from .logger import log_request
            log_request(url, response.status_code, duration)
            
            if response.status_code == 200:
                return response.text
            elif response.status_code == 429:  # Rate limited
                retry_after = response.headers.get('Retry-After', str(delay * (2 ** attempt)))
                wait_time = float(retry_after)
                logger.warning(f"Rate limited, waiting {wait_time}s before retry")
                
                if attempt < max_retries:
                    time.sleep(wait_time)
                    continue
                else:
                    raise RateLimitError(f"Rate limited and retries exhausted for {url}")
            elif response.status_code >= 500:  # Server error
                logger.warning(f"Server error {response.status_code} for {url}, attempt {attempt + 1}")
                if attempt < max_retries:
                    time.sleep(delay * (2 ** attempt))
                    continue
                else:
                    raise NetworkError(f"Server error {response.status_code} for {url}")
            elif response.status_code == 404:
                logger.error(f"Resource not found: {url}")
                return None
            elif response.status_code >= 400:
                logger.error(f"Client error {response.status_code} for {url}")
                return None
                
        except requests.exceptions.RequestException as e:
            logger.warning(f"Request failed (attempt {attempt + 1}): {e}")
            if attempt < max_retries:
                time.sleep(delay * (2 ** attempt))
                continue
            else:
                raise NetworkError(f"Network error after {max_retries} retries: {e}")
    
    return None


async def download_file(
    url: str,
    output_path: str,
    headers: Optional[Dict[str, str]] = None,
    chunk_size: int = 8192,
    progress_callback: Optional[callable] = None
) -> bool:
    """Download a file with progress tracking.
    
    Args:
        url: URL to download
        output_path: Local path to save the file
        headers: HTTP headers
        chunk_size: Size of chunks to read
        progress_callback: Callback function for progress updates
        
    Returns:
        True if download successful, False otherwise
    """
    logger = logging.getLogger(__name__)
    
    if headers is None:
        headers = {}
    
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(url, headers=headers) as response:
                if response.status != 200:
                    logger.error(f"Failed to download {url}: HTTP {response.status}")
                    return False
                
                total_size = int(response.headers.get('Content-Length', 0))
                downloaded = 0
                
                with open(output_path, 'wb') as f:
                    async for chunk in response.content.iter_chunked(chunk_size):
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        if progress_callback and total_size > 0:
                            progress = (downloaded / total_size) * 100
                            progress_callback(progress, downloaded, total_size)
                
                logger.info(f"Downloaded {url} to {output_path} ({downloaded} bytes)")
                return True
                
    except Exception as e:
        logger.error(f"Error downloading {url}: {e}")
        return False


def is_url_accessible(url: str, timeout: float = 10.0) -> bool:
    """Check if a URL is accessible.
    
    Args:
        url: URL to check
        timeout: Request timeout in seconds
        
    Returns:
        True if URL is accessible, False otherwise
    """
    try:
        response = requests.head(url, timeout=timeout)
        return response.status_code < 400
    except requests.exceptions.RequestException:
        return False


def get_content_type(url: str, timeout: float = 10.0) -> Optional[str]:
    """Get the content type of a URL.
    
    Args:
        url: URL to check
        timeout: Request timeout in seconds
        
    Returns:
        Content type string or None if not accessible
    """
    try:
        response = requests.head(url, timeout=timeout)
        if response.status_code < 400:
            return response.headers.get('Content-Type')
    except requests.exceptions.RequestException:
        pass
    
    return None


class RequestsSession:
    """Reusable requests session with configured headers and retry logic."""
    
    def __init__(self, headers: Optional[Dict[str, str]] = None, max_retries: int = 3):
        """Initialize session with headers and retry configuration.
        
        Args:
            headers: Default headers for all requests
            max_retries: Maximum number of retry attempts
        """
        self.session = requests.Session()
        self.max_retries = max_retries
        
        if headers:
            self.session.headers.update(headers)
    
    def get(self, url: str, **kwargs: Any) -> Optional[requests.Response]:
        """Make GET request with retry logic.
        
        Args:
            url: URL to request
            **kwargs: Additional arguments passed to requests
            
        Returns:
            Response object or None if failed
        """
        return self._request('GET', url, **kwargs)
    
    def _request(self, method: str, url: str, **kwargs: Any) -> Optional[requests.Response]:
        """Internal method to make request with retry logic.
        
        Args:
            method: HTTP method
            url: URL to request
            **kwargs: Additional arguments passed to requests
            
        Returns:
            Response object or None if failed
        """
        for attempt in range(self.max_retries + 1):
            try:
                response = self.session.request(method, url, **kwargs)
                if response.status_code < 400:
                    return response
                elif response.status_code >= 500 and attempt < self.max_retries:
                    time.sleep(2 ** attempt)
                    continue
                else:
                    return response
            except requests.exceptions.RequestException as e:
                if attempt < self.max_retries:
                    time.sleep(2 ** attempt)
                    continue
                else:
                    logging.error(f"Request failed after {self.max_retries} retries: {e}")
                    return None
        
        return None
    
    def close(self) -> None:
        """Close the session."""
        self.session.close() 