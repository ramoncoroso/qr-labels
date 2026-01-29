defmodule QrLabelSystemWeb.DataSourceLive.Index do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.DataSources
  alias QrLabelSystem.DataSources.DataSource

  @impl true
  def mount(_params, _session, socket) do
    data_sources = DataSources.list_user_data_sources(socket.assigns.current_user.id)
    {:ok,
     socket
     |> assign(:has_data_sources, length(data_sources) > 0)
     |> stream(:data_sources, data_sources)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Nueva Fuente de Datos")
    |> assign(:data_source, %DataSource{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Editar Fuente de Datos")
    |> assign(:data_source, DataSources.get_data_source!(id))
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Fuentes de Datos")
    |> assign(:data_source, nil)
  end

  @impl true
  def handle_info({QrLabelSystemWeb.DataSourceLive.FormComponent, {:saved, data_source}}, socket) do
    {:noreply, stream_insert(socket, :data_sources, data_source)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    data_source = DataSources.get_data_source!(id)

    if data_source.user_id == socket.assigns.current_user.id do
      {:ok, _} = DataSources.delete_data_source(data_source)
      {:noreply, stream_delete(socket, :data_sources, data_source)}
    else
      {:noreply, put_flash(socket, :error, "No tienes permiso para eliminar esta fuente de datos")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Fuentes de Datos
        <:subtitle>Configura conexiones a Excel, CSV o bases de datos externas</:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Add New Data Source Card -->
        <.link patch={~p"/data-sources/new"} class="block mb-4 bg-slate-50 rounded-lg border-2 border-dashed border-slate-300 hover:border-blue-500 hover:bg-blue-50 p-4 transition-colors">
          <div class="flex items-center space-x-4">
            <div class="w-12 h-12 rounded-lg bg-slate-200 flex items-center justify-center">
              <svg class="w-6 h-6 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-slate-600">Nueva Fuente de Datos</h3>
              <p class="text-sm text-slate-500">Excel, CSV o base de datos</p>
            </div>
          </div>
        </.link>

        <div id="data_sources" phx-update="stream" class="space-y-4">
          <div :for={{dom_id, data_source} <- @streams.data_sources} id={dom_id} class="bg-white rounded-lg shadow border border-gray-200 p-4">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-4">
                <div class={"w-12 h-12 rounded-lg flex items-center justify-center #{type_bg_color(data_source.type)}"}>
                  <%= type_icon(data_source.type) %>
                </div>
                <div>
                  <h3 class="text-lg font-semibold text-gray-900"><%= data_source.name %></h3>
                  <p class="text-sm text-gray-500">
                    <%= type_label(data_source.type) %>
                    <%= if data_source.type == "excel" && data_source.file_path do %>
                      - <%= Path.basename(data_source.file_path) %>
                    <% end %>
                  </p>
                </div>
              </div>

              <div class="flex items-center space-x-4">
                <.link navigate={~p"/data-sources/#{data_source.id}"} class="text-indigo-600 hover:text-indigo-800 text-sm font-medium">
                  Ver datos
                </.link>
                <.link patch={~p"/data-sources/#{data_source.id}/edit"} class="text-gray-600 hover:text-gray-800 text-sm font-medium">
                  Editar
                </.link>
                <button
                  phx-click="delete"
                  phx-value-id={data_source.id}
                  data-confirm="¿Estás seguro de que quieres eliminar esta fuente de datos?"
                  class="text-red-500 hover:text-red-700 text-sm"
                >
                  Eliminar
                </button>
              </div>
            </div>
          </div>
        </div>

      </div>

      <.modal :if={@live_action in [:new, :edit]} id="data-source-modal" show on_cancel={JS.patch(~p"/data-sources")}>
        <.live_component
          module={QrLabelSystemWeb.DataSourceLive.FormComponent}
          id={@data_source.id || :new}
          title={@page_title}
          action={@live_action}
          data_source={@data_source}
          user_id={@current_user.id}
          patch={~p"/data-sources"}
        />
      </.modal>
    </div>
    """
  end

  defp type_bg_color("excel"), do: "bg-green-100"
  defp type_bg_color("csv"), do: "bg-blue-100"
  defp type_bg_color("postgresql"), do: "bg-indigo-100"
  defp type_bg_color("mysql"), do: "bg-orange-100"
  defp type_bg_color("sqlserver"), do: "bg-red-100"
  defp type_bg_color(_), do: "bg-gray-100"

  defp type_label("excel"), do: "Excel"
  defp type_label("csv"), do: "CSV"
  defp type_label("postgresql"), do: "PostgreSQL"
  defp type_label("mysql"), do: "MySQL"
  defp type_label("sqlserver"), do: "SQL Server"
  defp type_label(type), do: type

  defp type_icon("excel") do
    Phoenix.HTML.raw("""
    <svg class="w-6 h-6 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
    </svg>
    """)
  end

  defp type_icon("csv") do
    Phoenix.HTML.raw("""
    <svg class="w-6 h-6 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
    </svg>
    """)
  end

  defp type_icon(_) do
    Phoenix.HTML.raw("""
    <svg class="w-6 h-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
    </svg>
    """)
  end
end
