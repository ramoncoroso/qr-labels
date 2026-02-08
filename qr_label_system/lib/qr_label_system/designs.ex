defmodule QrLabelSystem.Designs do
  @moduledoc """
  The Designs context.
  Handles CRUD operations for label designs and elements.
  Includes export/import functionality for sharing designs.
  Uses caching for frequently accessed designs.
  """

  import Ecto.Query, warn: false
  alias QrLabelSystem.Repo
  alias QrLabelSystem.Cache
  alias QrLabelSystem.Designs.Design
  alias QrLabelSystem.Designs.Tag

  @cache_ttl 30_000  # 30 seconds - reduced to prevent stale data issues

  @doc """
  Returns the list of designs.
  """
  def list_designs do
    Repo.all(from d in Design, order_by: [desc: d.updated_at])
  end

  @doc """
  Returns the list of designs for a specific user.
  """
  def list_user_designs(user_id) do
    Repo.all(
      from d in Design,
        where: d.user_id == ^user_id,
        order_by: [desc: d.updated_at]
    )
  end

  @doc """
  Returns designs for a user with heavy binary data stripped from elements.
  Used for listing pages where image_data/qr_logo_data aren't needed.
  """
  def list_user_designs_light(user_id) do
    list_user_designs(user_id)
    |> Enum.map(&strip_heavy_element_data/1)
  end

  @doc """
  Strips image_data and qr_logo_data from a design's elements.
  """
  def strip_heavy_element_data(%Design{} = design) do
    light_elements = Enum.map(design.elements || [], fn el ->
      %{el | image_data: nil, qr_logo_data: nil}
    end)
    %{design | elements: light_elements}
  end

  @doc """
  Returns the list of designs for a specific user filtered by label type.
  Label type can be "single" or "multiple".
  """
  def list_user_designs_by_type(user_id, label_type) when label_type in ["single", "multiple"] do
    Repo.all(
      from d in Design,
        where: d.user_id == ^user_id and d.label_type == ^label_type,
        order_by: [desc: d.updated_at],
        preload: [:tags]
    )
  end

  @doc """
  Returns the list of template designs (available to all users).
  """
  def list_templates do
    Repo.all(
      from d in Design,
        where: d.is_template == true,
        order_by: [asc: d.name]
    )
  end

  @doc """
  Returns built-in system templates, preloaded with tags.
  """
  def list_system_templates do
    Repo.all(
      from d in Design,
        where: d.is_template == true and d.template_source == "system",
        order_by: [asc: d.name],
        preload: [:tags]
    )
  end

  @doc """
  Returns designs with pagination and optional filters.
  """
  def list_designs(params) do
    page = Map.get(params, "page", "1") |> parse_int(1)
    per_page = Map.get(params, "per_page", "20") |> parse_int(20)
    user_id = Map.get(params, "user_id")
    search = Map.get(params, "search", "")

    offset = (page - 1) * per_page

    base_query = from(d in Design, order_by: [desc: d.updated_at])

    query =
      base_query
      |> maybe_filter_by_user(user_id)
      |> maybe_search(search)

    designs = query |> limit(^per_page) |> offset(^offset) |> Repo.all()
    total = query |> Repo.aggregate(:count)

    %{
      designs: designs,
      page: page,
      per_page: per_page,
      total: total,
      total_pages: ceil(total / per_page)
    }
  end

  defp maybe_filter_by_user(query, nil), do: query
  defp maybe_filter_by_user(query, user_id) do
    from d in query, where: d.user_id == ^user_id or d.is_template == true
  end

  defp maybe_search(query, ""), do: query
  defp maybe_search(query, search) do
    # Sanitize LIKE special characters to prevent pattern injection
    sanitized = search
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")

    search_term = "%#{sanitized}%"
    from d in query, where: ilike(d.name, ^search_term) or ilike(d.description, ^search_term)
  end

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end
  defp parse_int(value, _default) when is_integer(value), do: value
  defp parse_int(_, default), do: default

  @doc """
  Gets a single design.
  Uses cache for frequently accessed designs.
  Raises Ecto.NoResultsError if not found.
  """
  def get_design!(id) do
    case Cache.get(:designs, {:design, id}) do
      {:ok, design} ->
        design

      :miss ->
        design = Repo.get!(Design, id)
        Cache.put(:designs, {:design, id}, design, ttl: @cache_ttl)
        design
    end
  end

  @doc """
  Gets a single design, returns nil if not found.
  Uses cache for frequently accessed designs.
  """
  def get_design(id) do
    case Cache.get(:designs, {:design, id}) do
      {:ok, design} -> design
      :miss ->
        case Repo.get(Design, id) do
          nil -> nil
          design ->
            Cache.put(:designs, {:design, id}, design, ttl: @cache_ttl)
            design
        end
    end
  end

  @doc """
  Creates a design.
  """
  def create_design(attrs \\ %{}) do
    %Design{}
    |> Design.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a design.
  Invalidates cache on update.

  Opts:
  - `:user_id` — if provided, creates a version snapshot asynchronously
  """
  def update_design(%Design{} = design, attrs, opts \\ []) do
    result = design
    |> Design.changeset(attrs)
    |> Repo.update()

    case result do
      {:ok, updated_design} ->
        Cache.delete(:designs, {:design, design.id})
        Cache.put(:designs, {:design, updated_design.id}, updated_design, ttl: @cache_ttl)

        # Create version snapshot in background if user_id provided
        user_id = Keyword.get(opts, :user_id)
        if user_id do
          Task.start(fn ->
            QrLabelSystem.Designs.Versioning.create_snapshot(updated_design, user_id)
          end)
        end

        {:ok, updated_design}

      error ->
        error
    end
  end

  @doc """
  Deletes a design.
  Invalidates cache on delete.
  """
  def delete_design(%Design{} = design) do
    result = Repo.delete(design)

    case result do
      {:ok, _} ->
        Cache.delete(:designs, {:design, design.id})
        result

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking design changes.
  """
  def change_design(%Design{} = design, attrs \\ %{}) do
    Design.changeset(design, attrs)
  end

  @doc """
  Duplicates a design. Generates a new name automatically.
  """
  def duplicate_design(%Design{} = design, user_id) do
    new_name = "#{design.name} (copia)"
    duplicate_design(design, new_name, user_id)
  end

  @doc """
  Duplicates a design with a specific new name.
  """
  def duplicate_design(%Design{} = design, new_name, user_id) do
    # Note: elements is an embedded schema, no need to preload
    design = Repo.preload(design, :tags)

    case design
         |> Design.duplicate_changeset(%{name: new_name, user_id: user_id})
         |> Repo.insert() do
      {:ok, new_design} ->
        # Copy tags to the new design
        tag_assignments =
          Enum.map(design.tags, fn tag ->
            %{design_id: new_design.id, tag_id: tag.id}
          end)

        if tag_assignments != [] do
          Repo.insert_all("design_tag_assignments", tag_assignments, on_conflict: :nothing)
        end

        {:ok, Repo.preload(new_design, :tags)}

      error ->
        error
    end
  end

  # ==========================================
  # EXPORT / IMPORT FUNCTIONALITY
  # ==========================================

  @doc """
  Exports a design to a JSON-compatible map.
  This can be saved as a file and shared with others.
  """
  def export_design(%Design{} = design) do
    %{
      version: "1.0",
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      design: %{
        name: design.name,
        description: design.description,
        width_mm: design.width_mm,
        height_mm: design.height_mm,
        background_color: design.background_color,
        border_width: design.border_width,
        border_color: design.border_color,
        border_radius: design.border_radius,
        elements: Enum.map(design.elements || [], &export_element/1)
      }
    }
  end

  defp export_element(element) do
    %{
      type: element.type,
      x: element.x,
      y: element.y,
      width: element.width,
      height: element.height,
      rotation: element.rotation,
      binding: element.binding,
      qr_error_level: element.qr_error_level,
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
      image_url: element.image_url
    }
  end

  @doc """
  Exports a design to JSON string.
  """
  def export_design_to_json(%Design{} = design) do
    design
    |> export_design()
    |> Jason.encode!(pretty: true)
  end

  @doc """
  Imports a design from a JSON string or map.
  Returns {:ok, design} or {:error, reason}.
  """
  def import_design(json_string, user_id) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, data} -> import_design(data, user_id)
      {:error, _} -> {:error, "Invalid JSON format"}
    end
  end

  def import_design(%{"design" => design_data} = data, user_id) do
    version = Map.get(data, "version", "1.0")

    case version do
      "1.0" -> import_v1_design(design_data, user_id)
      _ -> {:error, "Unsupported design version: #{version}"}
    end
  end

  def import_design(%{} = design_data, user_id) do
    # Handle case where design is at root level (no wrapper)
    import_v1_design(design_data, user_id)
  end

  def import_design(_, _), do: {:error, "Invalid design format"}

  defp import_v1_design(design_data, user_id) do
    elements =
      (design_data["elements"] || [])
      |> Enum.map(&import_element/1)

    attrs = %{
      name: design_data["name"] || "Imported Design",
      description: design_data["description"],
      width_mm: design_data["width_mm"],
      height_mm: design_data["height_mm"],
      background_color: design_data["background_color"] || "#FFFFFF",
      border_width: design_data["border_width"] || 0,
      border_color: design_data["border_color"] || "#000000",
      border_radius: design_data["border_radius"] || 0,
      user_id: user_id,
      elements: elements
    }

    create_design(attrs)
  end

  defp import_element(element_data) do
    %{
      id: "el_#{:erlang.unique_integer([:positive])}",
      type: element_data["type"],
      x: element_data["x"] || 0,
      y: element_data["y"] || 0,
      width: element_data["width"],
      height: element_data["height"],
      rotation: element_data["rotation"] || 0,
      binding: element_data["binding"],
      qr_error_level: element_data["qr_error_level"] || "M",
      barcode_format: element_data["barcode_format"] || "CODE128",
      barcode_show_text: element_data["barcode_show_text"] || false,
      font_size: element_data["font_size"] || 10,
      font_family: element_data["font_family"] || "Arial",
      font_weight: element_data["font_weight"] || "normal",
      text_align: element_data["text_align"] || "left",
      text_content: element_data["text_content"],
      color: element_data["color"] || "#000000",
      background_color: element_data["background_color"],
      border_width: element_data["border_width"] || 0,
      border_color: element_data["border_color"] || "#000000",
      image_url: element_data["image_url"]
    }
  end

  # ==========================================
  # BACKUP / RESTORE FUNCTIONALITY
  # ==========================================

  @doc """
  Exports all designs to a JSON string for backup.
  """
  def export_all_designs_to_json(designs) when is_list(designs) do
    backup = %{
      version: "1.0",
      type: "backup",
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      count: length(designs),
      designs: Enum.map(designs, fn design ->
        %{
          name: design.name,
          description: design.description,
          width_mm: design.width_mm,
          height_mm: design.height_mm,
          background_color: design.background_color,
          border_width: design.border_width,
          border_color: design.border_color,
          border_radius: design.border_radius,
          label_type: design.label_type,
          is_template: design.is_template,
          template_source: design.template_source,
          template_category: design.template_category,
          elements: Enum.map(design.elements || [], &export_element/1)
        }
      end)
    }

    Jason.encode!(backup, pretty: true)
  end

  @doc """
  Imports multiple designs from a backup JSON string.
  Returns {:ok, imported_designs} or {:error, reason}.
  """
  def import_designs_from_json(json_string, user_id) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, %{"type" => "backup", "designs" => designs_data}} ->
        import_backup_designs(designs_data, user_id)

      {:ok, %{"design" => _} = single_design} ->
        # Handle single design export format
        case import_design(single_design, user_id) do
          {:ok, design} -> {:ok, [design]}
          error -> error
        end

      {:ok, _} ->
        {:error, "Formato de archivo no reconocido"}

      {:error, _} ->
        {:error, "JSON inválido"}
    end
  end

  @doc """
  Imports a list of design data maps directly (used by the import modal).
  """
  def import_designs_list(designs_data, user_id) when is_list(designs_data) do
    import_backup_designs(designs_data, user_id)
  end

  defp import_backup_designs(designs_data, user_id) when is_list(designs_data) do
    results =
      Enum.reduce_while(designs_data, {:ok, []}, fn design_data, {:ok, acc} ->
        case import_single_backup_design(design_data, user_id) do
          {:ok, design} -> {:cont, {:ok, [design | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case results do
      {:ok, designs} -> {:ok, Enum.reverse(designs)}
      error -> error
    end
  end

  defp import_single_backup_design(design_data, user_id) do
    elements =
      (design_data["elements"] || [])
      |> Enum.map(&import_element/1)

    attrs = %{
      name: design_data["name"] || "Diseño importado",
      description: design_data["description"],
      width_mm: design_data["width_mm"],
      height_mm: design_data["height_mm"],
      background_color: design_data["background_color"] || "#FFFFFF",
      border_width: design_data["border_width"] || 0,
      border_color: design_data["border_color"] || "#000000",
      border_radius: design_data["border_radius"] || 0,
      label_type: design_data["label_type"] || "single",
      is_template: design_data["is_template"] || false,
      template_source: design_data["template_source"],
      template_category: design_data["template_category"],
      user_id: user_id,
      elements: elements
    }

    create_design(attrs)
  end

  # ==========================================
  # TAG FUNCTIONS
  # ==========================================

  @doc """
  Returns the list of tags for a specific user.
  """
  def list_user_tags(user_id) do
    Repo.all(
      from t in Tag,
        where: t.user_id == ^user_id,
        order_by: [asc: t.name]
    )
  end

  @doc """
  Gets a single tag.
  """
  def get_tag(id), do: Repo.get(Tag, id)

  @doc """
  Gets a single tag, raises if not found.
  """
  def get_tag!(id), do: Repo.get!(Tag, id)

  @doc """
  Creates a tag.
  """
  def create_tag(attrs) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Finds an existing tag by name for a user, or creates it if it doesn't exist.
  """
  def find_or_create_tag(user_id, name, color \\ "#6366F1") do
    name = String.trim(name)

    case Repo.one(from t in Tag, where: t.user_id == ^user_id and t.name == ^name) do
      nil -> create_tag(%{user_id: user_id, name: name, color: color})
      tag -> {:ok, tag}
    end
  end

  @doc """
  Deletes a tag.
  """
  def delete_tag(%Tag{} = tag) do
    Repo.delete(tag)
  end

  @doc """
  Adds a tag to a design. Uses on_conflict: :nothing to avoid duplicates.
  """
  def add_tag_to_design(%Design{} = design, %Tag{} = tag) do
    Repo.insert_all(
      "design_tag_assignments",
      [%{design_id: design.id, tag_id: tag.id}],
      on_conflict: :nothing
    )

    {:ok, Repo.preload(design, :tags, force: true)}
  end

  @doc """
  Removes a tag from a design.
  """
  def remove_tag_from_design(%Design{} = design, tag_id) do
    from(dta in "design_tag_assignments",
      where: dta.design_id == ^design.id and dta.tag_id == ^tag_id
    )
    |> Repo.delete_all()

    {:ok, Repo.preload(design, :tags, force: true)}
  end

  @doc """
  Preloads tags for a design or list of designs.
  """
  def preload_tags(design_or_designs) do
    Repo.preload(design_or_designs, :tags)
  end

  @doc """
  Searches user tags by name prefix for autocompletado.
  Returns up to 10 matching tags.
  """
  def search_user_tags(user_id, prefix) do
    sanitized = prefix
      |> String.replace("\\", "\\\\")
      |> String.replace("%", "\\%")
      |> String.replace("_", "\\_")

    search_term = "#{sanitized}%"

    Repo.all(
      from t in Tag,
        where: t.user_id == ^user_id and ilike(t.name, ^search_term),
        order_by: [asc: t.name],
        limit: 10
    )
  end

  @doc """
  Returns designs for a user filtered by tag IDs.
  A design must have ALL specified tags to be included.
  """
  def list_user_designs_by_tags(user_id, tag_ids) when tag_ids == [] do
    list_user_designs(user_id)
  end

  def list_user_designs_by_tags(user_id, tag_ids) do
    tag_count = length(tag_ids)

    Repo.all(
      from d in Design,
        join: dta in "design_tag_assignments", on: dta.design_id == d.id,
        where: d.user_id == ^user_id and dta.tag_id in ^tag_ids,
        group_by: d.id,
        having: count(dta.tag_id) == ^tag_count,
        order_by: [desc: d.updated_at]
    )
  end
end
