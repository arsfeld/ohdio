defmodule Ohdio.Scraper.AudiobookScraperTest do
  use ExUnit.Case, async: true

  alias Ohdio.Scraper.AudiobookScraper
  alias Ohdio.Scraper.AudiobookScraper.AudiobookMetadata

  describe "extract_metadata/2" do
    test "extracts basic metadata from audiobook page" do
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>Test Book | ICI OHdio</title>
        <meta property="og:title" content="Test Book" />
        <meta name="description" content="A test audiobook description" />
      </head>
      <body>
        <h1>Test Book</h1>
        <div class="author">by Test Author</div>
        <div class="description">A test audiobook description that is longer than 20 characters</div>
        <div class="genre">Fiction</div>
        <script>
          var mediaId = "12345678";
        </script>
      </body>
      </html>
      """

      url = "https://ici.radio-canada.ca/ohdio/livres-audio/123/test-book"

      assert {:ok, metadata} = AudiobookScraper.extract_metadata(html, url)
      assert %AudiobookMetadata{} = metadata
      assert metadata.title == "Test Book"
      assert metadata.author == "Test Author"
      assert metadata.url == url
      assert String.contains?(metadata.description, "test audiobook")
    end

    test "extracts author from 'Écrit par' pattern" do
      html = """
      <html>
        <body>
          <h1>Test Book</h1>
          <div>Écrit par Jean Dupont</div>
          <script>var mediaId = "12345678";</script>
        </body>
      </html>
      """

      url = "https://example.com"

      assert {:ok, metadata} = AudiobookScraper.extract_metadata(html, url)
      assert metadata.author == "Jean Dupont"
    end

    test "cleans title from site suffixes" do
      html = """
      <html>
        <head>
          <meta property="og:title" content="Test Book | ICI OHdio" />
        </head>
        <body>
          <div class="author">Test Author</div>
          <script>var mediaId = "12345678";</script>
        </body>
      </html>
      """

      url = "https://example.com"

      assert {:ok, metadata} = AudiobookScraper.extract_metadata(html, url)
      assert metadata.title == "Test Book"
      refute String.contains?(metadata.title, "OHdio")
    end

    test "extracts thumbnail URL" do
      html = """
      <html>
        <head>
          <meta property="og:image" content="https://example.com/cover.jpg" />
        </head>
        <body>
          <h1>Test Book</h1>
          <div class="author">Test Author</div>
          <script>var mediaId = "12345678";</script>
        </body>
      </html>
      """

      url = "https://example.com"

      assert {:ok, metadata} = AudiobookScraper.extract_metadata(html, url)
      assert metadata.thumbnail_url == "https://example.com/cover.jpg"
    end

    test "extracts duration" do
      html = """
      <html>
        <body>
          <h1>Test Book</h1>
          <div class="author">Test Author</div>
          <div class="duration">2h 30min</div>
          <script>var mediaId = "12345678";</script>
        </body>
      </html>
      """

      url = "https://example.com"

      assert {:ok, metadata} = AudiobookScraper.extract_metadata(html, url)
      assert metadata.duration == "2h 30min"
    end

    test "extracts series information" do
      html = """
      <html>
        <body>
          <h1>Test Book</h1>
          <div class="author">Test Author</div>
          <div class="series">The Test Series #2</div>
          <script>var mediaId = "12345678";</script>
        </body>
      </html>
      """

      url = "https://example.com"

      assert {:ok, metadata} = AudiobookScraper.extract_metadata(html, url)
      assert metadata.series == "The Test Series"
      assert metadata.series_number == 2
    end

    test "returns error when title is missing" do
      html = """
      <html>
        <body>
          <div class="author">Test Author</div>
        </body>
      </html>
      """

      url = "https://example.com"

      assert {:error, :missing_basic_info} = AudiobookScraper.extract_metadata(html, url)
    end

    test "returns error when author is missing" do
      html = """
      <html>
        <body>
          <h1>Test Book</h1>
        </body>
      </html>
      """

      url = "https://example.com"

      assert {:error, :missing_basic_info} = AudiobookScraper.extract_metadata(html, url)
    end

    test "defaults genre to Jeunesse when not found" do
      html = """
      <html>
        <body>
          <h1>Test Book</h1>
          <div class="author">Test Author</div>
          <script>var mediaId = "12345678";</script>
        </body>
      </html>
      """

      url = "https://example.com"

      assert {:ok, metadata} = AudiobookScraper.extract_metadata(html, url)
      assert metadata.genre == "Jeunesse"
    end

    test "defaults language to French" do
      html = """
      <html>
        <body>
          <h1>Test Book</h1>
          <div class="author">Test Author</div>
          <script>var mediaId = "12345678";</script>
        </body>
      </html>
      """

      url = "https://example.com"

      assert {:ok, metadata} = AudiobookScraper.extract_metadata(html, url)
      assert metadata.language == "fr"
    end
  end

  describe "scrape_audiobook/2" do
    @tag :integration
    test "scrapes real OHdio audiobook page" do
      # This would require a real OHdio audiobook URL
      # Skip by default, run with: mix test --only integration
      # Example URL from Jeunesse category
      url = "https://ici.radio-canada.ca/ohdio/livres-audio/some-real-book"

      # Only run if we have a real URL to test
      if System.get_env("TEST_OHDIO_URL") do
        case AudiobookScraper.scrape_audiobook(url) do
          {:ok, metadata} ->
            assert %AudiobookMetadata{} = metadata
            assert is_binary(metadata.title)
            assert is_binary(metadata.author)

          {:error, _reason} ->
            # Expected to fail without real URL
            :ok
        end
      end
    end
  end
end
