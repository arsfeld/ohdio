defmodule Ohdio.Scraper do
  @moduledoc """
  The Scraper context for OHdio audiobook discovery and metadata extraction.

  This module provides the public API for:
  - Scraping category pages to discover audiobooks
  - Extracting metadata from individual audiobook pages
  - Detecting URL types and routing to appropriate handlers
  - Extracting m3u8 playlist URLs for downloads

  ## Examples

      # Scrape a category to discover audiobooks
      {:ok, audiobooks} = Scraper.scrape_category()

      # Scrape a specific audiobook for metadata
      {:ok, metadata} = Scraper.scrape_audiobook("https://...")

      # Detect URL type
      :ohdio_audiobook = Scraper.detect_url_type("https://ici.radio-canada.ca/ohdio/livres-audio/...")
  """

  alias Ohdio.Scraper.{
    CategoryScraper,
    AudiobookScraper,
    PlaylistExtractor,
    UrlDetector
  }

  @type audiobook_info :: CategoryScraper.AudiobookInfo.t()
  @type audiobook_metadata :: AudiobookScraper.AudiobookMetadata.t()
  @type url_type :: UrlDetector.url_type()

  # Category scraping

  @doc """
  Scrape a category page to discover audiobooks.

  ## Parameters
    * `category_url` - URL of the category page (optional, defaults to Jeunesse category)
    * `opts` - Options to pass to HTTP client

  ## Returns
    * `{:ok, [%AudiobookInfo{}]}` - List of discovered audiobooks
    * `{:error, reason}` - Failed to scrape the category

  ## Examples

      # Scrape default Jeunesse category
      {:ok, audiobooks} = Scraper.scrape_category()

      # Scrape a specific category
      {:ok, audiobooks} = Scraper.scrape_category("https://ici.radio-canada.ca/ohdio/categories/...")
  """
  @spec scrape_category(String.t() | nil, keyword()) ::
          {:ok, [audiobook_info()]} | {:error, atom()}
  defdelegate scrape_category(category_url \\ nil, opts \\ []), to: CategoryScraper

  @doc """
  Get the total number of audiobooks in a category.

  ## Examples

      {:ok, count} = Scraper.get_audiobook_count()
  """
  @spec get_audiobook_count(String.t() | nil, keyword()) ::
          {:ok, non_neg_integer()} | {:error, atom()}
  def get_audiobook_count(category_url \\ nil, opts \\ []) do
    case scrape_category(category_url, opts) do
      {:ok, audiobooks} -> {:ok, length(audiobooks)}
      {:error, reason} -> {:error, reason}
    end
  end

  # Audiobook scraping

  @doc """
  Scrape an audiobook page for detailed metadata.

  ## Parameters
    * `book_url` - URL of the audiobook page
    * `opts` - Options to pass to HTTP client

  ## Returns
    * `{:ok, %AudiobookMetadata{}}` - Successfully extracted metadata
    * `{:error, reason}` - Failed to scrape the audiobook

  ## Examples

      {:ok, metadata} = Scraper.scrape_audiobook("https://ici.radio-canada.ca/ohdio/livres-audio/...")
  """
  @spec scrape_audiobook(String.t(), keyword()) ::
          {:ok, audiobook_metadata()} | {:error, atom()}
  defdelegate scrape_audiobook(book_url, opts \\ []), to: AudiobookScraper

  # Playlist extraction

  @doc """
  Extract the m3u8 playlist URL from an audiobook page.

  ## Parameters
    * `html_content` - The HTML content of the audiobook page
    * `url` - The URL of the page (for logging)

  ## Returns
    * `{:ok, playlist_url}` - Successfully extracted the m3u8 URL
    * `{:error, reason}` - Failed to extract the playlist URL

  ## Examples

      {:ok, playlist_url} = Scraper.extract_playlist_url(html, url)
  """
  @spec extract_playlist_url(String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  defdelegate extract_playlist_url(html_content, url), to: PlaylistExtractor

  @doc """
  Extract the media ID from audiobook page HTML.

  ## Examples

      {:ok, "12345678"} = Scraper.extract_media_id(html, url)
  """
  @spec extract_media_id(String.t(), String.t()) ::
          {:ok, String.t()} | {:error, :media_id_not_found}
  defdelegate extract_media_id(html_content, url), to: PlaylistExtractor

  @doc """
  Get the m3u8 playlist URL directly from Radio-Canada API using media ID.

  ## Examples

      {:ok, playlist_url} = Scraper.get_playlist_from_api("12345678")
  """
  @spec get_playlist_from_api(String.t()) :: {:ok, String.t()} | {:error, atom()}
  defdelegate get_playlist_from_api(media_id), to: PlaylistExtractor

  # URL detection

  @doc """
  Detect the type of URL.

  ## Returns
    * `:ohdio_category` - OHdio category page
    * `:ohdio_audiobook` - OHdio audiobook page
    * `:ytdlp_passthrough` - yt-dlp compatible URL
    * `:unknown` - Unknown URL type

  ## Examples

      :ohdio_category = Scraper.detect_url_type("https://ici.radio-canada.ca/ohdio/categories/...")
      :ohdio_audiobook = Scraper.detect_url_type("https://ici.radio-canada.ca/ohdio/livres-audio/...")
      :ytdlp_passthrough = Scraper.detect_url_type("https://youtube.com/watch?v=...")
  """
  @spec detect_url_type(String.t()) :: url_type()
  defdelegate detect_url_type(url), to: UrlDetector

  @doc """
  Check if a URL is an OHdio URL (category or audiobook).

  ## Examples

      true = Scraper.ohdio_url?("https://ici.radio-canada.ca/ohdio/livres-audio/...")
      false = Scraper.ohdio_url?("https://youtube.com/...")
  """
  @spec ohdio_url?(String.t()) :: boolean()
  defdelegate ohdio_url?(url), to: UrlDetector

  @doc """
  Check if a URL should be passed through to yt-dlp.

  ## Examples

      true = Scraper.ytdlp_url?("https://youtube.com/...")
      false = Scraper.ytdlp_url?("https://ici.radio-canada.ca/ohdio/...")
  """
  @spec ytdlp_url?(String.t()) :: boolean()
  defdelegate ytdlp_url?(url), to: UrlDetector
end
