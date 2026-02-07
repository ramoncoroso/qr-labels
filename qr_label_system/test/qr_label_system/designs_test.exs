defmodule QrLabelSystem.DesignsTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Designs.Design

  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.DesignsFixtures

  describe "list_designs/0" do
    test "returns all designs" do
      design1 = design_fixture()
      design2 = design_fixture()

      designs = Designs.list_designs()
      assert length(designs) == 2
      # Both designs should be in the list (order may vary due to timestamp ties)
      design_ids = Enum.map(designs, & &1.id)
      assert design1.id in design_ids
      assert design2.id in design_ids
    end

    test "returns empty list when no designs exist" do
      assert Designs.list_designs() == []
    end
  end

  describe "list_user_designs/1" do
    test "returns designs for a specific user" do
      user = user_fixture()
      other_user = user_fixture()

      design1 = design_fixture(%{user_id: user.id})
      _design2 = design_fixture(%{user_id: other_user.id})

      designs = Designs.list_user_designs(user.id)
      assert length(designs) == 1
      assert hd(designs).id == design1.id
    end

    test "returns empty list when user has no designs" do
      user = user_fixture()
      assert Designs.list_user_designs(user.id) == []
    end
  end

  describe "list_user_designs_by_type/2" do
    test "returns designs filtered by label type" do
      user = user_fixture()
      design1 = design_fixture(%{user_id: user.id, label_type: "single"})
      _design2 = design_fixture(%{user_id: user.id, label_type: "multiple"})

      designs = Designs.list_user_designs_by_type(user.id, "single")
      assert length(designs) == 1
      assert hd(designs).id == design1.id
    end

    test "returns empty list when no matching designs" do
      user = user_fixture()
      design_fixture(%{user_id: user.id, label_type: "multiple"})

      assert Designs.list_user_designs_by_type(user.id, "single") == []
    end
  end

  describe "list_templates/0" do
    test "returns only template designs" do
      _regular = design_fixture(%{is_template: false})
      template = design_fixture(%{is_template: true})

      templates = Designs.list_templates()
      assert length(templates) == 1
      assert hd(templates).id == template.id
    end

    test "orders templates by name" do
      design_fixture(%{is_template: true, name: "Zebra Template"})
      design_fixture(%{is_template: true, name: "Alpha Template"})

      templates = Designs.list_templates()
      assert hd(templates).name == "Alpha Template"
    end
  end

  describe "list_designs/1 with pagination" do
    test "paginates results" do
      user = user_fixture()
      for _ <- 1..25, do: design_fixture(%{user_id: user.id})

      result = Designs.list_designs(%{"page" => "1", "per_page" => "10", "user_id" => user.id})

      assert length(result.designs) == 10
      assert result.page == 1
      assert result.per_page == 10
      assert result.total == 25
      assert result.total_pages == 3
    end

    test "applies search filter" do
      user = user_fixture()
      design_fixture(%{user_id: user.id, name: "Product Label"})
      design_fixture(%{user_id: user.id, name: "Shipping Label"})
      design_fixture(%{user_id: user.id, name: "Barcode Design"})

      result = Designs.list_designs(%{"user_id" => user.id, "search" => "Label"})
      assert result.total == 2
    end

    test "search filter is case insensitive" do
      user = user_fixture()
      design_fixture(%{user_id: user.id, name: "Product LABEL"})

      result = Designs.list_designs(%{"user_id" => user.id, "search" => "label"})
      assert result.total == 1
    end

    test "sanitizes LIKE special characters in search" do
      user = user_fixture()
      design_fixture(%{user_id: user.id, name: "100% Complete"})

      result = Designs.list_designs(%{"user_id" => user.id, "search" => "100%"})
      assert result.total == 1
    end

    test "uses default values for missing params" do
      result = Designs.list_designs(%{})
      assert result.page == 1
      assert result.per_page == 20
    end

    test "handles invalid page number gracefully" do
      result = Designs.list_designs(%{"page" => "invalid"})
      assert result.page == 1
    end

    test "includes templates for user filter" do
      user = user_fixture()
      design_fixture(%{user_id: user.id})
      design_fixture(%{is_template: true})

      result = Designs.list_designs(%{"user_id" => user.id})
      assert result.total == 2
    end
  end

  describe "get_design!/1" do
    test "returns the design with given id" do
      design = design_fixture()
      assert Designs.get_design!(design.id).id == design.id
    end

    test "raises Ecto.NoResultsError if design does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Designs.get_design!(0)
      end
    end

    test "uses cache for subsequent calls" do
      design = design_fixture()

      # First call - cache miss
      result1 = Designs.get_design!(design.id)
      # Second call - should use cache
      result2 = Designs.get_design!(design.id)

      assert result1.id == result2.id
    end
  end

  describe "get_design/1" do
    test "returns the design with given id" do
      design = design_fixture()
      assert Designs.get_design(design.id).id == design.id
    end

    test "returns nil if design does not exist" do
      assert Designs.get_design(0) == nil
    end
  end

  describe "create_design/1" do
    test "creates a design with valid data" do
      user = user_fixture()
      attrs = valid_design_attributes(%{user_id: user.id})

      assert {:ok, %Design{} = design} = Designs.create_design(attrs)
      assert design.name == attrs.name
      assert design.width_mm == attrs.width_mm
      assert design.height_mm == attrs.height_mm
    end

    test "returns error changeset with invalid data" do
      assert {:error, %Ecto.Changeset{}} = Designs.create_design(%{})
    end

    test "validates required fields" do
      assert {:error, changeset} = Designs.create_design(%{})
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).width_mm
      assert "can't be blank" in errors_on(changeset).height_mm
    end

    test "validates dimension constraints" do
      attrs = valid_design_attributes(%{width_mm: 0, height_mm: 600})

      assert {:error, changeset} = Designs.create_design(attrs)
      assert "must be greater than 0" in errors_on(changeset).width_mm
      assert "must be less than or equal to 500" in errors_on(changeset).height_mm
    end

    test "validates color format" do
      attrs = valid_design_attributes(%{background_color: "invalid"})

      assert {:error, changeset} = Designs.create_design(attrs)
      assert "must be a valid hex color (e.g., #FFFFFF)" in errors_on(changeset).background_color
    end

    test "accepts valid hex colors" do
      attrs = valid_design_attributes(%{background_color: "#FF5500"})

      assert {:ok, design} = Designs.create_design(attrs)
      assert design.background_color == "#FF5500"
    end

    test "creates design with embedded elements" do
      attrs = valid_design_attributes(%{
        elements: [
          %{id: "el_1", type: "qr", x: 10, y: 10, width: 20, height: 20},
          %{id: "el_2", type: "text", x: 35, y: 10, width: 50, height: 10, text_content: "Hello"}
        ]
      })

      assert {:ok, design} = Designs.create_design(attrs)
      assert length(design.elements) == 2
    end
  end

  describe "update_design/2" do
    test "updates design with valid data" do
      design = design_fixture()
      attrs = %{name: "Updated Name"}

      assert {:ok, updated} = Designs.update_design(design, attrs)
      assert updated.name == "Updated Name"
    end

    test "returns error changeset with invalid data" do
      design = design_fixture()
      attrs = %{width_mm: -1}

      assert {:error, %Ecto.Changeset{}} = Designs.update_design(design, attrs)
    end

    test "invalidates cache on update" do
      design = design_fixture()

      # Put in cache
      Designs.get_design!(design.id)

      # Update
      {:ok, updated} = Designs.update_design(design, %{name: "New Name"})

      # Should get updated version
      assert Designs.get_design!(design.id).name == "New Name"
      assert updated.name == "New Name"
    end
  end

  describe "delete_design/1" do
    test "deletes the design" do
      design = design_fixture()
      assert {:ok, %Design{}} = Designs.delete_design(design)
      assert_raise Ecto.NoResultsError, fn -> Designs.get_design!(design.id) end
    end

    test "invalidates cache on delete" do
      design = design_fixture()

      # Put in cache
      Designs.get_design!(design.id)

      # Delete
      {:ok, _} = Designs.delete_design(design)

      # Cache should be cleared
      assert_raise Ecto.NoResultsError, fn -> Designs.get_design!(design.id) end
    end
  end

  describe "change_design/2" do
    test "returns a changeset" do
      design = design_fixture()
      assert %Ecto.Changeset{} = Designs.change_design(design)
    end
  end

  describe "duplicate_design/2" do
    test "duplicates a design with auto-generated name" do
      user = user_fixture()
      design = design_fixture(%{user_id: user.id, name: "Original"})

      assert {:ok, duplicate} = Designs.duplicate_design(design, user.id)
      assert duplicate.name == "Original (copia)"
      assert duplicate.id != design.id
      assert duplicate.user_id == user.id
    end

    test "copies all properties except is_template" do
      user = user_fixture()
      design = design_fixture(%{
        user_id: user.id,
        is_template: true,
        width_mm: 100.0,
        height_mm: 50.0,
        background_color: "#FF0000"
      })

      assert {:ok, duplicate} = Designs.duplicate_design(design, user.id)
      assert duplicate.width_mm == 100.0
      assert duplicate.height_mm == 50.0
      assert duplicate.background_color == "#FF0000"
      assert duplicate.is_template == false
    end
  end

  describe "duplicate_design/3" do
    test "duplicates a design with custom name" do
      user = user_fixture()
      design = design_fixture(%{user_id: user.id})

      assert {:ok, duplicate} = Designs.duplicate_design(design, "Custom Name", user.id)
      assert duplicate.name == "Custom Name"
    end
  end

  describe "list_system_templates/0" do
    test "returns only system templates" do
      _regular = design_fixture()
      _user_template = template_fixture()
      system = system_template_fixture(%{name: "System Template"})

      templates = Designs.list_system_templates()
      assert length(templates) == 1
      assert hd(templates).id == system.id
    end

    test "orders system templates by name" do
      system_template_fixture(%{name: "Zebra System"})
      system_template_fixture(%{name: "Alpha System"})

      templates = Designs.list_system_templates()
      assert length(templates) == 2
      assert hd(templates).name == "Alpha System"
    end

    test "returns empty list when no system templates exist" do
      _regular = design_fixture()
      _user_template = template_fixture()

      assert Designs.list_system_templates() == []
    end
  end

  describe "template_source and template_category validation" do
    test "accepts valid template_source values" do
      attrs = valid_design_attributes(%{template_source: "system"})
      assert {:ok, design} = Designs.create_design(attrs)
      assert design.template_source == "system"

      attrs = valid_design_attributes(%{template_source: "user"})
      assert {:ok, design} = Designs.create_design(attrs)
      assert design.template_source == "user"
    end

    test "rejects invalid template_source values" do
      attrs = valid_design_attributes(%{template_source: "invalid"})
      assert {:error, changeset} = Designs.create_design(attrs)
      assert "must be system or user" in errors_on(changeset).template_source
    end

    test "accepts valid template_category values" do
      for category <- ~w(alimentacion farmaceutica logistica manufactura retail) do
        attrs = valid_design_attributes(%{template_category: category})
        assert {:ok, design} = Designs.create_design(attrs)
        assert design.template_category == category
      end
    end

    test "rejects invalid template_category values" do
      attrs = valid_design_attributes(%{template_category: "invalid"})
      assert {:error, changeset} = Designs.create_design(attrs)
      assert "must be a valid category" in errors_on(changeset).template_category
    end
  end

  describe "duplicate_design with system template" do
    test "resets template_source and template_category on duplicate" do
      user = user_fixture()

      template =
        system_template_fixture(%{
          user_id: user.id,
          name: "System Original",
          template_category: "farmaceutica"
        })

      assert {:ok, duplicate} = Designs.duplicate_design(template, user.id)
      assert duplicate.is_template == false
      assert duplicate.template_source == nil
      assert duplicate.template_category == nil
      assert duplicate.name == "System Original (copia)"
    end

    test "preserves design properties when duplicating system template" do
      user = user_fixture()

      template =
        system_template_fixture(%{
          user_id: user.id,
          width_mm: 100.0,
          height_mm: 60.0,
          background_color: "#FFCC00",
          template_category: "alimentacion",
          elements: [
            %{id: "el_1", type: "qr", x: 5, y: 5, width: 15, height: 15},
            %{id: "el_2", type: "text", x: 25, y: 5, width: 40, height: 8, text_content: "Test"}
          ]
        })

      assert {:ok, duplicate} = Designs.duplicate_design(template, user.id)
      assert duplicate.width_mm == 100.0
      assert duplicate.height_mm == 60.0
      assert duplicate.background_color == "#FFCC00"
      assert length(duplicate.elements) == 2
    end
  end

  describe "export_design/1" do
    test "exports design to a map with version info" do
      design = design_fixture(%{
        name: "Test Design",
        width_mm: 100.0,
        height_mm: 50.0
      })

      export = Designs.export_design(design)

      assert export.version == "1.0"
      assert export.exported_at != nil
      assert export.design.name == "Test Design"
      assert export.design.width_mm == 100.0
      assert export.design.height_mm == 50.0
    end

    test "includes elements in export" do
      design = design_fixture(%{
        elements: [
          %{id: "el_1", type: "qr", x: 10, y: 10, width: 20, height: 20}
        ]
      })

      export = Designs.export_design(design)
      assert length(export.design.elements) == 1
      assert hd(export.design.elements).type == "qr"
    end
  end

  describe "export_design_to_json/1" do
    test "exports design to JSON string" do
      design = design_fixture(%{name: "JSON Test"})

      json = Designs.export_design_to_json(design)

      assert is_binary(json)
      assert {:ok, parsed} = Jason.decode(json)
      assert parsed["design"]["name"] == "JSON Test"
    end
  end

  describe "import_design/2" do
    test "imports design from JSON string" do
      user = user_fixture()
      json = ~s({"version": "1.0", "design": {"name": "Imported", "width_mm": 100, "height_mm": 50}})

      assert {:ok, design} = Designs.import_design(json, user.id)
      assert design.name == "Imported"
      assert design.width_mm == 100
      assert design.height_mm == 50
      assert design.user_id == user.id
    end

    test "imports design from map" do
      user = user_fixture()
      data = %{
        "version" => "1.0",
        "design" => %{
          "name" => "Map Import",
          "width_mm" => 80,
          "height_mm" => 40
        }
      }

      assert {:ok, design} = Designs.import_design(data, user.id)
      assert design.name == "Map Import"
    end

    test "imports design with elements" do
      user = user_fixture()
      data = %{
        "design" => %{
          "name" => "With Elements",
          "width_mm" => 100,
          "height_mm" => 50,
          "elements" => [
            %{"type" => "qr", "x" => 10, "y" => 10, "width" => 20, "height" => 20}
          ]
        }
      }

      assert {:ok, design} = Designs.import_design(data, user.id)
      assert length(design.elements) == 1
    end

    test "returns error for invalid JSON" do
      user = user_fixture()
      assert {:error, "Invalid JSON format"} = Designs.import_design("not json", user.id)
    end

    test "returns error for unsupported version" do
      user = user_fixture()
      data = %{"version" => "999.0", "design" => %{}}

      assert {:error, "Unsupported design version: 999.0"} = Designs.import_design(data, user.id)
    end

    test "handles design at root level" do
      user = user_fixture()
      data = %{
        "name" => "Root Level",
        "width_mm" => 100,
        "height_mm" => 50
      }

      assert {:ok, design} = Designs.import_design(data, user.id)
      assert design.name == "Root Level"
    end

    test "returns error for invalid format" do
      user = user_fixture()
      assert {:error, "Invalid design format"} = Designs.import_design(123, user.id)
    end
  end

  describe "export_all_designs_to_json/1" do
    test "exports multiple designs to backup JSON" do
      user = user_fixture()
      designs = [
        design_fixture(%{user_id: user.id, name: "Design 1"}),
        design_fixture(%{user_id: user.id, name: "Design 2"})
      ]

      json = Designs.export_all_designs_to_json(designs)

      assert is_binary(json)
      assert {:ok, parsed} = Jason.decode(json)
      assert parsed["type"] == "backup"
      assert parsed["count"] == 2
      assert length(parsed["designs"]) == 2
    end
  end

  describe "import_designs_from_json/2" do
    test "imports backup with multiple designs" do
      user = user_fixture()
      json = Jason.encode!(%{
        "type" => "backup",
        "version" => "1.0",
        "designs" => [
          %{"name" => "Backup 1", "width_mm" => 100, "height_mm" => 50},
          %{"name" => "Backup 2", "width_mm" => 80, "height_mm" => 40}
        ]
      })

      assert {:ok, designs} = Designs.import_designs_from_json(json, user.id)
      assert length(designs) == 2
      assert Enum.map(designs, & &1.name) == ["Backup 1", "Backup 2"]
    end

    test "imports single design export format" do
      user = user_fixture()
      json = Jason.encode!(%{
        "design" => %{"name" => "Single", "width_mm" => 100, "height_mm" => 50}
      })

      assert {:ok, [design]} = Designs.import_designs_from_json(json, user.id)
      assert design.name == "Single"
    end

    test "returns error for invalid JSON" do
      user = user_fixture()
      assert {:error, "JSON inválido"} = Designs.import_designs_from_json("not json", user.id)
    end

    test "returns error for unrecognized format" do
      user = user_fixture()
      json = Jason.encode!(%{"unknown" => "format"})

      assert {:error, "Formato de archivo no reconocido"} = Designs.import_designs_from_json(json, user.id)
    end
  end
end
