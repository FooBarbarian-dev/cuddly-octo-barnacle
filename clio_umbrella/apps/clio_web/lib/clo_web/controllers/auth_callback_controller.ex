defmodule CloWeb.AuthCallbackController do
  @moduledoc "Handles auth callback to store JWT token in session after login."
  use CloWeb, :controller

  def callback(conn, %{"token" => token}) do
    case Clio.Auth.verify_token(token) do
      {:ok, _user} ->
        conn
        |> put_session("auth_token", token)
        |> redirect(to: "/")

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid authentication token")
        |> redirect(to: "/login")
    end
  end

  def callback(conn, _params) do
    conn
    |> redirect(to: "/login")
  end
end
