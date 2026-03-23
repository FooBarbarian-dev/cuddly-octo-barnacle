defmodule CloWeb.LoginLive do
  @moduledoc "Login page with authentication and forced password change flow."
  use CloWeb, :live_view
  import CloWeb.ClioComponents

  @impl true
  def mount(_params, session, socket) do
    # If already authenticated, redirect
    case session["auth_token"] do
      nil -> :ok
      token ->
        case Clio.Auth.verify_token(token) do
          {:ok, _} -> {:ok, redirect(socket, to: "/")}
          _ -> :ok
        end
    end

    {:ok,
     assign(socket,
       page_title: "Login",
       view: :login,
       username: "",
       password: "",
       error: nil,
       # Password change state
       current_password: "",
       new_password: "",
       confirm_password: "",
       change_error: nil,
       change_user: nil
     ), layout: false}
  end

  @impl true
  def handle_event("login", %{"username" => username, "password" => password}, socket) do
    case Clio.Auth.authenticate(username, password) do
      {:ok, user} ->
        if user.requires_password_change do
          {:noreply,
           assign(socket,
             view: :password_change,
             change_user: user,
             current_password: password,
             error: nil
           )}
        else
          {:ok, token, _claims} = Clio.Auth.issue_token(user)

          {:noreply,
           socket
           |> put_flash(:info, "Welcome back, #{user.username}")
           |> redirect(to: "/auth/callback?token=#{token}")}
        end

      {:error, :invalid_credentials} ->
        {:noreply, assign(socket, error: "Invalid username or password")}

      {:error, :invalid_username_format} ->
        {:noreply, assign(socket, error: "Invalid username format")}

      {:error, _reason} ->
        {:noreply, assign(socket, error: "Authentication failed")}
    end
  end

  def handle_event("change_password", params, socket) do
    %{"new_password" => new_password, "confirm_password" => confirm} = params
    user = socket.assigns.change_user

    cond do
      new_password != confirm ->
        {:noreply, assign(socket, change_error: "Passwords do not match")}

      true ->
        case Clio.Auth.change_password(
               user.username,
               user.role,
               socket.assigns.current_password,
               new_password
             ) do
          :ok ->
            {:ok, token, _claims} = Clio.Auth.issue_token(user)

            {:noreply,
             socket
             |> put_flash(:info, "Password changed successfully")
             |> redirect(to: "/auth/callback?token=#{token}")}

          {:error, {:invalid_password, errors}} ->
            {:noreply, assign(socket, change_error: Enum.join(errors, ", "))}

          {:error, _} ->
            {:noreply, assign(socket, change_error: "Failed to change password")}
        end
    end
  end

  def handle_event("validate_password", %{"new_password" => pw}, socket) do
    {:noreply, assign(socket, new_password: pw)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 flex items-center justify-center px-4">
      <div class="max-w-md w-full bg-gray-800 rounded-lg shadow-lg p-8">
        <h1 class="text-2xl font-bold text-white text-center mb-8">Clio Logging Platform</h1>

        <%= if @view == :login do %>
          <form phx-submit="login" class="space-y-6">
            <%= if @error do %>
              <div class="bg-red-900 text-red-200 rounded-md p-3 text-sm">{@error}</div>
            <% end %>

            <div>
              <label class="block text-sm font-medium text-gray-300 mb-2">Username</label>
              <input
                type="text"
                name="username"
                value={@username}
                required
                autocomplete="username"
                class="w-full bg-gray-700 border border-gray-600 text-white px-4 py-3 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 placeholder-gray-400"
                placeholder="Enter username"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-300 mb-2">Password</label>
              <input
                type="password"
                name="password"
                value={@password}
                required
                autocomplete="current-password"
                class="w-full bg-gray-700 border border-gray-600 text-white px-4 py-3 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 placeholder-gray-400"
                placeholder="Enter password"
              />
            </div>

            <button
              type="submit"
              class="w-full bg-blue-600 text-white py-3 rounded-md hover:bg-blue-700 transition-colors font-medium"
            >
              Sign In
            </button>
          </form>
        <% else %>
          <%!-- Password Change Form --%>
          <div>
            <h2 class="text-lg font-semibold text-white mb-2">Change Password Required</h2>
            <p class="text-gray-400 text-sm mb-6">You must set a new password before continuing.</p>

            <form phx-submit="change_password" phx-change="validate_password" class="space-y-4">
              <%= if @change_error do %>
                <div class="bg-red-900 text-red-200 rounded-md p-3 text-sm">{@change_error}</div>
              <% end %>

              <div>
                <label class="block text-sm font-medium text-gray-300 mb-2">New Password</label>
                <input
                  type="password"
                  name="new_password"
                  value={@new_password}
                  required
                  autocomplete="new-password"
                  class="w-full bg-gray-700 border border-gray-600 text-white px-4 py-3 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Enter new password"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-300 mb-2">Confirm Password</label>
                <input
                  type="password"
                  name="confirm_password"
                  value={@confirm_password}
                  required
                  autocomplete="new-password"
                  class="w-full bg-gray-700 border border-gray-600 text-white px-4 py-3 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Confirm new password"
                />
              </div>

              <.password_rules password={@new_password} />

              <button
                type="submit"
                class="w-full bg-blue-600 text-white py-3 rounded-md hover:bg-blue-700 transition-colors font-medium"
              >
                Change Password & Continue
              </button>
            </form>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
