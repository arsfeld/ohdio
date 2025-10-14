defmodule Ohdio.DownloadsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Ohdio.Downloads` context.
  """

  @doc """
  Generate a queue_item.
  """
  def queue_item_fixture(attrs \\ %{}) do
    # Create an audiobook if not provided
    audiobook_id =
      case Map.get(attrs, :audiobook_id) do
        nil ->
          audiobook = Ohdio.LibraryFixtures.audiobook_fixture()
          audiobook.id

        id ->
          id
      end

    {:ok, queue_item} =
      attrs
      |> Enum.into(%{
        audiobook_id: audiobook_id,
        attempts: 0,
        error_message: nil,
        max_attempts: 3,
        priority: 5,
        status: :queued
      })
      |> Ohdio.Downloads.create_queue_item()

    queue_item
  end
end
