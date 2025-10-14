defmodule Ohdio.Library.CategoryScrape do
  use Ecto.Schema
  import Ecto.Changeset

  schema "category_scrapes" do
    field :category_url, :string
    field :total_count, :integer
    field :error_message, :string
    field :oban_job_id, :integer

    field :status, Ecto.Enum,
      values: [:scraping, :completed, :failed],
      default: :scraping

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category_scrape, attrs) do
    category_scrape
    |> cast(attrs, [
      :category_url,
      :status,
      :total_count,
      :error_message,
      :oban_job_id
    ])
    |> validate_required([:category_url, :status])
    |> validate_url(:category_url)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, url ->
      uri = URI.parse(url)

      if uri.scheme in ["http", "https"] and uri.host do
        []
      else
        [{field, "must be a valid HTTP(S) URL"}]
      end
    end)
  end
end
