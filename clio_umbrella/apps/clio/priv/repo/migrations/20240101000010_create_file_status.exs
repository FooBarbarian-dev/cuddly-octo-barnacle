defmodule Clio.Repo.Migrations.CreateFileStatus do
  use Ecto.Migration

  def up do
    create table(:file_status) do
      add :filename, :string, size: 254, null: false
      add :status, :string, size: 50, null: false
      add :hash_algorithm, :string, size: 50
      add :hash_value, :string, size: 128
      add :hostname, :string, size: 75
      add :internal_ip, :string, size: 45
      add :external_ip, :string, size: 45
      add :mac_address, :string, size: 17
      add :username, :string, size: 75
      add :analyst, :string, size: 100, null: false
      add :notes, :text
      add :command, :text
      add :secrets, :text
      add :first_seen, :utc_datetime_usec, default: fragment("NOW()")
      add :last_seen, :utc_datetime_usec, default: fragment("NOW()")
      add :metadata, :map, default: %{}
      add :operation_tags, {:array, :integer}, default: []
      add :source_log_ids, {:array, :integer}, default: []
    end

    execute """
    CREATE UNIQUE INDEX file_status_filename_hostname_ip_idx
    ON file_status (filename, COALESCE(hostname, ''), COALESCE(internal_ip, ''));
    """

    execute "CREATE INDEX file_status_operation_tags_idx ON file_status USING GIN (operation_tags)"
    execute "CREATE INDEX file_status_source_log_ids_idx ON file_status USING GIN (source_log_ids)"
  end

  def down do
    drop table(:file_status)
  end
end
