defmodule Ohdio.Downloads.QueueItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "queue_items" do
    field :status, Ecto.Enum,
      values: [:queued, :processing, :completed, :failed],
      default: :queued

    field :priority, :integer, default: 0
    field :attempts, :integer, default: 0
    field :max_attempts, :integer, default: 3
    field :error_message, :string
    belongs_to :audiobook, Ohdio.Library.Audiobook

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(queue_item, attrs) do
    queue_item
    |> cast(attrs, [:audiobook_id, :status, :priority, :attempts, :max_attempts, :error_message])
    |> validate_required([:audiobook_id])
    |> foreign_key_constraint(:audiobook_id)
    |> unique_constraint(:audiobook_id)
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> validate_number(:attempts, greater_than_or_equal_to: 0)
    |> validate_number(:max_attempts, greater_than: 0)
  end
end
