defmodule QrLabelSystem.Repo.Migrations.AddTemplateCategoryToDesigns do
  use Ecto.Migration

  def change do
    alter table(:label_designs) do
      add :template_category, :string
    end

    create index(:label_designs, [:template_category])
  end
end
