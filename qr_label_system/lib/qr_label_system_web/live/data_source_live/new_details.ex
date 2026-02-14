defmodule QrLabelSystemWeb.DataSourceLive.NewDetails do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.DataSources
  alias QrLabelSystem.DataSources.DataSource

  @impl true
  def mount(_params, session, socket) do
    # Get uploaded file info from session
    file_path = session["uploaded_file_path"]
    file_name = session["uploaded_file_name"]
    detected_type = session["detected_type"]
    suggested_name = session["suggested_name"]

    if is_nil(file_path) do
      {:ok,
       socket
       |> put_flash(:error, "No se encontró el archivo. Por favor sube uno nuevo.")
       |> push_navigate(to: ~p"/data-sources/new")}
    else
      changeset = DataSources.change_data_source(%DataSource{}, %{
        "name" => suggested_name,
        "type" => detected_type
      })

      {:ok,
       socket
       |> assign(:page_title, "Agregar datos - Detalles")
       |> assign(:file_path, file_path)
       |> assign(:file_name, file_name)
       |> assign(:detected_type, detected_type)
       |> assign_form(changeset)}
    end
  end

  @impl true
  def handle_event("validate", %{"data_source" => data_source_params}, socket) do
    changeset =
      %DataSource{}
      |> DataSources.change_data_source(data_source_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"data_source" => data_source_params}, socket) do
    data_source_params =
      data_source_params
      |> Map.put("user_id", socket.assigns.current_user.id)
      |> Map.put("workspace_id", socket.assigns.current_workspace.id)
      |> Map.put("file_path", socket.assigns.file_path)
      |> Map.put("file_name", socket.assigns.file_name)
      |> Map.put("type", socket.assigns.detected_type)

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

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "data_source"))
  end

  defp type_label("excel"), do: "Excel"
  defp type_label("csv"), do: "CSV"
  defp type_label(_), do: "Archivo"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Agregar datos para etiquetas
        <:subtitle>Confirma los detalles de tus datos</:subtitle>
      </.header>

      <div class="mt-8 max-w-2xl">
        <!-- File info -->
        <div class="mb-6 p-4 bg-green-50 rounded-lg flex items-center space-x-3">
          <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
            <svg class="w-5 h-5 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <div>
            <p class="font-medium text-green-900"><%= @file_name %></p>
            <p class="text-sm text-green-700">Formato detectado: <%= type_label(@detected_type) %></p>
          </div>
        </div>

        <form action={~p"/data-sources/new"} method="post" class="space-y-6">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <input type="hidden" name="data_source[type]" value={@detected_type} />
          <input type="hidden" name="data_source[file_path]" value={@file_path} />
          <input type="hidden" name="data_source[file_name]" value={@file_name} />

          <div>
            <label for="name" class="block text-sm font-medium text-gray-700">
              Nombre para identificar estos datos
            </label>
            <input
              type="text"
              name="data_source[name]"
              id="name"
              value={@form[:name].value}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            />
          </div>

          <div class="flex justify-between items-center pt-4">
            <.link navigate={~p"/data-sources/new"} class="text-sm text-gray-600 hover:text-gray-900">
              Volver
            </.link>
            <button
              type="submit"
              class="px-4 py-2 rounded-md text-white font-medium bg-indigo-600 hover:bg-indigo-700"
            >
              Guardar
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
