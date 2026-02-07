defmodule QrLabelSystem.Designs.Tag do
  @moduledoc """
  Schema for design tags.
  Tags help organize designs with a many-to-many relationship,
  allowing each design to have multiple tags.
  Each user has their own set of tags.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "design_tags" do
    field :name, :string
    field :color, :string, default: "#6366F1"

    belongs_to :user, QrLabelSystem.Accounts.User
    many_to_many :designs, QrLabelSystem.Designs.Design, join_through: "design_tag_assignments"

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating a tag.
  """
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :color, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 50)
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/, message: "must be a valid hex color")
    |> unique_constraint([:user_id, :name], message: "ya existe un tag con este nombre")
  end
end
