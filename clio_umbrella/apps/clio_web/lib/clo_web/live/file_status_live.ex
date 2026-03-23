defmodule CloWeb.FileStatusLive do
  @moduledoc "File status tracking view with filters and expandable history."
  use CloWeb, :live_view
  import CloWeb.ClioComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "File Status",
       active_view: :file_status,
       file_statuses: [],
       filter_status: "all",
       filter_hostname: "",
       filter_analyst: "",
       expanded_files: MapSet.new(),
       file_histories: %{}
     )
     |> load_data()}
  end

  defp load_data(socket) do
    opts = [
      status: socket.assigns.filter_status,
      hostname: socket.assigns.filter_hostname,
      analyst: socket.assigns.filter_analyst
    ]

    statuses = Clio.RelationsContext.list_file_statuses(opts)
    assign(socket, file_statuses: statuses)
  end

  @impl true
  def handle_event("filter_changed", params, socket) do
    {:noreply,
     socket
     |> assign(
       filter_status: params["status"] || "all",
       filter_hostname: params["hostname"] || "",
       filter_analyst: params["analyst"] || ""
     )
     |> load_data()}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, load_data(socket)}
  end

  def handle_event("toggle_file", %{"id" => id}, socket) do
    id = String.to_integer(id)
    expanded = socket.assigns.expanded_files

    {expanded, histories} =
      if MapSet.member?(expanded, id) do
        {MapSet.delete(expanded, id), socket.assigns.file_histories}
      else
        # Load history for this file
        fs = Enum.find(socket.assigns.file_statuses, &(&1.id == id))
        history = if fs, do: Clio.RelationsContext.get_file_history(fs.filename), else: []
        {MapSet.put(expanded, id), Map.put(socket.assigns.file_histories, id, history)}
      end

    {:noreply, assign(socket, expanded_files: expanded, file_histories: histories)}
  end

  def handle_event("logout", _params, socket) do
    user = socket.assigns.current_user
    if user[:jti], do: Clio.Auth.revoke_token(user.jti, user.username)
    {:noreply, redirect(socket, to: "/login")}
  end

  @impl true
  def handle_info({:switch_operation, op_id}, socket) do
    user = socket.assigns.current_user
    Clio.Operations.set_primary_operation(user.username, op_id)
    operations = Clio.Operations.get_user_operations(user.username)
    active_op = case Clio.Operations.get_active_operation(user.username) do
      {:ok, op} -> op
      _ -> nil
    end
    {:noreply, socket |> assign(user_operations: operations, active_operation: active_op) |> load_data()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.nav_bar current_user={@current_user} active_view={@active_view} />

      <div class="flex items-center gap-3 mb-6">
        <.icon name="hero-document" class="w-8 h-8 text-blue-400" />
        <h2 class="text-2xl font-bold text-white">File Status Tracker</h2>
      </div>

      <%!-- Filters --%>
      <div class="bg-gray-800 rounded-lg p-4 mb-4">
        <form phx-change="filter_changed" class="flex flex-wrap items-center gap-4">
          <div>
            <label class="text-xs text-gray-400 block mb-1">Status</label>
            <select name="status" class="bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md">
              <option value="all" selected={@filter_status == "all"}>All Statuses</option>
              <%= for s <- ~w(ON_DISK IN_MEMORY ENCRYPTED REMOVED CLEANED DORMANT DETECTED UNKNOWN) do %>
                <option value={s} selected={@filter_status == s}>{s}</option>
              <% end %>
            </select>
          </div>
          <div>
            <label class="text-xs text-gray-400 block mb-1">Hostname</label>
            <input type="text" name="hostname" value={@filter_hostname} placeholder="Filter by hostname"
              class="bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md" phx-debounce="300" />
          </div>
          <div>
            <label class="text-xs text-gray-400 block mb-1">Analyst</label>
            <input type="text" name="analyst" value={@filter_analyst} placeholder="Filter by analyst"
              class="bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md" phx-debounce="300" />
          </div>
          <div class="self-end">
            <button type="button" phx-click="refresh" class="px-3 py-2 bg-gray-700 text-gray-300 rounded-md hover:bg-gray-600">
              <.icon name="hero-arrow-path" class="w-5 h-5" />
            </button>
          </div>
        </form>
      </div>

      <%!-- File Table --%>
      <div class="bg-gray-800 rounded-lg overflow-hidden">
        <table class="w-full text-sm text-left">
          <thead class="text-xs text-gray-400 uppercase bg-gray-700">
            <tr>
              <th class="px-4 py-3 w-8"></th>
              <th class="px-4 py-3">Filename</th>
              <th class="px-4 py-3">Status</th>
              <th class="px-4 py-3">Hostname</th>
              <th class="px-4 py-3">Internal IP</th>
              <th class="px-4 py-3">Analyst</th>
              <th class="px-4 py-3">First Seen</th>
              <th class="px-4 py-3">Last Seen</th>
            </tr>
          </thead>
          <tbody>
            <%= for fs <- @file_statuses do %>
              <tr
                class="border-b border-gray-700 hover:bg-gray-700 cursor-pointer"
                phx-click="toggle_file"
                phx-value-id={fs.id}
              >
                <td class="px-4 py-3">
                  <%= if MapSet.member?(@expanded_files, fs.id) do %>
                    <.icon name="hero-chevron-down" class="w-4 h-4 text-white" />
                  <% else %>
                    <.icon name="hero-chevron-right" class="w-4 h-4 text-white" />
                  <% end %>
                </td>
                <td class="px-4 py-3 text-purple-300">{fs.filename}</td>
                <td class="px-4 py-3"><.status_badge status={fs.status} /></td>
                <td class="px-4 py-3 text-white">{fs.hostname || "-"}</td>
                <td class="px-4 py-3 text-blue-300">{fs.internal_ip || "-"}</td>
                <td class="px-4 py-3 text-gray-300">{fs.analyst || "-"}</td>
                <td class="px-4 py-3 text-gray-400 text-xs">{format_ts(fs.first_seen)}</td>
                <td class="px-4 py-3 text-gray-400 text-xs">{format_ts(fs.last_seen)}</td>
              </tr>
              <%= if MapSet.member?(@expanded_files, fs.id) do %>
                <tr>
                  <td colspan="8" class="px-8 py-4 bg-gray-700/30">
                    <h4 class="text-sm font-medium text-white mb-3">Status History</h4>
                    <%= case Map.get(@file_histories, fs.id, []) do %>
                      <% [] -> %>
                        <p class="text-gray-500 text-sm">No history records.</p>
                      <% history -> %>
                        <div class="space-y-2">
                          <%= for h <- history do %>
                            <div class="flex items-center gap-4 text-sm bg-gray-700/50 rounded p-2">
                              <span class="text-gray-400 text-xs">{format_ts(h.timestamp)}</span>
                              <span class={status_text_class(h.previous_status || "UNKNOWN")}>
                                {h.previous_status || "?"}
                              </span>
                              <.icon name="hero-arrow-right" class="w-4 h-4 text-gray-500" />
                              <span class={status_text_class(h.status)}>
                                {h.status}
                              </span>
                            </div>
                          <% end %>
                        </div>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
        <%= if Enum.empty?(@file_statuses) do %>
          <p class="text-gray-500 text-center py-8">No file status records found.</p>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_ts(nil), do: "-"
  defp format_ts(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_ts(other), do: to_string(other)
end
