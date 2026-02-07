defmodule QrLabelSystemWeb.GenerateLive.DataFirst do
  use QrLabelSystemWeb, :live_view

  require Logger

  alias QrLabelSystem.DataSources.ExcelParser
  alias QrLabelSystem.Security.FileSanitizer
  alias QrLabelSystem.Designs

  # Maximum file size: 10 MB
  @max_file_size 10 * 1024 * 1024

  @impl true
  def mount(params, _session, socket) do
    # Check if we're loading data for a specific design
    design_id = Map.get(params, "design_id")
    element_id = Map.get(params, "element_id")
    user_id = socket.assigns.current_user.id

    # Validate design ownership if design_id is provided
    case validate_design(design_id, user_id) do
      {:ok, design} ->
        mount_with_design(socket, design, element_id)

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "El diseño no existe")
         |> push_navigate(to: ~p"/designs")}

      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, "No tienes permiso para editar este diseño")
         |> push_navigate(to: ~p"/designs")}

      :no_design ->
        mount_without_design(socket)
    end
  end

  defp validate_design(nil, _user_id), do: :no_design
  defp validate_design(design_id, user_id) do
    case Designs.get_design(design_id) do
      nil -> {:error, :not_found}
      design when design.user_id != user_id -> {:error, :unauthorized}
      design -> {:ok, design}
    end
  end

  defp mount_with_design(socket, design, element_id) do
    {:ok,
     socket
     |> assign(:page_title, "Cargar Datos - #{design.name}")
     |> assign(:design_id, design.id)
     |> assign(:design_name, design.name)
     |> assign(:element_id, element_id)
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

  defp mount_without_design(socket) do
    {:ok,
     socket
     |> assign(:page_title, "Cargar Datos")
     |> assign(:design_id, nil)
     |> assign(:design_name, nil)
     |> assign(:element_id, nil)
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
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :data_file, ref)}
  end

  @impl true
  def handle_event("upload_file", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :data_file, fn %{path: path}, entry ->
        case FileSanitizer.safe_upload_path(entry.client_name) do
          {:ok, dest} ->
            File.cp!(path, dest)
            {:ok, {:ok, dest}}

          {:error, :path_traversal_detected} ->
            {:ok, {:error, "Nombre de archivo inválido"}}
        end
      end)

    case uploaded_files do
      [{:ok, file_path}] ->
        Logger.debug("Upload file path: #{file_path}, extension: #{Path.extname(file_path)}")
        result = ExcelParser.parse_file(file_path)
        Logger.debug("Parse result keys: #{inspect(if match?({:ok, _}, result), do: :ok, else: result)}")

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
             |> assign(:upload_error, nil)
             |> push_event("scroll_to", %{id: "data-preview"})}

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
         |> assign(:upload_error, nil)
         |> push_event("scroll_to", %{id: "data-preview"})}

      {:error, reason} ->
        {:noreply, assign(socket, :upload_error, reason)}
    end
  end

  @impl true
  def handle_event("continue", _params, socket) do
    if socket.assigns.upload_data && length(socket.assigns.upload_data) > 0 do
      # Store data in persistent store for the workflow
      user_id = socket.assigns.current_user.id
      design_id = socket.assigns.design_id

      Logger.info("DataFirst continue - Storing #{length(socket.assigns.upload_data)} rows, #{length(socket.assigns.upload_columns)} columns for user=#{user_id}, design=#{inspect(design_id)}")

      QrLabelSystem.UploadDataStore.put(
        user_id,
        design_id,
        socket.assigns.upload_data,
        socket.assigns.upload_columns
      )

      # Navigate based on whether we have a design_id
      if design_id do
        # Coming from editor, go back with element_id if present
        element_id = socket.assigns.element_id
        redirect_url = if element_id do
          ~p"/designs/#{design_id}/edit?element_id=#{element_id}"
        else
          ~p"/designs/#{design_id}/edit"
        end
        {:noreply, push_navigate(socket, to: redirect_url)}
      else
        # Data-first flow, go to design selection
        {:noreply, push_navigate(socket, to: ~p"/generate/design")}
      end
    else
      {:noreply, put_flash(socket, :error, "No hay datos cargados")}
    end
  end

  @impl true
  def handle_event("continue_no_data", _params, socket) do
    # Clear any existing data for this user
    user_id = socket.assigns.current_user.id
    QrLabelSystem.UploadDataStore.clear(user_id)

    # Navigate to design selection with no_data flag
    {:noreply, push_navigate(socket, to: ~p"/generate/design?no_data=true")}
  end

  @impl true
  def handle_event("back", _params, socket) do
    if socket.assigns.design_id do
      {:noreply, push_navigate(socket, to: ~p"/designs")}
    else
      {:noreply, push_navigate(socket, to: ~p"/generate")}
    end
  end

  defp parse_pasted_data(text) when is_binary(text) do
    text = String.trim(text)

    if text == "" do
      {:error, "No hay datos para procesar"}
    else
      lines = String.split(text, ~r/\r?\n/, trim: true)

      case lines do
        [header | rows] when rows != [] ->
          # Auto-detect separator: tab, semicolon, comma, or multiple spaces
          separator = detect_separator(header)

          columns = String.split(header, separator)
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(&1 != ""))

          if length(columns) == 0 do
            {:error, "No se detectaron columnas. Asegúrate de que los encabezados estén separados por tabuladores, comas o punto y coma."}
          else
            data = Enum.map(rows, fn row ->
              values = String.split(row, separator)
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

  # Detect the best separator for pasted data
  defp detect_separator(header) do
    cond do
      String.contains?(header, "\t") -> "\t"
      String.contains?(header, ";") -> ";"
      String.contains?(header, ",") -> ","
      String.match?(header, ~r/\s{2,}/) -> ~r/\s{2,}/
      String.contains?(header, " ") -> ~r/\s+/
      true -> "\t"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="data-first-page" class="max-w-4xl mx-auto" phx-hook="ScrollTo">
      <.header>
        <%= if @design_name do %>
          Cargar datos para "<%= @design_name %>"
        <% else %>
          Cargar datos para etiquetas
        <% end %>
        <:subtitle>
          Selecciona cómo quieres cargar tus datos. Cada fila generará una etiqueta diferente.
        </:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Progress Steps -->
        <div class="mb-8">
          <div class="flex items-center justify-center space-x-4">
            <%= if @design_id do %>
              <!-- Flow: Coming from /designs -->
              <div class="flex items-center">
                <div class="w-8 h-8 bg-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-sm">1</div>
                <span class="ml-2 text-sm font-medium text-indigo-600">Cargar datos</span>
              </div>
              <div class="w-16 h-0.5 bg-gray-300"></div>
              <div class="flex items-center">
                <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">2</div>
                <span class="ml-2 text-sm text-gray-500">Editar diseño</span>
              </div>
              <div class="w-16 h-0.5 bg-gray-300"></div>
              <div class="flex items-center">
                <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">3</div>
                <span class="ml-2 text-sm text-gray-500">Imprimir</span>
              </div>
            <% else %>
              <!-- Flow: Data-first -->
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
            <% end %>
          </div>
        </div>

        <!-- Method Selection Cards -->
        <div class={"grid grid-cols-1 gap-6 mb-8 #{if @design_id, do: "md:grid-cols-2", else: "md:grid-cols-3"}"}>
          <button
            phx-click="select_method"
            phx-value-method="file"
            class={"rounded-xl p-6 text-left transition-all border-2 #{if @active_method == "file", do: "border-indigo-500 bg-indigo-50 ring-2 ring-indigo-200", else: "border-gray-200 bg-white hover:border-indigo-300 hover:bg-indigo-50/50"}"}
          >
            <div class="flex items-center space-x-4">
              <div class={"w-14 h-14 rounded-xl flex items-center justify-center #{if @active_method == "file", do: "bg-indigo-500", else: "bg-indigo-100"}"}>
                <svg class={"w-7 h-7 #{if @active_method == "file", do: "text-white", else: "text-indigo-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                </svg>
              </div>
              <div>
                <h3 class={"font-semibold #{if @active_method == "file", do: "text-indigo-900", else: "text-gray-900"}"}>Importar archivo</h3>
                <p class={"text-sm #{if @active_method == "file", do: "text-indigo-700", else: "text-gray-500"}"}>Excel (.xlsx) o CSV (.csv)</p>
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

          <!-- Solo mostrar "Diseñar sin datos" cuando NO hay design_id (flujo nuevo) -->
          <button
            :if={is_nil(@design_id)}
            phx-click="select_method"
            phx-value-method="no_data"
            class={"rounded-xl p-6 text-left transition-all border-2 #{if @active_method == "no_data", do: "border-amber-500 bg-amber-50 ring-2 ring-amber-200", else: "border-gray-200 bg-white hover:border-amber-300 hover:bg-amber-50/50"}"}
          >
            <div class="flex items-center space-x-4">
              <div class={"w-14 h-14 rounded-xl flex items-center justify-center #{if @active_method == "no_data", do: "bg-amber-500", else: "bg-amber-100"}"}>
                <svg class={"w-7 h-7 #{if @active_method == "no_data", do: "text-white", else: "text-amber-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
              </div>
              <div>
                <h3 class={"font-semibold #{if @active_method == "no_data", do: "text-amber-900", else: "text-gray-900"}"}>Diseñar sin datos</h3>
                <p class={"text-sm #{if @active_method == "no_data", do: "text-amber-700", else: "text-gray-500"}"}>Solo texto fijo</p>
              </div>
            </div>
          </button>
        </div>

        <!-- Upload Area (Excel/CSV) -->
        <div :if={@active_method == "file"} class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">
            Subir archivo Excel o CSV
          </h3>

          <form phx-submit="upload_file" phx-change="validate_upload">
            <.live_file_input upload={@uploads.data_file} class="sr-only" />
            <%= if length(@uploads.data_file.entries) == 0 do %>
              <!-- Drop zone: only visible when no file is selected -->
              <label
                for={@uploads.data_file.ref}
                class="block border-2 border-dashed border-gray-300 rounded-xl p-12 text-center hover:border-indigo-400 transition-colors cursor-pointer"
                phx-drop-target={@uploads.data_file.ref}
              >
                <svg class="mx-auto h-16 w-16 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                </svg>

                <p class="mt-4 text-base text-gray-600">
                  Arrastra tu archivo aquí o
                  <span class="text-indigo-600 hover:text-indigo-800 font-medium">
                    selecciona uno
                  </span>
                </p>
                <p class="mt-2 text-sm text-gray-500">
                  Excel (.xlsx) o CSV (.csv) hasta 10MB
                </p>
              </label>
            <% else %>
              <!-- File selected: show file info + process button -->
              <%= for entry <- @uploads.data_file.entries do %>
                <div class="flex items-center justify-between bg-indigo-50 border border-indigo-200 p-4 rounded-xl">
                  <div class="flex items-center space-x-3">
                    <div class="w-10 h-10 bg-indigo-100 rounded-lg flex items-center justify-center">
                      <svg class="w-5 h-5 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                      </svg>
                    </div>
                    <div>
                      <span class="text-sm font-medium text-gray-900"><%= entry.client_name %></span>
                      <div class="w-40 bg-gray-200 rounded-full h-1.5 mt-1">
                        <div class="bg-indigo-600 h-1.5 rounded-full transition-all" style={"width: #{entry.progress}%"}></div>
                      </div>
                    </div>
                  </div>
                  <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} class="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition">
                    <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                </div>
              <% end %>

              <button type="submit" class="mt-4 w-full bg-indigo-600 text-white px-6 py-3 rounded-xl hover:bg-indigo-700 font-medium transition">
                Procesar archivo
              </button>
            <% end %>
          </form>
        </div>

        <!-- No Data Area -->
        <div :if={@active_method == "no_data"} class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div class="text-center py-6">
            <div class="w-16 h-16 bg-amber-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg class="w-8 h-8 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-gray-900 mb-2">Crear etiquetas con texto fijo</h3>
            <p class="text-gray-600 mb-6 max-w-md mx-auto">
              Diseña etiquetas sin vincular datos externos. Ideal para etiquetas con contenido estatico o cuando quieras definir el texto manualmente.
            </p>
            <button
              phx-click="continue_no_data"
              class="px-8 py-3 rounded-xl bg-amber-600 text-white hover:bg-amber-700 font-medium transition flex items-center space-x-2 mx-auto"
            >
              <span>Continuar al diseño</span>
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
              </svg>
            </button>
          </div>
        </div>

        <!-- Paste Area -->
        <div :if={@active_method == "paste"} class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-2">Pegar datos</h3>
          <p class="text-sm text-gray-600 mb-4">
            Pega tus datos aquí. Se detectan automáticamente tabuladores, comas, punto y coma, o espacios como separadores.
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
          <div id="data-preview" class="mt-8 bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
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

        <!-- Back button when no data -->
        <div :if={!@upload_data || length(@upload_data) == 0} class="mt-8">
          <button
            phx-click="back"
            class="inline-flex items-center space-x-2 px-5 py-2.5 rounded-xl border-2 border-gray-300 text-gray-700 hover:bg-gray-100 hover:border-gray-400 font-medium transition"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            <span><%= if @design_id, do: "Volver a diseños", else: "Volver a selección de modo" %></span>
          </button>
        </div>
      </div>
    </div>
    """
  end
end
