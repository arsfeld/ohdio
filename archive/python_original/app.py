#!/usr/bin/env python3
"""Gradio web UI for the OHdio audiobook downloader."""

import asyncio
import logging
import sys
import zipfile
import io
import threading
import time
import queue
from pathlib import Path
from datetime import datetime
from typing import List, Optional, Tuple, Dict
import gradio as gr

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

from src.main import OHdioDownloader
from src.utils.config import Config
from src.utils.logger import setup_logging
from src.downloader.ytdlp_downloader import YtDlpDownloader


# Global state
LOG_QUEUE = queue.Queue()
DOWNLOAD_STATE = {
    'in_progress': False,
    'stop_requested': False,
    'thread': None,
    'result': None,
    'downloader': None,
    'log_handler': None
}


class GradioLogHandler(logging.Handler):
    """Custom logging handler that writes to queue for Gradio display."""

    def emit(self, record):
        """Emit a log record."""
        try:
            msg = self.format(record)
            timestamp = datetime.fromtimestamp(record.created).strftime("%H:%M:%S")

            # Determine log level emoji
            level_emoji = {
                'DEBUG': '🔍',
                'INFO': 'ℹ️',
                'WARNING': '⚠️',
                'ERROR': '❌',
                'CRITICAL': '🚨'
            }.get(record.levelname, 'ℹ️')

            log_entry = f"[{timestamp}] {level_emoji} {msg}"
            LOG_QUEUE.put(log_entry)
        except Exception:
            pass


def get_config_path() -> str:
    """Get configuration file path."""
    config_path = Path("config.json")
    if not config_path.exists():
        raise FileNotFoundError(f"Configuration file not found: {config_path}")
    return str(config_path)


def initialize_downloader():
    """Initialize the OHdio downloader."""
    if DOWNLOAD_STATE['downloader'] is None:
        config_file = get_config_path()
        # Use /data/logs for Docker volume, fallback to logs/ for local development
        log_path = "/data/logs/scraper.log" if Path("/data/logs").exists() else "logs/scraper.log"
        setup_logging(log_level="INFO", log_file=log_path, console_output=False, json_format=False)
        DOWNLOAD_STATE['downloader'] = OHdioDownloader(config_file)

        # Add custom log handler
        if DOWNLOAD_STATE['log_handler'] is None:
            DOWNLOAD_STATE['log_handler'] = GradioLogHandler()
            DOWNLOAD_STATE['log_handler'].setLevel(logging.INFO)
            formatter = logging.Formatter('%(message)s')
            DOWNLOAD_STATE['log_handler'].setFormatter(formatter)

            # Add handler to root logger
            root_logger = logging.getLogger()
            root_logger.addHandler(DOWNLOAD_STATE['log_handler'])


def get_downloaded_files() -> List[Path]:
    """Get list of downloaded audiobook files."""
    config_file = get_config_path()
    config = Config.from_file(config_file)
    output_dir = Path(config.output_directory)

    if not output_dir.exists():
        output_dir.mkdir(parents=True, exist_ok=True)
        return []

    # Get all MP3 files, sorted by modification time (newest first)
    files = sorted(
        output_dir.glob("*.mp3"),
        key=lambda x: x.stat().st_mtime,
        reverse=True
    )
    return files


def format_file_size(size_bytes: int) -> str:
    """Format file size in human-readable format."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.1f} TB"


def format_datetime(timestamp: float) -> str:
    """Format timestamp as human-readable datetime."""
    dt = datetime.fromtimestamp(timestamp)
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def is_ohdio_url(url: str) -> bool:
    """Check if URL is an OHdio URL."""
    ohdio_domains = [
        'ici.radio-canada.ca/ohdio',
        'radio-canada.ca/ohdio'
    ]
    return any(domain in url.lower() for domain in ohdio_domains)


def get_logs_text() -> str:
    """Get all logs from queue as formatted text."""
    logs = []
    while not LOG_QUEUE.empty():
        try:
            logs.append(LOG_QUEUE.get_nowait())
        except queue.Empty:
            break
    return "\n".join(logs) if logs else ""


def create_zip_of_files(file_paths: List[Path]) -> bytes:
    """Create a ZIP file containing the selected audiobooks."""
    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:
        for file_path in file_paths:
            zip_file.write(file_path, arcname=file_path.name)

    zip_buffer.seek(0)
    return zip_buffer.getvalue()


async def download_generic_url(url: str):
    """Download from any URL supported by yt-dlp."""
    try:
        config_file = get_config_path()
        config = Config.from_file(config_file)
        downloader = YtDlpDownloader(config)

        # Get media info first
        logging.info("Extracting media information...")
        media_info = downloader.get_media_info(url)

        if not media_info:
            logging.error("Failed to extract media information from URL")
            return False

        title = media_info.get('title', 'Unknown Title')
        uploader = media_info.get('uploader', 'Unknown Uploader')

        logging.info(f"Detected: {title} by {uploader}")

        # Download the file
        logging.info(f"Downloading {title}...")
        output_path = await downloader.download_audiobook(
            playlist_url=url,
            title=title,
            author=uploader
        )

        if output_path:
            logging.info(f"✅ Successfully downloaded: {title}")
            return True
        else:
            logging.error("Download failed")
            return False

    except Exception as e:
        logging.error(f"Error: {e}")
        return False


async def _download_single_async(url: str, downloader):
    """Async download single audiobook."""
    result = {'success': None, 'error': None}

    try:
        if is_ohdio_url(url):
            logging.info("🔍 Detected OHdio URL. Starting download...")
            success = await downloader.download_single_audiobook(url)
            if success:
                result['success'] = f"✅ Successfully downloaded audiobook from: {url}"
            else:
                result['error'] = f"❌ Failed to download audiobook from: {url}"
        else:
            logging.info("🔍 Non-OHdio URL detected. Using yt-dlp to download...")
            success = await download_generic_url(url)
            if success:
                result['success'] = f"✅ Successfully downloaded media from: {url}"
            else:
                result['error'] = f"❌ Failed to download media from: {url}"
    except Exception as e:
        result['error'] = f"❌ Error: {e}"
        logging.error(f"Download error: {e}")

    return result


async def _download_category_async(category_url: Optional[str], downloader):
    """Async download category."""
    result = {'success': None, 'error': None}

    try:
        logging.info("🔍 Starting category download...")
        await downloader.download_all_audiobooks(category_url)
        result['success'] = "✅ Category download completed!"
    except Exception as e:
        result['error'] = f"❌ Error: {e}"
        logging.error(f"Category download error: {e}")

    return result


def _run_async_in_thread(coro, result_container):
    """Run async coroutine in a new event loop."""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        result = loop.run_until_complete(coro)
        result_container['result'] = result
        result_container['completed'] = True
    except Exception as e:
        result_container['error'] = str(e)
        result_container['completed'] = True
    finally:
        loop.close()


def start_download_single(url: str) -> str:
    """Start downloading a single audiobook."""
    if not url:
        return "❌ Please enter a URL"

    if DOWNLOAD_STATE['in_progress']:
        return "⚠️ Download already in progress"

    # Clear logs
    while not LOG_QUEUE.empty():
        try:
            LOG_QUEUE.get_nowait()
        except queue.Empty:
            break

    # Initialize downloader
    initialize_downloader()

    # Set state
    DOWNLOAD_STATE['in_progress'] = True
    DOWNLOAD_STATE['stop_requested'] = False
    result_container = {'completed': False, 'result': None, 'error': None}
    DOWNLOAD_STATE['result'] = result_container

    # Start download thread
    thread = threading.Thread(
        target=_run_async_in_thread,
        args=(_download_single_async(url, DOWNLOAD_STATE['downloader']), result_container),
        daemon=True
    )
    thread.start()
    DOWNLOAD_STATE['thread'] = thread

    return "⏳ Download started... Check logs below for progress"


def start_download_category(category_url: Optional[str] = None) -> str:
    """Start downloading a category."""
    if DOWNLOAD_STATE['in_progress']:
        return "⚠️ Download already in progress"

    # Clear logs
    while not LOG_QUEUE.empty():
        try:
            LOG_QUEUE.get_nowait()
        except queue.Empty:
            break

    # Initialize downloader
    initialize_downloader()

    # Set state
    DOWNLOAD_STATE['in_progress'] = True
    DOWNLOAD_STATE['stop_requested'] = False
    result_container = {'completed': False, 'result': None, 'error': None}
    DOWNLOAD_STATE['result'] = result_container

    # Start download thread
    thread = threading.Thread(
        target=_run_async_in_thread,
        args=(_download_category_async(category_url if category_url else None, DOWNLOAD_STATE['downloader']), result_container),
        daemon=True
    )
    thread.start()
    DOWNLOAD_STATE['thread'] = thread

    return "⏳ Category download started... Check logs below for progress"


def check_download_status() -> Tuple[str, str, bool]:
    """Check if download is complete and return status."""
    if DOWNLOAD_STATE['result'] and DOWNLOAD_STATE['result'].get('completed'):
        result_data = DOWNLOAD_STATE['result'].get('result', {})

        status = ""
        if result_data:
            if result_data.get('success'):
                status = result_data['success']
            if result_data.get('error'):
                status = result_data['error']

        if DOWNLOAD_STATE['result'].get('error'):
            status = f"❌ Thread error: {DOWNLOAD_STATE['result']['error']}"

        DOWNLOAD_STATE['in_progress'] = False
        DOWNLOAD_STATE['result'] = None

        # Get final logs
        logs = get_logs_text()
        return status, logs, False

    if DOWNLOAD_STATE['in_progress']:
        logs = get_logs_text()
        return "⏳ Download in progress...", logs, True

    return "", "", False


def get_file_list(search_query: str = "") -> List[Dict]:
    """Get list of files with metadata."""
    files = get_downloaded_files()

    if search_query:
        files = [f for f in files if search_query.lower() in f.stem.lower()]

    file_list = []
    for f in files:
        file_list.append({
            'path': str(f),
            'name': f.stem,
            'size': format_file_size(f.stat().st_size),
            'modified': format_datetime(f.stat().st_mtime)
        })

    return file_list


def get_stats() -> str:
    """Get statistics for sidebar."""
    try:
        config_file = get_config_path()
        config = Config.from_file(config_file)

        files = get_downloaded_files()
        total_size = sum(f.stat().st_size for f in files)

        stats = f"""
### 📊 Statistics

**Total Files:** {len(files)}
**Total Size:** {format_file_size(total_size)}

### ⚙️ Configuration

**Output Dir:** `{config.output_directory}`
**Max Concurrent:** {config.max_concurrent_downloads}
**Skip Existing:** {'✅' if config.skip_existing else '❌'}
**Embed Metadata:** {'✅' if config.embed_metadata else '❌'}
"""

        # Add download stats if available
        if DOWNLOAD_STATE['downloader'] and DOWNLOAD_STATE['downloader'].stats:
            dl_stats = DOWNLOAD_STATE['downloader'].stats
            stats += f"""
### 📥 Download Stats

**Discovered:** {dl_stats.get('discovered', 0)}
**Downloaded:** {dl_stats.get('downloaded', 0)}
**Skipped:** {dl_stats.get('skipped', 0)}
**Failed:** {dl_stats.get('failed', 0)}
"""

        return stats
    except Exception as e:
        return f"Error loading stats: {e}"


def delete_file(file_path: str) -> str:
    """Delete a single file."""
    try:
        Path(file_path).unlink()
        return f"✅ Deleted {Path(file_path).name}"
    except Exception as e:
        return f"❌ Error deleting file: {e}"


def bulk_delete_files(selected_files: List) -> str:
    """Delete multiple files."""
    if not selected_files:
        return "⚠️ No files selected"

    deleted = 0
    errors = []

    for file_path in selected_files:
        try:
            Path(file_path).unlink()
            deleted += 1
        except Exception as e:
            errors.append(f"{Path(file_path).name}: {e}")

    result = f"✅ Deleted {deleted} file(s)"
    if errors:
        result += f"\n❌ Errors: {', '.join(errors)}"

    return result


def create_bulk_zip(selected_files: List) -> Optional[str]:
    """Create ZIP of selected files."""
    if not selected_files:
        return None

    file_paths = [Path(f) for f in selected_files]
    zip_data = create_zip_of_files(file_paths)

    # Save to temp file
    temp_zip = Path(f"temp_ohdio_{datetime.now().strftime('%Y%m%d_%H%M%S')}.zip")
    temp_zip.write_bytes(zip_data)

    return str(temp_zip)


# Initialize downloader on startup
initialize_downloader()


# Build Gradio interface
with gr.Blocks(title="OHdio Audiobook Downloader", theme=gr.themes.Soft()) as app:
    gr.Markdown("# 🎧 OHdio Audiobook Downloader")

    # Detect if running on HF Spaces
    import os
    if os.getenv("SPACE_ID"):
        gr.Markdown("""
        ⚠️ **Geo-Restriction Notice**: Radio-Canada content is geo-restricted to Canada.
        This Space runs on US servers and **cannot download OHdio audiobooks**.
        However, you can still download from YouTube, Vimeo, and other yt-dlp supported sites!

        To download OHdio audiobooks, please run this app locally or on a Canadian server.
        See [installation instructions](https://github.com/arsfeld/ohdio) for details.
        """, elem_classes=["warning-box"])

    with gr.Row():
        with gr.Column(scale=3):
            with gr.Tabs() as tabs:
                # Download Tab
                with gr.Tab("📥 Download"):
                    gr.Markdown("## Download Audiobooks")

                    download_mode = gr.Radio(
                        ["Single Audiobook", "Entire Category"],
                        label="Download Mode",
                        value="Single Audiobook"
                    )

                    with gr.Group(visible=True) as single_mode:
                        url_input = gr.Textbox(
                            label="Media URL",
                            placeholder="Enter OHdio URL or any yt-dlp supported URL (YouTube, Vimeo, etc.)",
                            lines=1
                        )
                        single_btn = gr.Button("📥 Download", variant="primary", size="lg")

                    with gr.Group(visible=False) as category_mode:
                        category_input = gr.Textbox(
                            label="Category URL (optional)",
                            placeholder="Leave empty for default Jeunesse category",
                            lines=1
                        )
                        category_btn = gr.Button("📥 Download All", variant="primary", size="lg")

                    status_output = gr.Textbox(label="Status", lines=2, interactive=False)

                    gr.Markdown("## 📋 Download Logs")
                    logs_output = gr.Textbox(
                        label="Logs",
                        lines=15,
                        max_lines=20,
                        interactive=False,
                        show_copy_button=True
                    )

                    clear_logs_btn = gr.Button("🗑️ Clear Logs", size="sm")

                # Browse Tab
                with gr.Tab("📂 Browse"):
                    gr.Markdown("## Downloaded Audiobooks")

                    with gr.Row():
                        search_input = gr.Textbox(
                            label="🔍 Search",
                            placeholder="Search by filename...",
                            scale=3
                        )
                        refresh_btn = gr.Button("🔄 Refresh", scale=1)

                    file_count_display = gr.Markdown("No files found")

                    # File selection and preview
                    with gr.Group():
                        file_dropdown = gr.Dropdown(
                            label="Select a file to preview",
                            choices=[],
                            interactive=True
                        )

                        with gr.Row(visible=False) as file_preview:
                            with gr.Column():
                                file_info = gr.Markdown("Select a file to view details")
                                audio_player = gr.Audio(
                                    label="Audio Player",
                                    type="filepath",
                                    interactive=False
                                )

                            with gr.Column():
                                download_file_btn = gr.File(
                                    label="Download File",
                                    interactive=False
                                )
                                delete_file_btn = gr.Button("🗑️ Delete This File", variant="stop")

                    file_action_status = gr.Textbox(label="Action Status", lines=2, interactive=False)

                    # Bulk operations
                    gr.Markdown("### Bulk Operations")
                    with gr.Row():
                        bulk_zip_btn = gr.Button("📦 Download All as ZIP", variant="primary")
                        bulk_delete_btn = gr.Button("🗑️ Delete All Files", variant="stop")

                # About Tab
                with gr.Tab("ℹ️ About"):
                    gr.Markdown("""
## 🎧 OHdio Audiobook Downloader

### Features

- **Web Scraping**: Automatically discovers audiobooks from OHdio categories
- **High-Quality Downloads**: Uses yt-dlp to download audio as MP3 files
- **Universal URL Support**: Download from OHdio or any yt-dlp supported site
- **Metadata Embedding**: Automatically embeds book metadata (title, author, artwork)
- **Smart Caching**: Skips files that already exist
- **File Browser**: Browse, search, and manage audiobooks
- **Bulk Operations**: Download multiple files as ZIP or delete in bulk

### How to Use

#### Download Single Audiobook
1. Go to **Download** tab
2. Select "Single Audiobook" mode
3. Paste an OHdio URL or any yt-dlp supported URL
4. Click "Download"

#### Download Category
1. Go to **Download** tab
2. Select "Entire Category" mode
3. (Optional) Enter a custom category URL
4. Click "Download All"

#### Browse Files
1. Go to **Browse** tab
2. Use search box to filter audiobooks
3. Select files using checkboxes
4. Use bulk actions to download or delete

### Legal Notice

This tool is for **educational purposes only**. Please respect copyright laws
and Radio-Canada's terms of service. Only download content you have the right to access.

### Resources

- [GitHub Repository](https://github.com/yourusername/ohdio-audiobook-downloader)
- [Report Issues](https://github.com/yourusername/ohdio-audiobook-downloader/issues)
""")

        with gr.Column(scale=1):
            stats_display = gr.Markdown(get_stats())
            gr.Markdown("---")
            gr.Markdown("For educational purposes only. Respect copyright laws.")

    # Event handlers
    def toggle_download_mode(mode):
        return {
            single_mode: gr.update(visible=(mode == "Single Audiobook")),
            category_mode: gr.update(visible=(mode == "Entire Category"))
        }

    download_mode.change(
        toggle_download_mode,
        inputs=[download_mode],
        outputs=[single_mode, category_mode]
    )

    single_btn.click(
        start_download_single,
        inputs=[url_input],
        outputs=[status_output]
    )

    category_btn.click(
        start_download_category,
        inputs=[category_input],
        outputs=[status_output]
    )

    clear_logs_btn.click(
        lambda: "",
        outputs=[logs_output]
    )

    def update_file_list(search=""):
        """Update file list based on search."""
        files = get_downloaded_files()

        if search:
            files = [f for f in files if search.lower() in f.stem.lower()]

        if not files:
            search_msg = f'matching "{search}"' if search else ''
            return (
                f"**No files found** {search_msg}",
                gr.update(choices=[], value=None)
            )

        file_count = f"**Showing {len(files)} audiobook(s)**"
        file_choices = [(f"{f.stem} ({format_file_size(f.stat().st_size)})", str(f)) for f in files]

        return file_count, gr.update(choices=file_choices, value=None)

    def show_file_preview(file_path_str):
        """Show preview of selected file."""
        if not file_path_str:
            return (
                gr.update(visible=False),
                "Select a file to view details",
                None,
                None
            )

        file_path = Path(file_path_str)
        if not file_path.exists():
            return (
                gr.update(visible=False),
                "❌ File not found",
                None,
                None
            )

        info = f"""
### 🎵 {file_path.stem}

**Filename:** `{file_path.name}`
**Size:** {format_file_size(file_path.stat().st_size)}
**Modified:** {format_datetime(file_path.stat().st_mtime)}
"""

        return (
            gr.update(visible=True),
            info,
            str(file_path),
            str(file_path)
        )

    def delete_selected_file(file_path_str):
        """Delete the selected file."""
        if not file_path_str:
            return "⚠️ No file selected", None, None, None

        result = delete_file(file_path_str)

        # Refresh file list after deletion
        files = get_downloaded_files()
        file_count = f"**Showing {len(files)} audiobook(s)**"
        file_choices = [(f"{f.stem} ({format_file_size(f.stat().st_size)})", str(f)) for f in files]

        return (
            result,
            file_count,
            gr.update(choices=file_choices, value=None),
            gr.update(visible=False)
        )

    def bulk_download_all():
        """Create ZIP of all files."""
        files = get_downloaded_files()
        if not files:
            return None, "⚠️ No files to download"

        zip_path = create_bulk_zip([str(f) for f in files])
        if zip_path:
            return zip_path, f"✅ Created ZIP with {len(files)} file(s)"
        return None, "❌ Failed to create ZIP"

    def bulk_delete_all():
        """Delete all files."""
        files = get_downloaded_files()
        if not files:
            return "⚠️ No files to delete", "**No files found**", gr.update(choices=[])

        result = bulk_delete_files([str(f) for f in files])

        # Refresh list
        files = get_downloaded_files()
        file_count = f"**Showing {len(files)} audiobook(s)**" if files else "**No files found**"
        file_choices = [(f"{f.stem} ({format_file_size(f.stat().st_size)})", str(f)) for f in files]

        return result, file_count, gr.update(choices=file_choices, value=None)

    # Wire up file browser events
    search_input.change(
        update_file_list,
        inputs=[search_input],
        outputs=[file_count_display, file_dropdown]
    )

    refresh_btn.click(
        update_file_list,
        inputs=[search_input],
        outputs=[file_count_display, file_dropdown]
    )

    file_dropdown.change(
        show_file_preview,
        inputs=[file_dropdown],
        outputs=[file_preview, file_info, audio_player, download_file_btn]
    )

    delete_file_btn.click(
        delete_selected_file,
        inputs=[file_dropdown],
        outputs=[file_action_status, file_count_display, file_dropdown, file_preview]
    )

    bulk_zip_btn.click(
        bulk_download_all,
        outputs=[download_file_btn, file_action_status]
    )

    bulk_delete_btn.click(
        bulk_delete_all,
        outputs=[file_action_status, file_count_display, file_dropdown]
    )

    # Auto-update logs and stats during download
    def poll_download_status(current_logs_value):
        """Poll download status and update UI."""
        status, logs, in_progress = check_download_status()
        stats = get_stats()

        # Append new logs instead of replacing
        if logs:
            current_logs = current_logs_value or ""
            new_logs = current_logs + "\n" + logs if current_logs else logs
            return new_logs, status, stats
        return current_logs_value or "", status, stats

    # Create a timer that polls for logs every second
    timer = gr.Timer(value=1.0, active=True)

    timer.tick(
        poll_download_status,
        inputs=[logs_output],
        outputs=[logs_output, status_output, stats_display]
    )

    # Initialize file browser on load
    app.load(
        update_file_list,
        inputs=[search_input],
        outputs=[file_count_display, file_dropdown]
    )


if __name__ == "__main__":
    app.queue()
    app.launch(
        server_name="0.0.0.0",
        server_port=7860,
        share=False
    )
