defmodule QrLabelSystem.Repo.Migrations.FixCsvDataSourceType do
  use Ecto.Migration

  def up do
    execute """
    UPDATE data_sources
    SET type = 'csv'
    WHERE type = 'excel'
      AND file_name ILIKE '%.csv'
    """
  end

  def down do
    execute """
    UPDATE data_sources
    SET type = 'excel'
    WHERE type = 'csv'
    """
  end
end
