defmodule QrLabelSystemWeb.DesignComponents do
  @moduledoc """
  Server-side rendered thumbnail components for label designs.
  """
  use Phoenix.Component

  @mm_to_px 3.78

  attr :design, :map, required: true
  attr :max_width, :integer, default: 80
  attr :max_height, :integer, default: 64

  def design_thumbnail(assigns) do
    design = assigns.design
    label_w_px = design.width_mm * @mm_to_px
    label_h_px = design.height_mm * @mm_to_px

    scale =
      min(assigns.max_width / max(label_w_px, 1), assigns.max_height / max(label_h_px, 1))

    thumb_w = label_w_px * scale
    thumb_h = label_h_px * scale

    visible_elements =
      (design.elements || [])
      |> Enum.filter(& &1.visible)
      |> Enum.sort_by(& &1.z_index)

    border_w = min((design.border_width || 0) * scale * @mm_to_px, 3)

    assigns =
      assigns
      |> assign(:thumb_w, thumb_w)
      |> assign(:thumb_h, thumb_h)
      |> assign(:scale, scale)
      |> assign(:visible_elements, visible_elements)
      |> assign(:border_w, border_w)

    ~H"""
    <div
      style={"width: #{@thumb_w}px; height: #{@thumb_h}px; position: relative; overflow: hidden; background-color: #{@design.background_color || "#FFFFFF"}; border: #{@border_w}px solid #{@design.border_color || "#000000"}; border-radius: #{(@design.border_radius || 0) * @scale}px;"}
      class="flex-shrink-0"
    >
      <%= if @visible_elements == [] do %>
        <div class="flex items-center justify-center w-full h-full">
          <span style="font-size: 6px; color: #9CA3AF;">Sin elementos</span>
        </div>
      <% else %>
        <.thumbnail_element
          :for={element <- @visible_elements}
          element={element}
          scale={@scale}
        />
      <% end %>
    </div>
    """
  end

  attr :element, :map, required: true
  attr :scale, :float, required: true

  defp thumbnail_element(assigns) do
    el = assigns.element
    s = assigns.scale

    left = (el.x || 0) * s * @mm_to_px
    top = (el.y || 0) * s * @mm_to_px
    w = (el.width || 0) * s * @mm_to_px
    h = (el.height || 0) * s * @mm_to_px
    rotation = el.rotation || 0

    base_style =
      "position: absolute; left: #{left}px; top: #{top}px; width: #{w}px; height: #{h}px; overflow: hidden;" <>
        if(rotation != 0, do: " transform: rotate(#{rotation}deg);", else: "")

    assigns =
      assigns
      |> assign(:base_style, base_style)
      |> assign(:w, w)
      |> assign(:h, h)
      |> assign(:s, s)

    case el.type do
      "qr" -> thumbnail_qr(assigns)
      "barcode" -> thumbnail_barcode(assigns)
      "text" -> thumbnail_text(assigns)
      "line" -> thumbnail_line(assigns)
      "rectangle" -> thumbnail_rectangle(assigns)
      "circle" -> thumbnail_circle(assigns)
      "image" -> thumbnail_image(assigns)
      _ -> thumbnail_fallback(assigns)
    end
  end

  defp thumbnail_qr(assigns) do
    ~H"""
    <div style={@base_style}>
      <svg viewBox="0 0 100 100" width={"#{@w}"} height={"#{@h}"} style="display: block;">
        <rect width="100" height="100" fill="white" />
        <rect x="5" y="5" width="30" height="30" fill="none" stroke="black" stroke-width="4" />
        <rect x="12" y="12" width="16" height="16" fill="black" />
        <rect x="65" y="5" width="30" height="30" fill="none" stroke="black" stroke-width="4" />
        <rect x="72" y="12" width="16" height="16" fill="black" />
        <rect x="5" y="65" width="30" height="30" fill="none" stroke="black" stroke-width="4" />
        <rect x="12" y="72" width="16" height="16" fill="black" />
        <rect x="42" y="42" width="6" height="6" fill="black" />
        <rect x="52" y="42" width="6" height="6" fill="black" />
        <rect x="42" y="52" width="6" height="6" fill="black" />
        <rect x="52" y="52" width="6" height="6" fill="black" />
        <rect x="62" y="52" width="6" height="6" fill="black" />
        <rect x="72" y="62" width="6" height="6" fill="black" />
        <rect x="82" y="72" width="6" height="6" fill="black" />
        <rect x="62" y="82" width="6" height="6" fill="black" />
      </svg>
    </div>
    """
  end

  defp thumbnail_barcode(assigns) do
    ~H"""
    <div style={"#{@base_style} background: white; display: flex; align-items: center; justify-content: center; gap: 0;"}>
      <div style="display: flex; align-items: stretch; height: 80%; width: 80%; gap: 0;">
        <div :for={
          w <- [2, 1, 1, 3, 1, 2, 1, 1, 3, 1, 2, 1, 1, 2, 3, 1, 1, 2, 1, 1]
        } style={"width: #{w}px; flex-shrink: 0; background: black; margin-right: 1px; min-width: 0.5px;"}></div>
      </div>
    </div>
    """
  end

  defp thumbnail_text(assigns) do
    el = assigns.element
    s = assigns.s
    font_size = max((el.font_size || 10) * s * @mm_to_px / 3, 2)
    color = el.color || "#000000"
    font_weight = el.font_weight || "normal"
    text_align = el.text_align || "left"
    content = el.text_content || el.binding || "Texto"

    assigns =
      assigns
      |> assign(:font_size, font_size)
      |> assign(:color, color)
      |> assign(:font_weight, font_weight)
      |> assign(:text_align, text_align)
      |> assign(:content, content)

    ~H"""
    <div style={"#{@base_style} font-size: #{@font_size}px; color: #{@color}; font-weight: #{@font_weight}; text-align: #{@text_align}; line-height: 1.2; white-space: nowrap;"}>
      {@content}
    </div>
    """
  end

  defp thumbnail_line(assigns) do
    el = assigns.element
    color = el.color || "#000000"

    assigns = assign(assigns, :color, color)

    ~H"""
    <div style={"#{@base_style} background-color: #{@color};"}></div>
    """
  end

  defp thumbnail_rectangle(assigns) do
    el = assigns.element
    s = assigns.s
    bg = el.background_color || "transparent"
    border_w = min((el.border_width || 0) * s * @mm_to_px, 2)
    border_c = el.border_color || "#000000"

    assigns =
      assigns
      |> assign(:bg, bg)
      |> assign(:border_w, border_w)
      |> assign(:border_c, border_c)

    ~H"""
    <div style={"#{@base_style} background-color: #{@bg}; border: #{@border_w}px solid #{@border_c};"}></div>
    """
  end

  defp thumbnail_circle(assigns) do
    el = assigns.element
    s = assigns.s
    bg = el.background_color || "transparent"
    border_w = min((el.border_width || 0) * s * @mm_to_px, 2)
    border_c = el.border_color || "#000000"
    br = el.border_radius || 100

    assigns =
      assigns
      |> assign(:bg, bg)
      |> assign(:border_w, border_w)
      |> assign(:border_c, border_c)
      |> assign(:br, br)

    ~H"""
    <div style={"#{@base_style} background-color: #{@bg}; border: #{@border_w}px solid #{@border_c}; border-radius: #{@br}%;"}></div>
    """
  end

  defp thumbnail_image(assigns) do
    ~H"""
    <div style={"#{@base_style} background-color: #E5E7EB; display: flex; align-items: center; justify-content: center;"}>
      <svg
        style={"width: #{max(@w * 0.4, 4)}px; height: #{max(@h * 0.4, 4)}px;"}
        viewBox="0 0 24 24"
        fill="none"
        stroke="#9CA3AF"
        stroke-width="1.5"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5A2.25 2.25 0 0022.5 18.75V5.25A2.25 2.25 0 0020.25 3H3.75A2.25 2.25 0 001.5 5.25v13.5A2.25 2.25 0 003.75 21zM10.5 8.25a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z"
        />
      </svg>
    </div>
    """
  end

  defp thumbnail_fallback(assigns) do
    ~H"""
    <div style={"#{@base_style} background-color: #D1D5DB;"}></div>
    """
  end
end
