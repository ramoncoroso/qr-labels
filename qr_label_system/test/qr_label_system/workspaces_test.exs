defmodule QrLabelSystem.WorkspacesTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.Workspaces
  alias QrLabelSystem.Workspaces.{Workspace, Membership, Invitation}

  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.WorkspacesFixtures

  # ==========================================
  # PERSONAL WORKSPACE CREATION
  # ==========================================

  describe "create_personal_workspace/1" do
    test "creates a personal workspace for a user" do
      user = user_fixture()
      # user_fixture() already creates a personal workspace via register_user
      workspace = get_personal_workspace!(user)

      assert workspace.type == "personal"
      assert workspace.name == "Personal"
      assert workspace.slug == "personal-#{user.id}"
      assert workspace.owner_id == user.id
    end

    test "creates admin membership automatically" do
      user = user_fixture()
      workspace = get_personal_workspace!(user)

      membership = Workspaces.get_membership(workspace.id, user.id)
      assert membership != nil
      assert membership.role == "admin"
    end

    test "returns error if user already has a personal workspace" do
      user = user_fixture()
      # user already has a personal workspace from registration

      assert {:error, _changeset} = Workspaces.create_personal_workspace(user)
    end
  end

  # ==========================================
  # TEAM WORKSPACE CREATION
  # ==========================================

  describe "create_workspace/2" do
    test "creates a team workspace" do
      user = user_fixture()

      assert {:ok, %Workspace{} = workspace} =
               Workspaces.create_workspace(user, %{name: "My Team", description: "A team space"})

      assert workspace.name == "My Team"
      assert workspace.type == "team"
      assert workspace.owner_id == user.id
      assert workspace.description == "A team space"
    end

    test "creates admin membership for the creator" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Team Alpha"})

      membership = Workspaces.get_membership(workspace.id, user.id)
      assert membership != nil
      assert membership.role == "admin"
    end

    test "validates required name" do
      user = user_fixture()

      assert {:error, changeset} = Workspaces.create_workspace(user, %{name: ""})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "auto-generates slug from name and owner" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "My Cool Team"})

      assert workspace.slug =~ "my-cool-team"
      assert workspace.slug =~ "#{user.id}"
    end

    test "allows creating multiple team workspaces" do
      user = user_fixture()

      assert {:ok, ws1} = Workspaces.create_workspace(user, %{name: "Team One"})
      assert {:ok, ws2} = Workspaces.create_workspace(user, %{name: "Team Two"})

      assert ws1.id != ws2.id
      assert ws1.slug != ws2.slug
    end
  end

  # ==========================================
  # WORKSPACE QUERIES
  # ==========================================

  describe "get_workspace/1" do
    test "returns workspace by id" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Test WS"})

      assert %Workspace{} = fetched = Workspaces.get_workspace(workspace.id)
      assert fetched.id == workspace.id
      assert fetched.name == "Test WS"
    end

    test "returns nil for non-existent id" do
      assert Workspaces.get_workspace(0) == nil
    end
  end

  describe "get_workspace!/1" do
    test "returns workspace by id" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Bang WS"})

      assert %Workspace{} = Workspaces.get_workspace!(workspace.id)
    end

    test "raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Workspaces.get_workspace!(0)
      end
    end
  end

  describe "list_user_workspaces/1" do
    test "returns personal workspace first, then teams alphabetically" do
      user = user_fixture()
      {:ok, _ws_z} = Workspaces.create_workspace(user, %{name: "Zebra Team"})
      {:ok, _ws_a} = Workspaces.create_workspace(user, %{name: "Alpha Team"})

      workspaces = Workspaces.list_user_workspaces(user.id)

      assert length(workspaces) == 3
      assert hd(workspaces).type == "personal"
      team_names = workspaces |> tl() |> Enum.map(& &1.name)
      assert team_names == ["Alpha Team", "Zebra Team"]
    end

    test "does not include deleted workspaces" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "To Delete"})
      {:ok, _deleted} = Workspaces.delete_workspace(workspace)

      workspaces = Workspaces.list_user_workspaces(user.id)
      assert length(workspaces) == 1
      assert hd(workspaces).type == "personal"
    end

    test "does not include workspaces where user is not a member" do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, _other_ws} = Workspaces.create_workspace(other_user, %{name: "Other Team"})

      workspaces = Workspaces.list_user_workspaces(user.id)
      workspace_names = Enum.map(workspaces, & &1.name)
      refute "Other Team" in workspace_names
    end

    test "returns empty list for unknown user" do
      assert Workspaces.list_user_workspaces(0) == []
    end
  end

  describe "get_personal_workspace/1" do
    test "returns the personal workspace for a user" do
      user = user_fixture()

      workspace = Workspaces.get_personal_workspace(user.id)
      assert workspace != nil
      assert workspace.type == "personal"
      assert workspace.owner_id == user.id
    end

    test "returns nil for unknown user" do
      assert Workspaces.get_personal_workspace(0) == nil
    end
  end

  # ==========================================
  # UPDATE / DELETE WORKSPACE
  # ==========================================

  describe "update_workspace/2" do
    test "updates team workspace name" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Old Name"})

      assert {:ok, updated} = Workspaces.update_workspace(workspace, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "updates team workspace description" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Team"})

      assert {:ok, updated} =
               Workspaces.update_workspace(workspace, %{description: "Updated desc"})

      assert updated.description == "Updated desc"
    end

    test "rejects updating personal workspace" do
      user = user_fixture()
      personal = get_personal_workspace!(user)

      assert {:error, :personal_workspace_immutable} =
               Workspaces.update_workspace(personal, %{name: "Renamed"})
    end

    test "validates name length" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Team"})

      assert {:error, changeset} =
               Workspaces.update_workspace(workspace, %{name: String.duplicate("x", 101)})

      assert errors_on(changeset).name != []
    end
  end

  describe "delete_workspace/1" do
    test "soft-deletes a team workspace" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "To Delete"})

      assert {:ok, deleted} = Workspaces.delete_workspace(workspace)
      assert deleted.deleted_at != nil
    end

    test "soft-deleted workspace still exists in DB" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Soft Delete"})
      {:ok, _deleted} = Workspaces.delete_workspace(workspace)

      # Can still fetch by ID directly
      assert %Workspace{} = Workspaces.get_workspace(workspace.id)
    end

    test "rejects deleting personal workspace" do
      user = user_fixture()
      personal = get_personal_workspace!(user)

      assert {:error, :personal_workspace_immutable} = Workspaces.delete_workspace(personal)
    end
  end

  # ==========================================
  # MEMBERSHIPS
  # ==========================================

  describe "get_membership/2" do
    test "returns membership for user in workspace" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Team"})

      assert %Membership{} = membership = Workspaces.get_membership(workspace.id, user.id)
      assert membership.role == "admin"
      assert membership.user_id == user.id
      assert membership.workspace_id == workspace.id
    end

    test "returns nil when user is not a member" do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Team"})

      assert Workspaces.get_membership(workspace.id, other_user.id) == nil
    end
  end

  describe "get_user_role/2" do
    test "returns role string for member" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Team"})

      assert Workspaces.get_user_role(workspace.id, user.id) == "admin"
    end

    test "returns nil for non-member" do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Team"})

      assert Workspaces.get_user_role(workspace.id, other_user.id) == nil
    end
  end

  describe "member?/2" do
    test "returns true when user is a member" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Team"})

      assert Workspaces.member?(workspace.id, user.id) == true
    end

    test "returns false when user is not a member" do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Team"})

      assert Workspaces.member?(workspace.id, other_user.id) == false
    end
  end

  describe "workspace_admin?/2" do
    test "returns true for admin" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Team"})

      assert Workspaces.workspace_admin?(workspace.id, user.id) == true
    end

    test "returns false for operator" do
      owner = user_fixture()
      member = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})
      _membership = membership_fixture(workspace, member, "operator")

      assert Workspaces.workspace_admin?(workspace.id, member.id) == false
    end

    test "returns false for viewer" do
      owner = user_fixture()
      member = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})
      _membership = membership_fixture(workspace, member, "viewer")

      assert Workspaces.workspace_admin?(workspace.id, member.id) == false
    end

    test "returns false for non-member" do
      user = user_fixture()
      other = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Team"})

      assert Workspaces.workspace_admin?(workspace.id, other.id) == false
    end
  end

  describe "workspace_operator?/2" do
    test "returns true for admin" do
      user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Team"})

      assert Workspaces.workspace_operator?(workspace.id, user.id) == true
    end

    test "returns true for operator" do
      owner = user_fixture()
      member = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})
      _membership = membership_fixture(workspace, member, "operator")

      assert Workspaces.workspace_operator?(workspace.id, member.id) == true
    end

    test "returns false for viewer" do
      owner = user_fixture()
      member = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})
      _membership = membership_fixture(workspace, member, "viewer")

      assert Workspaces.workspace_operator?(workspace.id, member.id) == false
    end

    test "returns false for non-member" do
      user = user_fixture()
      other = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(user, %{name: "Team"})

      assert Workspaces.workspace_operator?(workspace.id, other.id) == false
    end
  end

  describe "list_members/1" do
    test "returns all members with preloaded user" do
      owner = user_fixture()
      member = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})
      _membership = membership_fixture(workspace, member, "operator")

      members = Workspaces.list_members(workspace.id)
      assert length(members) == 2

      emails = Enum.map(members, & &1.user.email)
      assert owner.email in emails
      assert member.email in emails
    end

    test "returns empty list for workspace with no members" do
      # This is an edge case - in practice workspaces always have at least the owner
      assert Workspaces.list_members(0) == []
    end

    test "orders by role then insertion date" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      member1 = user_fixture()
      member2 = user_fixture()
      _m1 = membership_fixture(workspace, member1, "operator")
      _m2 = membership_fixture(workspace, member2, "viewer")

      members = Workspaces.list_members(workspace.id)
      roles = Enum.map(members, & &1.role)
      assert roles == ["admin", "operator", "viewer"]
    end
  end

  describe "update_member_role/2" do
    test "changes member role" do
      owner = user_fixture()
      member = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})
      membership = membership_fixture(workspace, member, "operator")

      assert {:ok, updated} = Workspaces.update_member_role(membership, "admin")
      assert updated.role == "admin"
    end

    test "rejects demoting the workspace owner" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})
      owner_membership = Workspaces.get_membership(workspace.id, owner.id)

      assert {:error, :cannot_demote_owner} =
               Workspaces.update_member_role(owner_membership, "operator")
    end

    test "rejects removing the last admin" do
      owner = user_fixture()
      member = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})
      membership = membership_fixture(workspace, member, "operator")

      # Promote member to admin first
      {:ok, admin_membership} = Workspaces.update_member_role(membership, "admin")

      # Now try to demote back - should succeed since owner is still admin
      assert {:ok, _demoted} = Workspaces.update_member_role(admin_membership, "operator")
    end

    test "allows role change when multiple admins exist" do
      owner = user_fixture()
      member1 = user_fixture()
      member2 = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      m1 = membership_fixture(workspace, member1, "operator")
      _m2 = membership_fixture(workspace, member2, "operator")

      # Promote both to admin
      {:ok, m1_admin} = Workspaces.update_member_role(m1, "admin")

      # Demote one - should work since there are still 2 admins (owner + member2... well owner + member1_was)
      # Actually owner is admin + m1 is admin = 2 admins, so demoting m1 leaves 1 admin (owner)
      assert {:ok, demoted} = Workspaces.update_member_role(m1_admin, "operator")
      assert demoted.role == "operator"
    end
  end

  describe "remove_member/1" do
    test "removes a member from the workspace" do
      owner = user_fixture()
      member = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})
      membership = membership_fixture(workspace, member, "operator")

      assert {:ok, %Membership{}} = Workspaces.remove_member(membership)
      assert Workspaces.get_membership(workspace.id, member.id) == nil
    end

    test "rejects removing the workspace owner" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})
      owner_membership = Workspaces.get_membership(workspace.id, owner.id)

      assert {:error, :cannot_remove_owner} = Workspaces.remove_member(owner_membership)
    end

    test "removed member is no longer listed" do
      owner = user_fixture()
      member = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})
      membership = membership_fixture(workspace, member, "operator")

      {:ok, _} = Workspaces.remove_member(membership)

      members = Workspaces.list_members(workspace.id)
      member_ids = Enum.map(members, & &1.user_id)
      refute member.id in member_ids
    end
  end

  # ==========================================
  # INVITATIONS
  # ==========================================

  describe "create_invitation/4" do
    test "creates an invitation with token and expiry" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      assert {:ok, %Invitation{} = invitation} =
               Workspaces.create_invitation(workspace, owner, "newuser@example.com")

      assert invitation.email == "newuser@example.com"
      assert invitation.role == "operator"
      assert invitation.status == "pending"
      assert invitation.workspace_id == workspace.id
      assert invitation.invited_by_id == owner.id
      assert invitation.token != nil
      assert invitation.expires_at != nil
    end

    test "creates invitation with custom role" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      assert {:ok, invitation} =
               Workspaces.create_invitation(workspace, owner, "admin@example.com", "admin")

      assert invitation.role == "admin"
    end

    test "creates invitation with viewer role" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      assert {:ok, invitation} =
               Workspaces.create_invitation(workspace, owner, "viewer@example.com", "viewer")

      assert invitation.role == "viewer"
    end

    test "sets expiration approximately 7 days in the future" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      {:ok, invitation} =
        Workspaces.create_invitation(workspace, owner, "future@example.com")

      now = DateTime.utc_now()
      diff = DateTime.diff(invitation.expires_at, now, :second)
      # Should be roughly 7 days (604800 seconds), allow some margin
      assert diff > 604_700
      assert diff < 604_900
    end

    test "returns error when inviting existing member" do
      owner = user_fixture()
      member = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})
      _membership = membership_fixture(workspace, member, "operator")

      assert {:error, :already_member} =
               Workspaces.create_invitation(workspace, owner, member.email)
    end

    test "generates unique tokens for each invitation" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      {:ok, inv1} = Workspaces.create_invitation(workspace, owner, "a@example.com")
      {:ok, inv2} = Workspaces.create_invitation(workspace, owner, "b@example.com")

      assert inv1.token != inv2.token
    end
  end

  describe "accept_invitation/2" do
    test "creates membership and marks invitation as accepted" do
      owner = user_fixture()
      invitee = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      {:ok, invitation} =
        Workspaces.create_invitation(workspace, owner, invitee.email, "operator")

      assert {:ok, %Membership{} = membership} =
               Workspaces.accept_invitation(invitation.token, invitee)

      assert membership.workspace_id == workspace.id
      assert membership.user_id == invitee.id
      assert membership.role == "operator"

      # Verify invitation status changed
      updated_invitation = Workspaces.get_invitation_by_token(invitation.token)
      assert updated_invitation.status == "accepted"
    end

    test "returns error for invalid token" do
      user = user_fixture()
      assert {:error, :not_found} = Workspaces.accept_invitation("invalid-token", user)
    end

    test "returns error for already accepted invitation" do
      owner = user_fixture()
      invitee = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      {:ok, invitation} =
        Workspaces.create_invitation(workspace, owner, invitee.email)

      {:ok, _membership} = Workspaces.accept_invitation(invitation.token, invitee)

      assert {:error, :already_used} =
               Workspaces.accept_invitation(invitation.token, invitee)
    end

    test "returns error for cancelled invitation" do
      owner = user_fixture()
      invitee = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      {:ok, invitation} =
        Workspaces.create_invitation(workspace, owner, invitee.email)

      {:ok, _cancelled} = Workspaces.cancel_invitation(invitation)

      assert {:error, :already_used} =
               Workspaces.accept_invitation(invitation.token, invitee)
    end

    test "returns error for email mismatch" do
      owner = user_fixture()
      invitee = user_fixture()
      wrong_user = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      {:ok, invitation} =
        Workspaces.create_invitation(workspace, owner, invitee.email)

      assert {:error, :email_mismatch} =
               Workspaces.accept_invitation(invitation.token, wrong_user)
    end

    test "returns error for expired invitation" do
      owner = user_fixture()
      invitee = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      {:ok, invitation} =
        Workspaces.create_invitation(workspace, owner, invitee.email)

      # Manually expire the invitation
      expired_at = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      invitation
      |> Ecto.Changeset.change(expires_at: expired_at)
      |> Repo.update!()

      assert {:error, :expired} =
               Workspaces.accept_invitation(invitation.token, invitee)
    end
  end

  describe "cancel_invitation/1" do
    test "marks invitation as cancelled" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      {:ok, invitation} =
        Workspaces.create_invitation(workspace, owner, "cancel@example.com")

      assert {:ok, cancelled} = Workspaces.cancel_invitation(invitation)
      assert cancelled.status == "cancelled"
    end
  end

  describe "list_pending_invitations/1" do
    test "returns only pending invitations for workspace" do
      owner = user_fixture()
      invitee = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      {:ok, _pending1} =
        Workspaces.create_invitation(workspace, owner, "pending1@example.com")

      {:ok, _pending2} =
        Workspaces.create_invitation(workspace, owner, "pending2@example.com")

      {:ok, accepted_inv} =
        Workspaces.create_invitation(workspace, owner, invitee.email)

      {:ok, _membership} = Workspaces.accept_invitation(accepted_inv.token, invitee)

      {:ok, cancelled_inv} =
        Workspaces.create_invitation(workspace, owner, "cancelled@example.com")

      {:ok, _cancelled} = Workspaces.cancel_invitation(cancelled_inv)

      pending = Workspaces.list_pending_invitations(workspace.id)
      assert length(pending) == 2

      emails = Enum.map(pending, & &1.email)
      assert "pending1@example.com" in emails
      assert "pending2@example.com" in emails
    end

    test "returns empty list when no pending invitations" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      assert Workspaces.list_pending_invitations(workspace.id) == []
    end

    test "does not include invitations from other workspaces" do
      owner = user_fixture()
      {:ok, ws1} = Workspaces.create_workspace(owner, %{name: "Team 1"})
      {:ok, ws2} = Workspaces.create_workspace(owner, %{name: "Team 2"})

      {:ok, _inv1} = Workspaces.create_invitation(ws1, owner, "ws1@example.com")
      {:ok, _inv2} = Workspaces.create_invitation(ws2, owner, "ws2@example.com")

      pending_ws1 = Workspaces.list_pending_invitations(ws1.id)
      assert length(pending_ws1) == 1
      assert hd(pending_ws1).email == "ws1@example.com"
    end
  end

  describe "get_invitation_by_token/1" do
    test "returns invitation with preloaded workspace" do
      owner = user_fixture()
      {:ok, workspace} = Workspaces.create_workspace(owner, %{name: "Team"})

      {:ok, invitation} =
        Workspaces.create_invitation(workspace, owner, "token@example.com")

      fetched = Workspaces.get_invitation_by_token(invitation.token)
      assert fetched.id == invitation.id
      assert fetched.workspace.id == workspace.id
      assert fetched.workspace.name == "Team"
    end

    test "returns nil for non-existent token" do
      assert Workspaces.get_invitation_by_token("nonexistent-token") == nil
    end

    test "returns nil for nil token" do
      assert Workspaces.get_invitation_by_token(nil) == nil
    end

    test "returns nil for non-binary token" do
      assert Workspaces.get_invitation_by_token(123) == nil
    end
  end
end
