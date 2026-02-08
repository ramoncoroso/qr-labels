defmodule QrLabelSystem.Designs.Design do
  @moduledoc """
  Schema for label designs.

  A design defines:
  - Physical dimensions (width x height in mm)
  - Visual elements (QR codes, barcodes, text, lines, etc.)
  - Global styling (background, border)

  Elements are stored as embedded schemas and can be bound to
  data columns for dynamic content generation.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias QrLabelSystem.Designs.Element
  alias QrLabelSystem.Designs.Tag

  schema "label_designs" do
    field :name, :string
    field :description, :string

    # Dimensions in millimeters
    field :width_mm, :float
    field :height_mm, :float

    # Global styling
    field :background_color, :string, default: "#FFFFFF"
    field :border_width, :float, default: 0.0
    field :border_color, :string, default: "#000000"
    field :border_radius, :float, default: 0.0

    # Template flag for reusable designs
    field :is_template, :boolean, default: false
    # Template source: "system" (built-in), "user" (user-created), nil (not a template)
    field :template_source, :string
    # Template category for system templates: "alimentacion", "farmaceutica", "logistica", "manufactura"
    field :template_category, :string

    # Label type: "single" for static labels, "multiple" for data-bound labels
    field :label_type, :string, default: "single"

    # Elements on the label
    # IMPORTANT: Using :delete means elements not in the new data will be removed
    # This requires the client to ALWAYS send ALL elements, even unchanged ones
    embeds_many :elements, Element, on_replace: :delete

    belongs_to :user, QrLabelSystem.Accounts.User
    many_to_many :tags, Tag, join_through: "design_tag_assignments"

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating a design.
  """
  def changeset(design, attrs) do
    design
    |> cast(attrs, [
      :name, :description,
      :width_mm, :height_mm,
      :background_color, :border_width, :border_color, :border_radius,
      :is_template, :template_source, :template_category, :label_type, :user_id
    ])
    |> validate_inclusion(:template_source, ~w(system user), message: "must be system or user")
    |> validate_inclusion(:template_category, ~w(alimentacion farmaceutica logistica manufactura retail), message: "must be a valid category")
    |> cast_embed(:elements, with: &Element.changeset/2)
    |> validate_required([:name, :width_mm, :height_mm])
    |> validate_number(:width_mm, greater_than: 0, less_than_or_equal_to: 500)
    |> validate_number(:height_mm, greater_than: 0, less_than_or_equal_to: 500)
    |> validate_number(:border_width, greater_than_or_equal_to: 0)
    |> validate_number(:border_radius, greater_than_or_equal_to: 0)
    |> validate_color(:background_color)
    |> validate_color(:border_color)
  end

  @doc """
  Changeset for duplicating a design.
  """
  def duplicate_changeset(design, attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name, :user_id, :label_type])
    |> put_change(:description, design.description)
    |> put_change(:width_mm, design.width_mm)
    |> put_change(:height_mm, design.height_mm)
    |> put_change(:background_color, design.background_color)
    |> put_change(:border_width, design.border_width)
    |> put_change(:border_color, design.border_color)
    |> put_change(:border_radius, design.border_radius)
    |> put_change(:is_template, false)
    |> put_change(:template_source, nil)
    |> put_change(:template_category, nil)
    |> put_change(:label_type, design.label_type)
    |> put_embed(:elements, design.elements)
    |> validate_required([:name, :width_mm, :height_mm])
  end

  defp validate_color(changeset, field) do
    value = get_field(changeset, field)

    if value && !Regex.match?(~r/^#[0-9A-Fa-f]{6}$/, value) do
      add_error(changeset, field, "must be a valid hex color (e.g., #FFFFFF)")
    else
      changeset
    end
  end

  @doc """
  Returns the design as a map suitable for JSON serialization to the frontend.
  """
  def to_json(%__MODULE__{} = design) do
    %{
      id: design.id,
      name: design.name,
      description: design.description,
      width_mm: design.width_mm,
      height_mm: design.height_mm,
      background_color: design.background_color,
      border_width: design.border_width,
      border_color: design.border_color,
      border_radius: design.border_radius,
      label_type: design.label_type,
      template_source: design.template_source,
      template_category: design.template_category,
      elements: Enum.map(design.elements || [], &element_to_json/1)
    }
  end

  defp element_to_json(element) do
    %{
      id: element.id,
      type: element.type,
      x: element.x,
      y: element.y,
      width: element.width,
      height: element.height,
      rotation: element.rotation,
      binding: element.binding,
      qr_error_level: element.qr_error_level,
      qr_logo_data: element.qr_logo_data,
      qr_logo_size: element.qr_logo_size,
      barcode_format: element.barcode_format,
      barcode_show_text: element.barcode_show_text,
      font_size: element.font_size,
      font_family: element.font_family,
      font_weight: element.font_weight,
      text_align: element.text_align,
      text_content: element.text_content,
      color: element.color,
      background_color: element.background_color,
      border_width: element.border_width,
      border_color: element.border_color,
      border_radius: element.border_radius,
      image_url: element.image_url,
      # Layer management fields - CRITICAL for persistence
      z_index: element.z_index,
      visible: element.visible,
      locked: element.locked,
      name: element.name,
      # Image data fields
      image_data: element.image_data,
      image_filename: element.image_filename
    }
  end
end
