defmodule QrLabelSystemWeb.DesignLive.New do
  use QrLabelSystemWeb, :live_view

  import Plug.CSRFProtection, only: [get_csrf_token: 0]

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Designs.Design
  alias QrLabelSystem.Compliance

  @impl true
  def mount(params, _session, socket) do
    # Get label type from query params (default to "single")
    label_type = Map.get(params, "type", "single")
    label_type = if label_type in ["single", "multiple"], do: label_type, else: "single"

    # Check if we're in no_data mode
    no_data_mode = Map.get(params, "no_data") == "true"

    changeset = Designs.change_design(%Design{label_type: label_type})

    # Get upload metadata from persistent store (for data-first flow - data not yet associated)
    user_id = socket.assigns.current_user.id
    {upload_columns, upload_total_rows, _upload_sample_rows} = QrLabelSystem.UploadDataStore.get_metadata(user_id, nil)
    return_to = Phoenix.Flash.get(socket.assigns.flash, :return_to)

    {:ok,
     socket
     |> assign(:page_title, "Nuevo Diseño")
     |> assign(:design, %Design{label_type: label_type})
     |> assign(:label_type, label_type)
     |> assign(:upload_total_rows, upload_total_rows)
     |> assign(:upload_columns, upload_columns)
     |> assign(:return_to, return_to)
     |> assign(:no_data_mode, no_data_mode)
     |> assign(:available_standards, Compliance.available_standards())
     |> assign(:selected_standard, nil)
     |> assign(:suggested_templates, [])
     |> assign(:selected_template, nil)
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
  def handle_event("select_standard", %{"standard" => ""}, socket) do
    {:noreply,
     socket
     |> assign(:selected_standard, nil)
     |> assign(:suggested_templates, [])
     |> assign(:selected_template, nil)}
  end

  def handle_event("select_standard", %{"standard" => standard}, socket) do
    templates = Designs.list_system_templates_by_standard(standard)

    {:noreply,
     socket
     |> assign(:selected_standard, standard)
     |> assign(:suggested_templates, templates)
     |> assign(:selected_template, nil)}
  end

  @impl true
  def handle_event("select_template", %{"template-id" => template_id}, socket) do
    template_id = String.to_integer(template_id)

    template = Enum.find(socket.assigns.suggested_templates, &(&1.id == template_id))

    if template do
      # Auto-fill form with template dimensions
      design_params = %{
        "width_mm" => to_string(template.width_mm),
        "height_mm" => to_string(template.height_mm),
        "background_color" => template.background_color || "#FFFFFF",
        "border_color" => template.border_color || "#000000",
        "border_width" => to_string(template.border_width || 0),
        "border_radius" => to_string(template.border_radius || 0)
      }

      changeset =
        socket.assigns.design
        |> Designs.change_design(design_params)
        |> Map.put(:action, :validate)

      {:noreply,
       socket
       |> assign(:selected_template, template)
       |> assign_form(changeset)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("deselect_template", _params, socket) do
    {:noreply, assign(socket, :selected_template, nil)}
  end

  @impl true
  def handle_event("save", %{"design" => design_params}, socket) do
    user_id = socket.assigns.current_user.id

    design_params =
      design_params
      |> Map.put("user_id", user_id)
      |> Map.put("label_type", socket.assigns.label_type)

    # Add compliance standard if selected
    design_params = if socket.assigns.selected_standard do
      Map.put(design_params, "compliance_standard", socket.assigns.selected_standard)
    else
      design_params
    end

    # Add elements/groups from selected template
    design_params = case socket.assigns.selected_template do
      nil -> design_params
      template ->
        design_params
        |> Map.put("elements", Enum.map(template.elements || [], &element_to_map/1))
        |> Map.put("groups", Enum.map(template.groups || [], &group_to_map/1))
    end

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

        flash_msg = if socket.assigns.selected_template do
          "Diseño creado desde plantilla \"#{socket.assigns.selected_template.name}\""
        else
          "Diseño creado exitosamente"
        end

        {:noreply,
         socket
         |> put_flash(:info, flash_msg)
         |> push_navigate(to: redirect_url)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp element_to_map(%{__struct__: _} = el) do
    Map.from_struct(el) |> Map.drop([:__meta__])
  end

  defp element_to_map(el) when is_map(el), do: el

  defp group_to_map(%{__struct__: _} = g) do
    Map.from_struct(g) |> Map.drop([:__meta__])
  end

  defp group_to_map(g) when is_map(g), do: g

  defp element_type_label("text"), do: "Texto"
  defp element_type_label("barcode"), do: "Código de barras"
  defp element_type_label("qr"), do: "QR"
  defp element_type_label("line"), do: "Línea"
  defp element_type_label("rectangle"), do: "Rectángulo"
  defp element_type_label("image"), do: "Imagen"
  defp element_type_label(_), do: "Elemento"

  defp element_type_icon("text"), do: "T"
  defp element_type_icon("barcode"), do: "|||"
  defp element_type_icon("qr"), do: "QR"
  defp element_type_icon("line"), do: "—"
  defp element_type_icon("rectangle"), do: "▢"
  defp element_type_icon(_), do: "•"

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
              Múltiples Etiquetas - <%= @upload_total_rows %> registros
            </span>
          <% end %>
        </div>

        <%!-- Compliance Standard selector (outside main form to avoid nested forms) --%>
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-4">
          <form phx-change="select_standard">
            <label class="block text-sm font-medium text-gray-700 mb-1">Norma de cumplimiento</label>
            <select name="standard" class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm">
              <option value="">Ninguna (sin normativa)</option>
              <%= for {code, name, description} <- @available_standards do %>
                <option value={code} selected={@selected_standard == code}>
                  <%= name %> — <%= description %>
                </option>
              <% end %>
            </select>
            <p class="mt-1 text-xs text-gray-400">
              Si tu etiqueta debe cumplir una normativa, selecciónala para validar automáticamente los campos obligatorios
            </p>
          </form>
        </div>

        <%!-- Template suggestions when a compliance standard is selected --%>
        <%= if @selected_standard && @suggested_templates != [] do %>
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-4">
            <h3 class="text-sm font-semibold text-gray-700 mb-1">
              <svg class="w-4 h-4 inline-block mr-1 text-indigo-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              Plantillas con campos obligatorios pre-configurados
            </h3>
            <p class="text-xs text-gray-400 mb-3">
              Selecciona una plantilla como punto de partida o continúa sin plantilla para crear un diseño en blanco.
            </p>
            <div class="grid grid-cols-2 md:grid-cols-3 gap-3">
              <%= for template <- @suggested_templates do %>
                <% is_selected = @selected_template && @selected_template.id == template.id %>
                <button
                  type="button"
                  phx-click={if is_selected, do: "deselect_template", else: "select_template"}
                  phx-value-template-id={template.id}
                  class={"group text-left rounded-lg p-4 transition-all border-2 #{if is_selected, do: "border-indigo-500 bg-indigo-50 shadow-md ring-1 ring-indigo-500", else: "border-gray-200 bg-white hover:border-indigo-300 hover:shadow-sm"}"}
                >
                  <div class="flex items-start justify-between">
                    <div class="flex-1 min-w-0">
                      <h4 class={"text-sm font-medium truncate #{if is_selected, do: "text-indigo-700", else: "text-gray-900 group-hover:text-indigo-600"}"}>
                        <%= template.name %>
                      </h4>
                      <p class="text-xs text-gray-500 mt-1 line-clamp-2">
                        <%= template.description || "Plantilla del sistema" %>
                      </p>
                    </div>
                    <%= if is_selected do %>
                      <div class="ml-2 shrink-0">
                        <svg class="w-5 h-5 text-indigo-600" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                        </svg>
                      </div>
                    <% end %>
                  </div>
                  <div class="mt-2 flex items-center gap-2 text-xs text-gray-400">
                    <span><%= template.width_mm %>×<%= template.height_mm %> mm</span>
                    <span>·</span>
                    <span><%= length(template.elements || []) %> elementos</span>
                  </div>
                </button>
              <% end %>
            </div>
          </div>

          <%!-- Preview of selected template --%>
          <%= if @selected_template do %>
            <div class="bg-white rounded-xl shadow-sm border border-indigo-200 p-6 mb-4">
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-sm font-semibold text-gray-700">
                  Vista previa: <%= @selected_template.name %>
                </h3>
                <span class="text-xs text-gray-400">
                  <%= @selected_template.width_mm %>×<%= @selected_template.height_mm %> mm
                </span>
              </div>

              <%!-- Elements list --%>
              <div class="border border-gray-100 rounded-lg divide-y divide-gray-100">
                <%= for {element, idx} <- Enum.with_index(@selected_template.elements || []) do %>
                  <div class="flex items-center gap-3 px-3 py-2 text-xs">
                    <%
                      icon_class = cond do
                        element.type == "text" -> "bg-blue-100 text-blue-600"
                        element.type in ~w(barcode qr) -> "bg-amber-100 text-amber-600"
                        true -> "bg-gray-100 text-gray-500"
                      end
                    %>
                    <span class={"w-6 h-6 rounded flex items-center justify-center text-[10px] font-mono shrink-0 #{icon_class}"}>
                      <%= element_type_icon(element.type) %>
                    </span>
                    <div class="flex-1 min-w-0">
                      <span class="font-medium text-gray-700"><%= element.name || "Elemento #{idx + 1}" %></span>
                      <span class="text-gray-400 ml-1">(<%= element_type_label(element.type) %>)</span>
                    </div>
                    <div class="shrink-0 text-gray-400">
                      <%= if element.binding do %>
                        <span class="inline-flex items-center px-1.5 py-0.5 rounded bg-purple-50 text-purple-600 text-[10px]">
                          {{ <%= element.binding %> }}
                        </span>
                      <% else %>
                        <span class="truncate max-w-[120px] inline-block"><%= element.text_content %></span>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>

              <p class="mt-3 text-xs text-gray-400">
                Las dimensiones de la plantilla se aplicarán al formulario. Puedes modificarlas antes de crear.
              </p>
            </div>
          <% end %>
        <% end %>

        <%= if @selected_standard && @suggested_templates == [] do %>
          <div class="mb-4 bg-amber-50 border border-amber-200 rounded-lg p-4">
            <div class="flex items-start gap-3">
              <svg class="w-5 h-5 text-amber-500 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <div>
                <p class="text-sm text-amber-800">
                  No hay plantillas disponibles para esta normativa. Se creará un diseño en blanco con la norma configurada.
                </p>
                <p class="text-xs text-amber-600 mt-1">
                  Una vez en el editor, el panel de compliance te indicará qué campos faltan y podrás agregarlos.
                </p>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Form Card -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <.form for={@form} id="design-form" phx-change="validate" phx-submit="save" action={~p"/designs/new"} method="post">
            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
            <div class="space-y-4">
              <p class="text-xs text-gray-400"><span class="text-indigo-500">*</span> Campos obligatorios</p>
              <%!-- Row 1: Name + Description --%>
              <div class="grid grid-cols-3 gap-4">
                <.input field={@form[:name]} type="text" label="Nombre del diseño" required />
                <div class="col-span-2">
                  <.input field={@form[:description]} type="text" label="Descripción" />
                </div>
              </div>

              <%!-- Row 2: Dimensions + Colors --%>
              <div class="grid grid-cols-4 gap-4">
                <.input field={@form[:width_mm]} type="number" label="Ancho (mm)" step="0.1" min="1" max="500" required />
                <.input field={@form[:height_mm]} type="number" label="Alto (mm)" step="0.1" min="1" max="500" required />
                <.input field={@form[:background_color]} type="color" label="Color de fondo" value="#FFFFFF" />
                <.input field={@form[:border_color]} type="color" label="Color del borde" value="#000000" />
              </div>

              <%!-- Row 3: Border settings --%>
              <div class="grid grid-cols-2 gap-4">
                <.input field={@form[:border_width]} type="number" label="Grosor del borde (mm)" step="0.1" min="0" value="0" />
                <.input field={@form[:border_radius]} type="number" label="Radio del borde (mm)" step="0.1" min="0" value="0" />
              </div>

              <%= if @selected_template do %>
                <div class="flex items-center gap-2 px-3 py-2 bg-indigo-50 border border-indigo-200 rounded-lg text-sm text-indigo-700">
                  <svg class="w-4 h-4 shrink-0" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                  </svg>
                  <span>Plantilla seleccionada: <strong><%= @selected_template.name %></strong> (<%= length(@selected_template.elements || []) %> elementos)</span>
                </div>
              <% end %>

              <.input field={@form[:is_template]} type="checkbox" label="Guardar como plantilla reutilizable" />

              <div class="flex items-center justify-between pt-2">
                <.link navigate={~p"/generate"} class="text-sm text-gray-600 hover:text-gray-900">
                  Cancelar
                </.link>
                <.button phx-disable-with="Guardando...">Crear y Diseñar</.button>
              </div>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
