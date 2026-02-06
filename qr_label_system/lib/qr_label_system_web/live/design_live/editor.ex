defmodule QrLabelSystemWeb.DesignLive.Editor do
  use QrLabelSystemWeb, :live_view

  require Logger

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Designs.Design
  alias QrLabelSystem.Security.FileSanitizer

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    case Designs.get_design(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Este diseño ha sido eliminado o no existe")
         |> push_navigate(to: ~p"/designs")}

      design when design.user_id != socket.assigns.current_user.id ->
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

      # Load available columns from persistent store (from data-first flow)
      user_id = socket.assigns.current_user.id
      {upload_data, available_columns} = QrLabelSystem.UploadDataStore.get(user_id, design.id)

      # Ensure we have lists (not nil)
      upload_data = upload_data || []
      available_columns = available_columns || []

      # Build preview data from first row if we have data
      preview_data = case upload_data do
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
       |> assign(:upload_data, upload_data)
       |> assign(:show_properties, true)
       |> assign(:show_preview, false)
       |> assign(:show_layers, true)
       |> assign(:preview_data, preview_data)
       |> assign(:preview_row_index, 0)
       |> assign(:history, [design.elements || []])
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
       |> assign(:pending_deletes, MapSet.new())  # Track pending delete operations
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
      {:noreply,
       socket
       |> assign(:canvas_loaded, true)
       |> push_event("load_design", %{design: Design.to_json(socket.assigns.design)})}
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

      # Normal selection - update element but preserve show_binding_mode if element has binding
      true ->
        # Only reset show_binding_mode if the element doesn't have a binding
        # This preserves binding mode when re-selecting an element in binding mode
        new_show_binding_mode = if has_binding?(element) do
          socket.assigns.show_binding_mode
        else
          false
        end

        {:noreply,
         socket
         |> assign(:selected_element, element)
         |> assign(:show_binding_mode, new_show_binding_mode)}
    end
  end

  @impl true
  def handle_event("element_deselected", _params, socket) do
    # Don't deselect if we're in the middle of an element recreation
    if Map.get(socket.assigns, :pending_selection_id) do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :selected_element, nil)}
    end
  end

  @impl true
  def handle_event("element_modified", %{"elements" => elements_json}, socket) do
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
        do_save_elements(socket, design, elements_json)
    end
  end

  defp do_save_elements(socket, design, elements_json) do
    # Debug: Log what we're about to save
    current_count = length(design.elements || [])
    new_count = length(elements_json || [])
    new_ids = Enum.map(elements_json || [], fn el -> Map.get(el, "id") end)
    Logger.info("do_save_elements - Design #{design.id}: #{current_count} -> #{new_count} elements. New IDs: #{inspect(new_ids)}")

    case Designs.update_design(design, %{elements: elements_json}) do
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

        socket = if show_flash do
          socket
          |> assign(:has_unsaved_changes, false)
          |> put_flash(:info, "Diseño guardado")
        else
          socket
        end

        {:noreply, socket}

      {:error, changeset} ->
        Logger.error("Failed to save design #{design.id}: #{inspect(changeset.errors)}")
        {:noreply,
         socket
         |> assign(:pending_save_flash, false)
         |> put_flash(:error, "Error al guardar cambios")}
    end
  end

  # Whitelist of allowed fields for element updates (security)
  @allowed_element_fields ~w(x y width height rotation binding qr_error_level
    barcode_format barcode_show_text font_size font_family font_weight
    text_align text_content color background_color border_width border_color border_radius
    z_index visible locked name image_data image_filename)

  @impl true
  def handle_event("update_element", %{"field" => field, "value" => value}, socket)
      when field in @allowed_element_fields do
    if socket.assigns.selected_element do
      # Update selected_element locally to keep UI in sync
      # Handle both atom and string keys
      key = String.to_atom(field)

      # Get element type
      element_type = Map.get(socket.assigns.selected_element, :type) ||
                     Map.get(socket.assigns.selected_element, "type")

      # For QR codes, width and height must be equal (square)
      updated_element = if element_type == "qr" and field in ["width", "height"] do
        socket.assigns.selected_element
        |> Map.put(:width, value)
        |> Map.put("width", value)
        |> Map.put(:height, value)
        |> Map.put("height", value)
      else
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
                          "qr_error_level", "barcode_show_text", "barcode_format"]

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

          # For QR/barcode in fixed mode, send binding: nil first to ensure
          # the canvas doesn't overwrite it with text_content value
          socket = if field == "text_content" and is_fixed_mode and is_code_element do
            socket
            |> push_event("update_element_property", %{id: element_id, field: "binding", value: nil})
            |> push_event("update_element_property", %{id: element_id, field: field, value: value})
          else
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
    if socket.assigns.selected_element do
      element_id = Map.get(socket.assigns.selected_element, :id) ||
                   Map.get(socket.assigns.selected_element, "id")
      element_type = Map.get(socket.assigns.selected_element, :type) ||
                     Map.get(socket.assigns.selected_element, "type")

      # Get current values
      current_binding = Map.get(socket.assigns.selected_element, :binding) ||
                        Map.get(socket.assigns.selected_element, "binding") || ""
      _current_text = Map.get(socket.assigns.selected_element, :text_content) ||
                      Map.get(socket.assigns.selected_element, "text_content") || ""

      case mode do
        "binding" ->
          # Switch to binding mode: set binding to empty string (not nil)
          # This signals "binding mode active but no column selected yet"
          binding_value = if current_binding != "" && current_binding != nil do
            current_binding
          else
            ""  # Empty string = binding mode, nil = fixed mode
          end

          updated_element = socket.assigns.selected_element
            |> Map.put(:binding, binding_value)
            |> Map.put("binding", binding_value)

          # For text elements, sync binding to canvas immediately
          # QR/barcode will sync when user selects a column (to avoid recreation issues)
          # IMPORTANT: Set show_binding_mode=true to keep UI in binding mode
          # even if element_selected fires with stale data before element_modified completes
          socket = socket
            |> assign(:selected_element, updated_element)
            |> assign(:pending_selection_id, element_id)
            |> assign(:show_binding_mode, true)

          socket = if element_type == "text" do
            push_event(socket, "update_element_property", %{id: element_id, field: "binding", value: binding_value})
          else
            socket
          end

          {:noreply, socket}

        "fixed" ->
          # Switch to fixed mode: clear binding and preserve text_content
          updated_element = socket.assigns.selected_element
            |> Map.put(:binding, nil)
            |> Map.put("binding", nil)

          # For text elements, sync binding to canvas immediately
          # QR/barcode will sync when user types content (to avoid recreation issues)
          socket = socket
            |> assign(:selected_element, updated_element)
            |> assign(:pending_selection_id, element_id)
            |> assign(:show_binding_mode, false)

          socket = if element_type == "text" do
            push_event(socket, "update_element_property", %{id: element_id, field: "binding", value: nil})
          else
            socket
          end

          {:noreply, socket}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
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
    {:noreply, assign(socket, :show_preview, !socket.assigns.show_preview)}
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
        [{:ok, %{data: image_data, filename: filename}}] ->
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
    {:noreply,
     socket
     |> assign(:selected_elements, elements)
     |> assign(:selected_element, List.first(elements))}
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
    {:noreply, assign(socket, :show_layers, !socket.assigns.show_layers)}
  end

  @impl true
  def handle_event("reorder_layers", %{"ordered_ids" => ordered_ids}, socket) when is_list(ordered_ids) do
    # Update z_index based on new order
    {:noreply, push_event(socket, "reorder_layers", %{ordered_ids: ordered_ids})}
  end

  def handle_event("reorder_layers", _params, socket), do: {:noreply, socket}

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
    upload_data = socket.assigns.upload_data
    current_index = socket.assigns.preview_row_index

    if current_index > 0 do
      new_index = current_index - 1
      new_preview_data = Enum.at(upload_data, new_index)
      {:noreply,
       socket
       |> assign(:preview_row_index, new_index)
       |> assign(:preview_data, new_preview_data)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("preview_next_row", _params, socket) do
    upload_data = socket.assigns.upload_data
    current_index = socket.assigns.preview_row_index
    max_index = length(upload_data) - 1

    if current_index < max_index do
      new_index = current_index + 1
      new_preview_data = Enum.at(upload_data, new_index)
      {:noreply,
       socket
       |> assign(:preview_row_index, new_index)
       |> assign(:preview_data, new_preview_data)}
    else
      {:noreply, socket}
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

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
          text_content: "QR-#{number}",
          binding: nil,
          name: "Código QR #{number}"
        })

      "barcode" ->
        Map.merge(base, %{
          width: 40.0,
          height: 15.0,
          barcode_format: "CODE128",
          barcode_show_text: true,
          text_content: "CODE#{number}",
          binding: nil,
          name: "Código de Barras #{number}"
        })

      "text" ->
        Map.merge(base, %{
          width: 30.0,
          height: 8.0,
          font_size: 12,
          font_family: "Arial",
          font_weight: "normal",
          text_align: "left",
          text_content: "Escriba aqui...",
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
          background_color: "#ffffff",
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
      "CODE128" -> true  # Accepts any text
      "CODE39" -> Regex.match?(~r/^[A-Z0-9\-. \$\/\+%]*$/i, content)
      "EAN13" -> digits_only and len in 12..13
      "EAN8" -> digits_only and len in 7..8
      "UPC" -> digits_only and len in 11..12
      "ITF14" -> digits_only and len in 13..14
      "pharmacode" ->
        if digits_only do
          case Integer.parse(content) do
            {num, ""} -> num >= 3 and num <= 131070
            _ -> false
          end
        else
          false
        end
      _ -> true
    end
  end

  # History management for undo/redo
  @max_history_size 10

  defp push_to_history(socket, design) do
    history = socket.assigns.history
    index = socket.assigns.history_index

    # Truncate future history if we're not at the end
    history = Enum.take(history, index + 1)

    # Add current state to history
    new_history = history ++ [design.elements]

    # Limit history size
    new_history = if length(new_history) > @max_history_size do
      Enum.drop(new_history, 1)
    else
      new_history
    end

    socket
    |> assign(:history, new_history)
    |> assign(:history_index, length(new_history) - 1)
  end

  defp undo(socket) do
    index = socket.assigns.history_index

    if index > 0 do
      new_index = index - 1
      previous_elements = Enum.at(socket.assigns.history, new_index)

      # Update design in memory without saving to DB (save happens on explicit save)
      design = socket.assigns.design
      updated_design = %{design | elements: previous_elements}

      {:ok,
       socket
       |> assign(:design, updated_design)
       |> assign(:history_index, new_index)
       |> assign(:has_unsaved_changes, true)
       |> push_event("reload_design", %{design: Design.to_json(updated_design)})}
    else
      :no_history
    end
  end

  defp redo(socket) do
    history = socket.assigns.history
    index = socket.assigns.history_index

    if index < length(history) - 1 do
      new_index = index + 1
      next_elements = Enum.at(history, new_index)

      # Update design in memory without saving to DB
      design = socket.assigns.design
      updated_design = %{design | elements: next_elements}

      {:ok,
       socket
       |> assign(:design, updated_design)
       |> assign(:history_index, new_index)
       |> assign(:has_unsaved_changes, true)
       |> push_event("reload_design", %{design: Design.to_json(updated_design)})}
    else
      :no_future
    end
  end

  defp can_undo?(assigns), do: assigns.history_index > 0
  defp can_redo?(assigns), do: assigns.history_index < length(assigns.history) - 1

  defp build_auto_mapping(elements, preview_data) do
    columns = Map.keys(preview_data)

    elements
    |> Enum.filter(&(&1.binding))
    |> Enum.reduce(%{}, fn element, acc ->
      # Try to find matching column
      binding = element.binding
      matching_column = Enum.find(columns, fn col ->
        String.downcase(col) == String.downcase(binding)
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
          <.link
            :if={@design.label_type == "multiple"}
            navigate={~p"/generate/data/#{@design.id}"}
            class={"px-3 py-2 rounded-lg flex items-center space-x-2 font-medium transition #{if length(@upload_data) > 0, do: "bg-amber-50 text-amber-700 hover:bg-amber-100 border border-amber-200", else: "bg-indigo-50 text-indigo-700 hover:bg-indigo-100 border border-indigo-200"}"}
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
            </svg>
            <span><%= if length(@upload_data) > 0, do: "Cambiar datos", else: "Vincular datos" %></span>
          </.link>
          <button
            phx-click="toggle_preview"
            class={"px-3 py-2 rounded-lg flex items-center space-x-2 font-medium transition #{if @show_preview, do: "bg-indigo-600 text-white", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
            </svg>
            <span>Vista previa</span>
          </button>

          <button
            phx-click="save_design"
            class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 flex items-center space-x-2 font-medium"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
            </svg>
            <span>Guardar</span>
          </button>
        </div>
      </div>

      <!-- Main Content -->
      <div class="flex-1 flex overflow-hidden">
        <!-- Left Sidebar - Element Tools (fixed width, won't shrink) -->
        <div class="w-20 flex-shrink-0 bg-white border-r border-gray-200 flex flex-col py-4" id="element-toolbar" phx-hook="DraggableElements">
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
        </div>

        <!-- Layers Panel (fixed width, won't shrink) -->
        <div :if={@show_layers} class="w-56 flex-shrink-0 bg-white border-l border-gray-200 flex flex-col">
          <div class="p-3 border-b border-gray-200 flex items-center justify-between">
            <h3 class="text-sm font-semibold text-gray-900">Capas</h3>
            <button phx-click="toggle_layers" class="text-gray-400 hover:text-gray-600">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Layer order controls -->
          <div :if={@selected_element} class="px-3 py-2 border-b border-gray-100 flex items-center justify-center space-x-1">
            <button phx-click="bring_to_front" class="p-1.5 rounded hover:bg-gray-100 text-gray-600" title="Traer al frente">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 11l7-7 7 7M5 19l7-7 7 7" /></svg>
            </button>
            <button phx-click="move_layer_up" class="p-1.5 rounded hover:bg-gray-100 text-gray-600" title="Subir una capa">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" /></svg>
            </button>
            <button phx-click="move_layer_down" class="p-1.5 rounded hover:bg-gray-100 text-gray-600" title="Bajar una capa">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" /></svg>
            </button>
            <button phx-click="send_to_back" class="p-1.5 rounded hover:bg-gray-100 text-gray-600" title="Enviar atrás">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 13l-7 7-7-7m14-8l-7 7-7-7" /></svg>
            </button>
          </div>

          <!-- Layer list -->
          <div class="flex-1 overflow-y-auto" id="layers-list" phx-hook="SortableLayers">
            <%= for element <- Enum.sort_by(@design.elements || [], fn el -> Map.get(el, :z_index, 0) end, :desc) do %>
              <div
                class={"flex items-center px-3 py-2 border-b border-gray-50 cursor-pointer transition #{if @selected_element && @selected_element.id == element.id, do: "bg-blue-50", else: "hover:bg-gray-50"}"}
                phx-click="select_layer"
                phx-value-id={element.id}
                data-id={element.id}
              >
                <!-- Visibility toggle -->
                <button
                  phx-click="toggle_element_visibility"
                  phx-value-id={element.id}
                  class={"p-1 rounded transition #{if Map.get(element, :visible, true), do: "text-gray-600 hover:text-gray-800", else: "text-gray-300 hover:text-gray-500"}"}
                  title={if Map.get(element, :visible, true), do: "Ocultar", else: "Mostrar"}
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <%= if Map.get(element, :visible, true) do %>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                    <% else %>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                    <% end %>
                  </svg>
                </button>

                <!-- Lock toggle -->
                <button
                  phx-click="toggle_element_lock"
                  phx-value-id={element.id}
                  class={"p-1 rounded transition #{if Map.get(element, :locked, false), do: "text-yellow-600 hover:text-yellow-700", else: "text-gray-400 hover:text-gray-600"}"}
                  title={if Map.get(element, :locked, false), do: "Desbloquear", else: "Bloquear"}
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <%= if Map.get(element, :locked, false) do %>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                    <% else %>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 11V7a4 4 0 118 0m-4 8v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2z" />
                    <% end %>
                  </svg>
                </button>

                <!-- Layer name and type icon -->
                <div class="flex-1 ml-2 flex items-center min-w-0">
                  <span class={"text-xs mr-2 #{if Map.get(element, :visible, true), do: "text-gray-500", else: "text-gray-300"}"}>
                    <%= case element.type do %>
                      <% "qr" -> %>QR
                      <% "barcode" -> %>BC
                      <% "text" -> %>T
                      <% "line" -> %>—
                      <% "rectangle" -> %>□
                      <% "circle" -> %>○
                      <% "image" -> %>IMG
                      <% _ -> %>?
                    <% end %>
                  </span>
                  <span class={"text-sm truncate #{if Map.get(element, :visible, true), do: "text-gray-700", else: "text-gray-400"}"}>
                    <%= Map.get(element, :name) || element.type %>
                  </span>
                </div>

                <!-- Drag handle -->
                <div class="text-gray-300 cursor-move drag-handle">
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16" />
                  </svg>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Empty state -->
          <div :if={@element_count == 0} class="flex-1 flex items-center justify-center p-4">
            <p class="text-sm text-gray-400 text-center">No hay elementos</p>
          </div>
        </div>

        <!-- Layers toggle button (when panel is hidden) -->
        <button
          :if={!@show_layers}
          phx-click="toggle_layers"
          class="absolute right-72 top-20 bg-white border border-gray-200 rounded-l-lg p-2 shadow-md text-gray-600 hover:text-gray-800"
          title="Mostrar capas"
        >
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
          </svg>
        </button>

        <!-- Right Sidebar - Properties (fixed width, won't shrink) -->
        <div class="w-72 flex-shrink-0 bg-white border-l border-gray-200 overflow-y-auto">
          <div class="p-4">
            <!-- Available Columns Panel (only for multiple labels) -->
            <div :if={@design.label_type == "multiple" && length(@available_columns) > 0} class="bg-indigo-50 rounded-lg p-3 mb-4">
              <h4 class="text-xs font-semibold text-indigo-700 uppercase tracking-wide mb-2">
                Columnas Disponibles
              </h4>
              <div class="flex flex-wrap gap-1.5">
                <%= for col <- @available_columns do %>
                  <span class="inline-block px-2 py-0.5 bg-indigo-100 text-indigo-700 text-xs font-mono rounded">
                    <%= col %>
                  </span>
                <% end %>
              </div>
              <p class="mt-2 text-xs text-indigo-600">
                Selecciona un elemento para vincularlo a una columna
              </p>
            </div>

            <%= if @selected_element do %>
              <div class="flex items-center justify-between mb-4">
                <h3 class="font-semibold text-gray-900">Propiedades</h3>
                <span class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded">
                  <%= String.capitalize(@selected_element.type) %>
                </span>
              </div>
              <.element_properties element={@selected_element} uploads={@uploads} available_columns={@available_columns} label_type={@design.label_type} design_id={@design.id} show_binding_mode={@show_binding_mode} />

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
              <%= if @design.label_type == "multiple" && length(@upload_data) > 0 do %>
                <div class="mt-6 pt-4 border-t">
                  <div class="bg-indigo-50 rounded-lg p-3">
                    <div class="flex items-center space-x-2 text-indigo-700 mb-2">
                      <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
                      </svg>
                      <span class="font-medium"><%= length(@upload_data) %> registros</span>
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

          <!-- Row Navigation (when multiple rows available) -->
          <%= if length(@upload_data) > 1 do %>
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
                  <span class="text-sm text-indigo-600"> de <%= length(@upload_data) %></span>
                  <p class="text-xs text-indigo-500">etiquetas</p>
                </div>
                <button
                  phx-click="preview_next_row"
                  disabled={@preview_row_index >= length(@upload_data) - 1}
                  class={"p-2 rounded-lg transition #{if @preview_row_index >= length(@upload_data) - 1, do: "text-gray-300 cursor-not-allowed", else: "text-indigo-600 hover:bg-indigo-100"}"}
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
              <%= if length(@upload_data) > 0 do %>
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
              data-design={Jason.encode!(Design.to_json(@design))}
              data-row={Jason.encode!(@preview_data)}
              data-mapping={Jason.encode!(build_auto_mapping(@design.elements || [], @preview_data))}
              class="inline-block"
            >
            </div>
          </div>

          <!-- Summary when data is loaded -->
          <%= if length(@upload_data) > 0 do %>
            <div class="mt-4 p-3 bg-green-50 rounded-lg border border-green-200">
              <div class="flex items-center space-x-2 text-green-700">
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span class="font-medium"><%= length(@upload_data) %> registros cargados</span>
              </div>
              <p class="mt-1 text-xs text-green-600">
                Usa las flechas para navegar entre etiquetas
              </p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp element_properties(assigns) do
    ~H"""
    <div class="space-y-4" id="property-fields" phx-hook="PropertyFields">
      <!-- Layer name -->
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

      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="block text-sm font-medium text-gray-700">X (mm)</label>
          <input
            type="number"
            name="value"
            step="0.1"
            value={@element.x}
            phx-blur="update_element"
            phx-value-field="x"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Y (mm)</label>
          <input
            type="number"
            name="value"
            step="0.1"
            value={@element.y}
            phx-blur="update_element"
            phx-value-field="y"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
          />
        </div>
      </div>

      <%= if @element.type != "text" do %>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-sm font-medium text-gray-700">Ancho (mm)</label>
            <input
              type="number"
              name="value"
              step="0.1"
              value={@element.width}
              phx-blur="update_element"
              phx-value-field="width"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Alto (mm)</label>
            <input
              type="number"
              name="value"
              step="0.1"
              value={@element.height}
              phx-blur="update_element"
              phx-value-field="height"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
            />
          </div>
        </div>
      <% end %>

      <div>
        <label class="block text-sm font-medium text-gray-700">Rotación (°)</label>
        <input
          type="number"
          name="value"
          step="1"
          value={@element.rotation || 0}
          phx-blur="update_element"
          phx-value-field="rotation"
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
        />
      </div>

      <%= if @label_type == "multiple" && @element.type in ["qr", "barcode", "text"] do %>
        <!-- Contenido del elemento: vincular a columna o texto fijo -->
        <div class="border-t pt-4 space-y-3">
          <label class="block text-sm font-medium text-gray-700">Contenido del elemento</label>

          <!-- Selector de modo -->
          <div class="flex rounded-lg border border-gray-300 overflow-hidden">
            <button
              type="button"
              phx-click="set_content_mode"
              phx-value-mode="binding"
              class={"flex-1 px-3 py-2 text-sm font-medium transition-colors #{if has_binding?(@element) or @show_binding_mode, do: "bg-indigo-600 text-white", else: "bg-white text-gray-700 hover:bg-gray-50"}"}
            >
              Vincular a columna
            </button>
            <button
              type="button"
              phx-click="set_content_mode"
              phx-value-mode="fixed"
              class={"flex-1 px-3 py-2 text-sm font-medium transition-colors #{if !has_binding?(@element) and !@show_binding_mode, do: "bg-indigo-600 text-white", else: "bg-white text-gray-700 hover:bg-gray-50"}"}
            >
              Texto fijo
            </button>
          </div>

          <%= if has_binding?(@element) or @show_binding_mode do %>
            <!-- Modo: Vincular a columna -->
            <%= if length(@available_columns) > 0 do %>
              <form phx-change="update_element">
                <input type="hidden" name="field" value="binding" />
                <select
                  name="value"
                  class="block w-full rounded-md border-gray-300 shadow-sm text-sm"
                >
                  <option value="">Seleccionar columna...</option>
                  <%= for col <- @available_columns do %>
                    <option value={col} selected={(Map.get(@element, :binding) || "") == col}><%= col %></option>
                  <% end %>
                </select>
              </form>
              <p class="text-xs text-gray-500">
                El contenido cambiará según cada fila de datos
              </p>
            <% else %>
              <!-- No hay datos cargados - mostrar opción para cargar -->
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
          <% else %>
            <!-- Modo: Texto fijo -->
            <input
              type="text"
              name="value"
              value={Map.get(@element, :text_content) || ""}
              placeholder={get_fixed_text_placeholder(@element.type)}
              phx-blur="update_element"
              phx-value-field="text_content"
              class="block w-full rounded-md border-gray-300 shadow-sm text-sm"
            />
            <p class="text-xs text-gray-500">
              Este contenido será igual en todas las etiquetas
            </p>
          <% end %>
        </div>
      <% end %>

      <%= case @element.type do %>
        <% "qr" -> %>
          <div class="border-t pt-4 space-y-3">
            <%= if @label_type == "single" do %>
              <div>
                <label class="block text-sm font-medium text-gray-700">Contenido código QR</label>
                <input
                  type="text"
                  name="value"
                  value={@element.text_content || ""}
                  phx-blur="update_element"
                  phx-value-field="text_content"
                  placeholder="Texto a codificar"
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                />
              </div>
            <% end %>
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
            <div>
              <label class="block text-sm font-medium text-gray-700">Color del código</label>
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
          </div>

        <% "barcode" -> %>
          <div class="border-t pt-4 space-y-3">
            <%= if @label_type == "single" do %>
              <div>
                <label class="block text-sm font-medium text-gray-700">Contenido código Barras</label>
                <input
                  type="text"
                  name="value"
                  value={@element.text_content || ""}
                  phx-blur="update_element"
                  phx-value-field="text_content"
                  placeholder="Texto a codificar"
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                />
                <%= case @element.barcode_format do %>
                  <% "EAN13" -> %>
                    <p class="text-xs text-gray-400 mt-1">Ej: 5901234123457 (13 dígitos)</p>
                  <% "EAN8" -> %>
                    <p class="text-xs text-gray-400 mt-1">Ej: 12345678 (8 dígitos)</p>
                  <% "UPC" -> %>
                    <p class="text-xs text-gray-400 mt-1">Ej: 012345678905 (12 dígitos)</p>
                  <% "ITF14" -> %>
                    <p class="text-xs text-gray-400 mt-1">Ej: 10012345678902 (14 dígitos)</p>
                  <% "pharmacode" -> %>
                    <p class="text-xs text-gray-400 mt-1">Ej: 1234 (número entre 3-131070)</p>
                  <% _ -> %>
                <% end %>
              </div>
            <% end %>
            <div>
              <label class="block text-sm font-medium text-gray-700">Formato</label>
              <select
                name="value"
                phx-change="update_element"
                phx-value-field="barcode_format"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
              >
                <%= for {value, label} <- [{"CODE128", "CODE128"}, {"CODE39", "CODE39"}, {"EAN13", "EAN-13"}, {"EAN8", "EAN-8"}, {"UPC", "UPC"}, {"ITF14", "ITF-14"}] do %>
                  <% compatible = barcode_format_compatible?(@element.text_content, value) %>
                  <option
                    value={value}
                    selected={@element.barcode_format == value}
                    disabled={not compatible}
                    class={if not compatible, do: "text-gray-400", else: ""}
                  >
                    <%= label %><%= if not compatible, do: " (incompatible)", else: "" %>
                  </option>
                <% end %>
              </select>
            </div>
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
            <div>
              <label class="block text-sm font-medium text-gray-700">Color del código</label>
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
          </div>

        <% "text" -> %>
          <div class="border-t pt-4 space-y-3">
            <%= if @label_type == "single" do %>
              <div>
                <label for="text_content_input" class="block text-sm font-medium text-gray-700">Contenido</label>
                <input
                  type="text"
                  id="text_content_input"
                  name="value"
                  value={@element.text_content || ""}
                  phx-blur="update_element"
                  phx-value-field="text_content"
                  onfocus="if(this.value === 'Texto') this.value = ''"
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                />
              </div>
            <% end %>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-sm font-medium text-gray-700">Tamaño fuente</label>
                <input
                  type="number"
                  name="value"
                  value={@element.font_size || 12}
                  phx-blur="update_element"
                  phx-value-field="font_size"
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700">Color</label>
                <input
                  type="color"
                  name="value"
                  value={@element.color || "#000000"}
                  phx-change="update_element"
                  phx-value-field="color"
                  class="mt-1 block w-full h-9 rounded-md border-gray-300"
                />
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Fuente</label>
              <form phx-change="update_element" class="mt-1">
                <input type="hidden" name="field" value="font_family" />
                <select
                  name="value"
                  class="block w-full rounded-md border-gray-300 shadow-sm text-sm"
                >
                  <!-- Fuentes compatibles con impresoras Zebra y sistemas comunes -->
                  <option value="Arial" selected={@element.font_family == "Arial"}>Arial</option>
                  <option value="Helvetica" selected={@element.font_family == "Helvetica"}>Helvetica</option>
                  <option value="Verdana" selected={@element.font_family == "Verdana"}>Verdana</option>
                  <option value="Courier New" selected={@element.font_family == "Courier New"}>Courier New (monospace)</option>
                  <option value="Times New Roman" selected={@element.font_family == "Times New Roman"}>Times New Roman</option>
                  <option value="Georgia" selected={@element.font_family == "Georgia"}>Georgia</option>
                  <!-- Fuentes genéricas como fallback -->
                  <option value="sans-serif" selected={@element.font_family == "sans-serif"}>Sans-serif (genérica)</option>
                  <option value="serif" selected={@element.font_family == "serif"}>Serif (genérica)</option>
                  <option value="monospace" selected={@element.font_family == "monospace"}>Monospace (genérica)</option>
                </select>
              </form>
              <p class="mt-1 text-xs text-gray-400">Compatible con impresoras Zebra</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Alineación</label>
              <form phx-change="update_element" class="mt-1">
                <input type="hidden" name="field" value="text_align" />
                <select
                  name="value"
                  class="block w-full rounded-md border-gray-300 shadow-sm text-sm"
                >
                  <option value="left" selected={@element.text_align == "left"}>Izquierda</option>
                  <option value="center" selected={@element.text_align == "center"}>Centro</option>
                  <option value="right" selected={@element.text_align == "right"}>Derecha</option>
                </select>
              </form>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Estilo</label>
              <form phx-change="update_element" class="mt-1">
                <input type="hidden" name="field" value="font_weight" />
                <select
                  name="value"
                  class="block w-full rounded-md border-gray-300 shadow-sm text-sm"
                >
                  <option value="normal" selected={@element.font_weight == "normal"}>Normal</option>
                  <option value="bold" selected={@element.font_weight == "bold"}>Negrita</option>
                </select>
              </form>
            </div>
          </div>

        <% "image" -> %>
          <div class="border-t pt-4 space-y-3">
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
          </div>

        <% "line" -> %>
          <div class="border-t pt-4 space-y-3">
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
          </div>

        <% "rectangle" -> %>
          <div class="border-t pt-4 space-y-3">
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
              <p class="text-xs text-gray-400 mt-1">0% = esquinas rectas, 100% = máximo redondeo</p>
            </div>
          </div>

        <% "circle" -> %>
          <div class="border-t pt-4 space-y-3">
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
              <p class="text-xs text-gray-400 mt-1">0% = rectángulo, 100% = elipse</p>
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
          </div>

        <% _ -> %>
          <div class="border-t pt-4">
            <p class="text-sm text-gray-500">Este elemento no tiene propiedades adicionales.</p>
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

  # Placeholder text for fixed content input
  defp get_fixed_text_placeholder("qr"), do: "URL o texto a codificar"
  defp get_fixed_text_placeholder("barcode"), do: "Código a mostrar"
  defp get_fixed_text_placeholder("text"), do: "Texto fijo"
  defp get_fixed_text_placeholder(_), do: "Contenido"
end
