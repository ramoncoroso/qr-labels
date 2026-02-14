defmodule QrLabelSystemWeb.DesignLive.Editor do
  use QrLabelSystemWeb, :live_view

  require Logger

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Designs.Design
  alias QrLabelSystem.Designs.Versioning
  alias QrLabelSystem.Export.ExpressionEvaluator
  alias QrLabelSystem.Security.FileSanitizer
  alias QrLabelSystem.Settings
  alias QrLabelSystem.Accounts.User
  alias QrLabelSystem.Compliance

  # Expression pattern definitions for visual builder
  @expression_patterns [
    %{id: :uppercase, icon: "Aa", color: "blue", needs_column: true,
      description: "A mayusculas"},
    %{id: :lowercase, icon: "aa", color: "blue", needs_column: true,
      description: "A minusculas"},
    %{id: :today, icon: "📅", color: "emerald", needs_column: false,
      description: "Fecha de hoy"},
    %{id: :counter, icon: "#", color: "amber", needs_column: false,
      description: "Numeracion 1, 2, 3..."},
    %{id: :batch, icon: "⚙", color: "amber", needs_column: false,
      description: "Codigo de lote"},
    %{id: :expiry, icon: "+", color: "emerald", needs_column: false,
      description: "Fecha + N dias"},
    %{id: :conditional, icon: "?", color: "violet", needs_column: true,
      description: "Si vacio, mostrar..."},
    %{id: :format_number, icon: "0.0", color: "amber", needs_column: true,
      description: "Formato numerico"}
  ]

  # Available languages for multi-language label support
  @available_languages [
    {"es", "Español", "🇪🇸"},
    {"en", "Inglés", "🇬🇧"},
    {"fr", "Francés", "🇫🇷"},
    {"de", "Alemán", "🇩🇪"},
    {"it", "Italiano", "🇮🇹"},
    {"pt", "Portugués", "🇵🇹"},
    {"nl", "Neerlandés", "🇳🇱"},
    {"pl", "Polaco", "🇵🇱"},
    {"ro", "Rumano", "🇷🇴"},
    {"sv", "Sueco", "🇸🇪"},
    {"da", "Danés", "🇩🇰"},
    {"fi", "Finés", "🇫🇮"},
    {"el", "Griego", "🇬🇷"},
    {"hu", "Húngaro", "🇭🇺"},
    {"cs", "Checo", "🇨🇿"},
    {"bg", "Búlgaro", "🇧🇬"},
    {"hr", "Croata", "🇭🇷"},
    {"zh", "Chino", "🇨🇳"},
    {"ja", "Japonés", "🇯🇵"},
    {"ko", "Coreano", "🇰🇷"},
    {"ar", "Árabe", "🇸🇦"}
  ]

  # Whitelist of allowed fields for element updates (security)
  @allowed_element_fields ~w(x y width height rotation binding qr_error_level
    qr_logo_data qr_logo_size
    barcode_format barcode_show_text font_size font_family font_weight
    text_align text_content text_auto_fit text_min_font_size
    color background_color border_width border_color border_radius
    z_index visible locked name image_data image_filename group_id compliance_role translations)

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    case Designs.get_design(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Este diseño ha sido eliminado o no existe")
         |> push_navigate(to: ~p"/designs")}

      design when design.workspace_id != socket.assigns.current_workspace.id ->
        {:ok,
         socket
         |> put_flash(:error, "No tienes permiso para editar este diseño")
         |> push_navigate(to: ~p"/designs")}

      design ->
      # Debug: Log design elements on mount
      element_count = length(design.elements || [])
      element_ids = Enum.map(design.elements || [], fn el ->
        Map.get(el, :id) || Map.get(el, "id")
      end)
      Logger.info("Editor mount - Design #{id}: #{element_count} elements, IDs: #{inspect(element_ids)}")

      # Load metadata from persistent store (from data-first flow)
      # Full row data lives in the browser's IndexedDB
      user_id = socket.assigns.current_user.id
      {available_columns, upload_total_rows, upload_sample_rows} = QrLabelSystem.UploadDataStore.get_metadata(user_id, design.id)
      Logger.info("Editor mount - Design #{id} (#{design.label_type}): total_rows=#{upload_total_rows}, columns=#{inspect(available_columns)}")

      # Build preview data from first sample row if we have data
      preview_data = case upload_sample_rows do
        [first_row | _] when is_map(first_row) -> first_row
        _ -> %{"col1" => "Ejemplo 1", "col2" => "Ejemplo 2", "col3" => "12345"}
      end

      # Check if we need to auto-select an element (returning from data load)
      element_id = Map.get(params, "element_id")
      selected_element = if element_id do
        Enum.find(design.elements || [], fn el ->
          (Map.get(el, :id) || Map.get(el, "id")) == element_id
        end)
      else
        nil
      end
      # Flag to show binding mode UI when returning from data load
      show_binding_mode = element_id != nil && selected_element != nil

      {:ok,
       socket
       |> assign(:page_title, "Editor: #{design.name}")
       |> assign(:design, design)
       |> assign(:selected_element, selected_element)
       |> assign(:selected_elements, [])
       |> assign(:pending_selection_id, element_id)
       |> assign(:clipboard, [])
       |> assign(:available_columns, available_columns)
       |> assign(:upload_total_rows, upload_total_rows)
       |> assign(:upload_sample_rows, upload_sample_rows)
       |> assign(:show_properties, true)
       |> assign(:show_preview, false)
       |> assign(:sidebar_tab, "properties")
       |> assign(:preview_data, preview_data)
       |> assign(:preview_row_index, 0)
       |> assign(:image_cache, extract_image_cache(design.elements || [], %{}))
       |> assign(:history, [%{elements: strip_binary_data(design.elements || []), groups: design.groups || []}])
       |> assign(:history_index, 0)
       |> assign(:has_unsaved_changes, false)
       |> assign(:pending_save_flash, false)
       |> assign(:zoom, 100)
       |> assign(:snap_enabled, true)
       |> assign(:snap_threshold, 5)
       |> assign(:renaming, false)
       |> assign(:rename_value, design.name)
       |> assign(:canvas_loaded, false)
       |> assign(:show_binding_mode, show_binding_mode)
       |> assign(:show_expression_mode, false)
       |> assign(:expression_visual_mode, :cards)
       |> assign(:expression_builder, %{})
       |> assign(:expression_applied, false)
       |> assign(:collapsed_sections, MapSet.new())
       |> assign(:collapsed_groups, MapSet.new())
       |> assign(:editing_group_id, nil)
       |> assign(:pending_deletes, MapSet.new())
       |> assign(:pending_print_action, nil)
       |> assign(:zpl_dpi, 203)
       |> assign(:show_versions, false)
       |> assign(:versions, [])
       |> then(fn s ->
         latest_v = Versioning.latest_version_number(design.id)
         s |> assign(:version_count, latest_v) |> assign(:current_version_number, latest_v)
       end)
       |> assign(:has_unversioned_changes, false)
       |> assign(:restored_from_version, nil)
       |> assign(:renaming_version_id, nil)
       |> assign(:rename_version_value, "")
       |> assign(:selected_version, nil)
       |> assign(:version_diff, nil)
       |> assign(:approval_required, Settings.approval_required?())
       |> assign(:is_admin, User.admin?(socket.assigns.current_user))
       |> assign(:show_approval_history, false)
       |> assign(:approval_history, [])
       |> assign(:approval_comment, "")
       |> assign(:skip_next_status_revert, false)
       |> assign(:compliance_issues, [])
       |> assign(:compliance_standard_name, nil)
       |> assign(:compliance_counts, %{errors: 0, warnings: 0, infos: 0})
       |> assign(:show_compliance_panel, false)
       |> assign(:preview_language, design.default_language || "es")
       |> assign(:available_languages, @available_languages)
       |> then(&maybe_run_compliance/1)
       |> allow_upload(:element_image,
         accept: ~w(.png .jpg .jpeg .gif),  # SVG blocked for XSS security
         max_entries: 1,
         max_file_size: 2_000_000,
         auto_upload: true)}
    end
  end

  @impl true
  def handle_event("canvas_ready", _params, socket) do
    # Only send load_design ONCE per session to prevent reverting user changes
    if socket.assigns[:canvas_loaded] do
      {:noreply, socket}
    else
      socket = socket
        |> assign(:canvas_loaded, true)
        |> push_event("load_design", %{design: Design.to_json(socket.assigns.design)})

      # If ETS has no data (e.g. server restarted), ask browser to check IndexedDB
      socket = if socket.assigns.upload_total_rows == 0 do
        push_event(socket, "check_idb_data", %{design_id: socket.assigns.design.id})
      else
        socket
      end

      # Send initial preview data via push_event (no longer in HTML attributes)
      socket = push_preview_update(socket)

      {:noreply, socket}
    end
  end

  @valid_element_types ~w(qr barcode text line rectangle image circle)

  @impl true
  def handle_event("add_element", %{"type" => type}, socket) when type in @valid_element_types do
    # Save current state to history before making changes
    design = socket.assigns.design
    current_elements = design.elements || []
    element = create_default_element(type, current_elements)
    current_elements_as_maps = Enum.map(current_elements, fn el ->
      case el do
        %QrLabelSystem.Designs.Element{} = struct -> Map.from_struct(struct)
        map when is_map(map) -> map
      end
    end)
    new_elements = current_elements_as_maps ++ [element]

    case Designs.update_design(design, %{elements: new_elements}) do
      {:ok, updated_design} ->
        {:noreply,
         socket
         |> push_to_history(design)
         |> assign(:design, updated_design)
         |> assign(:selected_element, element)
         |> push_event("add_element", %{element: element})}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error al crear elemento")
         |> push_event("add_element", %{element: element})}
    end
  end

  def handle_event("add_element", %{"type" => _invalid_type}, socket) do
    {:noreply, put_flash(socket, :error, "Tipo de elemento no válido")}
  end

  @impl true
  def handle_event("add_element_at", %{"type" => type, "x" => x, "y" => y}, socket)
      when type in @valid_element_types do
    # Save current state to history before making changes
    design = socket.assigns.design
    current_elements = design.elements || []
    element = create_default_element(type, current_elements)
    # Override position with drop location
    element = Map.merge(element, %{x: x, y: y})

    current_elements_as_maps = Enum.map(current_elements, fn el ->
      case el do
        %QrLabelSystem.Designs.Element{} = struct -> Map.from_struct(struct)
        map when is_map(map) -> map
      end
    end)
    new_elements = current_elements_as_maps ++ [element]

    case Designs.update_design(design, %{elements: new_elements}) do
      {:ok, updated_design} ->
        {:noreply,
         socket
         |> push_to_history(design)
         |> assign(:design, updated_design)
         |> assign(:selected_element, element)
         |> push_event("add_element", %{element: element})}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error al crear elemento")
         |> push_event("add_element", %{element: element})}
    end
  end

  def handle_event("add_element_at", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("element_selected", %{"id" => id}, socket) do
    elements = socket.assigns.design.elements || []
    # Handle both atom and string keys for id (elements may come from DB or JS)
    element = Enum.find(elements, fn el ->
      el_id = Map.get(el, :id) || Map.get(el, "id")
      el_id == id
    end)

    pending_id = Map.get(socket.assigns, :pending_selection_id)

    cond do
      # If we have a pending operation for this element, keep current state
      # This prevents race conditions where element_selected fires with stale data
      # before element_modified completes the update
      pending_id == id ->
        {:noreply, socket}

      # Element not found - might be transitional state
      is_nil(element) ->
        {:noreply, socket}

      # Normal selection - detect initial tab from element's binding
      true ->
        {init_binding, init_expression} = cond do
          has_expression?(element) -> {false, true}
          has_binding?(element) -> {true, false}
          true -> {false, false}
        end

        # Collapse "appearance" by default for qr/barcode (many options)
        el_type = Map.get(element, :type) || Map.get(element, "type")
        default_collapsed = if el_type in ["qr", "barcode"],
          do: MapSet.new(["appearance"]),
          else: MapSet.new()

        {:noreply,
         socket
         |> assign(:selected_element, element)
         |> assign(:sidebar_tab, "properties")
         |> assign(:show_binding_mode, init_binding)
         |> assign(:show_expression_mode, init_expression)
         |> assign(:expression_visual_mode, :cards)
         |> assign(:expression_builder, %{})
         |> assign(:collapsed_sections, default_collapsed)}
    end
  end

  @impl true
  def handle_event("element_deselected", _params, socket) do
    # Don't deselect if we're in the middle of an element recreation
    if Map.get(socket.assigns, :pending_selection_id) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> assign(:selected_element, nil)
       |> assign(:expression_visual_mode, :cards)
       |> assign(:expression_builder, %{})}
    end
  end

  @impl true
  def handle_event("toggle_section", %{"section" => section}, socket) do
    collapsed = socket.assigns.collapsed_sections
    collapsed = if MapSet.member?(collapsed, section),
      do: MapSet.delete(collapsed, section),
      else: MapSet.put(collapsed, section)
    {:noreply, assign(socket, :collapsed_sections, collapsed)}
  end

  @impl true
  def handle_event("element_modified", params, socket) do
    elements_json = Map.get(params, "elements", [])
    groups_json = Map.get(params, "groups")
    design = socket.assigns.design
    current_elements = design.elements || []
    current_element_count = length(current_elements)
    new_element_count = length(elements_json || [])
    pending_deletes = socket.assigns.pending_deletes

    # Get IDs of current elements
    current_ids = MapSet.new(Enum.map(current_elements, fn el ->
      Map.get(el, :id) || Map.get(el, "id")
    end))

    # Get IDs of incoming elements
    new_ids = MapSet.new(Enum.map(elements_json || [], fn el ->
      Map.get(el, "id")
    end))

    # Check for suspicious element loss
    missing_ids = MapSet.difference(current_ids, new_ids)
    _elements_lost = MapSet.size(missing_ids)

    # Check if all missing elements are expected deletions
    unexpected_missing = MapSet.difference(missing_ids, pending_deletes)
    unexpected_loss_count = MapSet.size(unexpected_missing)

    cond do
      # Empty array when we have elements and no pending deletes - definitely wrong
      new_element_count == 0 and current_element_count > 0 and MapSet.size(pending_deletes) == 0 ->
        Logger.warning("element_modified received empty array but design has #{current_element_count} elements - ignoring to prevent data loss")
        show_flash = Map.get(socket.assigns, :pending_save_flash, false)
        socket = if show_flash do
          socket
          |> assign(:pending_save_flash, false)
          |> put_flash(:error, "El canvas no está listo. Intenta guardar de nuevo.")
        else
          assign(socket, :pending_save_flash, false)
        end
        {:noreply, socket}

      # Elements lost that were NOT explicitly deleted - this is unexpected
      unexpected_loss_count > 0 ->
        Logger.warning("element_modified would unexpectedly lose #{unexpected_loss_count} elements. Expected deletes: #{inspect(MapSet.to_list(pending_deletes))}. Missing IDs: #{inspect(MapSet.to_list(missing_ids))}. Unexpected missing: #{inspect(MapSet.to_list(unexpected_missing))}. Ignoring to prevent data loss.")
        {:noreply, assign(socket, :pending_save_flash, false)}

      # Normal operation - save the elements and clear pending deletes
      true ->
        do_save_elements(socket, design, elements_json, groups_json)
    end
  end

  @impl true
  def handle_event("update_element", %{"field" => field, "value" => value}, socket)
      when field in @allowed_element_fields do
    if socket.assigns.selected_element do
      # Normalize empty qr_logo_data to nil (used by "Quitar logo" button)
      value = if field == "qr_logo_data" and value == "", do: nil, else: value

      # Update selected_element locally to keep UI in sync
      # Handle both atom and string keys
      key = String.to_atom(field)

      # Get element type
      element_type = Map.get(socket.assigns.selected_element, :type) ||
                     Map.get(socket.assigns.selected_element, "type")

      # For QR codes, width and height must be equal (square)
      updated_element = cond do
        element_type == "qr" and field in ["width", "height"] ->
          socket.assigns.selected_element
          |> Map.put(:width, value)
          |> Map.put("width", value)
          |> Map.put(:height, value)
          |> Map.put("height", value)

        # When switching barcode format to 2D, force square dimensions
        field == "barcode_format" and value in ~w(DATAMATRIX AZTEC MAXICODE) ->
          current_w = Map.get(socket.assigns.selected_element, :width) || Map.get(socket.assigns.selected_element, "width") || 20.0
          current_h = Map.get(socket.assigns.selected_element, :height) || Map.get(socket.assigns.selected_element, "height") || 20.0
          side = max(min(current_w, current_h), 20.0)
          socket.assigns.selected_element
          |> Map.put(key, value)
          |> Map.put(field, value)
          |> Map.put(:width, side)
          |> Map.put("width", side)
          |> Map.put(:height, side)
          |> Map.put("height", side)

        true ->
          socket.assigns.selected_element
          |> Map.put(key, value)
          |> Map.put(field, value)
      end

      # Get element ID (handle both atom and string keys)
      element_id = Map.get(socket.assigns.selected_element, :id) ||
                   Map.get(socket.assigns.selected_element, "id")

      # Fields that cause element recreation in canvas (QR/barcode regeneration)
      # For these, we need to preserve selection through the save cycle
      recreating_fields = ["binding", "color", "background_color", "text_content",
                          "qr_error_level", "qr_logo_data", "qr_logo_size",
                          "barcode_show_text", "barcode_format"]

      # For QR, push both width and height updates
      socket = cond do
        element_type == "qr" and field in ["width", "height"] ->
          socket
          |> assign(:selected_element, updated_element)
          |> assign(:pending_selection_id, element_id)
          |> push_event("update_element_property", %{id: element_id, field: "width", value: value})
          |> push_event("update_element_property", %{id: element_id, field: "height", value: value})

        # For border_radius, don't update selected_element to avoid re-render during slider drag
        # The value will be synced when element_modified is processed
        field == "border_radius" ->
          socket
          |> assign(:pending_selection_id, element_id)
          |> push_event("update_element_property", %{id: element_id, field: field, value: value})

        # For fields that cause canvas element recreation, set pending_selection_id
        # to ensure the element stays selected after the save cycle
        field in recreating_fields ->
          # Check if we're updating text_content in "fixed" mode (binding is nil)
          # For QR/barcode, we need to also send binding: nil to override the JS behavior
          # that sets both binding and text_content to the same value
          current_binding = Map.get(socket.assigns.selected_element, :binding) ||
                           Map.get(socket.assigns.selected_element, "binding")
          is_fixed_mode = is_nil(current_binding)
          is_code_element = element_type in ["qr", "barcode"]

          socket = socket
            |> assign(:selected_element, updated_element)
            |> assign(:pending_selection_id, element_id)

          socket = cond do
            # When switching to 2D format, push square dimensions before the format change
            field == "barcode_format" and value in ~w(DATAMATRIX AZTEC MAXICODE) ->
              side = Map.get(updated_element, :width) || Map.get(updated_element, "width") || 20.0
              socket
              |> push_event("update_element_property", %{id: element_id, field: "width", value: side})
              |> push_event("update_element_property", %{id: element_id, field: "height", value: side})
              |> push_event("update_element_property", %{id: element_id, field: field, value: value})

            # For QR/barcode in fixed mode, send binding: nil first to ensure
            # the canvas doesn't overwrite it with text_content value
            field == "text_content" and is_fixed_mode and is_code_element ->
              socket
              |> push_event("update_element_property", %{id: element_id, field: "binding", value: nil})
              |> push_event("update_element_property", %{id: element_id, field: field, value: value})

            true ->
              push_event(socket, "update_element_property", %{id: element_id, field: field, value: value})
          end

          socket

        true ->
          socket
          |> assign(:selected_element, updated_element)
          |> push_event("update_element_property", %{id: element_id, field: field, value: value})
      end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Catch-all for invalid/disallowed fields - silently ignore (security)
  def handle_event("update_element", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("set_content_mode", %{"mode" => mode}, socket) do
    # Tabs are UI-only: no binding changes, no push_event to canvas.
    # Binding only changes when user takes an explicit action
    # (select column, type text, apply pattern).
    if socket.assigns.selected_element do
      case mode do
        "binding" ->
          {:noreply,
           socket
           |> assign(:show_binding_mode, true)
           |> assign(:show_expression_mode, false)}

        "fixed" ->
          {:noreply,
           socket
           |> assign(:show_binding_mode, false)
           |> assign(:show_expression_mode, false)}

        "expression" ->
          {:noreply,
           socket
           |> assign(:show_binding_mode, false)
           |> assign(:show_expression_mode, true)}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("insert_expression_function", %{"template" => template}, socket) do
    if socket.assigns.selected_element do
      element_id = Map.get(socket.assigns.selected_element, :id) ||
                   Map.get(socket.assigns.selected_element, "id")
      current_binding = Map.get(socket.assigns.selected_element, :binding) ||
                        Map.get(socket.assigns.selected_element, "binding") || ""

      # If current binding is a simple column reference like {{col}},
      # replace "valor" placeholder in template with the column name
      new_binding = case extract_simple_column_ref(current_binding) do
        {:ok, col_name} ->
          String.replace(template, "valor", col_name)
        :none ->
          current_binding <> template
      end

      updated_element = socket.assigns.selected_element
        |> Map.put(:binding, new_binding)
        |> Map.put("binding", new_binding)

      socket = socket
        |> assign(:selected_element, updated_element)
        |> push_event("update_element_property", %{id: element_id, field: "binding", value: new_binding})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_expression_pattern", %{"pattern" => pattern_str}, socket) do
    pattern_id = String.to_existing_atom(pattern_str)
    # Pre-fill with column from builder if available
    col = Map.get(socket.assigns.expression_builder, "column")
    config = default_builder_config(pattern_id, col)

    {:noreply,
     socket
     |> assign(:expression_visual_mode, {:form, pattern_id})
     |> assign(:expression_builder, config)
     |> assign(:expression_applied, false)}
  end

  @impl true
  def handle_event("update_expression_builder", params, socket) do
    # Merge changed fields into expression_builder
    builder = socket.assigns.expression_builder
    new_builder = Enum.reduce(params, builder, fn
      {"_target", _}, acc -> acc
      {key, value}, acc -> Map.put(acc, key, value)
    end)

    {:noreply,
     socket
     |> assign(:expression_builder, new_builder)
     |> assign(:expression_applied, false)}
  end

  @impl true
  def handle_event("apply_expression_pattern", _params, socket) do
    case socket.assigns.expression_visual_mode do
      {:form, pattern_id} when socket.assigns.selected_element != nil ->
        config = socket.assigns.expression_builder
        expr = build_expression_from_pattern(pattern_id, config)

        element_id = Map.get(socket.assigns.selected_element, :id) ||
                     Map.get(socket.assigns.selected_element, "id")
        element_type = Map.get(socket.assigns.selected_element, :type) ||
                       Map.get(socket.assigns.selected_element, "type")

        updated_element = socket.assigns.selected_element
          |> Map.put(:binding, expr)
          |> Map.put("binding", expr)

        # Stay in form view so user can tweak and re-apply
        socket = socket
          |> assign(:selected_element, updated_element)
          |> assign(:expression_applied, true)

        socket = if element_type == "text" do
          push_event(socket, "update_element_property", %{id: element_id, field: "binding", value: expr})
        else
          socket
        end

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("back_to_expression_cards", _params, socket) do
    {:noreply,
     socket
     |> assign(:expression_visual_mode, :cards)
     |> assign(:expression_builder, %{})
     |> assign(:expression_applied, false)}
  end

  @impl true
  def handle_event("toggle_expression_advanced", _params, socket) do
    new_mode = case socket.assigns.expression_visual_mode do
      :advanced -> :cards
      _ -> :advanced
    end

    {:noreply, assign(socket, :expression_visual_mode, new_mode)}
  end

  @impl true
  def handle_event("delete_element", _params, socket) do
    selected_elements = socket.assigns.selected_elements || []
    selected_element = socket.assigns.selected_element
    pending_deletes = socket.assigns.pending_deletes

    cond do
      # Multiple elements selected - delete all
      length(selected_elements) > 1 ->
        ids = Enum.map(selected_elements, fn el ->
          Map.get(el, :id) || Map.get(el, "id")
        end)
        # Track pending deletes so element_modified knows these deletions are expected
        new_pending_deletes = MapSet.union(pending_deletes, MapSet.new(ids))
        {:noreply,
         socket
         |> assign(:pending_deletes, new_pending_deletes)
         |> push_event("delete_elements", %{ids: ids})
         |> assign(:selected_element, nil)
         |> assign(:selected_elements, [])}

      # Single element selected
      selected_element != nil ->
        id = Map.get(selected_element, :id) || Map.get(selected_element, "id")
        # Track pending delete
        new_pending_deletes = MapSet.put(pending_deletes, id)
        {:noreply,
         socket
         |> assign(:pending_deletes, new_pending_deletes)
         |> push_event("delete_elements", %{ids: [id]})
         |> assign(:selected_element, nil)
         |> assign(:selected_elements, [])}

      # Nothing selected
      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_design_properties", %{"design" => params}, socket) do
    case Designs.update_design(socket.assigns.design, params) do
      {:ok, updated_design} ->
        {:noreply,
         socket
         |> assign(:design, updated_design)
         |> push_event("update_canvas_size", %{
           width: updated_design.width_mm,
           height: updated_design.height_mm,
           background_color: updated_design.background_color,
           border_width: updated_design.border_width,
           border_color: updated_design.border_color,
           border_radius: updated_design.border_radius
         })}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Error al actualizar propiedades")}
    end
  end

  @impl true
  def handle_event("toggle_properties", _params, socket) do
    {:noreply, assign(socket, :show_properties, !socket.assigns.show_properties)}
  end

  @impl true
  def handle_event("toggle_preview", _params, socket) do
    new_show = !socket.assigns.show_preview

    socket =
      socket
      |> assign(:show_preview, new_show)

    # When opening the preview panel, push current data so the hook renders immediately
    socket = if new_show, do: push_preview_update(socket), else: socket

    {:noreply, socket}
  end

  @impl true
  def handle_event("request_preview_data", _params, socket) do
    {:noreply, push_preview_update(socket)}
  end

  @impl true
  def handle_event("undo", _params, socket) do
    case undo(socket) do
      {:ok, new_socket} -> {:noreply, new_socket}
      :no_history -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("redo", _params, socket) do
    case redo(socket) do
      {:ok, new_socket} -> {:noreply, new_socket}
      :no_future -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("zoom_in", _params, socket) do
    new_zoom = min(socket.assigns.zoom + 25, 200)
    {:noreply,
     socket
     |> assign(:zoom, new_zoom)
     |> push_event("update_zoom", %{zoom: new_zoom})}
  end

  @impl true
  def handle_event("zoom_out", _params, socket) do
    new_zoom = max(socket.assigns.zoom - 25, 25)
    {:noreply,
     socket
     |> assign(:zoom, new_zoom)
     |> push_event("update_zoom", %{zoom: new_zoom})}
  end

  @impl true
  def handle_event("zoom_reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:zoom, 100)
     |> push_event("update_zoom", %{zoom: 100})}
  end

  @impl true
  def handle_event("update_zoom_from_wheel", %{"zoom" => zoom}, socket) do
    new_zoom = max(25, min(200, round(zoom)))
    {:noreply,
     socket
     |> assign(:zoom, new_zoom)
     |> push_event("update_zoom", %{zoom: new_zoom})}
  end

  @impl true
  def handle_event("zoom_changed", %{"zoom" => zoom}, socket) do
    # Sync zoom state from canvas (e.g., after auto-fit)
    new_zoom = max(25, min(200, round(zoom)))
    {:noreply, assign(socket, :zoom, new_zoom)}
  end

  @impl true
  def handle_event("fit_to_view", _params, socket) do
    {:noreply, push_event(socket, "fit_to_view", %{})}
  end

  @impl true
  def handle_event("save_design", _params, socket) do
    # Request canvas to send its current state immediately
    # This triggers element_modified which will persist to database
    # We set a flag to show success flash after the save completes
    {:noreply,
     socket
     |> assign(:pending_save_flash, true)
     |> push_event("save_to_server", %{})}
  end

  # ============================================================================
  # Rename Design Handlers
  # ============================================================================

  @impl true
  def handle_event("start_rename", _params, socket) do
    {:noreply,
     socket
     |> assign(:renaming, true)
     |> assign(:rename_value, socket.assigns.design.name)}
  end

  @impl true
  def handle_event("cancel_rename", _params, socket) do
    {:noreply, assign(socket, :renaming, false)}
  end

  @impl true
  def handle_event("update_rename_value", %{"value" => value}, socket) do
    {:noreply, assign(socket, :rename_value, value)}
  end

  @impl true
  def handle_event("save_rename", _params, socket) do
    name = String.trim(socket.assigns.rename_value)

    if name == "" do
      {:noreply, put_flash(socket, :error, "El nombre no puede estar vacío")}
    else
      case Designs.update_design(socket.assigns.design, %{name: name}) do
        {:ok, updated_design} ->
          {:noreply,
           socket
           |> assign(:design, updated_design)
           |> assign(:renaming, false)
           |> assign(:page_title, "Editor: #{updated_design.name}")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Error al renombrar el diseño")}
      end
    end
  end

  # ============================================================================
  # Version History Handlers
  # ============================================================================

  @impl true
  def handle_event("toggle_versions", _params, socket) do
    show = !socket.assigns.show_versions

    socket =
      if show do
        versions = Versioning.list_versions_light(socket.assigns.design.id)
        socket |> assign(:versions, versions) |> assign(:show_versions, true)
      else
        socket
        |> assign(:show_versions, false)
        |> assign(:selected_version, nil)
        |> assign(:version_diff, nil)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_version", %{"version" => version_str}, socket) do
    case Integer.parse(version_str) do
      {version_number, ""} ->
        handle_select_version(socket, version_number)

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("canvas_thumbnail", %{"version_number" => vn, "thumbnail" => thumbnail}, socket) do
    design_id = socket.assigns.design.id
    Versioning.update_version_thumbnail(design_id, vn, thumbnail)
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_version_detail", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_version, nil)
     |> assign(:version_diff, nil)
     }
  end

  @impl true
  def handle_event("start_rename_version", %{"version" => version_str}, socket) do
    case Integer.parse(version_str) do
      {version_number, ""} ->
        version = Enum.find(socket.assigns.versions, &(&1.version_number == version_number))
        current_name = if version, do: version.custom_name || "", else: ""

        {:noreply,
         socket
         |> assign(:renaming_version_id, version_number)
         |> assign(:rename_version_value, current_name)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save_rename_version", %{"version" => version_str} = params, socket) do
    case Integer.parse(version_str) do
      {version_number, ""} ->
        design_id = socket.assigns.design.id
        name = String.trim(params["custom_name"] || socket.assigns.rename_version_value)
        do_save_rename_version(socket, design_id, version_number, name)

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_rename_version", _params, socket) do
    {:noreply,
     socket
     |> assign(:renaming_version_id, nil)
     |> assign(:rename_version_value, "")}
  end

  @impl true
  def handle_event("update_rename_version_value", %{"value" => value}, socket) do
    {:noreply, assign(socket, :rename_version_value, value)}
  end

  @impl true
  def handle_event("restore_version", %{"version" => version_str}, socket) do
    case Integer.parse(version_str) do
      {version_number, ""} ->
        design = socket.assigns.design
        user_id = socket.assigns.current_user.id

        case Versioning.restore_version(design, version_number, user_id) do
          {:ok, updated_design} ->
            Logger.info("[RESTORE] OK: v#{version_number} → elements=#{length(updated_design.elements || [])}, name=#{updated_design.name}")
            # Reload versions list (light — elements not needed for panel display)
            versions = Versioning.list_versions_light(design.id)

            # Build the canvas size update in case the restored version has
            # different dimensions/styling than the current design
            canvas_props = %{
              width_mm: updated_design.width_mm,
              height_mm: updated_design.height_mm,
              background_color: updated_design.background_color,
              border_width: updated_design.border_width,
              border_color: updated_design.border_color,
              border_radius: updated_design.border_radius
            }

            {:noreply,
             socket
             |> assign(:design, updated_design)
             |> assign(:versions, versions)
             |> assign(:version_count, if(v = List.first(versions), do: v.version_number, else: 0))
             |> assign(:current_version_number, version_number)
             |> assign(:has_unversioned_changes, false)
             |> assign(:restored_from_version, version_number)
             |> assign(:selected_version, nil)
             |> assign(:version_diff, nil)
             |> assign(:has_unsaved_changes, false)
             |> assign(:pending_deletes, MapSet.new())
             |> assign(:selected_element, nil)
             |> assign(:history, [%{elements: strip_binary_data(updated_design.elements || []), groups: updated_design.groups || []}])
             |> assign(:history_index, 0)
             |> assign(:image_cache, extract_image_cache(updated_design.elements || [], %{}))
             |> assign(:rename_value, updated_design.name)
             |> push_event("update_canvas_size", canvas_props)
             |> push_event("reload_design", %{design: Design.to_json(updated_design)})
             |> put_flash(:info, "Restaurado desde v#{version_number}")}

          {:error, :version_not_found} ->
            {:noreply, put_flash(socket, :error, "Versión no encontrada")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Error al restaurar versión")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  # ============================================================================
  # Image Upload Handlers
  # ============================================================================

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :element_image, ref)}
  end


  @impl true
  def handle_event("upload_element_image", %{"element_id" => element_id}, socket) do
    Logger.debug("upload_element_image called with element_id: #{inspect(element_id)}")

    # Handle empty element_id
    if element_id == "" or is_nil(element_id) do
      {:noreply, put_flash(socket, :error, "Selecciona un elemento de imagen primero")}
    else
      uploaded_files =
        consume_uploaded_entries(socket, :element_image, fn %{path: path}, entry ->
          # Validate file content using magic bytes (not client-provided MIME type)
          case FileSanitizer.validate_image_content(path) do
            {:ok, mime_type} ->
              {:ok, binary} = File.read(path)
              base64 = Base.encode64(binary)
              Logger.debug("Processed file: #{entry.client_name}, validated type: #{mime_type}")
              {:ok, %{data: "data:#{mime_type};base64,#{base64}", filename: entry.client_name}}

            {:error, :invalid_image_type} ->
              Logger.warning("Rejected file #{entry.client_name}: invalid image type (magic bytes mismatch)")
              {:error, :invalid_image_type}

            {:error, reason} ->
              Logger.warning("Failed to validate file #{entry.client_name}: #{inspect(reason)}")
              {:error, reason}
          end
        end)

      Logger.debug("uploaded_files count: #{length(uploaded_files)}")

      case uploaded_files do
        [%{data: image_data, filename: filename}] ->
          Logger.debug("Pushing update_element_image event for element: #{element_id}")
          {:noreply,
           socket
           |> push_event("update_element_image", %{
             element_id: element_id,
             image_data: image_data,
             image_filename: filename
           })
           |> put_flash(:info, "Imagen subida correctamente")}

        [{:error, :invalid_image_type}] ->
          {:noreply, put_flash(socket, :error, "Tipo de archivo no válido. Solo se permiten imágenes PNG, JPEG o GIF.")}

        _ ->
          {:noreply, put_flash(socket, :error, "Error al subir la imagen")}
      end
    end
  end

  # ============================================================================
  # Multi-selection Handlers
  # ============================================================================

  @impl true
  def handle_event("elements_selected", %{"ids" => ids}, socket) when is_list(ids) do
    elements = Enum.filter(socket.assigns.design.elements || [], &(&1.id in ids))
    socket = socket
      |> assign(:selected_elements, elements)
      |> assign(:selected_element, List.first(elements))
    # Auto-switch to layers panel when multiple elements are selected
    socket = if length(elements) > 1, do: assign(socket, :sidebar_tab, "layers"), else: socket
    {:noreply, socket}
  end

  @impl true
  def handle_event("copy_elements", _params, socket) do
    selected = socket.assigns.selected_elements
    if length(selected) > 0 do
      {:noreply, assign(socket, :clipboard, selected)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("paste_elements", _params, socket) do
    clipboard = socket.assigns.clipboard
    if length(clipboard) > 0 do
      # Paste with offset
      {:noreply, push_event(socket, "paste_elements", %{elements: Enum.map(clipboard, &element_to_map/1), offset: 5})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("duplicate_elements", _params, socket) do
    selected = socket.assigns.selected_elements
    if length(selected) > 0 do
      {:noreply, push_event(socket, "paste_elements", %{elements: Enum.map(selected, &element_to_map/1), offset: 5})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_all_elements", _params, socket) do
    {:noreply, push_event(socket, "select_all", %{})}
  end

  @valid_align_directions ~w(left center right top middle bottom)
  @impl true
  def handle_event("align_elements", %{"direction" => direction}, socket)
      when direction in @valid_align_directions do
    {:noreply, push_event(socket, "align_elements", %{direction: direction})}
  end

  def handle_event("align_elements", _params, socket), do: {:noreply, socket}

  @valid_distribute_directions ~w(horizontal vertical)
  @impl true
  def handle_event("distribute_elements", %{"direction" => direction}, socket)
      when direction in @valid_distribute_directions do
    {:noreply, push_event(socket, "distribute_elements", %{direction: direction})}
  end

  def handle_event("distribute_elements", _params, socket), do: {:noreply, socket}

  # ============================================================================
  # Layer Management Handlers
  # ============================================================================

  @impl true
  def handle_event("toggle_layers", _params, socket) do
    new_tab = if socket.assigns.sidebar_tab == "layers", do: "properties", else: "layers"
    {:noreply, assign(socket, :sidebar_tab, new_tab)}
  end

  @impl true
  def handle_event("switch_sidebar_tab", %{"tab" => tab}, socket)
      when tab in ["properties", "layers"] do
    {:noreply, assign(socket, :sidebar_tab, tab)}
  end



  @impl true
  def handle_event("toggle_element_visibility", %{"id" => id}, socket) do
    {:noreply, push_event(socket, "toggle_visibility", %{id: id})}
  end

  @impl true
  def handle_event("toggle_element_lock", %{"id" => id}, socket) do
    {:noreply, push_event(socket, "toggle_lock", %{id: id})}
  end

  @impl true
  def handle_event("bring_to_front", _params, socket) do
    if socket.assigns.selected_element do
      {:noreply, push_event(socket, "bring_to_front", %{id: socket.assigns.selected_element.id})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_to_back", _params, socket) do
    if socket.assigns.selected_element do
      {:noreply, push_event(socket, "send_to_back", %{id: socket.assigns.selected_element.id})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("move_layer_up", _params, socket) do
    if socket.assigns.selected_element do
      {:noreply, push_event(socket, "move_layer_up", %{id: socket.assigns.selected_element.id})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("move_layer_down", _params, socket) do
    if socket.assigns.selected_element do
      {:noreply, push_event(socket, "move_layer_down", %{id: socket.assigns.selected_element.id})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_layer", %{"id" => id}, socket) do
    element = Enum.find(socket.assigns.design.elements || [], &(&1.id == id))
    {:noreply,
     socket
     |> assign(:selected_element, element)
     |> assign(:selected_elements, if(element, do: [element], else: []))
     |> push_event("select_element", %{id: id})}
  end

  @impl true
  def handle_event("rename_layer", %{"id" => id, "name" => name}, socket) do
    {:noreply, push_event(socket, "rename_element", %{id: id, name: name})}
  end

  # ============================================================================
  # Group Handlers
  # ============================================================================

  @impl true
  def handle_event("group_elements", _params, socket) do
    selected = socket.assigns.selected_elements
    if length(selected) >= 2 do
      ids = Enum.map(selected, fn el -> Map.get(el, :id) || Map.get(el, "id") end)
      group_id = "grp_#{:erlang.unique_integer([:positive])}"
      group_name = "Grupo #{length(socket.assigns.design.groups || []) + 1}"
      {:noreply, push_event(socket, "create_group", %{group_id: group_id, name: group_name, element_ids: ids})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("ungroup_elements", _params, socket) do
    selected = socket.assigns.selected_elements
    # Find the group_id from any selected element
    group_id = Enum.find_value(selected, fn el ->
      Map.get(el, :group_id) || Map.get(el, "group_id")
    end)

    if group_id do
      {:noreply, push_event(socket, "ungroup", %{group_id: group_id})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_from_group", %{"id" => element_id}, socket) do
    {:noreply, push_event(socket, "remove_from_group", %{element_id: element_id})}
  end

  @impl true
  def handle_event("toggle_group_visibility", %{"group-id" => group_id}, socket) do
    {:noreply, push_event(socket, "toggle_group_visibility", %{group_id: group_id})}
  end

  @impl true
  def handle_event("toggle_group_lock", %{"group-id" => group_id}, socket) do
    {:noreply, push_event(socket, "toggle_group_lock", %{group_id: group_id})}
  end

  @impl true
  def handle_event("toggle_group_collapsed", %{"group-id" => group_id}, socket) do
    collapsed = socket.assigns.collapsed_groups
    new_collapsed = if MapSet.member?(collapsed, group_id) do
      MapSet.delete(collapsed, group_id)
    else
      MapSet.put(collapsed, group_id)
    end
    {:noreply, assign(socket, :collapsed_groups, new_collapsed)}
  end

  @impl true
  def handle_event("rename_group", %{"group-id" => group_id, "name" => name}, socket) do
    {:noreply, push_event(socket, "rename_group", %{group_id: group_id, name: name})}
  end

  @impl true
  def handle_event("start_rename_group", %{"group-id" => group_id}, socket) do
    {:noreply, assign(socket, :editing_group_id, group_id)}
  end

  @impl true
  def handle_event("confirm_rename_group", %{"group-id" => group_id, "name" => name}, socket) do
    name = String.trim(name)
    socket = assign(socket, :editing_group_id, nil)

    if name != "" do
      {:noreply, push_event(socket, "rename_group", %{group_id: group_id, name: name})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_rename_group", _params, socket) do
    {:noreply, assign(socket, :editing_group_id, nil)}
  end

  # ============================================================================
  # Snap Handlers
  # ============================================================================

  @impl true
  def handle_event("toggle_snap", _params, socket) do
    new_value = !socket.assigns.snap_enabled
    {:noreply,
     socket
     |> assign(:snap_enabled, new_value)
     |> push_event("update_snap_settings", %{snap_enabled: new_value})}
  end

  # ============================================================================
  # Preview Row Navigation Handlers
  # ============================================================================

  @impl true
  def handle_event("preview_prev_row", _params, socket) do
    current_index = socket.assigns.preview_row_index

    if current_index > 0 do
      new_index = current_index - 1
      navigate_to_preview_row(socket, new_index)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("preview_next_row", _params, socket) do
    current_index = socket.assigns.preview_row_index
    max_index = socket.assigns.upload_total_rows - 1

    if current_index < max_index do
      new_index = current_index + 1
      navigate_to_preview_row(socket, new_index)
    else
      {:noreply, socket}
    end
  end

  # Called by JS hook when a preview row is loaded from IndexedDB
  @impl true
  def handle_event("preview_row_loaded", %{"row" => row, "index" => index}, socket) do
    socket =
     socket
     |> assign(:preview_row_index, index)
     |> assign(:preview_data, row)
     |> push_preview_update()

    {:noreply, socket}
  end

  # Called by JS hook when IDB data is found after server restart (ETS was empty)
  @impl true
  def handle_event("idb_data_available", %{"columns" => cols, "total_rows" => total, "sample_rows" => sample}, socket) do
    user_id = socket.assigns.current_user.id
    design_id = socket.assigns.design.id

    # Re-populate ETS metadata from browser data
    QrLabelSystem.UploadDataStore.put_metadata(user_id, design_id, cols, total, sample)

    preview_data = case sample do
      [first | _] when is_map(first) -> first
      _ -> socket.assigns.preview_data
    end

    design = socket.assigns.design
    mapping = build_auto_mapping(design.elements || [], preview_data)

    socket =
     socket
     |> assign(:available_columns, cols)
     |> assign(:upload_total_rows, total)
     |> assign(:upload_sample_rows, sample)
     |> assign(:preview_data, preview_data)
     |> push_preview_update()
     |> push_event("set_preview_language", %{
       language: socket.assigns.preview_language,
       default_language: design.default_language || "es",
       row: preview_data,
       mapping: mapping
     })

    {:noreply, socket}
  end

  # ============================================================================
  # Print / PDF Generation Handlers
  # ============================================================================

  @impl true
  def handle_event("generate_and_print", _params, socket) do
    if print_blocked?(socket) do
      {:noreply, put_flash(socket, :error, "Este diseno requiere aprobacion antes de imprimir. Envíalo a revision.")}
    else
      {:noreply,
       socket
       |> assign(:pending_print_action, :print)
       |> push_generate_batch()}
    end
  end

  @impl true
  def handle_event("generate_and_download_pdf", _params, socket) do
    if print_blocked?(socket) do
      {:noreply, put_flash(socket, :error, "Este diseno requiere aprobacion antes de imprimir. Envíalo a revision.")}
    else
      {:noreply,
       socket
       |> assign(:pending_print_action, :pdf)
       |> push_generate_batch()}
    end
  end

  # Approval workflow handlers

  @impl true
  def handle_event("request_review", _params, socket) do
    design = socket.assigns.design
    user = socket.assigns.current_user

    case Designs.request_review(design, user) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:design, updated)
         |> put_flash(:info, "Diseno enviado a revision")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("approve_design", _params, socket) do
    design = socket.assigns.design
    admin = socket.assigns.current_user
    comment = socket.assigns.approval_comment

    case Designs.approve_design(design, admin, comment) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:design, updated)
         |> assign(:approval_comment, "")
         |> assign(:skip_next_status_revert, true)
         |> put_flash(:info, "Diseno aprobado")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("reject_design", _params, socket) do
    design = socket.assigns.design
    admin = socket.assigns.current_user
    comment = socket.assigns.approval_comment

    if comment == "" do
      {:noreply, put_flash(socket, :error, "Debes agregar un comentario al rechazar")}
    else
      case Designs.reject_design(design, admin, comment) do
        {:ok, updated} ->
          {:noreply,
           socket
           |> assign(:design, updated)
           |> assign(:approval_comment, "")
           |> assign(:skip_next_status_revert, true)
           |> put_flash(:info, "Diseno rechazado y devuelto a borrador")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  @impl true
  def handle_event("update_approval_comment", %{"value" => value}, socket) do
    {:noreply, assign(socket, :approval_comment, value)}
  end

  @impl true
  def handle_event("toggle_approval_history", _params, socket) do
    show = !socket.assigns.show_approval_history

    socket = if show do
      history = Designs.get_approval_history(socket.assigns.design.id)
      socket
      |> assign(:show_approval_history, true)
      |> assign(:approval_history, history)
    else
      assign(socket, :show_approval_history, false)
    end

    {:noreply, socket}
  end

  # ==========================================
  # COMPLIANCE EVENTS
  # ==========================================

  @impl true
  def handle_event("set_compliance_standard", %{"standard" => standard}, socket) do
    standard = if standard == "", do: nil, else: standard
    design = socket.assigns.design

    case Designs.update_design(design, %{compliance_standard: standard},
           revert_status: false) do
      {:ok, updated} ->
        socket =
          socket
          |> assign(:design, updated)
          |> maybe_run_compliance()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al cambiar norma de cumplimiento")}
    end
  end

  @impl true
  def handle_event("run_compliance_check", _params, socket) do
    {:noreply, maybe_run_compliance(socket)}
  end

  @impl true
  def handle_event("toggle_compliance_panel", _params, socket) do
    {:noreply, assign(socket, :show_compliance_panel, !socket.assigns.show_compliance_panel)}
  end

  # ── Multi-language handlers ──────────────────────────────────

  @impl true
  def handle_event("set_preview_language", %{"lang" => lang}, socket) do
    {:noreply,
     socket
     |> assign(:preview_language, lang)
     |> push_preview_update()
     |> push_event("set_preview_language", %{
       language: lang,
       default_language: socket.assigns.design.default_language || "es",
       row: socket.assigns.preview_data,
       mapping: build_auto_mapping(socket.assigns.design.elements || [], socket.assigns.preview_data)
     })}
  end

  @impl true
  def handle_event("add_language", %{"lang" => lang}, socket) do
    design = socket.assigns.design
    current_languages = design.languages || ["es"]

    if lang in current_languages do
      {:noreply, socket}
    else
      new_languages = current_languages ++ [lang]
      case Designs.update_design(design, %{languages: new_languages}) do
        {:ok, updated_design} ->
          {:noreply,
           socket
           |> assign(:design, updated_design)
           |> push_event("reload_design", %{design: Design.to_json(updated_design)})}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Error al añadir idioma")}
      end
    end
  end

  @impl true
  def handle_event("remove_language", %{"lang" => lang}, socket) do
    design = socket.assigns.design
    default_lang = design.default_language || "es"

    if lang == default_lang do
      {:noreply, put_flash(socket, :error, "No se puede eliminar el idioma por defecto")}
    else
      new_languages = Enum.reject(design.languages || ["es"], &(&1 == lang))
      case Designs.update_design(design, %{languages: new_languages}) do
        {:ok, updated_design} ->
          socket = if socket.assigns.preview_language == lang do
            assign(socket, :preview_language, default_lang)
          else
            socket
          end

          {:noreply,
           socket
           |> assign(:design, updated_design)
           |> push_preview_update()
           |> push_event("reload_design", %{design: Design.to_json(updated_design)})}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Error al eliminar idioma")}
      end
    end
  end

  @impl true
  def handle_event("update_translation", %{"element_id" => element_id, "lang" => lang, "value" => text}, socket) do
    design = socket.assigns.design
    elements = design.elements || []

    updated_elements = Enum.map(elements, fn el ->
      if el.id == element_id do
        translations = Map.get(el, :translations) || %{}
        %{el | translations: Map.put(translations, lang, text)}
      else
        el
      end
    end)

    case Designs.update_design(design, %{elements: Enum.map(updated_elements, &element_to_map/1)}) do
      {:ok, updated_design} ->
        {:noreply,
         socket
         |> assign(:design, updated_design)
         |> push_preview_update()
         |> push_event("reload_design", %{design: Design.to_json(updated_design)})}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al guardar traducción")}
    end
  end

  @impl true
  def handle_event("focus_compliance_issue", %{"element_id" => element_id}, socket) do
    # Find the element and select it, then push focus to canvas
    element = Enum.find(socket.assigns.design.elements || [], fn el ->
      (Map.get(el, :id) || Map.get(el, "id")) == element_id
    end)

    socket = if element do
      socket
      |> assign(:selected_element, element)
      |> push_event("select_element", %{id: element_id})
    else
      socket
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_compliance_element", params, socket) do
    type = params["type"]
    if type in @valid_element_types do
      design = socket.assigns.design
      current_elements = design.elements || []

      # Try to recover the original element from undo history
      {element, restored?} =
        case find_deleted_element_in_history(socket, type, params["name"]) do
          nil ->
            # No history match: create new element with compliance defaults
            new_el = create_default_element(type, current_elements)
            new_el = new_el
              |> Map.put(:name, params["name"] || new_el[:name])
              |> maybe_put(params, "text_content")
              |> maybe_put(params, "font_size", &parse_number/1)
              |> maybe_put(params, "font_weight")
              |> maybe_put(params, "barcode_format")
              |> maybe_put(params, "compliance_role")

            # 2D barcode formats (DataMatrix, PDF417, etc.) need square dimensions
            new_el = if params["barcode_format"] in ~w(DATAMATRIX AZTEC MAXICODE) do
              %{new_el | width: 20.0, height: 20.0}
            else
              new_el
            end

            {new_el, false}

          found ->
            # Restore from history: convert struct to map, keep all original properties
            restored_el = case found do
              %QrLabelSystem.Designs.Element{} = struct -> Map.from_struct(struct)
              map -> map
            end
            # Assign a new ID so it doesn't conflict with pending_deletes
            restored_el = Map.put(restored_el, :id, Ecto.UUID.generate())
            {restored_el, true}
        end

      current_elements_as_maps = Enum.map(current_elements, fn el ->
        case el do
          %QrLabelSystem.Designs.Element{} = struct -> Map.from_struct(struct)
          map when is_map(map) -> map
        end
      end)
      new_elements = current_elements_as_maps ++ [element]

      case Designs.update_design(design, %{elements: new_elements}) do
        {:ok, updated_design} ->
          action = if restored?, do: "restored", else: "created"
          Logger.info("add_compliance_element OK: #{action} #{type} '#{element[:name]}' (id=#{element[:id]}) to design #{design.id}")

          # Find the saved Element struct (not the raw map) to avoid KeyError
          # on template fields like .group_id that only exist on structs
          new_element_id = element[:id]
          saved_element = Enum.find(updated_design.elements || [], fn el ->
            (Map.get(el, :id) || Map.get(el, "id")) == new_element_id
          end)

          flash_msg = if restored?,
            do: "Elemento \"#{element[:name]}\" restaurado desde historial",
            else: "Elemento \"#{element[:name]}\" añadido"

          socket = socket
            |> push_to_history(design)
            |> assign(:design, updated_design)
            |> assign(:selected_element, saved_element)
            |> push_event("reload_design", %{design: Design.to_json(updated_design)})
            |> push_event("select_element", %{id: new_element_id})
            |> maybe_run_compliance()
            |> put_flash(:info, flash_msg)

          {:noreply, socket}

        {:error, changeset} ->
          Logger.error("add_compliance_element FAILED: #{inspect(changeset.errors)}")
          {:noreply, put_flash(socket, :error, "Error al crear elemento")}
      end
    else
      Logger.warning("add_compliance_element: invalid type '#{inspect(type)}'")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("generation_complete", _params, socket) do
    case socket.assigns[:pending_print_action] do
      :print ->
        {:noreply,
         socket
         |> assign(:pending_print_action, nil)
         |> push_event("print_labels", %{})}

      :pdf ->
        design = socket.assigns.design
        {:noreply,
         socket
         |> assign(:pending_print_action, nil)
         |> push_event("export_pdf", %{filename: "etiquetas-#{design.name}.pdf"})}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("print_recorded", %{"count" => count}, socket) do
    {:noreply, put_flash(socket, :info, "#{count} etiquetas enviadas a impresión")}
  end

  @impl true
  def handle_event("set_zpl_dpi", %{"dpi" => dpi_str}, socket) do
    dpi = case Integer.parse(dpi_str) do
      {n, _} when n in [203, 300, 600] -> n
      _ -> 203
    end
    {:noreply, assign(socket, :zpl_dpi, dpi)}
  end

  @impl true
  def handle_event("download_zpl", _params, socket) do
    if print_blocked?(socket) do
      {:noreply, put_flash(socket, :error, "Este diseno requiere aprobacion antes de generar ZPL.")}
    else
    design = socket.assigns.design
    user_id = socket.assigns.current_user.id
    dpi = socket.assigns.zpl_dpi

    # Generate ZPL entirely client-side — no data round-trip through server
    {:noreply,
     push_event(socket, "generate_zpl_client", %{
       design: Design.to_json_light(design),
       dpi: dpi,
       user_id: user_id,
       design_id: design.id,
       mapping: build_auto_mapping(design.elements || [], socket.assigns.preview_data),
       language: socket.assigns.preview_language,
       default_language: design.default_language || "es"
     })}
    end
  end

  # Called by JS when ZPL download completes (for UI feedback)
  @impl true
  def handle_event("zpl_download_complete", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("download_template_excel", _params, socket) do
    design = socket.assigns.design
    {:noreply, push_event(socket, "download_template", Design.to_json(design))}
  end

  defp do_save_rename_version(socket, design_id, version_number, name) do
    case Versioning.rename_version(design_id, version_number, name) do
      {:ok, _updated} ->
        versions = Versioning.list_versions_light(design_id)

        {:noreply,
         socket
         |> assign(:versions, versions)
         |> assign(:renaming_version_id, nil)
         |> assign(:rename_version_value, "")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:renaming_version_id, nil)
         |> put_flash(:error, "Error al renombrar versión")}
    end
  end

  defp print_blocked?(socket) do
    socket.assigns.approval_required && socket.assigns.design.status != "approved"
  end

  defp push_generate_batch(socket) do
    design = socket.assigns.design
    preview_data = socket.assigns.preview_data
    user_id = socket.assigns.current_user.id

    # Build mapping from element IDs to column names
    column_mapping = build_auto_mapping(design.elements || [], preview_data)

    # Default print config (A4, auto-calculated grid)
    print_config = %{
      printer_type: "normal",
      page_size: "a4",
      orientation: "portrait",
      columns: max(1, trunc(190 / (design.width_mm + 5))),
      rows: max(1, trunc(277 / (design.height_mm + 5))),
      margin_top: 10,
      margin_right: 10,
      margin_bottom: 10,
      margin_left: 10,
      gap_horizontal: 5,
      gap_vertical: 5
    }

    # JS hook reads data from IndexedDB instead of receiving it from server
    push_event(socket, "generate_batch_from_idb", %{
      design: Design.to_json_light(design),
      column_mapping: column_mapping,
      print_config: print_config,
      user_id: user_id,
      design_id: design.id,
      language: socket.assigns.preview_language,
      default_language: design.default_language || "es"
    })
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  # Extracts column name from a simple reference like "{{col_name}}"
  defp extract_simple_column_ref(binding) do
    case Regex.run(~r/^\{\{([a-zA-Z0-9_\s]+)\}\}$/, String.trim(binding || "")) do
      [_, col_name] -> {:ok, String.trim(col_name)}
      _ -> :none
    end
  end

  defp handle_select_version(socket, version_number) do
    version = Versioning.get_version(socket.assigns.design.id, version_number)

    # Compute diff against previous version (not against latest)
    diff =
      case Versioning.diff_against_previous(socket.assigns.design.id, version_number) do
        {:ok, d} -> d
        _ -> nil
      end

    {:noreply,
     socket
     |> assign(:selected_version, version)
     |> assign(:version_diff, diff)}
  end

  defp navigate_to_preview_row(socket, new_index) do
    sample_rows = socket.assigns.upload_sample_rows

    if new_index < length(sample_rows) do
      new_preview_data = Enum.at(sample_rows, new_index)
      socket =
       socket
       |> assign(:preview_row_index, new_index)
       |> assign(:preview_data, new_preview_data)
       |> push_preview_update()

      {:noreply, socket}
    else
      user_id = socket.assigns.current_user.id
      design_id = socket.assigns.design.id
      {:noreply,
       socket
       |> assign(:preview_row_index, new_index)
       |> push_event("fetch_preview_row", %{index: new_index, user_id: user_id, design_id: design_id})}
    end
  end

  # Search undo history for a deleted element that matches the compliance field being re-added.
  # Returns the element map if found, or nil.
  defp find_deleted_element_in_history(socket, type, name) do
    history = socket.assigns[:history] || []
    current_ids =
      (socket.assigns.design.elements || [])
      |> Enum.map(fn el -> Map.get(el, :id) || Map.get(el, "id") end)
      |> MapSet.new()

    name_words =
      (name || "")
      |> String.downcase()
      |> String.split(~r/[\s,.:;]+/, trim: true)
      |> Enum.reject(&(&1 in ~w(del de la el los las un una)))

    # Search history backwards (most recent state first) for a deleted element
    history
    |> Enum.reverse()
    |> Enum.find_value(fn entry ->
      {elements, _groups} = history_entry(entry)

      elements
      |> Enum.find(fn el ->
        el_id = Map.get(el, :id) || Map.get(el, "id")
        el_type = to_string(Map.get(el, :type) || Map.get(el, "type"))
        el_name = String.downcase(to_string(Map.get(el, :name) || Map.get(el, "name") || ""))

        not MapSet.member?(current_ids, el_id) &&
          el_type == type &&
          Enum.any?(name_words, &String.contains?(el_name, &1))
      end)
    end)
  end

  defp maybe_put(element, params, key, transform \\ &Function.identity/1) do
    case params[key] do
      nil -> element
      "" -> element
      value ->
        atom_key = String.to_existing_atom(key)
        transformed = transform.(value)
        Map.put(element, atom_key, transformed)
    end
  end

  defp compliance_roles_for("eu1169") do
    [
      {"product_name", "Nombre del producto"},
      {"ingredients", "Ingredientes"},
      {"allergens", "Alérgenos"},
      {"net_quantity", "Cantidad neta"},
      {"best_before", "Fecha caducidad"},
      {"manufacturer", "Fabricante"},
      {"origin", "País de origen"},
      {"nutrition", "Información nutricional"},
      {"lot", "Lote"},
      {"eu1169_barcode", "Código de barras"}
    ]
  end

  defp compliance_roles_for("fmd") do
    [
      {"product_name", "Nombre medicamento"},
      {"active_ingredient", "Principio activo"},
      {"lot", "Lote"},
      {"expiry", "Fecha caducidad"},
      {"national_code", "Código nacional"},
      {"serial", "Número de serie"},
      {"dosage", "Forma farmacéutica"},
      {"manufacturer", "Laboratorio titular"},
      {"datamatrix_fmd", "DataMatrix FMD"}
    ]
  end

  defp compliance_roles_for("gs1") do
    [
      {"gs1_barcode", "Código de barras GS1"},
      {"gs1_product", "Producto"},
      {"gs1_recipient", "Destinatario"},
      {"gs1_sender", "Remitente / origen"},
      {"gs1_address", "Dirección"},
      {"gs1_reference", "Referencia / tracking"},
      {"gs1_quantity", "Cantidad / bultos"},
      {"gs1_weight", "Peso"},
      {"gs1_lot", "Lote"},
      {"gs1_date", "Fecha"}
    ]
  end

  defp compliance_roles_for(_), do: []

  defp parse_number(value) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> value
    end
  end
  defp parse_number(value), do: value

  defp do_save_elements(socket, design, elements_json, groups_json) do
    # Debug: Log what we're about to save
    current_count = length(design.elements || [])
    new_count = length(elements_json || [])
    new_ids = Enum.map(elements_json || [], fn el -> Map.get(el, "id") end)
    Logger.info("do_save_elements - Design #{design.id}: #{current_count} -> #{new_count} elements. New IDs: #{inspect(new_ids)}")

    # Include groups in update if provided by the client
    attrs = %{elements: elements_json}
    attrs = if groups_json, do: Map.put(attrs, :groups, groups_json), else: attrs

    # Skip status revert if design was just approved/rejected (no real content change yet)
    skip_revert = Map.get(socket.assigns, :skip_next_status_revert, false)

    case Designs.update_design(design, attrs,
           user_id: socket.assigns.current_user.id,
           revert_status: !skip_revert) do
      {:ok, updated_design} ->
        # Get the ID of the element that should remain selected
        # Priority: pending_selection_id > current selected_element
        selected_id = Map.get(socket.assigns, :pending_selection_id) ||
          (socket.assigns.selected_element &&
            (Map.get(socket.assigns.selected_element, :id) ||
             Map.get(socket.assigns.selected_element, "id")))

        # Find the element in the updated design
        updated_selected =
          if selected_id do
            Enum.find(updated_design.elements || [], fn el ->
              (Map.get(el, :id) || Map.get(el, "id")) == selected_id
            end)
          else
            nil
          end

        # Check if this save was triggered by the "Guardar" button
        show_flash = Map.get(socket.assigns, :pending_save_flash, false)

        socket =
          socket
          |> push_to_history(design)
          |> assign(:design, updated_design)
          |> assign(:selected_element, updated_selected)
          |> assign(:pending_selection_id, nil)  # Clear pending selection after sync
          |> assign(:pending_save_flash, false)
          |> assign(:pending_deletes, MapSet.new())  # Clear pending deletes after successful save
          |> assign(:skip_next_status_revert, false)  # Clear one-time revert guard

        # Warn if design was auto-reverted from approved/pending_review to draft
        was_non_draft = design.status in ["approved", "pending_review"]
        now_draft = updated_design.status == "draft"

        socket = if was_non_draft && now_draft do
          put_flash(socket, :warning, "El diseno ha vuelto a borrador al editarlo. Necesitara nueva aprobacion.")
        else
          socket
        end

        socket = if show_flash do
          # Explicit save: create a version snapshot
          change_summary = Versioning.generate_change_summary(updated_design,
            restored_from: socket.assigns.restored_from_version)

          case Versioning.create_snapshot(updated_design, socket.assigns.current_user.id,
                 change_message: change_summary) do
            {:ok, version} ->
              socket
              |> assign(:has_unsaved_changes, false)
              |> assign(:has_unversioned_changes, false)
              |> assign(:current_version_number, version.version_number)
              |> assign(:version_count, version.version_number)
              |> assign(:restored_from_version, nil)
              |> assign(:versions, Versioning.list_versions_light(updated_design.id))
              |> push_event("capture_thumbnail", %{version_number: version.version_number})
              |> put_flash(:info, "Diseño guardado")

            {:duplicate, :no_changes} ->
              socket
              |> assign(:has_unsaved_changes, false)
              |> assign(:has_unversioned_changes, false)
              |> put_flash(:info, "Sin cambios para versionar")

            {:error, _} ->
              socket
              |> assign(:has_unsaved_changes, false)
              |> put_flash(:warning, "Guardado, pero error al crear versión")
          end
        else
          # Autosave: no version created, mark unversioned changes
          assign(socket, :has_unversioned_changes, true)
        end

        # Update preview panel with new design state
        socket = push_preview_update(socket)

        # Re-run compliance validation after save
        socket = maybe_run_compliance(socket)

        {:noreply, socket}

      {:error, changeset} ->
        Logger.error("Failed to save design #{design.id}: #{inspect(changeset.errors)}")
        {:noreply,
         socket
         |> assign(:pending_save_flash, false)
         |> put_flash(:error, "Error al guardar cambios")}
    end
  end

  defp element_to_map(element) when is_struct(element) do
    Map.from_struct(element)
    |> Map.drop([:__meta__])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp element_to_map(element) when is_map(element), do: element

  defp create_default_element(type, existing_elements) do
    # Count existing elements of the same type to generate sequential name and offset position
    count = Enum.count(existing_elements, fn el ->
      el_type = Map.get(el, :type) || Map.get(el, "type")
      el_type == type
    end)
    number = count + 1

    # Offset each new element so they don't overlap (5mm offset per element)
    offset = count * 5.0

    base = %{
      id: Ecto.UUID.generate(),
      type: type,
      x: 10.0 + offset,
      y: 10.0 + offset,
      rotation: 0,
      z_index: length(existing_elements),
      visible: true,
      locked: false
    }

    case type do
      "qr" ->
        Map.merge(base, %{
          width: 20.0,
          height: 20.0,
          qr_error_level: "M",
          qr_logo_data: nil,
          qr_logo_size: 25.0,
          text_content: "",
          binding: nil,
          name: "Código QR #{number}"
        })

      "barcode" ->
        Map.merge(base, %{
          width: 40.0,
          height: 15.0,
          barcode_format: "CODE128",
          barcode_show_text: true,
          text_content: "",
          binding: nil,
          name: "Código de Barras #{number}"
        })

      "text" ->
        Map.merge(base, %{
          width: 60.0,
          height: 14.0,
          font_size: 25,
          font_family: "Arial",
          font_weight: "normal",
          text_align: "left",
          text_content: "",
          text_auto_fit: false,
          text_min_font_size: 6.0,
          color: "#000000",
          binding: nil,
          name: "Texto #{number}"
        })

      "line" ->
        Map.merge(base, %{
          width: 50.0,
          height: 0.5,
          color: "#000000",
          binding: nil,
          name: "Línea #{number}"
        })

      "rectangle" ->
        Map.merge(base, %{
          width: 30.0,
          height: 20.0,
          binding: nil,
          background_color: "transparent",
          border_width: 0.5,
          border_color: "#000000",
          border_radius: 0,
          name: "Rectángulo #{number}"
        })

      "image" ->
        Map.merge(base, %{
          width: 20.0,
          height: 20.0,
          image_url: nil,
          image_data: nil,
          image_filename: nil,
          binding: nil,
          name: "Imagen #{number}"
        })

      "circle" ->
        Map.merge(base, %{
          width: 15.0,
          height: 15.0,
          binding: nil,
          background_color: "transparent",
          border_width: 0.5,
          border_color: "#000000",
          border_radius: 100,
          name: "Círculo #{number}"
        })

      _ ->
        base
    end
  end

  # Check if barcode format is compatible with the given content
  # Returns true if compatible, false otherwise
  defp barcode_format_compatible?(nil, _format), do: true
  defp barcode_format_compatible?("", _format), do: true
  defp barcode_format_compatible?(content, format) do
    content = String.trim(content)
    digits_only = Regex.match?(~r/^\d+$/, content)
    len = String.length(content)

    case format do
      "CODE128" -> true
      "CODE39" -> Regex.match?(~r/^[A-Z0-9\-. \$\/\+%]*$/i, content)
      "CODE93" -> Regex.match?(~r/^[A-Z0-9\-. \$\/\+%]*$/i, content)
      "CODABAR" -> Regex.match?(~r/^[A-Da-d][0-9\-\$:\/\.+]+[A-Da-d]$/i, content)
      "MSI" -> digits_only
      "EAN13" -> digits_only and len in 12..13
      "EAN8" -> digits_only and len in 7..8
      "UPC" -> digits_only and len in 11..12
      "ITF14" -> digits_only and len in 13..14
      "GS1_DATABAR" -> digits_only and len in 13..14
      "GS1_DATABAR_STACKED" -> digits_only and len in 13..14
      "GS1_DATABAR_EXPANDED" -> len >= 2
      "GS1_128" -> len >= 2
      "POSTNET" -> digits_only and len in [5, 9, 11]
      "PLANET" -> digits_only and len in [11, 13]
      "ROYALMAIL" -> Regex.match?(~r/^[A-Z0-9]+$/i, content)
      "pharmacode" ->
        if digits_only do
          case Integer.parse(content) do
            {num, ""} -> num >= 3 and num <= 131070
            _ -> false
          end
        else
          false
        end
      # 2D formats accept any text
      f when f in ~w(DATAMATRIX PDF417 AZTEC MAXICODE) -> true
      _ -> true
    end
  end

  # Validate barcode content and return structured result for UI feedback
  # Returns %{valid: bool, hint: string|nil}
  defp validate_barcode_content(nil, _format), do: %{valid: true, hint: nil}
  defp validate_barcode_content("", _format), do: %{valid: true, hint: nil}
  defp validate_barcode_content(content, format) do
    content = String.trim(content)
    len = String.length(content)
    digits_only = Regex.match?(~r/^\d+$/, content)

    case format do
      f when f in ~w(EAN13 EAN8 UPC ITF14 GS1_DATABAR GS1_DATABAR_STACKED) ->
        {min, max} = range_for_format(f)
        cond do
          not digits_only -> %{valid: false, hint: "Solo dígitos"}
          len < min -> %{valid: false, hint: "Llevas #{len}, #{falta_n(min - len)} para el mínimo de #{min}"}
          len > max -> %{valid: false, hint: "Llevas #{len}, #{sobra_n(len - max)} del máximo de #{max}"}
          true -> %{valid: true, hint: "#{len} dígitos ✓"}
        end

      "POSTNET" ->
        cond do
          not digits_only -> %{valid: false, hint: "Solo dígitos"}
          len in [5, 9, 11] -> %{valid: true, hint: "#{len} dígitos ✓"}
          true ->
            target = nearest_above(len, [5, 9, 11])
            %{valid: false, hint: "Llevas #{len}, #{falta_n(target - len)} para #{target} dígitos"}
        end

      "PLANET" ->
        cond do
          not digits_only -> %{valid: false, hint: "Solo dígitos"}
          len in [11, 13] -> %{valid: true, hint: "#{len} dígitos ✓"}
          true ->
            target = nearest_above(len, [11, 13])
            %{valid: false, hint: "Llevas #{len}, #{falta_n(target - len)} para #{target} dígitos"}
        end

      f when f in ~w(GS1_DATABAR_EXPANDED GS1_128) ->
        if len < 2 do
          %{valid: false, hint: "Llevas #{len}, #{falta_n(2 - len)} para el mínimo de 2"}
        else
          %{valid: true, hint: "#{len} caracteres ✓"}
        end

      "MSI" ->
        if not digits_only do
          %{valid: false, hint: "Solo dígitos"}
        else
          %{valid: true, hint: nil}
        end

      "CODE39" ->
        if not Regex.match?(~r/^[A-Z0-9\-. \$\/\+%]*$/i, content) do
          %{valid: false, hint: "Solo A-Z, 0-9, -.$/+%"}
        else
          %{valid: true, hint: nil}
        end

      "CODE93" ->
        if not Regex.match?(~r/^[A-Z0-9\-. \$\/\+%]*$/i, content) do
          %{valid: false, hint: "Solo A-Z, 0-9, -.$/+%"}
        else
          %{valid: true, hint: nil}
        end

      "CODABAR" ->
        if not Regex.match?(~r/^[A-Da-d][0-9\-\$:\/\.+]+[A-Da-d]$/i, content) do
          %{valid: false, hint: "Formato: A-D + dígitos + A-D (mín. 3)"}
        else
          %{valid: true, hint: "#{len} caracteres ✓"}
        end

      "ROYALMAIL" ->
        if not Regex.match?(~r/^[A-Z0-9]+$/i, content) do
          %{valid: false, hint: "Solo alfanumérico (A-Z, 0-9)"}
        else
          %{valid: true, hint: nil}
        end

      "pharmacode" ->
        cond do
          not digits_only -> %{valid: false, hint: "Solo dígitos"}
          true ->
            case Integer.parse(content) do
              {num, ""} when num >= 3 and num <= 131070 ->
                %{valid: true, hint: "Valor #{num} ✓"}
              {num, ""} when num < 3 ->
                %{valid: false, hint: "Valor #{num}, el mínimo es 3"}
              {num, ""} ->
                %{valid: false, hint: "Valor #{num}, el máximo es 131070"}
              _ ->
                %{valid: false, hint: "Valor inválido"}
            end
        end

      # 2D formats accept any text
      _ -> %{valid: true, hint: nil}
    end
  end

  defp range_for_format("EAN13"), do: {12, 13}
  defp range_for_format("EAN8"), do: {7, 8}
  defp range_for_format("UPC"), do: {11, 12}
  defp range_for_format("ITF14"), do: {13, 14}
  defp range_for_format("GS1_DATABAR"), do: {13, 14}
  defp range_for_format("GS1_DATABAR_STACKED"), do: {13, 14}

  defp falta_n(1), do: "falta 1"
  defp falta_n(n), do: "faltan #{n}"

  defp sobra_n(1), do: "sobra 1"
  defp sobra_n(n), do: "sobran #{n}"

  # Find the nearest valid length >= current length, or the max if already past all
  defp nearest_above(len, targets) do
    Enum.find(targets, List.last(targets), &(&1 >= len))
  end

  # Format info for barcode info card in properties panel
  defp barcode_format_info(format) do
    case format do
      "CODE128" -> %{name: "CODE128", category: "1D General", color: "blue", type: "Código 1D lineal (uso general)", length: "Variable", chars: "ASCII completo", usage: "Logística, inventario, etiquetas internas"}
      "CODE39" -> %{name: "CODE39", category: "1D General", color: "blue", type: "Código 1D lineal (uso general)", length: "Variable", chars: "A-Z, 0-9, -.$/+%", usage: "Industria automotriz, defensa, salud"}
      "CODE93" -> %{name: "CODE93", category: "1D General", color: "blue", type: "Código 1D lineal (uso general)", length: "Variable", chars: "A-Z, 0-9, -.$/+%", usage: "Correo canadiense, logística"}
      "CODABAR" -> %{name: "Codabar", category: "1D General", color: "blue", type: "Código 1D lineal (uso general)", length: "Mín. 3 caracteres", chars: "0-9, -$:/.+, inicio/fin A-D", usage: "Bibliotecas, bancos de sangre, paquetería"}
      "MSI" -> %{name: "MSI", category: "1D General", color: "blue", type: "Código 1D lineal (uso general)", length: "Variable", chars: "Solo dígitos", usage: "Estantes de supermercado, inventario"}
      "pharmacode" -> %{name: "Pharmacode", category: "1D General", color: "blue", type: "Código 1D lineal (farmacéutico)", length: "1 – 6 dígitos", chars: "Solo dígitos (valor 3 – 131070)", usage: "Industria farmacéutica (empaque)"}
      "EAN13" -> %{name: "EAN-13", category: "1D Retail", color: "emerald", type: "Código 1D lineal (retail)", length: "12 – 13 dígitos", chars: "Solo dígitos", usage: "Productos de consumo a nivel mundial"}
      "EAN8" -> %{name: "EAN-8", category: "1D Retail", color: "emerald", type: "Código 1D lineal (retail)", length: "7 – 8 dígitos", chars: "Solo dígitos", usage: "Productos pequeños con espacio limitado"}
      "UPC" -> %{name: "UPC-A", category: "1D Retail", color: "emerald", type: "Código 1D lineal (retail)", length: "11 – 12 dígitos", chars: "Solo dígitos", usage: "Productos de consumo en Norteamérica"}
      "ITF14" -> %{name: "ITF-14", category: "1D Retail", color: "emerald", type: "Código 1D lineal (retail/logística)", length: "13 – 14 dígitos", chars: "Solo dígitos", usage: "Cajas y embalaje exterior (GTIN)"}
      "GS1_DATABAR" -> %{name: "GS1 DataBar", category: "1D Retail", color: "emerald", type: "Código 1D lineal (retail)", length: "13 – 14 dígitos", chars: "Solo dígitos (GTIN)", usage: "Productos frescos, cupones"}
      "GS1_DATABAR_STACKED" -> %{name: "GS1 DB Stacked", category: "1D Retail", color: "emerald", type: "Código 1D apilado (retail)", length: "13 – 14 dígitos", chars: "Solo dígitos (GTIN)", usage: "Productos muy pequeños (frutas, verduras)"}
      "GS1_DATABAR_EXPANDED" -> %{name: "GS1 DB Expanded", category: "1D Retail", color: "emerald", type: "Código 1D expandido (retail)", length: "Mín. 2 caracteres", chars: "AI + datos variables", usage: "Productos con peso, fecha de vencimiento"}
      "GS1_128" -> %{name: "GS1-128", category: "1D Supply Chain", color: "cyan", type: "Código 1D lineal (cadena de suministro)", length: "Mín. 2, máx. ~48 caracteres", chars: "AI + datos", usage: "Pallets, cajas, trazabilidad logística"}
      "DATAMATRIX" -> %{name: "DataMatrix", category: "2D", color: "amber", type: "Código 2D matricial", length: "1 – 2335 caracteres", chars: "Texto libre", usage: "Electrónica, componentes pequeños, salud"}
      "PDF417" -> %{name: "PDF417", category: "2D", color: "amber", type: "Código 2D apilado", length: "1 – 1850 caracteres", chars: "Texto libre", usage: "Documentos de identidad, boarding passes"}
      "AZTEC" -> %{name: "Aztec", category: "2D", color: "amber", type: "Código 2D matricial", length: "1 – 3832 caracteres", chars: "Texto libre", usage: "Billetes de transporte, boletos"}
      "MAXICODE" -> %{name: "MaxiCode", category: "2D", color: "amber", type: "Código 2D hexagonal", length: "1 – 93 caracteres", chars: "Texto libre", usage: "Paquetería (UPS), clasificación automática"}
      "POSTNET" -> %{name: "POSTNET", category: "Postal", color: "pink", type: "Código postal de barras", length: "5, 9 u 11 dígitos", chars: "Solo dígitos", usage: "Correo de EE.UU. (USPS)"}
      "PLANET" -> %{name: "PLANET", category: "Postal", color: "pink", type: "Código postal de barras", length: "11 o 13 dígitos", chars: "Solo dígitos", usage: "Rastreo de correo USPS"}
      "ROYALMAIL" -> %{name: "Royal Mail", category: "Postal", color: "pink", type: "Código postal 4-state", length: "Variable", chars: "Alfanumérico (A-Z, 0-9)", usage: "Correo de Reino Unido (Royal Mail)"}
      _ -> nil
    end
  end

  # History management for undo/redo
  @max_history_size 10

  defp push_to_history(socket, design) do
    # Cache images before stripping them from history
    image_cache = extract_image_cache(design.elements, socket.assigns.image_cache)
    light_elements = strip_binary_data(design.elements)

    history = socket.assigns.history
    index = socket.assigns.history_index

    # Truncate future history if we're not at the end
    history = Enum.take(history, index + 1)

    # Add current state to history (without heavy binary data)
    entry = %{elements: light_elements, groups: design.groups || []}
    new_history = history ++ [entry]

    # Limit history size
    new_history = if length(new_history) > @max_history_size do
      Enum.drop(new_history, 1)
    else
      new_history
    end

    socket
    |> assign(:image_cache, image_cache)
    |> assign(:history, new_history)
    |> assign(:history_index, length(new_history) - 1)
  end

  # Extract elements and groups from a history entry (handles both old list format and new map format)
  defp history_entry(entry) when is_map(entry) and is_map_key(entry, :elements),
    do: {entry.elements, Map.get(entry, :groups, [])}
  defp history_entry(entry) when is_list(entry),
    do: {entry, []}
  defp history_entry(_), do: {[], []}

  defp undo(socket) do
    index = socket.assigns.history_index

    if index > 0 do
      new_index = index - 1
      {previous_elements, previous_groups} = history_entry(Enum.at(socket.assigns.history, new_index))
      # Re-inject images from cache into elements for the design struct
      restored = restore_images(previous_elements, socket.assigns.image_cache)

      # Update design in memory without saving to DB (save happens on explicit save)
      design = socket.assigns.design
      updated_design = %{design | elements: restored, groups: previous_groups}

      socket =
       socket
       |> assign(:design, updated_design)
       |> assign(:history_index, new_index)
       |> assign(:has_unsaved_changes, true)
       |> assign(:has_unversioned_changes, true)
       |> push_event("reload_design", %{design: Design.to_json_light(updated_design)})
       |> push_preview_update()

      {:ok, socket}
    else
      :no_history
    end
  end

  defp redo(socket) do
    history = socket.assigns.history
    index = socket.assigns.history_index

    if index < length(history) - 1 do
      new_index = index + 1
      {next_elements, next_groups} = history_entry(Enum.at(history, new_index))
      # Re-inject images from cache into elements for the design struct
      restored = restore_images(next_elements, socket.assigns.image_cache)

      # Update design in memory without saving to DB
      design = socket.assigns.design
      updated_design = %{design | elements: restored, groups: next_groups}

      socket =
       socket
       |> assign(:design, updated_design)
       |> assign(:history_index, new_index)
       |> assign(:has_unsaved_changes, true)
       |> assign(:has_unversioned_changes, true)
       |> push_event("reload_design", %{design: Design.to_json_light(updated_design)})
       |> push_preview_update()

      {:ok, socket}
    else
      :no_future
    end
  end

  defp can_undo?(assigns), do: assigns.history_index > 0
  defp can_redo?(assigns), do: assigns.history_index < length(assigns.history) - 1

  # Group columns: base columns with their translation flags appended.
  # Returns [{col_name, flags_string}] where flags_string is empty for columns
  # without translations, or "🇬🇧🇫🇷" etc for base columns that have translations.
  # Translation-only columns (e.g. nombre_en) are excluded from the list.
  defp columns_with_flags(columns, languages) do
    # Find which columns are translations of a base column
    {translations, bases} =
      Enum.split_with(columns, fn col ->
        case Regex.run(~r/^(.+)_([a-z]{2})$/, col) do
          [_, base, lang] -> lang in languages and base in columns
          _ -> false
        end
      end)

    # Build a map: base_col => [flag1, flag2, ...]
    flag_map =
      Enum.reduce(translations, %{}, fn col, acc ->
        [_, base, lang] = Regex.run(~r/^(.+)_([a-z]{2})$/, col)
        flag = case Enum.find(@available_languages, fn {c, _, _} -> c == lang end) do
          {_, _, f} -> f
          nil -> ""
        end
        Map.update(acc, base, [flag], &(&1 ++ [flag]))
      end)

    # Return base columns (non-translation) with flags
    bases
    |> Enum.map(fn col ->
      flags = Map.get(flag_map, col, []) |> Enum.join("")
      {col, flags}
    end)
  end

  defp unified_status_bar(assigns) do
    standards = Compliance.available_standards()

    {status_label, status_dot, status_bg} = case assigns.design.status do
      "draft" -> {"Borrador", "bg-gray-400", "bg-gray-50 text-gray-700"}
      "pending_review" -> {"En revision", "bg-amber-400", "bg-amber-50 text-amber-700"}
      "approved" -> {"Aprobado", "bg-green-500", "bg-green-50 text-green-700"}
      "archived" -> {"Archivado", "bg-red-400", "bg-red-50 text-red-700"}
      _ -> {"Desconocido", "bg-gray-400", "bg-gray-50 text-gray-700"}
    end

    assigns = assigns
      |> assign(:standards, standards)
      |> assign(:status_label, status_label)
      |> assign(:status_dot, status_dot)
      |> assign(:status_bg, status_bg)

    ~H"""
    <div class="mt-2 flex items-center bg-white rounded-lg shadow-sm border border-gray-200 px-3 h-9 text-sm">
      <%!-- Zone 1: Compliance (left) — only shown when a standard is assigned --%>
      <%= if @standard do %>
        <div class="flex items-center gap-2 min-w-0 flex-1">
          <div class="flex items-center gap-1 text-gray-400 flex-shrink-0">
            <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
            </svg>
            <span class="text-xs">Norma:</span>
          </div>
          <span class="text-xs font-medium text-gray-700"><%= @standard_name %></span>
          <button phx-click="toggle_compliance_panel" class="flex items-center gap-1.5 hover:opacity-80 transition flex-shrink-0" title="Ver detalle de cumplimiento">
            <%= cond do %>
              <% @counts.errors > 0 -> %>
                <span class="w-2.5 h-2.5 rounded-full bg-red-500"></span>
              <% @counts.warnings > 0 -> %>
                <span class="w-2.5 h-2.5 rounded-full bg-amber-400"></span>
              <% true -> %>
                <span class="w-2.5 h-2.5 rounded-full bg-green-500"></span>
            <% end %>
            <%= if @counts.errors > 0 || @counts.warnings > 0 do %>
              <span :if={@counts.errors > 0} class="text-xs text-red-600 font-medium whitespace-nowrap"><%= @counts.errors %> error<%= if @counts.errors != 1, do: "es" %></span>
              <span :if={@counts.warnings > 0} class="text-xs text-amber-600 font-medium whitespace-nowrap"><%= @counts.warnings %> aviso<%= if @counts.warnings != 1, do: "s" %></span>
              <span :if={@counts.infos > 0} class="text-xs text-blue-500 whitespace-nowrap"><%= @counts.infos %> info</span>
            <% else %>
              <span class="text-xs text-green-600 font-medium">Cumple</span>
            <% end %>
          </button>
          <button phx-click="run_compliance_check" class="p-1 rounded hover:bg-gray-100 text-gray-400 hover:text-gray-600 transition flex-shrink-0" title="Re-validar">
            <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          </button>
        </div>
      <% end %>

      <%!-- Zone 2: Workflow (center) — only if approval is required --%>
      <%= if @approval_required do %>
        <div class="w-px h-5 bg-gray-200 mx-3 flex-shrink-0"></div>
        <div class="flex items-center gap-2 flex-shrink-0">
          <span class={"inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium #{@status_bg}"}>
            <span class={"w-2 h-2 rounded-full #{@status_dot}"}></span>
            <%= @status_label %>
          </span>
          <%= cond do %>
            <% @design.status == "draft" && @design.user_id == @current_user.id -> %>
              <button
                phx-click="request_review"
                class="inline-flex items-center gap-1 px-2.5 py-1 bg-amber-500 hover:bg-amber-600 text-white rounded-md transition text-xs font-medium"
                title="Enviar a revision"
              >
                <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                Enviar
              </button>
            <% @design.status == "pending_review" && @is_admin -> %>
              <input
                type="text"
                placeholder="Comentario..."
                value={@approval_comment}
                phx-change="update_approval_comment"
                phx-debounce="300"
                name="value"
                class="w-28 px-2 py-1 text-xs border border-gray-300 rounded-md focus:ring-1 focus:ring-blue-500"
              />
              <button
                phx-click="approve_design"
                class="inline-flex items-center gap-1 px-2 py-1 bg-green-600 hover:bg-green-700 text-white rounded-md transition text-xs font-medium"
                title="Aprobar"
              >
                <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                </svg>
                Aprobar
              </button>
              <button
                phx-click="reject_design"
                class="inline-flex items-center gap-1 px-2 py-1 bg-red-600 hover:bg-red-700 text-white rounded-md transition text-xs font-medium"
                title="Rechazar"
              >
                <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
                Rechazar
              </button>
            <% @design.status == "pending_review" -> %>
              <span class="text-xs text-amber-600">En espera de aprobacion</span>
            <% true -> %>
          <% end %>
        </div>
      <% end %>

      <%!-- Zone 3: Languages (right) --%>
      <div class="w-px h-5 bg-gray-200 mx-3 flex-shrink-0"></div>
      <div class="flex items-center gap-1 flex-shrink-0">
        <%= for lang <- (@design.languages || ["es"]) do %>
          <% {_code, _name, flag} = Enum.find(@available_languages, {"es", "Español", "🇪🇸"}, fn {c, _, _} -> c == lang end) %>
          <button
            phx-click="set_preview_language"
            phx-value-lang={lang}
            class={"px-1.5 py-0.5 rounded text-xs font-medium transition #{if @preview_language == lang, do: "bg-blue-600 text-white", else: "bg-gray-100 text-gray-600 hover:bg-gray-200"}"}
            title={lang}
          >
            <%= flag %> <%= String.upcase(lang) %>
          </button>
        <% end %>
        <div class="relative" id="lang-add-dropdown" phx-hook="LangDropdown">
          <button
            phx-click={Phoenix.LiveView.JS.toggle(to: "#lang-dropdown-menu")}
            class="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-xs text-gray-400 hover:text-gray-600 hover:bg-gray-100 border border-dashed border-gray-300 hover:border-gray-400 transition"
            title="Añadir idioma"
          >
            <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
            </svg>
            <span>Idioma</span>
          </button>
          <div id="lang-dropdown-menu" style="display: none;" class="absolute right-0 top-full mt-1 w-52 bg-white rounded-lg shadow-lg border border-gray-200 z-50">
            <div class="p-1.5 border-b border-gray-100">
              <input
                type="text"
                id="lang-search-input"
                placeholder="Buscar idioma..."
                class="w-full text-xs border-gray-200 rounded px-2 py-1 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                autocomplete="off"
              />
            </div>
            <div class="max-h-48 overflow-y-auto" id="lang-dropdown-list">
              <%= for {code, name, flag} <- @available_languages do %>
                <%= unless code in (@design.languages || ["es"]) do %>
                  <button
                    phx-click={Phoenix.LiveView.JS.push("add_language", value: %{lang: code}) |> Phoenix.LiveView.JS.hide(to: "#lang-dropdown-menu")}
                    data-lang-name={String.downcase(name)}
                    data-lang-code={code}
                    class="lang-option w-full text-left px-3 py-1.5 text-sm hover:bg-gray-50 flex items-center gap-2"
                  >
                    <span><%= flag %></span>
                    <span><%= name %></span>
                    <span class="text-gray-400 text-xs"><%= String.upcase(code) %></span>
                  </button>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <%!-- Zone 4: Historial + Versions (right) --%>
      <div class="w-px h-5 bg-gray-200 mx-3 flex-shrink-0"></div>
      <div class="flex items-center flex-shrink-0">
        <button
          phx-click="toggle_versions"
          class="inline-flex items-center gap-1 px-2.5 py-1 bg-gray-100 hover:bg-gray-200 text-gray-600 rounded-md transition text-xs font-medium border border-gray-300"
          title="Historial de versiones"
        >
          <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          Historial<%= if @current_version_number > 0 do %> · v<%= @current_version_number %><%= if @has_unversioned_changes, do: " *" %><% end %>
        </button>
      </div>
    </div>
    """
  end

  # Extract image_data and qr_logo_data from elements into a cache keyed by element id
  defp extract_image_cache(elements, existing_cache) do
    Enum.reduce(elements || [], existing_cache, fn el, cache ->
      id = Map.get(el, :id) || Map.get(el, "id")
      if is_nil(id), do: cache, else: do_cache_element(el, id, cache)
    end)
  end

  defp do_cache_element(el, id, cache) do
    img = Map.get(el, :image_data) || Map.get(el, "image_data")
    logo = Map.get(el, :qr_logo_data) || Map.get(el, "qr_logo_data")

    if img || logo do
      entry = Map.get(cache, id, %{})
      entry = if img, do: Map.put(entry, :image_data, img), else: entry
      entry = if logo, do: Map.put(entry, :qr_logo_data, logo), else: entry
      Map.put(cache, id, entry)
    else
      cache
    end
  end

  # Strip image_data and qr_logo_data from elements for lightweight history storage
  defp strip_binary_data(elements) do
    Enum.map(elements || [], fn el ->
      el
      |> put_field(:image_data, nil)
      |> put_field(:qr_logo_data, nil)
    end)
  end

  # Re-inject images from cache into stripped elements
  defp restore_images(elements, image_cache) do
    Enum.map(elements || [], fn el ->
      id = Map.get(el, :id) || Map.get(el, "id")
      case Map.get(image_cache, id) do
        nil -> el
        cached ->
          el
          |> then(fn e -> if cached[:image_data], do: put_field(e, :image_data, cached[:image_data]), else: e end)
          |> then(fn e -> if cached[:qr_logo_data], do: put_field(e, :qr_logo_data, cached[:qr_logo_data]), else: e end)
      end
    end)
  end

  # Put a field on either a struct or map, handling both atom and string keys
  defp put_field(%{__struct__: _} = struct, key, value), do: Map.put(struct, key, value)
  defp put_field(map, key, value) when is_atom(key) do
    cond do
      Map.has_key?(map, key) -> Map.put(map, key, value)
      Map.has_key?(map, Atom.to_string(key)) -> Map.put(map, Atom.to_string(key), value)
      true -> Map.put(map, key, value)
    end
  end

  # Push preview update to the LabelPreview hook via push_event
  defp maybe_run_compliance(socket) do
    design = socket.assigns.design

    case Compliance.validate(design) do
      {nil, []} ->
        socket
        |> assign(:compliance_issues, [])
        |> assign(:compliance_standard_name, nil)
        |> assign(:compliance_counts, %{errors: 0, warnings: 0, infos: 0})
        |> push_event("highlight_compliance_issues", %{errors: [], warnings: []})

      {name, issues} ->
        sorted = Compliance.sort_issues(issues)
        counts = Compliance.count_by_severity(issues)

        error_ids = issues |> Enum.filter(&(&1.severity == :error && &1.element_id)) |> Enum.map(& &1.element_id) |> Enum.uniq()
        warning_ids = issues |> Enum.filter(&(&1.severity == :warning && &1.element_id)) |> Enum.map(& &1.element_id) |> Enum.uniq()
        # Don't highlight an element as warning if it already has an error
        warning_ids = warning_ids -- error_ids

        socket
        |> assign(:compliance_issues, sorted)
        |> assign(:compliance_standard_name, name)
        |> assign(:compliance_counts, counts)
        |> push_event("highlight_compliance_issues", %{errors: error_ids, warnings: warning_ids})
    end
  end

  defp push_preview_update(socket) do
    design = socket.assigns.design
    push_event(socket, "update_preview", %{
      design: Design.to_json_light(design),
      row: socket.assigns.preview_data,
      mapping: build_auto_mapping(design.elements || [], socket.assigns.preview_data),
      preview_index: socket.assigns.preview_row_index,
      total_rows: max(socket.assigns.upload_total_rows, 1),
      language: socket.assigns.preview_language,
      default_language: design.default_language || "es"
    })
  end

  defp build_auto_mapping(elements, preview_data) do
    columns = Map.keys(preview_data)

    elements
    |> Enum.filter(fn el ->
      # Only map elements with explicit binding (not expressions — they auto-resolve)
      # Elements without binding use static translations from the Translate panel
      binding = el.binding
      binding && is_binary(binding) && binding != "" && !String.contains?(binding, "{{")
    end)
    |> Enum.reduce(%{}, fn element, acc ->
      matching_column = Enum.find(columns, fn col ->
        String.downcase(col) == String.downcase(element.binding)
      end)

      if matching_column do
        Map.put(acc, element.id, matching_column)
      else
        acc
      end
    end)

  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :can_undo, can_undo?(assigns))
    assigns = assign(assigns, :can_redo, can_redo?(assigns))
    assigns = assign(assigns, :element_count, length(assigns.design.elements || []))
    ~H"""
    <div class="h-screen flex flex-col bg-gray-100" id="editor-container" phx-hook="KeyboardShortcuts">
      <div id="template-download-hook" phx-hook="TemplateDownload" class="hidden"></div>
      <!-- Header -->
      <div class="bg-white border-b border-gray-200 px-4 py-3 flex items-center justify-between shadow-sm">
        <!-- Left: Back + Name + Dimensions -->
        <div class="flex items-center space-x-4">
          <.link navigate={~p"/designs"} class="flex items-center space-x-2 text-gray-500 hover:text-gray-700">
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            <span class="text-sm">Volver</span>
          </.link>
          <div class="h-6 w-px bg-gray-300"></div>
          <div>
            <%= if @renaming do %>
              <form phx-submit="save_rename" class="flex items-center space-x-2">
                <input
                  type="text"
                  name="value"
                  value={@rename_value}
                  phx-change="update_rename_value"
                  phx-debounce="50"
                  autofocus
                  class="text-lg font-semibold text-gray-900 border-gray-300 rounded-md px-2 py-1 w-48"
                />
                <button type="submit" class="p-1.5 rounded-lg bg-green-100 text-green-600 hover:bg-green-200" title="Guardar">
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                </button>
                <button type="button" phx-click="cancel_rename" class="p-1.5 rounded-lg bg-gray-100 text-gray-500 hover:bg-gray-200" title="Cancelar">
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </form>
            <% else %>
              <div class="flex items-center space-x-2">
                <h1 class="text-lg font-semibold text-gray-900"><%= @design.name %></h1>
                <button
                  phx-click="start_rename"
                  class="p-1 rounded hover:bg-gray-100 text-gray-400 hover:text-gray-600 transition"
                  title="Renombrar"
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                  </svg>
                </button>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Center: Undo/Redo + Zoom Controls -->
        <div class="flex items-center space-x-1">
          <!-- Undo/Redo -->
          <button
            phx-click="undo"
            disabled={!@can_undo}
            class={"p-2 rounded-lg transition #{if @can_undo, do: "bg-gray-100 hover:bg-gray-200 text-gray-700", else: "bg-gray-50 text-gray-300 cursor-not-allowed"}"}
            title="Deshacer (Ctrl+Z)"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6" />
            </svg>
          </button>
          <button
            phx-click="redo"
            disabled={!@can_redo}
            class={"p-2 rounded-lg transition #{if @can_redo, do: "bg-gray-100 hover:bg-gray-200 text-gray-700", else: "bg-gray-50 text-gray-300 cursor-not-allowed"}"}
            title="Rehacer (Ctrl+Y)"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 10h-10a8 8 0 00-8 8v2M21 10l-6 6m6-6l-6-6" />
            </svg>
          </button>

          <div class="w-px h-6 bg-gray-300 mx-2"></div>

          <!-- Zoom -->
          <button
            phx-click="zoom_out"
            class="p-2 rounded-lg bg-gray-100 hover:bg-gray-200 text-gray-700 transition"
            title="Alejar (-25%)"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM13 10H7" />
            </svg>
          </button>
          <button
            phx-click="zoom_reset"
            class="px-3 py-1.5 rounded-lg bg-gray-100 hover:bg-gray-200 text-gray-700 font-semibold text-sm min-w-[60px] transition"
            title="Restablecer al 100%"
          >
            <%= @zoom %>%
          </button>
          <button
            phx-click="zoom_in"
            class="p-2 rounded-lg bg-gray-100 hover:bg-gray-200 text-gray-700 transition"
            title="Acercar (+25%)"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v6m3-3H7" />
            </svg>
          </button>
          <button
            phx-click="fit_to_view"
            class="p-2 rounded-lg bg-gray-100 hover:bg-gray-200 text-gray-700 transition"
            title="Ajustar a la vista"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
            </svg>
          </button>

          <div class="w-px h-6 bg-gray-300 mx-2"></div>

          <!-- Dimensions -->
          <span class="text-sm text-gray-500 font-medium"><%= @design.width_mm %> × <%= @design.height_mm %> mm</span>
        </div>

        <!-- Right: Data + Preview + Save -->
        <div class="flex items-center space-x-2">
          <div :if={@design.label_type == "multiple"} class="relative group/data flex">
            <.link
              navigate={~p"/generate/data/#{@design.id}"}
              class={"px-3 py-2 rounded-l-lg flex items-center space-x-2 font-medium transition text-sm #{if @upload_total_rows > 0, do: "bg-amber-50 text-amber-700 hover:bg-amber-100 border border-amber-200", else: "bg-slate-50 text-slate-700 hover:bg-slate-100 border border-slate-200"}"}
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
              </svg>
              <span><%= if @upload_total_rows > 0, do: "Cambiar datos", else: "Vincular datos" %></span>
            </.link>
            <button
              type="button"
              class={"flex items-center px-1.5 py-2 rounded-r-lg transition #{if @upload_total_rows > 0, do: "bg-amber-50 text-amber-700 group-hover/data:bg-amber-100 border border-l-0 border-amber-200", else: "bg-slate-50 text-slate-700 group-hover/data:bg-slate-100 border border-l-0 border-slate-200"}"}
              aria-haspopup="true"
              aria-label="Opciones de datos"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
              </svg>
            </button>
            <div class="invisible opacity-0 group-hover/data:visible group-hover/data:opacity-100 group-focus-within/data:visible group-focus-within/data:opacity-100 transition-all duration-150 absolute left-0 top-full pt-1 z-50">
              <div class="w-64 bg-white rounded-lg shadow-lg border border-gray-200 overflow-hidden">
                <.link
                  navigate={~p"/generate/data/#{@design.id}"}
                  class="w-full flex items-center space-x-3 px-4 py-3 hover:bg-slate-50 transition text-left"
                >
                  <div class="w-8 h-8 bg-slate-100 rounded-lg flex items-center justify-center">
                    <svg class="w-5 h-5 text-slate-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                    </svg>
                  </div>
                  <div>
                    <p class="text-sm font-medium text-gray-900">Vincular datos</p>
                    <p class="text-xs text-gray-500">Cargar Excel o pegar datos</p>
                  </div>
                </.link>
                <button
                  phx-click="download_template_excel"
                  class="w-full flex items-center space-x-3 px-4 py-3 hover:bg-slate-50 transition text-left border-t border-gray-100"
                >
                  <div class="w-8 h-8 bg-green-100 rounded-lg flex items-center justify-center">
                    <svg class="w-5 h-5 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                  </div>
                  <div>
                    <p class="text-sm font-medium text-gray-900">Descargar plantilla Excel</p>
                    <p class="text-xs text-gray-500">Rellénala con tus datos y vincúlala a la etiqueta</p>
                  </div>
                </button>
              </div>
            </div>
          </div>

          <div class="w-px h-6 bg-gray-300"></div>

          <!-- Save split button (hover dropdown, pure CSS) -->
          <button
            phx-click="save_design"
            class="flex items-center space-x-1.5 px-3 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition text-sm font-medium"
            title="Guardar diseño (Ctrl+S)"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
            </svg>
            <span>Guardar</span>
          </button>

          <div class="w-px h-6 bg-gray-300"></div>

          <!-- Print split button (hover dropdown, pure CSS) -->
          <div class="relative group/print flex">
            <button
              phx-click="generate_and_print"
              class="flex items-center space-x-1.5 px-3 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-l-lg transition text-sm font-medium"
              title="Imprimir etiquetas"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
              </svg>
              <span>Imprimir</span>
            </button>
            <button type="button" class="flex items-center px-1.5 py-2 bg-emerald-600 group-hover/print:bg-emerald-700 border-l border-emerald-500 rounded-r-lg transition text-white" aria-haspopup="true" aria-label="Opciones de impresión">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
              </svg>
            </button>
            <!-- Dropdown: shown on hover or keyboard focus -->
            <div class="invisible opacity-0 group-hover/print:visible group-hover/print:opacity-100 group-focus-within/print:visible group-focus-within/print:opacity-100 transition-all duration-150 absolute left-0 top-full pt-1 z-50">
              <div class="w-64 bg-white rounded-lg shadow-lg border border-gray-200 overflow-hidden">
                <button
                  phx-click="toggle_preview"
                  class="w-full flex items-center space-x-3 px-4 py-3 hover:bg-emerald-50 transition text-left"
                >
                  <div class="w-8 h-8 bg-emerald-100 rounded-lg flex items-center justify-center">
                    <svg class="w-5 h-5 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                    </svg>
                  </div>
                  <div>
                    <p class="text-sm font-medium text-gray-900">Vista previa</p>
                    <p class="text-xs text-gray-500">Ver etiquetas antes de imprimir</p>
                  </div>
                </button>
                <button
                  phx-click="generate_and_print"
                  class="w-full flex items-center space-x-3 px-4 py-3 hover:bg-emerald-50 transition text-left border-t border-gray-100"
                >
                  <div class="w-8 h-8 bg-emerald-100 rounded-lg flex items-center justify-center">
                    <svg class="w-5 h-5 text-emerald-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
                    </svg>
                  </div>
                  <div>
                    <p class="text-sm font-medium text-gray-900">Imprimir</p>
                    <p class="text-xs text-gray-500">Enviar al navegador</p>
                  </div>
                </button>
                <button
                  phx-click="generate_and_download_pdf"
                  class="w-full flex items-center space-x-3 px-4 py-3 hover:bg-red-50 transition text-left border-t border-gray-100"
                >
                  <div class="w-8 h-8 bg-red-100 rounded-lg flex items-center justify-center">
                    <svg class="w-5 h-5 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                  </div>
                  <div>
                    <p class="text-sm font-medium text-gray-900">Descargar PDF</p>
                    <p class="text-xs text-gray-500">Archivo listo para imprimir</p>
                  </div>
                </button>
                <div class="border-t border-gray-100 px-4 py-3 hover:bg-violet-50 transition">
                  <div class="flex items-center space-x-3 mb-2">
                    <div class="w-8 h-8 bg-violet-100 rounded-lg flex items-center justify-center">
                      <span class="text-sm font-bold text-violet-600 leading-none">ZPL</span>
                    </div>
                    <div>
                      <p class="text-sm font-medium text-gray-900">Descargar ZPL</p>
                      <p class="text-xs text-gray-500">Impresora termica Zebra</p>
                    </div>
                  </div>
                  <div class="flex items-center gap-2">
                    <div class="flex gap-1 flex-1">
                      <%= for dpi <- [203, 300, 600] do %>
                        <button
                          type="button"
                          phx-click="set_zpl_dpi"
                          phx-value-dpi={dpi}
                          class={"flex-1 px-2 py-1.5 text-xs font-medium rounded border transition #{if @zpl_dpi == dpi, do: "bg-violet-600 text-white border-violet-600", else: "bg-white text-gray-600 border-gray-300 hover:bg-gray-50"}"}
                        >
                          <%= dpi %> dpi
                        </button>
                      <% end %>
                    </div>
                    <button
                      phx-click="download_zpl"
                      class="px-4 py-1.5 text-xs font-medium bg-violet-600 text-white rounded hover:bg-violet-700 transition"
                    >
                      Descargar .zpl
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Main Content -->
      <div class="flex-1 flex overflow-hidden relative">
        <!-- Left Sidebar - Element Tools (fixed width, won't shrink) -->
        <div class="w-24 flex-shrink-0 bg-white border-r border-gray-200 flex flex-col py-4 overflow-hidden" id="element-toolbar" phx-hook="DraggableElements">
          <div class="px-2 mb-4">
            <p class="text-xs font-medium text-gray-400 text-center mb-3">ELEMENTOS</p>
            <div class="space-y-2">
              <button
                type="button"
                data-element-type="text"
                class="draggable-element w-full flex flex-col items-center p-2 rounded-lg hover:bg-blue-50 hover:text-blue-600 text-gray-600 transition"
              >
                <svg class="w-6 h-6 mb-1 pointer-events-none" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16m-7 6h7" />
                </svg>
                <span class="text-xs pointer-events-none">Texto</span>
              </button>

              <button
                type="button"
                data-element-type="qr"
                class="draggable-element w-full flex flex-col items-center p-2 rounded-lg hover:bg-blue-50 hover:text-blue-600 text-gray-600 transition"
              >
                <svg class="w-6 h-6 mb-1 pointer-events-none" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z" />
                </svg>
                <span class="text-xs pointer-events-none">QR</span>
              </button>

              <button
                type="button"
                data-element-type="barcode"
                class="draggable-element w-full flex flex-col items-center p-2 rounded-lg hover:bg-blue-50 hover:text-blue-600 text-gray-600 transition"
              >
                <svg class="w-6 h-6 mb-1 pointer-events-none" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 17h.01M17 7h.01M17 17h.01M12 7v10M7 7v10m10-10v10" />
                </svg>
                <span class="text-xs pointer-events-none">Barcode</span>
              </button>

              <button
                type="button"
                data-element-type="rectangle"
                class="draggable-element w-full flex flex-col items-center p-2 rounded-lg hover:bg-blue-50 hover:text-blue-600 text-gray-600 transition"
              >
                <svg class="w-6 h-6 mb-1 pointer-events-none" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h12a2 2 0 012 2v12a2 2 0 01-2 2H6a2 2 0 01-2-2V6z" />
                </svg>
                <span class="text-xs pointer-events-none">Cuadro</span>
              </button>

              <button
                type="button"
                data-element-type="circle"
                class="draggable-element w-full flex flex-col items-center p-2 rounded-lg hover:bg-blue-50 hover:text-blue-600 text-gray-600 transition"
              >
                <svg class="w-6 h-6 mb-1 pointer-events-none" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <circle cx="12" cy="12" r="9" stroke-width="2" />
                </svg>
                <span class="text-xs pointer-events-none">Círculo</span>
              </button>

              <button
                type="button"
                data-element-type="line"
                class="draggable-element w-full flex flex-col items-center p-2 rounded-lg hover:bg-blue-50 hover:text-blue-600 text-gray-600 transition"
              >
                <svg class="w-6 h-6 mb-1 pointer-events-none" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 12h16" />
                </svg>
                <span class="text-xs pointer-events-none">Línea</span>
              </button>

              <button
                type="button"
                data-element-type="image"
                class="draggable-element w-full flex flex-col items-center p-2 rounded-lg hover:bg-blue-50 hover:text-blue-600 text-gray-600 transition"
              >
                <svg class="w-6 h-6 mb-1 pointer-events-none" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <span class="text-xs pointer-events-none">Imagen</span>
              </button>
            </div>
          </div>

        </div>

        <!-- Canvas Area - grows but doesn't push sidebars -->
        <div class="flex-1 min-w-0 overflow-auto p-4 flex flex-col items-center">
          <!-- Alignment Toolbar (shown when multiple elements selected) -->
          <div :if={length(@selected_elements) > 1} class="mb-3 flex items-center space-x-1 bg-white rounded-lg shadow-md px-3 py-2">
              <span class="text-xs text-gray-500 font-medium mr-1">ALINEAR</span>
              <button phx-click="align_elements" phx-value-direction="left" class="p-1.5 rounded hover:bg-gray-100" title="Alinear izquierda">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v16M8 8h12M8 16h8" /></svg>
              </button>
              <button phx-click="align_elements" phx-value-direction="center" class="p-1.5 rounded hover:bg-gray-100" title="Centrar horizontal">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16M6 8h12M8 16h8" /></svg>
              </button>
              <button phx-click="align_elements" phx-value-direction="right" class="p-1.5 rounded hover:bg-gray-100" title="Alinear derecha">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 4v16M4 8h12M8 16h8" /></svg>
              </button>
              <div class="w-px h-4 bg-gray-300 mx-1"></div>
              <button phx-click="align_elements" phx-value-direction="top" class="p-1.5 rounded hover:bg-gray-100" title="Alinear arriba">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4h16M8 8v12M16 8v8" /></svg>
              </button>
              <button phx-click="align_elements" phx-value-direction="middle" class="p-1.5 rounded hover:bg-gray-100" title="Centrar vertical">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 12h16M8 6v12M16 8v8" /></svg>
              </button>
              <button phx-click="align_elements" phx-value-direction="bottom" class="p-1.5 rounded hover:bg-gray-100" title="Alinear abajo">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 20h16M8 4v12M16 8v8" /></svg>
              </button>
              <div :if={length(@selected_elements) > 2} class="w-px h-4 bg-gray-300 mx-1"></div>
              <button :if={length(@selected_elements) > 2} phx-click="distribute_elements" phx-value-direction="horizontal" class="p-1.5 rounded hover:bg-gray-100" title="Distribuir horizontal">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v16M12 6v12M20 4v16" /></svg>
              </button>
              <button :if={length(@selected_elements) > 2} phx-click="distribute_elements" phx-value-direction="vertical" class="p-1.5 rounded hover:bg-gray-100" title="Distribuir vertical">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4h16M6 12h12M4 20h16" /></svg>
              </button>
              <div class="w-px h-4 bg-gray-300 mx-1"></div>
              <button phx-click="group_elements" class="px-2 py-1 rounded hover:bg-gray-100 text-xs text-gray-600" title="Agrupar (Ctrl+G)">
                Agrupar
              </button>
          </div>

          <div class="relative max-w-full max-h-full overflow-hidden">
            <div
              id="canvas-container"
              phx-hook="CanvasDesigner"
              phx-update="ignore"
              data-width={@design.width_mm}
              data-height={@design.height_mm}
              data-background-color={@design.background_color}
              data-border-width={@design.border_width || 0}
              data-border-color={@design.border_color || "#000000"}
              data-border-radius={@design.border_radius || 0}
              data-snap-enabled={@snap_enabled}
              data-snap-threshold={@snap_threshold}
              class="rounded-lg bg-slate-200"
            >
              <canvas id="label-canvas"></canvas>
            </div>

            <!-- Empty State Hint - positioned AFTER canvas to not interfere with mouse events -->
            <!-- Note: This hint is shown only when there are no elements, but the canvas is always interactive -->
          </div>

          <!-- Unified Status Bar: Compliance + Workflow + Versions -->
          <.unified_status_bar
            standard={@design.compliance_standard}
            standard_name={@compliance_standard_name}
            counts={@compliance_counts}
            approval_required={@approval_required}
            design={@design}
            current_user={@current_user}
            is_admin={@is_admin}
            approval_comment={@approval_comment}
            version_count={@version_count}
            current_version_number={@current_version_number}
            has_unversioned_changes={@has_unversioned_changes}
            preview_language={@preview_language}
            available_languages={@available_languages}
          />
        </div>

        <!-- Right Sidebar - Properties & Layers Tabs (fixed width, won't shrink) -->
        <div class="w-72 flex-shrink-0 bg-white border-l border-gray-200 flex flex-col">
          <!-- Tab bar -->
          <div class="flex border-b border-gray-200 flex-shrink-0">
            <button
              phx-click="switch_sidebar_tab"
              phx-value-tab="properties"
              class={"flex-1 px-3 py-2.5 text-sm font-medium transition border-b-2 #{if @sidebar_tab == "properties", do: "text-blue-600 border-blue-600", else: "text-gray-500 border-transparent hover:text-gray-700 hover:border-gray-300"}"}
            >
              Propiedades
            </button>
            <button
              phx-click="switch_sidebar_tab"
              phx-value-tab="layers"
              class={"flex-1 px-3 py-2.5 text-sm font-medium transition border-b-2 flex items-center justify-center gap-1.5 #{if @sidebar_tab == "layers", do: "text-blue-600 border-blue-600", else: "text-gray-500 border-transparent hover:text-gray-700 hover:border-gray-300"}"}
            >
              Capas
              <span class={"inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1 text-xs rounded-full #{if @sidebar_tab == "layers", do: "bg-blue-100 text-blue-600", else: "bg-gray-100 text-gray-500"}"}>
                <%= @element_count %>
              </span>
            </button>
          </div>

          <!-- Properties tab content -->
          <div :if={@sidebar_tab == "properties"} class="flex-1 overflow-y-auto">
            <div class="p-4">
              <!-- Available Columns Panel (only for multiple labels) -->
              <div :if={@design.label_type == "multiple" && length(@available_columns) > 0} class="bg-indigo-50 rounded-lg p-3 mb-4">
                <h4 class="text-xs font-semibold text-indigo-700 uppercase tracking-wide mb-2">
                  Columnas Disponibles
                </h4>
                <div class="flex flex-wrap gap-1.5">
                  <%= for {col, flags} <- columns_with_flags(@available_columns, @design.languages || ["es"]) do %>
                    <span class="inline-flex items-center gap-1 px-2 py-0.5 bg-indigo-100 text-indigo-700 text-xs font-mono rounded">
                      <%= col %><%= if flags != "", do: " " <> flags %>
                    </span>
                  <% end %>
                </div>
                <p class="mt-2 text-xs text-indigo-600">
                  Selecciona un elemento para vincularlo a una columna
                </p>
              </div>

              <!-- No data warning for multiple labels -->
              <div :if={@design.label_type == "multiple" && length(@available_columns) == 0} class="bg-amber-50 border border-amber-200 rounded-lg p-3 mb-4">
                <div class="flex items-start space-x-2">
                  <svg class="w-5 h-5 text-amber-500 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                  <div>
                    <p class="text-sm font-medium text-amber-800">Sin datos vinculados</p>
                    <p class="text-xs text-amber-700 mt-1">
                      Usa tu propio archivo Excel o descarga una plantilla específica para esta etiqueta desde el botón
                      <span class="font-semibold">Vincular datos</span> en la barra superior.
                    </p>
                  </div>
                </div>
              </div>

              <%= if @selected_element do %>
                <div class="flex items-center justify-between mb-4">
                  <h3 class="font-semibold text-gray-900">Propiedades</h3>
                  <span class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded">
                    <%= String.capitalize(@selected_element.type) %>
                  </span>
                </div>
                <.element_properties element={@selected_element} uploads={@uploads} available_columns={@available_columns} label_type={@design.label_type} design_id={@design.id} show_binding_mode={@show_binding_mode} show_expression_mode={@show_expression_mode} expression_visual_mode={@expression_visual_mode} expression_builder={@expression_builder} expression_applied={@expression_applied} preview_data={@preview_data} collapsed_sections={@collapsed_sections} compliance_standard={@design.compliance_standard} all_elements={@design.elements || []} design={@design} available_languages={@available_languages} preview_language={@preview_language} />

                <div class="mt-6 pt-4 border-t">
                  <button
                    phx-click="delete_element"
                    class="w-full bg-red-50 text-red-600 px-4 py-2 rounded-lg hover:bg-red-100 flex items-center justify-center space-x-2"
                  >
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                    <span>Eliminar</span>
                  </button>
                </div>
              <% else %>
                <h3 class="font-semibold text-gray-900 mb-4">Propiedades de Etiqueta</h3>
                <.label_properties design={@design} />

                <!-- Data loaded indicator (only for multiple labels) -->
                <%= if @design.label_type == "multiple" && @upload_total_rows > 0 do %>
                  <div class="mt-6 pt-4 border-t">
                    <div class="bg-indigo-50 rounded-lg p-3">
                      <div class="flex items-center space-x-2 text-indigo-700 mb-2">
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
                        </svg>
                        <span class="font-medium"><%= @upload_total_rows %> registros</span>
                      </div>
                      <p class="text-xs text-indigo-600">
                        Datos Excel cargados. Asigna columnas a los elementos y usa Vista previa para ver el resultado.
                      </p>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>

          <!-- Layers tab content -->
          <div :if={@sidebar_tab == "layers"} class="flex-1 flex flex-col overflow-hidden">
            <!-- Layer order + group controls -->
            <div class="px-3 py-2 border-b border-gray-100 flex items-center justify-center space-x-1 flex-shrink-0">
              <button :if={@selected_element} phx-click="bring_to_front" class="p-1.5 rounded hover:bg-gray-100 text-gray-600" title="Traer al frente">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 11l7-7 7 7M5 19l7-7 7 7" /></svg>
              </button>
              <button :if={@selected_element} phx-click="move_layer_up" class="p-1.5 rounded hover:bg-gray-100 text-gray-600" title="Subir una capa">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" /></svg>
              </button>
              <button :if={@selected_element} phx-click="move_layer_down" class="p-1.5 rounded hover:bg-gray-100 text-gray-600" title="Bajar una capa">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
              </button>
              <button :if={@selected_element} phx-click="send_to_back" class="p-1.5 rounded hover:bg-gray-100 text-gray-600" title="Enviar atras">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 13l-7 7-7-7m14-8l-7 7-7-7" /></svg>
              </button>
              <div :if={@selected_element && length(@selected_elements) >= 2} class="w-px h-4 bg-gray-300 mx-1"></div>
              <button :if={length(@selected_elements) >= 2} phx-click="group_elements" class="px-2 py-1 rounded hover:bg-gray-100 text-xs text-gray-600" title="Agrupar (Ctrl+G)">
                Agrupar
              </button>
              <button :if={@selected_element && (@selected_element.group_id != nil)} phx-click="ungroup_elements" class="px-2 py-1 rounded hover:bg-gray-100 text-xs text-gray-600" title="Desagrupar (Ctrl+Shift+G)">
                Desagrupar
              </button>
            </div>

            <!-- Layer list (hierarchical with groups) -->
            <div class="flex-1 overflow-y-auto" id="layers-list">
              <%= for item <- organized_layers(@design) do %>
                <%= case item.type do %>
                  <% :group -> %>
                    <!-- Group header -->
                    <div class={"group/header flex items-center px-3 py-1.5 bg-gray-50 border-b border-gray-100 cursor-pointer border-l-4 #{item.group_color}"}>
                      <button phx-click="toggle_group_collapsed" phx-value-group-id={item.group.id} class="p-0.5 rounded hover:bg-gray-200 text-gray-500 mr-1" title="Colapsar/Expandir">
                        <svg class={"w-3 h-3 transition-transform #{if MapSet.member?(@collapsed_groups, item.group.id), do: "-rotate-90"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                        </svg>
                      </button>
                      <button
                        phx-click="toggle_group_visibility"
                        phx-value-group-id={item.group.id}
                        class={"p-1 rounded transition #{if Map.get(item.group, :visible, true), do: "text-gray-600 hover:text-gray-800", else: "text-gray-300 hover:text-gray-500"}"}
                        title={if Map.get(item.group, :visible, true), do: "Ocultar grupo", else: "Mostrar grupo"}
                      >
                        <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <%= if Map.get(item.group, :visible, true) do %>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                          <% else %>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                          <% end %>
                        </svg>
                      </button>
                      <button
                        phx-click="toggle_group_lock"
                        phx-value-group-id={item.group.id}
                        class={"p-1 rounded transition #{if Map.get(item.group, :locked, false), do: "text-yellow-600 hover:text-yellow-700", else: "text-gray-400 hover:text-gray-600"}"}
                        title={if Map.get(item.group, :locked, false), do: "Desbloquear grupo", else: "Bloquear grupo"}
                      >
                        <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <%= if Map.get(item.group, :locked, false) do %>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                          <% else %>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 11V7a4 4 0 118 0m-4 8v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2z" />
                          <% end %>
                        </svg>
                      </button>
                      <div class="flex-1 ml-1 flex items-center min-w-0">
                        <svg class="w-3.5 h-3.5 text-indigo-500 mr-1.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
                        </svg>
                        <%= if @editing_group_id == item.group.id do %>
                          <form phx-submit="confirm_rename_group" phx-click-away="cancel_rename_group" class="flex-1 min-w-0">
                            <input
                              type="hidden"
                              name="group-id"
                              value={item.group.id}
                            />
                            <input
                              type="text"
                              name="name"
                              value={item.group.name}
                              class="w-full text-xs font-medium text-gray-700 border border-blue-400 rounded px-1 py-0 focus:ring-1 focus:ring-blue-500 focus:outline-none"
                              phx-mounted={Phoenix.LiveView.JS.dispatch("focus-and-select", to: "#rename-group-input")}
                              id="rename-group-input"
                              autofocus
                            />
                          </form>
                        <% else %>
                          <span class="text-xs font-medium text-gray-700 truncate"><%= item.group.name %></span>
                          <button
                            phx-click="start_rename_group"
                            phx-value-group-id={item.group.id}
                            class="opacity-0 group-hover/header:opacity-100 p-0.5 rounded text-gray-400 hover:text-blue-500 transition ml-1 flex-shrink-0"
                            title="Renombrar grupo"
                          >
                            <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                              <path stroke-linecap="round" stroke-linejoin="round" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                            </svg>
                          </button>
                        <% end %>
                        <span class="ml-1 text-xs text-gray-400"><%= length(item.children) %></span>
                      </div>
                    </div>
                    <!-- Group children (collapsible) -->
                    <%= unless MapSet.member?(@collapsed_groups, item.group.id) do %>
                      <%= for element <- item.children do %>
                        <.layer_row element={element} selected_element={@selected_element} indent={true} group_color={item.group_color} />
                      <% end %>
                    <% end %>
                  <% :element -> %>
                    <.layer_row element={item.element} selected_element={@selected_element} indent={false} group_color={nil} />
                <% end %>
              <% end %>
            </div>

            <!-- Empty state -->
            <div :if={@element_count == 0} class="flex-1 flex items-center justify-center p-4">
              <p class="text-sm text-gray-400 text-center">No hay elementos.<br/>Agrega uno desde la barra de herramientas.</p>
            </div>
          </div>
        </div>

        <!-- Versions Panel (overlay) -->
        <div :if={@show_versions} class="absolute right-72 top-0 bottom-0 w-80 bg-gray-50 border-l border-gray-200 flex flex-col shadow-lg z-20">
          <div class="flex items-center justify-between px-4 py-3 border-b border-gray-200 bg-white flex-shrink-0">
            <h3 class="font-semibold text-gray-900">Historial de versiones</h3>
            <button phx-click="toggle_versions" class="text-gray-400 hover:text-gray-600">
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <%= if @selected_version do %>
            <!-- Version detail view -->
            <div class="flex-1 overflow-y-auto p-4">
              <button phx-click="close_version_detail" class="flex items-center text-sm text-blue-600 hover:text-blue-800 mb-3">
                <svg class="w-4 h-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                </svg>
                Volver a la lista
              </button>

              <div class="bg-white rounded-lg border border-gray-200 p-4 mb-4">
                <div class="flex items-center justify-between mb-2">
                  <span class="text-lg font-bold text-gray-900">v<%= @selected_version.version_number %></span>
                  <span class="text-xs text-gray-500">
                    <%= Calendar.strftime(@selected_version.inserted_at, "%d/%m/%Y %H:%M") %>
                  </span>
                </div>
                <%= if @selected_version.custom_name do %>
                  <p class="text-sm font-medium text-indigo-700 mb-1"><%= @selected_version.custom_name %></p>
                <% end %>
                <p class="text-sm text-gray-600"><%= @selected_version.name %></p>
                <div class="flex items-center mt-2 text-xs text-gray-500">
                  <svg class="w-3.5 h-3.5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                  </svg>
                  <%= if @selected_version.user, do: @selected_version.user.email, else: "Sistema" %>
                </div>
                <div class="flex items-center mt-1 text-xs text-gray-500">
                  <svg class="w-3.5 h-3.5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                  </svg>
                  <%= @selected_version.element_count %> elementos
                </div>
              </div>

              <%= if @selected_version.thumbnail do %>
                <div class="bg-white rounded-lg border border-gray-200 p-3 mb-4">
                  <h4 class="text-xs font-medium text-gray-500 mb-2">PREVIEW</h4>
                  <div class="flex justify-center bg-gray-50 rounded p-2">
                    <img src={@selected_version.thumbnail} alt={"Preview v#{@selected_version.version_number}"} class="max-w-full max-h-44 rounded" />
                  </div>
                </div>
              <% end %>

              <%= if @version_diff do %>
                <div class="bg-white rounded-lg border border-gray-200 p-4 mb-4">
                  <h4 class="text-xs font-medium text-gray-500 mb-3">CAMBIOS EN ESTA VERSION</h4>

                  <%= if map_size(@version_diff.fields) > 0 do %>
                    <div class="mb-3">
                      <p class="text-xs font-medium text-gray-700 mb-1">Campos modificados:</p>
                      <%= for {field, %{from: from, to: to}} <- @version_diff.fields do %>
                        <div class="text-xs py-1 border-b border-gray-100 last:border-0">
                          <span class="font-medium text-gray-600"><%= field %></span>
                          <div class="flex gap-2 mt-0.5">
                            <span class="text-red-500 line-through"><%= from || "—" %></span>
                            <span class="text-green-600"><%= to || "—" %></span>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>

                  <div class="flex items-center gap-3 text-xs">
                    <%= if length(@version_diff.elements.added) > 0 do %>
                      <span class="text-green-600">+<%= length(@version_diff.elements.added) %> nuevos</span>
                    <% end %>
                    <%= if length(@version_diff.elements.removed) > 0 do %>
                      <span class="text-red-500">-<%= length(@version_diff.elements.removed) %> eliminados</span>
                    <% end %>
                    <%= if length(@version_diff.elements.modified) > 0 do %>
                      <span class="text-amber-600">~<%= length(@version_diff.elements.modified) %> modificados</span>
                    <% end %>
                    <%= if length(@version_diff.elements.added) == 0 and length(@version_diff.elements.removed) == 0 and length(@version_diff.elements.modified) == 0 and map_size(@version_diff.fields) == 0 do %>
                      <span class="text-gray-500">Sin cambios</span>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <button
                phx-click="restore_version"
                phx-value-version={@selected_version.version_number}
                data-confirm={"Restaurar el diseño a la versión v#{@selected_version.version_number}?"}
                class="w-full py-2.5 rounded-lg font-medium transition flex items-center justify-center space-x-2 bg-amber-600 hover:bg-amber-700 text-white text-sm"
              >
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                <span>Restaurar esta versión</span>
              </button>
            </div>
          <% else %>
            <!-- Version list -->
            <div class="flex-1 overflow-y-auto">
              <%= if @versions == [] do %>
                <div class="p-4 text-center text-sm text-gray-500">
                  <svg class="w-10 h-10 mx-auto mb-2 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <p>No hay versiones guardadas aún.</p>
                  <p class="text-xs text-gray-400 mt-1">Pulsa Guardar para crear la primera versión.</p>
                </div>
              <% else %>
                <div class="divide-y divide-gray-200">
                  <%= for version <- @versions do %>
                    <div class="px-4 py-3 hover:bg-gray-100 transition">
                      <%!-- Row 1: vN + badge + custom_name + pencil + date --%>
                      <div class="flex items-center justify-between mb-1">
                        <div class="flex items-center gap-2 min-w-0">
                          <span class="text-sm font-bold text-gray-900 flex-shrink-0">v<%= version.version_number %></span>
                          <%= if version.version_number == @current_version_number do %>
                            <span class="text-[10px] px-1.5 py-0.5 bg-blue-100 text-blue-700 rounded font-medium flex-shrink-0">actual</span>
                          <% end %>
                          <%= if version.custom_name && @renaming_version_id != version.version_number do %>
                            <span class="text-xs font-medium text-indigo-700 truncate"><%= version.custom_name %></span>
                          <% end %>
                          <%= if @renaming_version_id != version.version_number do %>
                            <button
                              phx-click="start_rename_version"
                              phx-value-version={version.version_number}
                              class="text-gray-400 hover:text-blue-600 flex-shrink-0 transition"
                              title="Renombrar versión"
                            >
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                              </svg>
                            </button>
                          <% end %>
                        </div>
                        <span class="text-xs text-gray-400 flex-shrink-0 ml-2">
                          <%= Calendar.strftime(version.inserted_at, "%d/%m %H:%M") %>
                        </span>
                      </div>
                      <%!-- Inline rename form --%>
                      <%= if @renaming_version_id == version.version_number do %>
                        <form phx-submit="save_rename_version" phx-value-version={version.version_number} class="flex items-center gap-1 mb-1">
                          <input
                            type="text"
                            name="custom_name"
                            value={@rename_version_value}
                            phx-keyup="update_rename_version_value"
                            class="flex-1 text-xs border border-gray-300 rounded px-2 py-1 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                            placeholder="Nombre personalizado"
                            autofocus
                          />
                          <button type="submit" class="text-xs text-green-600 hover:text-green-800 font-medium">OK</button>
                          <button type="button" phx-click="cancel_rename_version" class="text-xs text-gray-400 hover:text-gray-600">X</button>
                        </form>
                      <% end %>
                      <%!-- Row 2: user email --%>
                      <div class="text-xs text-gray-500 mb-1">
                        <%= if version.user, do: version.user.email, else: "Sistema" %>
                      </div>
                      <%!-- Row 3: actions --%>
                      <div class="flex items-center justify-end">
                        <div class="flex gap-2 flex-shrink-0">
                          <button
                            phx-click="select_version"
                            phx-value-version={version.version_number}
                            class="text-xs text-blue-600 hover:text-blue-800 font-medium"
                          >
                            Ver
                          </button>
                          <button
                            phx-click="restore_version"
                            phx-value-version={version.version_number}
                            data-confirm={"Restaurar a v#{version.version_number}?"}
                            class="text-xs text-amber-600 hover:text-amber-800 font-medium"
                          >
                            Restaurar
                          </button>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Approval History Panel (overlay) -->
        <div :if={@show_approval_history} class="absolute right-72 top-0 bottom-0 w-80 bg-gray-50 border-l border-gray-200 flex flex-col shadow-lg z-20">
          <div class="flex items-center justify-between px-4 py-3 border-b border-gray-200 bg-white flex-shrink-0">
            <h3 class="font-semibold text-gray-900">Historial de aprobaciones</h3>
            <button phx-click="toggle_approval_history" class="text-gray-400 hover:text-gray-600">
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <div class="flex-1 overflow-y-auto">
            <%= if @approval_history == [] do %>
              <div class="p-4 text-center text-sm text-gray-500">
                <p>No hay historial de aprobaciones.</p>
              </div>
            <% else %>
              <div class="divide-y divide-gray-200">
                <%= for approval <- @approval_history do %>
                  <div class="px-4 py-3">
                    <div class="flex items-center justify-between mb-1">
                      <span class={"text-xs font-medium px-2 py-0.5 rounded-full " <>
                        case approval.action do
                          "request_review" -> "bg-amber-100 text-amber-700"
                          "approve" -> "bg-green-100 text-green-700"
                          "reject" -> "bg-red-100 text-red-700"
                          _ -> "bg-gray-100 text-gray-600"
                        end}>
                        <%= case approval.action do
                          "request_review" -> "Enviado a revision"
                          "approve" -> "Aprobado"
                          "reject" -> "Rechazado"
                          _ -> approval.action
                        end %>
                      </span>
                      <span class="text-xs text-gray-400">
                        <%= Calendar.strftime(approval.inserted_at, "%d/%m/%Y %H:%M") %>
                      </span>
                    </div>
                    <p class="text-xs text-gray-500"><%= approval.user.email %></p>
                    <%= if approval.comment do %>
                      <p class="text-xs text-gray-700 mt-1 italic bg-gray-100 rounded p-2"><%= approval.comment %></p>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Compliance Detail Panel (overlay) -->
        <div :if={@show_compliance_panel && @design.compliance_standard} class="absolute right-72 top-0 bottom-0 w-80 bg-gray-50 border-l border-gray-200 flex flex-col shadow-lg z-20">
          <div class="flex items-center justify-between px-4 py-3 border-b border-gray-200 bg-white flex-shrink-0">
            <h3 class="font-semibold text-gray-900">Cumplimiento: <%= @compliance_standard_name %></h3>
            <button phx-click="toggle_compliance_panel" class="text-gray-400 hover:text-gray-600">
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          <div class="flex-1 overflow-y-auto">
            <%= if @compliance_issues == [] do %>
              <div class="p-6 text-center">
                <div class="w-12 h-12 rounded-full bg-green-100 flex items-center justify-center mx-auto mb-3">
                  <svg class="w-6 h-6 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                </div>
                <p class="text-sm font-medium text-green-700">Cumple con <%= @compliance_standard_name %></p>
                <p class="text-xs text-gray-500 mt-1">No se encontraron problemas.</p>
              </div>
            <% else %>
              <div class="divide-y divide-gray-200">
                <%= for {issue, idx} <- Enum.with_index(@compliance_issues) do %>
                  <%= if issue.fix_action && !issue.element_id do %>
                    <%!-- Missing field: entire row is clickable to add the element --%>
                    <div
                      id={"compliance-issue-#{idx}"}
                      class="px-4 py-3 hover:bg-blue-50 transition cursor-pointer group"
                      phx-click="add_compliance_element"
                      phx-value-type={issue.fix_action.type}
                      phx-value-name={issue.fix_action.name}
                      phx-value-text_content={issue.fix_action[:text_content]}
                      phx-value-font_size={issue.fix_action[:font_size]}
                      phx-value-font_weight={issue.fix_action[:font_weight]}
                      phx-value-barcode_format={issue.fix_action[:barcode_format]}
                      phx-value-compliance_role={issue.fix_action[:compliance_role]}
                    >
                      <div class="flex items-start gap-2">
                        <span class={"flex-shrink-0 mt-0.5 w-5 h-5 rounded-full flex items-center justify-center text-xs font-bold " <>
                          case issue.severity do
                            :error -> "bg-red-100 text-red-600"
                            :warning -> "bg-amber-100 text-amber-600"
                            :info -> "bg-blue-100 text-blue-600"
                          end}>
                          <%= case issue.severity do
                            :error -> "!"
                            :warning -> "?"
                            :info -> "i"
                          end %>
                        </span>
                        <div class="flex-1 min-w-0">
                          <p class="text-sm text-gray-900"><%= issue.message %></p>
                          <p :if={issue.fix_hint} class="text-xs text-gray-500 mt-0.5"><%= issue.fix_hint %></p>
                          <div class="flex items-center justify-between mt-1">
                            <p class="text-xs text-gray-400 font-mono"><%= issue.code %></p>
                            <span class="inline-flex items-center gap-1 px-2 py-0.5 bg-blue-100 group-hover:bg-blue-200 text-blue-700 rounded text-xs font-medium transition">
                              <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
                              </svg>
                              Agregar campo
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% else %>
                    <%!-- Existing element issue: click focuses the element --%>
                    <div
                      id={"compliance-issue-#{idx}"}
                      class={"px-4 py-3 hover:bg-gray-100 transition" <> if(issue.element_id, do: " cursor-pointer", else: "")}
                      phx-click={if issue.element_id, do: "focus_compliance_issue"}
                      phx-value-element_id={issue.element_id}
                    >
                      <div class="flex items-start gap-2">
                        <span class={"flex-shrink-0 mt-0.5 w-5 h-5 rounded-full flex items-center justify-center text-xs font-bold " <>
                          case issue.severity do
                            :error -> "bg-red-100 text-red-600"
                            :warning -> "bg-amber-100 text-amber-600"
                            :info -> "bg-blue-100 text-blue-600"
                          end}>
                          <%= case issue.severity do
                            :error -> "!"
                            :warning -> "?"
                            :info -> "i"
                          end %>
                        </span>
                        <div class="flex-1 min-w-0">
                          <p class="text-sm text-gray-900"><%= issue.message %></p>
                          <p :if={issue.fix_hint} class="text-xs text-gray-500 mt-0.5"><%= issue.fix_hint %></p>
                          <p class="text-xs text-gray-400 font-mono mt-1"><%= issue.code %></p>
                        </div>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Preview Panel (overlay) -->
        <div :if={@show_preview} class="absolute right-72 top-16 bottom-0 w-96 bg-gray-50 border-l border-gray-200 overflow-auto p-4 shadow-lg z-20">
          <div class="flex items-center justify-between mb-4">
            <h3 class="font-semibold text-gray-900">Vista Previa</h3>
            <button phx-click="toggle_preview" class="text-gray-400 hover:text-gray-600">
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Language selector (only if design has multiple languages) -->
          <%= if length(@design.languages || ["es"]) > 1 do %>
            <div class="bg-blue-50 rounded-lg p-3 mb-4">
              <label class="block text-xs font-medium text-blue-700 mb-1.5">Idioma de vista previa</label>
              <div class="flex flex-wrap gap-1.5">
                <%= for lang <- (@design.languages || ["es"]) do %>
                  <% {_code, name, flag} = Enum.find(@available_languages, {"es", "Español", "🇪🇸"}, fn {c, _, _} -> c == lang end) %>
                  <button
                    phx-click="set_preview_language"
                    phx-value-lang={lang}
                    class={"px-2 py-1 rounded text-xs font-medium transition #{if @preview_language == lang, do: "bg-blue-600 text-white", else: "bg-white text-gray-700 hover:bg-gray-100 border border-gray-200"}"}
                  >
                    <%= flag %> <%= name %>
                  </button>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Row Navigation (when multiple rows available) -->
          <%= if @upload_total_rows > 1 do %>
            <div class="bg-indigo-50 rounded-lg p-3 mb-4">
              <div class="flex items-center justify-between">
                <button
                  phx-click="preview_prev_row"
                  disabled={@preview_row_index == 0}
                  class={"p-2 rounded-lg transition #{if @preview_row_index == 0, do: "text-gray-300 cursor-not-allowed", else: "text-indigo-600 hover:bg-indigo-100"}"}
                >
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                  </svg>
                </button>
                <div class="text-center">
                  <span class="text-lg font-bold text-indigo-700"><%= @preview_row_index + 1 %></span>
                  <span class="text-sm text-indigo-600"> de <%= @upload_total_rows %></span>
                  <p class="text-xs text-indigo-500">etiquetas</p>
                </div>
                <button
                  phx-click="preview_next_row"
                  disabled={@preview_row_index >= @upload_total_rows - 1}
                  class={"p-2 rounded-lg transition #{if @preview_row_index >= @upload_total_rows - 1, do: "text-gray-300 cursor-not-allowed", else: "text-indigo-600 hover:bg-indigo-100"}"}
                >
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                  </svg>
                </button>
              </div>
            </div>
          <% end %>

          <div class="bg-white rounded-lg shadow p-3 mb-4">
            <h4 class="text-xs font-medium text-gray-500 mb-2">
              <%= if @upload_total_rows > 0 do %>
                DATOS DE FILA <%= @preview_row_index + 1 %>
              <% else %>
                DATOS DE EJEMPLO
              <% end %>
            </h4>
            <div class="space-y-1 text-sm max-h-40 overflow-y-auto">
              <%= for {key, value} <- @preview_data do %>
                <div class="flex justify-between gap-2">
                  <span class="text-gray-500 truncate"><%= key %></span>
                  <span class="font-mono text-gray-900 truncate text-right"><%= value %></span>
                </div>
              <% end %>
            </div>
          </div>

          <div class="flex justify-center bg-white rounded-lg p-4 shadow">
            <div
              id="live-preview"
              phx-hook="LabelPreview"
              phx-update="ignore"
              class="inline-block"
            >
            </div>
          </div>

          <!-- Summary when data is loaded -->
          <%= if @upload_total_rows > 0 do %>
            <div class="mt-4 p-3 bg-green-50 rounded-lg border border-green-200">
              <div class="flex items-center space-x-2 text-green-700">
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span class="font-medium"><%= @upload_total_rows %> registros cargados</span>
              </div>
            </div>
          <% end %>

          <!-- Print Actions -->
          <div class="mt-3">
            <button
              phx-click="generate_and_print"
              class="w-full py-2.5 rounded-lg font-medium transition flex items-center justify-center space-x-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
              </svg>
              <span>Imprimir <%= if @upload_total_rows > 0, do: "#{@upload_total_rows} etiquetas", else: "etiqueta" %></span>
            </button>
            <div class="flex items-center gap-2 mt-2">
              <button phx-click="generate_and_download_pdf" class="flex-1 py-2 rounded-lg text-sm font-medium transition flex items-center justify-center gap-1.5 border border-gray-300 text-gray-700 hover:bg-gray-50 hover:border-gray-400">
                <svg class="w-4 h-4 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                PDF
              </button>
              <button phx-click="download_zpl" class="flex-1 py-2 rounded-lg text-sm font-medium transition flex items-center justify-center gap-1.5 border border-gray-300 text-gray-700 hover:bg-gray-50 hover:border-gray-400">
                <span class="font-bold text-violet-600">ZPL</span>
                <span class="text-gray-400 text-xs"><%= @zpl_dpi %></span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    <!-- PrintEngine hook (always mounted) -->
    <div id="print-engine-container" phx-hook="PrintEngine" data-user-id={@current_user.id} data-design-id={@design.id} class="hidden"></div>
    """
  end

  defp section_header(assigns) do
    ~H"""
    <button type="button" phx-click="toggle_section" phx-value-section={@id}
      class="w-full flex items-center justify-between py-2 text-sm font-medium text-gray-700 hover:text-gray-900 transition-colors">
      <span><%= @title %></span>
      <svg class={"w-4 h-4 text-gray-400 transition-transform #{if @collapsed, do: "-rotate-90"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
      </svg>
    </button>
    """
  end

  defp layer_row(assigns) do
    ~H"""
    <div
      class={"group/row flex items-center py-2 border-b border-gray-50 cursor-pointer transition #{if @indent, do: "pl-8 pr-3 border-l-4 #{@group_color}", else: "px-3"} #{if @selected_element && @selected_element.id == @element.id, do: "bg-blue-50", else: "hover:bg-gray-50"}"}
      phx-click="select_layer"
      phx-value-id={@element.id}
      data-id={@element.id}
    >
      <button
        phx-click="toggle_element_visibility"
        phx-value-id={@element.id}
        class={"p-1 rounded transition #{if Map.get(@element, :visible, true), do: "text-gray-600 hover:text-gray-800", else: "text-gray-300 hover:text-gray-500"}"}
        title={if Map.get(@element, :visible, true), do: "Ocultar", else: "Mostrar"}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <%= if Map.get(@element, :visible, true) do %>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
          <% else %>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
          <% end %>
        </svg>
      </button>
      <button
        phx-click="toggle_element_lock"
        phx-value-id={@element.id}
        class={"p-1 rounded transition #{if Map.get(@element, :locked, false), do: "text-yellow-600 hover:text-yellow-700", else: "text-gray-400 hover:text-gray-600"}"}
        title={if Map.get(@element, :locked, false), do: "Desbloquear", else: "Bloquear"}
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <%= if Map.get(@element, :locked, false) do %>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
          <% else %>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 11V7a4 4 0 118 0m-4 8v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2z" />
          <% end %>
        </svg>
      </button>
      <div class="flex-1 ml-2 flex items-center min-w-0">
        <span class={"text-xs mr-2 #{if Map.get(@element, :visible, true), do: "text-gray-500", else: "text-gray-300"}"}>
          <%= case @element.type do %>
            <% "qr" -> %>QR
            <% "barcode" -> %>BC
            <% "text" -> %>T
            <% "line" -> %>&#8212;
            <% "rectangle" -> %>&#9633;
            <% "circle" -> %>&#9675;
            <% "image" -> %>IMG
            <% _ -> %>?
          <% end %>
        </span>
        <span class={"text-sm truncate #{if Map.get(@element, :visible, true), do: "text-gray-700", else: "text-gray-400"}"}>
          <%= Map.get(@element, :name) || @element.type %>
        </span>
      </div>
      <%= if @indent do %>
        <button
          phx-click="remove_from_group"
          phx-value-id={@element.id}
          class="opacity-0 group-hover/row:opacity-100 p-1 rounded text-gray-400 hover:text-red-500 hover:bg-red-50 transition"
          title="Sacar del grupo"
        >
          <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      <% end %>
    </div>
    """
  end

  # Organize elements into a hierarchical list of groups and ungrouped elements
  @group_colors ~w(border-l-blue-400 border-l-violet-400 border-l-orange-400 border-l-emerald-400 border-l-rose-400 border-l-cyan-400 border-l-amber-400 border-l-fuchsia-400)

  defp organized_layers(design) do
    elements = design.elements || []
    groups = design.groups || []
    sorted_elements = Enum.sort_by(elements, fn el -> Map.get(el, :z_index, 0) end, :desc)

    # Build group lookup
    group_map = Map.new(groups, fn g -> {g.id, g} end)

    # Assign a stable color to each group based on its position in the groups list
    group_color_map = groups
    |> Enum.with_index()
    |> Map.new(fn {g, idx} -> {g.id, Enum.at(@group_colors, rem(idx, length(@group_colors)))} end)

    # Partition elements by group membership
    {grouped, ungrouped} = Enum.split_with(sorted_elements, fn el ->
      gid = Map.get(el, :group_id)
      gid != nil and Map.has_key?(group_map, gid)
    end)

    # Group elements by their group_id
    by_group = Enum.group_by(grouped, fn el -> Map.get(el, :group_id) end)

    # Build list: for each group, compute max z_index of its members for ordering
    group_items = Enum.map(by_group, fn {gid, members} ->
      group = Map.get(group_map, gid)
      max_z = Enum.max_by(members, fn el -> Map.get(el, :z_index, 0) end) |> Map.get(:z_index, 0)
      %{type: :group, group: group, children: members, max_z: max_z, group_color: Map.get(group_color_map, gid)}
    end)

    # Build ungrouped element items
    ungrouped_items = Enum.map(ungrouped, fn el ->
      %{type: :element, element: el, max_z: Map.get(el, :z_index, 0)}
    end)

    # Merge and sort by max_z descending
    (group_items ++ ungrouped_items)
    |> Enum.sort_by(& &1.max_z, :desc)
  end

  defp element_properties(assigns) do
    ~H"""
    <div class="space-y-1" id="property-fields" phx-hook="PropertyFields">
      <!-- Section: Posición y tamaño -->
      <div class="border-b border-gray-200">
        <.section_header id="position" title="Posición y tamaño" collapsed={MapSet.member?(@collapsed_sections, "position")} />
        <div class={if MapSet.member?(@collapsed_sections, "position"), do: "hidden", else: "pb-3 space-y-3"}>
          <div>
            <label class="block text-sm font-medium text-gray-700">Nombre</label>
            <input
              type="text"
              name="value"
              value={Map.get(@element, :name) || @element.type}
              phx-blur="update_element"
              phx-value-field="name"
              onfocus="this.setSelectionRange(this.value.length, this.value.length)"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
            />
          </div>
          <%= if @compliance_standard do %>
            <% roles = compliance_roles_for(@compliance_standard) %>
            <% assigned = Enum.reduce(@all_elements, MapSet.new(), fn el, acc ->
              role = Map.get(el, :compliance_role) || Map.get(el, "compliance_role")
              el_id = Map.get(el, :id) || Map.get(el, "id")
              current_id = Map.get(@element, :id) || Map.get(@element, "id")
              if role && role != "" && el_id != current_id, do: MapSet.put(acc, role), else: acc
            end) %>
            <div>
              <label class="block text-sm font-medium text-gray-700">Rol normativo</label>
              <form phx-change="update_element">
                <input type="hidden" name="field" value="compliance_role" />
                <select name="value" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm">
                  <option value="">Sin rol</option>
                  <%= for {value, label} <- roles do %>
                    <option value={value} selected={(Map.get(@element, :compliance_role) || "") == value}>
                      <%= label %><%= if MapSet.member?(assigned, value), do: " ✓" %>
                    </option>
                  <% end %>
                </select>
              </form>
            </div>
          <% end %>
          <div class="grid grid-cols-3 gap-2">
            <div>
              <label class="block text-xs font-medium text-gray-500">X (mm)</label>
              <input
                type="number"
                name="value"
                step="0.1"
                placeholder="mm"
                value={@element.x}
                phx-blur="update_element"
                phx-value-field="x"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
              />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-500">Y (mm)</label>
              <input
                type="number"
                name="value"
                step="0.1"
                placeholder="mm"
                value={@element.y}
                phx-blur="update_element"
                phx-value-field="y"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
              />
            </div>
            <div>
              <label class="block text-xs font-medium text-gray-500">Rotacion</label>
              <input
                type="number"
                name="value"
                step="1"
                placeholder="&deg;"
                value={@element.rotation || 0}
                phx-blur="update_element"
                phx-value-field="rotation"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
              />
            </div>
          </div>
          <%= if @element.type != "text" do %>
            <div class="grid grid-cols-2 gap-2">
              <div>
                <label class="block text-xs font-medium text-gray-500">Ancho</label>
                <input
                  type="number"
                  name="value"
                  step="0.1"
                  placeholder="mm"
                  value={@element.width}
                  phx-blur="update_element"
                  phx-value-field="width"
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                />
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-500">Alto</label>
                <input
                  type="number"
                  name="value"
                  step="0.1"
                  placeholder="mm"
                  value={@element.height}
                  phx-blur="update_element"
                  phx-value-field="height"
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                />
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Section: Translation (prominent, only for non-default language + fixed text) -->
      <% is_non_default_lang = @preview_language != (@design.default_language || "es") %>
      <% has_binding = (@element.binding || "") != "" %>
      <%= if is_non_default_lang && @element.type == "text" && !has_binding do %>
        <% {_code, lang_name, lang_flag} = Enum.find(@available_languages, {"es", "Español", "🇪🇸"}, fn {c, _, _} -> c == @preview_language end) %>
        <% current_translation = Map.get(@element.translations || %{}, @preview_language, "") %>
        <% has_translation = current_translation != "" %>
        <div class="border-b border-gray-200">
          <div class="p-3 space-y-2">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-1.5">
                <span class="text-sm"><%= lang_flag %></span>
                <span class="text-xs font-semibold text-gray-700">Traducción (<%= lang_name %>)</span>
              </div>
              <%= if !has_translation do %>
                <span class="text-[10px] font-medium text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded">Pendiente</span>
              <% end %>
            </div>
            <form phx-change="update_translation">
              <input type="hidden" name="element_id" value={@element.id} />
              <input type="hidden" name="lang" value={@preview_language} />
              <input
                type="text"
                value={current_translation}
                name="value"
                phx-debounce="500"
                placeholder={"Traducir al #{String.downcase(lang_name)}..."}
                class={"w-full text-sm rounded-md shadow-sm #{if has_translation, do: "border-gray-300", else: "border-amber-300 focus:border-amber-500 focus:ring-amber-500"}"}
              />
            </form>
            <div class="flex items-center justify-between">
              <p class="text-[11px] text-gray-400">
                Original: <span class="font-medium text-gray-500"><%= @element.text_content || "(vacío)" %></span>
              </p>
              <% untranslated = Enum.filter(@design.elements || [], fn el ->
                el.type == "text" && (el.binding || "") == "" &&
                (el.text_content || "") != "" &&
                (Map.get(el.translations || %{}, @preview_language, "") == "")
              end) %>
              <%= if length(untranslated) > 0 do %>
                <% next = Enum.find(untranslated, List.first(untranslated), fn el -> el.id != @element.id end) %>
                <button
                  type="button"
                  phx-click="select_element"
                  phx-value-id={next.id}
                  class="inline-flex items-center gap-1 text-[11px] text-amber-600 hover:text-amber-800 font-medium"
                  title={"#{length(untranslated)} pendiente(s)"}
                >
                  <span class="bg-amber-100 text-amber-700 px-1 rounded text-[10px]"><%= length(untranslated) %></span>
                  Siguiente
                  <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" /></svg>
                </button>
              <% else %>
                <span class="inline-flex items-center gap-1 text-[11px] text-green-600 font-medium">
                  <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
                  Todo traducido
                </span>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Section: Contenido (only for qr/barcode/text) -->
      <%= if @element.type in ["qr", "barcode", "text"] do %>
        <div class="border-b border-gray-200">
          <.section_header id="content" title="Contenido" collapsed={MapSet.member?(@collapsed_sections, "content")} />
          <div class={if MapSet.member?(@collapsed_sections, "content"), do: "hidden", else: "pb-3 space-y-3"}>
            <%= if @label_type == "multiple" do %>
              <% cm = content_mode(@element, @show_binding_mode, @show_expression_mode) %>
              <!-- Selector de modo (3 tabs) -->
              <div class="flex rounded-lg border border-gray-300 overflow-hidden">
                <button
                  type="button"
                  phx-click="set_content_mode"
                  phx-value-mode="binding"
                  class={"flex-1 px-2 py-2 text-xs font-medium transition-colors #{if cm == :column, do: "bg-indigo-600 text-white", else: "bg-white text-gray-700 hover:bg-gray-50"}"}
                >
                  Columna
                </button>
                <button
                  type="button"
                  phx-click="set_content_mode"
                  phx-value-mode="fixed"
                  class={"flex-1 px-2 py-2 text-xs font-medium transition-colors border-l border-gray-300 #{if cm == :text, do: "bg-indigo-600 text-white", else: "bg-white text-gray-700 hover:bg-gray-50"}"}
                >
                  Texto fijo
                </button>
                <button
                  type="button"
                  phx-click="set_content_mode"
                  phx-value-mode="expression"
                  class={"flex-1 px-2 py-2 text-xs font-medium transition-colors border-l border-gray-300 #{if cm == :expression, do: "bg-violet-600 text-white", else: "bg-white text-gray-700 hover:bg-gray-50"}"}
                >
                  Expresion
                </button>
              </div>

              <%= case cm do %>
                <% :column -> %>
                  <%= if length(@available_columns) > 0 do %>
                    <form phx-change="update_element">
                      <input type="hidden" name="field" value="binding" />
                      <select
                        name="value"
                        class="block w-full rounded-md border-gray-300 shadow-sm text-sm"
                      >
                        <option value="">Seleccionar columna...</option>
                        <%= for {col, flags} <- columns_with_flags(@available_columns, @design.languages || ["es"]) do %>
                          <option value={col} selected={(Map.get(@element, :binding) || "") == col}><%= col %><%= if flags != "", do: " " <> flags %></option>
                        <% end %>
                      </select>
                    </form>
                    <p class="text-xs text-gray-500">
                      El contenido cambiará según cada fila de datos
                    </p>
                  <% else %>
                    <div class="bg-amber-50 border border-amber-200 rounded-lg p-3">
                      <div class="flex items-start space-x-3">
                        <svg class="w-5 h-5 text-amber-500 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                        </svg>
                        <div class="flex-1">
                          <p class="text-sm font-medium text-amber-800">No hay datos cargados</p>
                          <p class="text-xs text-amber-700 mt-1">
                            Para vincular a una columna, primero debes cargar un archivo de datos.
                          </p>
                          <.link
                            navigate={~p"/generate/data?design_id=#{@design_id}&element_id=#{@element.id}"}
                            class="inline-flex items-center space-x-1 mt-2 text-sm font-medium text-amber-700 hover:text-amber-900"
                          >
                            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                            </svg>
                            <span>Cargar datos</span>
                          </.link>
                        </div>
                      </div>
                    </div>
                  <% end %>

                <% :text -> %>
                  <% bc_validation = if @element.type == "barcode", do: validate_barcode_content(Map.get(@element, :text_content), @element.barcode_format), else: nil %>
                  <form phx-change="update_element">
                    <input type="hidden" name="field" value="text_content" />
                    <input
                      type="text"
                      name="value"
                      data-field="text_content"
                      value={Map.get(@element, :text_content) || ""}
                      placeholder={get_fixed_text_placeholder(@element.type)}
                      phx-debounce={if @element.type in ["qr", "barcode"], do: "500", else: "300"}
                      class={[
                        "block w-full rounded-md shadow-sm text-sm",
                        if(bc_validation && not bc_validation.valid, do: "border-red-400 focus:border-red-500 focus:ring-red-500", else: "border-gray-300")
                      ]}
                    />
                  </form>
                  <%= if bc_validation && bc_validation.hint do %>
                    <p class={[
                      "text-xs mt-1",
                      if(not bc_validation.valid, do: "text-red-500 font-medium", else: "text-gray-400")
                    ]}><%= bc_validation.hint %></p>
                  <% else %>
                    <p class="text-xs text-gray-500 mt-1">
                      Este contenido sera igual en todas las etiquetas
                    </p>
                  <% end %>

                <% :expression -> %>
                  <%= case @expression_visual_mode do %>
                    <% :cards -> %>
                      <div class="grid grid-cols-2 gap-2">
                        <%= for pattern <- expression_patterns() do %>
                          <% {card_cls, text_cls, icon_cls} = pattern_color_classes(pattern.color) %>
                          <% disabled = pattern.needs_column && length(@available_columns) == 0 %>
                          <button
                            type="button"
                            phx-click="select_expression_pattern"
                            phx-value-pattern={pattern.id}
                            disabled={disabled}
                            class={"flex items-center gap-1.5 p-2 rounded-lg border text-left transition-colors min-w-0 #{card_cls} #{if disabled, do: "opacity-40 cursor-not-allowed", else: "cursor-pointer"}"}
                          >
                            <span class={"text-xs font-bold px-1.5 py-0.5 rounded shrink-0 #{icon_cls}"}><%= pattern.icon %></span>
                            <span class={"text-xs font-medium line-clamp-2 #{text_cls}"}><%= pattern.description %></span>
                          </button>
                        <% end %>
                      </div>
                      <button
                        type="button"
                        phx-click="toggle_expression_advanced"
                        class="text-xs text-gray-500 hover:text-gray-700 mt-1"
                      >
                        Modo avanzado &rarr;
                      </button>

                    <% {:form, pattern_id} -> %>
                      <% pattern = get_pattern(pattern_id) %>
                      <%= if pattern do %>
                        <% {_, text_cls, icon_cls} = pattern_color_classes(pattern.color) %>
                        <div class="flex items-center gap-2 mb-3">
                          <button type="button" phx-click="back_to_expression_cards" class="text-gray-400 hover:text-gray-600">
                            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" /></svg>
                          </button>
                          <span class={"text-xs font-bold px-1.5 py-0.5 rounded #{icon_cls}"}><%= pattern.icon %></span>
                          <span class={"text-sm font-semibold #{text_cls}"}><%= pattern.description %></span>
                        </div>

                        <form phx-change="update_expression_builder" class="space-y-3">
                          <%= case pattern_id do %>
                            <% p when p in [:uppercase, :lowercase] -> %>
                              <div>
                                <label class="block text-xs font-medium text-gray-600 mb-1">Columna</label>
                                <%= if length(@available_columns) > 0 do %>
                                  <select name="column" class="block w-full rounded-md border-gray-300 shadow-sm text-sm">
                                    <%= for {col, flags} <- columns_with_flags(@available_columns, @design.languages || ["es"]) do %>
                                      <option value={col} selected={Map.get(@expression_builder, "column") == col}><%= col %><%= if flags != "", do: " " <> flags %></option>
                                    <% end %>
                                  </select>
                                <% else %>
                                  <p class="text-xs text-amber-600">Carga un archivo de datos primero.</p>
                                <% end %>
                              </div>

                            <% :today -> %>
                              <div>
                                <label class="block text-xs font-medium text-gray-600 mb-1">Formato</label>
                                <select name="format" class="block w-full rounded-md border-gray-300 shadow-sm text-sm">
                                  <%= for fmt <- ["DD/MM/AAAA", "AAAA-MM-DD", "MM/DD/AAAA", "DD-MM-AAAA"] do %>
                                    <option value={fmt} selected={Map.get(@expression_builder, "format") == fmt}><%= fmt %></option>
                                  <% end %>
                                </select>
                              </div>

                            <% :counter -> %>
                              <div class="grid grid-cols-2 gap-2">
                                <div>
                                  <label class="block text-xs font-medium text-gray-600 mb-1">Inicio</label>
                                  <input type="number" name="start" min="0" value={Map.get(@expression_builder, "start", "1")} class="block w-full rounded-md border-gray-300 shadow-sm text-sm" />
                                </div>
                                <div>
                                  <label class="block text-xs font-medium text-gray-600 mb-1">Digitos</label>
                                  <input type="number" name="digits" min="1" max="10" value={Map.get(@expression_builder, "digits", "4")} class="block w-full rounded-md border-gray-300 shadow-sm text-sm" />
                                </div>
                              </div>

                            <% :batch -> %>
                              <div>
                                <label class="block text-xs font-medium text-gray-600 mb-1">Formato de lote</label>
                                <select name="format" class="block w-full rounded-md border-gray-300 shadow-sm text-sm">
                                  <%= for fmt <- ["AAMM-####", "AAAAMMDD-####", "AAAA-####", "####"] do %>
                                    <option value={fmt} selected={Map.get(@expression_builder, "format") == fmt}><%= fmt %></option>
                                  <% end %>
                                </select>
                              </div>

                            <% :expiry -> %>
                              <div class="space-y-2">
                                <div>
                                  <label class="block text-xs font-medium text-gray-600 mb-1">Dias a futuro</label>
                                  <input type="number" name="days" min="1" value={Map.get(@expression_builder, "days", "30")} class="block w-full rounded-md border-gray-300 shadow-sm text-sm" />
                                </div>
                                <div>
                                  <label class="block text-xs font-medium text-gray-600 mb-1">Formato</label>
                                  <select name="format" class="block w-full rounded-md border-gray-300 shadow-sm text-sm">
                                    <%= for fmt <- ["DD/MM/AAAA", "AAAA-MM-DD", "MM/DD/AAAA", "DD-MM-AAAA"] do %>
                                      <option value={fmt} selected={Map.get(@expression_builder, "format") == fmt}><%= fmt %></option>
                                    <% end %>
                                  </select>
                                </div>
                              </div>

                            <% :conditional -> %>
                              <div class="space-y-2">
                                <div>
                                  <label class="block text-xs font-medium text-gray-600 mb-1">Columna</label>
                                  <%= if length(@available_columns) > 0 do %>
                                    <select name="column" class="block w-full rounded-md border-gray-300 shadow-sm text-sm">
                                      <%= for {col, flags} <- columns_with_flags(@available_columns, @design.languages || ["es"]) do %>
                                        <option value={col} selected={Map.get(@expression_builder, "column") == col}><%= col %><%= if flags != "", do: " " <> flags %></option>
                                      <% end %>
                                    </select>
                                  <% else %>
                                    <p class="text-xs text-amber-600">Carga un archivo de datos primero.</p>
                                  <% end %>
                                </div>
                                <div>
                                  <label class="block text-xs font-medium text-gray-600 mb-1">Texto si vacio</label>
                                  <input type="text" name="alt_text" value={Map.get(@expression_builder, "alt_text", "N/A")} class="block w-full rounded-md border-gray-300 shadow-sm text-sm" />
                                </div>
                              </div>

                            <% :format_number -> %>
                              <div class="space-y-2">
                                <div>
                                  <label class="block text-xs font-medium text-gray-600 mb-1">Columna</label>
                                  <%= if length(@available_columns) > 0 do %>
                                    <select name="column" class="block w-full rounded-md border-gray-300 shadow-sm text-sm">
                                      <%= for {col, flags} <- columns_with_flags(@available_columns, @design.languages || ["es"]) do %>
                                        <option value={col} selected={Map.get(@expression_builder, "column") == col}><%= col %><%= if flags != "", do: " " <> flags %></option>
                                      <% end %>
                                    </select>
                                  <% else %>
                                    <p class="text-xs text-amber-600">Carga un archivo de datos primero.</p>
                                  <% end %>
                                </div>
                                <div>
                                  <label class="block text-xs font-medium text-gray-600 mb-1">Decimales</label>
                                  <input type="number" name="decimals" min="0" max="10" value={Map.get(@expression_builder, "decimals", "2")} class="block w-full rounded-md border-gray-300 shadow-sm text-sm" />
                                </div>
                              </div>

                            <% _ -> %>
                              <p class="text-xs text-gray-500">Sin opciones adicionales.</p>
                          <% end %>
                        </form>

                        <% {expr, result} = preview_expression(pattern_id, @expression_builder, @preview_data) %>
                        <div class="bg-gray-50 rounded-lg p-2.5 space-y-1 border border-gray-200">
                          <p class="text-[10px] font-medium text-gray-400 uppercase tracking-wide">Vista previa</p>
                          <p class="text-xs font-mono text-gray-600 break-all"><%= expr %></p>
                          <p class="text-sm font-semibold text-gray-900"><%= result %></p>
                        </div>

                        <%= if @expression_applied do %>
                          <button
                            type="button"
                            phx-click="apply_expression_pattern"
                            class="w-full bg-emerald-600 text-white px-3 py-2 rounded-lg text-sm font-medium hover:bg-emerald-700 transition-colors flex items-center justify-center gap-1.5"
                          >
                            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
                            Aplicado
                          </button>
                        <% else %>
                          <button
                            type="button"
                            phx-click="apply_expression_pattern"
                            class="w-full bg-indigo-600 text-white px-3 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors"
                          >
                            Aplicar
                          </button>
                        <% end %>
                      <% end %>

                    <% :advanced -> %>
                      <form phx-change="update_element">
                        <input type="hidden" name="field" value="binding" />
                        <textarea
                          name="value"
                          rows="3"
                          phx-debounce="500"
                          placeholder={"Ej: Lote: {{lote}} - {{HOY()}}"}
                          class="block w-full rounded-md border-gray-300 shadow-sm text-sm font-mono"
                        ><%= Map.get(@element, :binding) || "" %></textarea>
                      </form>

                      <div class="space-y-2">
                        <p class="text-xs font-medium text-gray-500">Insertar funcion:</p>
                        <div class="flex flex-wrap gap-1">
                          <span class="text-xs text-gray-400 w-full">Texto</span>
                          <%= for {label, tmpl} <- [{"MAYUS", "MAYUS(valor)"}, {"MINUS", "MINUS(valor)"}, {"CONCAT", "CONCAT(v1, v2)"}, {"RECORTAR", "RECORTAR(valor, largo)"}] do %>
                            <button
                              type="button"
                              phx-click="insert_expression_function"
                              phx-value-template={"{{#{tmpl}}}"}
                              class="px-2 py-0.5 text-xs bg-blue-50 text-blue-700 rounded border border-blue-200 hover:bg-blue-100"
                            ><%= label %></button>
                          <% end %>
                        </div>
                        <div class="flex flex-wrap gap-1">
                          <span class="text-xs text-gray-400 w-full">Fechas</span>
                          <%= for {label, tmpl} <- [{"HOY", "HOY()"}, {"AHORA", "AHORA()"}, {"+DIAS", "SUMAR_DIAS(HOY(), 30)"}, {"+MESES", "SUMAR_MESES(HOY(), 6)"}] do %>
                            <button
                              type="button"
                              phx-click="insert_expression_function"
                              phx-value-template={"{{#{tmpl}}}"}
                              class="px-2 py-0.5 text-xs bg-emerald-50 text-emerald-700 rounded border border-emerald-200 hover:bg-emerald-100"
                            ><%= label %></button>
                          <% end %>
                        </div>
                        <div class="flex flex-wrap gap-1">
                          <span class="text-xs text-gray-400 w-full">Contadores</span>
                          <%= for {label, tmpl} <- [{"CONTADOR", "CONTADOR(1, 1, 4)"}, {"LOTE", "LOTE(AAMM-####)"}, {"#NUM", "FORMATO_NUM(valor, 2)"}] do %>
                            <button
                              type="button"
                              phx-click="insert_expression_function"
                              phx-value-template={"{{#{tmpl}}}"}
                              class="px-2 py-0.5 text-xs bg-amber-50 text-amber-700 rounded border border-amber-200 hover:bg-amber-100"
                            ><%= label %></button>
                          <% end %>
                        </div>
                        <div class="flex flex-wrap gap-1">
                          <span class="text-xs text-gray-400 w-full">Condicionales</span>
                          <%= for {label, tmpl} <- [{"SI", "SI(valor == X, si, no)"}, {"VACIO", "VACIO(valor)"}, {"DEFECTO", "POR_DEFECTO(valor, alt)"}] do %>
                            <button
                              type="button"
                              phx-click="insert_expression_function"
                              phx-value-template={"{{#{tmpl}}}"}
                              class="px-2 py-0.5 text-xs bg-violet-50 text-violet-700 rounded border border-violet-200 hover:bg-violet-100"
                            ><%= label %></button>
                          <% end %>
                        </div>
                      </div>

                      <%= if length(@available_columns) > 0 do %>
                        <div class="space-y-1">
                          <p class="text-xs font-medium text-gray-500">Insertar columna:</p>
                          <div class="flex flex-wrap gap-1">
                            <%= for {col, flags} <- columns_with_flags(@available_columns, @design.languages || ["es"]) do %>
                              <button
                                type="button"
                                phx-click="insert_expression_function"
                                phx-value-template={"{{#{col}}}"}
                                class="px-2 py-0.5 text-xs bg-gray-100 text-gray-700 rounded border border-gray-300 hover:bg-gray-200 font-mono"
                              ><%= col %><%= if flags != "", do: " " <> flags %></button>
                            <% end %>
                          </div>
                        </div>
                      <% end %>

                      <button
                        type="button"
                        phx-click="toggle_expression_advanced"
                        class="text-xs text-gray-500 hover:text-gray-700"
                      >
                        &larr; Volver al constructor visual
                      </button>

                    <% _ -> %>
                      <p class="text-xs text-gray-500">Modo no reconocido.</p>
                  <% end %>
              <% end %>
            <% else %>
              <!-- Single label: direct content input -->
              <%= case @element.type do %>
                <% "qr" -> %>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Contenido codigo QR</label>
                    <form phx-change="update_element">
                      <input type="hidden" name="field" value="text_content" />
                      <input
                        type="text"
                        name="value"
                        data-field="text_content"
                        value={@element.text_content || ""}
                        phx-debounce="500"
                        placeholder="Completar"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                      />
                    </form>
                  </div>
                <% "barcode" -> %>
                  <% validation = validate_barcode_content(@element.text_content, @element.barcode_format) %>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Contenido codigo Barras</label>
                    <form phx-change="update_element">
                      <input type="hidden" name="field" value="text_content" />
                      <input
                        type="text"
                        name="value"
                        data-field="text_content"
                        value={@element.text_content || ""}
                        phx-debounce="500"
                        placeholder="Completar"
                        class={[
                          "mt-1 block w-full rounded-md shadow-sm text-sm",
                          if(not validation.valid, do: "border-red-400 focus:border-red-500 focus:ring-red-500", else: "border-gray-300")
                        ]}
                      />
                    </form>
                    <%= if validation.hint do %>
                      <p class={[
                        "text-xs mt-1",
                        if(not validation.valid, do: "text-red-500 font-medium", else: "text-gray-400")
                      ]}><%= validation.hint %></p>
                    <% end %>
                  </div>
                <% "text" -> %>
                  <div>
                    <label for="text_content_input" class="block text-sm font-medium text-gray-700">Contenido</label>
                    <form phx-change="update_element">
                      <input type="hidden" name="field" value="text_content" />
                      <input
                        type="text"
                        id="text_content_input"
                        name="value"
                        value={@element.text_content || ""}
                        phx-debounce="300"
                        placeholder="Completar"
                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                      />
                    </form>
                  </div>
                <% _ -> %>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Section: Tipografía (only for text) -->
      <%= if @element.type == "text" do %>
        <div class="border-b border-gray-200">
          <.section_header id="typography" title="Tipografía" collapsed={MapSet.member?(@collapsed_sections, "typography")} />
          <div class={if MapSet.member?(@collapsed_sections, "typography"), do: "hidden", else: "pb-3 space-y-2.5"}>
            <%!-- Row 1: Font family (full width, no label) --%>
            <form phx-change="update_element">
              <input type="hidden" name="field" value="font_family" />
              <select
                name="value"
                class="block w-full rounded-md border-gray-300 shadow-sm text-sm py-1.5"
              >
                <option value="Arial" selected={@element.font_family == "Arial"}>Arial</option>
                <option value="Helvetica" selected={@element.font_family == "Helvetica"}>Helvetica</option>
                <option value="Verdana" selected={@element.font_family == "Verdana"}>Verdana</option>
                <option value="Courier New" selected={@element.font_family == "Courier New"}>Courier New</option>
                <option value="Times New Roman" selected={@element.font_family == "Times New Roman"}>Times New Roman</option>
                <option value="Georgia" selected={@element.font_family == "Georgia"}>Georgia</option>
                <option value="sans-serif" selected={@element.font_family == "sans-serif"}>Sans-serif</option>
                <option value="serif" selected={@element.font_family == "serif"}>Serif</option>
                <option value="monospace" selected={@element.font_family == "monospace"}>Monospace</option>
              </select>
            </form>

            <%!-- Row 2: Size + Bold + Color + Alignment --%>
            <div class="flex items-center gap-1.5">
              <%!-- Font size --%>
              <input
                type="number"
                name="value"
                value={round(@element.font_size || 12)}
                phx-blur="update_element"
                phx-value-field="font_size"
                step="1"
                min="4"
                max="200"
                class="w-14 rounded-md border-gray-300 shadow-sm text-sm py-1.5 px-2 text-center"
                title="Tamaño de fuente"
              />

              <%!-- Bold toggle --%>
              <button
                type="button"
                phx-click="update_element"
                phx-value-field="font_weight"
                phx-value-value={if (@element.font_weight || "normal") == "bold", do: "normal", else: "bold"}
                class={"w-8 h-8 flex items-center justify-center rounded-md border text-sm font-bold transition " <>
                  if (@element.font_weight || "normal") == "bold",
                    do: "bg-gray-800 text-white border-gray-800",
                    else: "bg-white text-gray-500 border-gray-300 hover:bg-gray-50"}
                title="Negrita"
              >
                B
              </button>

              <%!-- Color picker --%>
              <input
                type="color"
                name="value"
                value={@element.color || "#000000"}
                phx-change="update_element"
                phx-value-field="color"
                class="w-8 h-8 rounded-md border border-gray-300 cursor-pointer p-0.5"
                title="Color de texto"
              />

              <%!-- Spacer --%>
              <div class="w-px h-5 bg-gray-200 mx-0.5"></div>

              <%!-- Alignment buttons --%>
              <div class="flex rounded-md border border-gray-300 overflow-hidden">
                <button
                  type="button"
                  phx-click="update_element"
                  phx-value-field="text_align"
                  phx-value-value="left"
                  class={"w-8 h-8 flex items-center justify-center transition " <>
                    if (@element.text_align || "left") == "left",
                      do: "bg-gray-800 text-white",
                      else: "bg-white text-gray-500 hover:bg-gray-50"}
                  title="Alinear izquierda"
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" d="M3 6h18M3 12h12M3 18h16" />
                  </svg>
                </button>
                <button
                  type="button"
                  phx-click="update_element"
                  phx-value-field="text_align"
                  phx-value-value="center"
                  class={"w-8 h-8 flex items-center justify-center border-l border-r border-gray-300 transition " <>
                    if @element.text_align == "center",
                      do: "bg-gray-800 text-white border-gray-800",
                      else: "bg-white text-gray-500 hover:bg-gray-50"}
                  title="Centrar"
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" d="M3 6h18M6 12h12M4 18h16" />
                  </svg>
                </button>
                <button
                  type="button"
                  phx-click="update_element"
                  phx-value-field="text_align"
                  phx-value-value="right"
                  class={"w-8 h-8 flex items-center justify-center transition " <>
                    if @element.text_align == "right",
                      do: "bg-gray-800 text-white",
                      else: "bg-white text-gray-500 hover:bg-gray-50"}
                  title="Alinear derecha"
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" d="M3 6h18M9 12h12M5 18h16" />
                  </svg>
                </button>
              </div>
            </div>

            <%!-- Row 3: Auto-fit --%>
            <div class="flex items-center justify-between border-t border-gray-100 pt-2">
              <label class="flex items-center gap-2 text-sm text-gray-700">
                <form phx-change="update_element" class="flex items-center gap-2">
                  <input type="hidden" name="field" value="text_auto_fit" />
                  <input type="hidden" name="value" value="false" />
                  <input
                    type="checkbox"
                    name="value"
                    value="true"
                    checked={Map.get(@element, :text_auto_fit, false) == true}
                    class="rounded border-gray-300 text-blue-600 focus:ring-blue-500 w-3.5 h-3.5"
                  />
                  <span class="text-xs font-medium">Ajustar al area</span>
                </form>
              </label>
              <%= if Map.get(@element, :text_auto_fit, false) == true do %>
                <form phx-change="update_element" class="flex items-center gap-1.5">
                  <input type="hidden" name="field" value="text_min_font_size" />
                  <span class="text-xs text-gray-400">min</span>
                  <input
                    type="number"
                    name="value"
                    value={Map.get(@element, :text_min_font_size, 6.0)}
                    min="4"
                    max={Map.get(@element, :font_size, 10)}
                    step="0.5"
                    class="w-14 rounded-md border-gray-300 shadow-sm text-xs py-1 px-1.5 text-center"
                  />
                </form>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Section: Apariencia (type-specific visual props) -->
      <%= if @element.type in ["qr", "barcode", "image", "line", "rectangle", "circle"] do %>
        <div class="border-b border-gray-200">
          <.section_header id="appearance" title="Apariencia" collapsed={MapSet.member?(@collapsed_sections, "appearance")} />
          <div class={if MapSet.member?(@collapsed_sections, "appearance"), do: "hidden", else: "pb-3 space-y-3"}>
            <%= case @element.type do %>
              <% "qr" -> %>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Nivel de corrección de error</label>
                  <form phx-change="update_element" class="mt-1">
                    <input type="hidden" name="field" value="qr_error_level" />
                    <select
                      name="value"
                      class="block w-full rounded-md border-gray-300 shadow-sm text-sm"
                    >
                      <option value="L" selected={@element.qr_error_level == "L"}>L (7%)</option>
                      <option value="M" selected={@element.qr_error_level == "M"}>M (15%)</option>
                      <option value="Q" selected={@element.qr_error_level == "Q"}>Q (25%)</option>
                      <option value="H" selected={@element.qr_error_level == "H"}>H (30%)</option>
                    </select>
                  </form>
                </div>
                <div class="border-t pt-3">
                  <label class="block text-sm font-medium text-gray-700 mb-1">Logo en QR</label>
                  <%= if @element.qr_logo_data do %>
                    <div class="flex items-center gap-2 mb-2">
                      <img src={@element.qr_logo_data} class="w-10 h-10 object-contain border rounded" />
                      <button
                        type="button"
                        phx-click="update_element"
                        phx-value-field="qr_logo_data"
                        phx-value-value=""
                        class="text-xs text-red-600 hover:text-red-800"
                      >
                        Quitar logo
                      </button>
                    </div>
                    <div>
                      <label class="block text-xs text-gray-500 mb-1">Tamaño del logo (<%= round(@element.qr_logo_size || 25) %>%)</label>
                      <form phx-change="update_element">
                        <input type="hidden" name="field" value="qr_logo_size" />
                        <input
                          type="range"
                          name="value"
                          min="5"
                          max="30"
                          step="1"
                          value={@element.qr_logo_size || 25}
                          class="w-full"
                        />
                      </form>
                    </div>
                  <% else %>
                    <div
                      id="qr-logo-upload"
                      phx-hook="QRLogoUpload"
                      class="border-2 border-dashed border-gray-300 rounded-lg p-3 text-center cursor-pointer hover:border-blue-400 transition-colors"
                    >
                      <input
                        type="file"
                        accept="image/png,image/jpeg,image/svg+xml"
                        class="hidden"
                        id="qr-logo-file-input"
                      />
                      <p class="text-xs text-gray-500">Click para subir logo</p>
                      <p class="text-xs text-gray-400">PNG/JPG, max 500KB</p>
                    </div>
                  <% end %>
                  <p class="text-xs text-gray-400 mt-1">El nivel de error se fija en H con logo</p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Color del codigo</label>
                  <input
                    type="color"
                    name="value"
                    value={Map.get(@element, :color) || "#000000"}
                    phx-change="update_element"
                    phx-value-field="color"
                    class="mt-1 block w-full h-9 rounded-md border-gray-300"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Color de fondo</label>
                  <input
                    type="color"
                    name="value"
                    value={Map.get(@element, :background_color) || "#ffffff"}
                    phx-change="update_element"
                    phx-value-field="background_color"
                    class="mt-1 block w-full h-9 rounded-md border-gray-300"
                  />
                </div>

              <% "barcode" -> %>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Formato</label>
                  <form phx-change="update_element">
                  <input type="hidden" name="field" value="barcode_format" />
                  <select
                    name="value"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                  >
                    <optgroup label="1D General">
                      <%= for {value, label} <- [{"CODE128", "CODE128"}, {"CODE39", "CODE39"}, {"CODE93", "CODE93"}, {"CODABAR", "Codabar"}, {"MSI", "MSI"}, {"pharmacode", "Pharmacode"}] do %>
                        <% compatible = barcode_format_compatible?(@element.text_content, value) %>
                        <option value={value} selected={@element.barcode_format == value} disabled={not compatible}>
                          <%= label %><%= if not compatible, do: " ✗", else: "" %>
                        </option>
                      <% end %>
                    </optgroup>
                    <optgroup label="1D Retail">
                      <%= for {value, label} <- [{"EAN13", "EAN-13"}, {"EAN8", "EAN-8"}, {"UPC", "UPC-A"}, {"ITF14", "ITF-14"}, {"GS1_DATABAR", "GS1 DataBar"}, {"GS1_DATABAR_STACKED", "GS1 DataBar Stacked"}, {"GS1_DATABAR_EXPANDED", "GS1 DataBar Expanded"}] do %>
                        <% compatible = barcode_format_compatible?(@element.text_content, value) %>
                        <option value={value} selected={@element.barcode_format == value} disabled={not compatible}>
                          <%= label %><%= if not compatible, do: " ✗", else: "" %>
                        </option>
                      <% end %>
                    </optgroup>
                    <optgroup label="1D Supply Chain">
                      <%= for {value, label} <- [{"GS1_128", "GS1-128"}] do %>
                        <% compatible = barcode_format_compatible?(@element.text_content, value) %>
                        <option value={value} selected={@element.barcode_format == value} disabled={not compatible}>
                          <%= label %><%= if not compatible, do: " ✗", else: "" %>
                        </option>
                      <% end %>
                    </optgroup>
                    <optgroup label="2D">
                      <%= for {value, label} <- [{"DATAMATRIX", "DataMatrix"}, {"PDF417", "PDF417"}, {"AZTEC", "Aztec"}, {"MAXICODE", "MaxiCode"}] do %>
                        <% compatible = barcode_format_compatible?(@element.text_content, value) %>
                        <option value={value} selected={@element.barcode_format == value} disabled={not compatible}>
                          <%= label %><%= if not compatible, do: " ✗", else: "" %>
                        </option>
                      <% end %>
                    </optgroup>
                    <optgroup label="Postal">
                      <%= for {value, label} <- [{"POSTNET", "POSTNET"}, {"PLANET", "PLANET"}, {"ROYALMAIL", "Royal Mail"}] do %>
                        <% compatible = barcode_format_compatible?(@element.text_content, value) %>
                        <option value={value} selected={@element.barcode_format == value} disabled={not compatible}>
                          <%= label %><%= if not compatible, do: " ✗", else: "" %>
                        </option>
                      <% end %>
                    </optgroup>
                  </select>
                  </form>
                </div>
                <%= if info = barcode_format_info(@element.barcode_format) do %>
                  <% color = info.color %>
                  <div class={[
                    "rounded-lg border p-2.5 text-xs space-y-1",
                    color == "blue" && "bg-blue-50 border-blue-200",
                    color == "emerald" && "bg-emerald-50 border-emerald-200",
                    color == "cyan" && "bg-cyan-50 border-cyan-200",
                    color == "amber" && "bg-amber-50 border-amber-200",
                    color == "pink" && "bg-pink-50 border-pink-200"
                  ]}>
                    <div class="flex items-center justify-between">
                      <span class={[
                        "font-semibold",
                        color == "blue" && "text-blue-700",
                        color == "emerald" && "text-emerald-700",
                        color == "cyan" && "text-cyan-700",
                        color == "amber" && "text-amber-700",
                        color == "pink" && "text-pink-700"
                      ]}><%= info.name %></span>
                      <span class={[
                        "text-[10px] px-1.5 py-0.5 rounded-full font-medium",
                        color == "blue" && "bg-blue-100 text-blue-600",
                        color == "emerald" && "bg-emerald-100 text-emerald-600",
                        color == "cyan" && "bg-cyan-100 text-cyan-600",
                        color == "amber" && "bg-amber-100 text-amber-600",
                        color == "pink" && "bg-pink-100 text-pink-600"
                      ]}><%= info.category %></span>
                    </div>
                    <p class="text-gray-600"><%= info.type %></p>
                    <div class="text-gray-500 space-y-0.5">
                      <p><span class="font-medium text-gray-600">Longitud:</span> <%= info.length %></p>
                      <p><span class="font-medium text-gray-600">Caracteres:</span> <%= info.chars %></p>
                      <p><span class="font-medium text-gray-600">Uso:</span> <%= info.usage %></p>
                    </div>
                  </div>
                <% end %>
                <%= unless @element.barcode_format in ~w(DATAMATRIX PDF417 AZTEC MAXICODE) do %>
                  <div class="flex items-center">
                    <form phx-change="update_element">
                      <input type="hidden" name="field" value="barcode_show_text" />
                      <input type="hidden" name="value" value="false" />
                      <input
                        type="checkbox"
                        id="barcode_show_text"
                        name="value"
                        value="true"
                        checked={@element.barcode_show_text}
                        class="rounded border-gray-300"
                      />
                      <label for="barcode_show_text" class="ml-2 text-sm text-gray-700">Mostrar texto</label>
                    </form>
                  </div>
                <% end %>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Color del codigo</label>
                  <input
                    type="color"
                    name="value"
                    value={Map.get(@element, :color) || "#000000"}
                    phx-change="update_element"
                    phx-value-field="color"
                    class="mt-1 block w-full h-9 rounded-md border-gray-300"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Color de fondo</label>
                  <input
                    type="color"
                    name="value"
                    value={Map.get(@element, :background_color) || "#ffffff"}
                    phx-change="update_element"
                    phx-value-field="background_color"
                    class="mt-1 block w-full h-9 rounded-md border-gray-300"
                  />
                </div>

              <% "image" -> %>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Imagen</label>
                  <%= if Map.get(@element, :image_data) do %>
                    <div class="mt-2 relative">
                      <img src={Map.get(@element, :image_data)} class="w-full h-auto rounded border border-gray-200" />
                      <p class="mt-1 text-xs text-gray-500 truncate"><%= Map.get(@element, :image_filename, "imagen") %></p>
                    </div>
                  <% end %>

                  <form
                    id="image-upload-form"
                    phx-submit="upload_element_image"
                    phx-change="validate_upload"
                    phx-hook="AutoUploadSubmit"
                  >
                    <input type="hidden" name="element_id" value={Map.get(@element, :id) || ""} />
                    <div class="mt-2">
                      <.live_file_input upload={@uploads.element_image} class="hidden" />
                      <label
                        for={@uploads.element_image.ref}
                        class="flex items-center justify-center w-full px-4 py-3 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-blue-400 hover:bg-blue-50 transition"
                      >
                        <div class="text-center">
                          <svg class="w-6 h-6 mx-auto text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                          </svg>
                          <p class="mt-1 text-xs text-gray-500">
                            <%= if Map.get(@element, :image_data), do: "Cambiar imagen", else: "Clic para seleccionar" %>
                          </p>
                          <p class="text-xs text-gray-400">PNG, JPG, GIF, SVG (max 2MB)</p>
                        </div>
                      </label>

                      <%= for entry <- @uploads.element_image.entries do %>
                        <div class="mt-2">
                          <div class="flex items-center justify-between text-sm">
                            <span class="text-gray-600 truncate"><%= entry.client_name %></span>
                            <span class="text-green-600 text-xs">
                              <%= if entry.done?, do: "✓ Aplicando...", else: "#{entry.progress}%" %>
                            </span>
                          </div>
                          <div class="mt-1 h-1.5 w-full bg-gray-200 rounded-full overflow-hidden">
                            <div class="h-full bg-blue-500 transition-all" style={"width: #{entry.progress}%"}></div>
                          </div>
                          <%= for err <- upload_errors(@uploads.element_image, entry) do %>
                            <p class="mt-1 text-xs text-red-500"><%= error_to_string(err) %></p>
                          <% end %>
                        </div>
                      <% end %>
                      <button type="submit" class="hidden">Submit</button>
                    </div>
                  </form>
                </div>

              <% "line" -> %>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Color</label>
                  <input
                    type="color"
                    name="value"
                    value={Map.get(@element, :color) || "#000000"}
                    phx-change="update_element"
                    phx-value-field="color"
                    class="mt-1 block w-full h-9 rounded-md border-gray-300"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Grosor (mm)</label>
                  <input
                    type="number"
                    name="value"
                    value={Map.get(@element, :border_width) || 0.5}
                    step="0.1"
                    min="0.1"
                    phx-blur="update_element"
                    phx-value-field="border_width"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                  />
                </div>

              <% "rectangle" -> %>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Color de fondo</label>
                  <div class="flex items-center gap-2 mt-1">
                    <label class="flex items-center gap-1 text-xs text-gray-500 cursor-pointer select-none">
                      <input
                        type="checkbox"
                        checked={Map.get(@element, :background_color) in [nil, "transparent"]}
                        phx-click="update_element"
                        phx-value-field="background_color"
                        phx-value-value={if Map.get(@element, :background_color) in [nil, "transparent"], do: "#ffffff", else: "transparent"}
                        class="rounded border-gray-300 text-blue-600 h-3.5 w-3.5"
                      /> Sin fondo
                    </label>
                    <%= if Map.get(@element, :background_color) not in [nil, "transparent"] do %>
                      <input
                        type="color"
                        name="value"
                        value={Map.get(@element, :background_color)}
                        phx-change="update_element"
                        phx-value-field="background_color"
                        class="block flex-1 h-9 rounded-md border-gray-300"
                      />
                    <% end %>
                  </div>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Color de borde</label>
                  <input
                    type="color"
                    name="value"
                    value={Map.get(@element, :border_color) || "#000000"}
                    phx-change="update_element"
                    phx-value-field="border_color"
                    class="mt-1 block w-full h-9 rounded-md border-gray-300"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Ancho de borde (mm)</label>
                  <input
                    type="number"
                    name="value"
                    value={Map.get(@element, :border_width) || 0.5}
                    step="0.1"
                    min="0"
                    phx-blur="update_element"
                    phx-value-field="border_width"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Radio de borde</label>
                  <div
                    id={"border-radius-slider-rect-#{Map.get(@element, :id) || Map.get(@element, "id")}"}
                    phx-hook="BorderRadiusSlider"
                    phx-update="ignore"
                    data-element-id={Map.get(@element, :id) || Map.get(@element, "id")}
                    data-value={Map.get(@element, :border_radius) || 0}
                    class="flex items-center space-x-2 mt-1"
                  >
                    <input
                      type="range"
                      min="0"
                      max="100"
                      class="flex-1 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                    />
                    <span class="text-sm text-gray-600 w-10 text-right"></span>
                  </div>
                  <p class="text-xs text-gray-400 mt-1">0% = esquinas rectas, 100% = maximo redondeo</p>
                </div>

              <% "circle" -> %>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Redondez</label>
                  <div
                    id={"border-radius-slider-#{Map.get(@element, :id) || Map.get(@element, "id")}"}
                    phx-hook="BorderRadiusSlider"
                    phx-update="ignore"
                    data-element-id={Map.get(@element, :id) || Map.get(@element, "id")}
                    data-value={Map.get(@element, :border_radius) || 100}
                    class="flex items-center space-x-2 mt-1"
                  >
                    <input
                      type="range"
                      min="0"
                      max="100"
                      class="flex-1 h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                    />
                    <span class="text-sm text-gray-600 w-10 text-right"></span>
                  </div>
                  <p class="text-xs text-gray-400 mt-1">0% = rectangulo, 100% = elipse</p>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Color de fondo</label>
                  <div class="flex items-center gap-2 mt-1">
                    <label class="flex items-center gap-1 text-xs text-gray-500 cursor-pointer select-none">
                      <input
                        type="checkbox"
                        checked={Map.get(@element, :background_color) in [nil, "transparent"]}
                        phx-click="update_element"
                        phx-value-field="background_color"
                        phx-value-value={if Map.get(@element, :background_color) in [nil, "transparent"], do: "#ffffff", else: "transparent"}
                        class="rounded border-gray-300 text-blue-600 h-3.5 w-3.5"
                      /> Sin fondo
                    </label>
                    <%= if Map.get(@element, :background_color) not in [nil, "transparent"] do %>
                      <input
                        type="color"
                        name="value"
                        value={Map.get(@element, :background_color)}
                        phx-change="update_element"
                        phx-value-field="background_color"
                        class="block flex-1 h-9 rounded-md border-gray-300"
                      />
                    <% end %>
                  </div>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Color de borde</label>
                  <input
                    type="color"
                    name="value"
                    value={Map.get(@element, :border_color) || "#000000"}
                    phx-change="update_element"
                    phx-value-field="border_color"
                    class="mt-1 block w-full h-9 rounded-md border-gray-300"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Ancho de borde (mm)</label>
                  <input
                    type="number"
                    name="value"
                    value={Map.get(@element, :border_width) || 0.5}
                    step="0.1"
                    min="0"
                    phx-blur="update_element"
                    phx-value-field="border_width"
                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                  />
                </div>

              <% _ -> %>
                <p class="text-sm text-gray-500">Este elemento no tiene propiedades adicionales.</p>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "Archivo muy grande (máx. 2MB)"
  defp error_to_string(:too_many_files), do: "Solo se permite un archivo"
  defp error_to_string(:not_accepted), do: "Tipo de archivo no permitido"
  defp error_to_string(_), do: "Error desconocido"

  defp label_properties(assigns) do
    ~H"""
    <form phx-change="update_design_properties" class="space-y-4">
      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="block text-sm font-medium text-gray-700">Ancho (mm)</label>
          <input
            type="number"
            name="design[width_mm]"
            step="0.1"
            value={@design.width_mm}
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Alto (mm)</label>
          <input
            type="number"
            name="design[height_mm]"
            step="0.1"
            value={@design.height_mm}
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
          />
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700">Color de fondo</label>
        <input
          type="color"
          name="design[background_color]"
          value={@design.background_color}
          class="mt-1 block w-full h-9 rounded-md border-gray-300"
        />
      </div>

      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="block text-sm font-medium text-gray-700">Borde (mm)</label>
          <input
            type="number"
            name="design[border_width]"
            step="0.1"
            value={@design.border_width}
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Color borde</label>
          <input
            type="color"
            name="design[border_color]"
            value={@design.border_color}
            class="mt-1 block w-full h-9 rounded-md border-gray-300"
          />
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700">Radio del borde (mm)</label>
        <input
          type="number"
          name="design[border_radius]"
          step="0.1"
          value={@design.border_radius}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
        />
      </div>
    </form>
    """
  end

  # Helper to check if element is in binding mode (vs fixed text mode)
  # nil = fixed text mode, "" or any string = binding mode
  defp has_binding?(element) do
    binding = Map.get(element, :binding)
    # Also check string key
    binding = if is_nil(binding), do: Map.get(element, "binding"), else: binding
    # nil means fixed text mode, anything else (including "") means binding mode
    binding != nil
  end

  defp has_expression?(element) do
    binding = Map.get(element, :binding) || Map.get(element, "binding") || ""
    is_binary(binding) && String.contains?(binding, "{{")
  end

  defp content_mode(_element, show_binding_mode, show_expression_mode) do
    cond do
      show_expression_mode -> :expression
      show_binding_mode -> :column
      true -> :text
    end
  end

  # Placeholder text for fixed content input
  defp get_fixed_text_placeholder("qr"), do: "Completar"
  defp get_fixed_text_placeholder("barcode"), do: "Completar"
  defp get_fixed_text_placeholder("text"), do: "Completar"
  defp get_fixed_text_placeholder(_), do: "Completar"

  # --- Expression visual builder helpers ---

  defp expression_patterns, do: @expression_patterns

  defp get_pattern(id) do
    Enum.find(@expression_patterns, fn p -> p.id == id end)
  end

  defp default_builder_config(pattern_id, column) do
    base = if column, do: %{"column" => column}, else: %{}

    case pattern_id do
      :uppercase -> base
      :lowercase -> base
      :today -> Map.put(base, "format", "DD/MM/AAAA")
      :counter -> Map.merge(base, %{"start" => "1", "digits" => "4"})
      :batch -> Map.put(base, "format", "AAMM-####")
      :expiry -> Map.merge(base, %{"days" => "30", "format" => "DD/MM/AAAA"})
      :conditional -> Map.merge(base, %{"alt_text" => "N/A"})
      :format_number -> Map.put(base, "decimals", "2")
      _ -> base
    end
  end

  defp build_expression_from_pattern(pattern_id, config) do
    col = Map.get(config, "column", "valor")

    case pattern_id do
      :uppercase -> "{{MAYUS(#{col})}}"
      :lowercase -> "{{MINUS(#{col})}}"
      :today ->
        fmt = Map.get(config, "format", "DD/MM/AAAA")
        "{{FORMATO_FECHA(HOY(), #{fmt})}}"
      :counter ->
        start = Map.get(config, "start", "1")
        digits = Map.get(config, "digits", "4")
        "{{CONTADOR(#{start}, 1, #{digits})}}"
      :batch ->
        fmt = Map.get(config, "format", "AAMM-####")
        "{{LOTE(#{fmt})}}"
      :expiry ->
        days = Map.get(config, "days", "30")
        fmt = Map.get(config, "format", "DD/MM/AAAA")
        "{{FORMATO_FECHA(SUMAR_DIAS(HOY(), #{days}), #{fmt})}}"
      :conditional ->
        alt = Map.get(config, "alt_text", "N/A")
        "{{SI(VACIO(#{col}), #{alt}, #{col})}}"
      :format_number ->
        decimals = Map.get(config, "decimals", "2")
        "{{FORMATO_NUM(#{col}, #{decimals})}}"
      _ -> ""
    end
  end

  defp preview_expression(pattern_id, config, preview_data) do
    expr = build_expression_from_pattern(pattern_id, config)
    if expr == "" do
      ""
    else
      context = %{row_index: 0, batch_size: 100, now: DateTime.utc_now()}
      result = ExpressionEvaluator.evaluate(expr, preview_data, context)
      {expr, result}
    end
  end

  defp pattern_color_classes(color) do
    case color do
      "blue" -> {"bg-blue-50 border-blue-200 hover:bg-blue-100", "text-blue-700", "bg-blue-100 text-blue-600"}
      "emerald" -> {"bg-emerald-50 border-emerald-200 hover:bg-emerald-100", "text-emerald-700", "bg-emerald-100 text-emerald-600"}
      "amber" -> {"bg-amber-50 border-amber-200 hover:bg-amber-100", "text-amber-700", "bg-amber-100 text-amber-600"}
      "violet" -> {"bg-violet-50 border-violet-200 hover:bg-violet-100", "text-violet-700", "bg-violet-100 text-violet-600"}
      _ -> {"bg-gray-50 border-gray-200 hover:bg-gray-100", "text-gray-700", "bg-gray-100 text-gray-600"}
    end
  end
end
