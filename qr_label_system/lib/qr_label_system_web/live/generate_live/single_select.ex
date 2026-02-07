defmodule QrLabelSystemWeb.GenerateLive.SingleSelect do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs

  import QrLabelSystemWeb.DesignComponents

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    all_designs = Designs.list_user_designs_by_type(user_id, "single")
    tags = Designs.list_user_tags(user_id)
    system_templates = Designs.list_system_templates()

    {:ok,
     socket
     |> assign(:page_title, "Etiqueta Única")
     |> assign(:all_designs, all_designs)
     |> assign(:designs, all_designs)
     |> assign(:tags, tags)
     |> assign(:active_tag_ids, [])
     |> assign(:system_templates, system_templates)}
  end

  @impl true
  def handle_event("select_design", %{"id" => design_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/generate/single/#{design_id}")}
  end

  @impl true
  def handle_event("create_new", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:return_to, "single_select")
     |> push_navigate(to: ~p"/designs/new?type=single")}
  end

  @impl true
  def handle_event("use_template", %{"id" => id}, socket) do
    case Designs.get_design(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "La plantilla ya no existe")}

      template ->
        user_id = socket.assigns.current_user.id

        case Designs.duplicate_design(template, user_id) do
          {:ok, new_design} ->
            # Update to single type since we're in single flow
            {:ok, new_design} = Designs.update_design(new_design, %{label_type: "single"})
            {:noreply, push_navigate(socket, to: ~p"/designs/#{new_design.id}/edit")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Error al usar la plantilla")}
        end
    end
  end

  @impl true
  def handle_event("toggle_tag_filter", %{"id" => tag_id}, socket) do
    tag_id = String.to_integer(tag_id)
    active = socket.assigns.active_tag_ids

    active =
      if tag_id in active,
        do: List.delete(active, tag_id),
        else: active ++ [tag_id]

    designs = filter_by_tags(socket.assigns.all_designs, active)

    {:noreply,
     socket
     |> assign(:active_tag_ids, active)
     |> assign(:designs, designs)}
  end

  @impl true
  def handle_event("clear_tag_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:active_tag_ids, [])
     |> assign(:designs, socket.assigns.all_designs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto">
      <.header>
        Etiqueta Única
        <:subtitle>
          Selecciona un diseño para imprimir una etiqueta con contenido estático
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
              <span class="ml-2 text-sm font-medium text-green-600">Modo único</span>
            </div>
            <div class="w-16 h-0.5 bg-indigo-600"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-sm">1</div>
              <span class="ml-2 text-sm font-medium text-indigo-600">Elegir diseño</span>
            </div>
            <div class="w-16 h-0.5 bg-gray-300"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-gray-500 font-bold text-sm">2</div>
              <span class="ml-2 text-sm text-gray-500">Imprimir</span>
            </div>
          </div>
        </div>

        <!-- Info Box -->
        <div class="bg-blue-50 border border-blue-200 rounded-xl p-4 mb-8">
          <div class="flex items-start space-x-3">
            <svg class="w-5 h-5 text-blue-500 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div class="text-sm text-blue-800">
              <p class="font-medium mb-1">Modo etiqueta única</p>
              <p>En este modo, el contenido de la etiqueta será estático. Los textos, códigos QR y códigos de barras usarán el contenido definido en el diseño, sin vinculación a datos externos.</p>
            </div>
          </div>
        </div>

        <!-- Tag Filters -->
        <div :if={@tags != []} class="flex flex-wrap items-center gap-2 mb-6">
          <%= for tag <- @tags do %>
            <button
              type="button"
              phx-click="toggle_tag_filter"
              phx-value-id={tag.id}
              class={"inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium transition-all #{if tag.id in @active_tag_ids, do: "ring-2 ring-offset-1 ring-blue-400", else: ""}"}
              style={"background-color: #{tag.color}20; color: #{tag.color};"}
            >
              <span class="w-2 h-2 rounded-full" style={"background-color: #{tag.color};"}></span>
              <%= tag.name %>
            </button>
          <% end %>
          <button
            :if={@active_tag_ids != []}
            type="button"
            phx-click="clear_tag_filters"
            class="text-xs text-gray-400 hover:text-gray-600 ml-1"
          >
            Limpiar filtros
          </button>
        </div>

        <!-- Design Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <!-- Create New Design Card -->
          <button
            phx-click="create_new"
            class="bg-slate-50 rounded-xl border-2 border-dashed border-slate-300 hover:border-indigo-500 hover:bg-indigo-50 p-6 cursor-pointer transition-all flex flex-col items-center justify-center min-h-[220px]"
          >
            <div class="w-14 h-14 bg-slate-200 rounded-full flex items-center justify-center mb-4">
              <svg class="w-7 h-7 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-slate-600">Nuevo Diseño</h3>
            <p class="text-sm text-slate-500 text-center mt-1">Crear una nueva plantilla</p>
          </button>

          <!-- Existing Designs -->
          <%= for design <- @designs do %>
            <button
              phx-click="select_design"
              phx-value-id={design.id}
              class="bg-white rounded-xl shadow-sm border-2 border-transparent hover:border-indigo-500 p-6 cursor-pointer transition-all text-left"
            >
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-lg font-semibold text-gray-900 truncate"><%= design.name %></h3>
                <svg class="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                </svg>
              </div>

              <p :if={design.description} class="text-sm text-gray-500 mb-3 line-clamp-2"><%= design.description %></p>

              <div class="text-sm text-gray-600 mb-3">
                <span><%= design.width_mm %> × <%= design.height_mm %> mm</span>
              </div>

              <!-- Tags -->
              <div :if={(design.tags || []) != []} class="flex flex-wrap gap-1 mb-3">
                <%= for tag <- design.tags do %>
                  <span
                    class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-full text-[10px] font-medium"
                    style={"background-color: #{tag.color}20; color: #{tag.color};"}
                  >
                    <span class="w-1.5 h-1.5 rounded-full" style={"background-color: #{tag.color};"}></span>
                    <%= tag.name %>
                  </span>
                <% end %>
              </div>

              <!-- Mini Preview -->
              <div class="bg-gray-100 rounded-lg p-3 flex justify-center items-center min-h-[80px]">
                <.design_thumbnail design={design} max_width={140} max_height={90} />
              </div>
            </button>
          <% end %>
        </div>

        <%= if length(@designs) == 0 do %>
          <div class="mt-4 text-center py-8 bg-gray-50 rounded-xl">
            <p class="text-gray-500">Aún no tienes diseños. Crea tu primer diseño o usa una plantilla.</p>
          </div>
        <% end %>

        <!-- System Templates Section -->
        <div :if={@system_templates != []} class="mt-10">
          <h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-4">Plantillas del sistema</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div
              :for={template <- @system_templates}
              class="bg-white rounded-xl shadow-sm border border-gray-200 hover:shadow-md hover:border-blue-300 transition-all p-4 cursor-pointer"
            >
              <div class="bg-gray-50 rounded-lg p-3 flex justify-center items-center min-h-[70px] mb-3">
                <.design_thumbnail design={template} max_width={120} max_height={70} />
              </div>
              <h4 class="font-semibold text-gray-900 text-sm"><%= template.name %></h4>
              <p class="text-xs text-gray-500 mt-1 line-clamp-1"><%= template.description %></p>
              <p class="text-xs text-gray-400 mt-1"><%= template.width_mm %> × <%= template.height_mm %> mm</p>
              <button
                phx-click="use_template"
                phx-value-id={template.id}
                class="mt-3 w-full inline-flex items-center justify-center gap-1.5 px-3 py-1.5 rounded-lg bg-blue-50 hover:bg-blue-100 border border-blue-200 text-blue-700 text-xs font-medium transition"
              >
                Usar plantilla
              </button>
            </div>
          </div>
        </div>

        <!-- Back button -->
        <div class="mt-8">
          <.link
            navigate={~p"/generate"}
            class="inline-flex items-center space-x-2 px-5 py-2.5 rounded-xl border-2 border-gray-300 text-gray-700 hover:bg-gray-100 hover:border-gray-400 font-medium transition"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            <span>Volver a selección de modo</span>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp filter_by_tags(designs, []), do: designs

  defp filter_by_tags(designs, active_tag_ids) do
    Enum.filter(designs, fn design ->
      design_tag_ids = Enum.map(design.tags || [], & &1.id)
      Enum.all?(active_tag_ids, &(&1 in design_tag_ids))
    end)
  end
end
