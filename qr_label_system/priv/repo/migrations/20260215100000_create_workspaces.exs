defmodule QrLabelSystem.Repo.Migrations.CreateWorkspaces do
  use Ecto.Migration

  def change do
    create table(:workspaces) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :type, :string, null: false, default: "personal"
      add :description, :string
      add :owner_id, references(:users, on_delete: :delete_all), null: false
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:workspaces, [:slug])
    create index(:workspaces, [:owner_id])
    create index(:workspaces, [:type])

    create table(:workspace_memberships) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "operator"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:workspace_memberships, [:workspace_id, :user_id])
    create index(:workspace_memberships, [:user_id])

    create table(:workspace_invitations) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :email, :string, null: false
      add :role, :string, null: false, default: "operator"
      add :token, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :expires_at, :utc_datetime, null: false
      add :invited_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:workspace_invitations, [:token])
    create index(:workspace_invitations, [:workspace_id])
    create index(:workspace_invitations, [:email])
  end
end
