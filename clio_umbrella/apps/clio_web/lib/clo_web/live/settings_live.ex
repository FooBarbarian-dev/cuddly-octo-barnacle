defmodule CloWeb.SettingsLive do
  @moduledoc "User settings: password change and operation management."
  use CloWeb, :live_view
  import CloWeb.ClioComponents

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    operations = Clio.Operations.get_user_operations(user.username)
    active_op = case Clio.Operations.get_active_operation(user.username) do
      {:ok, op} -> op
      _ -> nil
    end

    {:ok,
     assign(socket,
       page_title: "Settings",
       active_view: :settings,
       my_operations: operations,
       my_active_operation: active_op,
       current_password: "",
       new_password: "",
       confirm_password: "",
       password_error: nil,
       password_success: nil
     )}
  end

  @impl true
  def handle_event("change_password", params, socket) do
    %{"current_password" => current, "new_password" => new_pw, "confirm_password" => confirm} = params
    user = socket.assigns.current_user

    cond do
      new_pw != confirm ->
        {:noreply, assign(socket, password_error: "Passwords do not match", password_success: nil)}

      true ->
        case Clio.Auth.change_password(user.username, user.role, current, new_pw) do
          :ok ->
            {:noreply, assign(socket, password_error: nil, password_success: "Password changed successfully",
                              current_password: "", new_password: "", confirm_password: "")}
          {:error, {:invalid_password, errors}} ->
            {:noreply, assign(socket, password_error: Enum.join(errors, ", "), password_success: nil)}
          {:error, _} ->
            {:noreply, assign(socket, password_error: "Failed to change password", password_success: nil)}
        end
    end
  end

  def handle_event("validate_password", %{"new_password" => pw}, socket) do
    {:noreply, assign(socket, new_password: pw)}
  end

  def handle_event("set_active_operation", %{"id" => op_id}, socket) do
    user = socket.assigns.current_user
    Clio.Operations.set_primary_operation(user.username, String.to_integer(op_id))
    operations = Clio.Operations.get_user_operations(user.username)
    active_op = case Clio.Operations.get_active_operation(user.username) do
      {:ok, op} -> op
      _ -> nil
    end

    {:noreply, assign(socket, my_operations: operations, my_active_operation: active_op,
                       user_operations: operations, active_operation: active_op)}
  end

  def handle_event("logout", _params, socket) do
    user = socket.assigns.current_user
    if user[:jti], do: Clio.Auth.revoke_token(user.jti, user.username)
    {:noreply, redirect(socket, to: "/login")}
  end

  @impl true
  def handle_info({:switch_operation, op_id}, socket) do
    handle_event("set_active_operation", %{"id" => to_string(op_id)}, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.nav_bar current_user={@current_user} active_view={@active_view} />

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- Change Password --%>
        <div class="bg-gray-800 rounded-lg shadow-lg p-6">
          <h2 class="text-xl font-bold text-white mb-4">Change Password</h2>

          <%= if @password_success do %>
            <div class="bg-green-900 text-green-200 rounded-md p-3 mb-4 text-sm">{@password_success}</div>
          <% end %>
          <%= if @password_error do %>
            <div class="bg-red-900 text-red-200 rounded-md p-3 mb-4 text-sm">{@password_error}</div>
          <% end %>

          <form phx-submit="change_password" phx-change="validate_password" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-300 mb-1">Current Password</label>
              <input type="password" name="current_password" value={@current_password}
                class="w-full bg-gray-700 border border-gray-600 text-white px-4 py-2 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-300 mb-1">New Password</label>
              <input type="password" name="new_password" value={@new_password}
                class="w-full bg-gray-700 border border-gray-600 text-white px-4 py-2 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-300 mb-1">Confirm Password</label>
              <input type="password" name="confirm_password" value={@confirm_password}
                class="w-full bg-gray-700 border border-gray-600 text-white px-4 py-2 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" />
            </div>

            <.password_rules password={@new_password} />

            <button type="submit" class="w-full bg-blue-600 text-white py-2 rounded-md hover:bg-blue-700">
              Change Password
            </button>
          </form>
        </div>

        <%!-- My Operations --%>
        <div class="bg-gray-800 rounded-lg shadow-lg p-6">
          <h2 class="text-xl font-bold text-white mb-4">My Operations</h2>

          <%= if Enum.empty?(@my_operations) do %>
            <p class="text-gray-500">No operations assigned.</p>
          <% else %>
            <div class="space-y-3">
              <%= for uo <- @my_operations do %>
                <div class={"rounded-lg p-4 flex items-center justify-between #{if is_active_op?(@my_active_operation, uo), do: "bg-blue-600", else: "bg-gray-700"}"}>
                  <div>
                    <div class="flex items-center gap-2">
                      <span class="text-white font-medium">{uo.operation.name}</span>
                      <%= if uo.operation.tag do %>
                        <span
                          class="w-3 h-3 rounded-full inline-block"
                          style={"background-color: #{uo.operation.tag.color || "#6B7280"}"}
                        ></span>
                      <% end %>
                    </div>
                    <p class="text-gray-300 text-sm mt-1">{uo.operation.description || ""}</p>
                  </div>
                  <button
                    phx-click="set_active_operation"
                    phx-value-id={uo.operation.id}
                    class={"px-3 py-1 rounded text-sm #{if is_active_op?(@my_active_operation, uo), do: "bg-blue-500 text-white", else: "bg-gray-600 text-gray-300 hover:bg-gray-500"}"}
                  >
                    {if is_active_op?(@my_active_operation, uo), do: "Active", else: "Set Active"}
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp is_active_op?(nil, _uo), do: false
  defp is_active_op?(%{operation: %{id: active_id}}, uo), do: uo.operation.id == active_id
  defp is_active_op?(_, _), do: false
end
