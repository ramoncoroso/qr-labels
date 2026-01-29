defmodule QrLabelSystem.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs) do
      add :action, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :bigint
      add :metadata, :jsonb, default: "{}"
      add :ip_address, :string
      add :user_agent, :text

      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:action])
    create index(:audit_logs, [:resource_type])
    create index(:audit_logs, [:resource_type, :resource_id])
    create index(:audit_logs, [:inserted_at])
  end
end
