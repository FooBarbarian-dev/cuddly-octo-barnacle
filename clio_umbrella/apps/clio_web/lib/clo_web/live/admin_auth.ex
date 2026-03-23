defmodule CloWeb.Live.AdminAuth do
  @moduledoc "LiveView on_mount hook that verifies admin session for the Backpex admin panel."
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    case session["admin_user"] do
      %{"role" => "admin"} = user ->
        {:cont, assign(socket, :current_user, %{
          id: user["id"],
          username: user["username"],
          role: :admin
        })}

      _ ->
        {:halt, redirect(socket, to: "/admin/session/login")}
    end
  end
end
