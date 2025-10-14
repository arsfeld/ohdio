defmodule Ohdio.Library.Audiobook do
  use Ecto.Schema
  import Ecto.Changeset

  schema "audiobooks" do
    field :title, :string
    field :author, :string
    field :narrator, :string
    field :url, :string
    field :cover_image_url, :string
    field :duration, :integer
    field :file_size, :integer
    field :file_path, :string

    field :status, Ecto.Enum,
      values: [:pending, :downloading, :completed, :failed],
      default: :pending

    has_many :queue_items, Ohdio.Downloads.QueueItem

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(audiobook, attrs) do
    audiobook
    |> cast(attrs, [
      :title,
      :author,
      :narrator,
      :url,
      :cover_image_url,
      :duration,
      :file_size,
      :file_path,
      :status
    ])
    |> validate_required_fields()
    |> validate_url(:url)
    |> unique_constraint(:url)
  end

  # Validate required fields based on status
  # Author is optional when status is :pending (will be extracted by MetadataExtractWorker)
  defp validate_required_fields(changeset) do
    status = get_field(changeset, :status)

    case status do
      :pending ->
        validate_required(changeset, [:title, :url])

      _ ->
        validate_required(changeset, [:title, :author, :url])
    end
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
