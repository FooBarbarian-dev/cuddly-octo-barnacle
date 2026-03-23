defmodule CloWeb.Hooks.RequireAuth do
  @moduledoc "LiveView on_mount hook that verifies JWT auth token from session."
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    case session["auth_token"] do
      nil ->
        {:halt, redirect(socket, to: "/login")}

      token ->
        case Clio.Auth.verify_token(token) do
          {:ok, user} ->
            operations = Clio.Operations.get_user_operations(user.username)
            active_op = case Clio.Operations.get_active_operation(user.username) do
              {:ok, op} -> op
              _ -> nil
            end

            {:cont,
             socket
             |> assign(:current_user, user)
             |> assign(:auth_token, token)
             |> assign(:user_operations, operations)
             |> assign(:active_operation, active_op)}

          {:error, _} ->
            {:halt, redirect(socket, to: "/login")}
        end
    end
  end
end
