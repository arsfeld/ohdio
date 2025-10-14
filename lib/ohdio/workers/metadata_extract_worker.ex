defmodule Ohdio.Workers.MetadataExtractWorker do
  @moduledoc """
  Oban worker for extracting audiobook metadata with fallback to yt-dlp.

  This worker:
  1. Attempts to scrape metadata from OHdio pages
  2. Falls back to yt-dlp for URLs not supported by native scraping
  3. Updates the audiobook record with complete metadata
  4. Enqueues a download job if metadata extraction succeeds
  """
  use Oban.Worker, queue: :metadata, max_attempts: 3

  alias Ohdio.{Library, Scraper, Downloads, Repo}
  alias Ohdio.Workers.DownloadWorker
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"audiobook_id" => audiobook_id, "url" => url}}) do
    audiobook = Library.get_audiobook!(audiobook_id)

    case extract_metadata(url, audiobook) do
      {:ok, updated_audiobook} ->
        # Get or create queue item
        queue_item =
          case Repo.get_by(Downloads.QueueItem, audiobook_id: updated_audiobook.id) do
            nil ->
              # Create new queue item
              {:ok, qi} =
                Downloads.create_queue_item(%{
                  audiobook_id: updated_audiobook.id,
                  status: :queued,
                  priority: 5
                })

              qi

            existing_item ->
              # Use existing queue item (created by CategoryScrapeWorker)
              existing_item
          end

        # Only enqueue download if file doesn't exist and queue item is queued
        file_exists? =
          case updated_audiobook.file_path do
            nil -> false
            path -> File.exists?(path)
          end

        if not file_exists? and queue_item.status == :queued do
          %{queue_item_id: queue_item.id, audiobook_id: updated_audiobook.id}
          |> DownloadWorker.new()
          |> Oban.insert()
        end

        {:ok, %{audiobook_id: updated_audiobook.id}}

      {:error, reason} ->
        Library.update_audiobook(audiobook, %{status: :failed})
        {:error, reason}
    end
  end

  defp extract_metadata(url, audiobook) do
    url_type = Scraper.detect_url_type(url)

    case url_type do
      type when type in [:ohdio_audiobook, :ohdio_category] ->
        extract_ohdio_metadata(url, audiobook)

      :ytdlp_passthrough ->
        extract_ytdlp_metadata(url, audiobook)

      :unknown ->
        # Try yt-dlp as fallback
        extract_ytdlp_metadata(url, audiobook)
    end
  end

  defp extract_ohdio_metadata(url, audiobook) do
    case Scraper.scrape_audiobook(url) do
      {:ok, metadata} ->
        Library.update_audiobook(audiobook, %{
          title: metadata.title || audiobook.title,
          author: metadata.author || audiobook.author,
          narrator: metadata.narrator || audiobook.narrator,
          cover_image_url: metadata.thumbnail_url || audiobook.cover_image_url,
          duration: metadata.duration
        })

      {:error, reason} ->
        Logger.warning(
          "OHdio metadata extraction failed for #{url}, trying yt-dlp fallback: #{inspect(reason)}"
        )

        extract_ytdlp_metadata(url, audiobook)
    end
  end

  defp extract_ytdlp_metadata(url, audiobook) do
    case System.cmd("yt-dlp", [
           "--dump-json",
           "--no-playlist",
           url
         ]) do
      {output, 0} ->
        metadata = Jason.decode!(output)

        Library.update_audiobook(audiobook, %{
          title: metadata["title"] || audiobook.title,
          duration: metadata["duration"] && round(metadata["duration"]),
          cover_image_url: metadata["thumbnail"] || audiobook.cover_image_url
        })

      {error, _code} ->
        Logger.error("yt-dlp metadata extraction failed for #{url}: #{error}")
        {:error, :ytdlp_failed}
    end
  rescue
    e ->
      Logger.error("Error extracting metadata with yt-dlp: #{inspect(e)}")
      {:error, :ytdlp_error}
  end
end
