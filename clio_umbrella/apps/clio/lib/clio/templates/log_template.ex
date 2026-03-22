defmodule Clio.Templates.LogTemplate do
  @moduledoc "Schema for reusable log entry templates with JSON template data."
  use Ecto.Schema
  import Ecto.Changeset

  schema "log_templates" do
    field :name, :string
    field :template_data, :map, default: %{}
    field :created_by, :string

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :template_data, :created_by])
    |> validate_required([:name, :template_data, :created_by])
    |> validate_length(:name, max: 100)
  end
end
