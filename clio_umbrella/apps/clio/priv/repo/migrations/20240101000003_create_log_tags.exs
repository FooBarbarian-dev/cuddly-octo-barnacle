defmodule Clio.Repo.Migrations.CreateLogTags do
  use Ecto.Migration

  def up do
    create table(:log_tags) do
      add :log_id, references(:logs, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
      add :tagged_by, :string, size: 100
      add :tagged_at, :utc_datetime_usec, default: fragment("NOW()")
    end

    create unique_index(:log_tags, [:log_id, :tag_id])
    create index(:log_tags, [:log_id])
    create index(:log_tags, [:tag_id])
    create index(:log_tags, [:tagged_at])
  end

  def down do
    drop table(:log_tags)
  end
end
