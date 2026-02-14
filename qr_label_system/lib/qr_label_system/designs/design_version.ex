defmodule QrLabelSystem.Designs.DesignVersion do
  @moduledoc """
  Schema for design version snapshots.

  Each version is an immutable snapshot of a design at a point in time.
  Created automatically on each save, with MD5 deduplication to avoid
  storing identical consecutive versions.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "design_versions" do
    field :version_number, :integer
    field :name, :string
    field :description, :string
    field :width_mm, :float
    field :height_mm, :float
    field :background_color, :string
    field :border_width, :float
    field :border_color, :string
    field :border_radius, :float
    field :label_type, :string
    field :elements, {:array, :map}, default: []
    field :groups, {:array, :map}, default: []
    field :change_message, :string
    field :element_count, :integer, default: 0
    field :snapshot_hash, :string
    field :custom_name, :string

    belongs_to :design, QrLabelSystem.Designs.Design
    belongs_to :user, QrLabelSystem.Accounts.User

    timestamps(updated_at: false, type: :utc_datetime)
  end

  @doc """
  Changeset for creating a version snapshot. Versions are immutable.
  """
  def changeset(version, attrs) do
    version
    |> cast(attrs, [
      :design_id, :version_number, :user_id,
      :name, :description, :width_mm, :height_mm,
      :background_color, :border_width, :border_color, :border_radius,
      :label_type, :elements, :groups,
      :change_message, :element_count, :snapshot_hash, :custom_name
    ])
    |> validate_required([:design_id, :version_number, :name, :width_mm, :height_mm])
    |> unique_constraint([:design_id, :version_number])
    |> foreign_key_constraint(:design_id)
  end

  @doc """
  Changeset for renaming a version. Only allows updating custom_name.
  """
  def rename_changeset(version, attrs) do
    version
    |> cast(attrs, [:custom_name])
    |> validate_length(:custom_name, max: 100)
  end
end
