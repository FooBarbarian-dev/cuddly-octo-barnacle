defmodule CloWeb.AuthController do
  @moduledoc "Authentication controller: login, token verification, logout, and password changes."
  use CloWeb, :controller

  alias Clio.Auth
  alias Clio.Audit

  def login(conn, %{"username" => username, "password" => password}) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    case Auth.authenticate(username, password) do
      {:ok, user} ->
        {:ok, token, claims} = Auth.issue_token(user)
        Audit.log_security("login_success", username, %{"ip" => ip})

        json(conn, %{
          token: token,
          user: %{
            username: user.username,
            role: user.role,
            requires_password_change: user.requires_password_change
          },
          expires_at: claims["exp"]
        })

      {:error, reason} ->
        Audit.log_security("login_failure", username, %{"ip" => ip, "reason" => to_string(reason)})

        conn
        |> put_status(401)
        |> json(%{error: "Authentication failed"})
    end
  end

  def verify(conn, _params) do
    user = conn.assigns.current_user
    json(conn, %{valid: true, user: %{username: user.username, role: user.role}})
  end

  def logout(conn, _params) do
    user = conn.assigns.current_user
    Auth.revoke_token(user.jti, user.username)
    Audit.log_security("logout", user.username)
    json(conn, %{message: "Logged out"})
  end

  def change_password(conn, %{"current_password" => current, "new_password" => new_password}) do
    user = conn.assigns.current_user

    case Auth.change_password(user.username, user.role, current, new_password) do
      :ok ->
        Auth.revoke_all_user_tokens(user.username)
        Audit.log_security("password_change", user.username)
        json(conn, %{message: "Password changed. Please log in again."})

      {:error, {:invalid_password, errors}} ->
        conn |> put_status(422) |> json(%{error: "Invalid password", details: errors})

      {:error, _reason} ->
        conn |> put_status(401) |> json(%{error: "Current password is incorrect"})
    end
  end
end
