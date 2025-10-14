#!/usr/bin/env elixir

alias Ohdio.{Library, Downloads, Repo}
alias Ohdio.Workers.DownloadWorker
import Ecto.Query

IO.puts("\n=== Resetting Download Queue ===\n")

# Step 1: Delete all old download jobs from Oban
IO.puts("Step 1: Removing old Oban download jobs...")

{deleted_jobs, _} =
  Repo.delete_all(
    from j in "oban_jobs",
      where: j.queue == "downloads"
  )

IO.puts("Deleted #{deleted_jobs} old Oban jobs")

# Step 2: Reset all queue items to queued status
IO.puts("\nStep 2: Resetting queue items to queued status...")

{updated_items, _} =
  Repo.update_all(
    from(qi in Downloads.QueueItem, where: qi.status == :processing),
    set: [status: :queued, attempts: 0]
  )

IO.puts("Reset #{updated_items} queue items")

# Step 3: Reset audiobooks to pending
IO.puts("\nStep 3: Resetting audiobooks to pending...")

{updated_audiobooks, _} =
  Repo.update_all(
    from(a in Library.Audiobook, where: a.status == :downloading),
    set: [status: :pending]
  )

IO.puts("Reset #{updated_audiobooks} audiobooks")

# Step 4: Create fresh Oban jobs for all queued items
IO.puts("\nStep 4: Creating fresh download jobs...")

queued_items =
  Repo.all(
    from qi in Downloads.QueueItem,
      where: qi.status == :queued,
      select: qi
  )

Enum.each(queued_items, fn item ->
  %{queue_item_id: item.id, audiobook_id: item.audiobook_id}
  |> DownloadWorker.new()
  |> Oban.insert()

  if rem(item.id, 20) == 0 do
    IO.write(".")
  end
end)

IO.puts("\n\nCreated #{length(queued_items)} fresh download jobs")

# Step 5: Show summary
IO.puts("\n=== Summary ===")
stats = Downloads.get_queue_stats()
IO.puts("Queue stats:")
IO.puts("  Total: #{stats.total}")
IO.puts("  Queued: #{stats.queued}")
IO.puts("  Processing: #{stats.processing}")
IO.puts("  Completed: #{stats.completed}")
IO.puts("  Failed: #{stats.failed}")

IO.puts("\n")
