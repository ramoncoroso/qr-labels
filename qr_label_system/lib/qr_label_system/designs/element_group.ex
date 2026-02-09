defmodule QrLabelSystem.Designs.ElementGroup do
  @moduledoc """
  Embedded schema for element groups in label designs.

  Groups allow organizing multiple elements as a unit for:
  - Moving all members together
  - Toggling visibility/lock as a group
  - Collapsing in the layer panel
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :string
    field :name, :string
    field :locked, :boolean, default: false
    field :visible, :boolean, default: true
    field :collapsed, :boolean, default: false
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [:id, :name, :locked, :visible, :collapsed])
    |> generate_id_if_missing()
    |> validate_required([:id, :name])
  end

  defp generate_id_if_missing(changeset) do
    if get_field(changeset, :id) do
      changeset
    else
      put_change(changeset, :id, "grp_#{:erlang.unique_integer([:positive])}")
    end
  end
end
