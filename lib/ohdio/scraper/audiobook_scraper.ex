defmodule Ohdio.Scraper.AudiobookScraper do
  @moduledoc """
  Scrapes individual audiobook pages to extract detailed metadata.

  Extracts comprehensive metadata including title, author, description,
  playlist URL, and other audiobook information.
  """

  require Logger
  alias Ohdio.Scraper.{HttpClient, PlaylistExtractor}

  defmodule AudiobookMetadata do
    @moduledoc """
    Complete metadata for an audiobook.
    """
    @type t :: %__MODULE__{
            title: String.t(),
            author: String.t(),
            url: String.t(),
            playlist_url: String.t() | nil,
            description: String.t() | nil,
            duration: String.t() | nil,
            publication_date: String.t() | nil,
            genre: String.t() | nil,
            language: String.t(),
            thumbnail_url: String.t() | nil,
            isbn: String.t() | nil,
            publisher: String.t() | nil,
            narrator: String.t() | nil,
            series: String.t() | nil,
            series_number: integer() | nil
          }

    defstruct [
      :title,
      :author,
      :url,
      :playlist_url,
      :description,
      :duration,
      :publication_date,
      :genre,
      :thumbnail_url,
      :isbn,
      :publisher,
      :narrator,
      :series,
      :series_number,
      language: "fr"
    ]
  end

  @doc """
  Extract all metadata and playlist URL from an audiobook page.

  ## Parameters
    * `book_url` - URL of the audiobook page
    * `opts` - Options passed to HTTP client

  ## Returns
    * `{:ok, %AudiobookMetadata{}}` - Successfully extracted metadata
    * `{:error, reason}` - Failed to scrape the audiobook

  ## Examples

      iex> AudiobookScraper.scrape_audiobook("https://ici.radio-canada.ca/ohdio/livres-audio/...")
      {:ok, %AudiobookMetadata{title: "...", author: "...", ...}}
  """
  @spec scrape_audiobook(String.t(), keyword()) ::
          {:ok, AudiobookMetadata.t()} | {:error, atom()}
  def scrape_audiobook(book_url, opts \\ []) do
    Logger.info("Scraping audiobook: #{book_url}")

    case HttpClient.get(book_url, opts) do
      {:ok, html_content} ->
        case extract_metadata(html_content, book_url) do
          {:ok, metadata} ->
            Logger.info("Successfully scraped '#{metadata.title}' by #{metadata.author}")
            {:ok, metadata}

          {:error, reason} ->
            Logger.warning("Failed to extract metadata from #{book_url}: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to fetch audiobook page #{book_url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Extract metadata from audiobook page HTML content.
  """
  @spec extract_metadata(String.t(), String.t()) ::
          {:ok, AudiobookMetadata.t()} | {:error, atom()}
  def extract_metadata(html_content, page_url) do
    case Floki.parse_document(html_content) do
      {:ok, document} ->
        title = extract_title(document)
        author = extract_author(document, html_content)

        if title && author do
          # Extract playlist URL
          playlist_url =
            case PlaylistExtractor.extract_playlist_url(html_content, page_url) do
              {:ok, url} -> url
              {:error, _} -> nil
            end

          metadata = %AudiobookMetadata{
            title: title,
            author: author,
            url: page_url,
            playlist_url: playlist_url,
            description: extract_description(document),
            duration: extract_duration(document),
            publication_date: extract_publication_date(document),
            genre: extract_genre(document),
            thumbnail_url: extract_thumbnail_url(document, page_url),
            isbn: extract_isbn(document),
            publisher: extract_publisher(document),
            narrator: extract_narrator(document),
            series: extract_series(document) |> Map.get(:series),
            series_number: extract_series(document) |> Map.get(:number)
          }

          {:ok, metadata}
        else
          Logger.warning(
            "Missing basic info - title: '#{inspect(title)}', author: '#{inspect(author)}'"
          )

          {:error, :missing_basic_info}
        end

      {:error, reason} ->
        Logger.error("Failed to parse HTML: #{inspect(reason)}")
        {:error, :parse_error}
    end
  end

  # Extraction methods

  defp extract_title(document) do
    selectors = [
      "h1",
      ".title",
      ".book-title",
      ".audiobook-title",
      "[data-title]",
      "meta[property='og:title']",
      "title"
    ]

    Enum.find_value(selectors, fn selector ->
      case Floki.find(document, selector) do
        [] ->
          nil

        [element | _] ->
          title =
            case Floki.attribute(element, "content") do
              [content | _] -> content
              [] -> Floki.text(element)
            end

          if String.length(title) > 2 do
            clean_title(title)
          else
            nil
          end
      end
    end)
  end

  defp extract_author(document, html_content) do
    # Try CSS selectors first
    selectors = [
      ".author",
      ".book-author",
      ".by-author",
      "[data-author]",
      "meta[name='author']",
      "meta[property='book:author']"
    ]

    author =
      Enum.find_value(selectors, fn selector ->
        case Floki.find(document, selector) do
          [] ->
            nil

          [element | _] ->
            author =
              case Floki.attribute(element, "content") do
                [content | _] -> content
                [] -> Floki.text(element)
              end

            if String.length(author) > 1 do
              clean_author(author)
            else
              nil
            end
        end
      end)

    # If not found, try regex patterns
    author || extract_author_from_text(html_content)
  end

  defp extract_author_from_text(html_content) do
    # Prioritize "Écrit par" (author) over "Lu par" (narrator)
    patterns = [
      ~r/>Écrit\s+par\s+([A-ZÀ-Ÿ][a-zA-ZÀ-ÿ\s\-\']+?)</u,
      ~r/class="[^"]*animator[^"]*">Écrit\s+par\s+([A-ZÀ-Ÿ][a-zA-ZÀ-ÿ\s\-\']+?)</u,
      ~r/Écrit\s+par\s+([A-ZÀ-Ÿ][a-zA-ZÀ-ÿ\s\-\']+?)(?:\s|$)/u,
      ~r/auteur[:\s]+([A-ZÀ-Ÿ][a-zA-ZÀ-ÿ\s\-\']+?)(?:\s|$)/ui,
      ~r/by\s+([A-ZÀ-Ÿ][a-zA-ZÀ-ÿ\s\-\']+?)(?:\s|$)/u,
      ~r/de\s+([A-ZÀ-Ÿ][a-zA-ZÀ-ÿ\s\-\']+?)(?:\s|$)/u
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, html_content) do
        [_, author] ->
          author = String.trim(author)
          words = String.split(author)

          if length(words) in 1..3 and String.length(author) in 2..50 do
            author
          else
            nil
          end

        nil ->
          nil
      end
    end)
  end

  defp extract_description(document) do
    selectors = [
      ".description",
      ".summary",
      ".synopsis",
      ".excerpt",
      "meta[name='description']",
      "meta[property='og:description']",
      ".book-description",
      ".content-description"
    ]

    Enum.find_value(selectors, fn selector ->
      case Floki.find(document, selector) do
        [] ->
          nil

        [element | _] ->
          description =
            case Floki.attribute(element, "content") do
              [content | _] -> content
              [] -> Floki.text(element)
            end

          if String.length(description) > 20, do: description, else: nil
      end
    end)
  end

  defp extract_duration(document) do
    selectors = [
      ".duration",
      ".length",
      ".runtime",
      "[data-duration]",
      "meta[property='video:duration']"
    ]

    Enum.find_value(selectors, fn selector ->
      case Floki.find(document, selector) do
        [] ->
          nil

        [element | _] ->
          case Floki.attribute(element, "content") do
            [content | _] -> content
            [] -> Floki.text(element)
          end
      end
    end)
  end

  defp extract_publication_date(document) do
    selectors = [
      ".publication-date",
      ".publish-date",
      ".date",
      "meta[property='book:release_date']",
      "meta[name='publication_date']",
      "time[datetime]"
    ]

    Enum.find_value(selectors, fn selector ->
      case Floki.find(document, selector) do
        [] ->
          nil

        [element | _] ->
          case Floki.attribute(element, "datetime") do
            [datetime | _] ->
              datetime

            [] ->
              case Floki.attribute(element, "content") do
                [content | _] -> content
                [] -> Floki.text(element)
              end
          end
      end
    end)
  end

  defp extract_genre(document) do
    selectors = [
      ".genre",
      ".category",
      ".book-genre",
      "meta[property='book:genre']",
      "meta[name='genre']"
    ]

    Enum.find_value(selectors, fn selector ->
      case Floki.find(document, selector) do
        [] ->
          nil

        [element | _] ->
          case Floki.attribute(element, "content") do
            [content | _] -> content
            [] -> Floki.text(element)
          end
      end
    end) || "Jeunesse"
  end

  defp extract_thumbnail_url(document, base_url) do
    selectors = [
      ".book-cover img",
      ".cover img",
      ".thumbnail img",
      "meta[property='og:image']",
      "meta[name='twitter:image']",
      ".audiobook-cover img"
    ]

    Enum.find_value(selectors, fn selector ->
      case Floki.find(document, selector) do
        [] ->
          nil

        [element | _] ->
          url =
            case Floki.attribute(element, "content") do
              [content | _] ->
                content

              [] ->
                case Floki.attribute(element, "src") do
                  [src | _] ->
                    src

                  [] ->
                    case Floki.attribute(element, "data-src") do
                      [data_src | _] -> data_src
                      [] -> nil
                    end
                end
            end

          if url, do: resolve_url(url, base_url), else: nil
      end
    end)
  end

  defp extract_isbn(document) do
    selectors = [
      "meta[property='book:isbn']",
      "meta[name='isbn']",
      ".isbn"
    ]

    Enum.find_value(selectors, fn selector ->
      case Floki.find(document, selector) do
        [] ->
          nil

        [element | _] ->
          case Floki.attribute(element, "content") do
            [content | _] -> content
            [] -> Floki.text(element)
          end
      end
    end)
  end

  defp extract_publisher(document) do
    selectors = [
      ".publisher",
      ".book-publisher",
      "meta[property='book:publisher']",
      "meta[name='publisher']"
    ]

    Enum.find_value(selectors, fn selector ->
      case Floki.find(document, selector) do
        [] ->
          nil

        [element | _] ->
          case Floki.attribute(element, "content") do
            [content | _] -> content
            [] -> Floki.text(element)
          end
      end
    end)
  end

  defp extract_narrator(document) do
    selectors = [
      ".narrator",
      ".reader",
      ".voice-actor",
      ".read-by"
    ]

    Enum.find_value(selectors, fn selector ->
      case Floki.find(document, selector) do
        [] -> nil
        [element | _] -> Floki.text(element)
      end
    end)
  end

  defp extract_series(document) do
    selectors = [
      ".series",
      ".book-series",
      ".series-info"
    ]

    series_info =
      Enum.find_value(selectors, fn selector ->
        case Floki.find(document, selector) do
          [] ->
            nil

          [element | _] ->
            text = Floki.text(element)

            if String.length(text) > 0 do
              # Try to extract series name and number
              patterns = [
                ~r/(.+?)\s*#(\d+)/,
                ~r/(.+?),?\s*tome\s*(\d+)/i,
                ~r/(.+?),?\s*volume\s*(\d+)/i
              ]

              Enum.find_value(patterns, fn pattern ->
                case Regex.run(pattern, text) do
                  [_, series, number] ->
                    {:ok, %{series: String.trim(series), number: String.to_integer(number)}}

                  nil ->
                    nil
                end
              end) || {:ok, %{series: text, number: nil}}
            else
              nil
            end
        end
      end)

    case series_info do
      {:ok, info} -> info
      nil -> %{series: nil, number: nil}
    end
  end

  # Helper functions

  defp clean_title(title) do
    suffixes = [
      " | ICI OHdio",
      " | Radio-Canada",
      " - OHdio",
      " - Radio-Canada",
      " - Livre audio"
    ]

    Enum.reduce(suffixes, title, fn suffix, acc ->
      String.replace_suffix(acc, suffix, "")
    end)
    |> String.trim()
  end

  defp clean_author(author) do
    prefixes = ["par ", "by ", "de ", "auteur: "]

    author_lower = String.downcase(author)

    Enum.find_value(prefixes, author, fn prefix ->
      if String.starts_with?(author_lower, prefix) do
        String.slice(author, String.length(prefix)..-1//1)
      else
        nil
      end
    end)
    |> String.trim()
  end

  defp resolve_url(href, base_url) do
    URI.merge(base_url, href) |> to_string()
  end
end
