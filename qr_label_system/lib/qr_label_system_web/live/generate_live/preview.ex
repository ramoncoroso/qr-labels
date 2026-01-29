defmodule QrLabelSystemWeb.GenerateLive.Preview do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Batches
  alias QrLabelSystem.Designs

  @impl true
  def mount(%{"batch_id" => batch_id}, _session, socket) do
    batch = Batches.get_batch!(batch_id)
    design = if batch.design_id, do: Designs.get_design!(batch.design_id), else: nil

    {:ok,
     socket
     |> assign(:page_title, "Vista Previa del Lote")
     |> assign(:batch, batch)
     |> assign(:design, design)
     |> assign(:current_preview, 0)
     |> assign(:generating, false)}
  end

  @impl true
  def handle_event("next_preview", _params, socket) do
    max_idx = length(socket.assigns.batch.data_snapshot || []) - 1
    new_idx = min(socket.assigns.current_preview + 1, max_idx)
    {:noreply, assign(socket, :current_preview, new_idx)}
  end

  @impl true
  def handle_event("prev_preview", _params, socket) do
    new_idx = max(socket.assigns.current_preview - 1, 0)
    {:noreply, assign(socket, :current_preview, new_idx)}
  end

  @impl true
  def handle_event("go_to_print", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/batches/#{socket.assigns.batch.id}/print")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Lote Creado Exitosamente
        <:subtitle>Paso 4: Revisa y procede a imprimir</:subtitle>
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
              <span class="ml-2 text-sm font-medium text-green-600">Diseño</span>
            </div>
            <div class="w-16 h-0.5 bg-green-600"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-green-600 rounded-full flex items-center justify-center text-white">
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <span class="ml-2 text-sm font-medium text-green-600">Datos</span>
            </div>
            <div class="w-16 h-0.5 bg-green-600"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-green-600 rounded-full flex items-center justify-center text-white">
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <span class="ml-2 text-sm font-medium text-green-600">Mapeo</span>
            </div>
            <div class="w-16 h-0.5 bg-green-600"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-green-600 rounded-full flex items-center justify-center text-white">
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <span class="ml-2 text-sm font-medium text-green-600">Listo</span>
            </div>
          </div>
        </div>

        <!-- Success Message -->
        <div class="bg-green-50 border border-green-200 rounded-lg p-6 mb-8 text-center">
          <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h3 class="text-xl font-semibold text-green-800">Lote #<%= @batch.id %> creado</h3>
          <p class="text-green-600 mt-2">
            <%= @batch.total_labels %> etiquetas listas para imprimir
          </p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Preview -->
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-medium text-gray-900">Vista Previa de Etiqueta</h3>
              <div class="flex items-center space-x-2">
                <button
                  phx-click="prev_preview"
                  disabled={@current_preview == 0}
                  class="p-2 rounded hover:bg-gray-100 disabled:opacity-50"
                >
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                  </svg>
                </button>
                <span class="text-sm text-gray-600">
                  <%= @current_preview + 1 %> / <%= length(@batch.data_snapshot || []) %>
                </span>
                <button
                  phx-click="next_preview"
                  disabled={@current_preview >= length(@batch.data_snapshot || []) - 1}
                  class="p-2 rounded hover:bg-gray-100 disabled:opacity-50"
                >
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                  </svg>
                </button>
              </div>
            </div>

            <div
              id="label-preview"
              phx-hook="LabelPreview"
              data-design={Jason.encode!(Designs.Design.to_json(@design))}
              data-row={Jason.encode!(Enum.at(@batch.data_snapshot || [], @current_preview, %{}))}
              data-mapping={Jason.encode!(@batch.column_mapping || %{})}
              class="flex justify-center items-center bg-gray-100 rounded-lg p-8 min-h-[300px]"
            >
              <div class="text-gray-500">Cargando vista previa...</div>
            </div>
          </div>

          <!-- Batch Details -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Detalles del Lote</h3>

            <.list>
              <:item title="ID del lote">#<%= @batch.id %></:item>
              <:item title="Diseño"><%= @design.name %></:item>
              <:item title="Dimensiones"><%= @design.width_mm %> × <%= @design.height_mm %> mm</:item>
              <:item title="Total de etiquetas"><%= @batch.total_labels %></:item>
              <:item title="Estado">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                  Listo
                </span>
              </:item>
            </.list>

            <div class="mt-6 pt-4 border-t space-y-3">
              <button
                phx-click="go_to_print"
                class="w-full bg-indigo-600 text-white px-4 py-3 rounded-lg hover:bg-indigo-700 font-medium"
              >
                Ir a Imprimir
              </button>

              <.link
                navigate={~p"/batches"}
                class="block w-full text-center text-gray-600 hover:text-gray-800 px-4 py-2"
              >
                Ver todos los lotes
              </.link>
            </div>
          </div>
        </div>

        <!-- Data Table -->
        <div class="mt-8 bg-white rounded-lg shadow p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Datos del Lote</h3>

          <%= if @batch.data_snapshot && length(@batch.data_snapshot) > 0 do %>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">#</th>
                    <th :for={col <- get_columns(@batch.data_snapshot)} class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                      <%= col %>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200">
                  <tr :for={{row, idx} <- Enum.take(@batch.data_snapshot, 10) |> Enum.with_index(1)}>
                    <td class="px-4 py-3 text-gray-500"><%= idx %></td>
                    <td :for={col <- get_columns(@batch.data_snapshot)} class="px-4 py-3 text-gray-900">
                      <%= Map.get(row, col, "") %>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <%= if length(@batch.data_snapshot) > 10 do %>
              <p class="mt-4 text-sm text-gray-500">
                Mostrando 10 de <%= length(@batch.data_snapshot) %> registros
              </p>
            <% end %>
          <% else %>
            <p class="text-gray-500">No hay datos disponibles</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp get_columns([first | _]) when is_map(first), do: Map.keys(first)
  defp get_columns(_), do: []
end
