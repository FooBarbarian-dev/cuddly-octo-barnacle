defmodule CloWeb.Admin.TagsLive do
  @moduledoc "Admin tag management: create, edit, delete tags with protection for operation tags."
  use CloWeb, :live_view
  import CloWeb.ClioComponents

  @categories ~w(technique tool target status priority workflow evidence security operation custom)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Tags",
       active_view: :admin_tags,
       tag_stats: Clio.Tags.tag_stats(),
       # Form state
       editing_tag: nil,
       form_name: "",
       form_color: "#6B7280",
       form_category: "custom",
       form_description: "",
       form_error: nil,
       categories: @categories
     )}
  end

  @impl true
  def handle_event("create_tag", params, socket) do
    attrs = %{
      name: params["name"],
      color: params["color"],
      category: params["category"],
      description: params["description"],
      created_by: socket.assigns.current_user.username
    }

    case Clio.Tags.create_tag(attrs) do
      {:ok, _} ->
        {:noreply, assign(socket, tag_stats: Clio.Tags.tag_stats(), form_name: "", form_color: "#6B7280",
                          form_category: "custom", form_description: "", form_error: nil)}
      {:error, changeset} ->
        {:noreply, assign(socket, form_error: "Failed: #{inspect(changeset.errors)}")}
    end
  end

  def handle_event("edit_tag", %{"id" => id}, socket) do
    case Clio.Tags.get_tag(String.to_integer(id)) do
      {:ok, tag} ->
        {:noreply, assign(socket, editing_tag: tag, form_name: tag.name, form_color: tag.color,
                          form_category: tag.category, form_description: tag.description || "")}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("update_tag", params, socket) do
    tag = socket.assigns.editing_tag
    attrs = %{
      name: params["name"],
      color: params["color"],
      category: params["category"],
      description: params["description"]
    }

    case Clio.Tags.update_tag(tag.id, attrs) do
      {:ok, _} ->
        {:noreply, assign(socket, tag_stats: Clio.Tags.tag_stats(), editing_tag: nil, form_error: nil)}
      {:error, :operation_tag_protected} ->
        {:noreply, assign(socket, form_error: "Operation tags cannot be modified")}
      {:error, _} ->
        {:noreply, assign(socket, form_error: "Update failed")}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_tag: nil, form_name: "", form_color: "#6B7280",
                      form_category: "custom", form_description: "", form_error: nil)}
  end

  def handle_event("delete_tag", %{"id" => id}, socket) do
    case Clio.Tags.delete_tag(String.to_integer(id)) do
      {:ok, _} -> {:noreply, assign(socket, tag_stats: Clio.Tags.tag_stats())}
      {:error, :operation_tag_protected} -> {:noreply, put_flash(socket, :error, "Operation tags cannot be deleted")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Delete failed")}
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

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <%!-- Tags Table --%>
        <div class="lg:col-span-2 bg-gray-800 rounded-lg shadow-lg p-4">
          <h2 class="text-xl font-bold text-white mb-4">Tags</h2>
          <div class="overflow-x-auto">
            <table class="w-full text-sm text-left">
              <thead class="text-xs text-gray-400 uppercase bg-gray-700">
                <tr>
                  <th class="px-4 py-3">Name</th>
                  <th class="px-4 py-3">Category</th>
                  <th class="px-4 py-3">Color</th>
                  <th class="px-4 py-3">Usage</th>
                  <th class="px-4 py-3">Created By</th>
                  <th class="px-4 py-3">Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for stat <- @tag_stats do %>
                  <% tag = stat.tag %>
                  <% is_protected = String.starts_with?(tag.name, "op:") and tag.category == "operation" %>
                  <tr class="border-b border-gray-700 hover:bg-gray-700">
                    <td class="px-4 py-3">
                      <.tag_pill tag={tag} />
                    </td>
                    <td class="px-4 py-3">
                      <span class="bg-gray-700 text-gray-300 px-2 py-1 rounded text-xs">{tag.category}</span>
                    </td>
                    <td class="px-4 py-3">
                      <span class="w-4 h-4 rounded-full inline-block" style={"background-color: #{tag.color}"}></span>
                    </td>
                    <td class="px-4 py-3 text-gray-400">{stat.usage_count}</td>
                    <td class="px-4 py-3 text-gray-400 text-xs">{tag.created_by || "-"}</td>
                    <td class="px-4 py-3">
                      <%= if is_protected do %>
                        <span class="text-xs text-yellow-400">Protected</span>
                      <% else %>
                        <div class="flex items-center gap-2">
                          <button phx-click="edit_tag" phx-value-id={tag.id} class="text-blue-400 hover:text-blue-300 text-xs">Edit</button>
                          <button phx-click="delete_tag" phx-value-id={tag.id} class="text-red-400 hover:text-red-300 text-xs"
                            data-confirm="Delete this tag?">Delete</button>
                        </div>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Create/Edit Form --%>
        <div class="bg-gray-800 rounded-lg shadow-lg p-4">
          <h3 class="text-lg font-semibold text-white mb-3">
            {if @editing_tag, do: "Edit Tag", else: "Create Tag"}
          </h3>
          <%= if @form_error do %>
            <div class="bg-red-900 text-red-200 rounded-md p-3 mb-3 text-sm">{@form_error}</div>
          <% end %>
          <form phx-submit={if @editing_tag, do: "update_tag", else: "create_tag"} class="space-y-3">
            <div>
              <label class="text-xs text-gray-400 block mb-1">Name</label>
              <input type="text" name="name" value={@form_name} required
                class="w-full bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md" />
            </div>
            <div>
              <label class="text-xs text-gray-400 block mb-1">Color</label>
              <div class="flex items-center gap-2">
                <input type="text" name="color" value={@form_color}
                  class="flex-1 bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md" />
                <span class="w-8 h-8 rounded" style={"background-color: #{@form_color}"}></span>
              </div>
            </div>
            <div>
              <label class="text-xs text-gray-400 block mb-1">Category</label>
              <select name="category" class="w-full bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md">
                <%= for cat <- @categories do %>
                  <option value={cat} selected={cat == @form_category}>{cat}</option>
                <% end %>
              </select>
            </div>
            <div>
              <label class="text-xs text-gray-400 block mb-1">Description</label>
              <textarea name="description" rows="2"
                class="w-full bg-gray-700 border border-gray-600 text-white px-3 py-2 rounded-md">{@form_description}</textarea>
            </div>
            <div class="flex gap-2">
              <button type="submit" class="flex-1 bg-blue-600 text-white py-2 rounded-md hover:bg-blue-700">
                {if @editing_tag, do: "Update", else: "Create"}
              </button>
              <%= if @editing_tag do %>
                <button type="button" phx-click="cancel_edit" class="px-4 py-2 bg-gray-700 text-gray-300 rounded-md hover:bg-gray-600">
                  Cancel
                </button>
              <% end %>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
