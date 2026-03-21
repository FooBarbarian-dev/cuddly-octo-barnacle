defmodule Clio.Tags.LogTag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "log_tags" do
    belongs_to :log, Clio.Logs.Log
    belongs_to :tag, Clio.Tags.Tag
    field :tagged_by, :string
    field :tagged_at, :utc_datetime_usec, default: nil
  end

  def changeset(log_tag, attrs) do
    log_tag
    |> cast(attrs, [:log_id, :tag_id, :tagged_by, :tagged_at])
    |> validate_required([:log_id, :tag_id])
    |> unique_constraint([:log_id, :tag_id])
    |> foreign_key_constraint(:log_id)
    |> foreign_key_constraint(:tag_id)
    |> maybe_set_tagged_at()
  end

  defp maybe_set_tagged_at(changeset) do
    case get_field(changeset, :tagged_at) do
      nil -> put_change(changeset, :tagged_at, DateTime.utc_now())
      _ -> changeset
    end
  end
end
