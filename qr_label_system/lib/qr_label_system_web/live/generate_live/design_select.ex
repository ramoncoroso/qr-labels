defmodule QrLabelSystemWeb.GenerateLive.DesignSelect do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Batches

  @impl true
  def mount(_params, _session, socket) do
    # Get data from flash
    upload_data = Phoenix.Flash.get(socket.assigns.flash, :upload_data)
    upload_columns = Phoenix.Flash.get(socket.assigns.flash, :upload_columns)

    if is_nil(upload_data) or length(upload_data) == 0 do
      {:ok,
       socket
       |> put_flash(:error, "No hay datos cargados. Por favor, carga los datos primero.")
       |> push_navigate(to: ~p"/generate/data")}
    else
      designs = Designs.list_user_designs(socket.assigns.current_user.id)

      {:ok,
       socket
       |> assign(:page_title, "Elegir Diseño")
       |> assign(:designs, designs)
       |> assign(:upload_data, upload_data)
       |> assign(:upload_columns, upload_columns)
       |> assign(:selected_design_id, nil)
       |> assign(:creating_batch, false)}
    end
  end

  @impl true
  def handle_event("select_design", %{"id" => design_id}, socket) do
    {:noreply, assign(socket, :selected_design_id, design_id)}
  end

  @impl true
  def handle_event("use_design", _params, socket) do
    design_id = socket.assigns.selected_design_id

    if design_id do
      design = Designs.get_design!(design_id)

      # Verify ownership
      if design.user_id != socket.assigns.current_user.id do
        {:noreply, put_flash(socket, :error, "No tienes permiso para usar este diseño")}
      else
        # Create a batch with the uploaded data
        {:noreply,
         socket
         |> assign(:creating_batch, true)
         |> create_batch_and_redirect(design)}
      end
    else
      {:noreply, put_flash(socket, :error, "Selecciona un diseño primero")}
    end
  end

  @impl true
  def handle_event("create_new", _params, socket) do
    # Store data in session/flash and redirect to design creation
    {:noreply,
     socket
     |> put_flash(:upload_data, socket.assigns.upload_data)
     |> put_flash(:upload_columns, socket.assigns.upload_columns)
     |> put_flash(:return_to, "design_select")
     |> push_navigate(to: ~p"/designs/new")}
  end

  @impl true
  def handle_event("back", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/generate/data")}
  end

  defp create_batch_and_redirect(socket, design) do
    # Build auto-mapping based on column names matching element bindings
    column_mapping = build_auto_mapping(design.elements || [], socket.assigns.upload_columns)

    batch_attrs = %{
      name: "Lote - #{design.name} - #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M")}",
      design_id: design.id,
      user_id: socket.assigns.current_user.id,
      column_mapping: column_mapping,
      data_snapshot: socket.assigns.upload_data,
      total_labels: length(socket.assigns.upload_data),
      status: "ready"
    }

    case Batches.create_batch(batch_attrs) do
      {:ok, batch} ->
        socket
        |> put_flash(:info, "Lote creado correctamente")
        |> push_navigate(to: ~p"/generate/preview/#{batch.id}")

      {:error, _changeset} ->
        socket
        |> assign(:creating_batch, false)
        |> put_flash(:error, "Error al crear el lote de etiquetas")
    end
  end

  defp build_auto_mapping(elements, columns) do
    elements
    |> Enum.filter(fn el ->
      binding = Map.get(el, :binding) || Map.get(el, "binding")
      binding && binding != ""
    end)
    |> Enum.reduce(%{}, fn element, acc ->
      binding = Map.get(element, :binding) || Map.get(element, "binding")
      element_id = Map.get(element, :id) || Map.get(element, "id")

      # Find matching column (case-insensitive)
      matching_column = Enum.find(columns, fn col ->
        String.downcase(col) == String.downcase(binding)
      end)

      if matching_column do
        Map.put(acc, element_id, matching_column)
      else
        acc
      end
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto">
      <.header>
        Elegir diseño de etiqueta
        <:subtitle>
          Selecciona un diseño existente o crea uno nuevo para tus <%= length(@upload_data) %> registros
        </:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Progress Steps -->
        <div class="mb-8">
          <div class="flex items-center justify-center space-x-4">
            <div class="flex items-center">
              <div class="w-8 h-8 bg-green-600 rounded-full flex items-center justify-center text-white">
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <span class="ml-2 text-sm font-medium text-green-600">Datos cargados</span>
            </div>
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

        <!-- Data Summary -->
        <div class="bg-indigo-50 rounded-xl p-4 mb-8">
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
            disabled={@creating_batch}
            class={"px-8 py-3 rounded-xl font-medium transition flex items-center space-x-2 #{if @creating_batch, do: "bg-gray-400 cursor-not-allowed", else: "bg-indigo-600 hover:bg-indigo-700"} text-white"}
          >
            <%= if @creating_batch do %>
              <svg class="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              <span>Procesando...</span>
            <% else %>
              <span>Usar este diseño</span>
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
              </svg>
            <% end %>
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
