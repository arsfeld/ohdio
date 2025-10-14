defmodule Ohdio.Scraper.UrlDetector do
  @moduledoc """
  Detects URL type and routes to appropriate scraper or downloader.

  Determines whether a URL should be:
  - Scraped with OHdio-specific scrapers (category or audiobook pages)
  - Passed through to yt-dlp for download
  """

  @type url_type ::
          :ohdio_category
          | :ohdio_audiobook
          | :spotify_track
          | :spotify_playlist
          | :spotify_album
          | :ytdlp_passthrough
          | :unknown

  @ohdio_domain "ici.radio-canada.ca"
  @ohdio_category_pattern ~r|/ohdio/categories/\d+/|
  @ohdio_audiobook_pattern ~r|/ohdio/livres-audio/|

  @spotify_domain "spotify.com"
  @spotify_track_pattern ~r|/track/|
  @spotify_playlist_pattern ~r|/playlist/|
  @spotify_album_pattern ~r|/album/|

  @doc """
  Detect the type of URL.

  ## Returns
    * `:ohdio_category` - OHdio category page (list of audiobooks)
    * `:ohdio_audiobook` - OHdio individual audiobook page
    * `:spotify_track` - Spotify track URL
    * `:spotify_playlist` - Spotify playlist URL
    * `:spotify_album` - Spotify album URL
    * `:ytdlp_passthrough` - URL compatible with yt-dlp (YouTube, etc.)
    * `:unknown` - Unable to determine URL type

  ## Examples

      iex> UrlDetector.detect_url_type("https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse")
      :ohdio_category

      iex> UrlDetector.detect_url_type("https://ici.radio-canada.ca/ohdio/livres-audio/12345/book-title")
      :ohdio_audiobook

      iex> UrlDetector.detect_url_type("https://open.spotify.com/track/...")
      :spotify_track

      iex> UrlDetector.detect_url_type("https://www.youtube.com/watch?v=...")
      :ytdlp_passthrough
  """
  @spec detect_url_type(String.t()) :: url_type()
  def detect_url_type(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: nil} ->
        :unknown

      %URI{host: host, path: path} when is_binary(path) ->
        cond do
          ohdio_domain?(host) && category_path?(path) ->
            :ohdio_category

          ohdio_domain?(host) && audiobook_path?(path) ->
            :ohdio_audiobook

          spotify_domain?(host) && track_path?(path) ->
            :spotify_track

          spotify_domain?(host) && playlist_path?(path) ->
            :spotify_playlist

          spotify_domain?(host) && album_path?(path) ->
            :spotify_album

          ytdlp_compatible?(host) ->
            :ytdlp_passthrough

          true ->
            :unknown
        end

      _ ->
        :unknown
    end
  end

  def detect_url_type(_), do: :unknown

  @doc """
  Check if a URL is an OHdio URL (category or audiobook).

  ## Examples

      iex> UrlDetector.ohdio_url?("https://ici.radio-canada.ca/ohdio/livres-audio/...")
      true

      iex> UrlDetector.ohdio_url?("https://youtube.com/watch?v=...")
      false
  """
  @spec ohdio_url?(String.t()) :: boolean()
  def ohdio_url?(url) do
    detect_url_type(url) in [:ohdio_category, :ohdio_audiobook]
  end

  @doc """
  Check if a URL should be passed through to yt-dlp.

  ## Examples

      iex> UrlDetector.ytdlp_url?("https://youtube.com/watch?v=...")
      true
  """
  @spec ytdlp_url?(String.t()) :: boolean()
  def ytdlp_url?(url) do
    detect_url_type(url) == :ytdlp_passthrough
  end

  @doc """
  Check if a URL is a Spotify URL (track, playlist, or album).

  ## Examples

      iex> UrlDetector.spotify_url?("https://open.spotify.com/track/...")
      true

      iex> UrlDetector.spotify_url?("https://youtube.com/watch?v=...")
      false
  """
  @spec spotify_url?(String.t()) :: boolean()
  def spotify_url?(url) do
    detect_url_type(url) in [:spotify_track, :spotify_playlist, :spotify_album]
  end

  # Private functions

  defp ohdio_domain?(host) when is_binary(host) do
    String.contains?(host, @ohdio_domain)
  end

  defp ohdio_domain?(_), do: false

  defp category_path?(path) do
    Regex.match?(@ohdio_category_pattern, path)
  end

  defp audiobook_path?(path) do
    Regex.match?(@ohdio_audiobook_pattern, path)
  end

  defp spotify_domain?(host) when is_binary(host) do
    String.contains?(host, @spotify_domain)
  end

  defp spotify_domain?(_), do: false

  defp track_path?(path) do
    Regex.match?(@spotify_track_pattern, path)
  end

  defp playlist_path?(path) do
    Regex.match?(@spotify_playlist_pattern, path)
  end

  defp album_path?(path) do
    Regex.match?(@spotify_album_pattern, path)
  end

  defp ytdlp_compatible?(host) when is_binary(host) do
    # Common domains supported by yt-dlp
    ytdlp_domains = [
      "youtube.com",
      "youtu.be",
      "vimeo.com",
      "dailymotion.com",
      "soundcloud.com",
      "twitch.tv",
      "twitter.com",
      "x.com",
      "facebook.com",
      "instagram.com",
      "tiktok.com",
      "reddit.com"
    ]

    Enum.any?(ytdlp_domains, fn domain ->
      String.contains?(host, domain)
    end)
  end

  defp ytdlp_compatible?(_), do: false
end
