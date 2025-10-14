defmodule Ohdio.Library.ThumbnailGenerator do
  @moduledoc """
  Handles thumbnail generation from audio files using ffmpeg.
  """

  @doc """
  Extracts or generates a thumbnail from an audio file.

  Returns `{:ok, thumbnail_path}` if successful, or `{:error, reason}` if it fails.

  If the audio file has embedded artwork, it extracts it.
  Otherwise, it returns an error and the caller should use a placeholder.
  """
  def generate_thumbnail(audio_file_path, output_path \\ nil) do
    unless File.exists?(audio_file_path) do
      {:error, :file_not_found}
    else
      output_path = output_path || generate_output_path(audio_file_path)
      extract_embedded_artwork(audio_file_path, output_path)
    end
  end

  defp extract_embedded_artwork(audio_file_path, output_path) do
    # Create output directory if it doesn't exist
    output_dir = Path.dirname(output_path)
    File.mkdir_p!(output_dir)

    # Try to extract embedded artwork using ffmpeg
    args = [
      "-i",
      audio_file_path,
      # Disable audio
      "-an",
      # Copy the video stream (album art)
      "-vcodec",
      "copy",
      # Overwrite output file
      "-y",
      output_path
    ]

    case System.cmd("ffmpeg", args, stderr_to_stdout: true) do
      {_output, 0} ->
        {:ok, output_path}

      {_output, _exit_code} ->
        {:error, :no_embedded_artwork}
    end
  rescue
    _ -> {:error, :extraction_failed}
  end

  defp generate_output_path(audio_file_path) do
    base_path = Path.rootname(audio_file_path)
    "#{base_path}_thumbnail.jpg"
  end

  @doc """
  Ensures an audiobook has a thumbnail.

  If the audiobook has a cover_image_url, it returns it.
  If the audiobook has a file_path with embedded artwork, it extracts the thumbnail.
  Otherwise, it returns nil (caller should use placeholder).
  """
  def ensure_thumbnail(audiobook) do
    cond do
      # Already has a cover image URL
      audiobook.cover_image_url ->
        {:ok, audiobook.cover_image_url}

      # Try to extract from audio file
      audiobook.file_path && File.exists?(audiobook.file_path) ->
        thumbnail_path = generate_output_path(audiobook.file_path)

        if File.exists?(thumbnail_path) do
          {:ok, thumbnail_path}
        else
          generate_thumbnail(audiobook.file_path, thumbnail_path)
        end

      # No thumbnail available
      true ->
        {:error, :no_thumbnail_available}
    end
  end
end
