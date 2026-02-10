defmodule QrLabelSystem.Designs.ApprovalWorkflowTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Designs.Design

  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.DesignsFixtures

  describe "Design status field" do
    test "new designs default to draft" do
      user = user_fixture()
      design = design_fixture(%{user_id: user.id})
      assert design.status == "draft"
    end

    test "validates status inclusion" do
      changeset = Design.changeset(%Design{}, %{
        name: "Test",
        width_mm: 50.0,
        height_mm: 30.0,
        status: "invalid_status"
      })

      refute changeset.valid?
      assert "must be draft, pending_review, approved, or archived" in errors_on(changeset).status
    end

    test "status_changeset updates status" do
      changeset = Design.status_changeset(%Design{status: "draft"}, "pending_review")
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :status) == "pending_review"
    end
  end

  describe "Design helpers" do
    test "approved?/1" do
      assert Design.approved?(%Design{status: "approved"})
      refute Design.approved?(%Design{status: "draft"})
      refute Design.approved?(%Design{status: "pending_review"})
    end

    test "editable?/1" do
      assert Design.editable?(%Design{status: "draft"})
      assert Design.editable?(%Design{status: "pending_review"})
      refute Design.editable?(%Design{status: "approved"})
      refute Design.editable?(%Design{status: "archived"})
    end

    test "printable?/1" do
      assert Design.printable?(%Design{status: "draft"})
      assert Design.printable?(%Design{status: "approved"})
      refute Design.printable?(%Design{status: "pending_review"})
      refute Design.printable?(%Design{status: "archived"})
    end
  end

  describe "request_review/2" do
    test "owner can send draft to pending_review" do
      user = user_fixture()
      design = design_fixture(%{user_id: user.id})

      assert {:ok, updated} = Designs.request_review(design, user)
      assert updated.status == "pending_review"
    end

    test "non-owner cannot send to review" do
      owner = user_fixture()
      other = user_fixture()
      design = design_fixture(%{user_id: owner.id})

      assert {:error, "Solo el propietario puede enviar a revision"} =
               Designs.request_review(design, other)
    end

    test "cannot send already pending design to review" do
      user = user_fixture()
      design = design_fixture(%{user_id: user.id})
      {:ok, pending} = Designs.request_review(design, user)

      assert {:error, _} = Designs.request_review(pending, user)
    end

    test "creates approval record" do
      user = user_fixture()
      design = design_fixture(%{user_id: user.id})
      {:ok, _updated} = Designs.request_review(design, user)

      history = Designs.get_approval_history(design.id)
      assert length(history) == 1
      assert hd(history).action == "request_review"
      assert hd(history).user_id == user.id
    end
  end

  describe "approve_design/3" do
    test "admin can approve pending design" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)

      assert {:ok, approved} = Designs.approve_design(pending, admin, "LGTM")
      assert approved.status == "approved"
    end

    test "non-admin cannot approve" do
      owner = user_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)

      assert {:error, "Solo administradores pueden aprobar disenos"} =
               Designs.approve_design(pending, owner, nil)
    end

    test "cannot approve draft design" do
      admin = admin_fixture()
      design = design_fixture(%{user_id: admin.id})

      assert {:error, _} = Designs.approve_design(design, admin, nil)
    end

    test "creates approval record with comment" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, _approved} = Designs.approve_design(pending, admin, "Approved!")

      history = Designs.get_approval_history(design.id)
      approve_record = Enum.find(history, &(&1.action == "approve"))
      assert approve_record
      assert approve_record.user_id == admin.id
      assert approve_record.comment != nil
    end
  end

  describe "reject_design/3" do
    test "admin can reject pending design" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)

      assert {:ok, rejected} = Designs.reject_design(pending, admin, "Needs changes")
      assert rejected.status == "draft"
    end

    test "non-admin cannot reject" do
      owner = user_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)

      assert {:error, "Solo administradores pueden rechazar disenos"} =
               Designs.reject_design(pending, owner, "Bad")
    end

    test "creates rejection record" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, _rejected} = Designs.reject_design(pending, admin, "Fix spacing")

      history = Designs.get_approval_history(design.id)
      reject_record = Enum.find(history, &(&1.action == "reject"))
      assert reject_record
      assert reject_record.comment != nil
    end
  end

  describe "archive_design/2" do
    test "can archive approved design" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, approved} = Designs.approve_design(pending, admin)

      assert {:ok, archived} = Designs.archive_design(approved, owner)
      assert archived.status == "archived"
    end

    test "cannot archive draft design" do
      user = user_fixture()
      design = design_fixture(%{user_id: user.id})

      assert {:error, _} = Designs.archive_design(design, user)
    end
  end

  describe "reactivate_design/2" do
    test "can reactivate archived design" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, approved} = Designs.approve_design(pending, admin)
      {:ok, archived} = Designs.archive_design(approved, owner)

      assert {:ok, reactivated} = Designs.reactivate_design(archived, owner)
      assert reactivated.status == "draft"
    end
  end

  describe "auto-revert on edit" do
    test "editing an approved design reverts it to draft" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, approved} = Designs.approve_design(pending, admin)

      assert approved.status == "approved"

      {:ok, edited} = Designs.update_design(approved, %{name: "New Name"})
      assert edited.status == "draft"
    end

    test "status-only updates do not revert" do
      owner = user_fixture()
      design = design_fixture(%{user_id: owner.id})

      {:ok, updated} = Designs.update_design_status(design, "pending_review", owner)
      assert updated.status == "pending_review"
    end
  end

  describe "list_pending_approvals/0" do
    test "returns only pending_review designs" do
      owner = user_fixture()
      _draft = design_fixture(%{user_id: owner.id})
      pending_design = design_fixture(%{user_id: owner.id})
      {:ok, _pending} = Designs.request_review(pending_design, owner)

      pending = Designs.list_pending_approvals()
      assert length(pending) == 1
      assert hd(pending).id == pending_design.id
    end
  end

  describe "count_pending_approvals/0" do
    test "counts pending designs" do
      owner = user_fixture()
      design1 = design_fixture(%{user_id: owner.id})
      design2 = design_fixture(%{user_id: owner.id})
      _draft = design_fixture(%{user_id: owner.id})

      {:ok, _} = Designs.request_review(design1, owner)
      {:ok, _} = Designs.request_review(design2, owner)

      assert Designs.count_pending_approvals() == 2
    end
  end

  describe "get_approval_history/1" do
    test "returns full approval trail" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})

      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, _rejected} = Designs.reject_design(pending, admin, "Fix it")

      # Re-fetch to get latest status
      design = Designs.get_design!(design.id)
      {:ok, pending2} = Designs.request_review(design, owner)
      {:ok, _approved} = Designs.approve_design(pending2, admin, "OK now")

      history = Designs.get_approval_history(design.id)
      assert length(history) == 4

      actions = Enum.map(history, & &1.action)
      # Most recent first
      assert "approve" in actions
      assert "request_review" in actions
      assert "reject" in actions
    end
  end

  describe "invalid transitions" do
    test "cannot go from draft to approved directly" do
      admin = admin_fixture()
      design = design_fixture(%{user_id: admin.id})

      assert {:error, _} = Designs.update_design_status(design, "approved", admin)
    end

    test "cannot go from pending_review to archived" do
      owner = user_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)

      assert {:error, _} = Designs.update_design_status(pending, "archived", owner)
    end
  end

  describe "list_user_designs_by_status/2" do
    test "filters designs by status" do
      owner = user_fixture()
      _draft1 = design_fixture(%{user_id: owner.id})
      pending_design = design_fixture(%{user_id: owner.id})
      {:ok, _} = Designs.request_review(pending_design, owner)

      drafts = Designs.list_user_designs_by_status(owner.id, "draft")
      assert length(drafts) == 1

      pendings = Designs.list_user_designs_by_status(owner.id, "pending_review")
      assert length(pendings) == 1
      assert hd(pendings).id == pending_design.id
    end
  end

  describe "sanitize_comment/1" do
    test "comments are trimmed and truncated, HTML stored raw (escaped by HEEx at render)" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, _} = Designs.approve_design(pending, admin, "  <script>alert('xss')</script>  ")

      history = Designs.get_approval_history(design.id)
      approve_record = Enum.find(history, &(&1.action == "approve"))
      # Stored trimmed but not HTML-escaped (HEEx auto-escapes on render)
      assert approve_record.comment == "<script>alert('xss')</script>"
    end

    test "comments are truncated to 1000 chars" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      long_comment = String.duplicate("a", 1500)
      {:ok, _} = Designs.approve_design(pending, admin, long_comment)

      history = Designs.get_approval_history(design.id)
      approve_record = Enum.find(history, &(&1.action == "approve"))
      assert String.length(approve_record.comment) == 1000
    end
  end

  describe "revert_status option" do
    test "revert_status: false prevents auto-revert on approved design" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, approved} = Designs.approve_design(pending, admin)

      # With revert_status: false, editing should NOT revert
      {:ok, edited} = Designs.update_design(approved, %{name: "New Name"}, revert_status: false)
      assert edited.status == "approved"
    end

    test "revert_status: true (default) reverts approved design on content edit" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, approved} = Designs.approve_design(pending, admin)

      {:ok, edited} = Designs.update_design(approved, %{name: "New Name"})
      assert edited.status == "draft"
    end
  end

  describe "pending_review auto-revert on edit" do
    test "editing a pending_review design reverts it to draft" do
      owner = user_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)

      assert pending.status == "pending_review"

      {:ok, edited} = Designs.update_design(pending, %{name: "Changed"})
      assert edited.status == "draft"
    end

    test "revert_status: false prevents pending_review auto-revert" do
      owner = user_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)

      {:ok, edited} = Designs.update_design(pending, %{name: "Changed"}, revert_status: false)
      assert edited.status == "pending_review"
    end
  end

  describe "archive/reactivate ownership" do
    test "owner can archive own approved design" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, approved} = Designs.approve_design(pending, admin)

      assert {:ok, archived} = Designs.archive_design(approved, owner)
      assert archived.status == "archived"
    end

    test "admin can archive any approved design" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, approved} = Designs.approve_design(pending, admin)

      assert {:ok, archived} = Designs.archive_design(approved, admin)
      assert archived.status == "archived"
    end

    test "non-owner non-admin cannot archive design" do
      owner = user_fixture()
      other = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, approved} = Designs.approve_design(pending, admin)

      assert {:error, _} = Designs.archive_design(approved, other)
    end

    test "owner can reactivate own archived design" do
      owner = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, approved} = Designs.approve_design(pending, admin)
      {:ok, archived} = Designs.archive_design(approved, owner)

      assert {:ok, reactivated} = Designs.reactivate_design(archived, owner)
      assert reactivated.status == "draft"
    end

    test "non-owner non-admin cannot reactivate design" do
      owner = user_fixture()
      other = user_fixture()
      admin = admin_fixture()
      design = design_fixture(%{user_id: owner.id})
      {:ok, pending} = Designs.request_review(design, owner)
      {:ok, approved} = Designs.approve_design(pending, admin)
      {:ok, archived} = Designs.archive_design(approved, owner)

      assert {:error, _} = Designs.reactivate_design(archived, other)
    end
  end
end
