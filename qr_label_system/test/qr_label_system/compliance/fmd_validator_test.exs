defmodule QrLabelSystem.Compliance.FmdValidatorTest do
  use QrLabelSystem.DataCase, async: true

  alias QrLabelSystem.Compliance.FmdValidator
  alias QrLabelSystem.Designs.Design

  defp make_design(elements) do
    %Design{
      id: 1,
      name: "Test FMD",
      width_mm: 100.0,
      height_mm: 50.0,
      elements: elements,
      groups: [],
      compliance_standard: "fmd"
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
      font_size: 12.0,
      binding: Keyword.get(opts, :binding)
    }
  end

  defp datamatrix(content, opts \\ []) do
    %QrLabelSystem.Designs.Element{
      id: Keyword.get(opts, :id, "el_dm_#{System.unique_integer([:positive])}"),
      type: "barcode",
      x: 10.0,
      y: 10.0,
      width: 20.0,
      height: 20.0,
      barcode_format: "DATAMATRIX",
      text_content: content,
      binding: Keyword.get(opts, :binding)
    }
  end

  defp complete_pharma_elements do
    [
      text("Nombre medicamento", "Ibuprofeno"),
      text("Principio activo", "Ibuprofeno"),
      text("Lote", "LOT-2026-001"),
      text("Caducidad", "12/2027"),
      text("Código Nacional", "CN 123456"),
      text("Número de serie", "SN-ABC-789"),
      text("Dosis", "400 mg comprimidos recubiertos"),
      text("Laboratorio", "Laboratorio Pharma S.A."),
      datamatrix("011234567890123417271231\x1D10LOT001\x1D21SER001")
    ]
  end

  describe "standard metadata" do
    test "returns correct standard info" do
      assert FmdValidator.standard_name() =~ "FMD"
      assert FmdValidator.standard_code() == "fmd"
      assert is_binary(FmdValidator.standard_description())
    end
  end

  describe "complete pharma label" do
    test "no errors for complete label" do
      design = make_design(complete_pharma_elements())
      issues = FmdValidator.validate(design)
      errors = Enum.filter(issues, &(&1.severity == :error))
      assert errors == []
    end
  end

  describe "mandatory fields" do
    test "detects missing product name" do
      elements = complete_pharma_elements() |> Enum.reject(&((&1.name || "") =~ ~r/medicamento/i))
      design = make_design(elements)
      issues = FmdValidator.validate(design)
      assert Enum.any?(issues, &(&1.code == "FMD_MISSING_PRODUCT_NAME"))
    end

    test "detects missing active ingredient" do
      elements = complete_pharma_elements() |> Enum.reject(&((&1.name || "") =~ ~r/activo/i))
      design = make_design(elements)
      issues = FmdValidator.validate(design)
      assert Enum.any?(issues, &(&1.code == "FMD_MISSING_ACTIVE_INGREDIENT"))
    end

    test "detects missing lot number" do
      elements = complete_pharma_elements() |> Enum.reject(&((&1.name || "") =~ ~r/^Lote$/i))
      design = make_design(elements)
      issues = FmdValidator.validate(design)
      assert Enum.any?(issues, &(&1.code == "FMD_MISSING_LOT"))
    end

    test "detects missing expiry date" do
      elements = complete_pharma_elements() |> Enum.reject(&((&1.name || "") =~ ~r/Caducidad/i))
      design = make_design(elements)
      issues = FmdValidator.validate(design)
      assert Enum.any?(issues, &(&1.code == "FMD_MISSING_EXPIRY"))
    end

    test "detects missing national code" do
      elements = complete_pharma_elements() |> Enum.reject(&((&1.name || "") =~ ~r/Nacional/i))
      design = make_design(elements)
      issues = FmdValidator.validate(design)
      assert Enum.any?(issues, &(&1.code == "FMD_MISSING_NATIONAL_CODE"))
    end

    test "detects missing serial number" do
      elements = complete_pharma_elements() |> Enum.reject(&((&1.name || "") =~ ~r/serie/i))
      design = make_design(elements)
      issues = FmdValidator.validate(design)
      assert Enum.any?(issues, &(&1.code == "FMD_MISSING_SERIAL"))
    end

    test "empty design has all mandatory errors" do
      design = make_design([])
      issues = FmdValidator.validate(design)
      error_codes = issues |> Enum.filter(&(&1.severity == :error)) |> Enum.map(& &1.code)
      assert "FMD_MISSING_PRODUCT_NAME" in error_codes
      assert "FMD_MISSING_ACTIVE_INGREDIENT" in error_codes
      assert "FMD_MISSING_LOT" in error_codes
      assert "FMD_MISSING_EXPIRY" in error_codes
      assert "FMD_MISSING_NATIONAL_CODE" in error_codes
      assert "FMD_MISSING_SERIAL" in error_codes
      assert "FMD_MISSING_DATAMATRIX" in error_codes
    end
  end

  describe "DataMatrix validation" do
    test "missing DataMatrix produces error" do
      elements = complete_pharma_elements() |> Enum.reject(&(&1.barcode_format == "DATAMATRIX"))
      design = make_design(elements)
      issues = FmdValidator.validate(design)
      assert Enum.any?(issues, &(&1.code == "FMD_MISSING_DATAMATRIX"))
    end

    test "DataMatrix with complete GS1 AIs produces no warnings" do
      elements = [datamatrix("011234567890123417271231\x1D10LOT001\x1D21SER001")]
      design = make_design(elements)
      issues = FmdValidator.validate(design)
      refute Enum.any?(issues, &(&1.code == "FMD_DATAMATRIX_NO_GS1"))
    end

    test "DataMatrix without GS1 content produces warning" do
      elements = [datamatrix("Hello World")]
      design = make_design(elements)
      issues = FmdValidator.validate(design)
      assert Enum.any?(issues, &(&1.code == "FMD_DATAMATRIX_NO_GS1"))
    end

    test "DataMatrix with incomplete GS1 AIs produces warning about missing AIs" do
      # Only has AI 01 (GTIN), missing 17, 10, 21
      elements = [datamatrix("0112345678901234")]
      design = make_design(elements)
      issues = FmdValidator.validate(design)
      assert Enum.any?(issues, &(&1.code == "FMD_DATAMATRIX_NO_GS1"))
    end
  end

  describe "recommended fields" do
    test "warns about missing dosage" do
      elements = complete_pharma_elements() |> Enum.reject(&((&1.name || "") =~ ~r/Dosis/i))
      design = make_design(elements)
      issues = FmdValidator.validate(design)
      assert Enum.any?(issues, &(&1.code == "FMD_MISSING_DOSAGE"))
    end

    test "warns about missing manufacturer" do
      elements = complete_pharma_elements() |> Enum.reject(&((&1.name || "") =~ ~r/Laboratorio/i))
      design = make_design(elements)
      issues = FmdValidator.validate(design)
      assert Enum.any?(issues, &(&1.code == "FMD_MISSING_MANUFACTURER"))
    end
  end
end
