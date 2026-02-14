defmodule QrLabelSystem.Workspaces.Membership do
  @moduledoc """
  Schema for workspace memberships.

  Roles:
  - admin: Full control over workspace settings, members, and all resources
  - operator: Can create/edit/delete own resources within the workspace
  - viewer: Read-only access to workspace resources
  """
  use Ecto.Schema
  import Ecto.Changeset

  @roles ~w(admin operator viewer)

  schema "workspace_memberships" do
    field :role, :string, default: "operator"

    belongs_to :workspace, QrLabelSystem.Workspaces.Workspace
    belongs_to :user, QrLabelSystem.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:workspace_id, :user_id, :role])
    |> validate_required([:workspace_id, :user_id, :role])
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:workspace_id, :user_id])
  end

  def admin?(%__MODULE__{role: "admin"}), do: true
  def admin?(_), do: false

  def operator?(%__MODULE__{role: role}) when role in ["admin", "operator"], do: true
  def operator?(_), do: false

  def roles, do: @roles
end
