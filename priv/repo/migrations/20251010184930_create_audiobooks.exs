defmodule Ohdio.Repo.Migrations.CreateAudiobooks do
  use Ecto.Migration

  def change do
    create table(:audiobooks) do
      add :title, :string, null: false
      add :author, :string, null: false
      add :narrator, :string
      add :url, :string, null: false
      add :cover_image_url, :string
      add :duration, :integer
      add :file_size, :integer
      add :file_path, :string
      add :status, :string, default: "pending", null: false

      timestamps(type: :utc_datetime)
    end

    create index(:audiobooks, [:status])
    create unique_index(:audiobooks, [:url])
  end
end
