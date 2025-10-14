defmodule OhdioWeb.LibraryLive do
  use OhdioWeb, :live_view

  alias Ohdio.Library
  alias Ohdio.Downloads

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Library")
     |> assign(:search, "")
     |> assign(:sort_by, :inserted_at)
     |> assign(:sort_order, :desc)
     |> assign(:selected_audiobook, nil)
     |> assign(:selected_ids, MapSet.new())
     |> assign(:bulk_downloading, false)
     |> assign(:view_mode, "grid")
     |> load_audiobooks()}
  end

  @impl Phoenix.LiveView
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     socket
     |> assign(:search, search)
     |> load_audiobooks()}
  end

  @impl Phoenix.LiveView
  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    sort_by_atom = String.to_existing_atom(sort_by)

    # Toggle sort order if clicking the same field
    sort_order =
      if socket.assigns.sort_by == sort_by_atom do
        toggle_sort_order(socket.assigns.sort_order)
      else
        :asc
      end

    {:noreply,
     socket
     |> assign(:sort_by, sort_by_atom)
     |> assign(:sort_order, sort_order)
     |> load_audiobooks()}
  end

  @impl Phoenix.LiveView
  def handle_event("show_details", %{"id" => id}, socket) do
    audiobook = Library.get_audiobook!(id)
    {:noreply, assign(socket, :selected_audiobook, audiobook)}
  end

  @impl Phoenix.LiveView
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :selected_audiobook, nil)}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    audiobook = Library.get_audiobook!(id)

    case Library.delete_audiobook(audiobook) do
      {:ok, _audiobook} ->
        # Delete the file if it exists
        if audiobook.file_path && File.exists?(audiobook.file_path) do
          File.rm(audiobook.file_path)
        end

        {:noreply,
         socket
         |> put_flash(:info, "Audiobook deleted successfully")
         |> assign(:selected_audiobook, nil)
         |> load_audiobooks()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete audiobook")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_selection", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    selected_ids = socket.assigns.selected_ids

    new_selected_ids =
      if MapSet.member?(selected_ids, id) do
        MapSet.delete(selected_ids, id)
      else
        MapSet.put(selected_ids, id)
      end

    {:noreply, assign(socket, :selected_ids, new_selected_ids)}
  end

  @impl Phoenix.LiveView
  def handle_event("select_all", _params, socket) do
    all_ids = Enum.map(socket.assigns.audiobooks, & &1.id) |> MapSet.new()
    {:noreply, assign(socket, :selected_ids, all_ids)}
  end

  @impl Phoenix.LiveView
  def handle_event("deselect_all", _params, socket) do
    {:noreply, assign(socket, :selected_ids, MapSet.new())}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_view", _params, socket) do
    new_view_mode = if socket.assigns.view_mode == "grid", do: "list", else: "grid"

    {:noreply,
     socket
     |> assign(:view_mode, new_view_mode)
     |> push_event("save_view_mode", %{view_mode: new_view_mode})}
  end

  @impl Phoenix.LiveView
  def handle_event("set_view_mode", %{"view_mode" => view_mode}, socket) do
    {:noreply, assign(socket, :view_mode, view_mode)}
  end

  @impl Phoenix.LiveView
  def handle_event("bulk_download", _params, socket) do
    selected_ids = socket.assigns.selected_ids

    if MapSet.size(selected_ids) == 0 do
      {:noreply, put_flash(socket, :error, "No audiobooks selected")}
    else
      socket = assign(socket, :bulk_downloading, true)

      # Get selected audiobooks
      selected_audiobooks =
        socket.assigns.audiobooks
        |> Enum.filter(&MapSet.member?(selected_ids, &1.id))

      # Create queue items for each selected audiobook
      results =
        Enum.map(selected_audiobooks, fn audiobook ->
          Downloads.create_queue_item(%{audiobook_id: audiobook.id})
        end)

      # Count successes and failures
      {successes, failures} =
        Enum.reduce(results, {0, 0}, fn
          {:ok, _}, {s, f} -> {s + 1, f}
          {:error, _}, {s, f} -> {s, f + 1}
        end)

      socket =
        socket
        |> assign(:bulk_downloading, false)
        |> assign(:selected_ids, MapSet.new())

      socket =
        cond do
          successes > 0 and failures == 0 ->
            put_flash(
              socket,
              :info,
              "#{successes} audiobook#{if successes == 1, do: "", else: "s"} added to download queue"
            )

          successes > 0 and failures > 0 ->
            put_flash(
              socket,
              :info,
              "#{successes} audiobook#{if successes == 1, do: "", else: "s"} added to queue, #{failures} failed (may already be queued)"
            )

          true ->
            put_flash(
              socket,
              :error,
              "Failed to add audiobooks to queue (they may already be queued)"
            )
        end

      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("bulk_delete", _params, socket) do
    selected_ids = socket.assigns.selected_ids

    if MapSet.size(selected_ids) == 0 do
      {:noreply, put_flash(socket, :error, "No audiobooks selected")}
    else
      # Get selected audiobooks
      selected_audiobooks =
        socket.assigns.audiobooks
        |> Enum.filter(&MapSet.member?(selected_ids, &1.id))

      # Delete each audiobook and its file
      {successes, failures} =
        Enum.reduce(selected_audiobooks, {0, 0}, fn audiobook, {s, f} ->
          case Library.delete_audiobook(audiobook) do
            {:ok, _} ->
              # Delete the file if it exists
              if audiobook.file_path && File.exists?(audiobook.file_path) do
                File.rm(audiobook.file_path)
              end

              {s + 1, f}

            {:error, _} ->
              {s, f + 1}
          end
        end)

      socket =
        socket
        |> assign(:selected_ids, MapSet.new())
        |> load_audiobooks()

      socket =
        cond do
          successes > 0 and failures == 0 ->
            put_flash(
              socket,
              :info,
              "#{successes} audiobook#{if successes == 1, do: "", else: "s"} deleted successfully"
            )

          successes > 0 and failures > 0 ->
            put_flash(
              socket,
              :info,
              "#{successes} audiobook#{if successes == 1, do: "", else: "s"} deleted, #{failures} failed"
            )

          true ->
            put_flash(socket, :error, "Failed to delete audiobooks")
        end

      {:noreply, socket}
    end
  end

  defp load_audiobooks(socket) do
    audiobooks =
      Library.list_completed_audiobooks(
        search: socket.assigns.search,
        sort_by: socket.assigns.sort_by,
        sort_order: socket.assigns.sort_order
      )

    assign(socket, :audiobooks, audiobooks)
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(:desc), do: :asc

  defp format_duration(nil), do: "Unknown"

  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    "#{hours}h #{minutes}m"
  end

  defp format_file_size(nil), do: "Unknown"

  defp format_file_size(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  defp sort_icon(current_sort, target_sort, sort_order) do
    if current_sort == target_sort do
      if sort_order == :asc do
        "hero-chevron-up"
      else
        "hero-chevron-down"
      end
    else
      "hero-chevron-up-down"
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-4" id="library-container" phx-hook="ViewMode">
        <%!-- Unified Toolbar --%>
        <div class="card bg-base-100 shadow-sm border border-base-300 transition-all duration-200">
          <div class="card-body p-3">
            <div class="flex items-center gap-2 flex-wrap">
              <%!-- Search --%>
              <div class="flex-1 min-w-[180px]">
                <.form for={%{}} id="search-form" phx-change="search" class="mb-0">
                  <input
                    name="search"
                    type="text"
                    value={@search}
                    placeholder="Search..."
                    class="input input-sm input-bordered w-full"
                  />
                </.form>
              </div>

              <%!-- Sort Buttons (Join) --%>
              <div class="join">
                <button
                  phx-click="sort"
                  phx-value-sort_by="inserted_at"
                  class={[
                    "join-item btn btn-sm transition-all duration-150",
                    if(@sort_by == :inserted_at, do: "btn-active", else: "")
                  ]}
                >
                  <.icon name={sort_icon(@sort_by, :inserted_at, @sort_order)} class="size-4" />
                  <span class="hidden sm:inline ml-1">Date</span>
                </button>
                <button
                  phx-click="sort"
                  phx-value-sort_by="title"
                  class={[
                    "join-item btn btn-sm transition-all duration-150",
                    if(@sort_by == :title, do: "btn-active", else: "")
                  ]}
                >
                  <.icon name={sort_icon(@sort_by, :title, @sort_order)} class="size-4" />
                  <span class="hidden sm:inline ml-1">Title</span>
                </button>
                <button
                  phx-click="sort"
                  phx-value-sort_by="author"
                  class={[
                    "join-item btn btn-sm transition-all duration-150",
                    if(@sort_by == :author, do: "btn-active", else: "")
                  ]}
                >
                  <.icon name={sort_icon(@sort_by, :author, @sort_order)} class="size-4" />
                  <span class="hidden sm:inline ml-1">Author</span>
                </button>
              </div>

              <%!-- View Toggle (Join) --%>
              <div class="join">
                <button
                  phx-click="toggle_view"
                  class={[
                    "join-item btn btn-sm transition-all duration-150",
                    if(@view_mode == "grid", do: "btn-active", else: "")
                  ]}
                  title="Grid view"
                >
                  <.icon name="hero-squares-2x2" class="size-4" />
                </button>
                <button
                  phx-click="toggle_view"
                  class={[
                    "join-item btn btn-sm transition-all duration-150",
                    if(@view_mode == "list", do: "btn-active", else: "")
                  ]}
                  title="List view"
                >
                  <.icon name="hero-list-bullet" class="size-4" />
                </button>
              </div>

              <%!-- Bulk Actions --%>
              <%= if @audiobooks != [] do %>
                <div class="divider divider-horizontal hidden lg:flex mx-0"></div>

                <div class="join">
                  <%= if MapSet.size(@selected_ids) == length(@audiobooks) and length(@audiobooks) > 0 do %>
                    <button
                      phx-click="deselect_all"
                      class="join-item btn btn-sm transition-all duration-150"
                    >
                      <.icon name="hero-minus-circle" class="size-4" />
                      <span class="hidden sm:inline ml-1">Deselect</span>
                    </button>
                  <% else %>
                    <button
                      phx-click="select_all"
                      class="join-item btn btn-sm transition-all duration-150"
                    >
                      <.icon name="hero-check-circle" class="size-4" />
                      <span class="hidden sm:inline ml-1">Select All</span>
                    </button>
                  <% end %>

                  <%= if MapSet.size(@selected_ids) > 0 do %>
                    <button
                      phx-click="bulk_download"
                      disabled={@bulk_downloading}
                      class="join-item btn btn-sm btn-primary transition-all duration-150"
                    >
                      <%= if @bulk_downloading do %>
                        <span class="loading loading-spinner loading-sm"></span>
                        <span class="hidden sm:inline ml-1">Processing...</span>
                      <% else %>
                        <.icon name="hero-arrow-down-tray" class="size-4" />
                        <span class="hidden sm:inline ml-1">Download</span>
                      <% end %>
                    </button>

                    <button
                      phx-click="bulk_delete"
                      data-confirm="Are you sure you want to delete the selected audiobooks? This action cannot be undone."
                      class="join-item btn btn-sm btn-error transition-all duration-150"
                    >
                      <.icon name="hero-trash" class="size-4" />
                      <span class="hidden sm:inline ml-1">Delete</span>
                    </button>
                  <% end %>
                </div>

                <%= if MapSet.size(@selected_ids) > 0 do %>
                  <span class="text-xs text-base-content/70 hidden sm:inline">
                    {MapSet.size(@selected_ids)} selected
                  </span>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Audiobooks Display --%>
        <%= if @audiobooks == [] do %>
          <div class="card bg-base-100 shadow-sm border border-base-300">
            <div class="card-body p-12">
              <div class="flex flex-col items-center gap-2 text-center">
                <.icon name="hero-musical-note" class="size-10 opacity-50 text-base-content/50" />
                <p class="text-sm text-base-content/50">
                  <%= if @search != "" do %>
                    No audiobooks found. Try adjusting your search
                  <% else %>
                    No audiobooks in library yet
                  <% end %>
                </p>
              </div>
            </div>
          </div>
        <% else %>
          <%= if @view_mode == "grid" do %>
            <%!-- Grid View --%>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              <%= for audiobook <- @audiobooks do %>
                <div class={[
                  "card bg-base-100 shadow-sm border hover:bg-base-200/50 transition-all relative",
                  if(MapSet.member?(@selected_ids, audiobook.id),
                    do: "border-primary ring-2 ring-primary/20",
                    else: "border-base-300"
                  )
                ]}>
                  <%!-- Selection Checkbox --%>
                  <div class="absolute top-2 left-2 z-10">
                    <input
                      type="checkbox"
                      checked={MapSet.member?(@selected_ids, audiobook.id)}
                      phx-click="toggle_selection"
                      phx-value-id={audiobook.id}
                      class="checkbox checkbox-primary checkbox-sm"
                    />
                  </div>

                  <div class="flex flex-col h-full">
                    <%!-- Card Content (clickable for details) --%>
                    <div
                      class="cursor-pointer flex-1 flex flex-col"
                      phx-click="show_details"
                      phx-value-id={audiobook.id}
                    >
                      <figure class="aspect-square bg-base-300">
                        <%= if audiobook.cover_image_url do %>
                          <img
                            src={audiobook.cover_image_url}
                            alt={audiobook.title}
                            class="w-full h-full object-cover"
                          />
                        <% else %>
                          <div class="flex items-center justify-center w-full h-full">
                            <.icon name="hero-musical-note" class="size-24 text-base-content/20" />
                          </div>
                        <% end %>
                      </figure>
                      <div class="card-body p-3 flex-1">
                        <h3 class="font-medium text-sm line-clamp-2">{audiobook.title}</h3>
                        <p class="text-xs text-base-content/60 line-clamp-1">{audiobook.author}</p>
                        <%= if audiobook.duration do %>
                          <p class="text-xs text-base-content/50">
                            {format_duration(audiobook.duration)}
                          </p>
                        <% end %>
                      </div>
                    </div>

                    <%!-- Action Button (always at bottom) --%>
                    <div class="card-actions justify-end p-3 pt-0 mt-auto">
                      <%= if audiobook.file_path && File.exists?(audiobook.file_path) do %>
                        <a
                          href={~p"/files/audio/#{audiobook.id}"}
                          download
                          class="btn btn-xs btn-primary transition-all duration-150 w-full"
                          onclick="event.stopPropagation()"
                        >
                          <.icon name="hero-arrow-down-tray" class="size-3" /> Download
                        </a>
                      <% else %>
                        <span class="text-xs text-base-content/50">File not available</span>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <%!-- List View --%>
            <div class="card bg-base-100 border border-base-300 shadow-sm">
              <div class="card-body p-0">
                <div class="overflow-x-auto">
                  <table class="table table-sm">
                    <thead>
                      <tr class="border-b border-base-300">
                        <th class="w-12">
                          <input
                            type="checkbox"
                            checked={
                              MapSet.size(@selected_ids) == length(@audiobooks) and
                                length(@audiobooks) > 0
                            }
                            phx-click={
                              if MapSet.size(@selected_ids) == length(@audiobooks),
                                do: "deselect_all",
                                else: "select_all"
                            }
                            class="checkbox checkbox-primary checkbox-sm"
                          />
                        </th>
                        <th class="w-16"></th>
                        <th class="text-xs font-semibold">Title</th>
                        <th class="text-xs font-semibold">Author</th>
                        <th class="text-xs font-semibold">Duration</th>
                        <th class="text-xs font-semibold">File Size</th>
                        <th class="text-xs font-semibold">Added</th>
                        <th class="text-xs font-semibold">Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for audiobook <- @audiobooks do %>
                        <tr class="hover:bg-base-200/50 transition-colors">
                          <td class="py-3">
                            <input
                              type="checkbox"
                              checked={MapSet.member?(@selected_ids, audiobook.id)}
                              phx-click="toggle_selection"
                              phx-value-id={audiobook.id}
                              class="checkbox checkbox-primary checkbox-sm"
                            />
                          </td>
                          <td class="py-3">
                            <div class="w-12 h-12 bg-base-300 rounded overflow-hidden flex-shrink-0">
                              <%= if audiobook.cover_image_url do %>
                                <img
                                  src={audiobook.cover_image_url}
                                  alt={audiobook.title}
                                  class="w-full h-full object-cover"
                                />
                              <% else %>
                                <div class="flex items-center justify-center w-full h-full">
                                  <.icon name="hero-musical-note" class="size-6 text-base-content/20" />
                                </div>
                              <% end %>
                            </div>
                          </td>
                          <td class="py-3">
                            <div class="font-medium text-sm">{audiobook.title}</div>
                          </td>
                          <td class="py-3">
                            <div class="text-sm text-base-content/70">{audiobook.author}</div>
                          </td>
                          <td class="py-3">
                            <div class="text-sm text-base-content/70">
                              {format_duration(audiobook.duration)}
                            </div>
                          </td>
                          <td class="py-3">
                            <div class="text-sm text-base-content/70">
                              {format_file_size(audiobook.file_size)}
                            </div>
                          </td>
                          <td class="py-3">
                            <span class="text-xs text-base-content/60">
                              {Calendar.strftime(audiobook.inserted_at, "%Y-%m-%d")}
                            </span>
                          </td>
                          <td class="py-3">
                            <div class="flex gap-1">
                              <%= if audiobook.file_path && File.exists?(audiobook.file_path) do %>
                                <a
                                  href={~p"/files/audio/#{audiobook.id}"}
                                  download
                                  class="btn btn-xs btn-primary"
                                  title="Download audiobook"
                                >
                                  <.icon name="hero-arrow-down-tray" class="size-3.5" />
                                </a>
                              <% end %>
                              <button
                                phx-click="show_details"
                                phx-value-id={audiobook.id}
                                class="btn btn-xs btn-ghost"
                                title="View details"
                              >
                                <.icon name="hero-eye" class="size-3.5" />
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
          <% end %>
        <% end %>

        <%!-- Detail Modal --%>
        <%= if @selected_audiobook do %>
          <div
            class="modal modal-open"
            phx-click="close_modal"
            phx-window-keydown="close_modal"
            phx-key="Escape"
          >
            <div
              class="modal-box max-w-4xl border border-base-300"
              phx-click={JS.exec("phx-remove", to: "#close-on-click")}
            >
              <button
                phx-click="close_modal"
                class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
              >
                <.icon name="hero-x-mark" class="size-5" />
              </button>

              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div class="md:col-span-1">
                  <figure class="aspect-square bg-base-300 rounded-lg overflow-hidden border border-base-300">
                    <%= if @selected_audiobook.cover_image_url do %>
                      <img
                        src={@selected_audiobook.cover_image_url}
                        alt={@selected_audiobook.title}
                        class="w-full h-full object-cover"
                      />
                    <% else %>
                      <div class="flex items-center justify-center w-full h-full">
                        <.icon name="hero-musical-note" class="size-24 text-base-content/20" />
                      </div>
                    <% end %>
                  </figure>
                </div>

                <div class="md:col-span-2 space-y-3">
                  <div>
                    <h3 class="text-xl font-bold">{@selected_audiobook.title}</h3>
                    <p class="text-sm text-base-content/60">{@selected_audiobook.author}</p>
                    <%= if @selected_audiobook.narrator do %>
                      <p class="text-xs text-base-content/50">
                        Narrated by {@selected_audiobook.narrator}
                      </p>
                    <% end %>
                  </div>

                  <div class="divider my-2" />

                  <div class="grid grid-cols-2 gap-3 text-xs">
                    <%= if @selected_audiobook.duration do %>
                      <div>
                        <span class="font-semibold text-base-content/70">Duration:</span>
                        <span class="ml-1.5">{format_duration(@selected_audiobook.duration)}</span>
                      </div>
                    <% end %>
                    <%= if @selected_audiobook.file_size do %>
                      <div>
                        <span class="font-semibold text-base-content/70">File Size:</span>
                        <span class="ml-1.5">{format_file_size(@selected_audiobook.file_size)}</span>
                      </div>
                    <% end %>
                  </div>

                  <%= if @selected_audiobook.file_path && File.exists?(@selected_audiobook.file_path) do %>
                    <div class="divider my-2" />

                    <div>
                      <h4 class="font-semibold text-sm mb-2">Audio Player</h4>
                      <audio controls class="w-full">
                        <source src={~p"/files/audio/#{@selected_audiobook.id}"} type="audio/mpeg" />
                        Your browser does not support the audio element.
                      </audio>
                    </div>
                  <% end %>

                  <div class="divider my-2" />

                  <div class="modal-action">
                    <button
                      phx-click="delete"
                      phx-value-id={@selected_audiobook.id}
                      data-confirm="Are you sure you want to delete this audiobook? This action cannot be undone."
                      class="btn btn-sm btn-error"
                    >
                      <.icon name="hero-trash" class="size-4" /> Delete
                    </button>
                    <button phx-click="close_modal" class="btn btn-sm">Close</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
