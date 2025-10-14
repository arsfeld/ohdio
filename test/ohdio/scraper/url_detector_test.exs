defmodule Ohdio.Scraper.UrlDetectorTest do
  use ExUnit.Case, async: true

  alias Ohdio.Scraper.UrlDetector

  describe "detect_url_type/1" do
    test "detects OHdio category URLs" do
      urls = [
        "https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse",
        "https://ici.radio-canada.ca/ohdio/categories/123/fiction",
        "http://ici.radio-canada.ca/ohdio/categories/456/documentaires"
      ]

      for url <- urls do
        assert UrlDetector.detect_url_type(url) == :ohdio_category,
               "Expected #{url} to be detected as :ohdio_category"
      end
    end

    test "detects OHdio audiobook URLs" do
      urls = [
        "https://ici.radio-canada.ca/ohdio/livres-audio/12345/book-title",
        "https://ici.radio-canada.ca/ohdio/livres-audio/67890/another-book",
        "http://ici.radio-canada.ca/ohdio/livres-audio/111/test"
      ]

      for url <- urls do
        assert UrlDetector.detect_url_type(url) == :ohdio_audiobook,
               "Expected #{url} to be detected as :ohdio_audiobook"
      end
    end

    test "detects yt-dlp compatible URLs" do
      urls = [
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://youtu.be/dQw4w9WgXcQ",
        "https://vimeo.com/123456",
        "https://soundcloud.com/artist/track",
        "https://www.twitch.tv/channel",
        "https://twitter.com/user/status/123",
        "https://x.com/user/status/123"
      ]

      for url <- urls do
        assert UrlDetector.detect_url_type(url) == :ytdlp_passthrough,
               "Expected #{url} to be detected as :ytdlp_passthrough"
      end
    end

    test "returns :unknown for unrecognized URLs" do
      urls = [
        "https://example.com/some/path",
        "https://google.com",
        "not a url",
        ""
      ]

      for url <- urls do
        assert UrlDetector.detect_url_type(url) == :unknown,
               "Expected #{url} to be detected as :unknown"
      end
    end

    test "handles invalid inputs gracefully" do
      assert UrlDetector.detect_url_type(nil) == :unknown
      assert UrlDetector.detect_url_type(123) == :unknown
      assert UrlDetector.detect_url_type(%{}) == :unknown
    end
  end

  describe "ohdio_url?/1" do
    test "returns true for OHdio URLs" do
      assert UrlDetector.ohdio_url?(
               "https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse"
             )

      assert UrlDetector.ohdio_url?("https://ici.radio-canada.ca/ohdio/livres-audio/12345/book")
    end

    test "returns false for non-OHdio URLs" do
      refute UrlDetector.ohdio_url?("https://youtube.com/watch?v=123")
      refute UrlDetector.ohdio_url?("https://example.com")
    end
  end

  describe "ytdlp_url?/1" do
    test "returns true for yt-dlp compatible URLs" do
      assert UrlDetector.ytdlp_url?("https://youtube.com/watch?v=123")
      assert UrlDetector.ytdlp_url?("https://vimeo.com/123")
    end

    test "returns false for non-yt-dlp URLs" do
      refute UrlDetector.ytdlp_url?("https://ici.radio-canada.ca/ohdio/livres-audio/123/book")
      refute UrlDetector.ytdlp_url?("https://example.com")
    end
  end
end
