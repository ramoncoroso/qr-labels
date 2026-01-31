defmodule QrLabelSystemWeb.GenerateLive.SingleSelect do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs

  @impl true
  def mount(_params, _session, socket) do
    designs = Designs.list_user_designs_by_type(socket.assigns.current_user.id, "single")

    {:ok,
     socket
     |> assign(:page_title, "Etiqueta Única")
     |> assign(:designs, designs)}
  end

  @impl true
  def handle_event("select_design", %{"id" => design_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/generate/single/#{design_id}")}
  end

  @impl true
  def handle_event("create_new", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:return_to, "single_select")
     |> push_navigate(to: ~p"/designs/new?type=single")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto">
      <.header>
        Etiqueta Única
        <:subtitle>
          Selecciona un diseño para imprimir una etiqueta con contenido estático
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
              <span class="ml-2 text-sm font-medium text-green-600">Modo único</span>
            </div>
            <div class="w-16 h-0.5 bg-indigo-600"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-sm">1</div>
              <span class="ml-2 text-sm font-medium text-indigo-600">Elegir diseño</span>
            </div>
            <div class="w-16 h-0.5 bg-gray-300"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">2</div>
              <span class="ml-2 text-sm text-gray-500">Imprimir</span>
            </div>
          </div>
        </div>

        <!-- Info Box -->
        <div class="bg-blue-50 border border-blue-200 rounded-xl p-4 mb-8">
          <div class="flex items-start space-x-3">
            <svg class="w-5 h-5 text-blue-500 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div class="text-sm text-blue-800">
              <p class="font-medium mb-1">Modo etiqueta única</p>
              <p>En este modo, el contenido de la etiqueta será estático. Los textos, códigos QR y códigos de barras usarán el contenido definido en el diseño, sin vinculación a datos externos.</p>
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
              class="bg-white rounded-xl shadow-sm border-2 border-transparent hover:border-indigo-500 p-6 cursor-pointer transition-all text-left"
            >
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-lg font-semibold text-gray-900 truncate"><%= design.name %></h3>
                <svg class="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                </svg>
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
            </button>
          <% end %>
        </div>

        <%= if length(@designs) == 0 do %>
          <div class="mt-4 text-center py-8 bg-gray-50 rounded-xl">
            <p class="text-gray-500">Aún no tienes diseños. Crea tu primer diseño para continuar.</p>
          </div>
        <% end %>

        <!-- Back button -->
        <div class="mt-8">
          <.link
            navigate={~p"/generate"}
            class="inline-flex items-center space-x-2 px-5 py-2.5 rounded-xl border-2 border-gray-300 text-gray-700 hover:bg-gray-100 hover:border-gray-400 font-medium transition"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            <span>Volver a selección de modo</span>
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
