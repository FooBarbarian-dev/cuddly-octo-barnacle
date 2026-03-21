defmodule Clio.Repo.Migrations.CreateLogs do
  use Ecto.Migration

  def up do
    create table(:logs) do
      add :timestamp, :utc_datetime_usec, null: false
      add :internal_ip, :string, size: 45
      add :external_ip, :string, size: 45
      add :mac_address, :string, size: 17
      add :hostname, :string, size: 75
      add :domain, :string, size: 75
      add :username, :string, size: 75
      add :command, :text
      add :notes, :text
      add :filename, :string, size: 254
      add :status, :string, size: 75
      add :secrets, :text
      add :hash_algorithm, :string, size: 50
      add :hash_value, :string, size: 128
      add :pid, :string, size: 20
      add :analyst, :string, size: 100
      add :locked, :boolean, default: false
      add :locked_by, :string, size: 100
      add :created_at, :utc_datetime_usec, default: fragment("NOW()")
      add :updated_at, :utc_datetime_usec, default: fragment("NOW()")
    end

    execute "ALTER TABLE logs ADD CONSTRAINT logs_command_length CHECK (length(command) <= 254)"
    execute "ALTER TABLE logs ADD CONSTRAINT logs_notes_length CHECK (length(notes) <= 254)"
    execute "ALTER TABLE logs ADD CONSTRAINT logs_secrets_length CHECK (length(secrets) <= 254)"

    create index(:logs, [fragment("timestamp DESC")])
    create index(:logs, [:analyst])
    create index(:logs, [:hostname])
    create index(:logs, [:hash_value])
    create index(:logs, [:mac_address])
    create index(:logs, [:pid])

    execute """
    CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS $$
    BEGIN
      NEW.updated_at = NOW();
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER update_logs_updated_at
    BEFORE UPDATE ON logs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS update_logs_updated_at ON logs"
    execute "DROP FUNCTION IF EXISTS update_updated_at_column()"
    drop table(:logs)
  end
end
