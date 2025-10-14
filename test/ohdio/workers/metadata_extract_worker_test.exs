defmodule Ohdio.Workers.MetadataExtractWorkerTest do
  use Ohdio.DataCase
  use Oban.Testing, repo: Ohdio.Repo

  alias Ohdio.{Downloads, Library}
  alias Ohdio.Workers.{MetadataExtractWorker, DownloadWorker}

  import Ohdio.LibraryFixtures

  setup do
    # Create a test audiobook
    audiobook =
      audiobook_fixture(%{
        title: "Test Audiobook",
        url: "https://ohdio.fm/test",
        file_path: nil
      })

    %{audiobook: audiobook}
  end

  describe "perform/1 with no existing queue item" do
    test "creates new queue item and enqueues download worker", %{audiobook: audiobook} do
      # Mock successful metadata extraction
      # In a real scenario, you'd mock the Scraper or use a test URL

      # Perform the job
      assert :ok =
               perform_job(MetadataExtractWorker, %{
                 audiobook_id: audiobook.id,
                 url: audiobook.url
               })

      # Verify queue item was created
      queue_items = Downloads.list_queue_items()
      assert length(queue_items) == 1
      [queue_item] = queue_items
      assert queue_item.audiobook_id == audiobook.id
      assert queue_item.status == :queued
      assert queue_item.priority == 5

      # Verify DownloadWorker job was enqueued
      assert_enqueued(
        worker: DownloadWorker,
        args: %{
          queue_item_id: queue_item.id,
          audiobook_id: audiobook.id
        }
      )
    end

    test "does not enqueue download if file already exists", %{audiobook: audiobook} do
      # Create a temporary test file
      test_file = "/tmp/test_audiobook.m4a"
      File.write!(test_file, "test content")

      # Update audiobook with existing file path
      {:ok, audiobook} = Library.update_audiobook(audiobook, %{file_path: test_file})

      # Perform the job
      assert :ok =
               perform_job(MetadataExtractWorker, %{
                 audiobook_id: audiobook.id,
                 url: audiobook.url
               })

      # Verify queue item was created
      queue_items = Downloads.list_queue_items()
      assert length(queue_items) == 1

      # Verify DownloadWorker job was NOT enqueued
      refute_enqueued(worker: DownloadWorker)

      # Cleanup
      File.rm!(test_file)
    end
  end

  describe "perform/1 with existing queue item" do
    test "uses existing queue item and enqueues download worker", %{audiobook: audiobook} do
      # Create existing queue item
      {:ok, existing_queue_item} =
        Downloads.create_queue_item(%{
          audiobook_id: audiobook.id,
          status: :queued,
          priority: 10
        })

      # Perform the job
      assert :ok =
               perform_job(MetadataExtractWorker, %{
                 audiobook_id: audiobook.id,
                 url: audiobook.url
               })

      # Verify no duplicate queue item was created
      queue_items = Downloads.list_queue_items()
      assert length(queue_items) == 1
      [queue_item] = queue_items
      assert queue_item.id == existing_queue_item.id
      assert queue_item.audiobook_id == audiobook.id
      # Priority should remain unchanged (from existing queue item)
      assert queue_item.priority == 10

      # Verify DownloadWorker job was enqueued with existing queue item
      assert_enqueued(
        worker: DownloadWorker,
        args: %{
          queue_item_id: existing_queue_item.id,
          audiobook_id: audiobook.id
        }
      )
    end

    test "does not enqueue download if queue item status is not queued", %{audiobook: audiobook} do
      # Create existing queue item with processing status
      {:ok, _existing_queue_item} =
        Downloads.create_queue_item(%{
          audiobook_id: audiobook.id,
          status: :processing,
          priority: 10
        })

      # Perform the job
      assert :ok =
               perform_job(MetadataExtractWorker, %{
                 audiobook_id: audiobook.id,
                 url: audiobook.url
               })

      # Verify no duplicate queue item was created
      queue_items = Downloads.list_queue_items()
      assert length(queue_items) == 1

      # Verify DownloadWorker job was NOT enqueued (status is processing)
      refute_enqueued(worker: DownloadWorker)
    end

    test "does not create duplicate queue items for same audiobook", %{audiobook: audiobook} do
      # Create existing queue item
      {:ok, _existing_queue_item} =
        Downloads.create_queue_item(%{
          audiobook_id: audiobook.id,
          status: :queued,
          priority: 5
        })

      # Perform the job multiple times
      assert :ok =
               perform_job(MetadataExtractWorker, %{
                 audiobook_id: audiobook.id,
                 url: audiobook.url
               })

      assert :ok =
               perform_job(MetadataExtractWorker, %{
                 audiobook_id: audiobook.id,
                 url: audiobook.url
               })

      # Verify only one queue item exists
      queue_items = Downloads.list_queue_items()
      assert length(queue_items) == 1
    end
  end
end
