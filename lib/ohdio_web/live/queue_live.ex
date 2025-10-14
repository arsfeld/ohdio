defmodule OhdioWeb.QueueLive do
  use OhdioWeb, :live_view

  alias Ohdio.{Downloads, Library, Scraper}
  alias Ohdio.Workers.{CategoryScrapeWorker, MetadataExtractWorker}

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Ohdio.PubSub, "queue_updates")
      Phoenix.PubSub.subscribe(Ohdio.PubSub, "category_scrapes")
    end

    form =
      %{"url" => ""}
      |> to_form(as: :download)

    {:ok,
     socket
     |> assign(:page_title, "Download Queue")
     |> assign(:form, form)
     |> assign(:loading, false)
     |> assign(:filter_status, nil)
     |> assign(:sort_by, :priority)
     |> assign(:sort_order, :desc)
     |> assign(:show_url_types, false)
     |> load_queue_data()
     |> load_active_scrapes()}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"download" => params}, socket) do
    form =
      params
      |> to_form(as: :download)

    {:noreply, assign(socket, :form, form)}
  end

  @impl Phoenix.LiveView
  def handle_event("submit", %{"download" => %{"url" => url}}, socket) do
    url = String.trim(url)

    if url == "" do
      {:noreply, put_flash(socket, :error, "Please enter a URL")}
    else
      socket = assign(socket, :loading, true)
      process_url(socket, url)
    end
  end

  @impl Phoenix.LiveView
  def handle_event("filter_status", %{"status" => status}, socket) do
    filter_status =
      case status do
        "all" -> nil
        "queued" -> :queued
        "processing" -> :processing
        "completed" -> :completed
        "failed" -> :failed
        _ -> nil
      end

    {:noreply,
     socket
     |> assign(:filter_status, filter_status)
     |> load_queue_data()}
  end

  @impl Phoenix.LiveView
  def handle_event("sort", %{"by" => field}, socket) do
    sort_by = String.to_existing_atom(field)

    sort_order =
      if socket.assigns.sort_by == sort_by do
        toggle_sort_order(socket.assigns.sort_order)
      else
        :desc
      end

    {:noreply,
     socket
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, sort_order)
     |> load_queue_data()}
  end

  @impl Phoenix.LiveView
  def handle_event("pause_all", _params, socket) do
    case Downloads.pause_queue() do
      {:ok, _control} ->
        {:noreply,
         socket
         |> put_flash(:info, "Queue paused")
         |> load_queue_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to pause queue")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("resume_all", _params, socket) do
    case Downloads.resume_queue() do
      {:ok, _control} ->
        {:noreply,
         socket
         |> put_flash(:info, "Queue resumed")
         |> load_queue_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to resume queue")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("clear_completed", _params, socket) do
    {count, _} = Downloads.clear_completed()

    {:noreply,
     socket
     |> put_flash(:info, "Cleared #{count} completed items")
     |> load_queue_data()}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_queue", _params, socket) do
    {count, _} = Downloads.clear_queue()

    {:noreply,
     socket
     |> put_flash(:info, "Cleared #{count} items from queue")
     |> load_queue_data()}
  end

  @impl Phoenix.LiveView
  def handle_event("delete_item", %{"id" => id}, socket) do
    queue_item = Downloads.get_queue_item!(id)

    case Downloads.delete_queue_item(queue_item) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Item deleted")
         |> load_queue_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete item")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("retry_item", %{"id" => id}, socket) do
    queue_item = Downloads.get_queue_item!(id)

    case Downloads.retry_queue_item(queue_item) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Item queued for retry")
         |> load_queue_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to retry item")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("increase_priority", %{"id" => id}, socket) do
    queue_item = Downloads.get_queue_item!(id)
    new_priority = queue_item.priority + 1

    case Downloads.update_queue_item_priority(queue_item, new_priority) do
      {:ok, _} ->
        {:noreply, load_queue_data(socket)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update priority")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("decrease_priority", %{"id" => id}, socket) do
    queue_item = Downloads.get_queue_item!(id)
    new_priority = max(0, queue_item.priority - 1)

    case Downloads.update_queue_item_priority(queue_item, new_priority) do
      {:ok, _} ->
        {:noreply, load_queue_data(socket)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update priority")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_url_types", _params, socket) do
    {:noreply, assign(socket, :show_url_types, !socket.assigns.show_url_types)}
  end

  @impl Phoenix.LiveView
  def handle_info({:queue_updated, _data}, socket) do
    {:noreply, load_queue_data(socket)}
  end

  @impl Phoenix.LiveView
  def handle_info({:download_progress, _data}, socket) do
    {:noreply, load_queue_data(socket)}
  end

  @impl Phoenix.LiveView
  def handle_info({:category_scrape_updated, scrape}, socket) do
    socket =
      case scrape.status do
        :completed ->
          put_flash(
            socket,
            :info,
            "Category scraped! Found #{scrape.total_count} audiobooks"
          )

        _ ->
          socket
      end

    {:noreply, load_active_scrapes(socket)}
  end

  defp load_queue_data(socket) do
    filter_opts =
      [
        status: socket.assigns.filter_status,
        sort_by: socket.assigns.sort_by,
        sort_order: socket.assigns.sort_order
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    queue_items = Downloads.list_queue_items_filtered(filter_opts)
    stats = Downloads.get_queue_stats()
    control = Downloads.get_queue_control()

    socket
    |> assign(:queue_items, queue_items)
    |> assign(:stats, stats)
    |> assign(:control, control)
  end

  defp load_active_scrapes(socket) do
    active_scrapes = Library.list_active_category_scrapes()
    assign(socket, :active_scrapes, active_scrapes)
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(:desc), do: :asc

  defp process_url(socket, url) do
    url_type = Scraper.detect_url_type(url)

    result =
      case url_type do
        :ohdio_category ->
          # Enqueue category scrape job
          case enqueue_category_scrape(url) do
            {:ok, _job} ->
              {:ok,
               socket
               |> put_flash(
                 :info,
                 "OHdio category detected! Scraping audiobooks from category..."
               )
               |> reset_form()}

            {:error, reason} ->
              {:error,
               put_flash(socket, :error, "Failed to enqueue category scrape: #{inspect(reason)}")}
          end

        :ohdio_audiobook ->
          # Create audiobook and enqueue metadata extraction
          case enqueue_audiobook_download(url, "OHdio Audiobook") do
            {:ok, _audiobook} ->
              {:ok,
               socket
               |> put_flash(
                 :info,
                 "OHdio audiobook detected! Added to download queue..."
               )
               |> reset_form()}

            {:error, reason} ->
              {:error, put_flash(socket, :error, "Failed to add audiobook: #{inspect(reason)}")}
          end

        :ytdlp_passthrough ->
          # Create audiobook and enqueue metadata extraction
          case enqueue_audiobook_download(url, "Generic Media") do
            {:ok, _audiobook} ->
              {:ok,
               socket
               |> put_flash(
                 :info,
                 "Generic media URL detected! Added to download queue..."
               )
               |> reset_form()}

            {:error, reason} ->
              {:error, put_flash(socket, :error, "Failed to add media: #{inspect(reason)}")}
          end

        :unknown ->
          # Try with yt-dlp anyway
          case enqueue_audiobook_download(url, "Unknown URL") do
            {:ok, _audiobook} ->
              {:ok,
               socket
               |> put_flash(
                 :info,
                 "Unknown URL type - attempting download with yt-dlp..."
               )
               |> reset_form()}

            {:error, reason} ->
              {:error,
               put_flash(
                 socket,
                 :error,
                 "Unrecognized URL format: #{inspect(reason)}"
               )}
          end
      end

    case result do
      {:ok, updated_socket} ->
        {:noreply, assign(updated_socket, :loading, false)}

      {:error, updated_socket} ->
        {:noreply, assign(updated_socket, :loading, false)}
    end
  end

  defp enqueue_category_scrape(url) do
    # Create scrape record first
    case Library.create_category_scrape(%{
           category_url: url,
           status: :scraping
         }) do
      {:ok, scrape} ->
        # Enqueue worker with scrape_id
        case %{category_url: url, scrape_id: scrape.id}
             |> CategoryScrapeWorker.new()
             |> Oban.insert() do
          {:ok, job} ->
            # Update scrape record with job_id
            Library.update_category_scrape(scrape, %{oban_job_id: job.id})
            {:ok, job}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp enqueue_audiobook_download(url, title_prefix) do
    # Create audiobook record
    case Library.create_audiobook(%{
           title: "#{title_prefix} from #{extract_domain(url)}",
           url: url,
           status: :pending
         }) do
      {:ok, audiobook} ->
        # Enqueue metadata extraction job
        case %{audiobook_id: audiobook.id, url: url}
             |> MetadataExtractWorker.new()
             |> Oban.insert() do
          {:ok, _job} -> {:ok, audiobook}
          {:error, reason} -> {:error, reason}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp extract_domain(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> "unknown"
    end
  end

  defp reset_form(socket) do
    form =
      %{"url" => ""}
      |> to_form(as: :download)

    assign(socket, :form, form)
  end

  defp status_badge_class(status) do
    base = "badge text-xs font-medium"

    status_class =
      case status do
        :queued -> "badge-info"
        :processing -> "badge-warning"
        :completed -> "badge-success"
        :failed -> "badge-error"
      end

    "#{base} #{status_class}"
  end

  defp status_icon(status) do
    case status do
      :queued -> "hero-clock"
      :processing -> "hero-arrow-path"
      :completed -> "hero-check-circle"
      :failed -> "hero-x-circle"
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-4">
        <div class="flex items-center gap-2.5 mb-1">
          <.icon name="hero-musical-note" class="size-7 text-primary" />
          <div>
            <h1 class="text-2xl font-bold">OHdio Downloader</h1>
            <p class="text-sm text-base-content/60">
              Download audiobooks from OHdio or any yt-dlp compatible URL
            </p>
          </div>
        </div>

        <%!-- URL Submission Form --%>
        <div class="card bg-base-100 shadow-sm border border-base-300">
          <div class="card-body p-4">
            <.form for={@form} id="download-form" phx-change="validate" phx-submit="submit">
              <label class="form-control">
                <div class="label">
                  <span class="label-text">Enter URL</span>
                </div>
                <div class="join w-full">
                  <input
                    type="url"
                    name={@form[:url].name}
                    id={@form[:url].id}
                    value={@form[:url].value}
                    placeholder="https://ici.radio-canada.ca/ohdio/..."
                    class="input input-bordered join-item flex-1 w-full"
                    required
                  />
                  <button
                    type="submit"
                    disabled={@loading}
                    class="btn btn-primary join-item"
                  >
                    <%= if @loading do %>
                      <span class="loading loading-spinner loading-sm mr-2"></span> Processing...
                    <% else %>
                      <.icon name="hero-arrow-down-tray" class="size-5 mr-2" /> Add to Queue
                    <% end %>
                  </button>
                </div>
              </label>
            </.form>
          </div>
        </div>

        <%!-- Active Category Scrapes --%>
        <%= if @active_scrapes != [] do %>
          <div class="space-y-2">
            <%= for scrape <- @active_scrapes do %>
              <div class={[
                "card shadow-sm border",
                cond do
                  scrape.status == :scraping -> "bg-info/5 border-info/20"
                  scrape.status == :completed -> "bg-success/5 border-success/20"
                  scrape.status == :failed -> "bg-error/5 border-error/20"
                  true -> "bg-base-100 border-base-300"
                end
              ]}>
                <div class="card-body p-3">
                  <div class="flex items-center gap-3 flex-1 min-w-0">
                    <%= cond do %>
                      <% scrape.status == :scraping -> %>
                        <span class="loading loading-spinner loading-sm flex-shrink-0 text-info">
                        </span>
                        <div class="min-w-0">
                          <h3 class="font-semibold text-sm">Scraping category...</h3>
                          <div class="text-xs text-base-content/60 truncate">
                            {scrape.category_url}
                          </div>
                        </div>
                      <% scrape.status == :completed -> %>
                        <.icon name="hero-check-circle" class="size-5 flex-shrink-0 text-success" />
                        <div class="min-w-0">
                          <h3 class="font-semibold text-sm">
                            Category scraped! Found {scrape.total_count} audiobooks
                          </h3>
                          <div class="text-xs text-base-content/60 truncate">
                            {scrape.category_url}
                          </div>
                        </div>
                      <% scrape.status == :failed -> %>
                        <.icon name="hero-x-circle" class="size-5 flex-shrink-0 text-error" />
                        <div class="min-w-0">
                          <h3 class="font-semibold text-sm">Failed to scrape category</h3>
                          <div class="text-xs text-base-content/60 truncate">
                            {scrape.category_url}
                          </div>
                          <%= if scrape.error_message do %>
                            <div class="text-xs mt-0.5 text-error/80">{scrape.error_message}</div>
                          <% end %>
                        </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <%!-- Supported URL Types Info --%>
        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body p-4">
            <button
              phx-click="toggle_url_types"
              class="flex items-center justify-between w-full text-left group"
            >
              <h2 class="flex items-center gap-2 text-sm font-semibold text-base-content/70">
                <.icon name="hero-information-circle" class="size-4" /> Supported URL Types
              </h2>
              <.icon
                name={if @show_url_types, do: "hero-chevron-up", else: "hero-chevron-down"}
                class="size-4 text-base-content/50 group-hover:text-base-content transition-colors"
              />
            </button>

            <%= if @show_url_types do %>
              <div class="space-y-3 mt-3">
                <div>
                  <h3 class="font-medium text-sm flex items-center gap-1.5 mb-1">
                    <.icon name="hero-queue-list" class="size-4 text-primary" /> OHdio Category Pages
                  </h3>
                  <p class="text-xs text-base-content/60 mb-1">
                    Scrapes all audiobooks from a category page
                  </p>
                  <code class="text-xs bg-base-200 px-2 py-0.5 rounded block break-all">
                    https://ici.radio-canada.ca/ohdio/categories/1003592/jeunesse
                  </code>
                </div>

                <div class="divider my-1.5" />

                <div>
                  <h3 class="font-medium text-sm flex items-center gap-1.5 mb-1">
                    <.icon name="hero-book-open" class="size-4 text-secondary" />
                    OHdio Individual Audiobooks
                  </h3>
                  <p class="text-xs text-base-content/60 mb-1">
                    Downloads a specific audiobook with metadata
                  </p>
                  <code class="text-xs bg-base-200 px-2 py-0.5 rounded block break-all">
                    https://ici.radio-canada.ca/ohdio/livres-audio/12345/book-title
                  </code>
                </div>

                <div class="divider my-1.5" />

                <div>
                  <h3 class="font-medium text-sm flex items-center gap-1.5 mb-1">
                    <.icon name="hero-globe-alt" class="size-4 text-accent" />
                    Generic Media URLs (yt-dlp)
                  </h3>
                  <p class="text-xs text-base-content/60 mb-1.5">
                    Downloads media from YouTube, Vimeo, SoundCloud, and 1000+ other sites
                  </p>
                  <div class="flex flex-wrap gap-1.5 text-xs">
                    <code class="bg-base-200 px-2 py-0.5 rounded">youtube.com</code>
                    <code class="bg-base-200 px-2 py-0.5 rounded">vimeo.com</code>
                    <code class="bg-base-200 px-2 py-0.5 rounded">soundcloud.com</code>
                    <code class="bg-base-200 px-2 py-0.5 rounded">twitch.tv</code>
                    <code class="bg-base-200 px-2 py-0.5 rounded">and many more...</code>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Statistics Cards --%>
        <div class="grid grid-cols-2 md:grid-cols-5 gap-3">
          <div class="card bg-base-100 border border-base-300 shadow-sm">
            <div class="card-body p-3">
              <div class="text-xs text-base-content/60 font-medium">Total</div>
              <div class="text-xl font-bold">{@stats.total}</div>
            </div>
          </div>
          <div class="card bg-base-100 border border-info/20 shadow-sm">
            <div class="card-body p-3">
              <div class="text-xs text-base-content/60 font-medium">Queued</div>
              <div class="text-xl font-bold text-info">{@stats.queued}</div>
            </div>
          </div>
          <div class="card bg-base-100 border border-warning/20 shadow-sm">
            <div class="card-body p-3">
              <div class="text-xs text-base-content/60 font-medium">Processing</div>
              <div class="text-xl font-bold text-warning">{@stats.processing}</div>
            </div>
          </div>
          <div class="card bg-base-100 border border-success/20 shadow-sm">
            <div class="card-body p-3">
              <div class="text-xs text-base-content/60 font-medium">Completed</div>
              <div class="text-xl font-bold text-success">{@stats.completed}</div>
            </div>
          </div>
          <div class="card bg-base-100 border border-error/20 shadow-sm">
            <div class="card-body p-3">
              <div class="text-xs text-base-content/60 font-medium">Failed</div>
              <div class="text-xl font-bold text-error">{@stats.failed}</div>
            </div>
          </div>
        </div>

        <%!-- Controls Bar --%>
        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body p-3">
            <div class="flex flex-wrap items-center gap-3 justify-between">
              <div class="flex flex-wrap gap-1.5">
                <.button
                  phx-click="filter_status"
                  phx-value-status="all"
                  variant={if @filter_status == nil, do: "primary", else: nil}
                  class={if @filter_status != nil, do: "btn-sm btn-outline", else: "btn-sm"}
                >
                  All
                </.button>
                <.button
                  phx-click="filter_status"
                  phx-value-status="queued"
                  variant={if @filter_status == :queued, do: "primary", else: nil}
                  class={if @filter_status != :queued, do: "btn-sm btn-outline", else: "btn-sm"}
                >
                  Queued
                </.button>
                <.button
                  phx-click="filter_status"
                  phx-value-status="processing"
                  variant={if @filter_status == :processing, do: "primary", else: nil}
                  class={if @filter_status != :processing, do: "btn-sm btn-outline", else: "btn-sm"}
                >
                  Processing
                </.button>
                <.button
                  phx-click="filter_status"
                  phx-value-status="completed"
                  variant={if @filter_status == :completed, do: "primary", else: nil}
                  class={if @filter_status != :completed, do: "btn-sm btn-outline", else: "btn-sm"}
                >
                  Completed
                </.button>
                <.button
                  phx-click="filter_status"
                  phx-value-status="failed"
                  variant={if @filter_status == :failed, do: "primary", else: nil}
                  class={if @filter_status != :failed, do: "btn-sm btn-outline", else: "btn-sm"}
                >
                  Failed
                </.button>
              </div>

              <div class="flex flex-wrap gap-1.5">
                <.button
                  :if={!@control.is_paused}
                  phx-click="pause_all"
                  class="btn-sm btn-warning"
                >
                  <.icon name="hero-pause" class="size-4" /> Pause All
                </.button>
                <.button
                  :if={@control.is_paused}
                  phx-click="resume_all"
                  class="btn-sm btn-success"
                >
                  <.icon name="hero-play" class="size-4" /> Resume All
                </.button>
                <.button
                  phx-click="clear_completed"
                  class="btn-sm btn-outline"
                >
                  <.icon name="hero-trash" class="size-4" /> Clear Completed
                </.button>
                <.button
                  phx-click="clear_queue"
                  class="btn-sm btn-outline"
                  data-confirm="Are you sure you want to clear the entire queue?"
                >
                  <.icon name="hero-trash" class="size-4" /> Clear All
                </.button>
              </div>
            </div>
          </div>
        </div>

        <%!-- Queue Items Table --%>
        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body p-0">
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr class="border-b border-base-300">
                    <th class="text-xs font-semibold">
                      <button
                        phx-click="sort"
                        phx-value-by="status"
                        class="flex items-center gap-1 hover:text-primary transition-colors"
                      >
                        Status
                        <.icon
                          :if={@sort_by == :status}
                          name={
                            if @sort_order == :asc, do: "hero-chevron-up", else: "hero-chevron-down"
                          }
                          class="size-3"
                        />
                      </button>
                    </th>
                    <th class="text-xs font-semibold">Title</th>
                    <th class="text-xs font-semibold">
                      <button
                        phx-click="sort"
                        phx-value-by="priority"
                        class="flex items-center gap-1 hover:text-primary transition-colors"
                      >
                        Priority
                        <.icon
                          :if={@sort_by == :priority}
                          name={
                            if @sort_order == :asc, do: "hero-chevron-up", else: "hero-chevron-down"
                          }
                          class="size-3"
                        />
                      </button>
                    </th>
                    <th class="text-xs font-semibold">Attempts</th>
                    <th class="text-xs font-semibold">
                      <button
                        phx-click="sort"
                        phx-value-by="inserted_at"
                        class="flex items-center gap-1 hover:text-primary transition-colors"
                      >
                        Added
                        <.icon
                          :if={@sort_by == :inserted_at}
                          name={
                            if @sort_order == :asc, do: "hero-chevron-up", else: "hero-chevron-down"
                          }
                          class="size-3"
                        />
                      </button>
                    </th>
                    <th class="text-xs font-semibold">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @queue_items == [] do %>
                    <tr>
                      <td colspan="6" class="text-center py-12 text-base-content/50">
                        <div class="flex flex-col items-center gap-2">
                          <.icon name="hero-inbox" class="size-10 opacity-50" />
                          <p class="text-sm">No items in queue</p>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                  <%= for item <- @queue_items do %>
                    <tr class="hover:bg-base-200/50 transition-colors">
                      <td class="py-3">
                        <div class="flex items-center gap-1.5">
                          <.icon name={status_icon(item.status)} class="size-4" />
                          <span class={status_badge_class(item.status)}>
                            {item.status |> to_string() |> String.capitalize()}
                          </span>
                        </div>
                      </td>
                      <td class="py-3">
                        <div class="font-medium text-sm">{item.audiobook.title}</div>
                        <div class="text-xs text-base-content/60 truncate max-w-md">
                          {item.audiobook.url}
                        </div>
                        <%= if item.error_message do %>
                          <div class="text-xs text-error mt-0.5">{item.error_message}</div>
                        <% end %>
                      </td>
                      <td class="py-3">
                        <div class="flex items-center gap-1.5">
                          <span class="font-mono text-sm">{item.priority}</span>
                          <div class="join join-vertical">
                            <button
                              phx-click="increase_priority"
                              phx-value-id={item.id}
                              class="btn btn-xs join-item"
                              title="Increase priority"
                            >
                              <.icon name="hero-chevron-up" class="size-2.5" />
                            </button>
                            <button
                              phx-click="decrease_priority"
                              phx-value-id={item.id}
                              class="btn btn-xs join-item"
                              title="Decrease priority"
                              disabled={item.priority == 0}
                            >
                              <.icon name="hero-chevron-down" class="size-2.5" />
                            </button>
                          </div>
                        </div>
                      </td>
                      <td class="py-3">
                        <span class="font-mono text-xs text-base-content/70">
                          {item.attempts}/{item.max_attempts}
                        </span>
                      </td>
                      <td class="py-3">
                        <span class="text-xs text-base-content/60">
                          {Calendar.strftime(item.inserted_at, "%Y-%m-%d %H:%M")}
                        </span>
                      </td>
                      <td class="py-3">
                        <div class="flex gap-0.5">
                          <button
                            :if={item.status == :failed}
                            phx-click="retry_item"
                            phx-value-id={item.id}
                            class="btn btn-xs btn-ghost"
                            title="Retry"
                          >
                            <.icon name="hero-arrow-path" class="size-3.5" />
                          </button>
                          <button
                            phx-click="delete_item"
                            phx-value-id={item.id}
                            class="btn btn-xs btn-ghost text-error"
                            title="Delete"
                            data-confirm="Are you sure you want to delete this item?"
                          >
                            <.icon name="hero-trash" class="size-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
