defmodule Clio.Logs.Log do
  @moduledoc "Schema for red team log entries with forensic fields, row-level locking, and encrypted secrets."
  use Ecto.Schema
  import Ecto.Changeset

  schema "logs" do
    field :timestamp, :utc_datetime_usec
    field :internal_ip, :string
    field :external_ip, :string
    field :mac_address, :string
    field :hostname, :string
    field :domain, :string
    field :username, :string
    field :command, :string
    field :notes, :string
    field :filename, :string
    field :status, :string
    field :secrets, Clio.Encrypted.Binary
    field :hash_algorithm, :string
    field :hash_value, :string
    field :pid, :string
    field :analyst, :string
    field :locked, :boolean, default: false
    field :locked_by, :string

    has_many :log_tags, Clio.Tags.LogTag
    has_many :tags, through: [:log_tags, :tag]
    has_many :evidence_files, Clio.Evidence.EvidenceFile

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields []
  @optional_fields [
    :timestamp, :internal_ip, :external_ip, :mac_address, :hostname,
    :domain, :username, :command, :notes, :filename, :status,
    :secrets, :hash_algorithm, :hash_value, :pid, :analyst,
    :locked, :locked_by
  ]

  def changeset(log, attrs) do
    log
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_length(:command, max: 254)
    |> validate_length(:notes, max: 254)
    |> validate_length(:secrets, max: 254)
    |> validate_length(:internal_ip, max: 45)
    |> validate_length(:external_ip, max: 45)
    |> validate_length(:mac_address, max: 17)
    |> validate_length(:hostname, max: 75)
    |> validate_length(:domain, max: 75)
    |> validate_length(:username, max: 75)
    |> validate_length(:filename, max: 254)
    |> validate_length(:status, max: 75)
    |> validate_length(:hash_algorithm, max: 50)
    |> validate_length(:hash_value, max: 128)
    |> validate_length(:pid, max: 20)
    |> validate_length(:analyst, max: 100)
    |> validate_length(:locked_by, max: 100)
    |> maybe_set_timestamp()
    |> normalize_mac_address()
  end

  defp maybe_set_timestamp(changeset) do
    case get_field(changeset, :timestamp) do
      nil -> put_change(changeset, :timestamp, DateTime.utc_now())
      _ -> changeset
    end
  end

  defp normalize_mac_address(changeset) do
    case get_change(changeset, :mac_address) do
      nil -> changeset
      mac ->
        normalized = mac
        |> String.upcase()
        |> String.replace(~r/[:\.]/, "-")
        put_change(changeset, :mac_address, normalized)
    end
  end
end
