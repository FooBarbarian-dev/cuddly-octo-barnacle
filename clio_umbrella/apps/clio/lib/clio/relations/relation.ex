defmodule Clio.Relations.Relation do
  @moduledoc "Schema for discovered patterns (command sequences, co-occurrences, user/host patterns)."
  use Ecto.Schema
  import Ecto.Changeset

  @pattern_types ~w(command_sequence command_cooccurrence user_pattern host_pattern tag_cooccurrence tag_sequence)

  schema "relations" do
    field :source_type, :string
    field :source_value, :string
    field :target_type, :string
    field :target_value, :string
    field :strength, :integer, default: 1
    field :connection_count, :integer, default: 1
    field :pattern_type, :string
    field :first_seen, :utc_datetime_usec
    field :last_seen, :utc_datetime_usec
    field :metadata, :map, default: %{}
    field :operation_tags, {:array, :integer}, default: []
    field :source_log_ids, {:array, :integer}, default: []
  end

  def changeset(relation, attrs) do
    relation
    |> cast(attrs, [:source_type, :source_value, :target_type, :target_value,
                    :strength, :connection_count, :pattern_type, :first_seen,
                    :last_seen, :metadata, :operation_tags, :source_log_ids])
    |> validate_required([:source_type, :source_value, :target_type, :target_value])
    |> validate_inclusion(:pattern_type, @pattern_types)
    |> maybe_set_timestamps()
  end

  defp maybe_set_timestamps(changeset) do
    now = DateTime.utc_now()
    changeset
    |> put_default(:first_seen, now)
    |> put_default(:last_seen, now)
  end

  defp put_default(changeset, field, value) do
    case get_field(changeset, field) do
      nil -> put_change(changeset, field, value)
      _ -> changeset
    end
  end
end
