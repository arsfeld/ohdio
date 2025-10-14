#!/usr/bin/env elixir

# Run with: ./dc mix run enqueue_missing_downloads.exs

alias Ohdio.{Downloads, Repo}
alias Ohdio.Workers.DownloadWorker
import Ecto.Query

IO.puts("\n=== Enqueuing Missing Download Jobs ===\n")

# Get all queued items
queued_items = Downloads.list_queue_items_filtered(status: :queued)
IO.puts("Found #{length(queued_items)} queued items")

# Get all existing download jobs
existing_jobs =
  Repo.all(
    from j in "oban_jobs",
      where: j.queue == "downloads" and j.state in ["available", "executing", "scheduled"],
      select: j.args
  )

existing_queue_item_ids =
  existing_jobs
  |> Enum.map(fn args_json ->
    args = Jason.decode!(args_json)
    args["queue_item_id"]
  end)
  |> MapSet.new()

IO.puts("Found #{MapSet.size(existing_queue_item_ids)} existing download jobs")

# Find queue items without jobs
items_without_jobs =
  Enum.reject(queued_items, fn item ->
    MapSet.member?(existing_queue_item_ids, item.id)
  end)

IO.puts("#{length(items_without_jobs)} queue items need download jobs")

if length(items_without_jobs) > 0 do
  IO.puts("\nEnqueuing download jobs...")

  Enum.each(items_without_jobs, fn item ->
    %{queue_item_id: item.id, audiobook_id: item.audiobook_id}
    |> DownloadWorker.new()
    |> Oban.insert()

    if rem(item.id, 10) == 0 do
      IO.write(".")
    end
  end)

  IO.puts("\n\nDone! Enqueued #{length(items_without_jobs)} download jobs")
else
  IO.puts("\nNo missing jobs to enqueue")
end

IO.puts("\n")
