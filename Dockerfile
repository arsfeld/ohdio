# Multi-stage Dockerfile for OHdio Audiobook Downloader
# Optimized for size and security

FROM python:3.11-slim as builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install uv for faster dependency installation
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Set working directory
WORKDIR /app

# Copy dependency files
COPY pyproject.toml ./
COPY README.md ./

# Install Python dependencies
RUN uv pip install --system --no-cache -e .

# Final stage
FROM python:3.11-slim

# Install runtime dependencies (ffmpeg is required by yt-dlp)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd -m -u 1000 ohdio && \
    mkdir -p /app /data/downloads /data/logs && \
    chown -R ohdio:ohdio /app /data

# Set working directory
WORKDIR /app

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY --chown=ohdio:ohdio . .

# Create Docker-specific config (overwrites repo config.json)
RUN echo '{ \
    "output_directory": "/data/downloads", \
    "max_concurrent_downloads": 3, \
    "retry_attempts": 3, \
    "delay_between_requests": 1.0, \
    "audio_quality": "best", \
    "embed_metadata": true, \
    "skip_existing": true, \
    "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
}' > config.json

# Switch to non-root user
USER ohdio

# Expose Gradio port
EXPOSE 7860

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:7860/ || exit 1

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    GRADIO_SERVER_PORT=7860 \
    GRADIO_SERVER_NAME=0.0.0.0

# Run Gradio app
CMD ["python", "app.py"]
