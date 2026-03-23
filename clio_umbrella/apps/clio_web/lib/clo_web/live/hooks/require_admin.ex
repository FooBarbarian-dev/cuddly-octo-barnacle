defmodule CloWeb.Hooks.RequireAdmin do
  @moduledoc "LiveView on_mount hook that verifies the user has admin role."
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    if socket.assigns.current_user.role == :admin do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/")}
    end
  end
end
