"""
Playlist URL extractor for OHdio audiobooks using Radio-Canada's media validation API.

This module extracts m3u8 playlist URLs from OHdio audiobook pages by:
1. Extracting the mediaId from the page HTML
2. Using Radio-Canada's media validation API to get the actual playlist URL
"""

import re
import json
import logging
from typing import Optional, Union
from urllib.parse import urljoin
import requests
from bs4 import BeautifulSoup


logger = logging.getLogger(__name__)


class PlaylistExtractor:
    """Extract m3u8 playlist URLs from OHdio audiobook pages using the API."""
    
    def __init__(self, session: Optional[requests.Session] = None):
        """Initialize the playlist extractor.
        
        Args:
            session: Optional requests session to use for HTTP requests
        """
        self.session = session or requests.Session()
        self.api_base_url = "https://services.radio-canada.ca/media/validation/v2/"
        
        # Set a proper User-Agent
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        })
    
    def extract_media_id(self, html_content: str, url: str) -> Optional[str]:
        """Extract the mediaId from the HTML content.
        
        Args:
            html_content: The HTML content of the page
            url: The URL of the page (for logging)
            
        Returns:
            The mediaId if found, None otherwise
        """
        logger.debug(f"Extracting media ID from {url}")
        
        # Method 1: Look for mediaId in JSON data
        media_id_patterns = [
            r'"mediaId"\s*:\s*"([^"]+)"',
            r'"mediaId"\s*:\s*(\d+)',
            r'mediaId["\']?\s*:\s*["\']?([^",\s}]+)',
            r'media-id["\']?\s*:\s*["\']?([^",\s}]+)',
        ]
        
        for pattern in media_id_patterns:
            matches = re.findall(pattern, html_content, re.IGNORECASE)
            if matches:
                media_id = matches[0].strip('"\'')
                logger.debug(f"Found media ID using pattern {pattern}: {media_id}")
                return media_id
        
        # Method 2: Parse HTML and look for data attributes
        try:
            soup = BeautifulSoup(html_content, 'html.parser')
            
            # Look for elements with media-related data attributes
            selectors = [
                '[data-media-id]',
                '[data-mediaid]',
                '[data-id]',
                '.media-player[data-id]',
                '.audio-player[data-id]',
                '.listen-button[data-id]',
                '.play-button[data-id]',
            ]
            
            for selector in selectors:
                elements = soup.select(selector)
                for element in elements:
                    for attr in ['data-media-id', 'data-mediaid', 'data-id']:
                        value = element.get(attr)
                        if value and value.isdigit():
                            logger.debug(f"Found media ID in {selector} {attr}: {value}")
                            return value
        
        except Exception as e:
            logger.warning(f"Error parsing HTML for media ID: {e}")
        
        # Method 3: Look for numeric IDs in script tags
        try:
            soup = BeautifulSoup(html_content, 'html.parser')
            scripts = soup.find_all('script')
            
            for script in scripts:
                if script.string:
                    # Look for numeric IDs that could be media IDs (7-8 digits)
                    numeric_ids = re.findall(r'\b(\d{7,8})\b', script.string)
                    if numeric_ids:
                        # Take the first one that looks like a media ID
                        for media_id in numeric_ids:
                            logger.debug(f"Found potential media ID in script: {media_id}")
                            return media_id
        
        except Exception as e:
            logger.warning(f"Error parsing scripts for media ID: {e}")
        
        logger.warning(f"Could not extract media ID from {url}")
        return None
    
    def get_playlist_from_api(self, media_id: str) -> Optional[str]:
        """Get the m3u8 playlist URL from Radio-Canada's API.
        
        Args:
            media_id: The media ID to fetch the playlist for
            
        Returns:
            The m3u8 playlist URL if found, None otherwise
        """
        api_params = {
            'appCode': 'medianet',
            'connectionType': 'hd',
            'deviceType': 'ipad',
            'idMedia': media_id,
            'multibitrate': 'true',
            'output': 'json',
            'tech': 'hls',
            'manifestVersion': '2'
        }
        
        try:
            logger.debug(f"Calling Radio-Canada API for media ID: {media_id}")
            response = self.session.get(self.api_base_url, params=api_params, timeout=10)
            response.raise_for_status()

            data = response.json()
            logger.info(f"API response for media ID {media_id}: {json.dumps(data, indent=2)}")
            
            # Look for the m3u8 URL in the response
            if 'url' in data:
                url = data['url']
                if url and url.endswith('.m3u8'):
                    logger.info(f"Found m3u8 URL: {url}")
                    return url
            
            # Alternative: look for URLs in nested structures
            if 'validationResults' in data:
                for result in data['validationResults']:
                    if 'url' in result:
                        url = result['url']
                        if url and url.endswith('.m3u8'):
                            logger.info(f"Found m3u8 URL in validation results: {url}")
                            return url
            
            # Look for any field containing an m3u8 URL
            def find_m3u8_recursive(obj, path=""):
                if isinstance(obj, dict):
                    for key, value in obj.items():
                        current_path = f"{path}.{key}" if path else key
                        if isinstance(value, str) and value.endswith('.m3u8'):
                            logger.info(f"Found m3u8 URL at {current_path}: {value}")
                            return value
                        elif isinstance(value, (dict, list)):
                            result = find_m3u8_recursive(value, current_path)
                            if result:
                                return result
                elif isinstance(obj, list):
                    for i, item in enumerate(obj):
                        current_path = f"{path}[{i}]" if path else f"[{i}]"
                        result = find_m3u8_recursive(item, current_path)
                        if result:
                            return result
                return None
            
            m3u8_url = find_m3u8_recursive(data)
            if m3u8_url:
                return m3u8_url
            
            logger.warning(f"No m3u8 URL found in API response for media ID: {media_id}")
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Error calling Radio-Canada API for media ID {media_id}: {e}")
        except json.JSONDecodeError as e:
            logger.error(f"Error parsing API response for media ID {media_id}: {e}")
        except Exception as e:
            logger.error(f"Unexpected error calling API for media ID {media_id}: {e}")
        
        return None
    
    def extract_playlist_url(self, html_content: str, url: str) -> Optional[str]:
        """Extract the m3u8 playlist URL from an OHdio audiobook page.
        
        Args:
            html_content: The HTML content of the audiobook page
            url: The URL of the audiobook page
            
        Returns:
            The m3u8 playlist URL if found, None otherwise
        """
        logger.info(f"Extracting playlist URL from: {url}")
        
        # Step 1: Extract the media ID
        media_id = self.extract_media_id(html_content, url)
        if not media_id:
            return None
        
        # Step 2: Get the playlist URL from the API
        playlist_url = self.get_playlist_from_api(media_id)
        
        if playlist_url:
            logger.info(f"Successfully extracted playlist URL: {playlist_url}")
        else:
            logger.error(f"Failed to extract playlist URL from {url}")
        
        return playlist_url


async def extract_playlist_url_async(
    html_content: str, 
    url: str, 
    session: Optional[requests.Session] = None
) -> Optional[str]:
    """Async wrapper for playlist URL extraction.
    
    Args:
        html_content: The HTML content of the audiobook page
        url: The URL of the audiobook page
        session: Optional requests session
        
    Returns:
        The m3u8 playlist URL if found, None otherwise
    """
    extractor = PlaylistExtractor(session)
    return extractor.extract_playlist_url(html_content, url)


def extract_playlist_url_sync(
    html_content: str, 
    url: str, 
    session: Optional[requests.Session] = None
) -> Optional[str]:
    """Synchronous playlist URL extraction.
    
    Args:
        html_content: The HTML content of the audiobook page
        url: The URL of the audiobook page
        session: Optional requests session
        
    Returns:
        The m3u8 playlist URL if found, None otherwise
    """
    extractor = PlaylistExtractor(session)
    return extractor.extract_playlist_url(html_content, url) 