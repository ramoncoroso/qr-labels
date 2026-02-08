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

  @element_types ~w(qr barcode text line rectangle image circle)
  @barcode_formats ~w(CODE128 CODE39 EAN13 EAN8 UPC ITF14 pharmacode
    GS1_128 GS1_DATABAR GS1_DATABAR_STACKED GS1_DATABAR_EXPANDED
    CODE93 MSI CODABAR
    DATAMATRIX PDF417 AZTEC MAXICODE
    POSTNET PLANET ROYALMAIL)

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
    field :qr_logo_data, :string       # Base64 encoded logo for QR overlay
    field :qr_logo_size, :float, default: 25.0  # Logo size as % of QR area (5-30)

    # Barcode specific
    field :barcode_format, :string, default: "CODE128"
    field :barcode_show_text, :boolean, default: false

    # Text specific
    field :font_size, :float, default: 10.0
    field :font_family, :string, default: "Arial"
    field :font_weight, :string, default: "normal"
    field :text_align, :string, default: "left"
    field :text_content, :string
    field :text_auto_fit, :boolean, default: false
    field :text_min_font_size, :float, default: 6.0

    # Styling
    field :color, :string, default: "#000000"
    field :background_color, :string
    field :border_width, :float, default: 0.0
    field :border_color, :string, default: "#000000"
    field :border_radius, :float, default: 0.0  # 0=rectangle, 100=ellipse (circle default set in create_default_element)

    # Image specific
    field :image_url, :string
    field :image_data, :string      # Base64 encoded image data
    field :image_filename, :string  # Original filename

    # Layer management
    field :z_index, :integer, default: 0
    field :visible, :boolean, default: true
    field :locked, :boolean, default: false
    field :name, :string  # Friendly name for layer panel
  end

  @max_image_size 2_000_000  # 2MB limit for image data

  def changeset(element, attrs) do
    element
    |> cast(attrs, [
      :id, :type, :x, :y, :width, :height, :rotation,
      :binding,
      :qr_error_level, :qr_logo_data, :qr_logo_size,
      :barcode_format, :barcode_show_text,
      :font_size, :font_family, :font_weight, :text_align, :text_content,
      :text_auto_fit, :text_min_font_size,
      :color, :background_color, :border_width, :border_color, :border_radius,
      :image_url, :image_data, :image_filename,
      :z_index, :visible, :locked, :name
    ])
    |> generate_id_if_missing()
    |> generate_name_if_missing()
    |> validate_required([:id, :type, :x, :y])
    |> validate_inclusion(:type, @element_types)
    |> validate_barcode_format()
    |> validate_qr_error_level()
    |> validate_qr_logo()
    |> validate_image_data_size()
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

  @max_qr_logo_size 500_000  # 500KB limit for QR logo

  defp validate_qr_logo(changeset) do
    logo_data = get_field(changeset, :qr_logo_data)
    logo_size = get_field(changeset, :qr_logo_size)

    changeset
    |> then(fn cs ->
      if logo_data && byte_size(logo_data) > @max_qr_logo_size do
        add_error(cs, :qr_logo_data, "logo too large, maximum size is 500KB")
      else
        cs
      end
    end)
    |> then(fn cs ->
      if logo_size && (logo_size < 5.0 or logo_size > 30.0) do
        add_error(cs, :qr_logo_size, "must be between 5% and 30%")
      else
        cs
      end
    end)
  end

  defp generate_id_if_missing(changeset) do
    if get_field(changeset, :id) do
      changeset
    else
      put_change(changeset, :id, "el_#{:erlang.unique_integer([:positive])}")
    end
  end

  defp generate_name_if_missing(changeset) do
    if get_field(changeset, :name) do
      changeset
    else
      type = get_field(changeset, :type)
      type_name = case type do
        "qr" -> "Código QR"
        "barcode" -> "Código de Barras"
        "text" -> "Texto"
        "line" -> "Línea"
        "rectangle" -> "Rectángulo"
        "image" -> "Imagen"
        "circle" -> "Círculo"
        _ -> "Elemento"
      end
      put_change(changeset, :name, type_name)
    end
  end

  defp validate_image_data_size(changeset) do
    image_data = get_field(changeset, :image_data)

    if image_data && byte_size(image_data) > @max_image_size do
      add_error(changeset, :image_data, "image too large, maximum size is 2MB")
    else
      changeset
    end
  end

  def element_types, do: @element_types
  def barcode_formats, do: @barcode_formats
end
