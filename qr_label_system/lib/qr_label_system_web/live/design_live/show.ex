defmodule QrLabelSystemWeb.DesignLive.Show do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Designs.Design

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Designs.get_design(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Este diseño ha sido eliminado o no existe")
         |> push_navigate(to: ~p"/designs")}

      design ->
        {:ok,
         socket
         |> assign(:page_title, design.name)
         |> assign(:design, design)}
    end
  end

  @impl true
  def handle_event("download_pdf", _params, socket) do
    {:noreply,
     push_event(socket, "download_single_pdf", %{
       design: Design.to_json(socket.assigns.design),
       quantity: 1
     })}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="design-show-page" phx-hook="SingleLabelPrint">
      <.header>
        <%= @design.name %>
        <:subtitle><%= @design.description || "Sin descripción" %></:subtitle>
        <:actions>
          <.link navigate={~p"/designs/#{@design.id}/edit"}>
            <.button>Editar Diseño</.button>
          </.link>
        </:actions>
      </.header>

      <!-- Action Buttons Panel -->
      <div class="mt-6 bg-white rounded-lg shadow p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Acciones</h3>
        <div class="space-y-3">
          <button
            phx-click="download_pdf"
            class="w-full py-3 rounded-xl font-medium transition flex items-center justify-center space-x-2 bg-indigo-600 text-white hover:bg-indigo-700"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            <span>Descargar PDF</span>
          </button>

          <.link
            navigate={~p"/designs/#{@design.id}/edit"}
            class="w-full py-3 rounded-xl font-medium transition flex items-center justify-center space-x-2 bg-gray-100 text-gray-700 hover:bg-gray-200"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
            </svg>
            <span>Editar en Canvas</span>
          </.link>
        </div>
      </div>

      <div class="mt-8 grid grid-cols-1 lg:grid-cols-2 gap-8">
        <!-- Design Preview -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Vista Previa</h3>
          <div class="flex justify-center items-center bg-gray-100 rounded-lg p-8">
            <div
              class="bg-white shadow-lg relative"
              style={"width: #{min(@design.width_mm * 3.78, 400)}px; height: #{min(@design.height_mm * 3.78, 300)}px; background-color: #{@design.background_color}; border: #{@design.border_width}px solid #{@design.border_color}; border-radius: #{@design.border_radius * 3.78}px;"}
            >
              <div :for={element <- @design.elements || []} class="absolute" style={"left: #{element.x * 3.78}px; top: #{element.y * 3.78}px;"}>
                <%= render_element_preview(element) %>
              </div>
              <div :if={Enum.empty?(@design.elements || [])} class="flex items-center justify-center h-full text-gray-400 text-sm">
                Sin elementos
              </div>
            </div>
          </div>
        </div>

        <!-- Design Properties -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Propiedades</h3>

          <.list>
            <:item title="Dimensiones"><%= @design.width_mm %> × <%= @design.height_mm %> mm</:item>
            <:item title="Color de fondo">
              <div class="flex items-center">
                <div class="w-6 h-6 rounded border mr-2" style={"background-color: #{@design.background_color}"}></div>
                <%= @design.background_color %>
              </div>
            </:item>
            <:item title="Borde"><%= @design.border_width %> mm - <%= @design.border_color %></:item>
            <:item title="Radio del borde"><%= @design.border_radius %> mm</:item>
            <:item title="Es plantilla"><%= if @design.is_template, do: "Sí", else: "No" %></:item>
            <:item title="Elementos"><%= length(@design.elements || []) %></:item>
          </.list>
        </div>
      </div>

      <!-- Elements List -->
      <div class="mt-8 bg-white rounded-lg shadow p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Elementos</h3>

        <div :if={Enum.empty?(@design.elements || [])} class="text-center py-8 text-gray-500">
          No hay elementos en este diseño.
          <.link navigate={~p"/designs/#{@design.id}/edit"} class="text-indigo-600 hover:underline">
            Agregar elementos
          </.link>
        </div>

        <div :if={!Enum.empty?(@design.elements || [])} class="space-y-4">
          <div :for={element <- @design.elements || []} class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
            <div class="flex items-center space-x-4">
              <div class="w-10 h-10 flex items-center justify-center bg-indigo-100 rounded-lg">
                <%= element_icon(element.type) %>
              </div>
              <div>
                <p class="font-medium text-gray-900 capitalize"><%= element.type %></p>
                <p class="text-sm text-gray-500">
                  Posición: (<%= element.x %>, <%= element.y %>) mm
                  <%= if element.binding do %>
                    - Vinculado a: <span class="font-mono text-indigo-600"><%= element.binding %></span>
                  <% end %>
                </p>
              </div>
            </div>
            <div class="text-sm text-gray-500">
              <%= element.width %> × <%= element.height %> mm
            </div>
          </div>
        </div>
      </div>

      <.back navigate={~p"/designs"}>Volver a diseños</.back>
    </div>
    """
  end

  defp render_element_preview(element) do
    case element.type do
      "qr" ->
        Phoenix.HTML.raw("""
        <div class="flex items-center justify-center bg-gray-200 text-xs text-gray-500" style="width: #{element.width * 3.78}px; height: #{element.height * 3.78}px;">
          QR
        </div>
        """)

      "barcode" ->
        Phoenix.HTML.raw("""
        <div class="flex items-center justify-center bg-gray-200 text-xs text-gray-500" style="width: #{element.width * 3.78}px; height: #{element.height * 3.78}px;">
          Barcode
        </div>
        """)

      "text" ->
        Phoenix.HTML.raw("""
        <div class="text-xs truncate" style="width: #{element.width * 3.78}px; font-size: #{(element.font_size || 12) * 0.5}px; color: #{element.color || "#000000"};">
          #{element.text_content || element.binding || "Texto"}
        </div>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <div class="bg-gray-300" style="width: #{element.width * 3.78}px; height: #{element.height * 3.78}px;"></div>
        """)
    end
  end

  defp element_icon("qr") do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z" />
    </svg>
    """)
  end

  defp element_icon("barcode") do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
    </svg>
    """)
  end

  defp element_icon("text") do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16m-7 6h7" />
    </svg>
    """)
  end

  defp element_icon(_) do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6z" />
    </svg>
    """)
  end
end
