defmodule QrLabelSystem.Designs.VersioningTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Designs.Versioning

  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.DesignsFixtures

  setup do
    user = user_fixture()
    design = design_with_elements_fixture(%{user_id: user.id})
    %{user: user, design: design}
  end

  describe "create_snapshot/3" do
    test "creates a version with all design fields", %{design: design, user: user} do
      assert {:ok, version} = Versioning.create_snapshot(design, user.id)

      assert version.design_id == design.id
      assert version.user_id == user.id
      assert version.version_number == 1
      assert version.name == design.name
      assert version.width_mm == design.width_mm
      assert version.height_mm == design.height_mm
      assert version.background_color == design.background_color
      assert version.element_count == length(design.elements)
      assert version.snapshot_hash != nil
    end

    test "increments version_number", %{design: design, user: user} do
      {:ok, v1} = Versioning.create_snapshot(design, user.id)
      assert v1.version_number == 1

      # Change the design so hash differs
      {:ok, updated} = Designs.update_design(design, %{name: "Changed"})
      {:ok, v2} = Versioning.create_snapshot(updated, user.id)
      assert v2.version_number == 2
    end

    test "deduplicates by hash — no version if no changes", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      assert {:duplicate, :no_changes} = Versioning.create_snapshot(design, user.id)
      assert Versioning.version_count(design.id) == 1
    end

    test "stores change_message", %{design: design, user: user} do
      {:ok, version} = Versioning.create_snapshot(design, user.id,
        change_message: "Initial version")
      assert version.change_message == "Initial version"
    end

    test "same content with different change_message deduplicates", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id, change_message: "First")
      assert {:duplicate, :no_changes} = Versioning.create_snapshot(design, user.id, change_message: "Second")
      assert Versioning.version_count(design.id) == 1
    end
  end

  describe "list_versions/2" do
    test "returns versions most recent first", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      {:ok, updated} = Designs.update_design(design, %{name: "V2"})
      {:ok, _v2} = Versioning.create_snapshot(updated, user.id)

      versions = Versioning.list_versions(design.id)
      assert length(versions) == 2
      assert hd(versions).version_number == 2
    end

    test "preloads user", %{design: design, user: user} do
      {:ok, _} = Versioning.create_snapshot(design, user.id)
      [version] = Versioning.list_versions(design.id)
      assert version.user.id == user.id
      assert version.user.email == user.email
    end

    test "returns empty list for design with no versions", %{design: design} do
      assert Versioning.list_versions(design.id) == []
    end
  end

  describe "get_version/2" do
    test "returns specific version", %{design: design, user: user} do
      {:ok, v1} = Versioning.create_snapshot(design, user.id)
      found = Versioning.get_version(design.id, 1)
      assert found.id == v1.id
      assert found.version_number == 1
    end

    test "returns nil for nonexistent version", %{design: design} do
      assert Versioning.get_version(design.id, 999) == nil
    end
  end

  describe "restore_version/3" do
    test "restores design to a previous version's state", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      original_name = design.name

      {:ok, updated} = Designs.update_design(design, %{name: "Modified name"})
      {:ok, _v2} = Versioning.create_snapshot(updated, user.id)

      {:ok, restored} = Versioning.restore_version(updated, 1, user.id)
      assert restored.name == original_name
    end

    test "does not create a new version on restore", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      {:ok, updated} = Designs.update_design(design, %{name: "Modified"})
      {:ok, _v2} = Versioning.create_snapshot(updated, user.id)

      {:ok, _restored} = Versioning.restore_version(updated, 1, user.id)

      # Should still only have 2 versions (no v3 created by restore)
      assert Versioning.version_count(design.id) == 2
      versions = Versioning.list_versions(design.id)
      assert hd(versions).version_number == 2
    end

    test "returns error for nonexistent version", %{design: design, user: user} do
      assert {:error, :version_not_found} = Versioning.restore_version(design, 999, user.id)
    end
  end

  describe "rename_version/3" do
    test "sets custom_name on a version", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      {:ok, updated} = Versioning.rename_version(design.id, 1, "Mi version favorita")
      assert updated.custom_name == "Mi version favorita"
    end

    test "clears custom_name when set to empty string", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      {:ok, _} = Versioning.rename_version(design.id, 1, "Temp name")
      {:ok, updated} = Versioning.rename_version(design.id, 1, "")
      assert updated.custom_name == nil
    end

    test "returns error for nonexistent version", %{design: design} do
      assert {:error, :version_not_found} = Versioning.rename_version(design.id, 999, "Name")
    end

    test "validates max length of 100 characters", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      long_name = String.duplicate("a", 101)
      assert {:error, _changeset} = Versioning.rename_version(design.id, 1, long_name)
    end
  end

  describe "generate_change_summary/2" do
    test "returns 'Version inicial' when no prior versions exist", %{design: design} do
      assert Versioning.generate_change_summary(design) == "Version inicial"
    end

    test "detects field changes vs latest version", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      {:ok, updated} = Designs.update_design(design, %{name: "Nuevo nombre", width_mm: 200.0})

      summary = Versioning.generate_change_summary(updated)
      assert summary =~ "nombre"
      assert summary =~ "ancho"
    end

    test "prepends restore prefix when option given", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      {:ok, updated} = Designs.update_design(design, %{name: "Changed"})

      summary = Versioning.generate_change_summary(updated, restored_from: 1)
      assert summary =~ "Restaurado desde v1"
      assert summary =~ "nombre"
    end

    test "returns 'Sin cambios' when design matches latest version", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      summary = Versioning.generate_change_summary(design)
      assert summary == "Sin cambios"
    end
  end

  describe "diff_against_previous/2" do
    test "returns nil for the first version", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      assert Versioning.diff_against_previous(design.id, 1) == nil
    end

    test "returns diff against previous version", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      {:ok, updated} = Designs.update_design(design, %{name: "New Name"})
      {:ok, _v2} = Versioning.create_snapshot(updated, user.id)

      {:ok, diff} = Versioning.diff_against_previous(design.id, 2)
      assert diff.fields.name == %{from: design.name, to: "New Name"}
    end
  end

  describe "diff_versions/3" do
    test "detects changed scalar fields", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      {:ok, updated} = Designs.update_design(design, %{name: "New Name", width_mm: 100.0})
      {:ok, _v2} = Versioning.create_snapshot(updated, user.id)

      {:ok, diff} = Versioning.diff_versions(design.id, 1, 2)
      assert diff.fields.name == %{from: design.name, to: "New Name"}
      assert diff.fields.width_mm == %{from: design.width_mm, to: 100.0}
    end

    test "detects added elements", %{user: user} do
      design = design_fixture(%{user_id: user.id, elements: []})
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)

      new_elements = [text_element_attrs()]
      {:ok, updated} = Designs.update_design(design, %{elements: new_elements})
      {:ok, _v2} = Versioning.create_snapshot(updated, user.id)

      {:ok, diff} = Versioning.diff_versions(design.id, 1, 2)
      assert length(diff.elements.added) == 1
      assert diff.elements.removed == []
    end

    test "detects removed elements", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)

      {:ok, updated} = Designs.update_design(design, %{elements: []})
      {:ok, _v2} = Versioning.create_snapshot(updated, user.id)

      {:ok, diff} = Versioning.diff_versions(design.id, 1, 2)
      assert length(diff.elements.removed) == 3  # design_with_elements has 3 elements
      assert diff.elements.added == []
    end

    test "returns error for nonexistent version", %{design: design, user: user} do
      {:ok, _v1} = Versioning.create_snapshot(design, user.id)
      assert {:error, :version_not_found} = Versioning.diff_versions(design.id, 1, 999)
    end
  end

  describe "version_count/1" do
    test "returns correct count", %{design: design, user: user} do
      assert Versioning.version_count(design.id) == 0

      {:ok, _} = Versioning.create_snapshot(design, user.id)
      assert Versioning.version_count(design.id) == 1
    end
  end

  describe "cleanup" do
    test "keeps max 50 versions", %{user: user} do
      design = design_fixture(%{user_id: user.id, elements: []})

      # Create 52 versions with distinct names
      for i <- 1..52 do
        {:ok, updated} = Designs.update_design(design, %{name: "Version #{i}"})
        {:ok, _} = Versioning.create_snapshot(updated, user.id)
      end

      # Wait for async cleanup to run
      Process.sleep(100)

      assert Versioning.version_count(design.id) <= 50
    end
  end

  describe "integration with update_design" do
    test "update_design with user_id does not create snapshot", %{design: design, user: user} do
      {:ok, _updated} = Designs.update_design(design, %{name: "No auto snapshot"}, user_id: user.id)
      Process.sleep(100)
      assert Versioning.version_count(design.id) == 0
    end

    test "update_design without user_id does not create snapshot", %{design: design} do
      {:ok, _updated} = Designs.update_design(design, %{name: "No snapshot"})
      Process.sleep(100)
      assert Versioning.version_count(design.id) == 0
    end
  end
end
