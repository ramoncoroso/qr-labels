defmodule QrLabelSystem.Repo.Migrations.CreateLabelBatches do
  use Ecto.Migration

  def change do
    create table(:label_batches) do
      add :name, :string, null: false
      add :source_file, :string
      add :status, :string, null: false, default: "draft"
      add :total_labels, :integer, default: 0

      # Column mapping: element_id -> column_name
      add :column_mapping, :jsonb, default: "{}"

      # Optional data snapshot for reproducibility
      add :data_snapshot, :jsonb

      # Print tracking
      add :printed_at, :utc_datetime
      add :print_count, :integer, default: 0

      # Print configuration (paper size, margins, etc.)
      add :print_config, :jsonb, default: "{}"

      add :design_id, references(:label_designs, on_delete: :nilify_all)
      add :data_source_id, references(:data_sources, on_delete: :nilify_all)
      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :printed_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:label_batches, [:design_id])
    create index(:label_batches, [:data_source_id])
    create index(:label_batches, [:user_id])
    create index(:label_batches, [:status])
    create index(:label_batches, [:inserted_at])
  end
end
