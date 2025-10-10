"""OHdio audiobook downloader package."""

__version__ = "1.0.0"
__author__ = "OHdio Downloader"
__description__ = "A tool for downloading audiobooks from Radio-Canada's OHdio platform"

from .main import OHdioDownloader, main

__all__ = ["OHdioDownloader", "main"] 