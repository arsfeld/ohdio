defmodule Ohdio.Library do
  @moduledoc """
  The Library context.
  """

  import Ecto.Query, warn: false
  alias Ohdio.Repo

  alias Ohdio.Library.Audiobook
  alias Ohdio.Library.CategoryScrape

  @doc """
  Returns the list of audiobooks.

  ## Examples

      iex> list_audiobooks()
      [%Audiobook{}, ...]

  """
  def list_audiobooks do
    Repo.all(Audiobook)
  end

  @doc """
  Returns the list of completed audiobooks with optional search, filter, and sort.

  ## Options
    * `:search` - Search term to filter by title or author
    * `:sort_by` - Field to sort by (:inserted_at, :title, :author). Defaults to :inserted_at
    * `:sort_order` - Sort order (:asc or :desc). Defaults to :desc

  ## Examples

      iex> list_completed_audiobooks()
      [%Audiobook{}, ...]

      iex> list_completed_audiobooks(search: "harry potter")
      [%Audiobook{title: "Harry Potter..."}, ...]

      iex> list_completed_audiobooks(sort_by: :title, sort_order: :asc)
      [%Audiobook{}, ...]

  """
  def list_completed_audiobooks(opts \\ []) do
    search = Keyword.get(opts, :search)
    sort_by = Keyword.get(opts, :sort_by, :inserted_at)
    sort_order = Keyword.get(opts, :sort_order, :desc)

    Audiobook
    |> where([a], a.status == :completed)
    |> maybe_search(search)
    |> apply_sort(sort_by, sort_order)
    |> Repo.all()
  end

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, ""), do: query

  defp maybe_search(query, search_term) do
    search_pattern = "%#{search_term}%"
    where(query, [a], ilike(a.title, ^search_pattern) or ilike(a.author, ^search_pattern))
  end

  defp apply_sort(query, :inserted_at, :asc), do: order_by(query, [a], asc: a.inserted_at)
  defp apply_sort(query, :inserted_at, :desc), do: order_by(query, [a], desc: a.inserted_at)
  defp apply_sort(query, :title, :asc), do: order_by(query, [a], asc: a.title)
  defp apply_sort(query, :title, :desc), do: order_by(query, [a], desc: a.title)
  defp apply_sort(query, :author, :asc), do: order_by(query, [a], asc: a.author)
  defp apply_sort(query, :author, :desc), do: order_by(query, [a], desc: a.author)
  defp apply_sort(query, _, _), do: query

  @doc """
  Gets a single audiobook.

  Raises `Ecto.NoResultsError` if the Audiobook does not exist.

  ## Examples

      iex> get_audiobook!(123)
      %Audiobook{}

      iex> get_audiobook!(456)
      ** (Ecto.NoResultsError)

  """
  def get_audiobook!(id), do: Repo.get!(Audiobook, id)

  @doc """
  Creates a audiobook.

  ## Examples

      iex> create_audiobook(%{field: value})
      {:ok, %Audiobook{}}

      iex> create_audiobook(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_audiobook(attrs) do
    %Audiobook{}
    |> Audiobook.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a audiobook.

  ## Examples

      iex> update_audiobook(audiobook, %{field: new_value})
      {:ok, %Audiobook{}}

      iex> update_audiobook(audiobook, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_audiobook(%Audiobook{} = audiobook, attrs) do
    audiobook
    |> Audiobook.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a audiobook.

  ## Examples

      iex> delete_audiobook(audiobook)
      {:ok, %Audiobook{}}

      iex> delete_audiobook(audiobook)
      {:error, %Ecto.Changeset{}}

  """
  def delete_audiobook(%Audiobook{} = audiobook) do
    Repo.delete(audiobook)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking audiobook changes.

  ## Examples

      iex> change_audiobook(audiobook)
      %Ecto.Changeset{data: %Audiobook{}}

  """
  def change_audiobook(%Audiobook{} = audiobook, attrs \\ %{}) do
    Audiobook.changeset(audiobook, attrs)
  end

  # CategoryScrape functions

  @doc """
  Returns the list of active category scrapes (scraping or recently completed).

  ## Examples

      iex> list_active_category_scrapes()
      [%CategoryScrape{}, ...]

  """
  def list_active_category_scrapes do
    CategoryScrape
    |> where([cs], cs.status in [:scraping, :failed])
    |> order_by([cs], desc: cs.inserted_at)
    |> limit(10)
    |> Repo.all()
  end

  @doc """
  Gets a single category_scrape.

  Raises `Ecto.NoResultsError` if the CategoryScrape does not exist.

  ## Examples

      iex> get_category_scrape!(123)
      %CategoryScrape{}

      iex> get_category_scrape!(456)
      ** (Ecto.NoResultsError)

  """
  def get_category_scrape!(id), do: Repo.get!(CategoryScrape, id)

  @doc """
  Creates a category_scrape.

  ## Examples

      iex> create_category_scrape(%{field: value})
      {:ok, %CategoryScrape{}}

      iex> create_category_scrape(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_category_scrape(attrs) do
    %CategoryScrape{}
    |> CategoryScrape.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a category_scrape.

  ## Examples

      iex> update_category_scrape(category_scrape, %{field: new_value})
      {:ok, %CategoryScrape{}}

      iex> update_category_scrape(category_scrape, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_category_scrape(%CategoryScrape{} = category_scrape, attrs) do
    category_scrape
    |> CategoryScrape.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a category_scrape.

  ## Examples

      iex> delete_category_scrape(category_scrape)
      {:ok, %CategoryScrape{}}

      iex> delete_category_scrape(category_scrape)
      {:error, %Ecto.Changeset{}}

  """
  def delete_category_scrape(%CategoryScrape{} = category_scrape) do
    Repo.delete(category_scrape)
  end
end
