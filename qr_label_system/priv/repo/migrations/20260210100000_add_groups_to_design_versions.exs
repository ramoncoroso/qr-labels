defmodule QrLabelSystem.Repo.Migrations.AddGroupsToDesignVersions do
  use Ecto.Migration

  def change do
    alter table(:design_versions) do
      add :groups, {:array, :map}, default: []
    end
  end
end
