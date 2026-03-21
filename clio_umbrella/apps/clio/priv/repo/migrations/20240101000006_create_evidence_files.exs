defmodule Clio.Repo.Migrations.CreateEvidenceFiles do
  use Ecto.Migration

  def up do
    create table(:evidence_files) do
      add :log_id, references(:logs, on_delete: :delete_all), null: false
      add :filename, :string, size: 255, null: false
      add :original_filename, :string, size: 255, null: false
      add :file_type, :string, size: 100
      add :file_size, :integer
      add :upload_date, :utc_datetime_usec, default: fragment("NOW()")
      add :uploaded_by, :string, size: 100
      add :description, :text
      add :md5_hash, :string, size: 32
      add :filepath, :string, size: 255, null: false
      add :metadata, :map, default: %{}
    end

    create index(:evidence_files, [:log_id])
    create index(:evidence_files, [:uploaded_by])
  end

  def down do
    drop table(:evidence_files)
  end
end
