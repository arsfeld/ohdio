defmodule Ohdio.Scraper.CategoryScraper do
  @moduledoc """
  Scrapes OHdio category pages to discover audiobooks.

  Uses multiple fallback parsing strategies to extract audiobook information
  from category pages with varying HTML structures.
  """

  require Logger
  alias Ohdio.Scraper.HttpClient

  @jeunesse_category_url "https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse"

  defmodule AudiobookInfo do
    @moduledoc """
    Information about an audiobook discovered from a category page.
    """
    @type t :: %__MODULE__{
            title: String.t(),
            author: String.t(),
            url: String.t(),
            thumbnail_url: String.t() | nil,
            description: String.t() | nil
          }

    defstruct [:title, :author, :url, :thumbnail_url, :description]
  end

  @doc """
  Scrape all audiobooks from a category page.

  ## Parameters
    * `category_url` - URL of the category page (defaults to Jeunesse category)
    * `opts` - Options passed to HTTP client

  ## Returns
    * `{:ok, [%AudiobookInfo{}]}` - List of discovered audiobooks
    * `{:error, reason}` - Failed to scrape the category

  ## Examples

      iex> CategoryScraper.scrape_category()
      {:ok, [%AudiobookInfo{title: "...", author: "...", url: "..."}]}
  """
  @spec scrape_category(String.t() | nil, keyword()) ::
          {:ok, [AudiobookInfo.t()]} | {:error, atom()}
  def scrape_category(category_url \\ nil, opts \\ []) do
    url = category_url || @jeunesse_category_url
    Logger.info("Scraping category page: #{url}")

    case HttpClient.get(url, opts) do
      {:ok, html_content} ->
        audiobooks = parse_category_page(html_content, url)
        Logger.info("Found #{length(audiobooks)} audiobooks in category")
        {:ok, audiobooks}

      {:error, reason} ->
        Logger.error("Failed to fetch category page #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Parse category page HTML to extract audiobook information.

  Uses multiple parsing strategies in priority order:
  1. Index grid items (OHdio-specific layout)
  2. Common book item selectors
  3. "Livre audio" text search
  4. Generic link extraction

  Deduplicates results by URL.
  """
  @spec parse_category_page(String.t(), String.t()) :: [AudiobookInfo.t()]
  def parse_category_page(html_content, base_url) do
    case Floki.parse_document(html_content) do
      {:ok, document} ->
        parsing_methods = [
          &parse_index_grid_items/2,
          &parse_book_items/2,
          &parse_livre_audio_sections/2,
          &parse_generic_links/2
        ]

        audiobooks =
          Enum.flat_map(parsing_methods, fn method ->
            try do
              books = method.(document, base_url)
              method_name = function_name(method)

              if length(books) > 0 do
                Logger.debug("Found #{length(books)} books using #{method_name}")
              end

              books
            rescue
              e ->
                method_name = function_name(method)
                Logger.warning("Error in parsing method #{method_name}: #{inspect(e)}")
                []
            end
          end)

        # Remove duplicates based on URL
        audiobooks
        |> Enum.uniq_by(& &1.url)

      {:error, reason} ->
        Logger.error("Failed to parse HTML: #{inspect(reason)}")
        []
    end
  end

  # Parsing strategy 1: Index grid items
  defp parse_index_grid_items(document, base_url) do
    grid_items = Floki.find(document, ".index-grid-item")
    Logger.debug("Found #{length(grid_items)} index-grid-item elements")

    Enum.flat_map(grid_items, fn item ->
      # Find all audiobook links within the grid item
      item
      |> Floki.find("a[href*='livres-audio']")
      |> Enum.map(fn link ->
        extract_book_from_link(link, base_url)
      end)
      |> Enum.reject(&is_nil/1)
    end)
  end

  # Parsing strategy 2: Common book item selectors
  defp parse_book_items(document, base_url) do
    selectors = [
      "article[data-type='livres-audio']",
      ".livre-audio",
      ".audiobook-item",
      "article:has(a[href*='livres-audio'])",
      "div:has(a[href*='livres-audio'])"
    ]

    Enum.find_value(selectors, [], fn selector ->
      items = Floki.find(document, selector)

      if length(items) > 0 do
        Logger.debug("Found #{length(items)} items with selector: #{selector}")

        Enum.map(items, fn item ->
          extract_book_from_element(item, base_url)
        end)
        |> Enum.reject(&is_nil/1)
      end
    end)
  end

  # Parsing strategy 3: Find sections containing "Livre audio" text
  defp parse_livre_audio_sections(document, base_url) do
    # This is trickier in Floki - we'll search for text containing "Livre audio"
    # and then navigate up to find the container
    document
    |> Floki.find("*")
    |> Enum.filter(fn element ->
      text = Floki.text(element)
      String.contains?(text, "Livre audio")
    end)
    |> Enum.map(fn element ->
      # Find parent container that has audiobook links
      find_audiobook_container(element, document, base_url)
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Parsing strategy 4: Generic link extraction
  defp parse_generic_links(document, base_url) do
    document
    |> Floki.find("a[href*='livres-audio']")
    |> Enum.map(fn link ->
      extract_book_from_link(link, base_url)
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Extract book information from a link element
  defp extract_book_from_link(link, base_url) do
    case Floki.attribute(link, "href") do
      [href | _] ->
        full_url = resolve_url(href, base_url)

        # Skip category URLs - they are not audiobooks
        if String.contains?(full_url, "/categories/") do
          nil
        else
          title = extract_title_from_link(link)
          author = extract_author_from_link(link) || "Unknown Author"
          thumbnail_url = extract_thumbnail_from_link(link, base_url)

          if title do
            %AudiobookInfo{
              title: title,
              author: author,
              url: full_url,
              thumbnail_url: thumbnail_url
            }
          else
            nil
          end
        end

      [] ->
        nil
    end
  end

  # Extract book information from a container element
  defp extract_book_from_element(element, base_url) do
    # Find the main audiobook link
    case Floki.find(element, "a[href*='livres-audio']") do
      [link | _] ->
        extract_book_from_link(link, base_url)

      [] ->
        nil
    end
  end

  defp find_audiobook_container(element, _document, base_url) do
    # Try to find a link within this element
    case Floki.find(element, "a[href*='livres-audio']") do
      [link | _] -> extract_book_from_link(link, base_url)
      [] -> nil
    end
  end

  defp extract_title_from_link(link) do
    # Try different methods to extract title
    methods = [
      fn -> Floki.find(link, "span.text") |> Floki.text() end,
      fn -> Floki.attribute(link, "title") |> List.first() end,
      fn -> Floki.text(link) end,
      fn -> Floki.find(link, "h1") |> Floki.text() end,
      fn -> Floki.find(link, "h2") |> Floki.text() end,
      fn -> Floki.find(link, "h3") |> Floki.text() end,
      fn -> Floki.find(link, "h4") |> Floki.text() end,
      fn -> Floki.find(link, ".title") |> Floki.text() end,
      fn -> Floki.find(link, ".book-title") |> Floki.text() end
    ]

    Enum.find_value(methods, fn method ->
      try do
        result = method.()

        if is_binary(result) and String.length(result) > 2 do
          String.trim(result)
        else
          nil
        end
      rescue
        _ -> nil
      end
    end)
  end

  defp extract_author_from_link(link) do
    selectors = [
      ".author",
      ".book-author",
      ".by-author",
      "[data-author]"
    ]

    Enum.find_value(selectors, fn selector ->
      case Floki.find(link, selector) do
        [] ->
          nil

        elements ->
          text = Floki.text(elements)

          if String.length(text) > 1 do
            clean_author(text)
          else
            nil
          end
      end
    end)
  end

  defp extract_thumbnail_from_link(link, base_url) do
    case Floki.find(link, "img") do
      [] ->
        nil

      [img | _] ->
        case Floki.attribute(img, "src") do
          [src | _] ->
            resolve_url(src, base_url)

          [] ->
            case Floki.attribute(img, "data-src") do
              [src | _] -> resolve_url(src, base_url)
              [] -> nil
            end
        end
    end
  end

  defp clean_author(author) do
    author
    |> String.replace(~r/^(par|by|de|auteur:)\s+/i, "")
    |> String.trim()
  end

  defp resolve_url(href, base_url) do
    URI.merge(base_url, href) |> to_string()
  end

  defp function_name(fun) when is_function(fun) do
    info = Function.info(fun)
    "#{info[:module]}.#{info[:name]}"
  end
end
