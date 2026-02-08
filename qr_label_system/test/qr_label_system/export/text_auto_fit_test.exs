defmodule QrLabelSystem.Export.TextAutoFitTest do
  use ExUnit.Case, async: true

  alias QrLabelSystem.Export.ZplGenerator

  defp build_design(elements) do
    %{
      width_mm: 50,
      height_mm: 30,
      elements: elements
    }
  end

  defp text_element(opts) do
    %{
      id: "el_1",
      type: "text",
      x: 5.0,
      y: 5.0,
      width: Keyword.get(opts, :width, 40.0),
      height: Keyword.get(opts, :height, 10.0),
      rotation: nil,
      binding: nil,
      text_content: Keyword.get(opts, :text_content, "Hello"),
      font_size: Keyword.get(opts, :font_size, 24.0),
      font_family: "Arial",
      font_weight: "normal",
      text_align: "left",
      text_auto_fit: Keyword.get(opts, :text_auto_fit, false),
      text_min_font_size: Keyword.get(opts, :text_min_font_size, 6.0),
      color: "#000000",
      background_color: nil,
      border_width: 0,
      border_color: "#000000",
      border_radius: 0,
      barcode_format: "CODE128",
      barcode_show_text: false,
      qr_error_level: "M",
      image_data: nil,
      z_index: 0,
      visible: true,
      locked: false,
      name: nil
    }
  end

  describe "ZPL text auto-fit" do
    test "long text reduces font size when auto-fit enabled" do
      long_text = String.duplicate("A", 200)
      element = text_element(text_content: long_text, font_size: 24.0, width: 30.0, height: 8.0, text_auto_fit: true)
      design = build_design([element])

      zpl = ZplGenerator.generate(design)

      # Extract font height from ^A0N,<font_h>,<font_w>
      [_, font_h_str] = Regex.run(~r/\^A0N,(\d+),/, zpl)
      font_h = String.to_integer(font_h_str)

      # Original font_h at 203 DPI: round((24/6) * 8) = 32 dots
      # With auto-fit, should be smaller
      assert font_h < 32
    end

    test "respects minimum font size" do
      very_long_text = String.duplicate("A", 1000)
      element = text_element(
        text_content: very_long_text,
        font_size: 24.0,
        width: 10.0,
        height: 5.0,
        text_auto_fit: true,
        text_min_font_size: 8.0
      )
      design = build_design([element])

      zpl = ZplGenerator.generate(design)

      [_, font_h_str] = Regex.run(~r/\^A0N,(\d+),/, zpl)
      font_h = String.to_integer(font_h_str)

      # Minimum font: round((8/6) * 8) = 11 dots (at 203 DPI, 8 dpmm)
      min_font_dots = round(8.0 / 6 * 8)
      assert font_h >= min_font_dots
    end

    test "text_auto_fit: false preserves original font size" do
      long_text = String.duplicate("A", 200)
      element = text_element(
        text_content: long_text,
        font_size: 24.0,
        width: 30.0,
        height: 8.0,
        text_auto_fit: false
      )
      design = build_design([element])

      zpl = ZplGenerator.generate(design)

      [_, font_h_str] = Regex.run(~r/\^A0N,(\d+),/, zpl)
      font_h = String.to_integer(font_h_str)

      # Original: round((24/6) * 8) = 32 dots
      expected = round(24.0 / 6 * 8)
      assert font_h == expected
    end

    test "short text does not change font size with auto-fit enabled" do
      element = text_element(
        text_content: "Hi",
        font_size: 12.0,
        width: 40.0,
        height: 10.0,
        text_auto_fit: true
      )
      design = build_design([element])

      zpl = ZplGenerator.generate(design)

      [_, font_h_str] = Regex.run(~r/\^A0N,(\d+),/, zpl)
      font_h = String.to_integer(font_h_str)

      # Original: round((12/6) * 8) = 16 dots
      expected = round(12.0 / 6 * 8)
      assert font_h == expected
    end

    test "nil text_auto_fit defaults to false (auto-fit disabled)" do
      long_text = String.duplicate("A", 200)
      # Build element without text_auto_fit key to test Map.get default
      element = text_element(text_content: long_text, font_size: 24.0, width: 30.0, height: 8.0)
      element = Map.delete(element, :text_auto_fit)
      design = build_design([element])

      zpl = ZplGenerator.generate(design)

      [_, font_h_str] = Regex.run(~r/\^A0N,(\d+),/, zpl)
      font_h = String.to_integer(font_h_str)

      # Default is now false — should NOT auto-fit, preserves original 32 dots
      expected = round(24.0 / 6 * 8)
      assert font_h == expected
    end
  end
end
