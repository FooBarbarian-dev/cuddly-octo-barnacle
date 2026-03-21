defmodule Clio.Repo.Migrations.CreateLogRelationships do
  use Ecto.Migration

  def up do
    create table(:log_relationships) do
      add :source_id, references(:logs, on_delete: :delete_all)
      add :target_id, references(:logs, on_delete: :delete_all)
      add :type, :log_relationship_type, null: false
      add :relationship, :string, size: 100
      add :created_at, :utc_datetime_usec, default: fragment("NOW()")
      add :created_by, :string, size: 100
      add :notes, :text
    end
  end

  def down do
    drop table(:log_relationships)
  end
end
