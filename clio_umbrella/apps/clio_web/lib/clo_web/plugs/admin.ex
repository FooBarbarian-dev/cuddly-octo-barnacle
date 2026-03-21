defmodule CloWeb.Plugs.Admin do
  @moduledoc "Plug that ensures the current user has admin role."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %{role: :admin} ->
        conn

      _ ->
        conn
        |> put_status(403)
        |> Phoenix.Controller.json(%{error: "Forbidden", message: "Admin access required"})
        |> halt()
    end
  end
end
