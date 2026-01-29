defmodule QrLabelSystem.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :role, :string, null: false, default: "operator"
      add :confirmed_at, :naive_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
  end
end
