defmodule Clio.Relations.LogRelationship do
  @moduledoc "Schema for relationships between log entries (parent_child, linked, dependency, correlation)."
  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(parent_child linked dependency correlation)

  schema "log_relationships" do
    belongs_to :source, Clio.Logs.Log, foreign_key: :source_id
    belongs_to :target, Clio.Logs.Log, foreign_key: :target_id
    field :type, :string
    field :relationship, :string
    field :created_by, :string
    field :notes, :string
    field :created_at, :utc_datetime_usec
  end

  def changeset(lr, attrs) do
    lr
    |> cast(attrs, [:source_id, :target_id, :type, :relationship, :created_by, :notes, :created_at])
    |> validate_required([:source_id, :target_id, :type])
    |> validate_inclusion(:type, @types)
    |> foreign_key_constraint(:source_id)
    |> foreign_key_constraint(:target_id)
  end
end
