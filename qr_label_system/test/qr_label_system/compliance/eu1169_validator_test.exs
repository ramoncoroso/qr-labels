defmodule QrLabelSystem.Compliance.Eu1169ValidatorTest do
  use QrLabelSystem.DataCase, async: true

  alias QrLabelSystem.Compliance.Eu1169Validator
  alias QrLabelSystem.Designs.Design

  defp make_design(elements, opts \\ []) do
    %Design{
      id: 1,
      name: "Test EU 1169",
      width_mm: Keyword.get(opts, :width_mm, 100.0),
      height_mm: Keyword.get(opts, :height_mm, 50.0),
      elements: elements,
      groups: [],
      compliance_standard: "eu1169"
    }
  end

  defp text(name, content, opts \\ []) do
    %QrLabelSystem.Designs.Element{
      id: Keyword.get(opts, :id, "el_#{System.unique_integer([:positive])}"),
      type: "text",
      x: 10.0,
      y: 10.0,
      width: 50.0,
      height: 10.0,
      name: name,
      text_content: content,
      font_size: Keyword.get(opts, :font_size, 12.0),
      font_weight: Keyword.get(opts, :font_weight, "normal"),
      binding: Keyword.get(opts, :binding)
    }
  end

  defp barcode_el(format \\ "EAN13") do
    %QrLabelSystem.Designs.Element{
      id: "el_barcode_#{System.unique_integer([:positive])}",
      type: "barcode",
      x: 10.0,
      y: 10.0,
      width: 40.0,
      height: 15.0,
      barcode_format: format
    }
  end

  defp complete_food_elements do
    [
      text("Denominación", "Galletas de chocolate"),
      text("Ingredientes", "Harina, azúcar, cacao, mantequilla"),
      text("Alérgenos", "Contiene: GLUTEN, LECHE", font_weight: "bold"),
      text("Peso neto", "250g"),
      text("Caducidad", "Consumir antes de: 12/2026"),
      text("Fabricante", "Empresa ABC, Madrid"),
      text("Origen", "Hecho en España"),
      text("Nutrición", "Calorías: 450kcal por 100g"),
      text("Lote", "LOT-2026-001"),
      barcode_el()
    ]
  end

  describe "standard metadata" do
    test "returns correct standard info" do
      assert Eu1169Validator.standard_name() == "EU 1169/2011"
      assert Eu1169Validator.standard_code() == "eu1169"
      assert is_binary(Eu1169Validator.standard_description())
    end
  end

  describe "complete food label" do
    test "no errors for complete label" do
      design = make_design(complete_food_elements())
      issues = Eu1169Validator.validate(design)
      errors = Enum.filter(issues, &(&1.severity == :error))
      assert errors == []
    end

    test "no warnings for complete label with bold allergens" do
      design = make_design(complete_food_elements())
      issues = Eu1169Validator.validate(design)
      warnings = Enum.filter(issues, &(&1.severity == :warning))
      assert warnings == []
    end
  end

  describe "mandatory fields" do
    test "detects missing product name" do
      elements = complete_food_elements() |> Enum.reject(&((&1.name || "") =~ ~r/Denominación/))
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "EU_MISSING_NAME"))
    end

    test "detects missing ingredients" do
      elements = complete_food_elements() |> Enum.reject(&((&1.name || "") =~ ~r/Ingredientes/))
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "EU_MISSING_INGREDIENTS"))
    end

    test "detects missing allergens" do
      elements = complete_food_elements() |> Enum.reject(&((&1.name || "") =~ ~r/Alérgenos/))
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "EU_MISSING_ALLERGENS"))
    end

    test "detects missing net quantity" do
      elements = complete_food_elements() |> Enum.reject(&((&1.name || "") =~ ~r/Peso/))
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "EU_MISSING_NET_QUANTITY"))
    end

    test "detects missing best before date" do
      elements = complete_food_elements() |> Enum.reject(&((&1.name || "") =~ ~r/Caducidad/))
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "EU_MISSING_BEST_BEFORE"))
    end

    test "empty design has all mandatory errors" do
      design = make_design([])
      issues = Eu1169Validator.validate(design)
      error_codes = issues |> Enum.filter(&(&1.severity == :error)) |> Enum.map(& &1.code)
      assert "EU_MISSING_NAME" in error_codes
      assert "EU_MISSING_INGREDIENTS" in error_codes
      assert "EU_MISSING_ALLERGENS" in error_codes
      assert "EU_MISSING_NET_QUANTITY" in error_codes
      assert "EU_MISSING_BEST_BEFORE" in error_codes
    end
  end

  describe "recommended fields" do
    test "warns about missing manufacturer" do
      elements = complete_food_elements() |> Enum.reject(&((&1.name || "") =~ ~r/Fabricante/))
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "EU_MISSING_MANUFACTURER"))
    end

    test "warns about missing origin" do
      elements = complete_food_elements() |> Enum.reject(&((&1.name || "") =~ ~r/Origen/))
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "EU_MISSING_ORIGIN"))
    end

    test "warns about missing nutrition info" do
      elements = complete_food_elements() |> Enum.reject(&((&1.name || "") =~ ~r/Nutrición/))
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "EU_MISSING_NUTRITION"))
    end

    test "warns about missing lot number" do
      elements = complete_food_elements() |> Enum.reject(&((&1.name || "") =~ ~r/Lote/))
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "EU_MISSING_LOT"))
    end

    test "info about missing barcode" do
      elements = complete_food_elements() |> Enum.reject(&(&1.type == "barcode"))
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "EU_MISSING_BARCODE" && &1.severity == :info))
    end
  end

  describe "font size validation" do
    test "flags font size below 8pt for normal labels" do
      elements = [text("Ingredientes", "text", font_size: 5.0)]
      design = make_design(elements, width_mm: 100.0, height_mm: 100.0)
      issues = Eu1169Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "EU_FONT_SIZE_MIN"))
    end

    test "allows 6pt font for small labels (<80cm²)" do
      elements = [text("Ingredientes", "text", font_size: 6.5)]
      design = make_design(elements, width_mm: 50.0, height_mm: 30.0)
      issues = Eu1169Validator.validate(design)
      refute Enum.any?(issues, &(&1.code == "EU_FONT_SIZE_MIN"))
    end

    test "flags font below 6pt even for small labels" do
      elements = [text("Ingredientes", "text", font_size: 4.0)]
      design = make_design(elements, width_mm: 50.0, height_mm: 30.0)
      issues = Eu1169Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "EU_FONT_SIZE_MIN"))
    end
  end

  describe "allergen highlighting" do
    test "warns when allergens not in bold" do
      elements = [text("Alérgenos", "Contiene: gluten, leche", font_weight: "normal")]
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "EU_ALLERGEN_HIGHLIGHT"))
    end

    test "no warning when allergens in bold" do
      elements = [text("Alérgenos", "Contiene: GLUTEN, LECHE", font_weight: "bold")]
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      refute Enum.any?(issues, &(&1.code == "EU_ALLERGEN_HIGHLIGHT"))
    end
  end

  describe "field detection heuristics" do
    test "detects field by binding name" do
      elements = [text("Campo1", "", binding: "ingredientes")]
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      refute Enum.any?(issues, &(&1.code == "EU_MISSING_INGREDIENTS"))
    end

    test "detects field by text content" do
      elements = [text("Campo1", "Lista de ingredientes: harina, sal")]
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      refute Enum.any?(issues, &(&1.code == "EU_MISSING_INGREDIENTS"))
    end

    test "detects English field names" do
      elements = [
        text("Product Name", "Cookie"),
        text("Ingredients", "Flour, sugar"),
        text("Allergens", "GLUTEN", font_weight: "bold"),
        text("Net Weight", "250g"),
        text("Expiry", "12/2026")
      ]
      design = make_design(elements)
      issues = Eu1169Validator.validate(design)
      errors = Enum.filter(issues, &(&1.severity == :error))
      assert errors == []
    end
  end
end
