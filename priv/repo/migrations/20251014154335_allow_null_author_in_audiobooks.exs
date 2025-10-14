defmodule Ohdio.Repo.Migrations.AllowNullAuthorInAudiobooks do
  use Ecto.Migration

  def up do
    # SQLite doesn't support modifying column constraints directly
    # We need to recreate the table with the new schema

    # Create temporary table with correct schema
    create table(:audiobooks_temp) do
      add :title, :string, null: false
      # Changed to allow NULL
      add :author, :string, null: true
      add :narrator, :string
      add :url, :string, null: false
      add :cover_image_url, :string
      add :duration, :integer
      add :file_size, :integer
      add :file_path, :string
      add :status, :string, default: "pending", null: false

      timestamps(type: :utc_datetime)
    end

    # Copy data from old table to new table
    execute """
    INSERT INTO audiobooks_temp (id, title, author, narrator, url, cover_image_url, duration, file_size, file_path, status, inserted_at, updated_at)
    SELECT id, title, author, narrator, url, cover_image_url, duration, file_size, file_path, status, inserted_at, updated_at
    FROM audiobooks
    """

    # Drop old table
    drop table(:audiobooks)

    # Rename temp table to audiobooks
    rename table(:audiobooks_temp), to: table(:audiobooks)

    # Recreate indexes
    create index(:audiobooks, [:status])
    create unique_index(:audiobooks, [:url])
  end

  def down do
    # Reverse: make author NOT NULL again
    create table(:audiobooks_temp) do
      add :title, :string, null: false
      # Back to NOT NULL
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

    execute """
    INSERT INTO audiobooks_temp (id, title, author, narrator, url, cover_image_url, duration, file_size, file_path, status, inserted_at, updated_at)
    SELECT id, title, COALESCE(author, 'Unknown'), narrator, url, cover_image_url, duration, file_size, file_path, status, inserted_at, updated_at
    FROM audiobooks
    """

    drop table(:audiobooks)
    rename table(:audiobooks_temp), to: table(:audiobooks)

    create index(:audiobooks, [:status])
    create unique_index(:audiobooks, [:url])
  end
end
