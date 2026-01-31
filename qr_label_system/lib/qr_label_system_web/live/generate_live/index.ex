defmodule QrLabelSystemWeb.GenerateLive.Index do
  use QrLabelSystemWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Generar Etiquetas")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <.header>
        Generar Etiquetas
        <:subtitle>
          Selecciona el modo de generación según tus necesidades
        </:subtitle>
      </.header>

      <div class="mt-12">
        <!-- Mode Selection Cards -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <!-- Single Label Mode -->
          <.link
            navigate={~p"/generate/single"}
            class="group relative bg-white rounded-2xl shadow-sm border-2 border-gray-200 hover:border-indigo-500 hover:shadow-lg p-8 cursor-pointer transition-all"
          >
            <div class="absolute top-4 right-4">
              <svg class="w-6 h-6 text-gray-300 group-hover:text-indigo-500 transition" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
              </svg>
            </div>

            <div class="w-16 h-16 bg-blue-100 rounded-2xl flex items-center justify-center mb-6 group-hover:bg-blue-500 transition">
              <svg class="w-8 h-8 text-blue-600 group-hover:text-white transition" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
              </svg>
            </div>

            <h2 class="text-xl font-bold text-gray-900 mb-2 group-hover:text-indigo-600 transition">
              Etiqueta Única
            </h2>
            <p class="text-gray-600 mb-6">
              Imprime una o más copias de una etiqueta con contenido estático. Ideal para etiquetas fijas o pruebas de diseño.
            </p>

            <div class="space-y-2">
              <div class="flex items-center text-sm text-gray-500">
                <svg class="w-4 h-4 mr-2 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                Contenido fijo definido en el diseño
              </div>
              <div class="flex items-center text-sm text-gray-500">
                <svg class="w-4 h-4 mr-2 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                Imprimir múltiples copias iguales
              </div>
              <div class="flex items-center text-sm text-gray-500">
                <svg class="w-4 h-4 mr-2 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                Sin necesidad de archivo de datos
              </div>
            </div>
          </.link>

          <!-- Multiple Labels Mode -->
          <.link
            navigate={~p"/generate/data"}
            class="group relative bg-white rounded-2xl shadow-sm border-2 border-gray-200 hover:border-indigo-500 hover:shadow-lg p-8 cursor-pointer transition-all"
          >
            <div class="absolute top-4 right-4">
              <svg class="w-6 h-6 text-gray-300 group-hover:text-indigo-500 transition" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
              </svg>
            </div>

            <div class="w-16 h-16 bg-purple-100 rounded-2xl flex items-center justify-center mb-6 group-hover:bg-purple-500 transition">
              <svg class="w-8 h-8 text-purple-600 group-hover:text-white transition" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
              </svg>
            </div>

            <h2 class="text-xl font-bold text-gray-900 mb-2 group-hover:text-indigo-600 transition">
              Múltiples Etiquetas
            </h2>
            <p class="text-gray-600 mb-6">
              Genera etiquetas únicas para cada registro de tus datos. Ideal para productos, inventario o envíos.
            </p>

            <div class="space-y-2">
              <div class="flex items-center text-sm text-gray-500">
                <svg class="w-4 h-4 mr-2 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                Cargar datos desde Excel, CSV o pegar
              </div>
              <div class="flex items-center text-sm text-gray-500">
                <svg class="w-4 h-4 mr-2 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                Una etiqueta diferente por cada fila
              </div>
              <div class="flex items-center text-sm text-gray-500">
                <svg class="w-4 h-4 mr-2 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
                Vincular columnas a elementos del diseño
              </div>
            </div>
          </.link>
        </div>

        <!-- How it works section -->
        <div class="mt-12 bg-gray-50 rounded-2xl p-8">
          <h3 class="text-lg font-semibold text-gray-900 mb-6 text-center">¿Cómo funciona?</h3>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
            <!-- Single flow -->
            <div>
              <h4 class="font-medium text-blue-600 mb-4 flex items-center">
                <span class="w-6 h-6 bg-blue-100 rounded-full flex items-center justify-center text-xs font-bold mr-2">1</span>
                Etiqueta Única
              </h4>
              <ol class="space-y-3 text-sm text-gray-600">
                <li class="flex items-start">
                  <span class="w-5 h-5 bg-gray-200 rounded-full flex items-center justify-center text-xs font-medium mr-2 mt-0.5">1</span>
                  <span>Selecciona o crea un diseño</span>
                </li>
                <li class="flex items-start">
                  <span class="w-5 h-5 bg-gray-200 rounded-full flex items-center justify-center text-xs font-medium mr-2 mt-0.5">2</span>
                  <span>Elige la cantidad de copias</span>
                </li>
                <li class="flex items-start">
                  <span class="w-5 h-5 bg-gray-200 rounded-full flex items-center justify-center text-xs font-medium mr-2 mt-0.5">3</span>
                  <span>Imprime o descarga el PDF</span>
                </li>
              </ol>
            </div>

            <!-- Multiple flow -->
            <div>
              <h4 class="font-medium text-purple-600 mb-4 flex items-center">
                <span class="w-6 h-6 bg-purple-100 rounded-full flex items-center justify-center text-xs font-bold mr-2">2</span>
                Múltiples Etiquetas
              </h4>
              <ol class="space-y-3 text-sm text-gray-600">
                <li class="flex items-start">
                  <span class="w-5 h-5 bg-gray-200 rounded-full flex items-center justify-center text-xs font-medium mr-2 mt-0.5">1</span>
                  <span>Carga tus datos (Excel, CSV o pegar)</span>
                </li>
                <li class="flex items-start">
                  <span class="w-5 h-5 bg-gray-200 rounded-full flex items-center justify-center text-xs font-medium mr-2 mt-0.5">2</span>
                  <span>Selecciona un diseño existente o crea uno nuevo</span>
                </li>
                <li class="flex items-start">
                  <span class="w-5 h-5 bg-gray-200 rounded-full flex items-center justify-center text-xs font-medium mr-2 mt-0.5">3</span>
                  <span>El sistema vincula automáticamente las columnas</span>
                </li>
                <li class="flex items-start">
                  <span class="w-5 h-5 bg-gray-200 rounded-full flex items-center justify-center text-xs font-medium mr-2 mt-0.5">4</span>
                  <span>Revisa la vista previa e imprime</span>
                </li>
              </ol>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
