defmodule Clio.Repo.Migrations.CreateUserOperations do
  use Ecto.Migration

  def up do
    create table(:user_operations) do
      add :username, :string, size: 100, null: false
      add :operation_id, references(:operations, on_delete: :delete_all), null: false
      add :is_primary, :boolean, default: false
      add :assigned_by, :string, size: 100, null: false
      add :assigned_at, :utc_datetime_usec, default: fragment("NOW()")
      add :last_accessed, :utc_datetime_usec, default: fragment("NOW()")
    end

    create unique_index(:user_operations, [:username, :operation_id])
    create index(:user_operations, [:username])
    create index(:user_operations, [:operation_id])

    execute """
    CREATE OR REPLACE VIEW user_operations_view AS
    SELECT
      uo.id,
      uo.username,
      uo.operation_id,
      uo.is_primary,
      uo.assigned_by,
      uo.assigned_at,
      uo.last_accessed,
      o.name AS operation_name,
      o.description AS operation_description,
      o.is_active,
      o.tag_id,
      t.name AS tag_name,
      t.color AS tag_color
    FROM user_operations uo
    JOIN operations o ON uo.operation_id = o.id
    LEFT JOIN tags t ON o.tag_id = t.id
    WHERE o.is_active = true;
    """

    execute """
    CREATE OR REPLACE FUNCTION get_user_active_operation(p_username VARCHAR)
    RETURNS TABLE(
      operation_id INTEGER,
      operation_name VARCHAR,
      tag_id INTEGER,
      tag_name VARCHAR,
      is_primary BOOLEAN
    ) AS $$
    BEGIN
      RETURN QUERY
      SELECT
        o.id AS operation_id,
        o.name AS operation_name,
        o.tag_id AS tag_id,
        t.name AS tag_name,
        uo.is_primary AS is_primary
      FROM user_operations uo
      JOIN operations o ON uo.operation_id = o.id
      LEFT JOIN tags t ON o.tag_id = t.id
      WHERE uo.username = p_username
        AND o.is_active = true
      ORDER BY uo.is_primary DESC, uo.last_accessed DESC
      LIMIT 1;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    execute "DROP FUNCTION IF EXISTS get_user_active_operation(VARCHAR)"
    execute "DROP VIEW IF EXISTS user_operations_view"
    drop table(:user_operations)
  end
end
