defmodule QrLabelSystem.Repo.Migrations.AddLanguagesToDesigns do
  use Ecto.Migration

  def change do
    alter table(:label_designs) do
      add :languages, {:array, :string}, default: ["es"]
      add :default_language, :string, default: "es"
    end
  end
end
