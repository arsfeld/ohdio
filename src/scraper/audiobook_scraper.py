"""Audiobook scraper for extracting detailed metadata from individual book pages."""

import asyncio
import logging
from dataclasses import dataclass
from typing import Optional, Dict, Any
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from ..utils.network_utils import safe_request, download_file
from .playlist_extractor import PlaylistExtractor


@dataclass
class AudiobookMetadata:
    """Complete metadata for an audiobook."""
    
    title: str
    author: str
    url: str
    playlist_url: Optional[str] = None
    description: Optional[str] = None
    duration: Optional[str] = None
    publication_date: Optional[str] = None
    genre: Optional[str] = None
    language: str = "fr"
    thumbnail_url: Optional[str] = None
    thumbnail_data: Optional[bytes] = None
    isbn: Optional[str] = None
    publisher: Optional[str] = None
    narrator: Optional[str] = None
    series: Optional[str] = None
    series_number: Optional[int] = None


class AudiobookScraper:
    """Scrapes individual audiobook pages to extract detailed metadata."""
    
    def __init__(self, config):
        """Initialize the audiobook scraper.
        
        Args:
            config: Configuration object
        """
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.playlist_extractor = PlaylistExtractor()
    
    async def scrape_audiobook(self, book_url: str) -> Optional[AudiobookMetadata]:
        """Extract all metadata and playlist URL from an audiobook page.
        
        Args:
            book_url: URL of the audiobook page
            
        Returns:
            AudiobookMetadata object or None if scraping failed
        """
        self.logger.info(f"Scraping audiobook: {book_url}")
        
        # Get the page content
        headers = self.config.get_headers()
        page_content = await safe_request(
            book_url,
            headers=headers,
            max_retries=self.config.retry_attempts,
            delay=self.config.delay_between_requests
        )
        
        if not page_content:
            self.logger.error(f"Failed to fetch audiobook page: {book_url}")
            return None
        
        # Extract metadata from the page
        metadata = await self._extract_metadata(page_content, book_url)
        
        if metadata:
            self.logger.info(f"Successfully scraped '{metadata.title}' by {metadata.author}")
        else:
            self.logger.warning(f"Failed to extract metadata from {book_url}")
        
        return metadata
    
    async def _extract_metadata(self, page_content: str, page_url: str) -> Optional[AudiobookMetadata]:
        """Extract metadata from the audiobook page content.
        
        Args:
            page_content: HTML content of the page
            page_url: URL of the page
            
        Returns:
            AudiobookMetadata object or None
        """
        soup = BeautifulSoup(page_content, 'html.parser')
        
        # Extract basic information
        title = self._extract_title(soup)
        author = self._extract_author(soup)
        
        if not title or not author:
            self.logger.warning(f"Missing basic info - title: '{title}', author: '{author}'")
            return None
        
        # Extract playlist URL
        playlist_url = self.playlist_extractor.extract_playlist_url(page_content, page_url)
        
        # Extract additional metadata
        description = self._extract_description(soup)
        duration = self._extract_duration(soup)
        publication_date = self._extract_publication_date(soup)
        genre = self._extract_genre(soup)
        thumbnail_url = self._extract_thumbnail_url(soup, page_url)
        isbn = self._extract_isbn(soup)
        publisher = self._extract_publisher(soup)
        narrator = self._extract_narrator(soup)
        series_info = self._extract_series_info(soup)
        
        # Download thumbnail if available
        thumbnail_data = None
        if thumbnail_url:
            thumbnail_data = await self._download_thumbnail(thumbnail_url)
        
        metadata = AudiobookMetadata(
            title=title,
            author=author,
            url=page_url,
            playlist_url=playlist_url,
            description=description,
            duration=duration,
            publication_date=publication_date,
            genre=genre,
            thumbnail_url=thumbnail_url,
            thumbnail_data=thumbnail_data,
            isbn=isbn,
            publisher=publisher,
            narrator=narrator,
            series=series_info.get('series') if series_info else None,
            series_number=series_info.get('number') if series_info else None,
        )
        
        return metadata
    
    def _extract_title(self, soup: BeautifulSoup) -> Optional[str]:
        """Extract book title from the page.
        
        Args:
            soup: BeautifulSoup object of the page
            
        Returns:
            Book title or None
        """
        # Try different selectors for title
        selectors = [
            'h1',
            '.title',
            '.book-title',
            '.audiobook-title',
            '[data-title]',
            'meta[property="og:title"]',
            'title',
        ]
        
        for selector in selectors:
            try:
                element = soup.select_one(selector)
                if element:
                    if element.name == 'meta':
                        title = element.get('content')
                    else:
                        title = element.get_text(strip=True)
                    
                    if title and len(title) > 2:
                        # Clean up title (remove site name, etc.)
                        title = self._clean_title(title)
                        if title:
                            return title
            except Exception as e:
                self.logger.debug(f"Error extracting title with selector {selector}: {e}")
        
        return None
    
    def _extract_author(self, soup: BeautifulSoup) -> Optional[str]:
        """Extract book author from the page.
        
        Args:
            soup: BeautifulSoup object of the page
            
        Returns:
            Book author or None
        """
        # Try different selectors for author
        selectors = [
            '.author',
            '.book-author',
            '.by-author',
            '[data-author]',
            'meta[name="author"]',
            'meta[property="book:author"]',
        ]
        
        for selector in selectors:
            try:
                element = soup.select_one(selector)
                if element:
                    if element.name == 'meta':
                        author = element.get('content')
                    else:
                        author = element.get_text(strip=True)
                    
                    if author and len(author) > 1:
                        # Clean up author text
                        author = self._clean_author(author)
                        if author:
                            return author
            except Exception as e:
                self.logger.debug(f"Error extracting author with selector {selector}: {e}")
        
        # Try to find author in HTML content first, then text content
        import re
        
        # First search in HTML content to preserve structure
        html_content = str(soup)
        
        # Look for specific patterns in HTML, prioritizing "Écrit par" (author) over "Lu par" (narrator)
        html_author_patterns = [
            r'>Écrit\s+par\s+([A-Z][a-zA-ZÀ-ÿ\s\-\']+?)<',
            r'class="[^"]*animator[^"]*">Écrit\s+par\s+([A-Z][a-zA-ZÀ-ÿ\s\-\']+?)<',
        ]
        
        for pattern in html_author_patterns:
            match = re.search(pattern, html_content, re.IGNORECASE)
            if match:
                author = match.group(1).strip()
                # Clean up the author name
                author = re.sub(r'[^\w\s\-\'À-ÿ]', '', author)  # Remove non-alphanumeric except spaces, hyphens, apostrophes
                author = ' '.join(author.split())  # Normalize whitespace
                
                # Validate that it looks like a real name (1-3 words, reasonable length)
                words = author.split()
                if 1 <= len(words) <= 3 and 2 <= len(author) <= 50:
                    return author
        
        # If not found in HTML, try text content
        text_content = soup.get_text()
        text_author_patterns = [
            r'Écrit\s+par\s+([A-Z][a-zA-ZÀ-ÿ\s\-\']+?)(?:\s|$)',
            r'auteur[:\s]+([A-Z][a-zA-ZÀ-ÿ\s\-\']+?)(?:\s|$)',
            r'by\s+([A-Z][a-zA-ZÀ-ÿ\s\-\']+?)(?:\s|$)',
            r'de\s+([A-Z][a-zA-ZÀ-ÿ\s\-\']+?)(?:\s|$)',
        ]
        
        for pattern in text_author_patterns:
            match = re.search(pattern, text_content, re.IGNORECASE)
            if match:
                author = match.group(1).strip()
                # Clean up the author name
                author = re.sub(r'[^\w\s\-\'À-ÿ]', '', author)  # Remove non-alphanumeric except spaces, hyphens, apostrophes
                author = ' '.join(author.split())  # Normalize whitespace
                
                # Validate that it looks like a real name (1-3 words, reasonable length)
                words = author.split()
                if 1 <= len(words) <= 3 and 2 <= len(author) <= 50:
                    # Check if each word starts with a capital letter
                    if all(word[0].isupper() for word in words if word):
                        return author
        
        # Fallback: look for simple patterns in individual lines
        for line in text_content.split('\n'):
            line = line.strip()
            if len(line) > 5 and len(line) < 50:  # Reasonable line length
                if any(keyword in line.lower() for keyword in ['par ', 'by ', 'auteur']):
                    for keyword in ['par ', 'by ', 'auteur: ', 'de ']:
                        if keyword in line.lower():
                            author = line.lower().split(keyword, 1)[1].strip()
                            # Only take first 2-3 words (reasonable author name)
                            words = author.split()[:3]
                            if len(words) >= 1 and len(words) <= 3:
                                return ' '.join(word.title() for word in words)
        
        return None
    
    def _extract_description(self, soup: BeautifulSoup) -> Optional[str]:
        """Extract book description from the page.
        
        Args:
            soup: BeautifulSoup object of the page
            
        Returns:
            Book description or None
        """
        selectors = [
            '.description',
            '.summary',
            '.synopsis',
            '.excerpt',
            'meta[name="description"]',
            'meta[property="og:description"]',
            '.book-description',
            '.content-description',
        ]
        
        for selector in selectors:
            try:
                element = soup.select_one(selector)
                if element:
                    if element.name == 'meta':
                        description = element.get('content')
                    else:
                        description = element.get_text(strip=True)
                    
                    if description and len(description) > 20:
                        return description
            except Exception as e:
                self.logger.debug(f"Error extracting description with selector {selector}: {e}")
        
        return None
    
    def _extract_duration(self, soup: BeautifulSoup) -> Optional[str]:
        """Extract audiobook duration from the page.
        
        Args:
            soup: BeautifulSoup object of the page
            
        Returns:
            Duration string or None
        """
        selectors = [
            '.duration',
            '.length',
            '.runtime',
            '[data-duration]',
            'meta[property="video:duration"]',
        ]
        
        for selector in selectors:
            try:
                element = soup.select_one(selector)
                if element:
                    if element.name == 'meta':
                        duration = element.get('content')
                    else:
                        duration = element.get_text(strip=True)
                    
                    if duration:
                        return duration
            except Exception as e:
                self.logger.debug(f"Error extracting duration with selector {selector}: {e}")
        
        # Look for duration patterns in text
        import re
        text_content = soup.get_text()
        duration_patterns = [
            r'(\d+h\s*\d+min?)',
            r'(\d+:\d+:\d+)',
            r'(\d+\s*heures?\s*\d+\s*minutes?)',
            r'Durée[:\s]*([^.]+)',
        ]
        
        for pattern in duration_patterns:
            match = re.search(pattern, text_content, re.IGNORECASE)
            if match:
                return match.group(1).strip()
        
        return None
    
    def _extract_publication_date(self, soup: BeautifulSoup) -> Optional[str]:
        """Extract publication date from the page.
        
        Args:
            soup: BeautifulSoup object of the page
            
        Returns:
            Publication date string or None
        """
        selectors = [
            '.publication-date',
            '.publish-date',
            '.date',
            'meta[property="book:release_date"]',
            'meta[name="publication_date"]',
            'time[datetime]',
        ]
        
        for selector in selectors:
            try:
                element = soup.select_one(selector)
                if element:
                    if element.name == 'meta':
                        date = element.get('content')
                    elif element.name == 'time':
                        date = element.get('datetime') or element.get_text(strip=True)
                    else:
                        date = element.get_text(strip=True)
                    
                    if date:
                        return date
            except Exception as e:
                self.logger.debug(f"Error extracting date with selector {selector}: {e}")
        
        return None
    
    def _extract_genre(self, soup: BeautifulSoup) -> Optional[str]:
        """Extract genre from the page.
        
        Args:
            soup: BeautifulSoup object of the page
            
        Returns:
            Genre string or None
        """
        selectors = [
            '.genre',
            '.category',
            '.book-genre',
            'meta[property="book:genre"]',
            'meta[name="genre"]',
        ]
        
        for selector in selectors:
            try:
                element = soup.select_one(selector)
                if element:
                    if element.name == 'meta':
                        genre = element.get('content')
                    else:
                        genre = element.get_text(strip=True)
                    
                    if genre:
                        return genre
            except Exception as e:
                self.logger.debug(f"Error extracting genre with selector {selector}: {e}")
        
        # Default genre for Jeunesse category
        return "Jeunesse"
    
    def _extract_thumbnail_url(self, soup: BeautifulSoup, base_url: str) -> Optional[str]:
        """Extract thumbnail URL from the page.
        
        Args:
            soup: BeautifulSoup object of the page
            base_url: Base URL for resolving relative URLs
            
        Returns:
            Thumbnail URL or None
        """
        selectors = [
            '.book-cover img',
            '.cover img',
            '.thumbnail img',
            'meta[property="og:image"]',
            'meta[name="twitter:image"]',
            '.audiobook-cover img',
        ]
        
        for selector in selectors:
            try:
                element = soup.select_one(selector)
                if element:
                    if element.name == 'meta':
                        url = element.get('content')
                    else:
                        url = element.get('src') or element.get('data-src')
                    
                    if url:
                        return urljoin(base_url, url)
            except Exception as e:
                self.logger.debug(f"Error extracting thumbnail with selector {selector}: {e}")
        
        return None
    
    def _extract_isbn(self, soup: BeautifulSoup) -> Optional[str]:
        """Extract ISBN from the page.
        
        Args:
            soup: BeautifulSoup object of the page
            
        Returns:
            ISBN string or None
        """
        selectors = [
            'meta[property="book:isbn"]',
            'meta[name="isbn"]',
            '.isbn',
        ]
        
        for selector in selectors:
            try:
                element = soup.select_one(selector)
                if element:
                    if element.name == 'meta':
                        isbn = element.get('content')
                    else:
                        isbn = element.get_text(strip=True)
                    
                    if isbn:
                        return isbn
            except Exception as e:
                self.logger.debug(f"Error extracting ISBN with selector {selector}: {e}")
        
        return None
    
    def _extract_publisher(self, soup: BeautifulSoup) -> Optional[str]:
        """Extract publisher from the page.
        
        Args:
            soup: BeautifulSoup object of the page
            
        Returns:
            Publisher string or None
        """
        selectors = [
            '.publisher',
            '.book-publisher',
            'meta[property="book:publisher"]',
            'meta[name="publisher"]',
        ]
        
        for selector in selectors:
            try:
                element = soup.select_one(selector)
                if element:
                    if element.name == 'meta':
                        publisher = element.get('content')
                    else:
                        publisher = element.get_text(strip=True)
                    
                    if publisher:
                        return publisher
            except Exception as e:
                self.logger.debug(f"Error extracting publisher with selector {selector}: {e}")
        
        return None
    
    def _extract_narrator(self, soup: BeautifulSoup) -> Optional[str]:
        """Extract narrator from the page.
        
        Args:
            soup: BeautifulSoup object of the page
            
        Returns:
            Narrator string or None
        """
        selectors = [
            '.narrator',
            '.reader',
            '.voice-actor',
            '.read-by',
        ]
        
        for selector in selectors:
            try:
                element = soup.select_one(selector)
                if element:
                    narrator = element.get_text(strip=True)
                    if narrator:
                        return narrator
            except Exception as e:
                self.logger.debug(f"Error extracting narrator with selector {selector}: {e}")
        
        # Look for narrator in text content
        text_content = soup.get_text()
        for line in text_content.split('\n'):
            line = line.strip()
            if any(keyword in line.lower() for keyword in ['lu par', 'narré par', 'read by']):
                for keyword in ['lu par ', 'narré par ', 'read by ']:
                    if keyword in line.lower():
                        narrator = line.lower().split(keyword, 1)[1].strip()
                        if narrator:
                            return narrator.title()
        
        return None
    
    def _extract_series_info(self, soup: BeautifulSoup) -> Optional[Dict[str, Any]]:
        """Extract series information from the page.
        
        Args:
            soup: BeautifulSoup object of the page
            
        Returns:
            Dictionary with series info or None
        """
        selectors = [
            '.series',
            '.book-series',
            '.series-info',
        ]
        
        for selector in selectors:
            try:
                element = soup.select_one(selector)
                if element:
                    text = element.get_text(strip=True)
                    if text:
                        # Try to extract series name and number
                        import re
                        # Pattern like "Series Name #3" or "Series Name, tome 3"
                        patterns = [
                            r'(.+?)\s*#(\d+)',
                            r'(.+?),?\s*tome\s*(\d+)',
                            r'(.+?),?\s*volume\s*(\d+)',
                        ]
                        
                        for pattern in patterns:
                            match = re.match(pattern, text, re.IGNORECASE)
                            if match:
                                return {
                                    'series': match.group(1).strip(),
                                    'number': int(match.group(2))
                                }
                        
                        # Just series name without number
                        return {'series': text, 'number': None}
            except Exception as e:
                self.logger.debug(f"Error extracting series with selector {selector}: {e}")
        
        return None
    
    def _clean_title(self, title: str) -> str:
        """Clean up extracted title.
        
        Args:
            title: Raw title string
            
        Returns:
            Cleaned title
        """
        # Remove common suffixes
        suffixes_to_remove = [
            ' | ICI OHdio',
            ' | Radio-Canada',
            ' - OHdio',
            ' - Radio-Canada',
            ' - Livre audio',
        ]
        
        for suffix in suffixes_to_remove:
            if title.endswith(suffix):
                title = title[:-len(suffix)]
        
        return title.strip()
    
    def _clean_author(self, author: str) -> str:
        """Clean up extracted author.
        
        Args:
            author: Raw author string
            
        Returns:
            Cleaned author
        """
        # Remove common prefixes
        prefixes_to_remove = ['par ', 'by ', 'de ', 'auteur: ']
        
        author_lower = author.lower()
        for prefix in prefixes_to_remove:
            if author_lower.startswith(prefix):
                author = author[len(prefix):]
                break
        
        return author.strip()
    
    async def _download_thumbnail(self, thumbnail_url: str) -> Optional[bytes]:
        """Download thumbnail image data.
        
        Args:
            thumbnail_url: URL of the thumbnail image
            
        Returns:
            Image data as bytes or None
        """
        try:
            import tempfile
            import os
            
            # Download to temporary file
            with tempfile.NamedTemporaryFile(delete=False) as temp_file:
                temp_path = temp_file.name
            
            success = await download_file(
                thumbnail_url,
                temp_path,
                headers=self.config.get_headers()
            )
            
            if success:
                with open(temp_path, 'rb') as f:
                    data = f.read()
                os.unlink(temp_path)
                return data
            else:
                if os.path.exists(temp_path):
                    os.unlink(temp_path)
                return None
                
        except Exception as e:
            self.logger.warning(f"Failed to download thumbnail {thumbnail_url}: {e}")
            return None 