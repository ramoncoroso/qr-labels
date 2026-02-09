defmodule QrLabelSystem.SettingsTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.Settings

  setup do
    Settings.clear_cache()
    :ok
  end

  describe "get_setting/1" do
    test "returns nil for non-existent key" do
      assert Settings.get_setting("nonexistent_key") == nil
    end

    test "returns the value of an existing setting" do
      # The migration seeds approval_required = false
      assert Settings.get_setting("approval_required") == "false"
    end
  end

  describe "set_setting/2" do
    test "creates a new setting" do
      assert {:ok, setting} = Settings.set_setting("test_key", "test_value")
      assert setting.key == "test_key"
      assert setting.value == "test_value"
    end

    test "updates an existing setting" do
      Settings.set_setting("test_key2", "original")
      assert {:ok, setting} = Settings.set_setting("test_key2", "updated")
      assert setting.value == "updated"
    end

    test "value is cached after set" do
      Settings.set_setting("cached_key", "cached_value")
      assert Settings.get_setting("cached_key") == "cached_value"
    end
  end

  describe "approval_required?/0" do
    test "returns false by default" do
      refute Settings.approval_required?()
    end

    test "returns true when set to true" do
      Settings.set_setting("approval_required", "true")
      assert Settings.approval_required?()
    end

    test "returns false when set to false" do
      Settings.set_setting("approval_required", "false")
      refute Settings.approval_required?()
    end
  end
end
