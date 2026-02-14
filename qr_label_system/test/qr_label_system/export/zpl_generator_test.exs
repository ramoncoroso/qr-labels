defmodule QrLabelSystem.Export.ZplGeneratorTest do
  use ExUnit.Case, async: true

  alias QrLabelSystem.Export.ZplGenerator

  # Helper to build a minimal design struct-like map
  defp build_design(opts \\ []) do
    elements = Keyword.get(opts, :elements, [])
    %{
      width_mm: Keyword.get(opts, :width_mm, 50),
      height_mm: Keyword.get(opts, :height_mm, 30),
      elements: elements
    }
  end

  defp build_element(type, opts) do
    %{
      id: Keyword.get(opts, :id, "el_1"),
      type: type,
      x: Keyword.get(opts, :x, 5.0),
      y: Keyword.get(opts, :y, 5.0),
      width: Keyword.get(opts, :width, 20.0),
      height: Keyword.get(opts, :height, 10.0),
      rotation: Keyword.get(opts, :rotation, nil),
      binding: Keyword.get(opts, :binding, nil),
      text_content: Keyword.get(opts, :text_content, nil),
      font_size: Keyword.get(opts, :font_size, 12.0),
      font_family: Keyword.get(opts, :font_family, "Arial"),
      font_weight: Keyword.get(opts, :font_weight, "normal"),
      text_align: Keyword.get(opts, :text_align, "left"),
      color: Keyword.get(opts, :color, "#000000"),
      background_color: Keyword.get(opts, :background_color, nil),
      border_width: Keyword.get(opts, :border_width, 0.5),
      border_color: Keyword.get(opts, :border_color, "#000000"),
      border_radius: Keyword.get(opts, :border_radius, 0),
      barcode_format: Keyword.get(opts, :barcode_format, "CODE128"),
      barcode_show_text: Keyword.get(opts, :barcode_show_text, false),
      qr_error_level: Keyword.get(opts, :qr_error_level, "M"),
      image_data: Keyword.get(opts, :image_data, nil),
      z_index: Keyword.get(opts, :z_index, 0),
      visible: true,
      locked: false,
      name: nil
    }
  end

  describe "generate/3 - structure" do
    test "produces valid ZPL header and footer" do
      design = build_design()
      zpl = ZplGenerator.generate(design)

      assert String.starts_with?(zpl, "^XA")
      assert String.contains?(zpl, "^XZ")
    end

    test "sets label width and length" do
      design = build_design(width_mm: 50, height_mm: 30)
      zpl = ZplGenerator.generate(design, %{}, dpi: 203)

      # 50mm * 8 dots/mm = 400 dots
      assert String.contains?(zpl, "^PW400")
      # 30mm * 8 dots/mm = 240 dots
      assert String.contains?(zpl, "^LL240")
    end

    test "different DPI produces different dot values" do
      design = build_design(width_mm: 50, height_mm: 30)

      zpl_203 = ZplGenerator.generate(design, %{}, dpi: 203)
      zpl_300 = ZplGenerator.generate(design, %{}, dpi: 300)

      # 203 DPI: 50*8 = 400
      assert String.contains?(zpl_203, "^PW400")
      # 300 DPI: 50*12 = 600
      assert String.contains?(zpl_300, "^PW600")
    end
  end

  describe "generate/3 - text elements" do
    test "renders text with ^FO and ^FD" do
      el = build_element("text", text_content: "Hello World")
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^FO")
      assert String.contains?(zpl, "^FDHello World^FS")
    end

    test "text with binding resolves from row" do
      el = build_element("text", binding: "nombre")
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design, %{"nombre" => "Juan"})

      assert String.contains?(zpl, "^FDJuan^FS")
    end

    test "text with expression resolves" do
      el = build_element("text", binding: "{{MAYUS(nombre)}}")
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design, %{"nombre" => "juan"})

      assert String.contains?(zpl, "^FDJUAN^FS")
    end

    test "escapes ^ and ~ in text" do
      el = build_element("text", text_content: "Price: 5^ and ~10")
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      refute String.contains?(zpl, "5^")
      refute String.contains?(zpl, "~10")
    end

    test "uses ^A0 font command" do
      el = build_element("text", text_content: "Test")
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^A0")
    end
  end

  describe "generate/3 - barcodes" do
    test "CODE128 uses ^BC command" do
      el = build_element("barcode", barcode_format: "CODE128", text_content: "ABC123")
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^BC")
      assert String.contains?(zpl, "^FDABC123^FS")
    end

    test "CODE39 uses ^B3 command" do
      el = build_element("barcode", barcode_format: "CODE39", text_content: "12345")
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^B3")
    end

    test "EAN13 uses ^BE command" do
      el = build_element("barcode", barcode_format: "EAN13", text_content: "5901234123457")
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^BE")
    end

    test "DATAMATRIX uses ^BX command" do
      el = build_element("barcode", barcode_format: "DATAMATRIX", text_content: "DATA123")
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^BX")
    end

    test "PDF417 uses ^B7 command" do
      el = build_element("barcode", barcode_format: "PDF417", text_content: "DATA123")
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^B7")
    end

    test "barcode with expression binding" do
      el = build_element("barcode", barcode_format: "CODE128", binding: "{{CONTADOR(1, 1, 6)}}")
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design, %{}, row_index: 2)

      assert String.contains?(zpl, "^FD000003^FS")
    end
  end

  describe "generate/3 - QR codes" do
    test "QR uses ^BQ command" do
      el = build_element("qr", text_content: "https://example.com")
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^BQ")
      assert String.contains?(zpl, "^FDQA,https://example.com^FS")
    end

    test "QR with data binding" do
      el = build_element("qr", binding: "url")
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design, %{"url" => "https://test.com"})

      assert String.contains?(zpl, "^FDQA,https://test.com^FS")
    end
  end

  describe "generate/3 - shapes" do
    test "rectangle uses ^GB command" do
      el = build_element("rectangle", width: 20.0, height: 10.0)
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^GB")
    end

    test "line uses ^GB command" do
      el = build_element("line", width: 30.0, height: 0.5)
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^GB")
    end

    test "circle uses ^GC command" do
      el = build_element("circle", width: 10.0, height: 10.0)
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^GC")
    end

    test "image uses placeholder ^GB" do
      el = build_element("image", width: 15.0, height: 15.0)
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^GB")
    end
  end

  describe "generate/3 - rotation" do
    test "0 degrees maps to N" do
      el = build_element("text", text_content: "Test", rotation: 0)
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^A0N")
    end

    test "90 degrees maps to R" do
      el = build_element("text", text_content: "Test", rotation: 90)
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^A0R")
    end

    test "180 degrees maps to I" do
      el = build_element("text", text_content: "Test", rotation: 180)
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^A0I")
    end

    test "270 degrees maps to B" do
      el = build_element("text", text_content: "Test", rotation: 270)
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design)

      assert String.contains?(zpl, "^A0B")
    end
  end

  describe "generate_batch/3" do
    test "generates multiple labels" do
      el = build_element("text", binding: "nombre")
      design = build_design(elements: [el])
      rows = [%{"nombre" => "Alice"}, %{"nombre" => "Bob"}, %{"nombre" => "Carol"}]

      zpl = ZplGenerator.generate_batch(design, rows)

      # Should have 3 ^XA...^XZ blocks
      assert length(String.split(zpl, "^XA")) == 4  # 3 blocks + 1 empty before first
      assert String.contains?(zpl, "^FDAlice^FS")
      assert String.contains?(zpl, "^FDBob^FS")
      assert String.contains?(zpl, "^FDCarol^FS")
    end

    test "counter increments across batch" do
      el = build_element("text", binding: "{{CONTADOR(1, 1, 4)}}")
      design = build_design(elements: [el])
      rows = [%{}, %{}, %{}]

      zpl = ZplGenerator.generate_batch(design, rows)

      assert String.contains?(zpl, "^FD0001^FS")
      assert String.contains?(zpl, "^FD0002^FS")
      assert String.contains?(zpl, "^FD0003^FS")
    end
  end

  describe "mm to dots conversion" do
    test "203 DPI: 10mm = 80 dots" do
      el = build_element("text", text_content: "T", x: 10.0, y: 10.0)
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design, %{}, dpi: 203)

      assert String.contains?(zpl, "^FO80,80")
    end

    test "300 DPI: 10mm = 120 dots" do
      el = build_element("text", text_content: "T", x: 10.0, y: 10.0)
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design, %{}, dpi: 300)

      assert String.contains?(zpl, "^FO120,120")
    end

    test "600 DPI: 10mm = 240 dots" do
      el = build_element("text", text_content: "T", x: 10.0, y: 10.0)
      design = build_design(elements: [el])
      zpl = ZplGenerator.generate(design, %{}, dpi: 600)

      assert String.contains?(zpl, "^FO240,240")
    end
  end
end
