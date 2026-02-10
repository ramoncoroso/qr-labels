defmodule QrLabelSystem.Repo.Migrations.AddComplianceToDesigns do
  use Ecto.Migration

  def change do
    alter table(:label_designs) do
      add :compliance_standard, :string
    end
  end
end
