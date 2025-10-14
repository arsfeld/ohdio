defmodule Ohdio.Repo.Migrations.AddUniqueIndexToQueueItems do
  use Ecto.Migration

  def change do
    # Drop the existing non-unique index
    drop_if_exists index(:queue_items, [:audiobook_id])
    # Create the unique index
    create unique_index(:queue_items, [:audiobook_id])
  end
end
