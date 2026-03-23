defmodule CloWeb.Admin.ApiKeysLive do
  @moduledoc "Admin API key management: create, revoke, delete keys."
  use CloWeb, :live_view
  import CloWeb.ClioComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "API Keys",
       active_view: :admin_api_keys,
       api_keys: Clio.ApiKeys.list(),
       # Create form
       new_name: "",
       new_description: "",
       new_permissions: MapSet.new(),
       new_expiration: "",
       # Newly created key display
       new_key_display: nil,
       create_error: nil
     )}
  end

  @impl true
  def handle_event("toggle_permission", %{"perm" => perm}, socket) do
    perms = socket.assigns.new_permissions
    perms = if MapSet.member?(perms, perm), do: MapSet.delete(perms, perm), else: MapSet.put(perms, perm)
    {:noreply, assign(socket, new_permissions: perms)}
  end

  def handle_event("create_key", params, socket) do
    attrs = %{
      name: params["name"],
      description: params["description"],
      permissions: MapSet.to_list(socket.assigns.new_permissions),
      created_by: socket.assigns.current_user.username,
      is_active: true
    }

    attrs = if params["expiration"] && params["expiration"] != "" do
      case DateTime.from_iso8601(params["expiration"] <> ":00Z") do
        {:ok, dt, _} -> Map.put(attrs, :expires_at, dt)
        _ -> attrs
      end
    else
      attrs
    end

    case Clio.ApiKeys.create(attrs) do
      {:ok, _api_key, full_key} ->
        {:noreply,
         assign(socket,
           api_keys: Clio.ApiKeys.list(),
           new_key_display: full_key,
           new_name: "",
           new_description: "",
           new_permissions: MapSet.new(),
           new_expiration: "",
           create_error: nil
         )}
      {:error, changeset} ->
        {:noreply, assign(socket, create_error: "Failed: #{inspect(changeset.errors)}")}
    end
  end

  def handle_event("revoke_key", %{"id" => id}, socket) do
    Clio.ApiKeys.revoke(String.to_integer(id))
    {:noreply, assign(socket, api_keys: Clio.ApiKeys.list())}
  end

  def handle_event("delete_key", %{"id" => id}, socket) do
    Clio.ApiKeys.delete(String.to_integer(id))
    {:noreply, assign(socket, api_keys: Clio.ApiKeys.list())}
  end

  def handle_event("dismiss_key_display", _params, socket) do
    {:noreply, assign(socket, new_key_display: nil)}
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

      <%!-- New Key Display --%>
      <%= if @new_key_display do %>
        <div class="bg-yellow-900/50 border border-yellow-600 rounded-lg p-4 mb-6">
          <div class="flex items-center justify-between mb-2">
            <h3 class="text-yellow-300 font-semibold">New API Key Created</h3>
            <button phx-click="dismiss_key_display" class="text-gray-400 hover:text-white">
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>
          <p class="text-yellow-200 text-sm mb-2">This key will only be shown once. Copy it now.</p>
          <div class="flex items-center gap-2">
            <code class="flex-1 bg-gray-900 text-green-400 px-3 py-2 rounded font-mono text-sm break-all">{@new_key_display}</code>
            <button
              phx-hook="ClipboardCopy"
              id="copy-api-key"
              data-content={@new_key_display}
              class="px-3 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm"
            >
              Copy
            </button>
          </div>
        </div>
      <% end %>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- Keys Table --%>
        <div class="lg:col-span-2 bg-gray-800 rounded-lg shadow-lg p-4">
          <h2 class="text-xl font-bold text-white mb-4">API Keys</h2>
          <div class="overflow-x-auto">
            <table class="w-full text-sm text-left">
              <thead class="text-xs text-gray-400 uppercase bg-gray-700">
                <tr>
                  <th class="px-4 py-3">Name</th>
                  <th class="px-4 py-3">Key ID</th>
                  <th class="px-4 py-3">Permissions</th>
                  <th class="px-4 py-3">Status</th>
                  <th class="px-4 py-3">Created</th>
                  <th class="px-4 py-3">Last Used</th>
                  <th class="px-4 py-3">Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for key <- @api_keys do %>
                  <tr class="border-b border-gray-700 hover:bg-gray-700">
                    <td class="px-4 py-3 text-white">{key.name}</td>
                    <td class="px-4 py-3 text-gray-300 font-mono text-xs">{key.key_id}</td>
                    <td class="px-4 py-3">
                      <div class="flex flex-wrap gap-1">
                        <%= for perm <- key.permissions || [] do %>
                          <span class="bg-gray-700 text-gray-300 px-1.5 py-0.5 rounded text-xs">{perm}</span>
                        <% end %>
                      </div>
                    </td>
                    <td class="px-4 py-3">
                      <span class={"px-2 py-1 rounded text-xs #{if key.is_active, do: "bg-green-600/20 text-green-300", else: "bg-red-600/20 text-red-300"}"}>
                        {if key.is_active, do: "Active", else: "Revoked"}
                      </span>
                    </td>
                    <td class="px-4 py-3 text-gray-400 text-xs">{format_dt(key.inserted_at)}</td>
                    <td class="px-4 py-3 text-gray-400 text-xs">{format_dt(key.last_used)}</td>
                    <td class="px-4 py-3">
                      <div class="flex items-center gap-2">
                        <%= if key.is_active do %>
                          <button phx-click="revoke_key" phx-value-id={key.id}
                            class="text-yellow-400 hover:text-yellow-300 text-xs">Revoke</button>
                        <% end %>
                        <button phx-click="delete_key" phx-value-id={key.id}
                          class="text-red-400 hover:text-red-300 text-xs"
                          data-confirm="Delete this API key?">Delete</button>
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Create Form --%>
        <div class="bg-gray-800 rounded-lg shadow-lg p-4">
          <h3 class="text-lg font-semibold text-white mb-3">Create API Key</h3>
          <%= if @create_error do %>
            <div class="bg-red-900 text-red-200 rounded-md p-3 mb-3 text-sm">{@create_error}</div>
          <% end %>
          <form phx-submit="create_key" class="space-y-3">
            <div>
              <label class="text-xs text-gray-400 block mb-1">Name</label>
              <input type="text" name="name" value={@new_name} required
                class="w-full bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md" />
            </div>
            <div>
              <label class="text-xs text-gray-400 block mb-1">Description</label>
              <textarea name="description" rows="2"
                class="w-full bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md">{@new_description}</textarea>
            </div>
            <div>
              <label class="text-xs text-gray-400 block mb-1">Permissions</label>
              <div class="space-y-1">
                <%= for perm <- ["logs:read", "logs:write", "logs:admin"] do %>
                  <label class="flex items-center gap-2 text-sm text-gray-300 cursor-pointer">
                    <input type="checkbox" checked={MapSet.member?(@new_permissions, perm)}
                      phx-click="toggle_permission" phx-value-perm={perm}
                      class="rounded bg-gray-700 border-gray-600 text-blue-600" />
                    {perm}
                  </label>
                <% end %>
              </div>
            </div>
            <div>
              <label class="text-xs text-gray-400 block mb-1">Expiration (optional)</label>
              <input type="datetime-local" name="expiration" value={@new_expiration}
                class="w-full bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md" />
            </div>
            <button type="submit" class="w-full bg-blue-600 text-white py-2 rounded-md hover:bg-blue-700">
              Create Key
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp format_dt(nil), do: "Never"
  defp format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_dt(other), do: to_string(other)
end
