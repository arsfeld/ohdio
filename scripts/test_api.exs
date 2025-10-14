#!/usr/bin/env elixir

# Test script to investigate what the Radio-Canada API returns for a specific media ID
# Run with: elixir scripts/test_api.exs

Mix.install([
  {:req, "~> 0.4.0"},
  {:jason, "~> 1.4"}
])

media_id = "10491457"

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

IO.puts("Testing API call for media ID: #{media_id}")
IO.puts("URL: #{api_url}\n")

case Req.get(api_url) do
  {:ok, %{status: 200, body: body}} ->
    IO.puts("✓ API call successful")
    IO.puts("\nFull API Response:")
    IO.puts(Jason.encode!(body, pretty: true))

    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("Analysis:")
    IO.puts(String.duplicate("=", 80))

    # Check for m3u8 URLs
    json_str = Jason.encode!(body)
    if String.contains?(json_str, ".m3u8") do
      IO.puts("✓ Found .m3u8 in response")
    else
      IO.puts("✗ No .m3u8 found in response")
    end

    # Check for common keys
    IO.puts("\nTop-level keys in response:")
    if is_map(body) do
      body
      |> Map.keys()
      |> Enum.each(fn key -> IO.puts("  - #{key}") end)
    end

  {:ok, %{status: status, body: body}} ->
    IO.puts("✗ API returned status #{status}")
    IO.puts("\nResponse body:")
    IO.inspect(body, pretty: true, limit: :infinity)

  {:error, reason} ->
    IO.puts("✗ API call failed: #{inspect(reason)}")
end
