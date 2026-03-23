defmodule CloWeb.Admin.ApiDocsLive do
  @moduledoc "API documentation view with endpoint references and curl examples."
  use CloWeb, :live_view
  import CloWeb.ClioComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "API Docs",
       active_view: :admin_api_docs,
       expanded_sections: MapSet.new()
     )}
  end

  @impl true
  def handle_event("toggle_section", %{"section" => section}, socket) do
    expanded = socket.assigns.expanded_sections
    expanded = if MapSet.member?(expanded, section), do: MapSet.delete(expanded, section), else: MapSet.put(expanded, section)
    {:noreply, assign(socket, expanded_sections: expanded)}
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

      <div class="bg-gray-800 rounded-lg shadow-lg p-6">
        <div class="flex items-center gap-3 mb-6">
          <.icon name="hero-book-open" class="w-8 h-8 text-blue-400" />
          <h2 class="text-2xl font-bold text-white">API Documentation</h2>
        </div>

        <div class="space-y-4">
          <.api_section title="Authentication" section="auth" expanded={@expanded_sections}>
            <.endpoint method="POST" path="/api/auth/login" desc="Authenticate and receive JWT token">
              <code class="text-sm text-gray-300 block whitespace-pre">curl -X POST /api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "user", "password": "pass"}'</code>
            </.endpoint>
            <.endpoint method="GET" path="/api/auth/verify" desc="Verify current token" />
            <.endpoint method="POST" path="/api/auth/logout" desc="Revoke current token" />
            <.endpoint method="PUT" path="/api/auth/password" desc="Change password" />
          </.api_section>

          <.api_section title="Logs" section="logs" expanded={@expanded_sections}>
            <.endpoint method="GET" path="/api/logs" desc="List logs (with search params)" />
            <.endpoint method="POST" path="/api/logs" desc="Create a new log entry" />
            <.endpoint method="GET" path="/api/logs/:id" desc="Get a single log" />
            <.endpoint method="PUT" path="/api/logs/:id" desc="Update a log entry" />
            <.endpoint method="DELETE" path="/api/logs/:id" desc="Delete a log (admin)" />
            <.endpoint method="POST" path="/api/logs/bulk-delete" desc="Bulk delete logs (admin)" />
            <.endpoint method="POST" path="/api/logs/:id/lock" desc="Lock a log row" />
            <.endpoint method="POST" path="/api/logs/:id/unlock" desc="Unlock a log row" />
          </.api_section>

          <.api_section title="Tags" section="tags" expanded={@expanded_sections}>
            <.endpoint method="GET" path="/api/tags" desc="List all tags" />
            <.endpoint method="POST" path="/api/tags" desc="Create a tag" />
            <.endpoint method="GET" path="/api/tags/search/autocomplete?q=term" desc="Tag autocomplete" />
            <.endpoint method="GET" path="/api/tags/stats/usage" desc="Tag usage statistics" />
            <.endpoint method="POST" path="/api/logs/:log_id/tags/:tag_id" desc="Add tag to log" />
            <.endpoint method="DELETE" path="/api/logs/:log_id/tags/:tag_id" desc="Remove tag from log" />
          </.api_section>

          <.api_section title="Operations" section="operations" expanded={@expanded_sections}>
            <.endpoint method="GET" path="/api/operations" desc="List operations" />
            <.endpoint method="POST" path="/api/operations" desc="Create operation" />
            <.endpoint method="GET" path="/api/operations/mine/list" desc="User's operations" />
            <.endpoint method="POST" path="/api/operations/:id/assign" desc="Assign user" />
            <.endpoint method="POST" path="/api/operations/:id/activate" desc="Set active operation" />
          </.api_section>

          <.api_section title="Evidence" section="evidence" expanded={@expanded_sections}>
            <.endpoint method="GET" path="/api/logs/:log_id/evidence" desc="List evidence for a log" />
            <.endpoint method="POST" path="/api/logs/:log_id/evidence" desc="Upload evidence file" />
            <.endpoint method="GET" path="/api/evidence/:id/download" desc="Download evidence" />
            <.endpoint method="DELETE" path="/api/evidence/:id" desc="Delete evidence" />
          </.api_section>

          <.api_section title="Export" section="export" expanded={@expanded_sections}>
            <.endpoint method="GET" path="/api/export/csv" desc="Export logs as CSV" />
            <.endpoint method="GET" path="/api/export/json" desc="Export logs as JSON" />
          </.api_section>

          <.api_section title="Admin" section="admin" expanded={@expanded_sections}>
            <.endpoint method="GET" path="/api/admin/api-keys" desc="List API keys" />
            <.endpoint method="POST" path="/api/admin/api-keys" desc="Create API key" />
            <.endpoint method="POST" path="/api/admin/api-keys/:id/revoke" desc="Revoke API key" />
            <.endpoint method="GET" path="/api/admin/audit/:category" desc="Get audit logs" />
          </.api_section>
        </div>
      </div>
    </div>
    """
  end

  defp api_section(assigns) do
    is_expanded = MapSet.member?(assigns.expanded, assigns.section)
    assigns = assign(assigns, :is_expanded, is_expanded)

    ~H"""
    <div class="border border-gray-700 rounded-lg">
      <button
        phx-click="toggle_section"
        phx-value-section={@section}
        class="w-full px-4 py-3 flex items-center justify-between hover:bg-gray-700 rounded-lg transition-colors"
      >
        <h3 class="text-lg font-semibold text-white">{@title}</h3>
        <%= if @is_expanded do %>
          <.icon name="hero-chevron-down" class="w-5 h-5 text-gray-400" />
        <% else %>
          <.icon name="hero-chevron-right" class="w-5 h-5 text-gray-400" />
        <% end %>
      </button>
      <%= if @is_expanded do %>
        <div class="px-4 pb-4 space-y-3">
          {render_slot(@inner_block)}
        </div>
      <% end %>
    </div>
    """
  end

  attr :method, :string, required: true
  attr :path, :string, required: true
  attr :desc, :string, required: true
  slot :inner_block

  defp endpoint(assigns) do
    method_class = case assigns.method do
      "GET" -> "bg-green-600/20 text-green-300"
      "POST" -> "bg-blue-600/20 text-blue-300"
      "PUT" -> "bg-yellow-600/20 text-yellow-300"
      "DELETE" -> "bg-red-600/20 text-red-300"
      _ -> "bg-gray-600/20 text-gray-300"
    end
    assigns = assign(assigns, :method_class, method_class)

    ~H"""
    <div class="bg-gray-700/50 rounded p-3">
      <div class="flex items-center gap-3 mb-1">
        <span class={"px-2 py-0.5 rounded text-xs font-mono font-bold #{@method_class}"}>{@method}</span>
        <code class="text-sm text-gray-200">{@path}</code>
      </div>
      <p class="text-xs text-gray-400">{@desc}</p>
      <%= if @inner_block != [] do %>
        <div class="mt-2 bg-gray-900 rounded p-2">
          {render_slot(@inner_block)}
        </div>
      <% end %>
    </div>
    """
  end
end
