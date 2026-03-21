defmodule Clio.Repo.Migrations.CreateLogTemplates do
  use Ecto.Migration

  def up do
    create table(:log_templates) do
      add :name, :string, size: 100, null: false
      add :template_data, :map, null: false, default: %{}
      add :created_by, :string, size: 100, null: false
      add :created_at, :utc_datetime_usec, default: fragment("NOW()")
      add :updated_at, :utc_datetime_usec, default: fragment("NOW()")
    end

    execute """
    CREATE TRIGGER update_log_templates_updated_at
    BEFORE UPDATE ON log_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS update_log_templates_updated_at ON log_templates"
    drop table(:log_templates)
  end
end
