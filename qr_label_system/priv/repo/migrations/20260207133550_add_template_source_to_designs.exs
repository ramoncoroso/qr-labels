defmodule QrLabelSystem.Repo.Migrations.AddTemplateSourceToDesigns do
  use Ecto.Migration

  def change do
    alter table(:label_designs) do
      add :template_source, :string
    end

    create index(:label_designs, [:template_source])
  end
end
