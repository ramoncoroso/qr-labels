defmodule QrLabelSystemWeb.GenerateLive.DesignSelect do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs

  import QrLabelSystemWeb.DesignComponents

  @impl true
  def mount(params, _session, socket) do
    user_id = socket.assigns.current_user.id
    no_data_mode = Map.get(params, "no_data") == "true"

    # Get metadata from persistent store (data not yet associated with a design)
    {upload_columns, upload_total_rows, _upload_sample_rows} = QrLabelSystem.UploadDataStore.get_metadata(user_id, nil)

    cond do
      # Mode: designing without external data
      no_data_mode ->
        all_designs = Designs.list_workspace_designs_by_type(socket.assigns.current_workspace.id, "multiple")
        tags = Designs.list_workspace_tags(socket.assigns.current_workspace.id)

        {:ok,
         socket
         |> assign(:page_title, "Elegir Diseño")
         |> assign(:all_designs, all_designs)
         |> assign(:designs, all_designs)
         |> assign(:tags, tags)
         |> assign(:active_tag_ids, [])
         |> assign(:upload_total_rows, 0)
         |> assign(:upload_columns, [])
         |> assign(:no_data_mode, true)
         |> assign(:selected_design_id, nil)
         |> assign(:preview_design, nil)}

      # Mode: with uploaded data
      upload_total_rows > 0 ->
        all_designs = Designs.list_workspace_designs_by_type(socket.assigns.current_workspace.id, "multiple")
        tags = Designs.list_workspace_tags(socket.assigns.current_workspace.id)

        {:ok,
         socket
         |> assign(:page_title, "Elegir Diseño")
         |> assign(:all_designs, all_designs)
         |> assign(:designs, all_designs)
         |> assign(:tags, tags)
         |> assign(:active_tag_ids, [])
         |> assign(:upload_total_rows, upload_total_rows)
         |> assign(:upload_columns, upload_columns)
         |> assign(:no_data_mode, false)
         |> assign(:selected_design_id, nil)
         |> assign(:preview_design, nil)}

      # No data and not in no_data mode - redirect
      true ->
        {:ok,
         socket
         |> put_flash(:error, "No hay datos cargados. Por favor, carga los datos primero.")
         |> push_navigate(to: ~p"/generate/data")}
    end
  end

  @impl true
  def handle_event("select_design", %{"id" => design_id}, socket) do
    {:noreply, assign(socket, :selected_design_id, design_id)}
  end

  @impl true
  def handle_event("use_design", _params, socket) do
    design_id = socket.assigns.selected_design_id
    user_id = socket.assigns.current_user.id
    no_data_mode = socket.assigns.no_data_mode

    if design_id do
      design = Designs.get_design!(design_id)

      # Verify ownership
      if design.user_id != user_id do
        {:noreply, put_flash(socket, :error, "No tienes permiso para usar este diseño")}
      else
        if no_data_mode do
          # No data mode - go directly to editor with no_data flag
          {:noreply,
           socket
           |> put_flash(:info, "Diseñando sin datos externos - solo texto fijo disponible")
           |> push_navigate(to: ~p"/designs/#{design.id}/edit?no_data=true")}
        else
          # Associate the data with this design
          QrLabelSystem.UploadDataStore.associate_with_design(user_id, design.id)

          # Navigate to editor - data is now associated with the design
          {:noreply,
           socket
           |> put_flash(:info, "Asigna las columnas a los elementos y previsualiza el resultado")
           |> push_navigate(to: ~p"/designs/#{design.id}/edit")}
        end
      end
    else
      {:noreply, put_flash(socket, :error, "Selecciona un diseño primero")}
    end
  end

  @impl true
  def handle_event("create_new", _params, socket) do
    no_data_mode = socket.assigns.no_data_mode

    if no_data_mode do
      # No data mode - pass no_data flag
      {:noreply,
       socket
       |> put_flash(:return_to, "design_select")
       |> push_navigate(to: ~p"/designs/new?type=multiple&no_data=true")}
    else
      # Data is already in the persistent store, just navigate
      {:noreply,
       socket
       |> put_flash(:return_to, "design_select")
       |> push_navigate(to: ~p"/designs/new?type=multiple")}
    end
  end

  @impl true
  def handle_event("back", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/generate/data")}
  end

  @impl true
  def handle_event("preview_design", %{"id" => design_id}, socket) do
    design = Enum.find(socket.assigns.designs, fn d -> to_string(d.id) == design_id end)
    {:noreply, assign(socket, :preview_design, design)}
  end

  @impl true
  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, :preview_design, nil)}
  end

  @impl true
  def handle_event("toggle_tag_filter", %{"id" => tag_id}, socket) do
    {tag_id, ""} = Integer.parse(tag_id)
    active = socket.assigns.active_tag_ids

    active =
      if tag_id in active,
        do: List.delete(active, tag_id),
        else: active ++ [tag_id]

    designs = filter_by_tags(socket.assigns.all_designs, active)

    {:noreply,
     socket
     |> assign(:active_tag_ids, active)
     |> assign(:designs, designs)
     |> assign(:selected_design_id, nil)}
  end

  @impl true
  def handle_event("clear_tag_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:active_tag_ids, [])
     |> assign(:designs, socket.assigns.all_designs)
     |> assign(:selected_design_id, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto">
      <.header>
        Elegir diseño de etiqueta
        <:subtitle>
          <%= if @no_data_mode do %>
            Selecciona un diseño existente o crea uno nuevo (solo texto fijo)
          <% else %>
            Selecciona un diseño existente o crea uno nuevo para tus <%= @upload_total_rows %> registros
          <% end %>
        </:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Progress Steps -->
        <div class="mb-8">
          <div class="flex items-center justify-center space-x-4">
            <%= if @no_data_mode do %>
              <div class="flex items-center">
                <div class="w-8 h-8 bg-green-600 rounded-full flex items-center justify-center text-white">
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                </div>
                <span class="ml-2 text-sm font-medium text-green-600">Sin datos</span>
              </div>
            <% else %>
              <div class="flex items-center">
                <div class="w-8 h-8 bg-green-600 rounded-full flex items-center justify-center text-white">
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                </div>
                <span class="ml-2 text-sm font-medium text-green-600">Datos cargados</span>
              </div>
            <% end %>
            <div class="w-16 h-0.5 bg-indigo-600"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-sm">2</div>
              <span class="ml-2 text-sm font-medium text-indigo-600">Elegir diseño</span>
            </div>
            <div class="w-16 h-0.5 bg-gray-300"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">3</div>
              <span class="ml-2 text-sm text-gray-500">Imprimir</span>
            </div>
          </div>
        </div>

        <!-- Data Summary (only when we have data) -->
        <div :if={not @no_data_mode} class="bg-indigo-50 rounded-xl p-4 mb-8">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-4">
              <div class="w-12 h-12 bg-indigo-100 rounded-xl flex items-center justify-center">
                <svg class="w-6 h-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
                </svg>
              </div>
              <div>
                <p class="text-sm text-indigo-600">Datos cargados:</p>
                <p class="font-semibold text-indigo-900"><%= @upload_total_rows %> registros</p>
              </div>
            </div>
            <div class="flex flex-wrap gap-2">
              <%= for col <- @upload_columns do %>
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
                  <%= col %>
                </span>
              <% end %>
            </div>
          </div>
        </div>

        <!-- No Data Mode Info -->
        <div :if={@no_data_mode} class="bg-amber-50 rounded-xl p-4 mb-8">
          <div class="flex items-center space-x-4">
            <div class="w-12 h-12 bg-amber-100 rounded-xl flex items-center justify-center">
              <svg class="w-6 h-6 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </div>
            <div>
              <p class="text-sm text-amber-600">Modo diseño sin datos</p>
              <p class="font-semibold text-amber-900">Solo texto fijo disponible</p>
            </div>
          </div>
        </div>

        <!-- Tag Filters -->
        <div :if={@tags != []} class="flex flex-wrap items-center gap-2 mb-6">
          <%= for tag <- @tags do %>
            <button
              type="button"
              phx-click="toggle_tag_filter"
              phx-value-id={tag.id}
              class={"inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium transition-all #{if tag.id in @active_tag_ids, do: "ring-2 ring-offset-1 ring-blue-400", else: ""}"}
              style={"background-color: #{tag.color}20; color: #{tag.color};"}
            >
              <span class="w-2 h-2 rounded-full" style={"background-color: #{tag.color};"}></span>
              <%= tag.name %>
            </button>
          <% end %>
          <button
            :if={@active_tag_ids != []}
            type="button"
            phx-click="clear_tag_filters"
            class="text-xs text-gray-400 hover:text-gray-600 ml-1"
          >
            Limpiar filtros
          </button>
        </div>

        <!-- Design Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <!-- Create New Design Card -->
          <button
            phx-click="create_new"
            class="bg-slate-50 rounded-xl border-2 border-dashed border-slate-300 hover:border-indigo-500 hover:bg-indigo-50 p-6 cursor-pointer transition-all flex flex-col items-center justify-center min-h-[220px]"
          >
            <div class="w-14 h-14 bg-slate-200 rounded-full flex items-center justify-center mb-4">
              <svg class="w-7 h-7 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-slate-600">Nuevo Diseño</h3>
            <p class="text-sm text-slate-500 text-center mt-1">Crear una nueva plantilla</p>
          </button>

          <!-- Existing Designs -->
          <%= for design <- @designs do %>
            <% is_selected = @selected_design_id == to_string(design.id) %>
            <div
              phx-click="select_design"
              phx-value-id={design.id}
              class={"bg-white rounded-xl shadow-sm p-6 cursor-pointer transition-all text-left border-2 #{if is_selected, do: "border-indigo-500 ring-2 ring-indigo-200", else: "border-transparent hover:border-indigo-300"}"}
            >
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-lg font-semibold text-gray-900 truncate"><%= design.name %></h3>
                <%= if is_selected do %>
                  <div class="w-6 h-6 bg-indigo-500 rounded-full flex items-center justify-center flex-shrink-0">
                    <svg class="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                    </svg>
                  </div>
                <% end %>
              </div>

              <p :if={design.description} class="text-sm text-gray-500 mb-3 line-clamp-2"><%= design.description %></p>

              <div class="text-sm text-gray-600 mb-3">
                <span><%= design.width_mm %> × <%= design.height_mm %> mm</span>
              </div>

              <!-- Tags -->
              <div :if={(design.tags || []) != []} class="flex flex-wrap gap-1 mb-3">
                <%= for tag <- design.tags do %>
                  <span
                    class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-medium"
                    style={"background-color: #{tag.color}20; color: #{tag.color};"}
                  >
                    <span class="w-1.5 h-1.5 rounded-full" style={"background-color: #{tag.color};"}></span>
                    <%= tag.name %>
                  </span>
                <% end %>
              </div>

              <!-- Mini Preview -->
              <div class="bg-gray-100 rounded-lg p-3 flex justify-center items-center min-h-[80px]">
                <.design_thumbnail design={design} max_width={140} max_height={90} />
              </div>

              <!-- Action buttons when selected -->
              <%= if is_selected do %>
                <div class="mt-4 flex gap-2">
                  <button
                    type="button"
                    phx-click="preview_design"
                    phx-value-id={design.id}
                    class="flex-1 flex items-center justify-center gap-2 px-3 py-2 text-sm font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg transition"
                  >
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7" />
                    </svg>
                    Ampliar
                  </button>
                  <button
                    type="button"
                    phx-click="use_design"
                    class="flex-1 flex items-center justify-center gap-2 px-3 py-2 text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 rounded-lg transition"
                  >
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                    </svg>
                    Usar diseño
                  </button>
                </div>
              <% else %>
                <!-- Show binding info only when not selected -->
                <% bindings = get_bindings(design.elements) %>
                <%= if length(bindings) > 0 do %>
                  <div class="mt-3 pt-3 border-t border-gray-100">
                    <p class="text-xs text-gray-500 mb-1">Campos vinculados:</p>
                    <div class="flex flex-wrap gap-1">
                      <%= for binding <- Enum.take(bindings, 4) do %>
                        <span class={"text-xs px-1.5 py-0.5 rounded #{if binding in @upload_columns, do: "bg-green-100 text-green-700", else: "bg-gray-100 text-gray-600"}"}>
                          <%= binding %>
                        </span>
                      <% end %>
                      <%= if length(bindings) > 4 do %>
                        <span class="text-xs text-gray-400">+<%= length(bindings) - 4 %></span>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>

        <%= if length(@designs) == 0 do %>
          <div class="mt-4 text-center py-8 bg-gray-50 rounded-xl">
            <p class="text-gray-500">Aún no tienes diseños. Crea tu primer diseño o usa una plantilla.</p>
          </div>
        <% end %>

        <!-- Action Buttons -->
        <div class="mt-8 flex justify-start">
          <button
            phx-click="back"
            class="px-6 py-3 rounded-xl border border-gray-300 text-gray-700 hover:bg-gray-50 font-medium transition"
          >
            Volver
          </button>
        </div>
      </div>

      <!-- Preview Modal -->
      <%= if @preview_design do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4" phx-click="close_preview">
          <div class="bg-white rounded-2xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-auto" phx-click-away="close_preview">
            <!-- Modal Header -->
            <div class="flex items-center justify-between p-4 border-b">
              <div>
                <h3 class="text-lg font-semibold text-gray-900"><%= @preview_design.name %></h3>
                <p class="text-sm text-gray-500"><%= @preview_design.width_mm %> × <%= @preview_design.height_mm %> mm</p>
              </div>
              <button
                type="button"
                phx-click="close_preview"
                class="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100 transition"
              >
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <!-- Modal Body - Large Preview -->
            <div class="p-6 bg-gray-100 flex justify-center">
              <.design_thumbnail design={@preview_design} max_width={400} max_height={300} />
            </div>

            <!-- Design Info -->
            <div class="p-4 border-t">
              <p :if={@preview_design.description} class="text-sm text-gray-600 mb-3"><%= @preview_design.description %></p>

              <% bindings = get_bindings(@preview_design.elements) %>
              <%= if length(bindings) > 0 do %>
                <div class="mb-4">
                  <p class="text-xs text-gray-500 mb-2">Campos vinculados:</p>
                  <div class="flex flex-wrap gap-1">
                    <%= for binding <- bindings do %>
                      <span class={"text-xs px-2 py-1 rounded #{if binding in @upload_columns, do: "bg-green-100 text-green-700", else: "bg-gray-100 text-gray-600"}"}>
                        <%= binding %>
                      </span>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- Modal Actions -->
              <div class="flex gap-3">
                <button
                  type="button"
                  phx-click="close_preview"
                  class="flex-1 px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg transition"
                >
                  Cerrar
                </button>
                <button
                  type="button"
                  phx-click="use_design"
                  class="flex-1 px-4 py-2 text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 rounded-lg transition flex items-center justify-center gap-2"
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                  Usar este diseño
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp filter_by_tags(designs, []), do: designs

  defp filter_by_tags(designs, active_tag_ids) do
    Enum.filter(designs, fn design ->
      design_tag_ids = Enum.map(design.tags || [], & &1.id)
      Enum.all?(active_tag_ids, &(&1 in design_tag_ids))
    end)
  end

  defp get_bindings(elements) when is_list(elements) do
    elements
    |> Enum.map(fn el ->
      Map.get(el, :binding) || Map.get(el, "binding")
    end)
    |> Enum.filter(&(&1 && &1 != ""))
    |> Enum.uniq()
  end

  defp get_bindings(_), do: []
end
