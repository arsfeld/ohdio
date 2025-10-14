defmodule Ohdio.Downloads.QueueControl do
  use Ecto.Schema
  import Ecto.Changeset

  schema "queue_control" do
    field :is_paused, :boolean, default: false
    field :max_concurrent_downloads, :integer, default: 3

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(queue_control, attrs) do
    queue_control
    |> cast(attrs, [:is_paused, :max_concurrent_downloads])
    |> validate_required([:is_paused, :max_concurrent_downloads])
    |> validate_number(:max_concurrent_downloads, greater_than: 0)
  end
end
