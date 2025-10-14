defmodule Ohdio.Scraper.CategoryScraperTest do
  use ExUnit.Case, async: true

  alias Ohdio.Scraper.CategoryScraper
  alias Ohdio.Scraper.CategoryScraper.AudiobookInfo

  describe "parse_category_page/2" do
    test "parses audiobooks from index-grid-item layout" do
      html = """
      <html>
        <body>
          <div class="index-grid-item">
            <a href="/ohdio/livres-audio/123/book-one">
              <span class="text">Book One</span>
              <img src="/image1.jpg" />
            </a>
            <span class="author">Author One</span>
          </div>
          <div class="index-grid-item">
            <a href="/ohdio/livres-audio/456/book-two">
              <span class="text">Book Two</span>
              <img src="/image2.jpg" />
            </a>
            <span class="author">Author Two</span>
          </div>
        </body>
      </html>
      """

      base_url = "https://ici.radio-canada.ca/ohdio"
      audiobooks = CategoryScraper.parse_category_page(html, base_url)

      assert length(audiobooks) >= 1
      assert Enum.any?(audiobooks, fn book -> book.title == "Book One" end)
    end

    test "parses audiobooks from generic links" do
      html = """
      <html>
        <body>
          <a href="/ohdio/livres-audio/789/book-three" title="Book Three">
            <h2>Book Three</h2>
            <p>by Author Three</p>
          </a>
        </body>
      </html>
      """

      base_url = "https://ici.radio-canada.ca/ohdio"
      audiobooks = CategoryScraper.parse_category_page(html, base_url)

      assert length(audiobooks) >= 1
      book = hd(audiobooks)
      assert book.title == "Book Three"
      assert String.contains?(book.url, "livres-audio/789")
    end

    test "removes duplicate audiobooks by URL" do
      html = """
      <html>
        <body>
          <a href="/ohdio/livres-audio/123/book-one" title="Book One">Link 1</a>
          <a href="/ohdio/livres-audio/123/book-one" title="Book One">Link 2</a>
          <a href="/ohdio/livres-audio/456/book-two" title="Book Two">Link 3</a>
        </body>
      </html>
      """

      base_url = "https://ici.radio-canada.ca/ohdio"
      audiobooks = CategoryScraper.parse_category_page(html, base_url)

      # Should have 2 unique books, not 3
      assert length(audiobooks) == 2
    end

    test "handles malformed HTML gracefully" do
      html = """
      <html><body><div>Malformed<html>
      """

      base_url = "https://example.com"
      audiobooks = CategoryScraper.parse_category_page(html, base_url)

      # Should return empty list, not crash
      assert is_list(audiobooks)
    end

    test "extracts thumbnail URLs" do
      html = """
      <html>
        <body>
          <a href="/ohdio/livres-audio/123/book-one" title="Book One">
            <img src="/thumbnail.jpg" />
          </a>
        </body>
      </html>
      """

      base_url = "https://ici.radio-canada.ca"
      audiobooks = CategoryScraper.parse_category_page(html, base_url)

      assert length(audiobooks) >= 1
      book = hd(audiobooks)
      assert book.thumbnail_url == "https://ici.radio-canada.ca/thumbnail.jpg"
    end
  end

  describe "scrape_category/2" do
    @tag :integration
    test "scrapes real OHdio Jeunesse category" do
      # Skip this test by default as it makes a real HTTP request
      # Run with: mix test --only integration
      case CategoryScraper.scrape_category() do
        {:ok, audiobooks} ->
          assert length(audiobooks) > 0
          book = hd(audiobooks)
          assert %AudiobookInfo{} = book
          assert is_binary(book.title)
          assert is_binary(book.author)
          assert is_binary(book.url)

        {:error, reason} ->
          flunk("Failed to scrape category: #{inspect(reason)}")
      end
    end
  end
end
