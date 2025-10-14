defmodule Ohdio.Downloads do
  @moduledoc """
  The Downloads context.
  """

  import Ecto.Query, warn: false
  alias Ohdio.Repo

  alias Ohdio.Downloads.QueueItem
  alias Ohdio.Downloads.QueueControl

  @doc """
  Returns the list of queue_items.

  ## Examples

      iex> list_queue_items()
      [%QueueItem{}, ...]

  """
  def list_queue_items do
    Repo.all(QueueItem)
  end

  @doc """
  Returns the list of queue_items with optional filters and sorting.
  Preloads audiobook associations.

  ## Options

    * `:status` - Filter by status (:queued, :processing, :completed, :failed)
    * `:sort_by` - Sort field (:priority, :inserted_at, :status)
    * `:sort_order` - Sort order (:asc, :desc)

  ## Examples

      iex> list_queue_items_filtered(status: :queued, sort_by: :priority, sort_order: :desc)
      [%QueueItem{}, ...]

  """
  def list_queue_items_filtered(opts \\ []) do
    QueueItem
    |> apply_filters(opts)
    |> apply_sorting(opts)
    |> Repo.all()
    |> Repo.preload(:audiobook)
  end

  defp apply_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:status, status}, query when not is_nil(status) ->
        from q in query, where: q.status == ^status

      _, query ->
        query
    end)
  end

  defp apply_sorting(query, opts) do
    sort_by = Keyword.get(opts, :sort_by, :priority)
    sort_order = Keyword.get(opts, :sort_order, :desc)

    case sort_by do
      :priority ->
        from q in query, order_by: [{^sort_order, q.priority}, {:asc, q.inserted_at}]

      :inserted_at ->
        from q in query, order_by: [{^sort_order, q.inserted_at}]

      :status ->
        from q in query, order_by: [{^sort_order, q.status}, {:asc, q.inserted_at}]

      _ ->
        from q in query, order_by: [{:desc, q.priority}, {:asc, q.inserted_at}]
    end
  end

  @doc """
  Gets a single queue_item.

  Raises `Ecto.NoResultsError` if the Queue item does not exist.

  ## Examples

      iex> get_queue_item!(123)
      %QueueItem{}

      iex> get_queue_item!(456)
      ** (Ecto.NoResultsError)

  """
  def get_queue_item!(id), do: Repo.get!(QueueItem, id)

  @doc """
  Creates a queue_item.

  ## Examples

      iex> create_queue_item(%{field: value})
      {:ok, %QueueItem{}}

      iex> create_queue_item(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_queue_item(attrs) do
    result =
      %QueueItem{}
      |> QueueItem.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, queue_item} ->
        # Broadcast queue update
        Phoenix.PubSub.broadcast(
          Ohdio.PubSub,
          "queue_updates",
          {:queue_updated, %{action: :created, queue_item_id: queue_item.id}}
        )

        {:ok, queue_item}

      error ->
        error
    end
  end

  @doc """
  Updates a queue_item.

  ## Examples

      iex> update_queue_item(queue_item, %{field: new_value})
      {:ok, %QueueItem{}}

      iex> update_queue_item(queue_item, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_queue_item(%QueueItem{} = queue_item, attrs) do
    result =
      queue_item
      |> QueueItem.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_item} ->
        # Broadcast queue update
        Phoenix.PubSub.broadcast(
          Ohdio.PubSub,
          "queue_updates",
          {:queue_updated, %{action: :updated, queue_item_id: updated_item.id}}
        )

        {:ok, updated_item}

      error ->
        error
    end
  end

  @doc """
  Deletes a queue_item.

  ## Examples

      iex> delete_queue_item(queue_item)
      {:ok, %QueueItem{}}

      iex> delete_queue_item(queue_item)
      {:error, %Ecto.Changeset{}}

  """
  def delete_queue_item(%QueueItem{} = queue_item) do
    result = Repo.delete(queue_item)

    case result do
      {:ok, deleted_item} ->
        # Broadcast queue update
        Phoenix.PubSub.broadcast(
          Ohdio.PubSub,
          "queue_updates",
          {:queue_updated, %{action: :deleted, queue_item_id: deleted_item.id}}
        )

        {:ok, deleted_item}

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking queue_item changes.

  ## Examples

      iex> change_queue_item(queue_item)
      %Ecto.Changeset{data: %QueueItem{}}

  """
  def change_queue_item(%QueueItem{} = queue_item, attrs \\ %{}) do
    QueueItem.changeset(queue_item, attrs)
  end

  # Queue Control functions

  @doc """
  Gets the queue control settings.
  Creates default settings if none exist.

  ## Examples

      iex> get_queue_control()
      %QueueControl{}

  """
  def get_queue_control do
    case Repo.one(QueueControl) do
      nil ->
        {:ok, control} =
          %QueueControl{}
          |> QueueControl.changeset(%{})
          |> Repo.insert()

        control

      control ->
        control
    end
  end

  @doc """
  Checks if the download queue is currently paused.

  ## Examples

      iex> paused?()
      false

  """
  def paused? do
    get_queue_control().is_paused
  end

  @doc """
  Pauses the download queue.

  ## Examples

      iex> pause_queue()
      {:ok, %QueueControl{}}

  """
  def pause_queue do
    control = get_queue_control()

    control
    |> QueueControl.changeset(%{is_paused: true})
    |> Repo.update()
  end

  @doc """
  Resumes the download queue.

  ## Examples

      iex> resume_queue()
      {:ok, %QueueControl{}}

  """
  def resume_queue do
    control = get_queue_control()

    control
    |> QueueControl.changeset(%{is_paused: false})
    |> Repo.update()
  end

  @doc """
  Updates the maximum concurrent downloads.

  ## Examples

      iex> update_max_concurrent(5)
      {:ok, %QueueControl{}}

  """
  def update_max_concurrent(max) when is_integer(max) and max > 0 do
    control = get_queue_control()

    control
    |> QueueControl.changeset(%{max_concurrent_downloads: max})
    |> Repo.update()
  end

  @doc """
  Returns queue statistics.

  ## Examples

      iex> get_queue_stats()
      %{total: 10, queued: 3, processing: 2, completed: 4, failed: 1}

  """
  def get_queue_stats do
    from(q in QueueItem,
      select: {q.status, count(q.id)},
      group_by: q.status
    )
    |> Repo.all()
    |> Enum.into(%{})
    |> then(fn counts ->
      %{
        total: Enum.sum(Map.values(counts)),
        queued: Map.get(counts, :queued, 0),
        processing: Map.get(counts, :processing, 0),
        completed: Map.get(counts, :completed, 0),
        failed: Map.get(counts, :failed, 0)
      }
    end)
  end

  @doc """
  Clears all completed queue items.

  ## Examples

      iex> clear_completed()
      {3, nil}

  """
  def clear_completed do
    result =
      from(q in QueueItem, where: q.status == :completed)
      |> Repo.delete_all()

    # Broadcast queue update
    Phoenix.PubSub.broadcast(
      Ohdio.PubSub,
      "queue_updates",
      {:queue_updated, %{action: :bulk_delete, count: elem(result, 0)}}
    )

    result
  end

  @doc """
  Clears all queue items.

  ## Examples

      iex> clear_queue()
      {10, nil}

  """
  def clear_queue do
    result = Repo.delete_all(QueueItem)

    # Broadcast queue update
    Phoenix.PubSub.broadcast(
      Ohdio.PubSub,
      "queue_updates",
      {:queue_updated, %{action: :bulk_delete, count: elem(result, 0)}}
    )

    result
  end

  @doc """
  Retries a failed queue item by resetting its status and incrementing attempts.

  ## Examples

      iex> retry_queue_item(queue_item)
      {:ok, %QueueItem{}}

  """
  def retry_queue_item(%QueueItem{} = queue_item) do
    queue_item
    |> QueueItem.changeset(%{
      status: :queued,
      attempts: queue_item.attempts + 1,
      error_message: nil
    })
    |> Repo.update()
  end

  @doc """
  Updates the priority of a queue item.

  ## Examples

      iex> update_queue_item_priority(queue_item, 10)
      {:ok, %QueueItem{}}

  """
  def update_queue_item_priority(%QueueItem{} = queue_item, priority)
      when is_integer(priority) and priority >= 0 do
    queue_item
    |> QueueItem.changeset(%{priority: priority})
    |> Repo.update()
  end
end
