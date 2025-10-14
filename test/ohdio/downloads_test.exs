defmodule Ohdio.DownloadsTest do
  use Ohdio.DataCase

  alias Ohdio.Downloads

  describe "queue_items" do
    alias Ohdio.Downloads.QueueItem

    import Ohdio.DownloadsFixtures
    import Ohdio.LibraryFixtures

    @invalid_attrs %{
      audiobook_id: nil,
      priority: -1,
      max_attempts: 0
    }

    test "list_queue_items/0 returns all queue_items" do
      queue_item = queue_item_fixture()
      assert Downloads.list_queue_items() == [queue_item]
    end

    test "get_queue_item!/1 returns the queue_item with given id" do
      queue_item = queue_item_fixture()
      assert Downloads.get_queue_item!(queue_item.id) == queue_item
    end

    test "create_queue_item/1 with valid data creates a queue_item" do
      audiobook = audiobook_fixture()

      valid_attrs = %{
        audiobook_id: audiobook.id,
        priority: 42,
        status: :queued,
        max_attempts: 42,
        attempts: 0,
        error_message: "some error_message"
      }

      assert {:ok, %QueueItem{} = queue_item} = Downloads.create_queue_item(valid_attrs)
      assert queue_item.priority == 42
      assert queue_item.status == :queued
      assert queue_item.max_attempts == 42
      assert queue_item.attempts == 0
      assert queue_item.error_message == "some error_message"
    end

    test "create_queue_item/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Downloads.create_queue_item(@invalid_attrs)
    end

    test "update_queue_item/2 with valid data updates the queue_item" do
      queue_item = queue_item_fixture()

      update_attrs = %{
        priority: 43,
        status: :processing,
        max_attempts: 43,
        attempts: 1,
        error_message: "some updated error_message"
      }

      assert {:ok, %QueueItem{} = queue_item} =
               Downloads.update_queue_item(queue_item, update_attrs)

      assert queue_item.priority == 43
      assert queue_item.status == :processing
      assert queue_item.max_attempts == 43
      assert queue_item.attempts == 1
      assert queue_item.error_message == "some updated error_message"
    end

    test "update_queue_item/2 with invalid data returns error changeset" do
      queue_item = queue_item_fixture()
      assert {:error, %Ecto.Changeset{}} = Downloads.update_queue_item(queue_item, @invalid_attrs)
      assert queue_item == Downloads.get_queue_item!(queue_item.id)
    end

    test "delete_queue_item/1 deletes the queue_item" do
      queue_item = queue_item_fixture()
      assert {:ok, %QueueItem{}} = Downloads.delete_queue_item(queue_item)
      assert_raise Ecto.NoResultsError, fn -> Downloads.get_queue_item!(queue_item.id) end
    end

    test "change_queue_item/1 returns a queue_item changeset" do
      queue_item = queue_item_fixture()
      assert %Ecto.Changeset{} = Downloads.change_queue_item(queue_item)
    end
  end
end
