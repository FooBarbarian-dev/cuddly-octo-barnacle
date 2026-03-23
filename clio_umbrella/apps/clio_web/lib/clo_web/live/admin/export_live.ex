defmodule CloWeb.Admin.ExportLive do
  @moduledoc "Admin export view: CSV/JSON export with column selection, archives list."
  use CloWeb, :live_view
  import CloWeb.ClioComponents

  @all_columns ~w(timestamp internal_ip external_ip hostname domain username command notes filename status hash_algorithm hash_value pid analyst mac_address secrets)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, archives} = Clio.Export.list_archives()

    {:ok,
     assign(socket,
       page_title: "Export",
       active_view: :admin_export,
       columns: MapSet.new(@all_columns),
       all_columns: @all_columns,
       format: :csv,
       include_relationships: false,
       include_hashes: false,
       exporting: false,
       export_result: nil,
       archives: archives
     )}
  end

  @impl true
  def handle_event("toggle_column", %{"column" => col}, socket) do
    columns = socket.assigns.columns
    columns = if MapSet.member?(columns, col), do: MapSet.delete(columns, col), else: MapSet.put(columns, col)
    {:noreply, assign(socket, columns: columns)}
  end

  def handle_event("set_format", %{"format" => format}, socket) do
    {:noreply, assign(socket, format: String.to_atom(format))}
  end

  def handle_event("toggle_option", %{"option" => opt}, socket) do
    key = String.to_existing_atom(opt)
    {:noreply, assign(socket, [{key, !Map.get(socket.assigns, key)}])}
  end

  def handle_event("export", _params, socket) do
    socket = assign(socket, exporting: true)

    opts = %{
      columns: MapSet.to_list(socket.assigns.columns),
      format: socket.assigns.format
    }

    case Clio.Export.export_logs(opts) do
      {:ok, result} ->
        {:ok, archives} = Clio.Export.list_archives()
        {:noreply, assign(socket, exporting: false, export_result: result, archives: archives)}
      {:error, reason} ->
        {:noreply, socket |> assign(exporting: false) |> put_flash(:error, "Export failed: #{inspect(reason)}")}
    end
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
    active_op = case Clio.Operations.get_active_operation(user.username) do {:ok, op} -> op; _ -> nil end
    {:noreply, assign(socket, user_operations: operations, active_operation: active_op)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.nav_bar current_user={@current_user} active_view={@active_view} />

      <div class="space-y-6">
        <div class="bg-gray-800 rounded-lg shadow-lg p-6">
          <h2 class="text-xl font-bold text-white mb-4">Export Logs</h2>

          <%!-- Column Selector --%>
          <div class="mb-6">
            <h3 class="text-sm font-medium text-gray-300 mb-2">Select Columns</h3>
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-2">
              <%= for col <- @all_columns do %>
                <label class="flex items-center gap-2 text-sm text-gray-300 cursor-pointer">
                  <input type="checkbox" checked={MapSet.member?(@columns, col)} phx-click="toggle_column" phx-value-column={col}
                    class="rounded bg-gray-700 border-gray-600 text-blue-600 focus:ring-blue-500" />
                  {col}
                </label>
              <% end %>
            </div>
          </div>

          <%!-- Format --%>
          <div class="mb-6">
            <h3 class="text-sm font-medium text-gray-300 mb-2">Format</h3>
            <div class="flex gap-4">
              <label class="flex items-center gap-2 text-sm text-gray-300 cursor-pointer">
                <input type="radio" name="format" value="csv" checked={@format == :csv} phx-click="set_format" phx-value-format="csv"
                  class="bg-gray-700 border-gray-600 text-blue-600" />
                CSV
              </label>
              <label class="flex items-center gap-2 text-sm text-gray-300 cursor-pointer">
                <input type="radio" name="format" value="json" checked={@format == :json} phx-click="set_format" phx-value-format="json"
                  class="bg-gray-700 border-gray-600 text-blue-600" />
                JSON
              </label>
            </div>
          </div>

          <%!-- Options --%>
          <div class="mb-6 flex gap-6">
            <label class="flex items-center gap-2 text-sm text-gray-300 cursor-pointer">
              <input type="checkbox" checked={@include_relationships} phx-click="toggle_option" phx-value-option="include_relationships"
                class="rounded bg-gray-700 border-gray-600 text-blue-600" />
              Include Relationships
            </label>
            <label class="flex items-center gap-2 text-sm text-gray-300 cursor-pointer">
              <input type="checkbox" checked={@include_hashes} phx-click="toggle_option" phx-value-option="include_hashes"
                class="rounded bg-gray-700 border-gray-600 text-blue-600" />
              Include Hashes
            </label>
          </div>

          <button phx-click="export" class="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2" disabled={@exporting}>
            <%= if @exporting do %>
              <.icon name="hero-arrow-path" class="w-5 h-5 animate-spin" /> Exporting...
            <% else %>
              <.icon name="hero-circle-stack" class="w-5 h-5" /> Export
            <% end %>
          </button>

          <%= if @export_result do %>
            <div class="mt-4 bg-green-900/50 border border-green-700 rounded-lg p-4">
              <p class="text-green-300">Export complete: {@export_result.count} logs exported.</p>
              <p class="text-green-400 text-sm mt-1">File: {@export_result.filename}</p>
            </div>
          <% end %>
        </div>

        <%!-- Archives --%>
        <div class="bg-gray-800 rounded-lg shadow-lg p-6">
          <h2 class="text-xl font-bold text-white mb-4">Previous Exports</h2>
          <%= if Enum.empty?(@archives) do %>
            <p class="text-gray-500">No archives found.</p>
          <% else %>
            <div class="space-y-2">
              <%= for archive <- @archives do %>
                <div class="flex items-center justify-between bg-gray-700 rounded p-3">
                  <div>
                    <span class="text-white text-sm">{archive.filename}</span>
                    <span class="text-gray-400 text-xs ml-2">{format_size(archive.size)}</span>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
