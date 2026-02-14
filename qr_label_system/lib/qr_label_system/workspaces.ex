defmodule QrLabelSystem.Workspaces do
  @moduledoc """
  The Workspaces context.
  Handles workspace management, memberships, and invitations.
  """

  import Ecto.Query, warn: false
  alias QrLabelSystem.Repo
  alias QrLabelSystem.Workspaces.{Workspace, Membership, Invitation}
  alias QrLabelSystem.Accounts.User

  # ==========================================
  # WORKSPACE CRUD
  # ==========================================

  @doc """
  Creates a personal workspace for a user.
  Also creates an admin membership. Used in Ecto.Multi during registration.
  """
  def create_personal_workspace(%User{} = user) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:workspace, fn _changes ->
      Workspace.changeset(%Workspace{}, %{
        name: "Personal",
        slug: "personal-#{user.id}",
        type: "personal",
        owner_id: user.id
      })
    end)
    |> Ecto.Multi.insert(:membership, fn %{workspace: workspace} ->
      Membership.changeset(%Membership{}, %{
        workspace_id: workspace.id,
        user_id: user.id,
        role: "admin"
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{workspace: workspace}} -> {:ok, workspace}
      {:error, _step, changeset, _changes} -> {:error, changeset}
    end
  end

  @doc """
  Creates a personal workspace within an existing Multi (for registration).
  """
  def create_personal_workspace_multi(multi, user_key \\ :user) do
    multi
    |> Ecto.Multi.insert(:workspace, fn changes ->
      user = Map.fetch!(changes, user_key)
      Workspace.changeset(%Workspace{}, %{
        name: "Personal",
        slug: "personal-#{user.id}",
        type: "personal",
        owner_id: user.id
      })
    end)
    |> Ecto.Multi.insert(:membership, fn changes ->
      user = Map.fetch!(changes, user_key)
      workspace = Map.fetch!(changes, :workspace)
      Membership.changeset(%Membership{}, %{
        workspace_id: workspace.id,
        user_id: user.id,
        role: "admin"
      })
    end)
  end

  @doc """
  Creates a team workspace. The creating user becomes admin.
  """
  def create_workspace(%User{} = user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:workspace, fn _changes ->
      Workspace.changeset(%Workspace{}, Map.merge(attrs, %{type: "team", owner_id: user.id}))
    end)
    |> Ecto.Multi.insert(:membership, fn %{workspace: workspace} ->
      Membership.changeset(%Membership{}, %{
        workspace_id: workspace.id,
        user_id: user.id,
        role: "admin"
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{workspace: workspace}} -> {:ok, workspace}
      {:error, :workspace, changeset, _} -> {:error, changeset}
      {:error, _step, changeset, _changes} -> {:error, changeset}
    end
  end

  def get_workspace(id), do: Repo.get(Workspace, id)

  def get_workspace!(id), do: Repo.get!(Workspace, id)

  @doc """
  Lists workspaces where user is a member.
  Personal workspace first, then teams alphabetically.
  """
  def list_user_workspaces(user_id) do
    Repo.all(
      from w in Workspace,
        join: m in Membership, on: m.workspace_id == w.id,
        where: m.user_id == ^user_id and is_nil(w.deleted_at),
        order_by: [desc: w.type == "personal", asc: w.name],
        select: w
    )
  end

  @doc """
  Gets the personal workspace for a user.
  """
  def get_personal_workspace(user_id) do
    Repo.one(
      from w in Workspace,
        where: w.owner_id == ^user_id and w.type == "personal" and is_nil(w.deleted_at)
    )
  end

  @doc """
  Updates a workspace. Only team workspaces can be updated.
  """
  def update_workspace(%Workspace{type: "personal"}, _attrs) do
    {:error, :personal_workspace_immutable}
  end

  def update_workspace(%Workspace{} = workspace, attrs) do
    workspace
    |> Workspace.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Soft-deletes a team workspace. Personal workspaces cannot be deleted.
  """
  def delete_workspace(%Workspace{type: "personal"}) do
    {:error, :personal_workspace_immutable}
  end

  def delete_workspace(%Workspace{} = workspace) do
    workspace
    |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  # ==========================================
  # MEMBERSHIPS
  # ==========================================

  @doc """
  Gets the membership for a user in a workspace.
  """
  def get_membership(workspace_id, user_id) do
    Repo.one(
      from m in Membership,
        where: m.workspace_id == ^workspace_id and m.user_id == ^user_id
    )
  end

  @doc """
  Returns the user's role in a workspace, or nil if not a member.
  """
  def get_user_role(workspace_id, user_id) do
    Repo.one(
      from m in Membership,
        where: m.workspace_id == ^workspace_id and m.user_id == ^user_id,
        select: m.role
    )
  end

  def member?(workspace_id, user_id) do
    Repo.exists?(
      from m in Membership,
        where: m.workspace_id == ^workspace_id and m.user_id == ^user_id
    )
  end

  def workspace_admin?(workspace_id, user_id) do
    get_user_role(workspace_id, user_id) == "admin"
  end

  def workspace_operator?(workspace_id, user_id) do
    get_user_role(workspace_id, user_id) in ["admin", "operator"]
  end

  @doc """
  Lists members of a workspace with preloaded user info.
  """
  def list_members(workspace_id) do
    Repo.all(
      from m in Membership,
        where: m.workspace_id == ^workspace_id,
        preload: [:user],
        order_by: [asc: m.role, asc: m.inserted_at]
    )
  end

  @doc """
  Updates a member's role. Cannot change the owner's role or leave workspace
  without at least one admin.
  """
  def update_member_role(%Membership{} = membership, new_role) do
    workspace = get_workspace!(membership.workspace_id)

    cond do
      workspace.owner_id == membership.user_id && new_role != "admin" ->
        {:error, :cannot_demote_owner}

      true ->
        # Check we won't remove the last admin
        if membership.role == "admin" && new_role != "admin" do
          admin_count = Repo.one(
            from m in Membership,
              where: m.workspace_id == ^membership.workspace_id and m.role == "admin",
              select: count()
          )

          if admin_count <= 1 do
            {:error, :last_admin}
          else
            do_update_role(membership, new_role)
          end
        else
          do_update_role(membership, new_role)
        end
    end
  end

  defp do_update_role(membership, role) do
    membership
    |> Membership.changeset(%{role: role})
    |> Repo.update()
  end

  @doc """
  Removes a member from a workspace. Cannot remove the owner.
  """
  def remove_member(%Membership{} = membership) do
    workspace = get_workspace!(membership.workspace_id)

    if workspace.owner_id == membership.user_id do
      {:error, :cannot_remove_owner}
    else
      Repo.delete(membership)
    end
  end

  # ==========================================
  # INVITATIONS
  # ==========================================

  @doc """
  Creates an invitation to join a workspace.
  """
  def create_invitation(%Workspace{} = workspace, %User{} = inviter, email, role \\ "operator") do
    # Check if user is already a member
    existing_user = QrLabelSystem.Accounts.get_user_by_email(email)

    if existing_user && member?(workspace.id, existing_user.id) do
      {:error, :already_member}
    else
      %Invitation{}
      |> Invitation.changeset(%{
        workspace_id: workspace.id,
        email: email,
        role: role,
        invited_by_id: inviter.id
      })
      |> Repo.insert()
    end
  end

  @doc """
  Accepts an invitation by token. Creates a membership.
  """
  def accept_invitation(token, %User{} = user) do
    case get_invitation_by_token(token) do
      nil ->
        {:error, :not_found}

      invitation ->
        cond do
          !Invitation.pending?(invitation) ->
            {:error, :already_used}

          Invitation.expired?(invitation) ->
            {:error, :expired}

          String.downcase(user.email) != String.downcase(invitation.email) ->
            {:error, :email_mismatch}

          true ->
            Ecto.Multi.new()
            |> Ecto.Multi.insert(:membership, fn _changes ->
              Membership.changeset(%Membership{}, %{
                workspace_id: invitation.workspace_id,
                user_id: user.id,
                role: invitation.role
              })
            end)
            |> Ecto.Multi.update(:invitation, fn _changes ->
              Ecto.Changeset.change(invitation, status: "accepted")
            end)
            |> Repo.transaction()
            |> case do
              {:ok, %{membership: membership}} -> {:ok, membership}
              {:error, _step, changeset, _} -> {:error, changeset}
            end
        end
    end
  end

  @doc """
  Cancels a pending invitation.
  """
  def cancel_invitation(%Invitation{} = invitation) do
    invitation
    |> Ecto.Changeset.change(status: "cancelled")
    |> Repo.update()
  end

  @doc """
  Lists pending invitations for a workspace.
  """
  def list_pending_invitations(workspace_id) do
    Repo.all(
      from i in Invitation,
        where: i.workspace_id == ^workspace_id and i.status == "pending",
        order_by: [desc: i.inserted_at]
    )
  end

  @doc """
  Gets an invitation by its unique token.
  """
  def get_invitation_by_token(token) when is_binary(token) do
    Repo.one(
      from i in Invitation,
        where: i.token == ^token,
        preload: [:workspace]
    )
  end

  def get_invitation_by_token(_), do: nil
end
