defmodule QrLabelSystemWeb.GenerateLive.DesignSelect do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs

  @impl true
  def mount(params, _session, socket) do
    user_id = socket.assigns.current_user.id
    no_data_mode = Map.get(params, "no_data") == "true"

    # Get data from persistent store (data not yet associated with a design)
    {upload_data, upload_columns} = QrLabelSystem.UploadDataStore.get(user_id, nil)

    cond do
      # Mode: designing without external data
      no_data_mode ->
        designs = Designs.list_user_designs_by_type(user_id, "multiple")

        {:ok,
         socket
         |> assign(:page_title, "Elegir Diseño")
         |> assign(:designs, designs)
         |> assign(:upload_data, [])
         |> assign(:upload_columns, [])
         |> assign(:no_data_mode, true)
         |> assign(:selected_design_id, nil)}

      # Mode: with uploaded data
      not is_nil(upload_data) and length(upload_data) > 0 ->
        designs = Designs.list_user_designs_by_type(user_id, "multiple")

        {:ok,
         socket
         |> assign(:page_title, "Elegir Diseño")
         |> assign(:designs, designs)
         |> assign(:upload_data, upload_data)
         |> assign(:upload_columns, upload_columns)
         |> assign(:no_data_mode, false)
         |> assign(:selected_design_id, nil)}

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
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto">
      <.header>
        Elegir diseño de etiqueta
        <:subtitle>
          <%= if @no_data_mode do %>
            Selecciona un diseño existente o crea uno nuevo (solo texto fijo)
          <% else %>
            Selecciona un diseño existente o crea uno nuevo para tus <%= length(@upload_data) %> registros
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
                <p class="font-semibold text-indigo-900"><%= length(@upload_data) %> registros</p>
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
            <button
              phx-click="select_design"
              phx-value-id={design.id}
              class={"bg-white rounded-xl shadow-sm p-6 cursor-pointer transition-all text-left border-2 #{if @selected_design_id == design.id, do: "border-indigo-500 ring-2 ring-indigo-200", else: "border-transparent hover:border-indigo-300"}"}
            >
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-lg font-semibold text-gray-900 truncate"><%= design.name %></h3>
                <%= if @selected_design_id == design.id do %>
                  <div class="w-6 h-6 bg-indigo-500 rounded-full flex items-center justify-center flex-shrink-0">
                    <svg class="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                    </svg>
                  </div>
                <% end %>
              </div>

              <p class="text-sm text-gray-500 mb-3 line-clamp-2"><%= design.description || "Sin descripción" %></p>

              <div class="flex items-center justify-between text-sm text-gray-600 mb-4">
                <span><%= design.width_mm %> × <%= design.height_mm %> mm</span>
                <span><%= length(design.elements || []) %> elementos</span>
              </div>

              <!-- Mini Preview -->
              <div class="bg-gray-100 rounded-lg p-3 flex justify-center">
                <div
                  class="bg-white shadow-sm rounded"
                  style={"width: #{min(design.width_mm * 2, 120)}px; height: #{min(design.height_mm * 2, 80)}px; background-color: #{design.background_color}; border: 1px solid #{design.border_color};"}
                >
                </div>
              </div>

              <!-- Show binding info -->
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
            </button>
          <% end %>
        </div>

        <%= if length(@designs) == 0 do %>
          <div class="mt-4 text-center py-8 bg-gray-50 rounded-xl">
            <p class="text-gray-500">Aún no tienes diseños. Crea tu primer diseño para continuar.</p>
          </div>
        <% end %>

        <!-- Action Buttons -->
        <div class="mt-8 flex justify-between items-center">
          <button
            phx-click="back"
            class="px-6 py-3 rounded-xl border border-gray-300 text-gray-700 hover:bg-gray-50 font-medium transition"
          >
            Volver
          </button>

          <button
            :if={@selected_design_id}
            phx-click="use_design"
            class="px-8 py-3 rounded-xl font-medium transition flex items-center space-x-2 bg-indigo-600 hover:bg-indigo-700 text-white"
          >
            <span>Usar este diseño</span>
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
            </svg>
          </button>
        </div>
      </div>
    </div>
    """
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
