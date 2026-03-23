defmodule CloWeb.Admin.OperationsLive do
  @moduledoc "Admin operations management: create, assign users, deactivate."
  use CloWeb, :live_view
  import CloWeb.ClioComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Operations",
       active_view: :admin_operations,
       operations: Clio.Operations.list_operations(),
       selected_operation: nil,
       assigned_users: [],
       # Create form
       new_name: "",
       new_description: "",
       create_error: nil,
       # Assign form
       assign_username: ""
     )}
  end

  @impl true
  def handle_event("create_operation", %{"name" => name, "description" => desc}, socket) do
    user = socket.assigns.current_user

    tag_attrs = %{
      name: "op:#{String.downcase(name)}",
      category: "operation",
      color: "#3B82F6",
      created_by: user.username
    }

    case Clio.Tags.get_or_create(tag_attrs.name, category: tag_attrs.category, color: tag_attrs.color, created_by: tag_attrs.created_by) do
      {:ok, tag} ->
        attrs = %{name: name, description: desc, tag_id: tag.id, is_active: true, created_by: user.username}
        case Clio.Operations.create_operation(attrs) do
          {:ok, _op} ->
            {:noreply, assign(socket, operations: Clio.Operations.list_operations(), new_name: "", new_description: "", create_error: nil)}
          {:error, changeset} ->
            {:noreply, assign(socket, create_error: "Failed to create: #{inspect(changeset.errors)}")}
        end
      {:error, _} ->
        {:noreply, assign(socket, create_error: "Failed to create operation tag")}
    end
  end

  def handle_event("select_operation", %{"id" => id}, socket) do
    id = String.to_integer(id)
    case Clio.Operations.get_operation(id) do
      {:ok, op} ->
        assigned = op.user_operations || []
        {:noreply, assign(socket, selected_operation: op, assigned_users: assigned)}
      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("deactivate", %{"id" => id}, socket) do
    Clio.Operations.deactivate_operation(String.to_integer(id))
    {:noreply, assign(socket, operations: Clio.Operations.list_operations(), selected_operation: nil)}
  end

  def handle_event("assign_user", %{"username" => username}, socket) do
    op = socket.assigns.selected_operation
    user = socket.assigns.current_user

    case Clio.Operations.assign_user(op.id, username, user.username) do
      {:ok, _} ->
        {:ok, op} = Clio.Operations.get_operation(op.id)
        {:noreply, assign(socket, selected_operation: op, assigned_users: op.user_operations || [], assign_username: "")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to assign user")}
    end
  end

  def handle_event("unassign_user", %{"username" => username}, socket) do
    op = socket.assigns.selected_operation
    Clio.Operations.unassign_user(op.id, username)
    {:ok, op} = Clio.Operations.get_operation(op.id)
    {:noreply, assign(socket, selected_operation: op, assigned_users: op.user_operations || [])}
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
    {:noreply, assign(socket, user_operations: operations, active_operation: active_op)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.nav_bar current_user={@current_user} active_view={@active_view} />

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- Operations List --%>
        <div class="lg:col-span-2">
          <div class="bg-gray-800 rounded-lg shadow-lg p-4">
            <h2 class="text-xl font-bold text-white mb-4">Operations</h2>
            <div class="overflow-x-auto">
              <table class="w-full text-sm text-left">
                <thead class="text-xs text-gray-400 uppercase bg-gray-700">
                  <tr>
                    <th class="px-4 py-3">Name</th>
                    <th class="px-4 py-3">Description</th>
                    <th class="px-4 py-3">Status</th>
                    <th class="px-4 py-3">Tag</th>
                    <th class="px-4 py-3">Created</th>
                    <th class="px-4 py-3">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for op <- @operations do %>
                    <tr class={"border-b border-gray-700 hover:bg-gray-700 cursor-pointer #{if @selected_operation && @selected_operation.id == op.id, do: "bg-gray-700"}"}
                        phx-click="select_operation" phx-value-id={op.id}>
                      <td class="px-4 py-3 text-white font-medium">{op.name}</td>
                      <td class="px-4 py-3 text-gray-300 text-xs">{op.description || "-"}</td>
                      <td class="px-4 py-3">
                        <span class={"px-2 py-1 rounded-full text-xs #{if op.is_active, do: "bg-green-600/20 text-green-300", else: "bg-red-600/20 text-red-300"}"}>
                          {if op.is_active, do: "Active", else: "Inactive"}
                        </span>
                      </td>
                      <td class="px-4 py-3">
                        <%= if op.tag do %>
                          <span class="w-3 h-3 rounded-full inline-block" style={"background-color: #{op.tag.color || "#6B7280"}"}></span>
                        <% end %>
                      </td>
                      <td class="px-4 py-3 text-gray-400 text-xs">{format_dt(op.inserted_at)}</td>
                      <td class="px-4 py-3">
                        <%= if op.is_active do %>
                          <button phx-click="deactivate" phx-value-id={op.id}
                            class="text-red-400 hover:text-red-300 text-xs" data-confirm="Deactivate this operation?">
                            Deactivate
                          </button>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <%!-- Right Panel --%>
        <div class="space-y-6">
          <%!-- Create Form --%>
          <div class="bg-gray-800 rounded-lg shadow-lg p-4">
            <h3 class="text-lg font-semibold text-white mb-3">Create Operation</h3>
            <%= if @create_error do %>
              <div class="bg-red-900 text-red-200 rounded-md p-3 mb-3 text-sm">{@create_error}</div>
            <% end %>
            <form phx-submit="create_operation" class="space-y-3">
              <input type="text" name="name" value={@new_name} placeholder="Operation name" required
                class="w-full bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md" />
              <textarea name="description" placeholder="Description" rows="3"
                class="w-full bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md">{@new_description}</textarea>
              <button type="submit" class="w-full bg-blue-600 text-white py-2 rounded-md hover:bg-blue-700">
                Create
              </button>
            </form>
          </div>

          <%!-- User Assignment Panel --%>
          <%= if @selected_operation do %>
            <div class="bg-gray-800 rounded-lg shadow-lg p-4">
              <h3 class="text-lg font-semibold text-white mb-3">
                Users: {@selected_operation.name}
              </h3>
              <form phx-submit="assign_user" class="flex gap-2 mb-4">
                <input type="text" name="username" value={@assign_username} placeholder="Username"
                  class="flex-1 bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md" />
                <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">
                  Assign
                </button>
              </form>
              <div class="space-y-2">
                <%= for uo <- @assigned_users do %>
                  <div class="flex items-center justify-between bg-gray-700 rounded p-2">
                    <div>
                      <span class="text-white text-sm">{uo.username}</span>
                      <%= if uo.is_primary do %>
                        <span class="ml-2 text-xs bg-blue-500/30 text-blue-300 px-1.5 py-0.5 rounded">Primary</span>
                      <% end %>
                    </div>
                    <button phx-click="unassign_user" phx-value-username={uo.username}
                      class="text-red-400 hover:text-red-300 text-xs">Remove</button>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_dt(nil), do: "-"
  defp format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
  defp format_dt(other), do: to_string(other)
end
