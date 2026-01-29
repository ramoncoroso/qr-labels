defmodule QrLabelSystem.Designs.Element do
  @moduledoc """
  Embedded schema for label design elements.

  Each element represents a visual component on the label:
  - QR code
  - Barcode (various formats)
  - Text field
  - Line
  - Rectangle
  - Image/Logo

  Elements have position (x, y in mm), size, styling, and can be
  bound to data columns from Excel or database sources.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @element_types ~w(qr barcode text line rectangle image)
  @barcode_formats ~w(CODE128 CODE39 EAN13 EAN8 UPC ITF14 pharmacode)

  @primary_key false
  embedded_schema do
    field :id, :string
    field :type, :string
    field :x, :float, default: 0.0
    field :y, :float, default: 0.0
    field :width, :float
    field :height, :float
    field :rotation, :float, default: 0.0

    # Binding to data column (for dynamic content)
    field :binding, :string

    # QR specific
    field :qr_error_level, :string, default: "M"

    # Barcode specific
    field :barcode_format, :string, default: "CODE128"
    field :barcode_show_text, :boolean, default: false

    # Text specific
    field :font_size, :float, default: 10.0
    field :font_family, :string, default: "Arial"
    field :font_weight, :string, default: "normal"
    field :text_align, :string, default: "left"
    field :text_content, :string

    # Styling
    field :color, :string, default: "#000000"
    field :background_color, :string
    field :border_width, :float, default: 0.0
    field :border_color, :string, default: "#000000"

    # Image specific
    field :image_url, :string
  end

  def changeset(element, attrs) do
    element
    |> cast(attrs, [
      :id, :type, :x, :y, :width, :height, :rotation,
      :binding,
      :qr_error_level,
      :barcode_format, :barcode_show_text,
      :font_size, :font_family, :font_weight, :text_align, :text_content,
      :color, :background_color, :border_width, :border_color,
      :image_url
    ])
    |> validate_required([:id, :type, :x, :y])
    |> validate_inclusion(:type, @element_types)
    |> validate_barcode_format()
    |> validate_qr_error_level()
    |> generate_id_if_missing()
  end

  defp validate_barcode_format(changeset) do
    type = get_field(changeset, :type)
    format = get_field(changeset, :barcode_format)

    if type == "barcode" and format not in @barcode_formats do
      add_error(changeset, :barcode_format, "must be one of: #{Enum.join(@barcode_formats, ", ")}")
    else
      changeset
    end
  end

  defp validate_qr_error_level(changeset) do
    type = get_field(changeset, :type)
    level = get_field(changeset, :qr_error_level)

    if type == "qr" and level not in ~w(L M Q H) do
      add_error(changeset, :qr_error_level, "must be one of: L, M, Q, H")
    else
      changeset
    end
  end

  defp generate_id_if_missing(changeset) do
    if get_field(changeset, :id) do
      changeset
    else
      put_change(changeset, :id, "el_#{:erlang.unique_integer([:positive])}")
    end
  end

  def element_types, do: @element_types
  def barcode_formats, do: @barcode_formats
end
