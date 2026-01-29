defmodule QrLabelSystemWeb.GenerateLive.Index do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs

  @impl true
  def mount(_params, _session, socket) do
    designs = Designs.list_designs(socket.assigns.current_user.id)

    {:ok,
     socket
     |> assign(:page_title, "Generar Etiquetas")
     |> assign(:designs, designs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Generar Etiquetas
        <:subtitle>Paso 1: Selecciona un diseño de etiqueta</:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Progress Steps -->
        <div class="mb-8">
          <div class="flex items-center justify-center space-x-4">
            <div class="flex items-center">
              <div class="w-8 h-8 bg-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-sm">1</div>
              <span class="ml-2 text-sm font-medium text-indigo-600">Diseño</span>
            </div>
            <div class="w-16 h-0.5 bg-gray-300"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">2</div>
              <span class="ml-2 text-sm text-gray-500">Datos</span>
            </div>
            <div class="w-16 h-0.5 bg-gray-300"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">3</div>
              <span class="ml-2 text-sm text-gray-500">Mapeo</span>
            </div>
            <div class="w-16 h-0.5 bg-gray-300"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">4</div>
              <span class="ml-2 text-sm text-gray-500">Generar</span>
            </div>
          </div>
        </div>

        <!-- Design Selection -->
        <div :if={length(@designs) > 0} class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <.link
            :for={design <- @designs}
            navigate={~p"/generate/design/#{design.id}"}
            class="bg-white rounded-lg shadow border-2 border-transparent hover:border-indigo-500 p-6 cursor-pointer transition-all"
          >
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-gray-900"><%= design.name %></h3>
              <svg class="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </div>

            <p class="text-sm text-gray-500 mb-4"><%= design.description || "Sin descripción" %></p>

            <div class="flex items-center justify-between text-sm text-gray-600">
              <span><%= design.width_mm %> × <%= design.height_mm %> mm</span>
              <span><%= length(design.elements || []) %> elementos</span>
            </div>

            <!-- Mini Preview -->
            <div class="mt-4 bg-gray-100 rounded p-2 flex justify-center">
              <div
                class="bg-white shadow-sm"
                style={"width: #{min(design.width_mm * 2, 120)}px; height: #{min(design.height_mm * 2, 80)}px; background-color: #{design.background_color}; border: 1px solid #{design.border_color};"}
              >
              </div>
            </div>
          </.link>
        </div>

        <div :if={length(@designs) == 0} class="text-center py-12">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No hay diseños</h3>
          <p class="mt-1 text-sm text-gray-500">Primero necesitas crear un diseño de etiqueta.</p>
          <div class="mt-6">
            <.link navigate={~p"/designs/new"}>
              <.button>Crear Diseño</.button>
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
