defmodule CloWeb.AdminSessionController do
  @moduledoc "Handles browser-based admin login/logout for the Backpex admin panel."
  use CloWeb, :controller

  def login(conn, _params) do
    render(conn, :login, error: nil, layout: {CloWeb.Layouts, :root})
  end

  def create(conn, %{"username" => username, "password" => password}) do
    case Clio.Auth.authenticate(username, password) do
      {:ok, %{role: :admin} = user} ->
        conn
        |> put_session(:admin_user, %{
          "id" => user.id,
          "username" => user.username,
          "role" => "admin"
        })
        |> redirect(to: ~p"/admin/logs")

      {:ok, _non_admin} ->
        render(conn, :login,
          error: "Admin access required.",
          layout: {CloWeb.Layouts, :root}
        )

      {:error, _reason} ->
        render(conn, :login,
          error: "Invalid credentials.",
          layout: {CloWeb.Layouts, :root}
        )
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_session(:admin_user)
    |> redirect(to: ~p"/admin/session/login")
  end
end
