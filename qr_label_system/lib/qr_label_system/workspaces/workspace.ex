defmodule QrLabelSystem.Workspaces.Workspace do
  @moduledoc """
  Schema for workspaces.

  Types:
  - personal: Auto-created for each user, cannot be deleted or renamed
  - team: Created by users to collaborate with others
  """
  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(personal team)

  schema "workspaces" do
    field :name, :string
    field :slug, :string
    field :type, :string, default: "personal"
    field :description, :string
    field :deleted_at, :utc_datetime

    belongs_to :owner, QrLabelSystem.Accounts.User
    has_many :memberships, QrLabelSystem.Workspaces.Membership
    has_many :invitations, QrLabelSystem.Workspaces.Invitation
    has_many :designs, QrLabelSystem.Designs.Design
    has_many :data_sources, QrLabelSystem.DataSources.DataSource
    has_many :tags, QrLabelSystem.Designs.Tag

    timestamps(type: :utc_datetime)
  end

  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :slug, :type, :description, :owner_id])
    |> validate_required([:name, :type, :owner_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_inclusion(:type, @types)
    |> maybe_generate_slug()
    |> unique_constraint(:slug)
  end

  def personal?(%__MODULE__{type: "personal"}), do: true
  def personal?(_), do: false

  def team?(%__MODULE__{type: "team"}), do: true
  def team?(_), do: false

  defp maybe_generate_slug(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        name = get_field(changeset, :name) || ""
        owner_id = get_field(changeset, :owner_id)
        slug = generate_slug(name, owner_id)
        put_change(changeset, :slug, slug)

      _ ->
        changeset
    end
  end

  defp generate_slug(name, owner_id) do
    base =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\s-]/u, "")
      |> String.replace(~r/\s+/, "-")
      |> String.trim("-")
      |> String.slice(0, 50)

    suffix = if owner_id, do: "-#{owner_id}", else: "-#{:erlang.unique_integer([:positive])}"
    base <> suffix
  end
end
