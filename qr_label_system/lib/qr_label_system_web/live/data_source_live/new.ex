defmodule QrLabelSystemWeb.DataSourceLive.New do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.DataSources
  alias QrLabelSystem.DataSources.DataSource

  @impl true
  def mount(_params, _session, socket) do
    changeset = DataSources.change_data_source(%DataSource{})

    {:ok,
     socket
     |> assign(:page_title, "Agregar datos para etiquetas")
     |> assign(:data_source, %DataSource{})
     |> assign(:step, :upload)  # Steps: :upload, :details
     |> assign(:uploaded_file, nil)
     |> assign(:detected_type, nil)
     |> assign(:source_type, nil)
     |> assign(:connection_status, nil)
     |> assign(:connection_error, nil)
     |> allow_upload(:file, accept: ~w(.xlsx .xls .csv), max_entries: 1, max_file_size: 10_000_000)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"data_source" => data_source_params}, socket) do
    source_type = data_source_params["type"] || socket.assigns.source_type

    changeset =
      socket.assigns.data_source
      |> DataSources.change_data_source(data_source_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:source_type, source_type)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_file", _params, socket) do
    case uploaded_entries(socket, :file) do
      {[entry], []} ->
        # Get file extension to detect type
        ext = Path.extname(entry.client_name) |> String.downcase()
        detected_type = detect_type(ext)

        # Suggest name based on filename (without extension)
        suggested_name = Path.basename(entry.client_name, ext)

        # Save the uploaded file
        uploads_dir = Path.join([:code.priv_dir(:qr_label_system), "uploads", "data_sources"])
        File.mkdir_p!(uploads_dir)

        dest_filename = "#{Ecto.UUID.generate()}#{ext}"
        dest_path = Path.join(uploads_dir, dest_filename)

        consume_uploaded_entries(socket, :file, fn %{path: path}, _entry ->
          File.cp!(path, dest_path)
          {:ok, dest_path}
        end)

        changeset = DataSources.change_data_source(%DataSource{}, %{
          "name" => suggested_name,
          "type" => detected_type,
          "file_path" => dest_path,
          "file_name" => entry.client_name
        })

        {:noreply,
         socket
         |> assign(:step, :details)
         |> assign(:uploaded_file, %{path: dest_path, name: entry.client_name})
         |> assign(:detected_type, detected_type)
         |> assign(:source_type, detected_type)
         |> assign_form(changeset)}

      {[], []} ->
        {:noreply, put_flash(socket, :error, "Por favor selecciona un archivo")}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save", %{"data_source" => data_source_params}, socket) do
    data_source_params =
      data_source_params
      |> Map.put("user_id", socket.assigns.current_user.id)
      |> Map.put("file_path", socket.assigns.uploaded_file.path)
      |> Map.put("file_name", socket.assigns.uploaded_file.name)

    case DataSources.create_data_source(data_source_params) do
      {:ok, _data_source} ->
        {:noreply,
         socket
         |> put_flash(:info, "Datos agregados exitosamente")
         |> push_navigate(to: ~p"/data-sources")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("back", _params, socket) do
    # Delete uploaded file if going back
    if socket.assigns.uploaded_file do
      File.rm(socket.assigns.uploaded_file.path)
    end

    {:noreply,
     socket
     |> assign(:step, :upload)
     |> assign(:uploaded_file, nil)
     |> assign(:detected_type, nil)
     |> allow_upload(:file, accept: ~w(.xlsx .xls .csv), max_entries: 1, max_file_size: 10_000_000)
     |> assign_form(DataSources.change_data_source(%DataSource{}))}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :file, ref)}
  end

  defp detect_type(".xlsx"), do: "excel"
  defp detect_type(".xls"), do: "excel"
  defp detect_type(".csv"), do: "csv"
  defp detect_type(_), do: "excel"

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "data_source"))
  end

  defp type_label("excel"), do: "Excel"
  defp type_label("csv"), do: "CSV"
  defp type_label(_), do: "Archivo"

  defp error_to_string(:too_large), do: "Archivo muy grande (máx 10MB)"
  defp error_to_string(:not_accepted), do: "Tipo de archivo no aceptado. Usa .xlsx, .xls o .csv"
  defp error_to_string(:too_many_files), do: "Solo puedes subir un archivo"
  defp error_to_string(error), do: "Error: #{inspect(error)}"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Agregar datos para etiquetas
        <:subtitle>
          <%= if @step == :upload do %>
            Sube un archivo Excel o CSV para comenzar
          <% else %>
            Confirma los detalles de tus datos
          <% end %>
        </:subtitle>
      </.header>

      <div class="mt-8 max-w-2xl">
        <%= if @step == :upload do %>
          <!-- Step 1: Upload file - HTML form fallback -->
          <form action={~p"/data-sources/upload"} method="post" enctype="multipart/form-data" class="space-y-6">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-indigo-500 transition-colors">
              <div class="space-y-4">
                <div class="mx-auto w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center">
                  <svg class="w-8 h-8 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                  </svg>
                </div>

                <div>
                  <label for="file-upload" class="cursor-pointer text-indigo-600 hover:text-indigo-500 font-medium">
                    Selecciona un archivo
                  </label>
                  <input
                    id="file-upload"
                    type="file"
                    name="file"
                    accept=".xlsx,.xls,.csv"
                    class="mt-4 block w-full text-sm text-gray-500
                      file:mr-4 file:py-2 file:px-4
                      file:rounded-md file:border-0
                      file:text-sm file:font-semibold
                      file:bg-indigo-50 file:text-indigo-700
                      hover:file:bg-indigo-100"
                    required
                  />
                  <p class="text-xs text-gray-400 mt-2">Excel (.xlsx, .xls) o CSV - Máximo 10MB</p>
                </div>
              </div>
            </div>

            <div class="flex justify-between items-center pt-4">
              <.link navigate={~p"/data-sources"} class="text-sm text-gray-600 hover:text-gray-900">
                Cancelar
              </.link>
              <button
                type="submit"
                class="px-4 py-2 rounded-md text-white font-medium bg-indigo-600 hover:bg-indigo-700"
              >
                Continuar
              </button>
            </div>
          </form>
        <% else %>
          <!-- Step 2: Details -->
          <div class="mb-6 p-4 bg-green-50 rounded-lg flex items-center space-x-3">
            <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <div>
              <p class="font-medium text-green-900"><%= @uploaded_file.name %></p>
              <p class="text-sm text-green-700">Formato detectado: <%= type_label(@detected_type) %></p>
            </div>
          </div>

          <.simple_form
            for={@form}
            id="data-source-form"
            phx-change="validate"
            phx-submit="save"
          >
            <.input field={@form[:name]} type="text" label="Nombre para identificar estos datos" required />

            <input type="hidden" name="data_source[type]" value={@detected_type} />

            <:actions>
              <button type="button" phx-click="back" class="text-sm text-gray-600 hover:text-gray-900">
                Volver
              </button>
              <.button phx-disable-with="Guardando...">Guardar</.button>
            </:actions>
          </.simple_form>
        <% end %>
      </div>
    </div>
    """
  end
end
