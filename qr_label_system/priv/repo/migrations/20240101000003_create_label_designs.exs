defmodule QrLabelSystem.Repo.Migrations.CreateLabelDesigns do
  use Ecto.Migration

  def change do
    create table(:label_designs) do
      add :name, :string, null: false
      add :description, :text

      # Dimensions in millimeters
      add :width_mm, :float, null: false
      add :height_mm, :float, null: false

      # Global styling
      add :background_color, :string, default: "#FFFFFF"
      add :border_width, :float, default: 0
      add :border_color, :string, default: "#000000"
      add :border_radius, :float, default: 0

      # Template flag
      add :is_template, :boolean, default: false

      # Elements stored as JSONB array
      add :elements, :jsonb, default: "[]"

      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:label_designs, [:user_id])
    create index(:label_designs, [:is_template])
    create index(:label_designs, [:name])
  end
end
