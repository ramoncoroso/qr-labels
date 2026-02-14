defmodule QrLabelSystemWeb.DataSourceLive.Show do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.DataSources

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    data_source = DataSources.get_data_source!(id)

    if data_source.workspace_id != socket.assigns.current_workspace.id do
      {:ok,
       socket
       |> put_flash(:error, "No tienes permiso para ver esta fuente de datos")
       |> push_navigate(to: ~p"/data-sources")}
    else
      {:ok,
       socket
       |> assign(:page_title, data_source.name)
       |> assign(:data_source, data_source)
       |> assign(:preview_data, nil)
       |> assign(:columns, [])
       |> assign(:loading, false)
       |> assign(:error, nil)}
    end
  end

  @impl true
  def handle_event("load_preview", _params, socket) do
    socket = assign(socket, :loading, true)

    case DataSources.get_data_from_source(socket.assigns.data_source, limit: 10) do
      {:ok, %{columns: columns, rows: rows}} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:columns, columns)
         |> assign(:preview_data, rows)
         |> assign(:error, nil)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, reason)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @data_source.name %>
        <:subtitle>Vista previa de los datos</:subtitle>
        <:actions>
          <.link navigate={~p"/data-sources/#{@data_source.id}/edit"}>
            <.button>Editar</.button>
          </.link>
        </:actions>
      </.header>

      <div class="mt-8">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-medium text-gray-900">Vista Previa de Datos</h3>
            <button
              phx-click="load_preview"
              class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 text-sm"
              disabled={@loading}
            >
              <%= if @loading, do: "Cargando...", else: "Cargar datos" %>
            </button>
          </div>

          <%= if @error do %>
            <div class="bg-red-50 text-red-700 p-4 rounded-lg mb-4">
              Error: <%= @error %>
            </div>
          <% end %>

          <%= if @preview_data do %>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th :for={col <- @columns} class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      <%= col %>
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <tr :for={row <- @preview_data}>
                    <td :for={col <- @columns} class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <%= Map.get(row, col, "") %>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p class="mt-4 text-sm text-gray-500">
              Mostrando hasta 10 registros de vista previa
            </p>
          <% else %>
            <div class="text-center py-12 text-gray-500">
              <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
              </svg>
              <p class="mt-2">Haz clic en "Cargar datos" para ver una vista previa</p>
            </div>
          <% end %>
        </div>
      </div>

      <.back navigate={~p"/data-sources"}>Volver a datos para etiquetas</.back>
    </div>
    """
  end
end
