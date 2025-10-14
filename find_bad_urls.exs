#!/usr/bin/env elixir

alias Ohdio.{Library, Repo}
import Ecto.Query

IO.puts("\n=== Finding Audiobooks with Category URLs ===\n")

# Find audiobooks with category URLs
bad_audiobooks =
  Repo.all(
    from a in Library.Audiobook,
      where: fragment("? LIKE '%categories%'", a.url)
  )

IO.puts("Found #{length(bad_audiobooks)} audiobooks with category URLs:")

Enum.each(bad_audiobooks, fn audiobook ->
  IO.puts("\nID: #{audiobook.id}")
  IO.puts("Title: #{audiobook.title}")
  IO.puts("URL: #{audiobook.url}")
  IO.puts("Status: #{audiobook.status}")
end)

IO.puts("\n")
