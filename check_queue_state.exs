#!/usr/bin/env elixir

# Run with: ./dc mix run check_queue_state.exs

alias Ohdio.{Downloads, Library, Repo}

IO.puts("\n=== Queue Control State ===")
queue_control = Downloads.get_queue_control()
IO.puts("Paused: #{queue_control.is_paused}")
IO.puts("Max Concurrent: #{queue_control.max_concurrent_downloads}")

IO.puts("\n=== Queue Items ===")
queue_items = Downloads.list_queue_items() |> Repo.preload(:audiobook)
IO.puts("Total queue items: #{length(queue_items)}")

Enum.group_by(queue_items, & &1.status)
|> Enum.each(fn {status, items} ->
  IO.puts("  #{status}: #{length(items)}")
end)

IO.puts("\n=== Queued Items (first 10) ===")

queue_items
|> Enum.filter(&(&1.status == :queued))
|> Enum.take(10)
|> Enum.each(fn item ->
  IO.puts("  [#{item.id}] #{item.audiobook.title} - Priority: #{item.priority}")
end)

IO.puts("\n=== Oban Jobs ===")
# Check Oban jobs in the downloads queue
import Ecto.Query

jobs_query =
  from(j in "oban_jobs",
    where: j.queue == "downloads",
    select: %{
      id: j.id,
      state: j.state,
      worker: j.worker,
      scheduled_at: j.scheduled_at,
      attempted_at: j.attempted_at,
      errors: j.errors
    }
  )

case Repo.all(jobs_query) do
  [] ->
    IO.puts("No Oban jobs in downloads queue")

  jobs ->
    IO.puts("Total Oban jobs: #{length(jobs)}")

    Enum.group_by(jobs, & &1.state)
    |> Enum.each(fn {state, state_jobs} ->
      IO.puts("  #{state}: #{length(state_jobs)}")
    end)

    IO.puts("\n=== Job Details (first 5) ===")

    jobs
    |> Enum.take(5)
    |> Enum.each(fn job ->
      IO.puts("  [#{job.id}] #{job.state} - #{job.worker}")
      IO.puts("    Scheduled: #{job.scheduled_at}")
      IO.puts("    Errors: #{length(job.errors || [])}")
    end)
end

IO.puts("\n")
