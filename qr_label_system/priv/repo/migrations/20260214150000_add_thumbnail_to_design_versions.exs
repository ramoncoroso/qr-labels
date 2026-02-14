defmodule QrLabelSystem.Repo.Migrations.AddThumbnailToDesignVersions do
  use Ecto.Migration

  def change do
    alter table(:design_versions) do
      add :thumbnail, :text
    end
  end
end
