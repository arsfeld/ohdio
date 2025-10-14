#!/usr/bin/env elixir

alias Ohdio.{Library, Downloads, Repo}
alias Ohdio.Workers.DownloadWorker
import Ecto.Query

IO.puts("\n=== Cleaning Up and Retrying Failed Downloads ===\n")

# Step 1: Delete audiobooks with category URLs (these are invalid)
IO.puts("Step 1: Removing audiobooks with category URLs...")

bad_audiobooks =
  Repo.all(
    from a in Library.Audiobook,
      where: fragment("? LIKE '%categories%'", a.url)
  )

IO.puts("Found #{length(bad_audiobooks)} audiobooks with category URLs")

Enum.each(bad_audiobooks, fn audiobook ->
  IO.puts("  Deleting: #{audiobook.title} (#{audiobook.url})")

  # Delete queue items first (due to foreign key)
  {deleted_qi, _} =
    Repo.delete_all(
      from qi in Downloads.QueueItem,
        where: qi.audiobook_id == ^audiobook.id
    )

  if deleted_qi > 0 do
    IO.puts("    Deleted #{deleted_qi} queue item(s)")
  end

  # Delete the audiobook
  Repo.delete(audiobook)
  IO.puts("    Deleted audiobook")
end)

# Step 2: Reset failed queue items to queued and retry
IO.puts("\nStep 2: Resetting failed queue items to queued...")

failed_items =
  Repo.all(
    from qi in Downloads.QueueItem,
      where: qi.status == :failed,
      preload: :audiobook
  )

IO.puts("Found #{length(failed_items)} failed queue items")

Enum.each(failed_items, fn item ->
  # Reset queue item to queued status with zero attempts
  {:ok, updated_item} =
    Downloads.update_queue_item(item, %{
      status: :queued,
      attempts: 0,
      error_message: nil
    })

  # Reset audiobook status
  if item.audiobook do
    Library.update_audiobook(item.audiobook, %{status: :pending})
  end

  # Enqueue new download job
  %{queue_item_id: updated_item.id, audiobook_id: updated_item.audiobook_id}
  |> DownloadWorker.new()
  |> Oban.insert()

  if rem(item.id, 10) == 0 do
    IO.write(".")
  end
end)

IO.puts("\n\nDone! Reset #{length(failed_items)} failed items and enqueued download jobs")

# Step 3: Show summary
IO.puts("\n=== Summary ===")

stats = Downloads.get_queue_stats()
IO.puts("Queue stats:")
IO.puts("  Total: #{stats.total}")
IO.puts("  Queued: #{stats.queued}")
IO.puts("  Processing: #{stats.processing}")
IO.puts("  Completed: #{stats.completed}")
IO.puts("  Failed: #{stats.failed}")

IO.puts("\n")
