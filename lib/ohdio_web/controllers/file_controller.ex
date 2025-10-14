defmodule OhdioWeb.FileController do
  use OhdioWeb, :controller

  alias Ohdio.Library

  @doc """
  Serves audio files with HTTP range support for streaming.
  """
  def audio(conn, %{"id" => id}) do
    audiobook = Library.get_audiobook!(id)

    if audiobook.file_path && File.exists?(audiobook.file_path) do
      filename = generate_filename(audiobook)
      serve_file_with_range(conn, audiobook.file_path, filename)
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "File not found"})
    end
  end

  @doc """
  Serves cover images.
  """
  def cover(conn, %{"id" => id}) do
    audiobook = Library.get_audiobook!(id)

    if audiobook.cover_image_url do
      # If it's a local file path, serve it
      if File.exists?(audiobook.cover_image_url) do
        conn
        |> put_resp_content_type("image/jpeg")
        |> send_file(200, audiobook.cover_image_url)
      else
        # If it's a URL, redirect to it
        redirect(conn, external: audiobook.cover_image_url)
      end
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "Cover image not found"})
    end
  end

  defp serve_file_with_range(conn, file_path, filename) do
    file_stat = File.stat!(file_path)
    file_size = file_stat.size

    case get_req_header(conn, "range") do
      [] ->
        # No range header, serve entire file
        conn
        |> put_resp_content_type(get_content_type(file_path))
        |> put_resp_header("accept-ranges", "bytes")
        |> put_resp_header("content-length", to_string(file_size))
        |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
        |> send_file(200, file_path)

      [range_header | _] ->
        # Parse range header and serve requested byte range
        case parse_range_header(range_header, file_size) do
          {:ok, range_start, range_end} ->
            content_length = range_end - range_start + 1

            conn
            |> put_resp_content_type(get_content_type(file_path))
            |> put_resp_header("accept-ranges", "bytes")
            |> put_resp_header("content-range", "bytes #{range_start}-#{range_end}/#{file_size}")
            |> put_resp_header("content-length", to_string(content_length))
            |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
            |> send_file(206, file_path, range_start, content_length)

          {:error, _reason} ->
            conn
            |> put_status(:requested_range_not_satisfiable)
            |> put_resp_header("content-range", "bytes */#{file_size}")
            |> json(%{error: "Invalid range"})
        end
    end
  end

  defp parse_range_header("bytes=" <> range, file_size) do
    case String.split(range, "-", parts: 2) do
      [start_str, end_str] ->
        start = if start_str == "", do: 0, else: String.to_integer(start_str)
        range_end = if end_str == "", do: file_size - 1, else: String.to_integer(end_str)

        if start >= 0 and range_end >= start and range_end < file_size do
          {:ok, start, range_end}
        else
          {:error, :invalid_range}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  defp parse_range_header(_, _), do: {:error, :invalid_format}

  defp generate_filename(audiobook) do
    # Sanitize title and author for use in filename
    title = sanitize_filename(audiobook.title || "Unknown")
    author = sanitize_filename(audiobook.author || "Unknown")

    # Get file extension from original file
    extension = Path.extname(audiobook.file_path)

    # Format: "Title - Author.ext"
    "#{title} - #{author}#{extension}"
  end

  defp sanitize_filename(string) do
    string
    # Remove or replace invalid filename characters
    |> String.replace(~r/[<>:\"\/\\|?*]/, "")
    # Replace multiple spaces with single space
    |> String.replace(~r/\s+/, " ")
    # Trim whitespace
    |> String.trim()
    # Limit length to avoid issues with long filenames
    |> String.slice(0, 100)
  end

  defp get_content_type(file_path) do
    case Path.extname(file_path) |> String.downcase() do
      ".mp3" -> "audio/mpeg"
      ".m4a" -> "audio/mp4"
      ".m4b" -> "audio/mp4"
      ".ogg" -> "audio/ogg"
      ".opus" -> "audio/opus"
      ".wav" -> "audio/wav"
      ".flac" -> "audio/flac"
      _ -> "application/octet-stream"
    end
  end
end
