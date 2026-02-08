defmodule QrLabelSystemWeb.GenerateLive.DataSource do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs
  alias QrLabelSystem.DataSources
  alias QrLabelSystem.UploadDataStore
  alias QrLabelSystem.Security.FileSanitizer

  # Maximum file size: 10 MB
  @max_file_size 10 * 1024 * 1024

  @impl true
  def mount(%{"design_id" => design_id}, _session, socket) do
    design = Designs.get_design!(design_id)
    user_id = socket.assigns.current_user.id

    # Security: Verify user owns this design
    if design.user_id != user_id do
      {:ok,
       socket
       |> put_flash(:error, "No tienes permiso para acceder a este diseño")
       |> push_navigate(to: ~p"/designs")}
    else
      data_sources = DataSources.list_user_data_sources(user_id)

      {:ok,
       socket
       |> assign(:page_title, "Seleccionar Datos")
       |> assign(:design, design)
       |> assign(:data_sources, data_sources)
       |> assign(:upload_data, nil)
       |> assign(:upload_columns, [])
       |> assign(:upload_error, nil)
       |> allow_upload(:excel_file,
         accept: ~w(.xlsx .xls .csv),
         max_entries: 1,
         max_file_size: @max_file_size
       )}
    end
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_file", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :excel_file, fn %{path: path}, entry ->
        # Sanitize filename to prevent path traversal attacks
        case FileSanitizer.safe_upload_path(entry.client_name) do
          {:ok, dest} ->
            File.cp!(path, dest)
            {:ok, dest}

          {:error, :path_traversal_detected} ->
            {:error, "Invalid filename detected"}
        end
      end)

    case uploaded_files do
      [{:ok, file_path}] ->
        # Parse the file and clean up after
        result = QrLabelSystem.DataSources.ExcelParser.parse_file(file_path)

        # Cleanup temp file immediately after parsing
        File.rm(file_path)

        case result do
          {:ok, %{headers: headers, rows: rows}} ->
            {:noreply,
             socket
             |> assign(:upload_data, rows)
             |> assign(:upload_columns, headers)
             |> assign(:upload_error, nil)}

          {:error, reason} ->
            {:noreply, assign(socket, :upload_error, reason)}
        end

      [{:error, reason}] ->
        {:noreply, assign(socket, :upload_error, reason)}

      [] ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("use_uploaded_data", _params, socket) do
    if socket.assigns.upload_data do
      user_id = socket.assigns.current_user.id
      design_id = socket.assigns.design.id
      columns = socket.assigns.upload_columns
      rows = socket.assigns.upload_data
      sample_rows = Enum.take(rows, 5)

      # Store lightweight metadata in ETS (columns + sample only, not full dataset)
      UploadDataStore.put_metadata(user_id, design_id, columns, length(rows), sample_rows)

      {:noreply, push_navigate(socket, to: ~p"/generate/map/#{design_id}/upload")}
    else
      {:noreply, put_flash(socket, :error, "No hay datos cargados")}
    end
  end

  @impl true
  def handle_event("select_source", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/generate/map/#{socket.assigns.design.id}/#{id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Cargar datos
        <:subtitle>Paso 2: Sube tu archivo Excel o CSV con la información para las etiquetas</:subtitle>
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
            <div class="w-16 h-0.5 bg-indigo-600"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-sm">2</div>
              <span class="ml-2 text-sm font-medium text-indigo-600">Cargar datos</span>
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

        <!-- Selected Design Info -->
        <div class="bg-indigo-50 rounded-lg p-4 mb-8 flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <div class="w-12 h-12 bg-indigo-100 rounded-lg flex items-center justify-center">
              <svg class="w-6 h-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" />
              </svg>
            </div>
            <div>
              <p class="text-sm text-indigo-600">Diseño seleccionado:</p>
              <p class="font-semibold text-indigo-900"><%= @design.name %></p>
            </div>
          </div>
          <.link navigate={~p"/generate"} class="text-indigo-600 hover:text-indigo-800 text-sm">
            Cambiar
          </.link>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Upload File Option -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Subir archivo Excel/CSV</h3>

            <form phx-submit="upload_file" phx-change="validate_upload">
              <div
                class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-indigo-400 transition-colors"
                phx-drop-target={@uploads.excel_file.ref}
              >
                <.live_file_input upload={@uploads.excel_file} class="hidden" />

                <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                </svg>

                <p class="mt-2 text-sm text-gray-600">
                  Arrastra un archivo aquí o
                  <label class="text-indigo-600 hover:text-indigo-800 cursor-pointer">
                    selecciona uno
                    <.live_file_input upload={@uploads.excel_file} class="sr-only" />
                  </label>
                </p>
                <p class="mt-1 text-xs text-gray-500">Excel (.xlsx, .xls) o CSV</p>
              </div>

              <%= for entry <- @uploads.excel_file.entries do %>
                <div class="mt-4 flex items-center justify-between bg-gray-50 p-3 rounded-lg">
                  <span class="text-sm text-gray-700"><%= entry.client_name %></span>
                  <div class="flex items-center space-x-2">
                    <div class="w-32 bg-gray-200 rounded-full h-2">
                      <div class="bg-indigo-600 h-2 rounded-full" style={"width: #{entry.progress}%"}></div>
                    </div>
                    <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="text-red-500 hover:text-red-700">
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                </div>
              <% end %>

              <%= if length(@uploads.excel_file.entries) > 0 do %>
                <button type="submit" class="mt-4 w-full bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700">
                  Cargar archivo
                </button>
              <% end %>
            </form>

            <%= if @upload_error do %>
              <div class="mt-4 bg-red-50 text-red-700 p-3 rounded-lg text-sm">
                Error: <%= @upload_error %>
              </div>
            <% end %>

            <%= if @upload_data do %>
              <div class="mt-4 bg-green-50 p-4 rounded-lg">
                <p class="text-sm text-green-800 font-medium">
                  Archivo cargado: <%= length(@upload_data) %> registros, <%= length(@upload_columns) %> columnas
                </p>
                <p class="text-xs text-green-600 mt-1">
                  Columnas: <%= Enum.join(@upload_columns, ", ") %>
                </p>
                <button
                  phx-click="use_uploaded_data"
                  class="mt-3 w-full bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 text-sm"
                >
                  Usar estos datos
                </button>
              </div>
            <% end %>
          </div>

          <!-- Existing Data Sources -->
          <div class="bg-white rounded-lg shadow p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Fuentes de datos guardadas</h3>

            <%= if length(@data_sources) > 0 do %>
              <div class="space-y-3">
                <button
                  :for={source <- @data_sources}
                  phx-click="select_source"
                  phx-value-id={source.id}
                  class="w-full flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:border-indigo-500 hover:bg-indigo-50 transition-colors text-left"
                >
                  <div class="flex items-center space-x-3">
                    <div class={"w-10 h-10 rounded-lg flex items-center justify-center #{type_bg_color(source.type)}"}>
                      <%= type_icon(source.type) %>
                    </div>
                    <div>
                      <p class="font-medium text-gray-900"><%= source.name %></p>
                      <p class="text-sm text-gray-500"><%= type_label(source.type) %></p>
                    </div>
                  </div>
                  <svg class="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                  </svg>
                </button>
              </div>
            <% else %>
              <div class="text-center py-8 text-gray-500">
                <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
                </svg>
                <p class="mt-2">No hay datos guardados</p>
                <.link navigate={~p"/data-sources/new"} class="text-indigo-600 hover:underline text-sm">
                  Agregar datos para etiquetas
                </.link>
              </div>
            <% end %>
          </div>
        </div>

        <.back navigate={~p"/generate"}>Volver a selección de diseño</.back>
      </div>
    </div>
    """
  end

  defp type_bg_color("excel"), do: "bg-green-100"
  defp type_bg_color("csv"), do: "bg-blue-100"
  defp type_bg_color("postgresql"), do: "bg-indigo-100"
  defp type_bg_color("mysql"), do: "bg-orange-100"
  defp type_bg_color("sqlserver"), do: "bg-red-100"
  defp type_bg_color(_), do: "bg-gray-100"

  defp type_label("excel"), do: "Excel"
  defp type_label("csv"), do: "CSV"
  defp type_label("postgresql"), do: "PostgreSQL"
  defp type_label("mysql"), do: "MySQL"
  defp type_label("sqlserver"), do: "SQL Server"
  defp type_label(type), do: type

  defp type_icon("excel") do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
    </svg>
    """)
  end

  defp type_icon(_) do
    Phoenix.HTML.raw("""
    <svg class="w-5 h-5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
    </svg>
    """)
  end
end
