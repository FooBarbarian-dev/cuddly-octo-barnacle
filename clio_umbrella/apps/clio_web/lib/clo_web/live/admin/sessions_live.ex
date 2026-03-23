defmodule CloWeb.Admin.SessionsLive do
  @moduledoc "Admin sessions view: list active sessions, revoke tokens."
  use CloWeb, :live_view
  import CloWeb.ClioComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Sessions",
       active_view: :admin_sessions,
       sessions: load_sessions()
     )}
  end

  defp load_sessions do
    # Get all active JWT tokens from cache
    case Clio.Cache.keys("jwt:*") do
      {:ok, keys} ->
        Enum.map(keys, fn key ->
          jti = String.replace_prefix(key, "jwt:", "")
          case Clio.Cache.get(key) do
            {:ok, value} when is_binary(value) ->
              parts = String.split(value, "::")
              username = Enum.at(parts, 1, "unknown")
              role = Enum.at(parts, 3, "user")
              issued_at = Enum.at(parts, 5, "0") |> String.to_integer()
              %{jti: jti, username: username, role: role, issued_at: issued_at}
            _ ->
              %{jti: jti, username: "unknown", role: "user", issued_at: 0}
          end
        end)
        |> Enum.sort_by(& &1.issued_at, :desc)
      _ -> []
    end
  end

  @impl true
  def handle_event("revoke_session", %{"jti" => jti, "username" => username}, socket) do
    Clio.Auth.revoke_token(jti, username)
    {:noreply, assign(socket, sessions: load_sessions())}
  end

  def handle_event("force_global_logout", _params, socket) do
    for session <- socket.assigns.sessions do
      Clio.Auth.revoke_token(session.jti, session.username)
    end
    {:noreply, assign(socket, sessions: load_sessions())}
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

      <div class="bg-gray-800 rounded-lg shadow-lg p-4">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-bold text-white">Active Sessions</h2>
          <button phx-click="force_global_logout" class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 text-sm"
            data-confirm="Force logout ALL users? This will invalidate all sessions.">
            Force Global Logout
          </button>
        </div>

        <table class="w-full text-sm text-left">
          <thead class="text-xs text-gray-400 uppercase bg-gray-700">
            <tr>
              <th class="px-4 py-3">Session ID</th>
              <th class="px-4 py-3">Username</th>
              <th class="px-4 py-3">Role</th>
              <th class="px-4 py-3">Issued</th>
              <th class="px-4 py-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for session <- @sessions do %>
              <tr class="border-b border-gray-700 hover:bg-gray-700">
                <td class="px-4 py-3 text-gray-300 font-mono text-xs">
                  {String.slice(session.jti, 0, 8)}...
                  <%= if session.jti == @current_user[:jti] do %>
                    <span class="ml-2 bg-blue-600/30 text-blue-300 px-1.5 py-0.5 rounded text-xs">Current</span>
                  <% end %>
                </td>
                <td class="px-4 py-3 text-white">{session.username}</td>
                <td class="px-4 py-3">
                  <span class={"px-2 py-1 rounded text-xs #{if session.role == "admin", do: "bg-red-900 text-red-200", else: "bg-gray-700 text-gray-300"}"}>
                    {session.role}
                  </span>
                </td>
                <td class="px-4 py-3 text-gray-400 text-xs">{format_unix(session.issued_at)}</td>
                <td class="px-4 py-3">
                  <button phx-click="revoke_session" phx-value-jti={session.jti} phx-value-username={session.username}
                    class="text-red-400 hover:text-red-300 text-xs">
                    Revoke
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if Enum.empty?(@sessions) do %>
          <p class="text-gray-500 text-center py-8">No active sessions.</p>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_unix(0), do: "-"
  defp format_unix(ts) when is_integer(ts) do
    case DateTime.from_unix(ts) do
      {:ok, dt} -> Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
      _ -> "-"
    end
  end
  defp format_unix(_), do: "-"
end
