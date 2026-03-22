defmodule Clio.Evidence.EvidenceFile do
  @moduledoc "Schema for evidence file attachments with MIME validation, MD5 hashing, and 10MB size limit."
  use Ecto.Schema
  import Ecto.Changeset

  @allowed_mime_types ~w(image/jpeg image/png image/gif application/pdf text/plain application/vnd.tcpdump.pcap application/octet-stream)

  schema "evidence_files" do
    belongs_to :log, Clio.Logs.Log
    field :filename, :string
    field :original_filename, :string
    field :file_type, :string
    field :file_size, :integer
    field :upload_date, :utc_datetime_usec
    field :uploaded_by, :string
    field :description, :string
    field :md5_hash, :string
    field :filepath, :string
    field :metadata, :map, default: %{}
  end

  def changeset(evidence, attrs) do
    evidence
    |> cast(attrs, [:log_id, :filename, :original_filename, :file_type, :file_size,
                    :upload_date, :uploaded_by, :description, :md5_hash, :filepath, :metadata])
    |> validate_required([:log_id, :filename, :original_filename, :filepath])
    |> validate_inclusion(:file_type, @allowed_mime_types, message: "unsupported file type")
    |> validate_number(:file_size, less_than_or_equal_to: 10_485_760, message: "file exceeds 10MB limit")
    |> foreign_key_constraint(:log_id)
    |> maybe_set_upload_date()
  end

  defp maybe_set_upload_date(changeset) do
    case get_field(changeset, :upload_date) do
      nil -> put_change(changeset, :upload_date, DateTime.utc_now())
      _ -> changeset
    end
  end

  def allowed_mime_types, do: @allowed_mime_types
end
