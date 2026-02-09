defmodule QrLabelSystem.Designs.DesignApprovalTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.Designs.DesignApproval

  describe "changeset/2" do
    test "valid changeset with all fields" do
      changeset = DesignApproval.changeset(%DesignApproval{}, %{
        design_id: 1,
        user_id: 1,
        action: "approve",
        comment: "Looks good"
      })

      assert changeset.valid?
    end

    test "requires design_id, user_id, action" do
      changeset = DesignApproval.changeset(%DesignApproval{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).design_id
      assert "can't be blank" in errors_on(changeset).user_id
      assert "can't be blank" in errors_on(changeset).action
    end

    test "validates action inclusion" do
      changeset = DesignApproval.changeset(%DesignApproval{}, %{
        design_id: 1,
        user_id: 1,
        action: "invalid"
      })

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).action
    end

    test "validates comment max length" do
      changeset = DesignApproval.changeset(%DesignApproval{}, %{
        design_id: 1,
        user_id: 1,
        action: "approve",
        comment: String.duplicate("a", 1001)
      })

      refute changeset.valid?
    end

    test "accepts all valid actions" do
      for action <- ~w(request_review approve reject) do
        changeset = DesignApproval.changeset(%DesignApproval{}, %{
          design_id: 1,
          user_id: 1,
          action: action
        })

        assert changeset.valid?, "Expected #{action} to be valid"
      end
    end
  end
end
