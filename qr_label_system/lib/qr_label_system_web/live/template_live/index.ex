defmodule QrLabelSystemWeb.TemplateLive.Index do
  use QrLabelSystemWeb, :live_view

  import QrLabelSystemWeb.DesignComponents

  alias QrLabelSystem.Designs

  @impl true
  def mount(_params, _session, socket) do
    system_templates = Designs.list_system_templates()

    {:ok,
     socket
     |> assign(:page_title, "Plantillas del sistema")
     |> assign(:system_templates, system_templates)
     |> assign(:category_filter, "all")
     |> assign(:preview_template, nil)}
  end

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :category_filter, category)}
  end

  @impl true
  def handle_event("preview_template", %{"id" => id}, socket) do
    template = Enum.find(socket.assigns.system_templates, &(to_string(&1.id) == id))
    {:noreply, assign(socket, :preview_template, template)}
  end

  @impl true
  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, :preview_template, nil)}
  end

  @impl true
  def handle_event("use_template", %{"id" => id}, socket) do
    case Designs.get_design(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "La plantilla ya no existe")}

      template ->
        case Designs.duplicate_design(template, socket.assigns.current_user.id) do
          {:ok, new_design} ->
            {:noreply,
             socket
             |> put_flash(:info, "Plantilla \"#{template.name}\" duplicada en tus diseños.")
             |> push_navigate(to: ~p"/designs/#{new_design.id}/edit")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Error al usar la plantilla")}
        end
    end
  end

  defp filtered_templates(templates, "all"), do: templates

  defp filtered_templates(templates, category) do
    Enum.filter(templates, &(&1.template_category == category))
  end

  @category_labels %{
    "alimentacion" => "Alimentación",
    "farmaceutica" => "Farmacéutica",
    "logistica" => "Logística",
    "manufactura" => "Manufactura",
    "retail" => "Retail / Textil"
  }

  defp category_label(key), do: Map.get(@category_labels, key, key)

  @type_labels %{
    "qr" => "QR",
    "barcode" => "Código de barras",
    "text" => "Texto",
    "line" => "Línea",
    "rectangle" => "Rectángulo",
    "image" => "Imagen",
    "circle" => "Círculo"
  }

  defp element_type_label(type), do: Map.get(@type_labels, type, type)

  defp element_summary(elements) do
    elements
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, items} ->
      count = length(items)
      label = element_type_label(type)
      if count > 1, do: "#{count} #{label}", else: "1 #{label}"
    end)
    |> Enum.sort()
  end

  defp binding_columns(elements) do
    elements
    |> Enum.map(& &1.binding)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.sort()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto">
      <.header>
        Plantillas del sistema
        <:subtitle>
          Plantillas prediseñadas por sector. Usa una para crear un diseño propio a partir de ella.
        </:subtitle>
      </.header>

      <!-- Category Filters -->
      <div class="mt-6 mb-6 flex items-center gap-2 flex-wrap">
        <button
          phx-click="filter_category"
          phx-value-category="all"
          class={"px-3 py-1.5 rounded-full text-sm font-medium transition-all border " <>
            if(@category_filter == "all",
              do: "bg-blue-100 text-blue-700 border-blue-300",
              else: "bg-gray-100 text-gray-600 border-gray-200 hover:bg-gray-200"
            )}
        >
          Todas (<%= length(@system_templates) %>)
        </button>
        <button
          :for={cat <- ~w(alimentacion farmaceutica logistica manufactura retail)}
          phx-click="filter_category"
          phx-value-category={cat}
          class={"px-3 py-1.5 rounded-full text-sm font-medium transition-all border " <>
            if(@category_filter == cat,
              do: "bg-blue-100 text-blue-700 border-blue-300",
              else: "bg-gray-100 text-gray-600 border-gray-200 hover:bg-gray-200"
            )}
        >
          <%= category_label(cat) %>
          (<%= Enum.count(@system_templates, &(&1.template_category == cat)) %>)
        </button>
      </div>

      <!-- Template List -->
      <div class="space-y-4 pb-4">
        <div
          :for={template <- filtered_templates(@system_templates, @category_filter)}
          class="group/card relative bg-white rounded-xl shadow-sm border border-gray-200/80 p-4 hover:shadow-md hover:border-gray-300 transition-all duration-200"
        >
          <div class="flex gap-4">
            <!-- LEFT: Thumbnail -->
            <div
              phx-click="preview_template"
              phx-value-id={template.id}
              class="flex-shrink-0 self-stretch flex items-center cursor-pointer"
            >
              <div class="rounded-lg border border-gray-200 shadow-sm overflow-hidden">
                <.design_thumbnail design={template} max_width={80} max_height={80} />
              </div>
            </div>

            <!-- RIGHT: Content -->
            <div class="min-w-0 flex-1">
              <div class="flex items-center justify-between">
                <!-- Name + meta -->
                <div class="min-w-0 flex-1">
                  <h3 class="text-base font-semibold text-gray-900 truncate"><%= template.name %></h3>
                  <p :if={template.description} class="text-sm text-gray-500 truncate mt-0.5"><%= template.description %></p>
                  <p class="text-sm text-gray-500 flex items-center gap-2 flex-wrap mt-0.5">
                    <span class="inline-flex items-center gap-1">
                      <svg class="w-3.5 h-3.5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15" />
                      </svg>
                      <%= template.width_mm %> × <%= template.height_mm %> mm
                    </span>
                    <span class="text-gray-300">·</span>
                    <span><%= if template.label_type == "single", do: "Única", else: "Múltiple" %></span>
                    <span class="text-gray-300">·</span>
                    <span class={"inline-block px-2 py-0.5 rounded-full text-xs font-medium " <>
                      case template.template_category do
                        "alimentacion" -> "bg-green-100 text-green-700"
                        "farmaceutica" -> "bg-blue-100 text-blue-700"
                        "logistica" -> "bg-orange-100 text-orange-700"
                        "manufactura" -> "bg-purple-100 text-purple-700"
                        "retail" -> "bg-pink-100 text-pink-700"
                        _ -> "bg-gray-100 text-gray-600"
                      end}>
                      <%= category_label(template.template_category) %>
                    </span>
                  </p>
                </div>

                <!-- Action buttons -->
                <div class="flex items-center gap-2 ml-4">
                  <button
                    phx-click="preview_template"
                    phx-value-id={template.id}
                    class="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg bg-gray-100 hover:bg-gray-200 border border-gray-200 text-gray-700 text-sm font-medium transition"
                  >
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    Ver
                  </button>
                  <button
                    phx-click="use_template"
                    phx-value-id={template.id}
                    class="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium transition"
                  >
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                    </svg>
                    Usar plantilla
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div :if={filtered_templates(@system_templates, @category_filter) == []} class="text-center py-12 text-gray-500">
        No hay plantillas en esta categoría.
      </div>

      <!-- Preview Modal -->
      <div
        :if={@preview_template}
        class="fixed inset-0 z-50 overflow-y-auto"
        role="dialog"
        aria-modal="true"
      >
        <div class="flex items-center justify-center min-h-screen px-4 py-8">
          <!-- Overlay -->
          <div class="fixed inset-0 bg-gray-900/60 transition-opacity" phx-click="close_preview"></div>

          <!-- Modal -->
          <div class="relative bg-white rounded-2xl shadow-2xl max-w-2xl w-full overflow-hidden">
            <!-- Header -->
            <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
              <div class="flex items-center gap-3">
                <span class={"inline-block px-2.5 py-1 rounded-full text-xs font-semibold " <>
                  case @preview_template.template_category do
                    "alimentacion" -> "bg-green-100 text-green-700"
                    "farmaceutica" -> "bg-blue-100 text-blue-700"
                    "logistica" -> "bg-orange-100 text-orange-700"
                    "manufactura" -> "bg-purple-100 text-purple-700"
                    "retail" -> "bg-pink-100 text-pink-700"
                    _ -> "bg-gray-100 text-gray-600"
                  end}>
                  <%= category_label(@preview_template.template_category) %>
                </span>
                <h3 class="text-lg font-semibold text-gray-900"><%= @preview_template.name %></h3>
              </div>
              <button phx-click="close_preview" class="p-1.5 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition">
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <!-- Large Preview -->
            <div class="bg-gray-50 px-6 py-8 flex items-center justify-center">
              <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
                <.design_thumbnail design={@preview_template} max_width={400} max_height={280} />
              </div>
            </div>

            <!-- Details -->
            <div class="px-6 py-5 space-y-4">
              <!-- Description -->
              <p :if={@preview_template.description} class="text-sm text-gray-600">
                <%= @preview_template.description %>
              </p>

              <!-- Dimensions -->
              <div class="flex items-center gap-2 text-sm text-gray-500">
                <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15" />
                </svg>
                <span><%= @preview_template.width_mm %> × <%= @preview_template.height_mm %> mm</span>
              </div>

              <!-- Elements summary -->
              <div :if={(@preview_template.elements || []) != []}>
                <h4 class="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-2">Elementos</h4>
                <div class="flex flex-wrap gap-1.5">
                  <span
                    :for={summary <- element_summary(@preview_template.elements)}
                    class="inline-flex items-center px-2.5 py-1 rounded-lg bg-gray-100 text-xs font-medium text-gray-700"
                  >
                    <%= summary %>
                  </span>
                </div>
              </div>

              <!-- Binding columns -->
              <div :if={binding_columns(@preview_template.elements || []) != []}>
                <h4 class="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-2">Campos de datos requeridos</h4>
                <div class="flex flex-wrap gap-1.5">
                  <span
                    :for={col <- binding_columns(@preview_template.elements || [])}
                    class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-indigo-50 text-xs font-medium text-indigo-700"
                  >
                    <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m9.86-2.032a4.5 4.5 0 00-1.242-7.244l4.5-4.5a4.5 4.5 0 016.364 6.364l-1.757 1.757" />
                    </svg>
                    <%= col %>
                  </span>
                </div>
              </div>
            </div>

            <!-- Footer -->
            <div class="px-6 py-4 bg-gray-50 border-t border-gray-100 flex items-center justify-end gap-3">
              <button
                phx-click="close_preview"
                class="px-4 py-2 rounded-lg border border-gray-300 bg-white text-sm font-medium text-gray-700 hover:bg-gray-50 transition"
              >
                Cerrar
              </button>
              <button
                phx-click="use_template"
                phx-value-id={@preview_template.id}
                class="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium transition"
              >
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                </svg>
                Usar plantilla
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
