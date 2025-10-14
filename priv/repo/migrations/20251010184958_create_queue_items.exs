defmodule Ohdio.Repo.Migrations.CreateQueueItems do
  use Ecto.Migration

  def change do
    create table(:queue_items) do
      add :status, :string, default: "queued", null: false
      add :priority, :integer, default: 0, null: false
      add :attempts, :integer, default: 0, null: false
      add :max_attempts, :integer, default: 3, null: false
      add :error_message, :text
      add :audiobook_id, references(:audiobooks, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:queue_items, [:audiobook_id])
    create index(:queue_items, [:status])
    create index(:queue_items, [:priority])
  end
end
