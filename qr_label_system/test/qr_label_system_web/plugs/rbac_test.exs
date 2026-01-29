defmodule QrLabelSystemWeb.Plugs.RBACTest do
  use QrLabelSystemWeb.ConnCase

  alias QrLabelSystem.Accounts.User

  describe "User role predicates" do
    test "admin?/1 correctly identifies admin users" do
      admin = %User{role: "admin"}
      operator = %User{role: "operator"}
      viewer = %User{role: "viewer"}

      assert User.admin?(admin)
      refute User.admin?(operator)
      refute User.admin?(viewer)
      refute User.admin?(nil)
    end

    test "operator?/1 returns true for admin and operator" do
      admin = %User{role: "admin"}
      operator = %User{role: "operator"}
      viewer = %User{role: "viewer"}

      assert User.operator?(admin)
      assert User.operator?(operator)
      refute User.operator?(viewer)
      refute User.operator?(nil)
    end

    test "viewer?/1 returns true for any authenticated user" do
      admin = %User{role: "admin"}
      operator = %User{role: "operator"}
      viewer = %User{role: "viewer"}

      assert User.viewer?(admin)
      assert User.viewer?(operator)
      assert User.viewer?(viewer)
      refute User.viewer?(nil)
    end
  end

  describe "User.roles/0" do
    test "returns all available roles" do
      roles = User.roles()
      assert "admin" in roles
      assert "operator" in roles
      assert "viewer" in roles
      assert length(roles) == 3
    end
  end
end
