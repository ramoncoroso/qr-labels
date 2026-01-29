defmodule QrLabelSystem.Batches.Batch do
  @moduledoc """
  Schema for label batches.

  A batch represents a set of labels generated from:
  - A design (label template)
  - A data source (Excel file or database query)
  - Column mappings (which data columns go to which design elements)

  Each row of data generates one unique label with its own codes.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(draft ready printed archived)

  schema "label_batches" do
    field :name, :string
    field :source_file, :string
    field :status, :string, default: "draft"
    field :total_labels, :integer, default: 0

    # Column mapping: element_id -> column_name
    # e.g., %{"qr_1" => "ID", "text_1" => "Name", "barcode_1" => "SKU"}
    field :column_mapping, :map, default: %{}

    # Snapshot of the data at generation time (optional, for reproducibility)
    field :data_snapshot, {:array, :map}

    # Print tracking
    field :printed_at, :utc_datetime
    field :print_count, :integer, default: 0

    # Print configuration
    field :print_config, :map, default: %{}

    belongs_to :design, QrLabelSystem.Designs.Design
    belongs_to :data_source, QrLabelSystem.DataSources.DataSource
    belongs_to :user, QrLabelSystem.Accounts.User
    belongs_to :printed_by, QrLabelSystem.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating a batch.
  """
  def changeset(batch, attrs) do
    batch
    |> cast(attrs, [
      :name, :source_file, :status, :total_labels,
      :column_mapping, :data_snapshot, :print_config,
      :design_id, :data_source_id, :user_id
    ])
    |> validate_required([:name, :design_id, :user_id])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:design_id)
    |> foreign_key_constraint(:data_source_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for updating batch status.
  """
  def status_changeset(batch, status) do
    batch
    |> cast(%{status: status}, [:status])
    |> validate_inclusion(:status, @statuses)
  end

  @doc """
  Changeset for recording a print action.
  """
  def print_changeset(batch, printed_by_id) do
    batch
    |> cast(%{
      status: "printed",
      printed_at: DateTime.utc_now(),
      printed_by_id: printed_by_id,
      print_count: (batch.print_count || 0) + 1
    }, [:status, :printed_at, :printed_by_id, :print_count])
  end

  @doc """
  Changeset for saving print configuration.
  """
  def print_config_changeset(batch, config) do
    batch
    |> cast(%{print_config: config}, [:print_config])
  end

  def statuses, do: @statuses

  @doc """
  Returns the batch data suitable for label generation.
  Combines the design, mappings, and data rows.
  """
  def to_generation_data(%__MODULE__{} = batch, data_rows) do
    %{
      batch_id: batch.id,
      design: batch.design,
      column_mapping: batch.column_mapping,
      rows: data_rows,
      total: length(data_rows)
    }
  end
end
