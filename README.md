# OHdio Audiobook Downloader

A locally-running Phoenix/Elixir web application for creating personal backups of audiobooks from the OHdio platform for offline listening only. **Not intended for redistribution of any files.**

This is a self-hosted application that runs entirely on your own machine - it is not a cloud service or hosted platform.

![Phoenix](https://img.shields.io/badge/Phoenix-1.8-orange)
![Elixir](https://img.shields.io/badge/Elixir-1.17-purple)
![License](https://img.shields.io/badge/license-MIT-blue)

## Quick Start

### Using Docker (Recommended)

The easiest way to run OHdio is with Docker Compose:

```bash
# Start the application
./dc up -d

# View logs
./dc logs -f

# Stop the application
./dc down
```

The web interface will be available at `http://localhost:4000`

### Local Development

**Prerequisites:**
- Elixir 1.17+
- Erlang/OTP 27+
- Node.js 18+ (for asset compilation)

**Setup:**

```bash
# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.create
mix ecto.migrate

# Install JavaScript dependencies and build assets
cd assets && npm install && cd ..
mix assets.build

# Start the Phoenix server
mix phx.server
```

Visit `http://localhost:4000` to access the application.

## Using the Application

### Downloading Audiobooks

1. **Single Audiobook**: Paste an OHdio audiobook URL in the input field and click "Add to Queue"
2. **Category Scrape**: Paste a category URL to discover and queue all audiobooks in that category
3. **Monitor Progress**: Watch downloads process in real-time on the Home page

### Supported URL Types

- **Audiobook URLs**: `https://ici.radio-canada.ca/ohdio/livres-audio/[id]/[title]`
- **Category URLs**: `https://ici.radio-canada.ca/ohdio/categories/[id]/[name]`

### Library Browser

- Browse your downloaded audiobooks
- Search by title or author
- Play audiobooks directly in the browser
- View cover art and metadata
- Toggle between card and list views

## Docker Helper Script

The `./dc` script simplifies Docker operations:

```bash
# Docker Compose commands
./dc up -d              # Start services in background
./dc down               # Stop and remove containers
./dc logs -f            # Follow logs
./dc ps                 # List containers

# Run commands inside the Phoenix container
./dc mix test           # Run tests
./dc mix ecto.migrate   # Run migrations
./dc iex -S mix         # Start IEx console
./dc bash               # Open bash shell
```

## Development

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/ohdio/scraper/audiobook_scraper_test.exs

# Run with coverage
mix test --cover
```

### Code Quality

```bash
# Run formatter, credo, and tests
mix precommit

# Format code
mix format

# Run static analysis
mix credo
```

### Database Management

```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Rollback migration
mix ecto.rollback

# Reset database (drop, create, migrate)
mix ecto.reset

# Generate migration
mix ecto.gen.migration add_field_to_table
```

### Helper Scripts

The project includes several helper scripts in the `scripts/` directory for debugging and management:

- `check_job_errors.exs` - Check for failed Oban jobs
- `check_queue_state.exs` - View current queue state
- `enqueue_missing_downloads.exs` - Re-queue items that weren't processed
- `reset_download_queue.exs` - Reset all queue items to queued state
- `retry_failed_downloads.exs` - Retry failed downloads
- `find_bad_urls.exs` - Find and report invalid URLs in the queue

Run scripts with: `./dc mix run scripts/<script_name.exs>`

## Architecture

### Tech Stack

- **Phoenix Framework**: Web framework and LiveView for real-time UI
- **Elixir**: Functional programming language for concurrent operations
- **Ecto**: Database wrapper and query generator
- **SQLite**: Embedded database for easy deployment
- **Oban**: Reliable background job processing
- **Req**: Modern HTTP client for scraping
- **Floki**: HTML parsing for web scraping
- **daisyUI**: Beautiful Tailwind CSS components

### Project Structure

```
lib/
├── ohdio/
│   ├── application.ex          # Application supervisor
│   ├── repo.ex                 # Ecto repository
│   ├── library/                # Library context (Audiobooks)
│   ├── downloads/              # Downloads context (Queue)
│   ├── scraper/                # Web scraping logic
│   └── workers/                # Oban background workers
├── ohdio_web/
│   ├── controllers/            # Phoenix controllers
│   ├── live/                   # LiveView modules
│   ├── components/             # Reusable components
│   └── router.ex               # Route definitions
priv/
├── repo/migrations/            # Database migrations
└── static/                     # Static assets
test/                           # Test files
```

## Configuration

Configuration files are in `config/`:

- `config.exs` - Base configuration
- `dev.exs` - Development environment
- `test.exs` - Test environment
- `runtime.exs` - Runtime configuration

Key configuration options:

```elixir
# Database
config :ohdio, Ohdio.Repo,
  database: "ohdio_dev.db",
  pool_size: 5

# Oban (background jobs)
config :ohdio, Oban,
  engine: Oban.Engines.Lite,
  queues: [default: 10, downloads: 1, scraping: 2]

# Phoenix Endpoint
config :ohdio, OhdioWeb.Endpoint,
  http: [port: 4000],
  secret_key_base: "..."
```

## Deployment

### Docker Compose (linuxserver.io conventions)

OHdio follows [linuxserver.io](https://www.linuxserver.io/) conventions for better portability and easier backups. All persistent data is stored in a single `/config` directory with PUID/PGID support for proper file permissions.

#### Development Setup

The included `compose.yml` is configured for development with hot-reloading:

```bash
# Start development environment
./dc up -d

# Access at http://localhost:4001
```

All persistent data is stored in `./config/` in your project directory:
- `./config/db/` - SQLite database
- `./config/downloads/` - Downloaded audiobooks
- `./config/logs/` - Application logs

#### Production Deployment

For production, use `compose.prod.yml` as a template:

```bash
# 1. Copy and customize the production compose file
cp compose.prod.yml docker-compose.yml

# 2. Edit the file and set:
#    - Your domain in PHX_HOST
#    - SECRET_KEY_BASE (generate with: mix phx.gen.secret)
#    - PUID/PGID to match your host user (run: id)
#    - Volume path (e.g., /opt/ohdio/config:/config)

# 3. Start the service
docker compose up -d
```

**Important Production Settings:**

1. **Data Directory**: Change the bind mount to your preferred location:
   ```yaml
   volumes:
     - /opt/ohdio/config:/config  # Host path : Container path
   ```

2. **User Permissions**: Set PUID/PGID to match your host user:
   ```bash
   # Find your user/group ID
   id
   # Output: uid=1000(username) gid=1000(username)

   # Set in compose file
   environment:
     - PUID=1000
     - PGID=1000
   ```

3. **Secret Key**: Generate and set a secure secret:
   ```bash
   docker run --rm hexpm/elixir:1.17.3-erlang-27.1.2-debian-bookworm-20241016-slim \
     mix phx.gen.secret
   ```

### Environment Variables

#### Required
- `SECRET_KEY_BASE` - Phoenix secret key (generate with `mix phx.gen.secret`)
- `PHX_HOST` - Your domain name (e.g., audiobooks.example.com)

#### User Permissions (linuxserver.io convention)
- `PUID` - User ID for file ownership (default: 1000)
- `PGID` - Group ID for file ownership (default: 1000)

#### Application Settings
- `MIX_ENV` - Application environment (dev/prod)
- `PORT` - HTTP port (default: 4000)
- `DATABASE_PATH` - SQLite database path (default: /config/db/ohdio_prod.db)
- `STORAGE_PATH` - Download storage path (default: /config/downloads)
- `LOG_PATH` - Application logs path (default: /config/logs)

#### Optional
- `POOL_SIZE` - Database connection pool size (default: 10)
- `MAX_CONCURRENT_DOWNLOADS` - Concurrent downloads (default: 3)
- `MIN_DISK_SPACE_MB` - Minimum free disk space (default: 1000)

### Backup and Migration

With the linuxserver.io structure, backing up is simple:

```bash
# Backup all data
tar -czf ohdio-backup.tar.gz /opt/ohdio/config/

# Restore
tar -xzf ohdio-backup.tar.gz -C /

# Or migrate to new host
rsync -av /opt/ohdio/config/ newhost:/opt/ohdio/config/
```

## ⚠️ Important Notes

### Legal Notice

This tool is intended for personal backup purposes only to enable offline listening of content you have the right to access. **Do not redistribute any downloaded files.** Please respect copyright laws and terms of service.

## Contributing

Contributions are welcome! Please see the [Development Guide](docs/DEVELOPMENT_GUIDE.md) for details.

## Task Management

This project uses [Backlog.md](https://github.com/crazywolf132/backlog.md) for task management. View tasks in `backlog/tasks/`.

## License

MIT License - see LICENSE file for details

## Archive

The original Python implementation has been archived in `archive/python_original/`. See that directory for the legacy codebase.
