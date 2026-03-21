defmodule Clio.Repo.Migrations.CreateOperations do
  use Ecto.Migration

  def up do
    create table(:operations) do
      add :name, :string, size: 100, null: false
      add :description, :text
      add :tag_id, references(:tags, on_delete: :nilify_all)
      add :is_active, :boolean, default: true
      add :created_by, :string, size: 100, null: false
      add :created_at, :utc_datetime_usec, default: fragment("NOW()")
      add :updated_at, :utc_datetime_usec, default: fragment("NOW()")
    end

    create unique_index(:operations, [:name])
    create index(:operations, [:tag_id])
    create index(:operations, [:is_active])

    execute """
    CREATE TRIGGER update_operations_updated_at
    BEFORE UPDATE ON operations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    execute """
    CREATE OR REPLACE FUNCTION create_operation_tag()
    RETURNS TRIGGER AS $$
    DECLARE
      new_tag_id INTEGER;
    BEGIN
      INSERT INTO tags (name, category, color, created_by, created_at, updated_at)
      VALUES ('OP:' || NEW.name, 'operation', '#3B82F6', NEW.created_by, NOW(), NOW())
      RETURNING id INTO new_tag_id;

      NEW.tag_id := new_tag_id;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER trigger_create_operation_tag
    BEFORE INSERT ON operations
    FOR EACH ROW
    EXECUTE FUNCTION create_operation_tag();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS trigger_create_operation_tag ON operations"
    execute "DROP FUNCTION IF EXISTS create_operation_tag()"
    execute "DROP TRIGGER IF EXISTS update_operations_updated_at ON operations"
    drop table(:operations)
  end
end
