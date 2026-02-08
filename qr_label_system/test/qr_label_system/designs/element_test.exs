defmodule QrLabelSystem.Designs.ElementTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.Designs.Element

  describe "changeset/2 - required fields" do
    test "valid changeset with required fields" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "auto-generates id when not provided" do
      attrs = %{type: "qr", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      # id is auto-generated if missing
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :id) != nil
    end

    test "invalid without type" do
      attrs = %{id: "el_1", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).type
    end

    test "uses default for x when not provided" do
      attrs = %{id: "el_1", type: "qr", y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      # x has a default value of 0.0 in the schema
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :x) == 0.0
    end

    test "uses default for y when not provided" do
      attrs = %{id: "el_1", type: "qr", x: 10.0}
      changeset = Element.changeset(%Element{}, attrs)
      # y has a default value of 0.0 in the schema
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :y) == 0.0
    end
  end

  describe "changeset/2 - type validation" do
    test "accepts qr type" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts barcode type" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts text type" do
      attrs = %{id: "el_1", type: "text", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts line type" do
      attrs = %{id: "el_1", type: "line", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts rectangle type" do
      attrs = %{id: "el_1", type: "rectangle", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts image type" do
      attrs = %{id: "el_1", type: "image", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "rejects invalid type" do
      attrs = %{id: "el_1", type: "unknown", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).type
    end
  end

  describe "changeset/2 - barcode_format validation" do
    test "validates barcode format for barcode type" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "INVALID"}
      changeset = Element.changeset(%Element{}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).barcode_format != nil
    end

    test "accepts CODE128 format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "CODE128"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts CODE39 format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "CODE39"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts EAN13 format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "EAN13"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts EAN8 format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "EAN8"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts UPC format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "UPC"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts ITF14 format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "ITF14"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts pharmacode format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "pharmacode"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    # New industrial formats
    test "accepts GS1_128 format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "GS1_128"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts GS1_DATABAR format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "GS1_DATABAR"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts GS1_DATABAR_STACKED format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "GS1_DATABAR_STACKED"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts GS1_DATABAR_EXPANDED format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "GS1_DATABAR_EXPANDED"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts CODE93 format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "CODE93"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts MSI format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "MSI"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts CODABAR format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "CODABAR"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts DATAMATRIX format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "DATAMATRIX"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts PDF417 format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "PDF417"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts AZTEC format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "AZTEC"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts MAXICODE format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "MAXICODE"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts POSTNET format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "POSTNET"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts PLANET format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "PLANET"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts ROYALMAIL format" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0, barcode_format: "ROYALMAIL"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "skips barcode format validation for non-barcode types" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, barcode_format: "INVALID"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end
  end

  describe "changeset/2 - qr_error_level validation" do
    test "validates qr_error_level for qr type" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, qr_error_level: "INVALID"}
      changeset = Element.changeset(%Element{}, attrs)
      refute changeset.valid?
      assert "must be one of: L, M, Q, H" in errors_on(changeset).qr_error_level
    end

    test "accepts L error level" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, qr_error_level: "L"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts M error level" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, qr_error_level: "M"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts Q error level" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, qr_error_level: "Q"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts H error level" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, qr_error_level: "H"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "skips qr_error_level validation for non-qr types" do
      attrs = %{id: "el_1", type: "text", x: 10.0, y: 20.0, qr_error_level: "INVALID"}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end
  end

  describe "changeset/2 - qr_logo validation" do
    test "accepts qr_logo_data within size limit" do
      small_logo = String.duplicate("a", 1000)
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, qr_logo_data: small_logo}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "rejects qr_logo_data over 500KB" do
      large_logo = String.duplicate("a", 500_001)
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, qr_logo_data: large_logo}
      changeset = Element.changeset(%Element{}, attrs)
      refute changeset.valid?
      assert "logo too large, maximum size is 500KB" in errors_on(changeset).qr_logo_data
    end

    test "accepts valid qr_logo_size" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, qr_logo_size: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "rejects qr_logo_size below 5%" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, qr_logo_size: 3.0}
      changeset = Element.changeset(%Element{}, attrs)
      refute changeset.valid?
      assert "must be between 5% and 30%" in errors_on(changeset).qr_logo_size
    end

    test "rejects qr_logo_size above 30%" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, qr_logo_size: 35.0}
      changeset = Element.changeset(%Element{}, attrs)
      refute changeset.valid?
      assert "must be between 5% and 30%" in errors_on(changeset).qr_logo_size
    end

    test "accepts boundary qr_logo_size of 5%" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, qr_logo_size: 5.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "accepts boundary qr_logo_size of 30%" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, qr_logo_size: 30.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "defaults qr_logo_size to 25%" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :qr_logo_size) == 25.0
    end
  end

  describe "changeset/2 - image_data validation" do
    test "accepts image_data within size limit" do
      small_data = String.duplicate("a", 1000)
      attrs = %{id: "el_1", type: "image", x: 10.0, y: 20.0, image_data: small_data}
      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end

    test "rejects image_data over 2MB" do
      large_data = String.duplicate("a", 2_000_001)
      attrs = %{id: "el_1", type: "image", x: 10.0, y: 20.0, image_data: large_data}
      changeset = Element.changeset(%Element{}, attrs)
      refute changeset.valid?
      assert "image too large, maximum size is 2MB" in errors_on(changeset).image_data
    end
  end

  describe "changeset/2 - auto-generated fields" do
    test "generates id if missing" do
      attrs = %{type: "qr", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      id = Ecto.Changeset.get_field(changeset, :id)
      assert String.starts_with?(id, "el_")
    end

    test "generates name if missing" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :name) == "Código QR"
    end

    test "generates correct name for barcode" do
      attrs = %{id: "el_1", type: "barcode", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :name) == "Código de Barras"
    end

    test "generates correct name for text" do
      attrs = %{id: "el_1", type: "text", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :name) == "Texto"
    end

    test "generates correct name for line" do
      attrs = %{id: "el_1", type: "line", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :name) == "Línea"
    end

    test "generates correct name for rectangle" do
      attrs = %{id: "el_1", type: "rectangle", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :name) == "Rectángulo"
    end

    test "generates correct name for image" do
      attrs = %{id: "el_1", type: "image", x: 10.0, y: 20.0}
      changeset = Element.changeset(%Element{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :name) == "Imagen"
    end

    test "preserves existing name" do
      attrs = %{id: "el_1", type: "qr", x: 10.0, y: 20.0, name: "Custom Name"}
      changeset = Element.changeset(%Element{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :name) == "Custom Name"
    end
  end

  describe "changeset/2 - all fields" do
    test "accepts all fields" do
      attrs = %{
        id: "el_1",
        type: "text",
        x: 10.0,
        y: 20.0,
        width: 100.0,
        height: 20.0,
        rotation: 45.0,
        binding: "product_name",
        font_size: 12.0,
        font_family: "Arial",
        font_weight: "bold",
        text_align: "center",
        text_content: "Hello World",
        color: "#333333",
        background_color: "#FFFFFF",
        border_width: 1.0,
        border_color: "#000000",
        z_index: 5,
        visible: true,
        locked: false,
        name: "Product Label"
      }

      changeset = Element.changeset(%Element{}, attrs)
      assert changeset.valid?
    end
  end

  describe "element_types/0" do
    test "returns all valid element types" do
      types = Element.element_types()
      assert "qr" in types
      assert "barcode" in types
      assert "text" in types
      assert "line" in types
      assert "rectangle" in types
      assert "image" in types
    end
  end

  describe "barcode_formats/0" do
    test "returns all valid barcode formats including new industrial formats" do
      formats = Element.barcode_formats()
      # Original 7
      assert "CODE128" in formats
      assert "CODE39" in formats
      assert "EAN13" in formats
      assert "EAN8" in formats
      assert "UPC" in formats
      assert "ITF14" in formats
      assert "pharmacode" in formats
      # New 14
      assert "GS1_128" in formats
      assert "GS1_DATABAR" in formats
      assert "GS1_DATABAR_STACKED" in formats
      assert "GS1_DATABAR_EXPANDED" in formats
      assert "CODE93" in formats
      assert "MSI" in formats
      assert "CODABAR" in formats
      assert "DATAMATRIX" in formats
      assert "PDF417" in formats
      assert "AZTEC" in formats
      assert "MAXICODE" in formats
      assert "POSTNET" in formats
      assert "PLANET" in formats
      assert "ROYALMAIL" in formats
    end

    test "returns exactly 21 formats" do
      assert length(Element.barcode_formats()) == 21
    end
  end
end
