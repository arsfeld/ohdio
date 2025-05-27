"""Category scraper for discovering audiobooks from OHdio category pages."""

import asyncio
import logging
from dataclasses import dataclass
from typing import List, Optional
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup

from ..utils.network_utils import safe_request


@dataclass
class AudiobookInfo:
    """Information about an audiobook discovered from category page."""
    
    title: str
    author: str
    url: str
    thumbnail_url: Optional[str] = None
    description: Optional[str] = None


class CategoryScraper:
    """Scrapes OHdio category pages to discover audiobooks."""
    
    JEUNESSE_CATEGORY_URL = "https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse"
    
    def __init__(self, config):
        """Initialize the category scraper.
        
        Args:
            config: Configuration object
        """
        self.config = config
        self.logger = logging.getLogger(__name__)
    
    async def scrape_category(self, category_url: Optional[str] = None) -> List[AudiobookInfo]:
        """Scrape all audiobooks from the category page.
        
        Args:
            category_url: URL of the category page (defaults to Jeunesse category)
            
        Returns:
            List of AudiobookInfo objects for discovered audiobooks
        """
        if category_url is None:
            category_url = self.JEUNESSE_CATEGORY_URL
        
        self.logger.info(f"Scraping category page: {category_url}")
        
        # Get the page content
        headers = self.config.get_headers()
        page_content = await safe_request(
            category_url,
            headers=headers,
            max_retries=self.config.retry_attempts,
            delay=self.config.delay_between_requests
        )
        
        if not page_content:
            self.logger.error(f"Failed to fetch category page: {category_url}")
            return []
        
        # Parse the page to extract audiobooks
        audiobooks = self._parse_category_page(page_content, category_url)
        
        self.logger.info(f"Found {len(audiobooks)} audiobooks in category")
        return audiobooks
    
    def _parse_category_page(self, page_content: str, base_url: str) -> List[AudiobookInfo]:
        """Parse the category page HTML to extract audiobook information.
        
        Args:
            page_content: HTML content of the category page
            base_url: Base URL for resolving relative links
            
        Returns:
            List of AudiobookInfo objects
        """
        soup = BeautifulSoup(page_content, 'html.parser')
        audiobooks = []
        
        # Try different parsing strategies based on the page structure
        parsing_methods = [
            self._parse_index_grid_items,  # New method for index-grid-item elements
            self._parse_book_items,
            self._parse_livre_audio_sections,
            self._parse_generic_links,
        ]
        
        for method in parsing_methods:
            try:
                books = method(soup, base_url)
                if books:
                    audiobooks.extend(books)
                    self.logger.debug(f"Found {len(books)} books using {method.__name__}")
            except Exception as e:
                self.logger.warning(f"Error in parsing method {method.__name__}: {e}")
        
        # Remove duplicates based on URL
        seen_urls = set()
        unique_audiobooks = []
        for book in audiobooks:
            if book.url not in seen_urls:
                seen_urls.add(book.url)
                unique_audiobooks.append(book)
        
        return unique_audiobooks
    
    def _parse_index_grid_items(self, soup: BeautifulSoup, base_url: str) -> List[AudiobookInfo]:
        """Parse audiobook items using index-grid-item class specifically.
        
        Args:
            soup: BeautifulSoup object of the page
            base_url: Base URL for resolving relative links
            
        Returns:
            List of AudiobookInfo objects
        """
        audiobooks = []
        
        # Find all elements with class index-grid-item
        grid_items = soup.find_all(class_='index-grid-item')
        self.logger.debug(f"Found {len(grid_items)} index-grid-item elements")
        
        for item in grid_items:
            # Look for audiobook links within each grid item
            audiobook_links = item.find_all('a', href=lambda href: href and 'livres-audio' in href)
            
            for link in audiobook_links:
                href = link.get('href')
                if not href:
                    continue
                
                full_url = urljoin(base_url, href)
                
                # Extract title from the link text or span
                title = self._extract_title_from_link(link)
                author = self._extract_author_from_link(link) or "Unknown Author"  # Default if not found
                thumbnail_url = self._extract_thumbnail_from_link(link, base_url)
                
                if title:  # Only require title, not author
                    book = AudiobookInfo(
                        title=title,
                        author=author,
                        url=full_url,
                        thumbnail_url=thumbnail_url
                    )
                    audiobooks.append(book)
                    self.logger.debug(f"Added book from grid item: {title} by {author}")
        
        return audiobooks
    
    def _parse_book_items(self, soup: BeautifulSoup, base_url: str) -> List[AudiobookInfo]:
        """Parse audiobook items using common CSS selectors.
        
        Args:
            soup: BeautifulSoup object of the page
            base_url: Base URL for resolving relative links
            
        Returns:
            List of AudiobookInfo objects
        """
        audiobooks = []
        
        # Common selectors for audiobook items
        selectors = [
            'article[data-type="livres-audio"]',
            '.livre-audio',
            '.audiobook-item',
            'article:has(a[href*="livres-audio"])',
            'div:has(a[href*="livres-audio"])',
        ]
        
        for selector in selectors:
            try:
                items = soup.select(selector)
                if items:
                    self.logger.debug(f"Found {len(items)} items with selector: {selector}")
                    for item in items:
                        book = self._extract_book_info_from_element(item, base_url)
                        if book:
                            audiobooks.append(book)
                    break  # Use first successful selector
            except Exception as e:
                self.logger.debug(f"Selector {selector} failed: {e}")
                continue
        
        return audiobooks
    
    def _parse_livre_audio_sections(self, soup: BeautifulSoup, base_url: str) -> List[AudiobookInfo]:
        """Parse sections specifically containing 'Livre audio' text.
        
        Args:
            soup: BeautifulSoup object of the page
            base_url: Base URL for resolving relative links
            
        Returns:
            List of AudiobookInfo objects
        """
        audiobooks = []
        
        # Find all elements containing "Livre audio" text
        livre_audio_elements = soup.find_all(text=lambda text: text and "Livre audio" in text)
        
        for element in livre_audio_elements:
            # Navigate up to find the containing article/div
            parent = element.parent
            while parent and parent.name not in ['article', 'div', 'section']:
                parent = parent.parent
            
            if parent:
                # Look for the main container
                container = parent
                while container and container.parent and container.parent.name in ['div', 'section', 'article']:
                    if len(container.parent.find_all('a', href=True)) > 0:
                        container = container.parent
                    else:
                        break
                
                book = self._extract_book_info_from_element(container, base_url)
                if book:
                    audiobooks.append(book)
        
        return audiobooks
    
    def _parse_generic_links(self, soup: BeautifulSoup, base_url: str) -> List[AudiobookInfo]:
        """Parse by finding all links that point to audiobook pages.
        
        Args:
            soup: BeautifulSoup object of the page
            base_url: Base URL for resolving relative links
            
        Returns:
            List of AudiobookInfo objects
        """
        audiobooks = []
        
        # Find all links that contain "livres-audio" in the href
        audiobook_links = soup.find_all('a', href=lambda href: href and 'livres-audio' in href)
        
        for link in audiobook_links:
            href = link.get('href')
            if not href:
                continue
            
            # Resolve relative URLs
            full_url = urljoin(base_url, href)
            
            # Extract title and author from the link or its parent elements
            title = self._extract_title_from_link(link)
            author = self._extract_author_from_link(link) or "Unknown Author"
            thumbnail_url = self._extract_thumbnail_from_link(link, base_url)
            
            if title:  # Only require title, author is optional
                book = AudiobookInfo(
                    title=title,
                    author=author,
                    url=full_url,
                    thumbnail_url=thumbnail_url
                )
                audiobooks.append(book)
        
        return audiobooks
    
    def _extract_book_info_from_element(self, element, base_url: str) -> Optional[AudiobookInfo]:
        """Extract audiobook information from a DOM element.
        
        Args:
            element: BeautifulSoup element containing book information
            base_url: Base URL for resolving relative links
            
        Returns:
            AudiobookInfo object or None if extraction failed
        """
        # Find the main link
        link = element.find('a', href=lambda href: href and 'livres-audio' in href)
        if not link:
            return None
        
        href = link.get('href')
        if not href:
            return None
        
        full_url = urljoin(base_url, href)
        
        # Extract title and author
        title = self._extract_title_from_link(link)
        author = self._extract_author_from_link(link) or "Unknown Author"
        thumbnail_url = self._extract_thumbnail_from_link(link, base_url)
        description = self._extract_description_from_element(element)
        
        if not title:
            self.logger.debug(f"No title found for book")
            return None
        
        return AudiobookInfo(
            title=title,
            author=author,
            url=full_url,
            thumbnail_url=thumbnail_url,
            description=description
        )
    
    def _extract_title_from_link(self, link) -> Optional[str]:
        """Extract book title from a link element.
        
        Args:
            link: BeautifulSoup link element
            
        Returns:
            Book title or None
        """
        # Try different methods to extract title, prioritizing OHdio-specific selectors
        methods = [
            lambda: link.find('span', class_='text'),  # OHdio specific
            lambda: link.get('title'),
            lambda: link.get_text(strip=True),
            lambda: link.find('h1'),
            lambda: link.find('h2'),
            lambda: link.find('h3'),
            lambda: link.find('h4'),
            lambda: link.find('.title'),
            lambda: link.find('.book-title'),
        ]
        
        for method in methods:
            try:
                result = method()
                if result:
                    text = result.get_text(strip=True) if hasattr(result, 'get_text') else str(result)
                    if text and len(text) > 2:
                        return text
            except:
                continue
        
        # Try parent elements
        parent = link.parent
        if parent:
            # Look for headings in parent
            for tag in ['h1', 'h2', 'h3', 'h4']:
                heading = parent.find(tag)
                if heading:
                    text = heading.get_text(strip=True)
                    if text and len(text) > 2:
                        return text
        
        return None
    
    def _extract_author_from_link(self, link) -> Optional[str]:
        """Extract book author from a link element.
        
        Args:
            link: BeautifulSoup link element
            
        Returns:
            Book author or None
        """
        # Look in the link and its parent for author information
        search_elements = [link, link.parent] if link.parent else [link]
        
        for element in search_elements:
            if not element:
                continue
            
            # Try different selectors for author
            author_selectors = [
                '.author',
                '.book-author',
                '.by-author',
                'p:contains("par")',
                'span:contains("par")',
                '[data-author]',
            ]
            
            for selector in author_selectors:
                try:
                    author_elem = element.select_one(selector)
                    if author_elem:
                        text = author_elem.get_text(strip=True)
                        # Clean up author text (remove "par", "by", etc.)
                        text = text.replace('par ', '').replace('by ', '').strip()
                        if text and len(text) > 1:
                            return text
                except:
                    continue
            
            # Try to find author in sibling elements
            if element.parent:
                siblings = element.parent.find_all(['p', 'span', 'div'])
                for sibling in siblings:
                    text = sibling.get_text(strip=True)
                    if any(keyword in text.lower() for keyword in ['par ', 'by ', 'auteur']):
                        # Extract author name
                        for keyword in ['par ', 'by ', 'auteur: ']:
                            if keyword in text.lower():
                                author = text.lower().split(keyword, 1)[1].strip()
                                if author:
                                    return author.title()
        
        return None
    
    def _extract_thumbnail_from_link(self, link, base_url: str) -> Optional[str]:
        """Extract thumbnail URL from a link element.
        
        Args:
            link: BeautifulSoup link element
            base_url: Base URL for resolving relative URLs
            
        Returns:
            Thumbnail URL or None
        """
        # Look for images in the link and its parent
        search_elements = [link, link.parent] if link.parent else [link]
        
        for element in search_elements:
            if not element:
                continue
            
            # Find img tags
            img = element.find('img')
            if img:
                src = img.get('src') or img.get('data-src')
                if src:
                    return urljoin(base_url, src)
        
        return None
    
    def _extract_description_from_element(self, element) -> Optional[str]:
        """Extract book description from an element.
        
        Args:
            element: BeautifulSoup element
            
        Returns:
            Book description or None
        """
        # Look for description in various places
        desc_selectors = [
            '.description',
            '.summary',
            '.excerpt',
            'p.description',
            '[data-description]',
        ]
        
        for selector in desc_selectors:
            try:
                desc_elem = element.select_one(selector)
                if desc_elem:
                    text = desc_elem.get_text(strip=True)
                    if text and len(text) > 10:
                        return text
            except:
                continue
        
        return None
    
    async def get_total_audiobook_count(self, category_url: Optional[str] = None) -> int:
        """Get the total number of audiobooks in the category.
        
        Args:
            category_url: URL of the category page
            
        Returns:
            Total number of audiobooks
        """
        if category_url is None:
            category_url = self.JEUNESSE_CATEGORY_URL
        
        audiobooks = await self.scrape_category(category_url)
        return len(audiobooks) 