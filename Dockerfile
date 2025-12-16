# Phoenix Development Dockerfile for OHdio
# Based on Elixir 1.17 with Erlang/OTP 27

FROM hexpm/elixir:1.17.3-erlang-27.1.2-debian-bookworm-20241016-slim

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential \
    git \
    curl \
    # Node.js for Phoenix assets (via NodeSource)
    ca-certificates \
    gnupg \
    # SQLite3
    sqlite3 \
    libsqlite3-dev \
    # FFmpeg for audio processing
    ffmpeg \
    # yt-dlp dependencies
    python3 \
    python3-pip \
    # inotify-tools for Phoenix live reload
    inotify-tools \
    # gosu for user switching (linuxserver.io convention)
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install yt-dlp (latest binary from GitHub) and spotdl for Spotify support
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp \
    && chmod a+rx /usr/local/bin/yt-dlp \
    && pip3 install --no-cache-dir --break-system-packages spotdl

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install Phoenix
RUN mix archive.install hex phx_new --force

# Create app directory
WORKDIR /app

# Create directories for config (linuxserver.io convention)
# User/group and permissions will be set by entrypoint
RUN mkdir -p /app /config/db /config/logs /config/downloads

# Copy entrypoint and utility scripts
COPY docker-entrypoint.sh yt-dlp-updater.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/yt-dlp-updater.sh

# Set environment variables
ENV MIX_ENV=dev \
    ERL_AFLAGS="-kernel shell_history enabled" \
    LANG=C.UTF-8 \
    TERM=xterm \
    PUID=1000 \
    PGID=1000

# Expose Phoenix port
EXPOSE 4000

# Use entrypoint for PUID/PGID support
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command (will be overridden by docker-compose)
CMD ["mix", "phx.server"]
