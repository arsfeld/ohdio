defmodule Ohdio.Scraper.HttpClient do
  @moduledoc """
  HTTP client with retry logic and exponential backoff for scraping operations.

  Uses Req library for HTTP requests with configured retry strategies.
  """

  require Logger
  alias Ohdio.Scraper.RateLimiter

  @default_headers %{
    "user-agent" =>
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "accept-language" => "fr-CA,fr;q=0.9,en;q=0.8",
    "accept-encoding" => "gzip, deflate",
    "connection" => "keep-alive"
  }

  @type http_error ::
          :timeout
          | :server_error
          | :not_found
          | :client_error
          | :network_error

  @doc """
  Make an HTTP GET request with retry logic.

  ## Options
    * `:max_retries` - Maximum number of retry attempts (default: 3)
    * `:base_delay` - Base delay in milliseconds for exponential backoff (default: 1000)
    * `:timeout` - Request timeout in milliseconds (default: 30000)
    * `:headers` - Additional headers to merge with defaults (default: %{})

  ## Returns
    * `{:ok, body}` - Successful response with HTML body
    * `{:error, reason}` - Failed after all retries

  ## Examples

      iex> HttpClient.get("https://example.com")
      {:ok, "<html>...</html>"}

      iex> HttpClient.get("https://example.com/not-found")
      {:error, :not_found}
  """
  @spec get(String.t(), keyword()) :: {:ok, String.t()} | {:error, http_error()}
  def get(url, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    base_delay = Keyword.get(opts, :base_delay, 1000)
    timeout = Keyword.get(opts, :timeout, 30_000)
    custom_headers = Keyword.get(opts, :headers, %{})

    headers = Map.merge(@default_headers, custom_headers)

    request_opts = [
      url: url,
      headers: headers,
      receive_timeout: timeout,
      retry: :transient,
      max_retries: max_retries,
      retry_delay: fn attempt -> (base_delay * :math.pow(2, attempt - 1)) |> trunc() end,
      retry_log_level: :warning
    ]

    Logger.debug("Fetching URL: #{url}")

    # Apply rate limiting for OHdio domains
    apply_rate_limiting(url)

    start_time = System.monotonic_time(:millisecond)

    case Req.get(request_opts) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        duration = System.monotonic_time(:millisecond) - start_time
        Logger.debug("Successfully fetched #{url} in #{duration}ms")
        {:ok, body}

      {:ok, %Req.Response{status: 404}} ->
        Logger.error("Resource not found: #{url}")
        {:error, :not_found}

      {:ok, %Req.Response{status: 429}} ->
        Logger.error("Rate limited for #{url}")
        {:error, :rate_limited}

      {:ok, %Req.Response{status: status}} when status >= 500 ->
        Logger.error("Server error #{status} for #{url}")
        {:error, :server_error}

      {:ok, %Req.Response{status: status}} when status >= 400 ->
        Logger.error("Client error #{status} for #{url}")
        {:error, :client_error}

      {:error, %Req.TransportError{reason: :timeout}} ->
        Logger.error("Request timeout for #{url}")
        {:error, :timeout}

      {:error, reason} ->
        Logger.error("Network error for #{url}: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  @doc """
  Make a POST request with retry logic.

  ## Options
  Same as `get/2`, plus:
    * `:json` - JSON body to send (will be encoded automatically)
    * `:params` - URL parameters to send

  ## Examples

      iex> HttpClient.post("https://api.example.com/endpoint", json: %{key: "value"})
      {:ok, "response"}
  """
  @spec post(String.t(), keyword()) :: {:ok, String.t()} | {:error, http_error()}
  def post(url, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    base_delay = Keyword.get(opts, :base_delay, 1000)
    timeout = Keyword.get(opts, :timeout, 30_000)
    custom_headers = Keyword.get(opts, :headers, %{})
    json_body = Keyword.get(opts, :json)
    params = Keyword.get(opts, :params)

    headers = Map.merge(@default_headers, custom_headers)

    request_opts =
      [
        url: url,
        headers: headers,
        receive_timeout: timeout,
        retry: :transient,
        max_retries: max_retries,
        retry_delay: fn attempt -> (base_delay * :math.pow(2, attempt - 1)) |> trunc() end,
        retry_log_level: :warning
      ]
      |> maybe_add_json(json_body)
      |> maybe_add_params(params)

    Logger.debug("POSTing to URL: #{url}")

    case Req.post(request_opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        Logger.debug("Successfully posted to #{url}")
        {:ok, body}

      {:ok, %Req.Response{status: 404}} ->
        Logger.error("Resource not found: #{url}")
        {:error, :not_found}

      {:ok, %Req.Response{status: status}} when status >= 500 ->
        Logger.error("Server error #{status} for #{url}")
        {:error, :server_error}

      {:ok, %Req.Response{status: status}} when status >= 400 ->
        Logger.error("Client error #{status} for #{url}")
        {:error, :client_error}

      {:error, %Req.TransportError{reason: :timeout}} ->
        Logger.error("Request timeout for #{url}")
        {:error, :timeout}

      {:error, reason} ->
        Logger.error("Network error for #{url}: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  defp maybe_add_json(opts, nil), do: opts
  defp maybe_add_json(opts, json), do: Keyword.put(opts, :json, json)

  defp maybe_add_params(opts, nil), do: opts
  defp maybe_add_params(opts, params), do: Keyword.put(opts, :params, params)

  defp apply_rate_limiting(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) ->
        # Apply stricter rate limiting for OHdio domains
        min_delay =
          if String.contains?(host, "radio-canada.ca") or String.contains?(host, "ohdio") do
            # 2 seconds between requests to OHdio servers
            2000
          else
            # 1 second for other domains
            1000
          end

        RateLimiter.wait_if_needed(host, min_delay)

      _ ->
        # Unable to parse host, skip rate limiting
        :ok
    end
  end
end
