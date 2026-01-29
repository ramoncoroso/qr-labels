defmodule QrLabelSystemWeb.DesignLive.Editor do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Designs.Design

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    design = Designs.get_design!(id)

    if design.user_id != socket.assigns.current_user.id do
      {:ok,
       socket
       |> put_flash(:error, "No tienes permiso para editar este diseño")
       |> push_navigate(to: ~p"/designs")}
    else
      {:ok,
       socket
       |> assign(:page_title, "Editor: #{design.name}")
       |> assign(:design, design)
       |> assign(:selected_element, nil)
       |> assign(:available_columns, [])
       |> assign(:show_properties, true)
       |> assign(:show_preview, false)
       |> assign(:preview_data, %{"col1" => "Ejemplo 1", "col2" => "Ejemplo 2", "col3" => "12345"})
       |> assign(:history, [])
       |> assign(:history_index, -1)
       |> assign(:has_unsaved_changes, false)}
    end
  end

  @impl true
  def handle_event("canvas_ready", _params, socket) do
    # Send design data to canvas
    {:noreply, push_event(socket, "load_design", %{design: Design.to_json(socket.assigns.design)})}
  end

  @valid_element_types ~w(qr barcode text line rectangle image)

  @impl true
  def handle_event("add_element", %{"type" => type}, socket) when type in @valid_element_types do
    element = create_default_element(type)
    {:noreply, push_event(socket, "add_element", %{element: element})}
  end

  def handle_event("add_element", %{"type" => _invalid_type}, socket) do
    {:noreply, put_flash(socket, :error, "Tipo de elemento no válido")}
  end

  @impl true
  def handle_event("element_selected", %{"id" => id}, socket) do
    element = Enum.find(socket.assigns.design.elements || [], &(&1.id == id))
    {:noreply, assign(socket, :selected_element, element)}
  end

  @impl true
  def handle_event("element_deselected", _params, socket) do
    {:noreply, assign(socket, :selected_element, nil)}
  end

  @impl true
  def handle_event("element_modified", %{"elements" => elements_json}, socket) do
    # Update design with modified elements from canvas
    design = socket.assigns.design

    case Designs.update_design(design, %{elements: elements_json}) do
      {:ok, updated_design} ->
        {:noreply,
         socket
         |> push_to_history(design)
         |> assign(:design, updated_design)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Error al guardar cambios")}
    end
  end

  @impl true
  def handle_event("update_element", %{"field" => field, "value" => value}, socket) do
    if socket.assigns.selected_element do
      {:noreply, push_event(socket, "update_element_property", %{field: field, value: value})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_element", _params, socket) do
    if socket.assigns.selected_element do
      {:noreply,
       socket
       |> push_event("delete_element", %{id: socket.assigns.selected_element.id})
       |> assign(:selected_element, nil)}
    else
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
  def handle_event("save_design", _params, socket) do
    # Persist current design state to database
    case Designs.update_design(socket.assigns.design, %{elements: socket.assigns.design.elements}) do
      {:ok, saved_design} ->
        {:noreply,
         socket
         |> assign(:design, saved_design)
         |> assign(:has_unsaved_changes, false)
         |> put_flash(:info, "Diseño guardado")
         |> push_event("save_to_server", %{})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Error al guardar el diseño")}
    end
  end

  defp create_default_element(type) do
    base = %{
      id: Ecto.UUID.generate(),
      type: type,
      x: 10.0,
      y: 10.0,
      rotation: 0
    }

    case type do
      "qr" ->
        Map.merge(base, %{
          width: 20.0,
          height: 20.0,
          qr_error_level: "M",
          binding: nil
        })

      "barcode" ->
        Map.merge(base, %{
          width: 40.0,
          height: 15.0,
          barcode_format: "CODE128",
          barcode_show_text: true,
          binding: nil
        })

      "text" ->
        Map.merge(base, %{
          width: 30.0,
          height: 8.0,
          font_size: 12,
          font_family: "Arial",
          font_weight: "normal",
          text_align: "left",
          text_content: "Texto",
          color: "#000000",
          binding: nil
        })

      "line" ->
        Map.merge(base, %{
          width: 50.0,
          height: 0.5,
          color: "#000000"
        })

      "rectangle" ->
        Map.merge(base, %{
          width: 30.0,
          height: 20.0,
          background_color: "transparent",
          border_width: 0.5,
          border_color: "#000000"
        })

      "image" ->
        Map.merge(base, %{
          width: 20.0,
          height: 20.0,
          image_url: nil
        })

      _ ->
        base
    end
  end

  # History management for undo/redo
  @max_history_size 50

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
       |> push_event("load_design", %{design: Design.to_json(updated_design)})}
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
       |> push_event("load_design", %{design: Design.to_json(updated_design)})}
    else
      :no_future
    end
  end

  defp can_undo?(socket), do: socket.assigns.history_index > 0
  defp can_redo?(socket), do: socket.assigns.history_index < length(socket.assigns.history) - 1

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
    ~H"""
    <div class="h-[calc(100vh-12rem)] flex flex-col" id="editor-container" phx-hook="KeyboardShortcuts">
      <!-- Toolbar -->
      <div class="bg-white border-b border-gray-200 px-4 py-2 flex items-center justify-between">
        <div class="flex items-center space-x-2">
          <.link navigate={~p"/designs"} class="text-gray-500 hover:text-gray-700">
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
          </.link>
          <span class="text-lg font-semibold text-gray-900"><%= @design.name %></span>
        </div>

        <div class="flex items-center space-x-4">
          <!-- Undo/Redo buttons -->
          <div class="flex items-center space-x-1 bg-gray-100 rounded-lg p-1">
            <button
              phx-click="undo"
              disabled={!@can_undo}
              class={"p-2 rounded hover:bg-white hover:shadow #{if @can_undo, do: "text-gray-600 hover:text-indigo-600", else: "text-gray-300 cursor-not-allowed"}"}
              title="Deshacer (Ctrl+Z)"
            >
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6" />
              </svg>
            </button>
            <button
              phx-click="redo"
              disabled={!@can_redo}
              class={"p-2 rounded hover:bg-white hover:shadow #{if @can_redo, do: "text-gray-600 hover:text-indigo-600", else: "text-gray-300 cursor-not-allowed"}"}
              title="Rehacer (Ctrl+Y)"
            >
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 10h-10a8 8 0 00-8 8v2M21 10l-6 6m6-6l-6-6" />
              </svg>
            </button>
          </div>

          <!-- Element buttons -->
          <div class="flex items-center space-x-1 bg-gray-100 rounded-lg p-1">
            <button
              phx-click="add_element"
              phx-value-type="qr"
              class="p-2 rounded hover:bg-white hover:shadow text-gray-600 hover:text-indigo-600"
              title="Agregar QR"
            >
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z" />
              </svg>
            </button>
            <button
              phx-click="add_element"
              phx-value-type="barcode"
              class="p-2 rounded hover:bg-white hover:shadow text-gray-600 hover:text-indigo-600"
              title="Agregar Código de Barras"
            >
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 17h.01M17 7h.01M17 17h.01M12 7v10M7 7v10m10-10v10" />
              </svg>
            </button>
            <button
              phx-click="add_element"
              phx-value-type="text"
              class="p-2 rounded hover:bg-white hover:shadow text-gray-600 hover:text-indigo-600"
              title="Agregar Texto"
            >
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16m-7 6h7" />
              </svg>
            </button>
            <button
              phx-click="add_element"
              phx-value-type="line"
              class="p-2 rounded hover:bg-white hover:shadow text-gray-600 hover:text-indigo-600"
              title="Agregar Línea"
            >
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 12h16" />
              </svg>
            </button>
            <button
              phx-click="add_element"
              phx-value-type="rectangle"
              class="p-2 rounded hover:bg-white hover:shadow text-gray-600 hover:text-indigo-600"
              title="Agregar Rectángulo"
            >
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h12a2 2 0 012 2v12a2 2 0 01-2 2H6a2 2 0 01-2-2V6z" />
              </svg>
            </button>
            <button
              phx-click="add_element"
              phx-value-type="image"
              class="p-2 rounded hover:bg-white hover:shadow text-gray-600 hover:text-indigo-600"
              title="Agregar Imagen"
            >
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
            </button>
          </div>

          <button
            phx-click="toggle_preview"
            class={"p-2 rounded hover:bg-gray-100 #{if @show_preview, do: "text-indigo-600 bg-indigo-50", else: "text-gray-600"}"}
            title="Vista Previa (Ctrl+P)"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
            </svg>
          </button>

          <button
            phx-click="toggle_properties"
            class="p-2 rounded hover:bg-gray-100 text-gray-600"
            title="Mostrar/Ocultar Propiedades"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </button>

          <button
            phx-click="save_design"
            class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 flex items-center space-x-2"
            title="Guardar (Ctrl+S)"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
            <span>Guardar</span>
          </button>
        </div>
      </div>

      <!-- Main Content -->
      <div class="flex-1 flex overflow-hidden">
        <!-- Canvas Area -->
        <div class={"flex-1 bg-gray-100 overflow-auto p-8 flex items-center justify-center #{if @show_preview, do: "w-1/2", else: ""}"}>
          <div
            id="canvas-container"
            phx-hook="CanvasDesigner"
            data-width={@design.width_mm}
            data-height={@design.height_mm}
            data-background-color={@design.background_color}
            data-border-width={@design.border_width}
            data-border-color={@design.border_color}
            data-border-radius={@design.border_radius}
            class="shadow-xl"
          >
            <canvas id="label-canvas"></canvas>
          </div>
        </div>

        <!-- Live Preview Panel -->
        <div :if={@show_preview} class="w-1/2 bg-gray-50 border-l border-gray-200 overflow-auto p-4">
          <div class="mb-4">
            <h3 class="font-semibold text-gray-900 mb-2">Vista Previa en Tiempo Real</h3>
            <p class="text-sm text-gray-500">Muestra cómo se verá la etiqueta con datos de ejemplo</p>
          </div>

          <div class="bg-white rounded-lg shadow p-4 mb-4">
            <h4 class="text-sm font-medium text-gray-700 mb-2">Datos de Prueba</h4>
            <div class="grid grid-cols-2 gap-2 text-sm">
              <%= for {key, value} <- @preview_data do %>
                <div class="flex items-center space-x-2">
                  <span class="text-gray-500"><%= key %>:</span>
                  <span class="font-mono text-gray-900"><%= value %></span>
                </div>
              <% end %>
            </div>
          </div>

          <div class="flex justify-center">
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
        </div>

        <!-- Properties Panel -->
        <div :if={@show_properties} class="w-80 bg-white border-l border-gray-200 overflow-y-auto">
          <div class="p-4">
            <%= if @selected_element do %>
              <h3 class="font-semibold text-gray-900 mb-4">Propiedades del Elemento</h3>
              <.element_properties element={@selected_element} />

              <div class="mt-6 pt-4 border-t">
                <button
                  phx-click="delete_element"
                  class="w-full bg-red-50 text-red-600 px-4 py-2 rounded-lg hover:bg-red-100"
                >
                  Eliminar Elemento
                </button>
              </div>
            <% else %>
              <h3 class="font-semibold text-gray-900 mb-4">Propiedades de la Etiqueta</h3>
              <.label_properties design={@design} />
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp element_properties(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="block text-sm font-medium text-gray-700">X (mm)</label>
          <input
            type="number"
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
            step="0.1"
            value={@element.y}
            phx-blur="update_element"
            phx-value-field="y"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
          />
        </div>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="block text-sm font-medium text-gray-700">Ancho (mm)</label>
          <input
            type="number"
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
            step="0.1"
            value={@element.height}
            phx-blur="update_element"
            phx-value-field="height"
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
          />
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700">Rotación (°)</label>
        <input
          type="number"
          step="1"
          value={@element.rotation || 0}
          phx-blur="update_element"
          phx-value-field="rotation"
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
        />
      </div>

      <div class="border-t pt-4">
        <label class="block text-sm font-medium text-gray-700">Vincular a columna</label>
        <input
          type="text"
          value={@element.binding || ""}
          placeholder="Nombre de columna"
          phx-blur="update_element"
          phx-value-field="binding"
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
        />
        <p class="mt-1 text-xs text-gray-500">
          Ingresa el nombre exacto de la columna del Excel/BD
        </p>
      </div>

      <%= case @element.type do %>
        <% "qr" -> %>
          <div class="border-t pt-4">
            <label class="block text-sm font-medium text-gray-700">Nivel de corrección de error</label>
            <select
              phx-blur="update_element"
              phx-value-field="qr_error_level"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
            >
              <option value="L" selected={@element.qr_error_level == "L"}>L (7%)</option>
              <option value="M" selected={@element.qr_error_level == "M"}>M (15%)</option>
              <option value="Q" selected={@element.qr_error_level == "Q"}>Q (25%)</option>
              <option value="H" selected={@element.qr_error_level == "H"}>H (30%)</option>
            </select>
          </div>

        <% "barcode" -> %>
          <div class="border-t pt-4 space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700">Formato</label>
              <select
                phx-blur="update_element"
                phx-value-field="barcode_format"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
              >
                <option value="CODE128" selected={@element.barcode_format == "CODE128"}>CODE128</option>
                <option value="CODE39" selected={@element.barcode_format == "CODE39"}>CODE39</option>
                <option value="EAN13" selected={@element.barcode_format == "EAN13"}>EAN-13</option>
                <option value="EAN8" selected={@element.barcode_format == "EAN8"}>EAN-8</option>
                <option value="UPC" selected={@element.barcode_format == "UPC"}>UPC</option>
                <option value="ITF14" selected={@element.barcode_format == "ITF14"}>ITF-14</option>
              </select>
            </div>
            <div class="flex items-center">
              <input
                type="checkbox"
                id="barcode_show_text"
                checked={@element.barcode_show_text}
                phx-click="update_element"
                phx-value-field="barcode_show_text"
                class="rounded border-gray-300"
              />
              <label for="barcode_show_text" class="ml-2 text-sm text-gray-700">Mostrar texto</label>
            </div>
          </div>

        <% "text" -> %>
          <div class="border-t pt-4 space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700">Contenido (si no está vinculado)</label>
              <input
                type="text"
                value={@element.text_content || ""}
                phx-blur="update_element"
                phx-value-field="text_content"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
              />
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-sm font-medium text-gray-700">Tamaño fuente</label>
                <input
                  type="number"
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
                  value={@element.color || "#000000"}
                  phx-change="update_element"
                  phx-value-field="color"
                  class="mt-1 block w-full h-9 rounded-md border-gray-300"
                />
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Alineación</label>
              <select
                phx-blur="update_element"
                phx-value-field="text_align"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
              >
                <option value="left" selected={@element.text_align == "left"}>Izquierda</option>
                <option value="center" selected={@element.text_align == "center"}>Centro</option>
                <option value="right" selected={@element.text_align == "right"}>Derecha</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Peso</label>
              <select
                phx-blur="update_element"
                phx-value-field="font_weight"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm text-sm"
              >
                <option value="normal" selected={@element.font_weight == "normal"}>Normal</option>
                <option value="bold" selected={@element.font_weight == "bold"}>Negrita</option>
              </select>
            </div>
          </div>

        <% _ -> %>
          <div class="border-t pt-4 space-y-3">
            <div>
              <label class="block text-sm font-medium text-gray-700">Color</label>
              <input
                type="color"
                value={@element.color || "#000000"}
                phx-change="update_element"
                phx-value-field="color"
                class="mt-1 block w-full h-9 rounded-md border-gray-300"
              />
            </div>
          </div>
      <% end %>
    </div>
    """
  end

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
end
