defmodule Clio.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def up do
    create table(:tags) do
      add :name, :string, size: 50, null: false
      add :color, :string, size: 7, default: "#6B7280"
      add :category, :string, size: 50
      add :description, :text
      add :is_default, :boolean, default: false
      add :created_by, :string, size: 100
      add :created_at, :utc_datetime_usec, default: fragment("NOW()")
      add :updated_at, :utc_datetime_usec, default: fragment("NOW()")
    end

    create unique_index(:tags, [fragment("lower(name)")])
    create index(:tags, [:category])
    create index(:tags, [:is_default])

    execute """
    CREATE TRIGGER update_tags_updated_at
    BEFORE UPDATE ON tags
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS update_tags_updated_at ON tags"
    drop table(:tags)
  end
end
