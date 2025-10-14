defmodule Ohdio.Scraper.RateLimiter do
  @moduledoc """
  Rate limiter for HTTP requests to respect server resources.

  Uses ETS to track request timestamps per host and enforces
  minimum delays between requests to the same host.
  """

  use GenServer
  require Logger

  @table_name :rate_limiter_timestamps
  @default_min_delay_ms 1000

  # Client API

  @doc """
  Start the rate limiter GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Wait if necessary before making a request to the given host.

  Returns immediately if enough time has passed since the last request,
  or sleeps until the minimum delay has elapsed.

  ## Parameters
    * `host` - The hostname to rate limit
    * `min_delay_ms` - Minimum milliseconds between requests (default: 1000)

  ## Examples

      iex> RateLimiter.wait_if_needed("ici.radio-canada.ca")
      :ok

      iex> RateLimiter.wait_if_needed("example.com", 2000)
      :ok
  """
  @spec wait_if_needed(String.t(), non_neg_integer()) :: :ok
  def wait_if_needed(host, min_delay_ms \\ @default_min_delay_ms) do
    # Use longer timeout to handle queued concurrent requests
    # With 2s delay and multiple workers, we need more than default 5s
    GenServer.call(__MODULE__, {:wait_if_needed, host, min_delay_ms}, 60_000)
  end

  @doc """
  Reset rate limiting for a specific host (useful for testing).
  """
  @spec reset(String.t()) :: :ok
  def reset(host) do
    GenServer.call(__MODULE__, {:reset, host})
  end

  @doc """
  Reset all rate limiting data (useful for testing).
  """
  @spec reset_all() :: :ok
  def reset_all do
    GenServer.call(__MODULE__, :reset_all)
  end

  # Server Callbacks

  @impl GenServer
  def init(_opts) do
    # Create ETS table to store timestamps
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  @impl GenServer
  def handle_call({:wait_if_needed, host, min_delay_ms}, _from, state) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table_name, host) do
      [{^host, last_request_time}] ->
        elapsed = now - last_request_time
        remaining = min_delay_ms - elapsed

        if remaining > 0 do
          Logger.debug("Rate limiting #{host}: waiting #{remaining}ms")
          Process.sleep(remaining)
        end

      [] ->
        # First request to this host
        :ok
    end

    # Update timestamp
    :ets.insert(@table_name, {host, System.monotonic_time(:millisecond)})

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:reset, host}, _from, state) do
    :ets.delete(@table_name, host)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:reset_all, _from, state) do
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, state}
  end
end
