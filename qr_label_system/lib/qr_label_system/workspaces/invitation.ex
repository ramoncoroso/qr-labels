defmodule QrLabelSystem.Workspaces.Invitation do
  @moduledoc """
  Schema for workspace invitations.

  An invitation is sent to an email address with a unique token.
  The recipient can accept the invitation to join the workspace.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending accepted cancelled)
  @invitation_ttl_days 7

  schema "workspace_invitations" do
    field :email, :string
    field :role, :string, default: "operator"
    field :token, :string
    field :status, :string, default: "pending"
    field :expires_at, :utc_datetime

    belongs_to :workspace, QrLabelSystem.Workspaces.Workspace
    belongs_to :invited_by, QrLabelSystem.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:workspace_id, :email, :role, :invited_by_id])
    |> validate_required([:workspace_id, :email, :role])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_inclusion(:role, QrLabelSystem.Workspaces.Membership.roles())
    |> validate_inclusion(:status, @statuses)
    |> put_token()
    |> put_expiration()
    |> unique_constraint(:token)
  end

  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  def pending?(%__MODULE__{status: "pending"}), do: true
  def pending?(_), do: false

  defp put_token(changeset) do
    case get_field(changeset, :token) do
      nil ->
        token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
        put_change(changeset, :token, token)

      _ ->
        changeset
    end
  end

  defp put_expiration(changeset) do
    case get_field(changeset, :expires_at) do
      nil ->
        expires = DateTime.utc_now() |> DateTime.add(@invitation_ttl_days * 24 * 3600, :second) |> DateTime.truncate(:second)
        put_change(changeset, :expires_at, expires)

      _ ->
        changeset
    end
  end
end
