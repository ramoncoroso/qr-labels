defmodule QrLabelSystem.Repo.Migrations.AddCustomNameToDesignVersions do
  use Ecto.Migration

  def change do
    alter table(:design_versions) do
      add :custom_name, :string
    end
  end
end
