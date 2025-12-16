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
    # Get existing queue item (created when URL was submitted)
    queue_item = Repo.get_by(Downloads.QueueItem, audiobook_id: audiobook_id)

    case extract_metadata(url, audiobook) do
      {:ok, updated_audiobook} ->
        # Ensure queue item exists (fallback for legacy jobs or category scrapes)
        queue_item =
          case queue_item do
            nil ->
              {:ok, qi} =
                Downloads.create_queue_item(%{
                  audiobook_id: updated_audiobook.id,
                  status: :queued,
                  priority: 5
                })

              qi

            existing_item ->
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

        # Mark queue item as failed so user sees the error in the UI
        if queue_item do
          Downloads.update_queue_item(queue_item, %{
            status: :failed,
            error_message: format_error(reason)
          })
        end

        {:error, reason}
    end
  end

  defp format_error(reason) when is_atom(reason), do: Atom.to_string(reason) |> String.replace("_", " ")
  defp format_error(reason), do: inspect(reason)

  defp extract_metadata(url, audiobook) do
    url_type = Scraper.detect_url_type(url)

    case url_type do
      type when type in [:ohdio_audiobook, :ohdio_category] ->
        extract_ohdio_metadata(url, audiobook)

      type when type in [:spotify_track, :spotify_playlist, :spotify_album] ->
        extract_spotify_metadata(url, audiobook)

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

  defp extract_spotify_metadata(url, audiobook) do
    # Create a temp file for spotdl output
    temp_file = Path.join(System.tmp_dir!(), "spotdl_#{audiobook.id}.spotdl")

    try do
      case System.cmd("spotdl", ["save", url, "--save-file", temp_file], stderr_to_stdout: true) do
        {_output, 0} ->
          case File.read(temp_file) do
            {:ok, content} ->
              case Jason.decode(content) do
                {:ok, [first_track | _]} ->
                  Library.update_audiobook(audiobook, %{
                    title: first_track["name"] || audiobook.title,
                    author: first_track["artist"] || audiobook.author,
                    duration: first_track["duration"],
                    cover_image_url: first_track["cover_url"] || audiobook.cover_image_url
                  })

                {:ok, []} ->
                  Logger.error("spotdl returned empty track list for #{url}")
                  {:error, :spotify_no_tracks}

                {:error, decode_error} ->
                  Logger.error("Failed to parse spotdl output: #{inspect(decode_error)}")
                  {:error, :spotify_parse_failed}
              end

            {:error, read_error} ->
              Logger.error("Failed to read spotdl output file: #{inspect(read_error)}")
              {:error, :spotify_read_failed}
          end

        {error, _code} ->
          Logger.error("spotdl metadata extraction failed for #{url}: #{error}")
          {:error, :spotify_failed}
      end
    after
      File.rm(temp_file)
    end
  rescue
    e ->
      Logger.error("Error extracting Spotify metadata: #{inspect(e)}")
      {:error, :spotify_error}
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
