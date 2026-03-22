defmodule Clio.Relations.TagRelationship do
  @moduledoc "Schema for tag co-occurrence and sequence relationships with correlation strength."
  use Ecto.Schema
  import Ecto.Changeset

  schema "tag_relationships" do
    belongs_to :source_tag, Clio.Tags.Tag
    belongs_to :target_tag, Clio.Tags.Tag
    field :cooccurrence_count, :integer, default: 1
    field :sequence_count, :integer, default: 0
    field :correlation_strength, :float, default: 0.0
    field :first_seen, :utc_datetime_usec
    field :last_seen, :utc_datetime_usec
    field :metadata, :map, default: %{}
  end

  def changeset(tr, attrs) do
    tr
    |> cast(attrs, [:source_tag_id, :target_tag_id, :cooccurrence_count, :sequence_count,
                    :correlation_strength, :first_seen, :last_seen, :metadata])
    |> validate_required([:source_tag_id, :target_tag_id])
    |> foreign_key_constraint(:source_tag_id)
    |> foreign_key_constraint(:target_tag_id)
  end
end
