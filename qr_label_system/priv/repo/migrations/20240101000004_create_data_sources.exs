defmodule QrLabelSystem.Repo.Migrations.CreateDataSources do
  use Ecto.Migration

  def change do
    create table(:data_sources) do
      add :name, :string, null: false
      add :type, :string, null: false  # excel, postgresql, mysql, sqlserver
      add :query, :text

      # Encrypted connection configuration
      add :connection_config, :binary

      # Connection test results
      add :last_tested_at, :utc_datetime
      add :test_status, :string
      add :test_error, :text

      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:data_sources, [:user_id])
    create index(:data_sources, [:type])
  end
end
