#!/bin/bash
# yt-dlp auto-updater - runs in background and updates daily
# This ensures YouTube downloads keep working as YouTube changes their API

UPDATE_INTERVAL=${YT_DLP_UPDATE_INTERVAL:-86400}  # Default: 24 hours in seconds
YT_DLP_PATH="/usr/local/bin/yt-dlp"

update_ytdlp() {
    echo "[yt-dlp-updater] Checking for updates..."

    # Get current version
    CURRENT_VERSION=$($YT_DLP_PATH --version 2>/dev/null || echo "none")

    # Download latest
    if curl -sL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /tmp/yt-dlp.new; then
        chmod a+rx /tmp/yt-dlp.new
        NEW_VERSION=$(/tmp/yt-dlp.new --version 2>/dev/null || echo "failed")

        if [ "$NEW_VERSION" != "failed" ] && [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
            mv /tmp/yt-dlp.new $YT_DLP_PATH
            echo "[yt-dlp-updater] Updated yt-dlp: $CURRENT_VERSION -> $NEW_VERSION"
        else
            rm -f /tmp/yt-dlp.new
            echo "[yt-dlp-updater] yt-dlp is up to date ($CURRENT_VERSION)"
        fi
    else
        echo "[yt-dlp-updater] Failed to download update"
    fi
}

# Run initial update
update_ytdlp

# If running in daemon mode, loop forever
if [ "$1" = "--daemon" ]; then
    echo "[yt-dlp-updater] Starting daemon mode (update interval: ${UPDATE_INTERVAL}s)"
    while true; do
        sleep $UPDATE_INTERVAL
        update_ytdlp
    done
fi
