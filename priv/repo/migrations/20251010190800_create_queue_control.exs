defmodule Ohdio.Repo.Migrations.CreateQueueControl do
  use Ecto.Migration

  def change do
    create table(:queue_control) do
      add :is_paused, :boolean, default: false, null: false
      add :max_concurrent_downloads, :integer, default: 3, null: false

      timestamps(type: :utc_datetime)
    end

    # Insert default row
    execute(
      "INSERT INTO queue_control (is_paused, max_concurrent_downloads, inserted_at, updated_at) VALUES (false, 3, datetime('now'), datetime('now'))",
      "DELETE FROM queue_control"
    )
  end
end
