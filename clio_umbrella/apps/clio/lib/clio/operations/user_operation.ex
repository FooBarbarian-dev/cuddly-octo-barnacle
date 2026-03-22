defmodule Clio.Operations.UserOperation do
  @moduledoc "Schema for user-to-operation assignment tracking with primary flag and access timestamps."
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_operations" do
    field :username, :string
    belongs_to :operation, Clio.Operations.Operation
    field :is_primary, :boolean, default: false
    field :assigned_by, :string
    field :assigned_at, :utc_datetime_usec
    field :last_accessed, :utc_datetime_usec
  end

  def changeset(user_op, attrs) do
    user_op
    |> cast(attrs, [:username, :operation_id, :is_primary, :assigned_by, :assigned_at, :last_accessed])
    |> validate_required([:username, :operation_id, :assigned_by])
    |> validate_length(:username, max: 100)
    |> validate_length(:assigned_by, max: 100)
    |> unique_constraint([:username, :operation_id])
    |> foreign_key_constraint(:operation_id)
    |> maybe_set_timestamps()
  end

  defp maybe_set_timestamps(changeset) do
    now = DateTime.utc_now()
    changeset
    |> put_default(:assigned_at, now)
    |> put_default(:last_accessed, now)
  end

  defp put_default(changeset, field, value) do
    case get_field(changeset, field) do
      nil -> put_change(changeset, field, value)
      _ -> changeset
    end
  end
end
