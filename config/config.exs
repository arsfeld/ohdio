# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ohdio,
  ecto_repos: [Ohdio.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :ohdio, OhdioWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: OhdioWeb.ErrorHTML, json: OhdioWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Ohdio.PubSub,
  live_view: [signing_salt: "+XIPHzgE"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  ohdio: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  ohdio: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Oban for SQLite
# Get max concurrent downloads from env or use default
max_concurrent_downloads = String.to_integer(System.get_env("MAX_CONCURRENT_DOWNLOADS") || "3")

config :ohdio, Oban,
  repo: Ohdio.Repo,
  engine: Oban.Engines.Lite,
  notifier: Oban.Notifiers.PG,
  plugins: [Oban.Plugins.Pruner],
  queues: [
    default: 10,
    scraping: 5,
    metadata: 10,
    downloads: max_concurrent_downloads
  ]

# Download configuration
config :ohdio, :downloads,
  # Directory where audiobooks are downloaded
  output_dir: System.get_env("DOWNLOAD_DIR") || "priv/static/downloads",
  # Maximum concurrent downloads (controls Oban queue concurrency)
  max_concurrent: String.to_integer(System.get_env("MAX_CONCURRENT_DOWNLOADS") || "3"),
  # Minimum free disk space required (in MB)
  min_disk_space_mb: String.to_integer(System.get_env("MIN_DISK_SPACE_MB") || "100"),
  # Maximum file size for downloads (in MB, 0 = unlimited)
  max_file_size_mb: String.to_integer(System.get_env("MAX_FILE_SIZE_MB") || "0")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
