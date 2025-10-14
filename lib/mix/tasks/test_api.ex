defmodule Mix.Tasks.TestApi do
  @moduledoc """
  Test task to debug API response for a specific media ID.

  Usage: mix test_api 10491457
  """

  use Mix.Task
  require Logger

  @shortdoc "Test Radio-Canada API response for a media ID"

  def run([media_id]) do
    Mix.Task.run("app.start")

    Logger.configure(level: :info)

    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("Testing Radio-Canada API for media ID: #{media_id}")
    IO.puts(String.duplicate("=", 80) <> "\n")

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
    api_url = "https://services.radio-canada.ca/media/validation/v2/?#{query_string}"

    IO.puts("API URL: #{api_url}\n")

    case Ohdio.Scraper.HttpClient.get(api_url) do
      {:ok, body} ->
        IO.puts("✓ API call successful\n")

        # Body could be a string or already-decoded map
        data =
          if is_binary(body) do
            case Jason.decode(body) do
              {:ok, decoded} -> decoded
              {:error, _} -> body
            end
          else
            body
          end

        IO.puts("Response type: #{if is_map(data), do: "map", else: "string"}")
        IO.puts("\nFull Response:")

        if is_map(data) do
          IO.puts(Jason.encode!(data, pretty: true))
        else
          IO.puts(data)
        end

        # Check for m3u8
        json_str = if is_map(data), do: Jason.encode!(data), else: data

        if String.contains?(json_str, ".m3u8") do
          IO.puts("\n✓ Found .m3u8 in response")

          # Extract and display the URL
          if is_map(data) and Map.has_key?(data, "url") do
            IO.puts("m3u8 URL: #{data["url"]}")
          end
        else
          IO.puts("\n✗ No .m3u8 found in response")
        end

      {:error, reason} ->
        IO.puts("✗ API call failed: #{inspect(reason)}")
    end

    IO.puts("\n" <> String.duplicate("=", 80))
  end

  def run(_) do
    IO.puts("Usage: mix test_api <media_id>")
    IO.puts("Example: mix test_api 10491457")
  end
end
