defmodule Clio.Tags.Tag do
  @moduledoc "Schema for categorized tags with operation tag protection (op: prefix)."
  use Ecto.Schema
  import Ecto.Changeset

  @categories ~w(technique tool target status priority workflow evidence security operation custom)

  schema "tags" do
    field :name, :string
    field :color, :string, default: "#6B7280"
    field :category, :string
    field :description, :string
    field :is_default, :boolean, default: false
    field :created_by, :string

    has_many :log_tags, Clio.Tags.LogTag
    has_one :operation, Clio.Operations.Operation, foreign_key: :tag_id

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :color, :category, :description, :is_default, :created_by])
    |> validate_required([:name])
    |> validate_length(:name, max: 50)
    |> validate_length(:color, max: 7)
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/, message: "must be a valid hex color")
    |> validate_inclusion(:category, @categories)
    |> normalize_name()
    |> unique_constraint(:name)
  end

  defp normalize_name(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :name, name |> String.trim() |> String.downcase())
    end
  end

  def operation_tag?(%__MODULE__{name: "op:" <> _, category: "operation"}), do: true
  def operation_tag?(_), do: false
end
