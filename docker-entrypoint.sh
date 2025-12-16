#!/bin/bash
set -e

# Update yt-dlp on startup and start background updater
if [ -x /usr/local/bin/yt-dlp-updater.sh ]; then
    echo "Updating yt-dlp..."
    /usr/local/bin/yt-dlp-updater.sh
    # Start background daemon for daily updates
    nohup /usr/local/bin/yt-dlp-updater.sh --daemon > /config/logs/yt-dlp-updater.log 2>&1 &
fi

# linuxserver.io style PUID/PGID support
# Default to 1000:1000 if not set
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Starting OHdio with UID: $PUID, GID: $PGID"

# Create group if it doesn't exist
if ! getent group ohdio > /dev/null 2>&1; then
    groupadd -g "$PGID" ohdio
else
    # Update existing group
    groupmod -o -g "$PGID" ohdio
fi

# Create user if it doesn't exist
if ! getent passwd ohdio > /dev/null 2>&1; then
    useradd -u "$PUID" -g "$PGID" -s /bin/bash -m ohdio
else
    # Update existing user
    usermod -o -u "$PUID" -g "$PGID" ohdio
fi

# Create /config directory structure if it doesn't exist
mkdir -p /config/db /config/logs /config/downloads

# Fix permissions on /config directory
chown -R ohdio:ohdio /config /app

# Execute command as ohdio user
exec gosu ohdio "$@"
