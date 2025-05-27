#!/usr/bin/env python3
"""CLI entry point for the OHdio audiobook downloader."""

import asyncio
import sys
from pathlib import Path

# Add src to path so we can import our modules
sys.path.insert(0, str(Path(__file__).parent / "src"))

from src.main import main

if __name__ == "__main__":
    asyncio.run(main()) 