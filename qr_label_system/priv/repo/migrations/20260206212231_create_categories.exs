defmodule QrLabelSystem.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:design_categories) do
      add :name, :string, null: false
      add :color, :string, default: "#6366F1"
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:design_categories, [:user_id])
    create unique_index(:design_categories, [:user_id, :name])

    alter table(:label_designs) do
      add :category_id, references(:design_categories, on_delete: :nilify_all)
    end

    create index(:label_designs, [:category_id])
  end
end
