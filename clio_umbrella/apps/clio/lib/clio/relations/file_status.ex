defmodule Clio.Relations.FileStatus do
  @moduledoc "Schema for DFIR file status tracking (ON_DISK, IN_MEMORY, ENCRYPTED, REMOVED, etc.)."
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(ON_DISK IN_MEMORY ENCRYPTED REMOVED CLEANED DORMANT DETECTED UNKNOWN)

  schema "file_status" do
    field :filename, :string
    field :status, :string
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
    field :first_seen, :utc_datetime_usec
    field :last_seen, :utc_datetime_usec
    field :metadata, :map, default: %{}
    field :operation_tags, {:array, :integer}, default: []
    field :source_log_ids, {:array, :integer}, default: []
  end

  def changeset(fs, attrs) do
    fs
    |> cast(attrs, [:filename, :status, :hash_algorithm, :hash_value, :hostname,
                    :internal_ip, :external_ip, :mac_address, :username, :analyst,
                    :notes, :command, :secrets, :first_seen, :last_seen,
                    :metadata, :operation_tags, :source_log_ids])
    |> validate_required([:filename, :status, :analyst])
    |> validate_inclusion(:status, @statuses)
  end

  def statuses, do: @statuses
end
