defmodule Clio.Repo.Migrations.CreateTagRelationships do
  use Ecto.Migration

  def up do
    create table(:tag_relationships) do
      add :source_tag_id, references(:tags, on_delete: :delete_all)
      add :target_tag_id, references(:tags, on_delete: :delete_all)
      add :cooccurrence_count, :integer, default: 1
      add :sequence_count, :integer, default: 0
      add :correlation_strength, :float, default: 0.0
      add :first_seen, :utc_datetime_usec, default: fragment("NOW()")
      add :last_seen, :utc_datetime_usec, default: fragment("NOW()")
      add :metadata, :map, default: %{}
    end
  end

  def down do
    drop table(:tag_relationships)
  end
end
