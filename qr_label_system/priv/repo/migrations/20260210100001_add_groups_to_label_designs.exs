defmodule QrLabelSystem.Repo.Migrations.AddGroupsToLabelDesigns do
  use Ecto.Migration

  def change do
    alter table(:label_designs) do
      add :groups, {:array, :map}, default: []
    end
  end
end
