defmodule QrLabelSystem.Designs.MultiLanguageTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Designs.Design
  alias QrLabelSystem.Designs.Element

  describe "Element translations field" do
    test "element has translations field with default empty map" do
      element = %Element{}
      assert element.translations == %{}
    end

    test "changeset accepts translations map" do
      attrs = %{
        id: "el_1",
        type: "text",
        x: 10.0,
        y: 10.0,
        text_content: "Ingredientes",
        translations: %{"en" => "Ingredients", "fr" => "Ingrédients"}
      }

      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :translations) == %{"en" => "Ingredients", "fr" => "Ingrédients"}
    end
  end

  describe "Design language fields" do
    test "design has default language 'es'" do
      design = %Design{}
      assert design.default_language == "es"
      assert design.languages == ["es"]
    end

    test "changeset accepts languages and default_language" do
      attrs = %{
        name: "Multi-lang Design",
        width_mm: 100.0,
        height_mm: 50.0,
        languages: ["es", "en", "fr"],
        default_language: "es"
      }

      changeset = Design.changeset(%Design{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :languages) == ["es", "en", "fr"]
      assert Ecto.Changeset.get_field(changeset, :default_language) == "es"
    end
  end

  describe "Design to_json includes language fields" do
    test "to_json includes languages and default_language" do
      design = %Design{
        id: 1,
        name: "Test",
        width_mm: 100.0,
        height_mm: 50.0,
        languages: ["es", "en"],
        default_language: "es",
        elements: []
      }

      json = Design.to_json(design)
      assert json.languages == ["es", "en"]
      assert json.default_language == "es"
    end

    test "to_json_light includes languages and default_language" do
      design = %Design{
        id: 1,
        name: "Test",
        width_mm: 100.0,
        height_mm: 50.0,
        languages: ["es", "fr"],
        default_language: "es",
        elements: []
      }

      json = Design.to_json_light(design)
      assert json.languages == ["es", "fr"]
      assert json.default_language == "es"
    end

    test "to_json includes element translations" do
      design = %Design{
        id: 1,
        name: "Test",
        width_mm: 100.0,
        height_mm: 50.0,
        elements: [
          %Element{
            id: "el_1",
            type: "text",
            x: 10.0,
            y: 10.0,
            text_content: "Ingredientes",
            translations: %{"en" => "Ingredients", "fr" => "Ingrédients"}
          }
        ]
      }

      json = Design.to_json(design)
      element = hd(json.elements)
      assert element.translations == %{"en" => "Ingredients", "fr" => "Ingrédients"}
    end
  end

  describe "Design persistence with languages" do
    test "creates design with languages" do
      attrs = %{
        name: "Multi-lang",
        width_mm: 100.0,
        height_mm: 50.0,
        languages: ["es", "en", "fr"],
        default_language: "es",
        elements: []
      }

      {:ok, design} = Designs.create_design(attrs)
      assert design.languages == ["es", "en", "fr"]
      assert design.default_language == "es"
    end

    test "updates design languages" do
      {:ok, design} = Designs.create_design(%{
        name: "Test",
        width_mm: 100.0,
        height_mm: 50.0,
        elements: []
      })

      {:ok, updated} = Designs.update_design(design, %{languages: ["es", "en"]})
      assert updated.languages == ["es", "en"]
    end

    test "creates design with element translations" do
      attrs = %{
        name: "With Translations",
        width_mm: 100.0,
        height_mm: 50.0,
        languages: ["es", "en"],
        default_language: "es",
        elements: [
          %{
            id: "el_1",
            type: "text",
            x: 10.0,
            y: 10.0,
            text_content: "Ingredientes",
            translations: %{"en" => "Ingredients"}
          }
        ]
      }

      {:ok, design} = Designs.create_design(attrs)
      element = hd(design.elements)
      assert element.translations == %{"en" => "Ingredients"}
    end
  end

  describe "Export/Import with translations" do
    test "export includes translations" do
      {:ok, design} = Designs.create_design(%{
        name: "Export Test",
        width_mm: 100.0,
        height_mm: 50.0,
        languages: ["es", "en"],
        default_language: "es",
        elements: [
          %{
            id: "el_1",
            type: "text",
            x: 10.0,
            y: 10.0,
            text_content: "Lote",
            translations: %{"en" => "Batch"}
          }
        ]
      })

      exported = Designs.export_design(design)
      element = hd(exported.design.elements)
      assert element.translations == %{"en" => "Batch"}
      assert exported.design.languages == ["es", "en"]
      assert exported.design.default_language == "es"
    end

    test "import preserves translations" do
      # First create a user for import
      {:ok, user} = QrLabelSystem.Accounts.register_user(%{
        email: "import_test_#{System.unique_integer()}@example.com",
        password: "Test_password_123!"
      })

      json_data = %{
        "version" => "1.0",
        "design" => %{
          "name" => "Imported",
          "width_mm" => 100.0,
          "height_mm" => 50.0,
          "languages" => ["es", "en"],
          "default_language" => "es",
          "elements" => [
            %{
              "type" => "text",
              "x" => 10,
              "y" => 10,
              "text_content" => "Ingredientes",
              "translations" => %{"en" => "Ingredients"}
            }
          ]
        }
      }

      {:ok, design} = Designs.import_design(json_data, user.id)
      assert design.languages == ["es", "en"]
      assert design.default_language == "es"
      element = hd(design.elements)
      assert element.translations == %{"en" => "Ingredients"}
    end
  end

  describe "Duplicate design with languages" do
    test "duplicating preserves languages and translations" do
      {:ok, user} = QrLabelSystem.Accounts.register_user(%{
        email: "dup_test_#{System.unique_integer()}@example.com",
        password: "Test_password_123!"
      })

      {:ok, original} = Designs.create_design(%{
        name: "Original",
        width_mm: 100.0,
        height_mm: 50.0,
        languages: ["es", "en", "fr"],
        default_language: "es",
        user_id: user.id,
        elements: [
          %{
            id: "el_1",
            type: "text",
            x: 10.0,
            y: 10.0,
            text_content: "Hola",
            translations: %{"en" => "Hello", "fr" => "Bonjour"}
          }
        ]
      })

      {:ok, copy} = Designs.duplicate_design(original, "Copy", user.id)
      assert copy.languages == ["es", "en", "fr"]
      assert copy.default_language == "es"
      element = hd(copy.elements)
      assert element.translations == %{"en" => "Hello", "fr" => "Bonjour"}
    end
  end
end
