defmodule Clio.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def up do
    create table(:api_keys) do
      add :name, :string, size: 100, null: false
      add :key_id, :string, size: 50, null: false
      add :key_hash, :string, size: 255, null: false
      add :created_by, :string, size: 100, null: false
      add :permissions, :map, default: fragment("'[\"logs:write\"]'::jsonb")
      add :description, :text
      add :created_at, :utc_datetime_usec, default: fragment("NOW()")
      add :updated_at, :utc_datetime_usec, default: fragment("NOW()")
      add :expires_at, :utc_datetime_usec
      add :is_active, :boolean, default: true
      add :last_used, :utc_datetime_usec
      add :metadata, :map, default: %{}
      add :operation_id, references(:operations, on_delete: :nilify_all)
    end

    create unique_index(:api_keys, [:key_id])
    create index(:api_keys, [:created_by])
    create index(:api_keys, [:is_active])
    create index(:api_keys, [:operation_id])

    execute """
    CREATE TRIGGER update_api_keys_updated_at
    BEFORE UPDATE ON api_keys
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS update_api_keys_updated_at ON api_keys"
    drop table(:api_keys)
  end
end
