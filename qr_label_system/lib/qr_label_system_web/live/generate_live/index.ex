defmodule QrLabelSystemWeb.GenerateLive.Index do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs

  @impl true
  def mount(_params, _session, socket) do
    designs = Designs.list_user_designs(socket.assigns.current_user.id)

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
        <:subtitle>
          Selecciona un diseño de etiqueta para comenzar. Después podrás cargar tus datos (Excel/CSV) y generar etiquetas únicas para cada registro.
        </:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Progress Steps -->
        <div class="mb-8">
          <div class="flex items-center justify-center space-x-4">
            <div class="flex items-center">
              <div class="w-8 h-8 bg-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-sm">1</div>
              <span class="ml-2 text-sm font-medium text-indigo-600">Elegir diseño</span>
            </div>
            <div class="w-16 h-0.5 bg-gray-300"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">2</div>
              <span class="ml-2 text-sm text-gray-500">Cargar datos</span>
            </div>
            <div class="w-16 h-0.5 bg-gray-300"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">3</div>
              <span class="ml-2 text-sm text-gray-500">Conectar campos</span>
            </div>
            <div class="w-16 h-0.5 bg-gray-300"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">4</div>
              <span class="ml-2 text-sm text-gray-500">Imprimir</span>
            </div>
          </div>
        </div>

        <!-- How it works -->
        <div class="mb-8 bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h4 class="font-medium text-blue-900 mb-2">¿Cómo funciona?</h4>
          <ol class="text-sm text-blue-800 space-y-2 list-decimal list-inside">
            <li><strong>Elegir diseño:</strong> Selecciona la plantilla de etiqueta que usarás. Puedes crear diseños con códigos QR, textos, imágenes y códigos de barras.</li>
            <li><strong>Cargar datos:</strong> Sube un archivo Excel (.xlsx) o CSV con la información. Cada fila será una etiqueta diferente.</li>
            <li><strong>Conectar campos:</strong> Asocia las columnas de tu archivo (ej: "Producto", "Precio") con los elementos del diseño.</li>
            <li><strong>Imprimir:</strong> Revisa la vista previa de cada etiqueta y genera el PDF listo para imprimir.</li>
          </ol>
        </div>

        <!-- Design Selection -->
        <h3 class="text-lg font-medium text-gray-900 mb-4">Tus diseños de etiquetas</h3>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <!-- Create New Design Card -->
          <.link
            navigate={~p"/designs/new"}
            class="bg-slate-50 rounded-lg border-2 border-dashed border-slate-300 hover:border-indigo-500 hover:bg-indigo-50 p-6 cursor-pointer transition-all flex flex-col items-center justify-center min-h-[200px]"
          >
            <div class="w-12 h-12 bg-slate-200 rounded-full flex items-center justify-center mb-4">
              <svg class="w-6 h-6 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-slate-600">Nuevo Diseño</h3>
            <p class="text-sm text-slate-500 text-center mt-1">Crea una nueva plantilla de etiqueta</p>
          </.link>

          <!-- Existing Designs -->
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

        <div :if={length(@designs) == 0} class="mt-4 text-center py-8 bg-gray-50 rounded-lg">
          <p class="text-gray-500">Aún no tienes diseños. Crea tu primer diseño para comenzar a generar etiquetas.</p>
        </div>
      </div>
    </div>
    """
  end
end
