defmodule QrLabelSystemWeb.BatchLive.Print do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Batches
  alias QrLabelSystem.Designs

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    batch = Batches.get_batch!(id)
    design = if batch.design_id, do: Designs.get_design!(batch.design_id), else: nil

    {:ok,
     socket
     |> assign(:page_title, "Imprimir Lote ##{batch.id}")
     |> assign(:batch, batch)
     |> assign(:design, design)
     |> assign(:print_config, default_print_config())
     |> assign(:generating, false)}
  end

  @impl true
  def handle_event("update_config", %{"config" => config}, socket) do
    {:noreply, assign(socket, :print_config, Map.merge(socket.assigns.print_config, atomize_keys(config)))}
  end

  @impl true
  def handle_event("generate_labels", _params, socket) do
    socket = assign(socket, :generating, true)

    # Prepare data for client-side generation
    design_json = Designs.Design.to_json(socket.assigns.design)
    data = socket.assigns.batch.data_snapshot || []

    {:noreply,
     socket
     |> push_event("generate_batch", %{
       design: design_json,
       data: data,
       column_mapping: socket.assigns.batch.column_mapping,
       print_config: socket.assigns.print_config
     })}
  end

  @impl true
  def handle_event("generation_complete", _params, socket) do
    {:noreply, assign(socket, :generating, false)}
  end

  @impl true
  def handle_event("print", _params, socket) do
    {:noreply, push_event(socket, "print_labels", %{})}
  end

  @impl true
  def handle_event("export_pdf", _params, socket) do
    {:noreply, push_event(socket, "export_pdf", %{filename: "lote_#{socket.assigns.batch.id}.pdf"})}
  end

  @impl true
  def handle_event("print_recorded", %{"count" => count}, socket) do
    Batches.record_print(socket.assigns.batch, count)
    batch = Batches.get_batch!(socket.assigns.batch.id)

    {:noreply,
     socket
     |> assign(:batch, batch)
     |> put_flash(:info, "Se imprimieron #{count} etiquetas")}
  end

  defp default_print_config do
    %{
      printer_type: "normal",
      page_size: "a4",
      orientation: "portrait",
      margin_top: 10,
      margin_bottom: 10,
      margin_left: 10,
      margin_right: 10,
      columns: 3,
      rows: 7,
      gap_horizontal: 5,
      gap_vertical: 5,
      roll_width: 50,
      label_gap: 3
    }
  end

  defp atomize_keys(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), parse_value(v)}
      {k, v} -> {k, v}
    end)
  rescue
    _ -> map
  end

  defp parse_value(v) when is_binary(v) do
    case Float.parse(v) do
      {num, ""} -> num
      _ -> v
    end
  end

  defp parse_value(v), do: v

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Imprimir Lote #<%= @batch.id %>
        <:subtitle><%= @batch.total_labels %> etiquetas</:subtitle>
      </.header>

      <div class="mt-8 grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- Print Configuration -->
        <div class="lg:col-span-1 space-y-6">
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Tipo de Impresora</h3>

            <div class="space-y-2">
              <label class="flex items-center">
                <input
                  type="radio"
                  name="printer_type"
                  value="normal"
                  checked={@print_config.printer_type == "normal"}
                  phx-click="update_config"
                  phx-value-config_printer_type="normal"
                  class="rounded-full border-gray-300"
                />
                <span class="ml-2 text-sm">Impresora normal (hojas A4/Carta)</span>
              </label>
              <label class="flex items-center">
                <input
                  type="radio"
                  name="printer_type"
                  value="label"
                  checked={@print_config.printer_type == "label"}
                  phx-click="update_config"
                  phx-value-config_printer_type="label"
                  class="rounded-full border-gray-300"
                />
                <span class="ml-2 text-sm">Impresora de etiquetas (rollo)</span>
              </label>
            </div>
          </div>

          <%= if @print_config.printer_type == "normal" do %>
            <div class="bg-white rounded-lg shadow p-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Configuración de Página</h3>

              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700">Tamaño de papel</label>
                  <select
                    phx-change="update_config"
                    name="config[page_size]"
                    class="mt-1 block w-full rounded-md border-gray-300 text-sm"
                  >
                    <option value="a4" selected={@print_config.page_size == "a4"}>A4 (210 × 297 mm)</option>
                    <option value="letter" selected={@print_config.page_size == "letter"}>Carta (216 × 279 mm)</option>
                    <option value="legal" selected={@print_config.page_size == "legal"}>Legal (216 × 356 mm)</option>
                  </select>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700">Orientación</label>
                  <select
                    phx-change="update_config"
                    name="config[orientation]"
                    class="mt-1 block w-full rounded-md border-gray-300 text-sm"
                  >
                    <option value="portrait" selected={@print_config.orientation == "portrait"}>Vertical</option>
                    <option value="landscape" selected={@print_config.orientation == "landscape"}>Horizontal</option>
                  </select>
                </div>

                <div class="grid grid-cols-2 gap-3">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Margen superior (mm)</label>
                    <input
                      type="number"
                      name="config[margin_top]"
                      value={@print_config.margin_top}
                      phx-change="update_config"
                      class="mt-1 block w-full rounded-md border-gray-300 text-sm"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Margen inferior (mm)</label>
                    <input
                      type="number"
                      name="config[margin_bottom]"
                      value={@print_config.margin_bottom}
                      phx-change="update_config"
                      class="mt-1 block w-full rounded-md border-gray-300 text-sm"
                    />
                  </div>
                </div>

                <div class="grid grid-cols-2 gap-3">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Margen izquierdo (mm)</label>
                    <input
                      type="number"
                      name="config[margin_left]"
                      value={@print_config.margin_left}
                      phx-change="update_config"
                      class="mt-1 block w-full rounded-md border-gray-300 text-sm"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Margen derecho (mm)</label>
                    <input
                      type="number"
                      name="config[margin_right]"
                      value={@print_config.margin_right}
                      phx-change="update_config"
                      class="mt-1 block w-full rounded-md border-gray-300 text-sm"
                    />
                  </div>
                </div>

                <div class="grid grid-cols-2 gap-3">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Columnas</label>
                    <input
                      type="number"
                      name="config[columns]"
                      value={@print_config.columns}
                      min="1"
                      phx-change="update_config"
                      class="mt-1 block w-full rounded-md border-gray-300 text-sm"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Filas</label>
                    <input
                      type="number"
                      name="config[rows]"
                      value={@print_config.rows}
                      min="1"
                      phx-change="update_config"
                      class="mt-1 block w-full rounded-md border-gray-300 text-sm"
                    />
                  </div>
                </div>

                <div class="grid grid-cols-2 gap-3">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Espacio horizontal (mm)</label>
                    <input
                      type="number"
                      name="config[gap_horizontal]"
                      value={@print_config.gap_horizontal}
                      phx-change="update_config"
                      class="mt-1 block w-full rounded-md border-gray-300 text-sm"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Espacio vertical (mm)</label>
                    <input
                      type="number"
                      name="config[gap_vertical]"
                      value={@print_config.gap_vertical}
                      phx-change="update_config"
                      class="mt-1 block w-full rounded-md border-gray-300 text-sm"
                    />
                  </div>
                </div>
              </div>
            </div>
          <% else %>
            <div class="bg-white rounded-lg shadow p-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Configuración del Rollo</h3>

              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700">Ancho del rollo (mm)</label>
                  <input
                    type="number"
                    name="config[roll_width]"
                    value={@print_config.roll_width}
                    phx-change="update_config"
                    class="mt-1 block w-full rounded-md border-gray-300 text-sm"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Separación entre etiquetas (mm)</label>
                  <input
                    type="number"
                    name="config[label_gap]"
                    value={@print_config.label_gap}
                    phx-change="update_config"
                    class="mt-1 block w-full rounded-md border-gray-300 text-sm"
                  />
                </div>
              </div>
            </div>
          <% end %>

          <div class="flex space-x-3">
            <button
              phx-click="generate_labels"
              disabled={@generating}
              class="flex-1 bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 disabled:opacity-50"
            >
              <%= if @generating, do: "Generando...", else: "Generar Etiquetas" %>
            </button>
          </div>
        </div>

        <!-- Preview Area -->
        <div class="lg:col-span-2">
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-medium text-gray-900">Vista Previa</h3>
              <div class="flex space-x-2">
                <button
                  phx-click="print"
                  class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 text-sm"
                >
                  Imprimir
                </button>
                <button
                  phx-click="export_pdf"
                  class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 text-sm"
                >
                  Exportar PDF
                </button>
              </div>
            </div>

            <div
              id="print-preview"
              phx-hook="PrintEngine"
              class="bg-gray-100 rounded-lg p-4 min-h-[600px] overflow-auto"
            >
              <div class="text-center text-gray-500 py-12">
                <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
                </svg>
                <p class="mt-2">Haz clic en "Generar Etiquetas" para ver la vista previa</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <.back navigate={~p"/batches"}>Volver a lotes</.back>
    </div>
    """
  end
end
