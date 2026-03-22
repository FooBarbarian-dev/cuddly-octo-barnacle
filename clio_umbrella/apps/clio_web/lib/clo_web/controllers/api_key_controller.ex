defmodule CloWeb.ApiKeyController do
  @moduledoc "Admin-only controller for API key management: creation, listing, and revocation."
  use CloWeb, :controller

  alias Clio.Repo
  alias Clio.ApiKeys.ApiKey
  import Ecto.Query

  def index(conn, _params) do
    api_keys = Repo.all(from a in ApiKey, where: a.is_active == true, order_by: [desc: a.inserted_at])
    json(conn, %{data: Enum.map(api_keys, &serialize/1)})
  end

  def create(conn, %{"api_key" => params}) do
    user = conn.assigns.current_user
    key_raw = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    key_id = :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    key_hash = :crypto.hash(:sha256, key_raw) |> Base.encode16(case: :lower)

    attrs =
      params
      |> Map.put("key_id", key_id)
      |> Map.put("key_hash", key_hash)
      |> Map.put("created_by", user.username)

    changeset = ApiKey.changeset(%ApiKey{}, attrs)

    case Repo.insert(changeset) do
      {:ok, api_key} ->
        conn
        |> put_status(201)
        |> json(%{
          data: serialize(api_key),
          key: "#{key_id}.#{key_raw}"
        })

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{error: format_errors(changeset)})
    end
  end

  def revoke(conn, %{"id" => id}) do
    case Repo.get(ApiKey, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "API key not found"})

      api_key ->
        api_key
        |> Ecto.Changeset.change(%{is_active: false})
        |> Repo.update!()

        json(conn, %{message: "API key revoked"})
    end
  end

  defp serialize(api_key) do
    %{
      id: api_key.id,
      name: api_key.name,
      key_id: api_key.key_id,
      permissions: api_key.permissions,
      description: api_key.description,
      is_active: api_key.is_active,
      created_by: api_key.created_by,
      expires_at: api_key.expires_at,
      last_used: api_key.last_used,
      inserted_at: api_key.inserted_at
    }
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
