defmodule Ohdio.Scraper.PlaylistExtractor do
  @moduledoc """
  Extracts m3u8 playlist URLs from OHdio audiobook pages.

  This module:
  1. Extracts the mediaId from the page HTML using multiple strategies
  2. Calls Radio-Canada's media validation API to get the actual playlist URL
  """

  require Logger
  alias Ohdio.Scraper.HttpClient

  @api_base_url "https://services.radio-canada.ca/media/validation/v2/"

  @doc """
  Extract the m3u8 playlist URL from an audiobook page's HTML content.

  ## Parameters
    * `html_content` - The HTML content of the audiobook page
    * `url` - The URL of the page (for logging purposes)

  ## Returns
    * `{:ok, playlist_url}` - Successfully extracted the m3u8 URL
    * `{:error, reason}` - Failed to extract the playlist URL

  ## Examples

      iex> PlaylistExtractor.extract_playlist_url(html, "https://...")
      {:ok, "https://...master.m3u8"}
  """
  @spec extract_playlist_url(String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def extract_playlist_url(html_content, url) do
    Logger.info("Extracting playlist URL from: #{url}")

    with {:ok, media_id} <- extract_media_id(html_content, url),
         {:ok, playlist_url} <- get_playlist_from_api(media_id) do
      # Ensure we're returning a string, not a map
      unless is_binary(playlist_url) do
        Logger.error(
          "Expected string URL but got: #{inspect(playlist_url, pretty: true, limit: :infinity)}"
        )

        {:error, :invalid_playlist_url}
      else
        Logger.info("Successfully extracted playlist URL: #{playlist_url}")
        {:ok, playlist_url}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to extract playlist URL from #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Extract the mediaId from the HTML content using multiple strategies.

  Tries the following strategies in order:
  1. Regex patterns for mediaId in JSON data
  2. HTML data attributes
  3. Numeric IDs in script tags

  ## Examples

      iex> extract_media_id(html, url)
      {:ok, "12345678"}
  """
  @spec extract_media_id(String.t(), String.t()) ::
          {:ok, String.t()} | {:error, :media_id_not_found}
  def extract_media_id(html_content, url) do
    Logger.debug("Extracting media ID from #{url}")

    # Try regex patterns first
    media_id_patterns = [
      ~r/"mediaId"\s*:\s*"([^"]+)"/,
      ~r/"mediaId"\s*:\s*(\d+)/,
      ~r/mediaId["']?\s*:\s*["']?([^",\s}]+)/,
      ~r/media-id["']?\s*:\s*["']?([^",\s}]+)/
    ]

    case try_regex_patterns(html_content, media_id_patterns) do
      {:ok, media_id} ->
        Logger.debug("Found media ID using regex pattern: #{media_id}")
        {:ok, media_id}

      :not_found ->
        # Try parsing HTML for data attributes
        case try_html_data_attributes(html_content) do
          {:ok, media_id} ->
            Logger.debug("Found media ID in HTML data attribute: #{media_id}")
            {:ok, media_id}

          :not_found ->
            # Try finding numeric IDs in script tags
            case try_script_numeric_ids(html_content) do
              {:ok, media_id} ->
                Logger.debug("Found potential media ID in script: #{media_id}")
                {:ok, media_id}

              :not_found ->
                Logger.warning("Could not extract media ID from #{url}")
                {:error, :media_id_not_found}
            end
        end
    end
  end

  @doc """
  Get the m3u8 playlist URL from Radio-Canada's media validation API.

  ## Examples

      iex> get_playlist_from_api("12345678")
      {:ok, "https://...master.m3u8"}
  """
  @spec get_playlist_from_api(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def get_playlist_from_api(media_id) do
    params = %{
      "appCode" => "medianet",
      "connectionType" => "hd",
      "deviceType" => "ipad",
      "idMedia" => media_id,
      "multibitrate" => "true",
      "output" => "json",
      "tech" => "hls",
      "manifestVersion" => "2"
    }

    query_string = URI.encode_query(params)
    api_url = "#{@api_base_url}?#{query_string}"

    Logger.debug("Calling Radio-Canada API for media ID: #{media_id}")

    case HttpClient.get(api_url) do
      {:ok, body} ->
        # Req automatically decodes JSON responses, so body might be a map or string
        data =
          cond do
            is_map(body) ->
              # Already decoded by Req
              body

            is_binary(body) ->
              # Need to decode JSON string
              case Jason.decode(body) do
                {:ok, decoded} ->
                  decoded

                {:error, _} ->
                  Logger.error("Failed to parse API response JSON for media ID: #{media_id}")
                  {:error, :json_parse_error}
              end

            true ->
              Logger.error("Unexpected body type: #{inspect(body)}")
              {:error, :unexpected_response}
          end

        case data do
          {:error, reason} ->
            {:error, reason}

          _ ->
            Logger.debug("API response data: #{inspect(data, pretty: true, limit: 500)}")
            result = find_m3u8_url(data, media_id)
            Logger.debug("find_m3u8_url returned: #{inspect(result)}")
            result
        end

      {:error, reason} ->
        Logger.error("API request failed for media ID #{media_id}: #{inspect(reason)}")
        {:error, :api_request_failed}
    end
  end

  # Private functions

  defp try_regex_patterns(html_content, patterns) do
    Enum.find_value(patterns, :not_found, fn pattern ->
      case Regex.run(pattern, html_content) do
        [_, media_id] ->
          media_id = String.trim(media_id, ~s("'))
          {:ok, media_id}

        nil ->
          nil
      end
    end)
  end

  defp try_html_data_attributes(html_content) do
    selectors = [
      "[data-media-id]",
      "[data-mediaid]",
      "[data-id]",
      ".media-player[data-id]",
      ".audio-player[data-id]",
      ".listen-button[data-id]",
      ".play-button[data-id]"
    ]

    case Floki.parse_document(html_content) do
      {:ok, document} ->
        Enum.find_value(selectors, :not_found, fn selector ->
          case Floki.find(document, selector) do
            [] ->
              nil

            elements ->
              Enum.find_value(elements, fn element ->
                Enum.find_value(["data-media-id", "data-mediaid", "data-id"], fn attr ->
                  case Floki.attribute(element, attr) do
                    [value] when is_binary(value) ->
                      if numeric?(value), do: {:ok, value}, else: nil

                    _ ->
                      nil
                  end
                end)
              end)
          end
        end)

      {:error, _} ->
        :not_found
    end
  end

  defp try_script_numeric_ids(html_content) do
    case Floki.parse_document(html_content) do
      {:ok, document} ->
        scripts = Floki.find(document, "script")

        Enum.find_value(scripts, :not_found, fn script ->
          script_text = Floki.text(script)
          # Look for 7-8 digit numeric IDs
          case Regex.scan(~r/\b(\d{7,8})\b/, script_text) do
            [[_, media_id] | _] -> {:ok, media_id}
            [] -> nil
          end
        end)

      {:error, _} ->
        :not_found
    end
  end

  defp numeric?(str) do
    case Integer.parse(str) do
      {_, ""} -> true
      _ -> false
    end
  end

  defp find_m3u8_url(data, media_id) do
    case find_m3u8_recursive(data) do
      {:ok, url} ->
        Logger.info("Found m3u8 URL for media ID #{media_id}: #{url}")
        {:ok, url}

      :not_found ->
        Logger.warning("No m3u8 URL found in API response for media ID: #{media_id}")

        Logger.warning(
          "Full API response for debugging: #{inspect(data, pretty: true, limit: :infinity)}"
        )

        {:error, :m3u8_not_found}
    end
  end

  defp find_m3u8_recursive(data) when is_map(data) do
    # Check if "url" key contains an m3u8 URL
    case Map.get(data, "url") do
      url when is_binary(url) and byte_size(url) > 0 ->
        if String.ends_with?(url, ".m3u8") do
          {:ok, url}
        else
          search_nested_maps(data)
        end

      _ ->
        search_nested_maps(data)
    end
  end

  defp find_m3u8_recursive(data) when is_list(data) do
    Enum.find_value(data, :not_found, fn item ->
      case find_m3u8_recursive(item) do
        {:ok, url} -> {:ok, url}
        :not_found -> nil
      end
    end)
  end

  defp find_m3u8_recursive(_), do: :not_found

  defp search_nested_maps(data) do
    Enum.find_value(data, :not_found, fn {_key, value} ->
      case find_m3u8_recursive(value) do
        {:ok, url} -> {:ok, url}
        :not_found -> nil
      end
    end)
  end
end
