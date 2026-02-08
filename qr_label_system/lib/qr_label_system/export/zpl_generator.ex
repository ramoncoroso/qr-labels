defmodule QrLabelSystem.Export.ZplGenerator do
  @moduledoc """
  Generates ZPL (Zebra Programming Language) code from label designs.
  Supports text, barcodes (CODE128, CODE39, EAN13, etc.), QR codes, and shapes.

  Usage:
      ZplGenerator.generate(design)                    # Single label, no data
      ZplGenerator.generate(design, row, opts)         # Single label with data
      ZplGenerator.generate_batch(design, rows, opts)  # Multiple labels
  """

  alias QrLabelSystem.Export.ExpressionEvaluator

  # Dots per mm for each DPI setting
  @dpi_map %{203 => 8, 300 => 12, 600 => 24}

  @doc """
  Generate ZPL for a single label.

  Options:
    - `:dpi` - Printer DPI (203, 300, or 600). Default: 203
    - `:row_index` - Row index for expression context. Default: 0
    - `:batch_size` - Total batch size for expressions. Default: 1
  """
  def generate(design, row \\ %{}, opts \\ []) do
    dpi = Keyword.get(opts, :dpi, 203)
    dpmm = Map.get(@dpi_map, dpi, 8)

    row_index = Keyword.get(opts, :row_index, 0)
    batch_size = Keyword.get(opts, :batch_size, 1)
    context = %{row_index: row_index, batch_size: batch_size, now: DateTime.utc_now()}

    # Label dimensions in dots
    w_dots = mm_to_dots(design.width_mm, dpmm)
    h_dots = mm_to_dots(design.height_mm, dpmm)

    elements_zpl =
      (design.elements || [])
      |> Enum.sort_by(& &1.z_index)
      |> Enum.map(&element_to_zpl(&1, row, context, dpmm))
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    """
    ^XA
    ^PW#{w_dots}
    ^LL#{h_dots}
    #{elements_zpl}
    ^XZ\
    """
  end

  @doc """
  Generate ZPL for a batch of labels (concatenated).
  """
  def generate_batch(design, rows, opts \\ []) do
    batch_size = length(rows)
    base_opts = Keyword.put(opts, :batch_size, batch_size)

    rows
    |> Enum.with_index()
    |> Enum.map(fn {row, idx} ->
      generate(design, row, Keyword.put(base_opts, :row_index, idx))
    end)
    |> Enum.join("\n")
  end

  # ── Element → ZPL ───────────────────────────────────────────

  defp element_to_zpl(element, row, context, dpmm) do
    x = mm_to_dots(element.x || 0, dpmm)
    y = mm_to_dots(element.y || 0, dpmm)

    case element.type do
      "text" -> text_to_zpl(element, row, context, x, y, dpmm)
      "barcode" -> barcode_to_zpl(element, row, context, x, y, dpmm)
      "qr" -> qr_to_zpl(element, row, context, x, y, dpmm)
      "rectangle" -> rectangle_to_zpl(element, x, y, dpmm)
      "line" -> line_to_zpl(element, x, y, dpmm)
      "circle" -> circle_to_zpl(element, x, y, dpmm)
      "image" -> image_placeholder_to_zpl(element, x, y, dpmm)
      _ -> nil
    end
  end

  # ── Text ─────────────────────────────────────────────────────

  defp text_to_zpl(element, row, context, x, y, dpmm) do
    text = ExpressionEvaluator.resolve_text(element, row, context)
    text = escape_zpl(text)

    # Font height in dots (canvas font_size is in px at 6px/mm)
    font_h = mm_to_dots((element.font_size || 10) / 6, dpmm)
    font_w = font_h  # Square proportions for ^A0

    rot = rotation_to_zpl(element.rotation)

    "^FO#{x},#{y}^A0#{rot},#{font_h},#{font_w}^FD#{text}^FS"
  end

  # ── Barcodes ─────────────────────────────────────────────────

  defp barcode_to_zpl(element, row, context, x, y, dpmm) do
    data = ExpressionEvaluator.resolve_code_value(element, row, context)
    data = escape_zpl(data)
    h = mm_to_dots(element.height || 10, dpmm)
    rot = rotation_to_zpl(element.rotation)
    show_text = if element.barcode_show_text, do: "Y", else: "N"

    case element.barcode_format do
      "CODE128" ->
        "^FO#{x},#{y}^BC#{rot},#{h},#{show_text},N,N^FD#{data}^FS"

      "CODE39" ->
        "^FO#{x},#{y}^B3#{rot},N,#{h},#{show_text},N^FD#{data}^FS"

      "CODE93" ->
        "^FO#{x},#{y}^BA#{rot},#{h},#{show_text},N,N^FD#{data}^FS"

      "EAN13" ->
        "^FO#{x},#{y}^BE#{rot},#{h},#{show_text},N^FD#{data}^FS"

      "EAN8" ->
        "^FO#{x},#{y}^B8#{rot},#{h},#{show_text},N^FD#{data}^FS"

      "UPC" ->
        "^FO#{x},#{y}^BU#{rot},#{h},#{show_text},N,Y^FD#{data}^FS"

      "ITF14" ->
        "^FO#{x},#{y}^BI#{rot},#{h},#{show_text},N^FD#{data}^FS"

      "CODABAR" ->
        "^FO#{x},#{y}^BK#{rot},N,#{h},#{show_text},N,A,A^FD#{data}^FS"

      "MSI" ->
        # MSI Plessey - use Code128 as fallback since ZPL has no native MSI
        "^FO#{x},#{y}^BC#{rot},#{h},#{show_text},N,N^FD#{data}^FS"

      "DATAMATRIX" ->
        mag = max(div(h, 20), 1)
        "^FO#{x},#{y}^BXN,#{mag},200^FD#{data}^FS"

      "PDF417" ->
        cols = max(div(h, 10), 1)
        "^FO#{x},#{y}^B7#{rot},#{cols},0,0,0,N^FD#{data}^FS"

      "AZTEC" ->
        mag = max(div(h, 20), 1)
        "^FO#{x},#{y}^BO#{rot},#{mag},N^FD#{data}^FS"

      "MAXICODE" ->
        "^FO#{x},#{y}^BD#{rot},1,Y^FD#{data}^FS"

      "POSTNET" ->
        "^FO#{x},#{y}^BZ#{rot},#{h},#{show_text},N^FD#{data}^FS"

      "PLANET" ->
        "^FO#{x},#{y}^BZ#{rot},#{h},#{show_text},N^FD#{data}^FS"

      f when f in ["GS1_128", "GS1_DATABAR", "GS1_DATABAR_STACKED", "GS1_DATABAR_EXPANDED"] ->
        "^FO#{x},#{y}^BC#{rot},#{h},#{show_text},N,N^FD#{data}^FS"

      _ ->
        # Fallback to Code 128
        "^FO#{x},#{y}^BC#{rot},#{h},#{show_text},N,N^FD#{data}^FS"
    end
  end

  # ── QR Code ──────────────────────────────────────────────────

  defp qr_to_zpl(element, row, context, x, y, dpmm) do
    data = ExpressionEvaluator.resolve_code_value(element, row, context)
    data = escape_zpl(data)
    size = mm_to_dots(element.width || 10, dpmm)
    mag = max(div(size, 30), 2)

    error_level = case element.qr_error_level do
      "L" -> "L"
      "Q" -> "Q"
      "H" -> "H"
      _ -> "M"
    end

    "^FO#{x},#{y}^BQN,2,#{mag},#{error_level}^FDQA,#{data}^FS"
  end

  # ── Shapes ───────────────────────────────────────────────────

  defp rectangle_to_zpl(element, x, y, dpmm) do
    w = mm_to_dots(element.width || 10, dpmm)
    h = mm_to_dots(element.height || 10, dpmm)
    border = mm_to_dots(element.border_width || 0.5, dpmm)
    border = max(border, 1)

    "^FO#{x},#{y}^GB#{w},#{h},#{border}^FS"
  end

  defp line_to_zpl(element, x, y, dpmm) do
    w = mm_to_dots(element.width || 10, dpmm)
    thickness = mm_to_dots(element.border_width || element.height || 0.5, dpmm)
    thickness = max(thickness, 1)

    "^FO#{x},#{y}^GB#{w},#{thickness},#{thickness}^FS"
  end

  defp circle_to_zpl(element, x, y, dpmm) do
    diameter = mm_to_dots(min(element.width || 10, element.height || 10), dpmm)
    border = mm_to_dots(element.border_width || 0.5, dpmm)
    border = max(border, 1)

    "^FO#{x},#{y}^GC#{diameter},#{border}^FS"
  end

  defp image_placeholder_to_zpl(element, x, y, dpmm) do
    w = mm_to_dots(element.width || 10, dpmm)
    h = mm_to_dots(element.height || 10, dpmm)

    # MVP: placeholder box for images
    "^FO#{x},#{y}^GB#{w},#{h},1^FS"
  end

  # ── Helpers ──────────────────────────────────────────────────

  defp mm_to_dots(mm, dpmm) when is_number(mm) do
    round(mm * dpmm)
  end
  defp mm_to_dots(_, _), do: 0

  defp rotation_to_zpl(nil), do: "N"
  defp rotation_to_zpl(deg) when is_number(deg) do
    normalized = rem(round(deg), 360)
    normalized = if normalized < 0, do: normalized + 360, else: normalized

    cond do
      normalized >= 315 or normalized < 45 -> "N"    # 0°
      normalized >= 45 and normalized < 135 -> "R"   # 90°
      normalized >= 135 and normalized < 225 -> "I"  # 180°
      true -> "B"                                     # 270°
    end
  end
  defp rotation_to_zpl(_), do: "N"

  defp escape_zpl(nil), do: ""
  defp escape_zpl(text) when is_binary(text) do
    text
    |> String.replace("^", " ")
    |> String.replace("~", " ")
  end
  defp escape_zpl(val), do: to_string(val) |> escape_zpl()
end
