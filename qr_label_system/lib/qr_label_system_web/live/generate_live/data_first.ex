defmodule QrLabelSystemWeb.GenerateLive.DataFirst do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.DataSources.ExcelParser
  alias QrLabelSystem.Security.FileSanitizer

  # Maximum file size: 10 MB
  @max_file_size 10 * 1024 * 1024

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Cargar Datos")
     |> assign(:active_method, nil)
     |> assign(:upload_data, nil)
     |> assign(:upload_columns, [])
     |> assign(:upload_error, nil)
     |> assign(:pasted_text, "")
     |> assign(:processing, false)
     |> allow_upload(:data_file,
       accept: ~w(.xlsx .xls .csv),
       max_entries: 1,
       max_file_size: @max_file_size
     )}
  end

  @impl true
  def handle_event("select_method", %{"method" => method}, socket) do
    {:noreply,
     socket
     |> assign(:active_method, method)
     |> assign(:upload_data, nil)
     |> assign(:upload_columns, [])
     |> assign(:upload_error, nil)
     |> assign(:pasted_text, "")}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_file", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :data_file, fn %{path: path}, entry ->
        case FileSanitizer.safe_upload_path(entry.client_name) do
          {:ok, dest} ->
            File.cp!(path, dest)
            {:ok, dest}

          {:error, :path_traversal_detected} ->
            {:error, "Nombre de archivo inválido"}
        end
      end)

    case uploaded_files do
      [{:ok, file_path}] ->
        result = ExcelParser.parse_file(file_path)

        # Schedule cleanup
        Task.start(fn ->
          Process.sleep(60_000)
          File.rm(file_path)
        end)

        case result do
          {:ok, %{headers: headers, rows: rows}} ->
            {:noreply,
             socket
             |> assign(:upload_data, rows)
             |> assign(:upload_columns, headers)
             |> assign(:upload_error, nil)}

          {:error, reason} ->
            File.rm(file_path)
            {:noreply, assign(socket, :upload_error, reason)}
        end

      [{:error, reason}] ->
        {:noreply, assign(socket, :upload_error, reason)}

      [] ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_pasted_text", %{"value" => text}, socket) do
    {:noreply, assign(socket, :pasted_text, text)}
  end

  @impl true
  def handle_event("parse_pasted", _params, socket) do
    text = socket.assigns.pasted_text

    case parse_pasted_data(text) do
      {:ok, columns, data} ->
        {:noreply,
         socket
         |> assign(:upload_data, data)
         |> assign(:upload_columns, columns)
         |> assign(:upload_error, nil)}

      {:error, reason} ->
        {:noreply, assign(socket, :upload_error, reason)}
    end
  end

  @impl true
  def handle_event("continue", _params, socket) do
    if socket.assigns.upload_data && length(socket.assigns.upload_data) > 0 do
      {:noreply,
       socket
       |> put_flash(:upload_data, socket.assigns.upload_data)
       |> put_flash(:upload_columns, socket.assigns.upload_columns)
       |> push_navigate(to: ~p"/generate/design")}
    else
      {:noreply, put_flash(socket, :error, "No hay datos cargados")}
    end
  end

  @impl true
  def handle_event("back", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/generate")}
  end

  defp parse_pasted_data(text) when is_binary(text) do
    text = String.trim(text)

    if text == "" do
      {:error, "No hay datos para procesar"}
    else
      lines = String.split(text, ~r/\r?\n/, trim: true)

      case lines do
        [header | rows] when rows != [] ->
          columns = String.split(header, "\t")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(&1 != ""))

          if length(columns) == 0 do
            {:error, "No se detectaron columnas. Asegúrate de copiar datos con encabezados separados por tabuladores."}
          else
            data = Enum.map(rows, fn row ->
              values = String.split(row, "\t")
              |> Enum.map(&String.trim/1)

              columns
              |> Enum.with_index()
              |> Enum.reduce(%{}, fn {col, idx}, acc ->
                value = Enum.at(values, idx, "")
                Map.put(acc, col, value)
              end)
            end)

            {:ok, columns, data}
          end

        [_header] ->
          {:error, "Solo se detectó una fila. Asegúrate de incluir datos además de los encabezados."}

        [] ->
          {:error, "No hay datos para procesar"}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <.header>
        Cargar datos para etiquetas
        <:subtitle>
          Selecciona cómo quieres cargar tus datos. Cada fila generará una etiqueta diferente.
        </:subtitle>
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
              <span class="ml-2 text-sm font-medium text-green-600">Modo múltiple</span>
            </div>
            <div class="w-16 h-0.5 bg-indigo-600"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-sm">1</div>
              <span class="ml-2 text-sm font-medium text-indigo-600">Cargar datos</span>
            </div>
            <div class="w-16 h-0.5 bg-gray-300"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">2</div>
              <span class="ml-2 text-sm text-gray-500">Elegir diseño</span>
            </div>
            <div class="w-16 h-0.5 bg-gray-300"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">3</div>
              <span class="ml-2 text-sm text-gray-500">Imprimir</span>
            </div>
          </div>
        </div>

        <!-- Method Selection Cards -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <button
            phx-click="select_method"
            phx-value-method="excel"
            class={"rounded-xl p-6 text-left transition-all border-2 #{if @active_method == "excel", do: "border-green-500 bg-green-50 ring-2 ring-green-200", else: "border-gray-200 bg-white hover:border-green-300 hover:bg-green-50/50"}"}
          >
            <div class="flex items-center space-x-4">
              <div class={"w-14 h-14 rounded-xl flex items-center justify-center #{if @active_method == "excel", do: "bg-green-500", else: "bg-green-100"}"}>
                <svg class={"w-7 h-7 #{if @active_method == "excel", do: "text-white", else: "text-green-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
              </div>
              <div>
                <h3 class={"font-semibold #{if @active_method == "excel", do: "text-green-900", else: "text-gray-900"}"}>Excel</h3>
                <p class={"text-sm #{if @active_method == "excel", do: "text-green-700", else: "text-gray-500"}"}>Archivo .xlsx</p>
              </div>
            </div>
          </button>

          <button
            phx-click="select_method"
            phx-value-method="csv"
            class={"rounded-xl p-6 text-left transition-all border-2 #{if @active_method == "csv", do: "border-blue-500 bg-blue-50 ring-2 ring-blue-200", else: "border-gray-200 bg-white hover:border-blue-300 hover:bg-blue-50/50"}"}
          >
            <div class="flex items-center space-x-4">
              <div class={"w-14 h-14 rounded-xl flex items-center justify-center #{if @active_method == "csv", do: "bg-blue-500", else: "bg-blue-100"}"}>
                <svg class={"w-7 h-7 #{if @active_method == "csv", do: "text-white", else: "text-blue-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
              </div>
              <div>
                <h3 class={"font-semibold #{if @active_method == "csv", do: "text-blue-900", else: "text-gray-900"}"}>CSV</h3>
                <p class={"text-sm #{if @active_method == "csv", do: "text-blue-700", else: "text-gray-500"}"}>Archivo .csv</p>
              </div>
            </div>
          </button>

          <button
            phx-click="select_method"
            phx-value-method="paste"
            class={"rounded-xl p-6 text-left transition-all border-2 #{if @active_method == "paste", do: "border-purple-500 bg-purple-50 ring-2 ring-purple-200", else: "border-gray-200 bg-white hover:border-purple-300 hover:bg-purple-50/50"}"}
          >
            <div class="flex items-center space-x-4">
              <div class={"w-14 h-14 rounded-xl flex items-center justify-center #{if @active_method == "paste", do: "bg-purple-500", else: "bg-purple-100"}"}>
                <svg class={"w-7 h-7 #{if @active_method == "paste", do: "text-white", else: "text-purple-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                </svg>
              </div>
              <div>
                <h3 class={"font-semibold #{if @active_method == "paste", do: "text-purple-900", else: "text-gray-900"}"}>Pegar datos</h3>
                <p class={"text-sm #{if @active_method == "paste", do: "text-purple-700", else: "text-gray-500"}"}>Copiar desde Excel</p>
              </div>
            </div>
          </button>
        </div>

        <!-- Upload Area (Excel/CSV) -->
        <div :if={@active_method in ["excel", "csv"]} class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">
            Subir archivo <%= if @active_method == "excel", do: "Excel", else: "CSV" %>
          </h3>

          <form phx-submit="upload_file" phx-change="validate_upload">
            <div
              class="border-2 border-dashed border-gray-300 rounded-xl p-12 text-center hover:border-indigo-400 transition-colors cursor-pointer"
              phx-drop-target={@uploads.data_file.ref}
            >
              <.live_file_input upload={@uploads.data_file} class="hidden" />

              <svg class="mx-auto h-16 w-16 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
              </svg>

              <p class="mt-4 text-base text-gray-600">
                Arrastra tu archivo aquí o
                <label class="text-indigo-600 hover:text-indigo-800 cursor-pointer font-medium">
                  selecciona uno
                  <.live_file_input upload={@uploads.data_file} class="sr-only" />
                </label>
              </p>
              <p class="mt-2 text-sm text-gray-500">
                <%= if @active_method == "excel", do: "Excel (.xlsx, .xls)", else: "CSV (.csv)" %> hasta 10MB
              </p>
            </div>

            <%= for entry <- @uploads.data_file.entries do %>
              <div class="mt-4 flex items-center justify-between bg-gray-50 p-4 rounded-xl">
                <div class="flex items-center space-x-3">
                  <div class="w-10 h-10 bg-indigo-100 rounded-lg flex items-center justify-center">
                    <svg class="w-5 h-5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                    </svg>
                  </div>
                  <span class="text-sm font-medium text-gray-700"><%= entry.client_name %></span>
                </div>
                <div class="flex items-center space-x-3">
                  <div class="w-32 bg-gray-200 rounded-full h-2">
                    <div class="bg-indigo-600 h-2 rounded-full transition-all" style={"width: #{entry.progress}%"}></div>
                  </div>
                  <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="text-gray-400 hover:text-red-500">
                    <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              </div>
            <% end %>

            <%= if length(@uploads.data_file.entries) > 0 do %>
              <button type="submit" class="mt-4 w-full bg-indigo-600 text-white px-6 py-3 rounded-xl hover:bg-indigo-700 font-medium transition">
                Procesar archivo
              </button>
            <% end %>
          </form>
        </div>

        <!-- Paste Area -->
        <div :if={@active_method == "paste"} class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-2">Pegar datos desde Excel</h3>
          <p class="text-sm text-gray-600 mb-4">
            Copia las celdas en Excel (incluyendo los encabezados) y pégalas aquí. Los datos deben estar separados por tabuladores.
          </p>

          <form phx-submit="parse_pasted">
            <textarea
              name="value"
              phx-change="update_pasted_text"
              phx-debounce="100"
              rows="10"
              placeholder={"Producto\tSKU\tPrecio\nWidget A\tSKU-001\t10.00\nWidget B\tSKU-002\t15.00"}
              class="w-full rounded-xl border-gray-300 shadow-sm font-mono text-sm placeholder:text-gray-400"
            ><%= @pasted_text %></textarea>

            <button
              type="submit"
              disabled={@pasted_text == ""}
              class={"mt-4 w-full px-6 py-3 rounded-xl font-medium transition #{if @pasted_text == "", do: "bg-gray-200 text-gray-400 cursor-not-allowed", else: "bg-purple-600 text-white hover:bg-purple-700"}"}
            >
              Procesar datos
            </button>
          </form>
        </div>

        <!-- Error Message -->
        <%= if @upload_error do %>
          <div class="mt-6 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl flex items-center space-x-3">
            <svg class="w-5 h-5 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <span><%= @upload_error %></span>
          </div>
        <% end %>

        <!-- Data Preview -->
        <%= if @upload_data && length(@upload_data) > 0 do %>
          <div class="mt-8 bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
            <div class="px-6 py-4 bg-green-50 border-b border-green-100 flex items-center justify-between">
              <div class="flex items-center space-x-3">
                <div class="w-10 h-10 bg-green-500 rounded-full flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                </div>
                <div>
                  <p class="font-semibold text-green-900">Datos cargados correctamente</p>
                  <p class="text-sm text-green-700">
                    <%= length(@upload_data) %> registros, <%= length(@upload_columns) %> columnas
                  </p>
                </div>
              </div>
            </div>

            <div class="p-6">
              <h4 class="text-sm font-medium text-gray-700 mb-3">Columnas detectadas:</h4>
              <div class="flex flex-wrap gap-2 mb-6">
                <%= for col <- @upload_columns do %>
                  <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-indigo-100 text-indigo-800">
                    <%= col %>
                  </span>
                <% end %>
              </div>

              <h4 class="text-sm font-medium text-gray-700 mb-3">Vista previa (primeras 5 filas):</h4>
              <div class="overflow-x-auto rounded-lg border border-gray-200">
                <table class="min-w-full divide-y divide-gray-200">
                  <thead class="bg-gray-50">
                    <tr>
                      <%= for col <- @upload_columns do %>
                        <th class="px-4 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">
                          <%= col %>
                        </th>
                      <% end %>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-100">
                    <%= for row <- Enum.take(@upload_data, 5) do %>
                      <tr class="hover:bg-gray-50">
                        <%= for col <- @upload_columns do %>
                          <td class="px-4 py-3 text-sm text-gray-700 font-mono">
                            <%= Map.get(row, col, "") %>
                          </td>
                        <% end %>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <%= if length(@upload_data) > 5 do %>
                <p class="mt-3 text-sm text-gray-500 text-center">
                  ...y <%= length(@upload_data) - 5 %> filas más
                </p>
              <% end %>
            </div>
          </div>

          <!-- Continue Button -->
          <div class="mt-8 flex justify-between items-center">
            <button
              phx-click="back"
              class="px-6 py-3 rounded-xl border border-gray-300 text-gray-700 hover:bg-gray-50 font-medium transition"
            >
              Volver
            </button>
            <button
              phx-click="continue"
              class="px-8 py-3 rounded-xl bg-indigo-600 text-white hover:bg-indigo-700 font-medium transition flex items-center space-x-2"
            >
              <span>Continuar</span>
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
              </svg>
            </button>
          </div>
        <% end %>

        <!-- Back link when no data -->
        <div :if={!@upload_data || length(@upload_data) == 0} class="mt-8">
          <.back navigate={~p"/generate"}>Volver a selección de modo</.back>
        </div>
      </div>
    </div>
    """
  end
end
