defmodule CloWeb.Plugs.Auth do
  @moduledoc "Plug that verifies JWT tokens and assigns current user."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- extract_token(conn),
         {:ok, user} <- Clio.Auth.verify_token(token) do
      conn
      |> assign(:current_user, user)
      |> maybe_refresh_token(user)
    else
      {:error, _reason} ->
        conn
        |> put_status(401)
        |> Phoenix.Controller.json(%{error: "Unauthorized"})
        |> halt()
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, String.trim(token)}
      _ ->
        case get_req_header(conn, "x-api-key") do
          [api_key] when byte_size(api_key) > 0 -> {:ok, api_key}
          _ -> {:error, :missing_token}
        end
    end
  end

  defp maybe_refresh_token(conn, user) do
    if Clio.Auth.should_refresh?(user.claims) do
      case Clio.Auth.refresh_token(user, user.claims) do
        {:ok, new_token, _claims} ->
          put_resp_header(conn, "x-refreshed-token", new_token)

        _ ->
          conn
      end
    else
      conn
    end
  end
end
