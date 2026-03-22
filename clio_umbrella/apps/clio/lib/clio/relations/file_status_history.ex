defmodule Clio.Relations.FileStatusHistory do
  @moduledoc "Schema for tracking file status changes over time for forensic analysis."
  use Ecto.Schema
  import Ecto.Changeset

  schema "file_status_history" do
    field :filename, :string
    field :status, :string
    field :previous_status, :string
    field :hash_algorithm, :string
    field :hash_value, :string
    field :hostname, :string
    field :internal_ip, :string
    field :external_ip, :string
    field :mac_address, :string
    field :username, :string
    field :analyst, :string
    field :notes, :string
    field :command, :string
    field :secrets, :string
    field :timestamp, :utc_datetime_usec
    field :operation_tags, {:array, :integer}, default: []
  end

  def changeset(fsh, attrs) do
    fsh
    |> cast(attrs, [:filename, :status, :previous_status, :hash_algorithm, :hash_value,
                    :hostname, :internal_ip, :external_ip, :mac_address, :username,
                    :analyst, :notes, :command, :secrets, :timestamp, :operation_tags])
    |> validate_required([:filename, :status])
    |> maybe_set_timestamp()
  end

  defp maybe_set_timestamp(changeset) do
    case get_field(changeset, :timestamp) do
      nil -> put_change(changeset, :timestamp, DateTime.utc_now())
      _ -> changeset
    end
  end
end
