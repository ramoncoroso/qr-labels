defmodule QrLabelSystem.Repo.Migrations.DropLabelBatches do
  use Ecto.Migration

  @doc """
  Security migration: Remove label_batches table to prevent storage
  of sensitive print data. Data is now processed in memory only.
  """
  def up do
    drop_if_exists table(:label_batches)
  end

  def down do
    # No restoration - intentional security removal
    # Print data should not be persisted in the database
    :ok
  end
end
