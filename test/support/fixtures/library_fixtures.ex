defmodule Ohdio.LibraryFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Ohdio.Library` context.
  """

  @doc """
  Generate a audiobook.
  """
  def audiobook_fixture(attrs \\ %{}) do
    # Generate unique URL to avoid conflicts
    unique_id = System.unique_integer([:positive])

    {:ok, audiobook} =
      attrs
      |> Enum.into(%{
        author: "Test Author",
        cover_image_url: "https://example.com/cover.jpg",
        duration: 3600,
        file_path: nil,
        file_size: nil,
        narrator: "Test Narrator",
        status: :pending,
        title: "Test Audiobook",
        url: "https://example.com/audiobook/#{unique_id}"
      })
      |> Ohdio.Library.create_audiobook()

    audiobook
  end
end
