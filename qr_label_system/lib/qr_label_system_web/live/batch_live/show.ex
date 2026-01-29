defmodule QrLabelSystemWeb.BatchLive.Show do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Batches
  alias QrLabelSystem.Designs

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    batch = Batches.get_batch!(id)
    design = if batch.design_id, do: Designs.get_design!(batch.design_id), else: nil

    {:ok,
     socket
     |> assign(:page_title, "Lote ##{batch.id}")
     |> assign(:batch, batch)
     |> assign(:design, design)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Lote #<%= @batch.id %>
        <:subtitle>Detalles del lote de etiquetas</:subtitle>
        <:actions>
          <.link navigate={~p"/batches/#{@batch.id}/print"}>
            <.button>Imprimir</.button>
          </.link>
        </:actions>
      </.header>

      <div class="mt-8 grid grid-cols-1 lg:grid-cols-2 gap-8">
        <!-- Batch Info -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Información del Lote</h3>

          <.list>
            <:item title="Estado">
              <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{status_color(@batch.status)}"}>
                <%= status_label(@batch.status) %>
              </span>
            </:item>
            <:item title="Total de etiquetas"><%= @batch.total_labels %></:item>
            <:item title="Etiquetas impresas"><%= @batch.printed_count %></:item>
            <:item title="Diseño"><%= if @design, do: @design.name, else: "N/A" %></:item>
            <:item title="Creado"><%= Calendar.strftime(@batch.inserted_at, "%d/%m/%Y %H:%M") %></:item>
          </.list>
        </div>

        <!-- Column Mapping -->
        <div class="bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Mapeo de Columnas</h3>

          <%= if @batch.column_mapping && map_size(@batch.column_mapping) > 0 do %>
            <div class="space-y-2">
              <div :for={{element_id, column_name} <- @batch.column_mapping} class="flex items-center justify-between py-2 border-b border-gray-100">
                <span class="text-sm font-medium text-gray-900"><%= element_id %></span>
                <span class="text-sm text-gray-500">→</span>
                <span class="text-sm font-mono text-indigo-600"><%= column_name %></span>
              </div>
            </div>
          <% else %>
            <p class="text-gray-500">No hay mapeo de columnas definido</p>
          <% end %>
        </div>
      </div>

      <!-- Data Preview -->
      <div class="mt-8 bg-white rounded-lg shadow p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Vista Previa de Datos</h3>

        <%= if @batch.data_snapshot && length(@batch.data_snapshot) > 0 do %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">#</th>
                  <th :for={col <- get_columns(@batch.data_snapshot)} class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    <%= col %>
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200">
                <tr :for={{row, idx} <- Enum.take(@batch.data_snapshot, 20) |> Enum.with_index(1)}>
                  <td class="px-4 py-3 text-sm text-gray-500"><%= idx %></td>
                  <td :for={col <- get_columns(@batch.data_snapshot)} class="px-4 py-3 text-sm text-gray-900">
                    <%= Map.get(row, col, "") %>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <%= if length(@batch.data_snapshot) > 20 do %>
            <p class="mt-4 text-sm text-gray-500">
              Mostrando 20 de <%= length(@batch.data_snapshot) %> registros
            </p>
          <% end %>
        <% else %>
          <p class="text-gray-500">No hay datos disponibles</p>
        <% end %>
      </div>

      <.back navigate={~p"/batches"}>Volver a lotes</.back>
    </div>
    """
  end

  defp get_columns([first | _]) when is_map(first) do
    Map.keys(first)
  end

  defp get_columns(_), do: []

  defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("ready"), do: "bg-green-100 text-green-800"
  defp status_color("printed"), do: "bg-blue-100 text-blue-800"
  defp status_color("partial"), do: "bg-orange-100 text-orange-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp status_label("pending"), do: "Pendiente"
  defp status_label("ready"), do: "Listo"
  defp status_label("printed"), do: "Impreso"
  defp status_label("partial"), do: "Parcial"
  defp status_label(status), do: status
end
