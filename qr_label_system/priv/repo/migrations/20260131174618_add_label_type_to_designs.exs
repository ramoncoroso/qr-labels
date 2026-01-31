defmodule QrLabelSystem.Repo.Migrations.AddLabelTypeToDesigns do
  use Ecto.Migration

  def change do
    alter table(:label_designs) do
      add :label_type, :string, default: "single", null: false
    end

    create index(:label_designs, [:user_id, :label_type])
  end
end
