defmodule QrLabelSystem.Repo.Migrations.AddApprovalWorkflow do
  use Ecto.Migration

  def change do
    # System settings table (for approval_required toggle)
    create table(:system_settings) do
      add :key, :string, null: false
      add :value, :string
      timestamps()
    end

    create unique_index(:system_settings, [:key])

    # Status field on label_designs
    alter table(:label_designs) do
      add :status, :string, default: "draft", null: false
    end

    create index(:label_designs, [:status])
    create index(:label_designs, [:user_id, :status])

    # Design approvals history table
    create table(:design_approvals) do
      add :design_id, references(:label_designs, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :action, :string, null: false
      add :comment, :text
      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:design_approvals, [:design_id])
    create index(:design_approvals, [:user_id])

    # Insert default setting: approval disabled
    execute(
      "INSERT INTO system_settings (key, value, inserted_at, updated_at) VALUES ('approval_required', 'false', NOW(), NOW())",
      "DELETE FROM system_settings WHERE key = 'approval_required'"
    )
  end
end
