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
  alias QrLabelSystem.Designs.ElementGroup
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

    # Approval workflow status
    field :status, :string, default: "draft"

    # Regulatory compliance standard (nil = no compliance check)
    field :compliance_standard, :string

    # Elements on the label
    # IMPORTANT: Using :delete means elements not in the new data will be removed
    # This requires the client to ALWAYS send ALL elements, even unchanged ones
    embeds_many :elements, Element, on_replace: :delete
    embeds_many :groups, ElementGroup, on_replace: :delete

    belongs_to :user, QrLabelSystem.Accounts.User
    has_many :versions, QrLabelSystem.Designs.DesignVersion
    has_many :approvals, QrLabelSystem.Designs.DesignApproval
    many_to_many :tags, Tag, join_through: "design_tag_assignments"

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating a design.
  """
  @valid_statuses ~w(draft pending_review approved archived)
  @valid_compliance_standards ~w(gs1 eu1169 fmd)

  def changeset(design, attrs) do
    design
    |> cast(attrs, [
      :name, :description,
      :width_mm, :height_mm,
      :background_color, :border_width, :border_color, :border_radius,
      :is_template, :template_source, :template_category, :label_type, :user_id,
      :status, :compliance_standard
    ])
    |> validate_inclusion(:template_source, ~w(system user), message: "must be system or user")
    |> validate_inclusion(:template_category, ~w(alimentacion farmaceutica logistica manufactura retail), message: "must be a valid category")
    |> validate_inclusion(:status, @valid_statuses, message: "must be draft, pending_review, approved, or archived")
    |> validate_compliance_standard()
    |> cast_embed(:elements, with: &Element.changeset/2)
    |> cast_embed(:groups, with: &ElementGroup.changeset/2)
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
    |> put_change(:compliance_standard, design.compliance_standard)
    |> put_embed(:elements, design.elements)
    |> put_embed(:groups, design.groups || [])
    |> validate_required([:name, :width_mm, :height_mm])
  end

  defp validate_compliance_standard(changeset) do
    value = get_field(changeset, :compliance_standard)

    if value && value not in @valid_compliance_standards do
      add_error(changeset, :compliance_standard, "must be one of: #{Enum.join(@valid_compliance_standards, ", ")}")
    else
      changeset
    end
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
      compliance_standard: design.compliance_standard,
      elements: Enum.map(design.elements || [], &element_to_json/1),
      groups: Enum.map(design.groups || [], &group_to_json/1)
    }
  end

  @doc """
  Returns the design as JSON without heavy binary data (image_data, qr_logo_data).
  Used for undo/redo, batch generation, and preview where the canvas already has images loaded.
  """
  def to_json_light(%__MODULE__{} = design) do
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
      compliance_standard: design.compliance_standard,
      elements: Enum.map(design.elements || [], &element_to_json_light/1),
      groups: Enum.map(design.groups || [], &group_to_json/1)
    }
  end

  defp element_to_json_light(element) do
    element
    |> element_to_json()
    |> Map.put(:image_data, nil)
    |> Map.put(:qr_logo_data, nil)
  end

  def status_changeset(design, status) when status in @valid_statuses do
    design
    |> cast(%{status: status}, [:status])
    |> validate_inclusion(:status, @valid_statuses)
  end

  def approved?(%__MODULE__{status: "approved"}), do: true
  def approved?(_), do: false

  def editable?(%__MODULE__{status: status}) when status in ~w(draft pending_review), do: true
  def editable?(_), do: false

  def printable?(%__MODULE__{status: "approved"}), do: true
  def printable?(%__MODULE__{status: "draft"}), do: true
  def printable?(_), do: false

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
      text_auto_fit: element.text_auto_fit,
      text_min_font_size: element.text_min_font_size,
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
      image_filename: element.image_filename,
      # Group membership
      group_id: element.group_id
    }
  end

  defp group_to_json(group) do
    %{
      id: group.id,
      name: group.name,
      locked: group.locked,
      visible: group.visible,
      collapsed: group.collapsed
    }
  end
end
