defmodule QrLabelSystem.Designs.Category do
  @moduledoc """
  Schema for design categories.
  Categories help organize designs by purpose (e.g., shelves, materials, equipment).
  Each user has their own set of categories.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "design_categories" do
    field :name, :string
    field :color, :string, default: "#6366F1"

    belongs_to :user, QrLabelSystem.Accounts.User
    has_many :designs, QrLabelSystem.Designs.Design

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating a category.
  """
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :color, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 50)
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/, message: "must be a valid hex color")
    |> unique_constraint([:user_id, :name], message: "ya existe una categoría con este nombre")
  end
end
