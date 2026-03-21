defmodule Clio.Repo.Migrations.CreateRelations do
  use Ecto.Migration

  def up do
    execute "CREATE TYPE pattern_type AS ENUM ('command_sequence', 'command_cooccurrence', 'user_pattern', 'host_pattern', 'tag_cooccurrence', 'tag_sequence')"
    execute "CREATE TYPE log_relationship_type AS ENUM ('parent_child', 'linked', 'dependency', 'correlation')"

    create table(:relations) do
      add :source_type, :string, size: 50, null: false
      add :source_value, :text, null: false
      add :target_type, :string, size: 50, null: false
      add :target_value, :text, null: false
      add :strength, :integer, default: 1
      add :connection_count, :integer, default: 1
      add :pattern_type, :pattern_type
      add :first_seen, :utc_datetime_usec, default: fragment("NOW()")
      add :last_seen, :utc_datetime_usec, default: fragment("NOW()")
      add :metadata, :map, default: %{}
      add :operation_tags, {:array, :integer}, default: []
      add :source_log_ids, {:array, :integer}, default: []
    end

    execute """
    CREATE UNIQUE INDEX relations_source_target_unique_idx
    ON relations (source_type, source_value, target_type, target_value)
    WHERE NOT (source_type = 'username' AND target_type = 'command');
    """

    execute "CREATE INDEX relations_operation_tags_idx ON relations USING GIN (operation_tags)"
    execute "CREATE INDEX relations_source_log_ids_idx ON relations USING GIN (source_log_ids)"

    create index(:relations, [:source_type, :source_value])
    create index(:relations, [:target_type, :target_value])
    create index(:relations, [:last_seen])

    execute "CREATE INDEX relations_metadata_idx ON relations USING GIN (metadata)"
  end

  def down do
    drop table(:relations)
    execute "DROP TYPE IF EXISTS log_relationship_type"
    execute "DROP TYPE IF EXISTS pattern_type"
  end
end
