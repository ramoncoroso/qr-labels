defmodule QrLabelSystem.Designs.SvgPreview do
  @moduledoc """
  Generates SVG previews for label designs.
  Used to show thumbnails in design selection screens.
  """

  @doc """
  Generates an SVG string representing the design with its elements.
  The SVG is scaled to fit within max_width x max_height while maintaining aspect ratio.
  """
  def generate(design, opts \\ []) do
    max_width = Keyword.get(opts, :max_width, 150)
    max_height = Keyword.get(opts, :max_height, 100)

    width_mm = design.width_mm || 50
    height_mm = design.height_mm || 30

    scale = min(max_width / width_mm, max_height / height_mm)

    svg_width = width_mm * scale
    svg_height = height_mm * scale

    elements_svg = render_elements(design.elements || [], scale)

    background_color = design.background_color || "#FFFFFF"
    border_color = design.border_color || "#CCCCCC"
    border_width = design.border_width || 1
    border_radius = (design.border_radius || 0) * scale

    svg_open = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"#{round(svg_width)}\" height=\"#{round(svg_height)}\" viewBox=\"0 0 #{svg_width} #{svg_height}\" style=\"pointer-events: none;\">"
    bg_rect = "<rect x=\"0.5\" y=\"0.5\" width=\"#{svg_width - 1}\" height=\"#{svg_height - 1}\" fill=\"#{background_color}\" stroke=\"#{border_color}\" stroke-width=\"#{border_width}\" rx=\"#{border_radius}\" ry=\"#{border_radius}\"/>"

    svg_open <> bg_rect <> elements_svg <> "</svg>"
  end

  defp render_elements(elements, scale) do
    elements
    |> Enum.map(fn el -> render_element(el, scale) end)
    |> Enum.join("")
  end

  defp render_element(element, scale) do
    type = get_field(element, :type)
    x = (get_field(element, :x) || 0) * scale
    y = (get_field(element, :y) || 0) * scale
    width = (get_field(element, :width) || 20) * scale
    height = (get_field(element, :height) || 20) * scale
    color = get_field(element, :color) || "#000000"
    rotation = get_field(element, :rotation) || 0

    transform =
      if rotation != 0 do
        cx = x + width / 2
        cy = y + height / 2
        " transform=\"rotate(#{rotation}, #{cx}, #{cy})\""
      else
        ""
      end

    case type do
      "qr" -> render_qr(x, y, width, height, color, transform)
      "barcode" -> render_barcode(x, y, width, height, color, transform)
      "text" -> render_text(element, x, y, width, height, scale, transform)
      "image" -> render_image(x, y, width, height, transform)
      _ -> ""
    end
  end

  defp render_qr(x, y, width, height, color, transform) do
    size = min(width, height)
    cell = size / 7

    "<g#{transform}>" <>
      "<rect x=\"#{x}\" y=\"#{y}\" width=\"#{size}\" height=\"#{size}\" fill=\"white\" stroke=\"#{color}\" stroke-width=\"0.5\"/>" <>
      "<rect x=\"#{x + cell * 0.5}\" y=\"#{y + cell * 0.5}\" width=\"#{cell * 2}\" height=\"#{cell * 2}\" fill=\"#{color}\"/>" <>
      "<rect x=\"#{x + cell * 4.5}\" y=\"#{y + cell * 0.5}\" width=\"#{cell * 2}\" height=\"#{cell * 2}\" fill=\"#{color}\"/>" <>
      "<rect x=\"#{x + cell * 0.5}\" y=\"#{y + cell * 4.5}\" width=\"#{cell * 2}\" height=\"#{cell * 2}\" fill=\"#{color}\"/>" <>
      "<rect x=\"#{x + cell * 3}\" y=\"#{y + cell * 3}\" width=\"#{cell}\" height=\"#{cell}\" fill=\"#{color}\"/>" <>
      "</g>"
  end

  defp render_barcode(x, y, width, height, color, transform) do
    bar_count = 12
    bar_width = width / (bar_count * 2)

    bars =
      Enum.map(0..(bar_count - 1), fn i ->
        bar_x = x + i * bar_width * 2
        bar_h = if rem(i, 3) == 0, do: height, else: height * 0.85
        bar_y = y + (height - bar_h) / 2
        "<rect x=\"#{bar_x}\" y=\"#{bar_y}\" width=\"#{bar_width}\" height=\"#{bar_h}\" fill=\"#{color}\"/>"
      end)

    "<g#{transform}>" <>
      "<rect x=\"#{x}\" y=\"#{y}\" width=\"#{width}\" height=\"#{height}\" fill=\"white\" stroke=\"#CCCCCC\" stroke-width=\"0.5\"/>" <>
      Enum.join(bars, "") <>
      "</g>"
  end

  defp render_text(element, x, y, width, height, scale, transform) do
    font_size = ((get_field(element, :font_size) || 10) * scale) |> min(14) |> max(6)
    font_family = get_field(element, :font_family) || "Arial"
    font_weight = get_field(element, :font_weight) || "normal"
    color = get_field(element, :color) || "#000000"
    text_align = get_field(element, :text_align) || "left"
    content = get_field(element, :text_content) || get_field(element, :binding) || "Texto"
    background = get_field(element, :background_color)

    display_text =
      if String.length(content || "") > 15 do
        String.slice(content, 0, 12) <> "..."
      else
        content || ""
      end

    {anchor, text_x} =
      case text_align do
        "center" -> {"middle", x + width / 2}
        "right" -> {"end", x + width}
        _ -> {"start", x}
      end

    text_y = y + height / 2 + font_size / 3

    bg_rect =
      if background && background != "" && background != "transparent" do
        "<rect x=\"#{x}\" y=\"#{y}\" width=\"#{width}\" height=\"#{height}\" fill=\"#{background}\"/>"
      else
        ""
      end

    "<g#{transform}>" <>
      bg_rect <>
      "<text x=\"#{text_x}\" y=\"#{text_y}\" font-family=\"#{font_family}\" font-size=\"#{font_size}\" font-weight=\"#{font_weight}\" fill=\"#{color}\" text-anchor=\"#{anchor}\">" <>
      escape_xml(display_text) <>
      "</text></g>"
  end

  defp render_image(x, y, width, height, transform) do
    icon_size = min(width, height) * 0.5
    icon_x = x + (width - icon_size) / 2
    icon_y = y + (height - icon_size) / 2

    "<g#{transform}>" <>
      "<rect x=\"#{x}\" y=\"#{y}\" width=\"#{width}\" height=\"#{height}\" fill=\"#F3F4F6\" stroke=\"#D1D5DB\" stroke-width=\"0.5\"/>" <>
      "<rect x=\"#{icon_x}\" y=\"#{icon_y}\" width=\"#{icon_size}\" height=\"#{icon_size * 0.7}\" fill=\"none\" stroke=\"#9CA3AF\" stroke-width=\"1\"/>" <>
      "<circle cx=\"#{icon_x + icon_size * 0.3}\" cy=\"#{icon_y + icon_size * 0.25}\" r=\"#{icon_size * 0.1}\" fill=\"#9CA3AF\"/>" <>
      "</g>"
  end

  defp get_field(element, key) when is_atom(key) do
    Map.get(element, key) || Map.get(element, Atom.to_string(key))
  end

  defp escape_xml(nil), do: ""

  defp escape_xml(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
