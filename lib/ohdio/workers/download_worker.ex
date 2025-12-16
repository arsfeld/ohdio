defmodule Ohdio.Workers.DownloadWorker do
  @moduledoc """
  Oban worker for downloading audiobooks with yt-dlp and embedding metadata with FFmpeg.

  This worker:
  1. Checks if queue is paused and waits if necessary
  2. Downloads audiobook using yt-dlp
  3. Embeds metadata using FFmpeg
  4. Broadcasts progress updates via PubSub
  5. Updates audiobook and queue item status
  """
  use Oban.Worker, queue: :downloads, max_attempts: 3

  alias Ohdio.{Library, Downloads, Scraper, Repo}
  require Logger

  # Configuration is fetched at runtime to support environment variables
  defp download_dir do
    Application.get_env(:ohdio, :downloads, [])
    |> Keyword.get(:output_dir, "priv/static/downloads")
  end

  defp min_disk_space_mb do
    Application.get_env(:ohdio, :downloads, [])
    |> Keyword.get(:min_disk_space_mb, 100)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"queue_item_id" => queue_item_id, "audiobook_id" => audiobook_id}
      }) do
    # Check if queue item and audiobook still exist
    # If not, discard the job (they may have been deleted by user)
    with {:ok, queue_item} <- fetch_queue_item(queue_item_id),
         {:ok, audiobook} <- fetch_audiobook(audiobook_id) do
      # Check if queue is paused
      if Downloads.paused?() do
        # Snooze the job to retry later
        {:snooze, 60}
      else
        process_download(queue_item, audiobook)
      end
    else
      {:error, :not_found, resource} ->
        Logger.warning(
          "#{resource} not found for download job (queue_item: #{queue_item_id}, audiobook: #{audiobook_id}), discarding job"
        )

        {:discard, :resource_not_found}
    end
  end

  defp fetch_queue_item(queue_item_id) do
    case Repo.get(Downloads.QueueItem, queue_item_id) do
      nil -> {:error, :not_found, "Queue item"}
      queue_item -> {:ok, queue_item}
    end
  end

  defp fetch_audiobook(audiobook_id) do
    case Repo.get(Library.Audiobook, audiobook_id) do
      nil -> {:error, :not_found, "Audiobook"}
      audiobook -> {:ok, audiobook}
    end
  end

  defp process_download(queue_item, audiobook) do
    # Update statuses
    Downloads.update_queue_item(queue_item, %{status: :processing})
    Library.update_audiobook(audiobook, %{status: :downloading})

    # Broadcast progress
    broadcast_progress(audiobook.id, :started, 0)

    # Validate download directory and disk space
    case validate_download_prerequisites(download_dir()) do
      :ok ->
        perform_download(queue_item, audiobook)

      {:error, reason} ->
        error_msg = format_error_message(reason)
        Logger.error("Download prerequisites failed for audiobook #{audiobook.id}: #{error_msg}")
        handle_error(queue_item, audiobook, reason)
    end
  end

  defp perform_download(queue_item, audiobook) do
    # Sanitize filename - ASCII only to avoid encoding issues
    sanitized_title = sanitize_filename(audiobook.title)

    output_path = Path.join(download_dir(), "#{sanitized_title}.mp3")

    # Download with yt-dlp
    case download_audiobook(audiobook.url, output_path, audiobook.id) do
      {:ok, final_path} ->
        # Embed metadata with FFmpeg
        case embed_metadata(final_path, audiobook) do
          :ok ->
            file_size = File.stat!(final_path).size

            # Update both records atomically - audiobook first, then queue item
            # Use a transaction to ensure consistency
            # Include default author if missing (required for non-pending status)
            update_attrs = %{
              status: :completed,
              file_path: final_path,
              file_size: file_size
            }

            update_attrs =
              if is_nil(audiobook.author) or audiobook.author == "" do
                Map.put(update_attrs, :author, "Unknown")
              else
                update_attrs
              end

            result =
              Repo.transaction(fn ->
                case Library.update_audiobook(audiobook, update_attrs) do
                  {:ok, _} ->
                    Downloads.update_queue_item(queue_item, %{status: :completed})

                  {:error, changeset} ->
                    Repo.rollback(changeset)
                end
              end)

            case result do
              {:ok, _} ->
                # Broadcast completion
                broadcast_progress(audiobook.id, :completed, 100)
                {:ok, %{file_path: final_path, file_size: file_size}}

              {:error, reason} ->
                Logger.error("Failed to update records after download: #{inspect(reason)}")
                handle_error(queue_item, audiobook, :record_update_failed)
            end

          {:error, reason} ->
            handle_error(queue_item, audiobook, reason)
        end

      {:error, reason} ->
        handle_error(queue_item, audiobook, reason)
    end
  end

  # Sanitize filename to ASCII-only characters to avoid encoding issues
  defp sanitize_filename(title) do
    title
    # Normalize Unicode to decomposed form, then remove non-ASCII
    |> String.normalize(:nfd)
    |> String.replace(~r/[^\x00-\x7F]/, "")
    # Keep only alphanumeric, spaces, and hyphens
    |> String.replace(~r/[^a-zA-Z0-9\s-]/, "")
    # Replace whitespace with underscores
    |> String.replace(~r/\s+/, "_")
    # Remove consecutive underscores
    |> String.replace(~r/_+/, "_")
    # Trim underscores from ends
    |> String.trim("_")
    # Limit length
    |> String.slice(0, 200)
    # Fallback if empty
    |> then(fn s -> if s == "", do: "untitled", else: s end)
  end

  # Sanitize string for safe logging (removes non-printable and problematic Unicode)
  defp sanitize_for_logging(str) when is_binary(str) do
    str
    |> String.replace(~r/[^\x20-\x7E]/, "")
    |> String.slice(0, 100)
  end

  defp sanitize_for_logging(nil), do: ""

  defp download_audiobook(url, output_path, audiobook_id) do
    url_type = Scraper.detect_url_type(url)
    Logger.debug("Detected URL type: #{inspect(url_type)} for #{url}")

    # Handle Spotify URLs with spotdl
    if url_type in [:spotify_track, :spotify_playlist, :spotify_album] do
      execute_spotdl_download(url, output_path, audiobook_id)
    else
      # For OHdio URLs, extract the actual m3u8 playlist URL first
      with {:ok, download_url} <- resolve_download_url(url, url_type) do
        Logger.debug(
          "Resolved download URL: #{inspect(download_url)}, output: #{inspect(output_path)}"
        )

        execute_ytdlp_download(download_url, output_path, audiobook_id)
      end
    end
  rescue
    e ->
      Logger.error("Error during download: #{inspect(e)}")
      Logger.error("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
      {:error, :download_error}
  end

  defp resolve_download_url(url, url_type) do
    case url_type do
      type when type in [:ohdio_audiobook, :ohdio_category] ->
        Logger.info("Extracting playlist URL from OHdio page...")

        case extract_ohdio_playlist_url(url) do
          {:ok, playlist_url} ->
            Logger.info("Extracted playlist URL: #{playlist_url}")
            {:ok, playlist_url}

          {:error, _reason} ->
            {:error, :playlist_extraction_failed}
        end

      _ ->
        # For other URLs, use the URL directly
        {:ok, url}
    end
  end

  defp execute_ytdlp_download(download_url, output_path, audiobook_id) do
    # Validate inputs are strings
    unless is_binary(download_url) and is_binary(output_path) do
      Logger.error(
        "Invalid arguments for yt-dlp: download_url=#{inspect(download_url)}, output_path=#{inspect(output_path)}"
      )

      {:error, :invalid_arguments}
    else
      args = [
        "-f",
        "bestaudio",
        "-o",
        output_path,
        "--extract-audio",
        "--audio-format",
        "mp3",
        download_url
      ]

      Logger.info("Starting download: yt-dlp #{Enum.join(args, " ")}")

      case System.cmd("yt-dlp", args, stderr_to_stdout: true) do
        {_output, 0} ->
          # yt-dlp might add extension, find the actual file
          actual_path =
            if File.exists?(output_path) do
              output_path
            else
              # Try with .mp3 extension added
              Path.rootname(output_path) <> ".mp3"
            end

          if File.exists?(actual_path) do
            broadcast_progress(audiobook_id, :downloading, 50)
            {:ok, actual_path}
          else
            {:error, :file_not_found}
          end

        {error, code} ->
          Logger.error("yt-dlp download failed (exit #{code}): #{error}")
          {:error, :download_failed}
      end
    end
  end

  defp extract_ohdio_playlist_url(url) do
    # Fetch the OHdio page HTML
    case Ohdio.Scraper.HttpClient.get(url) do
      {:ok, html_content} ->
        # Extract the playlist URL using the PlaylistExtractor
        Ohdio.Scraper.PlaylistExtractor.extract_playlist_url(html_content, url)

      {:error, reason} ->
        Logger.error("Failed to fetch OHdio page: #{inspect(reason)}")
        {:error, :page_fetch_failed}
    end
  end

  defp execute_spotdl_download(spotify_url, output_path, audiobook_id) do
    # Validate inputs are strings
    unless is_binary(spotify_url) and is_binary(output_path) do
      Logger.error(
        "Invalid arguments for spotdl: spotify_url=#{inspect(spotify_url)}, output_path=#{inspect(output_path)}"
      )

      {:error, :invalid_arguments}
    else
      # spotdl downloads to current directory, so we need to specify the output directory
      output_dir = Path.dirname(output_path)

      # spotdl arguments
      args = [
        "download",
        spotify_url,
        "--output",
        output_dir,
        "--format",
        "mp3",
        "--bitrate",
        "320k"
      ]

      Logger.info("Starting Spotify download: spotdl #{Enum.join(args, " ")}")

      case System.cmd("spotdl", args, stderr_to_stdout: true) do
        {output, 0} ->
          Logger.info("spotdl output: #{output}")
          broadcast_progress(audiobook_id, :downloading, 50)

          # spotdl creates files with naming pattern: "Artist - Song.mp3"
          # Find the downloaded files in the output directory
          case find_latest_files_in_directory(output_dir, ".mp3") do
            {:ok, [file | _rest]} ->
              # For now, return the first file (single track or first track of playlist/album)
              # TODO: In the future, we could handle multiple files better
              {:ok, file}

            {:ok, []} ->
              Logger.error("No MP3 files found after spotdl download")
              {:error, :file_not_found}

            {:error, reason} ->
              Logger.error("Failed to find downloaded files: #{inspect(reason)}")
              {:error, :file_not_found}
          end

        {error, code} ->
          Logger.error("spotdl download failed (exit #{code}): #{error}")
          {:error, :download_failed}
      end
    end
  end

  defp find_latest_files_in_directory(directory, extension) do
    try do
      files =
        File.ls!(directory)
        |> Enum.filter(&String.ends_with?(&1, extension))
        |> Enum.map(&Path.join(directory, &1))
        |> Enum.sort_by(&File.stat!(&1).mtime, :desc)

      {:ok, files}
    rescue
      e ->
        Logger.error("Error listing files in #{directory}: #{inspect(e)}")
        {:error, :directory_read_error}
    end
  end

  defp embed_metadata(file_path, audiobook) do
    temp_path = file_path <> ".tmp.mp3"

    args = [
      "-i",
      file_path,
      "-metadata",
      "title=#{audiobook.title}",
      "-metadata",
      "artist=#{audiobook.author}",
      "-metadata",
      "album_artist=#{audiobook.narrator}",
      "-codec",
      "copy",
      temp_path
    ]

    # Log with sanitized title to avoid JSON encoding issues with emoji
    Logger.info("Embedding metadata for: #{sanitize_for_logging(audiobook.title)}")

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_output, 0} ->
        # Replace original with metadata-embedded version
        File.rm!(file_path)
        File.rename!(temp_path, file_path)
        :ok

      {error, code} ->
        Logger.error("FFmpeg metadata embedding failed (exit #{code}): #{error}")
        # Clean up temp file if it exists
        File.rm(temp_path)
        {:error, :metadata_embed_failed}
    end
  rescue
    e ->
      Logger.error("Error embedding metadata: #{inspect(e)}")
      {:error, :metadata_embed_error}
  end

  defp handle_error(queue_item, audiobook, reason) do
    # Increment attempts
    updated_attempts = queue_item.attempts + 1
    error_message = format_error_message(reason)

    if updated_attempts >= queue_item.max_attempts do
      # Max attempts reached, mark as failed
      Logger.error(
        "Audiobook #{audiobook.id} failed after #{updated_attempts} attempts: #{error_message}"
      )

      Downloads.update_queue_item(queue_item, %{
        status: :failed,
        attempts: updated_attempts,
        error_message: error_message
      })

      Library.update_audiobook(audiobook, %{status: :failed})

      broadcast_progress(audiobook.id, :failed, 0)

      {:error, reason}
    else
      # Retry
      Logger.warning(
        "Audiobook #{audiobook.id} failed (attempt #{updated_attempts}/#{queue_item.max_attempts}): #{error_message}, retrying..."
      )

      Downloads.update_queue_item(queue_item, %{attempts: updated_attempts})
      {:error, reason}
    end
  end

  defp broadcast_progress(audiobook_id, status, progress) do
    Phoenix.PubSub.broadcast(
      Ohdio.PubSub,
      "downloads",
      {:download_progress, %{audiobook_id: audiobook_id, status: status, progress: progress}}
    )
  end

  defp validate_download_prerequisites(download_dir) do
    with :ok <- ensure_directory_exists(download_dir),
         :ok <- check_directory_writable(download_dir),
         :ok <- check_disk_space(download_dir) do
      :ok
    end
  end

  defp ensure_directory_exists(dir) do
    case File.mkdir_p(dir) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to create download directory #{dir}: #{inspect(reason)}")
        {:error, {:directory_creation_failed, reason}}
    end
  end

  defp check_directory_writable(dir) do
    test_file = Path.join(dir, ".write_test_#{:os.system_time(:millisecond)}")

    case File.write(test_file, "test") do
      :ok ->
        File.rm(test_file)
        :ok

      {:error, reason} ->
        Logger.error("Download directory #{dir} is not writable: #{inspect(reason)}")
        {:error, {:directory_not_writable, reason}}
    end
  end

  defp check_disk_space(dir) do
    # Get available disk space (in bytes)
    case get_available_disk_space(dir) do
      {:ok, available_bytes} ->
        # Require configured minimum free space
        min_space_mb = min_disk_space_mb()
        min_required = min_space_mb * 1024 * 1024

        if available_bytes >= min_required do
          :ok
        else
          available_mb = div(available_bytes, 1024 * 1024)

          Logger.error(
            "Insufficient disk space: #{available_mb}MB available, need at least #{min_space_mb}MB"
          )

          {:error, {:insufficient_disk_space, available_mb}}
        end

      {:error, reason} ->
        Logger.warning("Could not check disk space: #{inspect(reason)}, proceeding anyway")
        :ok
    end
  end

  defp get_available_disk_space(dir) do
    case System.cmd("df", ["-k", dir]) do
      {output, 0} ->
        # Parse df output to get available space
        lines = String.split(output, "\n", trim: true)

        if length(lines) >= 2 do
          # Second line contains the stats
          stats = lines |> Enum.at(1) |> String.split() |> Enum.filter(&(&1 != ""))
          # Available space is typically the 4th column (in KB)
          available_kb = stats |> Enum.at(3) |> String.to_integer()
          {:ok, available_kb * 1024}
        else
          {:error, :parse_error}
        end

      {_error, _code} ->
        {:error, :command_failed}
    end
  rescue
    _ -> {:error, :unexpected_error}
  end

  defp format_error_message(error) do
    case error do
      {:directory_creation_failed, reason} ->
        "Failed to create download directory: #{inspect(reason)}"

      {:directory_not_writable, reason} ->
        "Download directory is not writable: #{inspect(reason)}"

      {:insufficient_disk_space, available_mb} ->
        "Insufficient disk space: only #{available_mb}MB available, need at least #{min_disk_space_mb()}MB"

      :playlist_extraction_failed ->
        "Failed to extract media URL from OHdio page"

      :page_fetch_failed ->
        "Failed to fetch OHdio page for playlist extraction"

      :invalid_arguments ->
        "Invalid arguments provided to download command"

      :file_not_found ->
        "Downloaded file not found after completion"

      :download_failed ->
        "Download command failed - possible reasons: invalid URL, region lock, premium content, or network issue"

      :download_error ->
        "Unexpected error during download"

      :metadata_embed_failed ->
        "FFmpeg failed to embed metadata"

      :metadata_embed_error ->
        "Unexpected error while embedding metadata"

      :directory_read_error ->
        "Failed to read download directory after completion"

      :spotify_download_failed ->
        "Spotify download failed - the track may be region-locked, require premium access, or not be available on YouTube Music"

      :spotify_no_results ->
        "No matching tracks found on YouTube Music for this Spotify URL"

      :record_update_failed ->
        "Failed to update database records after successful download"

      _ ->
        "Unknown error: #{inspect(error)}"
    end
  end
end
