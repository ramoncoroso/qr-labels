defmodule QrLabelSystemWeb.DesignLive.Index do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Designs.Design

  @impl true
  def mount(_params, _session, socket) do
    designs = Designs.list_user_designs(socket.assigns.current_user.id)
    {:ok,
     socket
     |> assign(:has_designs, length(designs) > 0)
     |> stream(:designs, designs)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Nuevo Diseño")
    |> assign(:design, %Design{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Diseños de Etiquetas")
    |> assign(:design, nil)
  end

  @impl true
  def handle_info({QrLabelSystemWeb.DesignLive.FormComponent, {:saved, design}}, socket) do
    {:noreply, stream_insert(socket, :designs, design)}
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
        <:actions>
          <.link patch={~p"/designs/new"}>
            <.button>+ Nuevo Diseño</.button>
          </.link>
        </:actions>
      </.header>

      <div class="mt-8">
        <div id="designs" phx-update="stream" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div :for={{dom_id, design} <- @streams.designs} id={dom_id} class="bg-white rounded-lg shadow border border-slate-200 overflow-hidden hover:shadow-lg transition-shadow">
            <div class="p-4">
              <div class="flex justify-between items-start">
                <div>
                  <h3 class="text-lg font-semibold text-slate-900"><%= design.name %></h3>
                  <p class="text-sm text-slate-500 mt-1"><%= design.description || "Sin descripción" %></p>
                </div>
                <%= if design.is_template do %>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    Plantilla
                  </span>
                <% end %>
              </div>

              <div class="mt-4 flex items-center space-x-4 text-sm text-slate-600">
                <div class="flex items-center">
                  <svg class="w-4 h-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
                  </svg>
                  <%= design.width_mm %> × <%= design.height_mm %> mm
                </div>
                <div class="flex items-center">
                  <svg class="w-4 h-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                  </svg>
                  <%= length(design.elements || []) %> elementos
                </div>
              </div>

              <div class="mt-4 pt-4 border-t border-slate-100 flex justify-between">
                <div class="flex space-x-2">
                  <.link navigate={~p"/designs/#{design.id}/edit"} class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                    Editar
                  </.link>
                  <.link navigate={~p"/designs/#{design.id}"} class="text-slate-600 hover:text-slate-800 text-sm font-medium">
                    Ver
                  </.link>
                </div>
                <div class="flex space-x-2">
                  <button phx-click="duplicate" phx-value-id={design.id} class="text-slate-500 hover:text-slate-700 text-sm">
                    Duplicar
                  </button>
                  <button phx-click="export" phx-value-id={design.id} class="text-slate-500 hover:text-slate-700 text-sm">
                    Exportar
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

        <div :if={not @has_designs} class="text-center py-12">
          <svg class="mx-auto h-12 w-12 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m5 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-slate-900">No hay diseños</h3>
          <p class="mt-1 text-sm text-slate-500">Comienza creando un nuevo diseño de etiqueta.</p>
          <div class="mt-6">
            <.link patch={~p"/designs/new"}>
              <.button>+ Nuevo Diseño</.button>
            </.link>
          </div>
        </div>
      </div>

      <.modal :if={@live_action == :new} id="design-modal" show on_cancel={JS.patch(~p"/designs")}>
        <.live_component
          module={QrLabelSystemWeb.DesignLive.FormComponent}
          id={:new}
          title="Nuevo Diseño"
          action={@live_action}
          design={@design}
          user_id={@current_user.id}
          patch={~p"/designs"}
        />
      </.modal>
    </div>
    """
  end
end
