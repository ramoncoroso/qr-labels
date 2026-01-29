defmodule QrLabelSystemWeb.DesignLive.Index do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs

  @impl true
  def mount(_params, _session, socket) do
    designs = Designs.list_user_designs(socket.assigns.current_user.id)
    {:ok,
     socket
     |> assign(:has_designs, length(designs) > 0)
     |> assign(:page_title, "Diseños de Etiquetas")
     |> stream(:designs, designs)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    design = Designs.get_design!(id)

    if design.user_id == socket.assigns.current_user.id do
      {:ok, _} = Designs.delete_design(design)
      {:noreply, stream_delete(socket, :designs, design)}
    else
      {:noreply, put_flash(socket, :error, "No tienes permiso para eliminar este diseño")}
    end
  end

  @impl true
  def handle_event("duplicate", %{"id" => id}, socket) do
    design = Designs.get_design!(id)

    case Designs.duplicate_design(design, socket.assigns.current_user.id) do
      {:ok, new_design} ->
        {:noreply,
         socket
         |> put_flash(:info, "Diseño duplicado exitosamente")
         |> stream_insert(:designs, new_design)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Error al duplicar el diseño")}
    end
  end

  @impl true
  def handle_event("export", %{"id" => id}, socket) do
    design = Designs.get_design!(id)
    json = Designs.export_design_to_json(design)

    {:noreply,
     push_event(socket, "download_file", %{
       content: json,
       filename: "#{design.name}.json",
       mime_type: "application/json"
     })}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Diseños de Etiquetas
        <:subtitle>Crea y administra tus diseños de etiquetas personalizadas</:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Add New Design Card -->
        <.link navigate={~p"/designs/new"} class="block mb-4 bg-slate-50 rounded-lg border-2 border-dashed border-slate-300 hover:border-blue-500 hover:bg-blue-50 p-4 transition-colors">
          <div class="flex items-center space-x-4">
            <div class="w-12 h-12 rounded-lg bg-slate-200 flex items-center justify-center">
              <svg class="w-6 h-6 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-slate-600">Nuevo Diseño</h3>
              <p class="text-sm text-slate-500">Crea una nueva plantilla de etiqueta</p>
            </div>
          </div>
        </.link>

        <div id="designs" phx-update="stream" class="space-y-4">
          <div :for={{dom_id, design} <- @streams.designs} id={dom_id} class="bg-white rounded-lg shadow border border-gray-200 p-4">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-4">
                <div class="w-12 h-12 rounded-lg bg-blue-100 flex items-center justify-center">
                  <svg class="w-6 h-6 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" />
                  </svg>
                </div>
                <div>
                  <h3 class="text-lg font-semibold text-gray-900">
                    <%= design.name %>
                  </h3>
                  <p class="text-sm text-gray-500">
                    <%= design.width_mm %> × <%= design.height_mm %> mm
                    · <%= length(design.elements || []) %> elementos
                  </p>
                </div>
              </div>

              <div class="flex items-center space-x-4">
                <div class="text-right">
                  <%= if design.is_template do %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      Plantilla
                    </span>
                  <% end %>
                </div>

                <div class="flex space-x-2">
                  <.link navigate={~p"/designs/#{design.id}/edit"} class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                    Editar
                  </.link>
                  <.link navigate={~p"/designs/#{design.id}"} class="text-indigo-600 hover:text-indigo-800 text-sm font-medium">
                    Ver
                  </.link>
                  <button phx-click="duplicate" phx-value-id={design.id} class="text-slate-500 hover:text-slate-700 text-sm">
                    Duplicar
                  </button>
                  <button
                    phx-click="delete"
                    phx-value-id={design.id}
                    data-confirm="¿Estás seguro de que quieres eliminar este diseño?"
                    class="text-red-500 hover:text-red-700 text-sm"
                  >
                    Eliminar
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
    """
  end
end
