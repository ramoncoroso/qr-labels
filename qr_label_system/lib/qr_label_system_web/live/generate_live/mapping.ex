defmodule QrLabelSystemWeb.GenerateLive.Mapping do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs
  alias QrLabelSystem.DataSources
  alias QrLabelSystem.UploadDataStore

  @impl true
  def mount(%{"design_id" => design_id, "source_id" => source_id}, _session, socket) do
    design = Designs.get_design!(design_id)
    user_id = socket.assigns.current_user.id

    # Security: Verify user owns this design
    if design.user_id != user_id do
      {:ok,
       socket
       |> put_flash(:error, "No tienes permiso para acceder a este diseño")
       |> push_navigate(to: ~p"/designs")}
    else
      mount_authorized(socket, design, source_id, user_id)
    end
  end

  defp mount_authorized(socket, design, source_id, user_id) do
    {data_source, data, columns} =
      if source_id == "upload" do
        # Get data from UploadDataStore (uploaded file) - associated with this design
        {upload_data, upload_columns} = UploadDataStore.get(user_id, design.id)
        {nil, upload_data || [], upload_columns || []}
      else
        # Load from saved data source with ownership verification
        source = DataSources.get_data_source!(source_id)

        # Security: Verify user owns this data source
        if source.user_id != user_id do
          {nil, [], []}
        else
          case DataSources.get_data(source, nil) do
            {:ok, %{headers: cols, rows: rows}} -> {source, rows, cols}
            {:error, _} -> {source, [], []}
          end
        end
      end

    # Get elements that need binding
    bindable_elements =
      (design.elements || [])
      |> Enum.filter(&(&1.type in ["qr", "barcode", "text"]))

    # Initialize mapping from existing bindings
    initial_mapping =
      bindable_elements
      |> Enum.map(fn el -> {el.id, el.binding} end)
      |> Enum.into(%{})

    {:ok,
     socket
     |> assign(:page_title, "Conectar campos")
     |> assign(:design, design)
     |> assign(:data_source, data_source)
     |> assign(:data, data)
     |> assign(:columns, columns)
     |> assign(:bindable_elements, bindable_elements)
     |> assign(:mapping, initial_mapping)
     |> assign(:saving, false)}
  end

  @impl true
  def handle_event("update_mapping", %{"element_id" => element_id, "column" => column}, socket) do
    column = if column == "", do: nil, else: column
    mapping = Map.put(socket.assigns.mapping, element_id, column)
    {:noreply, assign(socket, :mapping, mapping)}
  end

  @impl true
  def handle_event("go_to_editor", _params, socket) do
    socket = assign(socket, :saving, true)
    design = socket.assigns.design

    # Update design element bindings based on mapping
    updated_elements =
      (design.elements || [])
      |> Enum.map(fn el ->
        binding = Map.get(socket.assigns.mapping, el.id)
        if binding do
          Map.put(el, :binding, binding)
        else
          el
        end
      end)

    # Save design with updated bindings
    case Designs.update_design(design, %{elements: updated_elements}) do
      {:ok, _updated_design} ->
        # Data is already in UploadDataStore, redirect to editor
        {:noreply,
         socket
         |> put_flash(:info, "Campos vinculados. Ahora puedes ver la vista previa y generar PDF.")
         |> push_navigate(to: ~p"/designs/#{design.id}/edit")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:saving, false)
         |> put_flash(:error, "Error al guardar los bindings")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Conectar campos
        <:subtitle>Paso 3: Asocia las columnas de tu archivo con los elementos del diseño</:subtitle>
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
              <span class="ml-2 text-sm font-medium text-green-600">Elegir diseño</span>
            </div>
            <div class="w-16 h-0.5 bg-green-600"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-green-600 rounded-full flex items-center justify-center text-white">
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <span class="ml-2 text-sm font-medium text-green-600">Cargar datos</span>
            </div>
            <div class="w-16 h-0.5 bg-indigo-600"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-sm">3</div>
              <span class="ml-2 text-sm font-medium text-indigo-600">Conectar campos</span>
            </div>
            <div class="w-16 h-0.5 bg-gray-300"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">4</div>
              <span class="ml-2 text-sm text-gray-500">Editor / Imprimir</span>
            </div>
          </div>
        </div>

        <!-- Summary -->
        <div class="bg-indigo-50 rounded-lg p-4 mb-8">
          <div class="grid grid-cols-3 gap-4 text-center">
            <div>
              <p class="text-sm text-indigo-600">Diseño</p>
              <p class="font-semibold text-indigo-900"><%= @design.name %></p>
            </div>
            <div>
              <p class="text-sm text-indigo-600">Registros</p>
              <p class="font-semibold text-indigo-900"><%= length(@data) %></p>
            </div>
            <div>
              <p class="text-sm text-indigo-600">Columnas</p>
              <p class="font-semibold text-indigo-900"><%= length(@columns) %></p>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Mapping Form -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Vincular elementos a columnas</h3>

            <%= if length(@bindable_elements) > 0 do %>
              <div class="space-y-4">
                <div :for={element <- @bindable_elements} class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                  <div class="flex items-center space-x-3">
                    <div class="w-10 h-10 bg-indigo-100 rounded-lg flex items-center justify-center">
                      <%= element_icon(element.type) %>
                    </div>
                    <div>
                      <p class="font-medium text-gray-900 capitalize"><%= element.type %></p>
                      <p class="text-xs text-gray-500">
                        Pos: (<%= element.x %>, <%= element.y %>) mm
                      </p>
                    </div>
                  </div>

                  <select
                    phx-change="update_mapping"
                    phx-value-element_id={element.id}
                    name="column"
                    class="rounded-md border-gray-300 text-sm w-40"
                  >
                    <option value="">Sin vincular</option>
                    <%= for col <- @columns do %>
                      <option value={col} selected={Map.get(@mapping, element.id) == col}>
                        <%= col %>
                      </option>
                    <% end %>
                  </select>
                </div>
              </div>
            <% else %>
              <p class="text-gray-500 text-center py-8">
                No hay elementos vinculables en este diseño (QR, código de barras o texto).
              </p>
            <% end %>

            <div class="mt-6 pt-4 border-t">
              <button
                phx-click="go_to_editor"
                disabled={@saving || length(@data) == 0}
                class="w-full bg-indigo-600 text-white px-4 py-3 rounded-lg hover:bg-indigo-700 disabled:opacity-50 font-medium"
              >
                <%= if @saving, do: "Guardando...", else: "Ir al Editor (#{length(@data)} registros)" %>
              </button>
              <p class="text-xs text-gray-500 text-center mt-2">
                Los datos se procesan en memoria y no se guardan en el servidor
              </p>
            </div>
          </div>

          <!-- Data Preview -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Vista previa de datos</h3>

            <%= if length(@data) > 0 do %>
              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 text-sm">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">#</th>
                      <th :for={col <- Enum.take(@columns, 5)} class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase truncate max-w-[100px]">
                        <%= col %>
                      </th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-200">
                    <tr :for={{row, idx} <- Enum.take(@data, 5) |> Enum.with_index(1)}>
                      <td class="px-3 py-2 text-gray-500"><%= idx %></td>
                      <td :for={col <- Enum.take(@columns, 5)} class="px-3 py-2 text-gray-900 truncate max-w-[100px]">
                        <%= Map.get(row, col, "") %>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <p class="mt-4 text-sm text-gray-500">
                Mostrando 5 de <%= length(@data) %> registros
              </p>
            <% else %>
              <p class="text-gray-500 text-center py-8">No hay datos disponibles</p>
            <% end %>
          </div>
        </div>

        <.back navigate={~p"/generate/design/#{@design.id}"}>Volver a selección de datos</.back>
      </div>
    </div>
    """
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
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 17h.01M17 7h.01M17 17h.01M12 7v10M7 7v10m10-10v10" />
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
