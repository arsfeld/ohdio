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
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install yt-dlp
RUN pip3 install --no-cache-dir --break-system-packages yt-dlp

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install Phoenix
RUN mix archive.install hex phx_new --force

# Create app directory
WORKDIR /app

# Create non-root user for development
RUN useradd -m -u 1000 -s /bin/bash dev && \
    mkdir -p /app /data/downloads /data/logs /data/db && \
    chown -R dev:dev /app /data

# Switch to dev user
USER dev

# Set environment variables
ENV MIX_ENV=dev \
    ERL_AFLAGS="-kernel shell_history enabled" \
    LANG=C.UTF-8 \
    TERM=xterm

# Expose Phoenix port
EXPOSE 4000

# Default command (will be overridden by docker-compose)
CMD ["mix", "phx.server"]
