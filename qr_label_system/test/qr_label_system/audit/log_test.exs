defmodule QrLabelSystem.Audit.LogTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.Audit.Log

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{action: "login", resource_type: "user"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "invalid without action" do
      attrs = %{resource_type: "user"}
      changeset = Log.changeset(%Log{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).action
    end

    test "invalid without resource_type" do
      attrs = %{action: "login"}
      changeset = Log.changeset(%Log{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).resource_type
    end

    test "validates action inclusion - login" do
      attrs = %{action: "login", resource_type: "user"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - logout" do
      attrs = %{action: "logout", resource_type: "user"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - create_design" do
      attrs = %{action: "create_design", resource_type: "design"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - update_design" do
      attrs = %{action: "update_design", resource_type: "design"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - delete_design" do
      attrs = %{action: "delete_design", resource_type: "design"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - export_design" do
      attrs = %{action: "export_design", resource_type: "design"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - import_design" do
      attrs = %{action: "import_design", resource_type: "design"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - create_data_source" do
      attrs = %{action: "create_data_source", resource_type: "data_source"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - update_data_source" do
      attrs = %{action: "update_data_source", resource_type: "data_source"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - delete_data_source" do
      attrs = %{action: "delete_data_source", resource_type: "data_source"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - test_connection" do
      attrs = %{action: "test_connection", resource_type: "data_source"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - create_batch" do
      attrs = %{action: "create_batch", resource_type: "batch"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - update_batch" do
      attrs = %{action: "update_batch", resource_type: "batch"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - delete_batch" do
      attrs = %{action: "delete_batch", resource_type: "batch"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - print_batch" do
      attrs = %{action: "print_batch", resource_type: "batch"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - export_pdf" do
      attrs = %{action: "export_pdf", resource_type: "batch"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - create_user" do
      attrs = %{action: "create_user", resource_type: "user"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - update_user" do
      attrs = %{action: "update_user", resource_type: "user"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - delete_user" do
      attrs = %{action: "delete_user", resource_type: "user"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "validates action inclusion - update_role" do
      attrs = %{action: "update_role", resource_type: "user"}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "rejects invalid action" do
      attrs = %{action: "invalid_action", resource_type: "user"}
      changeset = Log.changeset(%Log{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).action
    end

    test "accepts optional fields" do
      attrs = %{
        action: "login",
        resource_type: "user",
        resource_id: 123,
        user_id: 456,
        metadata: %{browser: "Chrome"},
        ip_address: "192.168.1.1",
        user_agent: "Mozilla/5.0"
      }
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "accepts nil resource_id" do
      attrs = %{action: "logout", resource_type: "session", resource_id: nil}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end

    test "accepts empty metadata" do
      attrs = %{action: "login", resource_type: "user", metadata: %{}}
      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end
  end

  describe "actions/0" do
    test "returns all valid actions" do
      actions = Log.actions()

      assert "login" in actions
      assert "logout" in actions
      assert "create_design" in actions
      assert "update_design" in actions
      assert "delete_design" in actions
      assert "export_design" in actions
      assert "import_design" in actions
      assert "create_data_source" in actions
      assert "update_data_source" in actions
      assert "delete_data_source" in actions
      assert "test_connection" in actions
      assert "create_batch" in actions
      assert "update_batch" in actions
      assert "delete_batch" in actions
      assert "print_batch" in actions
      assert "export_pdf" in actions
      assert "create_user" in actions
      assert "update_user" in actions
      assert "delete_user" in actions
      assert "update_role" in actions
    end

    test "returns a list" do
      assert is_list(Log.actions())
    end
  end
end
