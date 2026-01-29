defmodule QrLabelSystem.Repo.Migrations.AddSoftDeleteColumns do
  use Ecto.Migration

  def change do
    # Add deleted_at to label_designs
    alter table(:label_designs) do
      add :deleted_at, :utc_datetime
    end

    create index(:label_designs, [:deleted_at])

    # Add deleted_at to data_sources
    alter table(:data_sources) do
      add :deleted_at, :utc_datetime
    end

    create index(:data_sources, [:deleted_at])

    # Add deleted_at to label_batches
    alter table(:label_batches) do
      add :deleted_at, :utc_datetime
    end

    create index(:label_batches, [:deleted_at])

    # Add deleted_at to users (for account deactivation)
    alter table(:users) do
      add :deleted_at, :utc_datetime
    end

    create index(:users, [:deleted_at])
  end
end
