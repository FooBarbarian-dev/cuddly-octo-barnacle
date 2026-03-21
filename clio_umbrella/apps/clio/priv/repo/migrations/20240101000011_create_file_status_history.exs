defmodule Clio.Repo.Migrations.CreateFileStatusHistory do
  use Ecto.Migration

  def up do
    create table(:file_status_history) do
      add :filename, :string, size: 254, null: false
      add :status, :string, size: 50, null: false
      add :previous_status, :string, size: 50
      add :hash_algorithm, :string, size: 50
      add :hash_value, :string, size: 128
      add :hostname, :string, size: 75
      add :internal_ip, :string, size: 45
      add :external_ip, :string, size: 45
      add :mac_address, :string, size: 17
      add :username, :string, size: 75
      add :analyst, :string, size: 100
      add :notes, :text
      add :command, :text
      add :secrets, :text
      add :timestamp, :utc_datetime_usec, default: fragment("NOW()")
      add :operation_tags, {:array, :integer}, default: []
    end
  end

  def down do
    drop table(:file_status_history)
  end
end
