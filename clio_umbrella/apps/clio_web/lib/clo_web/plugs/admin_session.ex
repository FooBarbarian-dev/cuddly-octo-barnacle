defmodule CloWeb.Plugs.AdminSession do
  @moduledoc """
  Plug that loads admin user from session for browser-based admin panel access.
  Works alongside the existing JWT-based API auth by reading from the session
  instead of Authorization headers.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :admin_user) do
      %{"role" => "admin"} = user ->
        assign(conn, :current_user, struct_from_session(user))

      _ ->
        conn
        |> redirect(to: "/admin/session/login")
        |> halt()
    end
  end

  defp struct_from_session(user) do
    %{
      id: user["id"],
      username: user["username"],
      role: :admin
    }
  end
end
