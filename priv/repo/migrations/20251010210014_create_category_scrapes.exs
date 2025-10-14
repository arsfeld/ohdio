defmodule Ohdio.Repo.Migrations.CreateCategoryScrapes do
  use Ecto.Migration

  def change do
    create table(:category_scrapes) do
      add :category_url, :string, null: false
      add :status, :string, default: "scraping", null: false
      add :total_count, :integer
      add :error_message, :text
      add :oban_job_id, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:category_scrapes, [:status])
    create index(:category_scrapes, [:oban_job_id])
  end
end
