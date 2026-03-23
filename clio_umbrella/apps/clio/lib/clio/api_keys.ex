defmodule Clio.ApiKeys do
  @moduledoc "API Keys context: create, list, revoke, delete API keys."

  import Ecto.Query
  alias Clio.Repo
  alias Clio.ApiKeys.ApiKey

  def list do
    Repo.all(from k in ApiKey, order_by: [desc: k.inserted_at])
  end

  def get(id) do
    case Repo.get(ApiKey, id) do
      nil -> {:error, :not_found}
      key -> {:ok, key}
    end
  end

  def create(attrs) do
    key_id = random_hex(8)
    secret = random_hex(32)
    full_key = "rtl_#{key_id}_#{secret}"
    key_hash = :crypto.hash(:sha256, full_key) |> Base.encode16(case: :lower)

    attrs =
      attrs
      |> Map.put(:key_id, key_id)
      |> Map.put(:key_hash, key_hash)

    case %ApiKey{} |> ApiKey.changeset(attrs) |> Repo.insert() do
      {:ok, api_key} -> {:ok, api_key, full_key}
      error -> error
    end
  end

  def revoke(id) do
    with {:ok, key} <- get(id) do
      key
      |> Ecto.Changeset.change(%{is_active: false})
      |> Repo.update()
    end
  end

  def delete(id) do
    with {:ok, key} <- get(id) do
      Repo.delete(key)
    end
  end

  def verify(api_key_string) do
    key_hash = :crypto.hash(:sha256, api_key_string) |> Base.encode16(case: :lower)

    case Repo.get_by(ApiKey, key_hash: key_hash, is_active: true) do
      nil -> {:error, :invalid_key}
      key ->
        key |> Ecto.Changeset.change(%{last_used: DateTime.utc_now()}) |> Repo.update()
        {:ok, key}
    end
  end

  defp random_hex(bytes) do
    :crypto.strong_rand_bytes(bytes) |> Base.encode16(case: :lower)
  end
end
