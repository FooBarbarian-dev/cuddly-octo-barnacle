defmodule Clio.ApiKeys.ApiKey do
  @moduledoc "Schema for API keys with permission scopes, expiration, and SHA-256 hashed storage."
  use Ecto.Schema
  import Ecto.Changeset

  @valid_permissions ~w(logs:write logs:read logs:admin)

  schema "api_keys" do
    field :name, :string
    field :key_id, :string
    field :key_hash, :string
    field :created_by, :string
    field :permissions, {:array, :string}, default: ["logs:write"]
    field :description, :string
    field :expires_at, :utc_datetime_usec
    field :is_active, :boolean, default: true
    field :last_used, :utc_datetime_usec
    field :metadata, :map, default: %{}
    belongs_to :operation, Clio.Operations.Operation

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :key_id, :key_hash, :created_by, :permissions, :description,
                    :expires_at, :is_active, :last_used, :metadata, :operation_id])
    |> validate_required([:name, :key_id, :key_hash, :created_by])
    |> validate_length(:name, max: 100)
    |> validate_permissions()
    |> unique_constraint(:key_id)
    |> foreign_key_constraint(:operation_id)
  end

  defp validate_permissions(changeset) do
    case get_field(changeset, :permissions) do
      nil -> changeset
      perms ->
        if Enum.all?(perms, &(&1 in @valid_permissions)) do
          changeset
        else
          add_error(changeset, :permissions, "contains invalid permission scopes")
        end
    end
  end
end
