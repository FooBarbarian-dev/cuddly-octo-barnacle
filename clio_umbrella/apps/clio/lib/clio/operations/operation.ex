defmodule Clio.Operations.Operation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "operations" do
    field :name, :string
    field :description, :string
    belongs_to :tag, Clio.Tags.Tag
    field :is_active, :boolean, default: true
    field :created_by, :string

    has_many :user_operations, Clio.Operations.UserOperation

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(operation, attrs) do
    operation
    |> cast(attrs, [:name, :description, :is_active, :created_by])
    |> validate_required([:name, :created_by])
    |> validate_length(:name, max: 100)
    |> unique_constraint(:name)
  end
end
