defmodule QrLabelSystem.Repo.Migrations.AddFilePathToDataSources do
  use Ecto.Migration

  def change do
    alter table(:data_sources) do
      add :file_path, :string
      add :file_name, :string
    end
  end
end
