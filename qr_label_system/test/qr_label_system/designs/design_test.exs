defmodule QrLabelSystem.Designs.DesignTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.Designs.Design

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        name: "Test Design",
        width_mm: 100.0,
        height_mm: 50.0
      }

      changeset = Design.changeset(%Design{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset without name" do
      attrs = %{width_mm: 100.0, height_mm: 50.0}
      changeset = Design.changeset(%Design{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "invalid changeset without dimensions" do
      attrs = %{name: "Test"}
      changeset = Design.changeset(%Design{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).width_mm
      assert "can't be blank" in errors_on(changeset).height_mm
    end

    test "validates width_mm is greater than 0" do
      attrs = %{name: "Test", width_mm: 0, height_mm: 50.0}
      changeset = Design.changeset(%Design{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).width_mm
    end

    test "validates width_mm is less than or equal to 500" do
      attrs = %{name: "Test", width_mm: 501.0, height_mm: 50.0}
      changeset = Design.changeset(%Design{}, attrs)
      refute changeset.valid?
      assert "must be less than or equal to 500" in errors_on(changeset).width_mm
    end

    test "validates height_mm is greater than 0" do
      attrs = %{name: "Test", width_mm: 100.0, height_mm: -10}
      changeset = Design.changeset(%Design{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).height_mm
    end

    test "validates height_mm is less than or equal to 500" do
      attrs = %{name: "Test", width_mm: 100.0, height_mm: 600}
      changeset = Design.changeset(%Design{}, attrs)
      refute changeset.valid?
      assert "must be less than or equal to 500" in errors_on(changeset).height_mm
    end

    test "validates border_width is not negative" do
      attrs = %{name: "Test", width_mm: 100.0, height_mm: 50.0, border_width: -1}
      changeset = Design.changeset(%Design{}, attrs)
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).border_width
    end

    test "validates border_radius is not negative" do
      attrs = %{name: "Test", width_mm: 100.0, height_mm: 50.0, border_radius: -5}
      changeset = Design.changeset(%Design{}, attrs)
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).border_radius
    end

    test "validates background_color format - valid" do
      attrs = %{name: "Test", width_mm: 100.0, height_mm: 50.0, background_color: "#AABBCC"}
      changeset = Design.changeset(%Design{}, attrs)
      assert changeset.valid?
    end

    test "validates background_color format - lowercase valid" do
      attrs = %{name: "Test", width_mm: 100.0, height_mm: 50.0, background_color: "#aabbcc"}
      changeset = Design.changeset(%Design{}, attrs)
      assert changeset.valid?
    end

    test "validates background_color format - invalid without hash" do
      attrs = %{name: "Test", width_mm: 100.0, height_mm: 50.0, background_color: "AABBCC"}
      changeset = Design.changeset(%Design{}, attrs)
      refute changeset.valid?
      assert "must be a valid hex color (e.g., #FFFFFF)" in errors_on(changeset).background_color
    end

    test "validates background_color format - invalid too short" do
      attrs = %{name: "Test", width_mm: 100.0, height_mm: 50.0, background_color: "#FFF"}
      changeset = Design.changeset(%Design{}, attrs)
      refute changeset.valid?
    end

    test "validates background_color format - invalid too long" do
      attrs = %{name: "Test", width_mm: 100.0, height_mm: 50.0, background_color: "#FFFFFFF"}
      changeset = Design.changeset(%Design{}, attrs)
      refute changeset.valid?
    end

    test "validates background_color format - invalid characters" do
      attrs = %{name: "Test", width_mm: 100.0, height_mm: 50.0, background_color: "#GGGGGG"}
      changeset = Design.changeset(%Design{}, attrs)
      refute changeset.valid?
    end

    test "validates border_color format" do
      attrs = %{name: "Test", width_mm: 100.0, height_mm: 50.0, border_color: "invalid"}
      changeset = Design.changeset(%Design{}, attrs)
      refute changeset.valid?
      assert "must be a valid hex color (e.g., #FFFFFF)" in errors_on(changeset).border_color
    end

    test "allows nil background_color" do
      attrs = %{name: "Test", width_mm: 100.0, height_mm: 50.0, background_color: nil}
      changeset = Design.changeset(%Design{}, attrs)
      assert changeset.valid?
    end

    test "accepts all optional fields" do
      attrs = %{
        name: "Full Design",
        description: "A complete design",
        width_mm: 100.0,
        height_mm: 50.0,
        background_color: "#FFFFFF",
        border_width: 1.0,
        border_color: "#000000",
        border_radius: 5.0,
        is_template: true,
        label_type: "multiple",
        user_id: 1
      }

      changeset = Design.changeset(%Design{}, attrs)
      assert changeset.valid?
    end

    test "casts embedded elements" do
      attrs = %{
        name: "With Elements",
        width_mm: 100.0,
        height_mm: 50.0,
        elements: [
          %{id: "el_1", type: "qr", x: 10, y: 10, width: 20, height: 20}
        ]
      }

      changeset = Design.changeset(%Design{}, attrs)
      assert changeset.valid?
    end
  end

  describe "duplicate_changeset/2" do
    test "creates changeset for duplication" do
      original = %Design{
        name: "Original",
        description: "Test description",
        width_mm: 100.0,
        height_mm: 50.0,
        background_color: "#FF0000",
        border_width: 2.0,
        border_color: "#00FF00",
        border_radius: 5.0,
        is_template: true,
        label_type: "multiple",
        elements: []
      }

      changeset = Design.duplicate_changeset(original, %{name: "Copy", user_id: 123})

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :name) == "Copy"
      assert Ecto.Changeset.get_field(changeset, :user_id) == 123
      assert Ecto.Changeset.get_field(changeset, :description) == "Test description"
      assert Ecto.Changeset.get_field(changeset, :width_mm) == 100.0
      # is_template should be set to false for duplicates
      assert Ecto.Changeset.get_field(changeset, :is_template) == false
    end
  end

  describe "to_json/1" do
    test "converts design to JSON-serializable map" do
      design = %Design{
        id: 1,
        name: "Test",
        description: "Description",
        width_mm: 100.0,
        height_mm: 50.0,
        background_color: "#FFFFFF",
        border_width: 1.0,
        border_color: "#000000",
        border_radius: 5.0,
        elements: []
      }

      json = Design.to_json(design)

      assert json.id == 1
      assert json.name == "Test"
      assert json.width_mm == 100.0
      assert json.height_mm == 50.0
      assert json.elements == []
    end

    test "includes element details in JSON" do
      design = %Design{
        id: 1,
        name: "With Element",
        width_mm: 100.0,
        height_mm: 50.0,
        elements: [
          %QrLabelSystem.Designs.Element{
            id: "el_1",
            type: "qr",
            x: 10.0,
            y: 10.0,
            width: 20.0,
            height: 20.0,
            z_index: 1,
            visible: true,
            locked: false
          }
        ]
      }

      json = Design.to_json(design)

      assert length(json.elements) == 1
      element = hd(json.elements)
      assert element.id == "el_1"
      assert element.type == "qr"
      assert element.z_index == 1
    end
  end
end
