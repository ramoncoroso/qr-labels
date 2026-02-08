defmodule QrLabelSystem.Repo.Migrations.CreateDesignVersions do
  use Ecto.Migration

  def change do
    create table(:design_versions) do
      add :design_id, references(:label_designs, on_delete: :delete_all), null: false
      add :version_number, :integer, null: false
      add :user_id, references(:users, on_delete: :nilify_all)

      # Snapshot completo del estado del diseño
      add :name, :string, null: false
      add :description, :text
      add :width_mm, :float, null: false
      add :height_mm, :float, null: false
      add :background_color, :string
      add :border_width, :float
      add :border_color, :string
      add :border_radius, :float
      add :label_type, :string
      add :elements, :jsonb, default: "[]"

      # Metadata de versión
      add :change_message, :string
      add :element_count, :integer, default: 0
      add :snapshot_hash, :string

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create unique_index(:design_versions, [:design_id, :version_number])
    create index(:design_versions, [:design_id, :inserted_at])
    create index(:design_versions, [:user_id])
  end
end
