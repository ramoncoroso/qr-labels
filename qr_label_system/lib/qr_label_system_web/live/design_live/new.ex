defmodule QrLabelSystemWeb.DesignLive.New do
  use QrLabelSystemWeb, :live_view

  import Plug.CSRFProtection, only: [get_csrf_token: 0]

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Designs.Design

  @impl true
  def mount(params, _session, socket) do
    # Get label type from query params (default to "single")
    label_type = Map.get(params, "type", "single")
    label_type = if label_type in ["single", "multiple"], do: label_type, else: "single"

    # Check if we're in no_data mode
    no_data_mode = Map.get(params, "no_data") == "true"

    changeset = Designs.change_design(%Design{label_type: label_type})

    # Get upload data from persistent store (for data-first flow - data not yet associated)
    user_id = socket.assigns.current_user.id
    {upload_data, upload_columns} = QrLabelSystem.UploadDataStore.get(user_id, nil)
    return_to = Phoenix.Flash.get(socket.assigns.flash, :return_to)

    {:ok,
     socket
     |> assign(:page_title, "Nuevo Diseño")
     |> assign(:design, %Design{label_type: label_type})
     |> assign(:label_type, label_type)
     |> assign(:upload_data, upload_data)
     |> assign(:upload_columns, upload_columns)
     |> assign(:return_to, return_to)
     |> assign(:no_data_mode, no_data_mode)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"design" => design_params}, socket) do
    changeset =
      socket.assigns.design
      |> Designs.change_design(design_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"design" => design_params}, socket) do
    user_id = socket.assigns.current_user.id

    design_params =
      design_params
      |> Map.put("user_id", user_id)
      |> Map.put("label_type", socket.assigns.label_type)

    case Designs.create_design(design_params) do
      {:ok, design} ->
        # For multiple designs with data, associate the data with the new design
        if socket.assigns.label_type == "multiple" and not socket.assigns.no_data_mode do
          QrLabelSystem.UploadDataStore.associate_with_design(user_id, design.id)
        end

        # Navigate to editor, passing no_data flag if in no_data mode
        redirect_url = if socket.assigns.no_data_mode do
          ~p"/designs/#{design.id}/edit?no_data=true"
        else
          ~p"/designs/#{design.id}/edit"
        end

        {:noreply,
         socket
         |> put_flash(:info, "Diseño creado exitosamente")
         |> push_navigate(to: redirect_url)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <.header>
        Configurar nuevo diseño
        <:subtitle>Define las dimensiones básicas de tu etiqueta</:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Progress Steps -->
        <div class="mb-8">
          <%= if @label_type == "multiple" do %>
            <div class="flex items-center justify-center space-x-4">
              <div class="flex items-center">
                <div class="w-8 h-8 bg-green-600 rounded-full flex items-center justify-center text-white">
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                </div>
                <span class="ml-2 text-sm font-medium text-green-600">Datos</span>
              </div>
              <div class="w-16 h-0.5 bg-indigo-600"></div>
              <div class="flex items-center">
                <div class="w-8 h-8 bg-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-sm">2</div>
                <span class="ml-2 text-sm font-medium text-indigo-600">Configurar</span>
              </div>
              <div class="w-16 h-0.5 bg-gray-300"></div>
              <div class="flex items-center">
                <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">3</div>
                <span class="ml-2 text-sm text-gray-500">Diseñar</span>
              </div>
              <div class="w-16 h-0.5 bg-gray-300"></div>
              <div class="flex items-center">
                <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">4</div>
                <span class="ml-2 text-sm text-gray-500">Imprimir</span>
              </div>
            </div>
          <% else %>
            <div class="flex items-center justify-center space-x-4">
              <div class="flex items-center">
                <div class="w-8 h-8 bg-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-sm">1</div>
                <span class="ml-2 text-sm font-medium text-indigo-600">Configurar</span>
              </div>
              <div class="w-16 h-0.5 bg-gray-300"></div>
              <div class="flex items-center">
                <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">2</div>
                <span class="ml-2 text-sm text-gray-500">Diseñar</span>
              </div>
              <div class="w-16 h-0.5 bg-gray-300"></div>
              <div class="flex items-center">
                <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">3</div>
                <span class="ml-2 text-sm text-gray-500">Imprimir</span>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Type Badge -->
        <div class="flex justify-center mb-6">
          <%= if @label_type == "single" do %>
            <span class="inline-flex items-center px-4 py-2 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
              <svg class="w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
              </svg>
              Etiqueta Única
            </span>
          <% else %>
            <span class="inline-flex items-center px-4 py-2 rounded-full text-sm font-medium bg-purple-100 text-purple-800">
              <svg class="w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
              </svg>
              Múltiples Etiquetas - <%= length(@upload_data || []) %> registros
            </span>
          <% end %>
        </div>

        <!-- Form Card -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <.simple_form
            for={@form}
            id="design-form"
            phx-change="validate"
            phx-submit="save"
            action={~p"/designs/new"}
            method="post"
          >
            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
            <.input field={@form[:name]} type="text" label="Nombre del diseño" required />
            <.input field={@form[:description]} type="textarea" label="Descripción" />

            <div class="grid grid-cols-2 gap-4">
              <.input field={@form[:width_mm]} type="number" label="Ancho (mm)" step="0.1" min="1" max="500" required />
              <.input field={@form[:height_mm]} type="number" label="Alto (mm)" step="0.1" min="1" max="500" required />
            </div>

            <div class="grid grid-cols-2 gap-4">
              <.input field={@form[:background_color]} type="color" label="Color de fondo" value="#FFFFFF" />
              <.input field={@form[:border_width]} type="number" label="Grosor del borde (mm)" step="0.1" min="0" value="0" />
            </div>

            <div class="grid grid-cols-2 gap-4">
              <.input field={@form[:border_color]} type="color" label="Color del borde" value="#000000" />
              <.input field={@form[:border_radius]} type="number" label="Radio del borde (mm)" step="0.1" min="0" value="0" />
            </div>

            <.input field={@form[:is_template]} type="checkbox" label="Guardar como plantilla reutilizable" />

            <:actions>
              <.link navigate={~p"/generate"} class="text-sm text-gray-600 hover:text-gray-900">
                Cancelar
              </.link>
              <.button phx-disable-with="Guardando...">Crear y Diseñar</.button>
            </:actions>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end
end
