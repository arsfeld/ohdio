#!/usr/bin/env elixir

alias Ohdio.Repo
import Ecto.Query

jobs =
  Repo.all(
    from j in "oban_jobs",
      where: j.queue == "downloads" and j.state == "retryable",
      limit: 3,
      select: %{
        id: j.id,
        state: j.state,
        worker: j.worker,
        args: j.args,
        errors: j.errors,
        max_attempts: j.max_attempts,
        attempt: j.attempt,
        scheduled_at: j.scheduled_at,
        attempted_at: j.attempted_at
      }
  )

IO.puts("\n=== Retryable Job Details ===\n")

Enum.each(jobs, fn job ->
  IO.puts("Job ID: #{job.id}")
  IO.puts("Worker: #{job.worker}")
  IO.puts("Attempt: #{job.attempt} / #{job.max_attempts}")
  IO.puts("Scheduled: #{job.scheduled_at}")
  IO.puts("Last Attempted: #{job.attempted_at}")
  IO.puts("Args: #{inspect(job.args)}")

  errors = Jason.decode!(job.errors)
  IO.puts("\nErrors (#{length(errors)}):")

  Enum.each(errors, fn error ->
    IO.puts("  - Attempt #{error["attempt"]}: #{error["kind"]} - #{error["error"]}")

    if error["stacktrace"] do
      IO.puts("    #{String.slice(error["stacktrace"], 0, 200)}...")
    end
  end)

  IO.puts("\n" <> String.duplicate("-", 80) <> "\n")
end)
