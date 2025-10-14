defmodule Ohdio.Workers.CategoryScrapeWorker do
  @moduledoc """
  Oban worker for scraping category pages and enqueuing metadata extraction jobs.

  This worker:
  1. Creates a CategoryScrape record to track progress
  2. Scrapes a category page to discover audiobooks
  3. Creates audiobook records in the database
  4. Enqueues MetadataExtract jobs for each discovered audiobook
  5. Updates the CategoryScrape record with results
  6. Broadcasts updates via PubSub for real-time UI updates
  """
  use Oban.Worker, queue: :scraping, max_attempts: 3

  alias Ohdio.{Downloads, Library, Scraper}
  alias Ohdio.Workers.MetadataExtractWorker

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"category_url" => category_url, "scrape_id" => scrape_id}}) do
    scrape = Library.get_category_scrape!(scrape_id)

    case Scraper.scrape_category(category_url) do
      {:ok, audiobooks} ->
        count = length(audiobooks)
        enqueue_metadata_jobs(audiobooks)

        # Update scrape record as completed
        {:ok, updated_scrape} =
          Library.update_category_scrape(scrape, %{
            status: :completed,
            total_count: count
          })

        # Broadcast completion
        broadcast_scrape_update(updated_scrape)

        {:ok, %{count: count}}

      {:error, reason} ->
        error_message = "Failed to scrape category: #{inspect(reason)}"

        # Update scrape record as failed
        {:ok, updated_scrape} =
          Library.update_category_scrape(scrape, %{
            status: :failed,
            error_message: error_message
          })

        # Broadcast failure
        broadcast_scrape_update(updated_scrape)

        {:error, reason}
    end
  end

  def perform(%Oban.Job{args: %{"scrape_id" => scrape_id}}) do
    # Default category (Jeunesse)
    scrape = Library.get_category_scrape!(scrape_id)

    case Scraper.scrape_category() do
      {:ok, audiobooks} ->
        count = length(audiobooks)
        enqueue_metadata_jobs(audiobooks)

        # Update scrape record as completed
        {:ok, updated_scrape} =
          Library.update_category_scrape(scrape, %{
            status: :completed,
            total_count: count
          })

        # Broadcast completion
        broadcast_scrape_update(updated_scrape)

        {:ok, %{count: count}}

      {:error, reason} ->
        error_message = "Failed to scrape category: #{inspect(reason)}"

        # Update scrape record as failed
        {:ok, updated_scrape} =
          Library.update_category_scrape(scrape, %{
            status: :failed,
            error_message: error_message
          })

        # Broadcast failure
        broadcast_scrape_update(updated_scrape)

        {:error, reason}
    end
  end

  defp enqueue_metadata_jobs(audiobooks) do
    Enum.each(audiobooks, fn book_info ->
      # Create or get existing audiobook record
      audiobook =
        case Library.create_audiobook(%{
               title: book_info.title,
               author: book_info.author,
               url: book_info.url,
               cover_image_url: book_info.thumbnail_url
             }) do
          {:ok, audiobook} ->
            audiobook

          {:error, %Ecto.Changeset{errors: [url: {"has already been taken", _}]}} ->
            # Audiobook already exists, fetch it
            Ohdio.Repo.get_by(Ohdio.Library.Audiobook, url: book_info.url)

          {:error, _changeset} ->
            # Other error, skip this audiobook
            nil
        end

      # Only proceed if we have a valid audiobook
      if audiobook do
        # Check if file exists on filesystem - this is the source of truth
        file_exists? =
          case audiobook.file_path do
            nil -> false
            path -> File.exists?(path)
          end

        # Only queue for download if file doesn't exist
        if not file_exists? do
          # Check if there's already a queue item for this audiobook
          existing_queue_item =
            Ohdio.Repo.get_by(Ohdio.Downloads.QueueItem, audiobook_id: audiobook.id)

          queue_item =
            case existing_queue_item do
              nil ->
                # Create new queue item
                case Downloads.create_queue_item(%{
                       audiobook_id: audiobook.id,
                       status: :queued,
                       priority: 5
                     }) do
                  {:ok, qi} -> qi
                  {:error, _} -> nil
                end

              qi ->
                # Use existing queue item
                qi
            end

          # Enqueue jobs if we have a valid queue item
          if queue_item do
            # Enqueue metadata extraction job
            # MetadataExtractWorker will automatically enqueue DownloadWorker
            # respecting the configured max_concurrent_downloads limit
            %{audiobook_id: audiobook.id, url: book_info.url}
            |> MetadataExtractWorker.new()
            |> Oban.insert()
          end
        end
      end
    end)
  end

  defp broadcast_scrape_update(scrape) do
    Phoenix.PubSub.broadcast(
      Ohdio.PubSub,
      "category_scrapes",
      {:category_scrape_updated, scrape}
    )
  end
end
