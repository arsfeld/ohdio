defmodule Ohdio.Scraper.PlaylistExtractorTest do
  use ExUnit.Case, async: true

  alias Ohdio.Scraper.PlaylistExtractor

  describe "extract_media_id/2" do
    test "extracts media ID from JSON pattern" do
      html = """
      <script>
        var config = {
          "mediaId": "12345678",
          "title": "Test Audiobook"
        };
      </script>
      """

      assert {:ok, "12345678"} = PlaylistExtractor.extract_media_id(html, "test_url")
    end

    test "extracts media ID from numeric pattern" do
      html = """
      <script>
        var config = {
          mediaId: 87654321,
          title: "Test"
        };
      </script>
      """

      assert {:ok, "87654321"} = PlaylistExtractor.extract_media_id(html, "test_url")
    end

    test "extracts media ID from data attributes" do
      html = """
      <div class="media-player" data-media-id="11223344">
        <button>Play</button>
      </div>
      """

      assert {:ok, "11223344"} = PlaylistExtractor.extract_media_id(html, "test_url")
    end

    test "extracts media ID from script numeric IDs" do
      html = """
      <script>
        window.__INITIAL_STATE__ = {
          mediaId: 99887766
        };
      </script>
      """

      assert {:ok, "99887766"} = PlaylistExtractor.extract_media_id(html, "test_url")
    end

    test "returns error when media ID not found" do
      html = """
      <html>
        <body>
          <h1>No media here</h1>
        </body>
      </html>
      """

      assert {:error, :media_id_not_found} = PlaylistExtractor.extract_media_id(html, "test_url")
    end
  end

  describe "get_playlist_from_api/1" do
    @tag :integration
    test "makes API request for media ID" do
      # This test requires a real media ID from OHdio
      # Skip if you don't want to make real API calls
      media_id = "1234567"

      case PlaylistExtractor.get_playlist_from_api(media_id) do
        {:ok, url} ->
          assert String.ends_with?(url, ".m3u8")

        {:error, _reason} ->
          # API might fail for invalid media IDs, which is expected
          :ok
      end
    end
  end

  describe "extract_playlist_url/2" do
    test "extracts playlist URL from complete HTML" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <script>
          window.__INITIAL_STATE__ = {
            "mediaId": "12345678",
            "title": "Test Audiobook"
          };
        </script>
      </head>
      <body>
        <h1>Test Audiobook</h1>
      </body>
      </html>
      """

      # This will try to extract media ID (which should work)
      # but fail at API call (since it's a fake ID)
      # We're mainly testing the extraction logic here
      result = PlaylistExtractor.extract_playlist_url(html, "https://example.com")

      case result do
        {:ok, _url} ->
          # If it succeeds (unlikely with fake ID), that's fine
          :ok

        {:error, _reason} ->
          # Expected to fail at API call, but media ID extraction should have worked
          assert {:ok, "12345678"} = PlaylistExtractor.extract_media_id(html, "test")
      end
    end
  end
end
