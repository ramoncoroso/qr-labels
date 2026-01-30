defmodule QrLabelSystemWeb.DataSourceLive.Index do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.DataSources

  @impl true
  def mount(_params, _session, socket) do
    data_sources = DataSources.list_user_data_sources(socket.assigns.current_user.id)
    {:ok,
     socket
     |> assign(:has_data_sources, length(data_sources) > 0)
     |> stream(:data_sources, data_sources)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :page_title, "Datos para etiquetas")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    data_source = DataSources.get_data_source!(id)

    if data_source.user_id == socket.assigns.current_user.id do
      {:ok, _} = DataSources.delete_data_source(data_source)
      {:noreply, stream_delete(socket, :data_sources, data_source)}
    else
      {:noreply, put_flash(socket, :error, "No tienes permiso para eliminar estos datos")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Datos para etiquetas
        <:subtitle>Configura tus archivos Excel, CSV o conexiones a bases de datos</:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Add New Data Source Card -->
        <.link navigate={~p"/data-sources/new"} class="group block mb-6 bg-gradient-to-br from-gray-50 to-gray-100/50 rounded-xl border-2 border-dashed border-gray-300 hover:border-emerald-400 hover:from-emerald-50 hover:to-teal-50/50 p-5 transition-all duration-300 hover:shadow-lg hover:shadow-emerald-100/50">
          <div class="flex items-center space-x-4">
            <div class="w-14 h-14 rounded-xl bg-white shadow-sm border border-gray-200 group-hover:border-emerald-200 group-hover:shadow-md group-hover:shadow-emerald-100/50 flex items-center justify-center transition-all duration-300">
              <svg class="w-7 h-7 text-gray-400 group-hover:text-emerald-500 transition-colors duration-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-semibold text-gray-700 group-hover:text-emerald-700 transition-colors">Agregar datos</h3>
              <p class="text-sm text-gray-500 group-hover:text-emerald-600/70 transition-colors">Excel, CSV o base de datos</p>
            </div>
            <div class="flex-1"></div>
            <div class="w-10 h-10 rounded-full bg-white shadow-sm border border-gray-200 group-hover:bg-emerald-500 group-hover:border-emerald-500 flex items-center justify-center transition-all duration-300 opacity-0 group-hover:opacity-100">
              <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3" />
              </svg>
            </div>
          </div>
        </.link>

        <div id="data_sources" phx-update="stream" class="space-y-4 pb-4">
          <div :for={{dom_id, data_source} <- @streams.data_sources} id={dom_id} class="group/card bg-white rounded-xl shadow-sm border border-gray-200/80 p-4 hover:shadow-md hover:border-gray-300 transition-all duration-200">
            <div class="flex items-center justify-between">
              <.link navigate={~p"/data-sources/#{data_source.id}"} class="flex items-center space-x-4 flex-1 min-w-0 cursor-pointer">
                <div class={["w-12 h-12 rounded-xl shadow-lg flex items-center justify-center", type_gradient(data_source.type)]}>
                  <%= type_icon(data_source.type) %>
                </div>
                <div class="min-w-0 flex-1">
                  <h3 class="text-base font-semibold text-gray-900 truncate group-hover/card:text-emerald-700 transition-colors">
                    <%= data_source.name %>
                  </h3>
                  <p class="text-sm text-gray-500 flex items-center gap-2">
                    <span class={["inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-xs font-medium", type_badge_color(data_source.type)]}>
                      <%= type_icon_small(data_source.type) %>
                      <%= type_label(data_source.type) %>
                    </span>
                    <%= if data_source.file_name do %>
                      <span class="text-gray-400 truncate max-w-[200px]"><%= data_source.file_name %></span>
                    <% end %>
                  </p>
                </div>
              </.link>

              <div class="flex items-center gap-3">
                <div class="flex items-center gap-1">
                  <!-- View Button -->
                  <.link
                    navigate={~p"/data-sources/#{data_source.id}"}
                    class="group relative inline-flex items-center justify-center w-9 h-9 rounded-lg bg-gray-50 hover:bg-indigo-50 border border-gray-200 hover:border-indigo-200 transition-all duration-200 hover:shadow-sm"
                  >
                    <svg class="w-4 h-4 text-gray-500 group-hover:text-indigo-600 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    <span class="sr-only">Ver</span>
                    <span class="absolute -bottom-8 left-1/2 -translate-x-1/2 px-2 py-1 bg-gray-900 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none z-10">
                      Ver
                    </span>
                  </.link>

                  <!-- Edit Button -->
                  <.link
                    navigate={~p"/data-sources/#{data_source.id}/edit"}
                    class="group relative inline-flex items-center justify-center w-9 h-9 rounded-lg bg-gray-50 hover:bg-blue-50 border border-gray-200 hover:border-blue-200 transition-all duration-200 hover:shadow-sm"
                  >
                    <svg class="w-4 h-4 text-gray-500 group-hover:text-blue-600 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125" />
                    </svg>
                    <span class="sr-only">Editar</span>
                    <span class="absolute -bottom-8 left-1/2 -translate-x-1/2 px-2 py-1 bg-gray-900 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none z-10">
                      Editar
                    </span>
                  </.link>

                  <!-- Divider -->
                  <div class="w-px h-6 bg-gray-200 mx-1"></div>

                  <!-- Delete Button -->
                  <button
                    phx-click="delete"
                    phx-value-id={data_source.id}
                    data-confirm="¿Estás seguro de que quieres eliminar estos datos? Esta acción no se puede deshacer."
                    class="group relative inline-flex items-center justify-center w-9 h-9 rounded-lg bg-gray-50 hover:bg-red-50 border border-gray-200 hover:border-red-200 transition-all duration-200 hover:shadow-sm"
                  >
                    <svg class="w-4 h-4 text-gray-400 group-hover:text-red-500 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                    </svg>
                    <span class="sr-only">Eliminar</span>
                    <span class="absolute -bottom-8 left-1/2 -translate-x-1/2 px-2 py-1 bg-gray-900 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none z-10">
                      Eliminar
                    </span>
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

  defp type_gradient("excel"), do: "bg-gradient-to-br from-green-500 to-emerald-600 shadow-green-500/25"
  defp type_gradient("csv"), do: "bg-gradient-to-br from-blue-500 to-cyan-600 shadow-blue-500/25"
  defp type_gradient("postgresql"), do: "bg-gradient-to-br from-indigo-500 to-blue-600 shadow-indigo-500/25"
  defp type_gradient("mysql"), do: "bg-gradient-to-br from-orange-500 to-amber-600 shadow-orange-500/25"
  defp type_gradient("sqlserver"), do: "bg-gradient-to-br from-red-500 to-rose-600 shadow-red-500/25"
  defp type_gradient(_), do: "bg-gradient-to-br from-gray-500 to-slate-600 shadow-gray-500/25"

  defp type_badge_color("excel"), do: "bg-green-50 text-green-700 border border-green-200/50"
  defp type_badge_color("csv"), do: "bg-blue-50 text-blue-700 border border-blue-200/50"
  defp type_badge_color("postgresql"), do: "bg-indigo-50 text-indigo-700 border border-indigo-200/50"
  defp type_badge_color("mysql"), do: "bg-orange-50 text-orange-700 border border-orange-200/50"
  defp type_badge_color("sqlserver"), do: "bg-red-50 text-red-700 border border-red-200/50"
  defp type_badge_color(_), do: "bg-gray-50 text-gray-700 border border-gray-200/50"

  defp type_label("excel"), do: "Excel"
  defp type_label("csv"), do: "CSV"
  defp type_label("postgresql"), do: "PostgreSQL"
  defp type_label("mysql"), do: "MySQL"
  defp type_label("sqlserver"), do: "SQL Server"
  defp type_label(type), do: type

  defp type_icon("excel") do
    Phoenix.HTML.raw("""
    <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
      <path stroke-linecap="round" stroke-linejoin="round" d="M3.375 19.5h17.25m-17.25 0a1.125 1.125 0 01-1.125-1.125M3.375 19.5h7.5c.621 0 1.125-.504 1.125-1.125m-9.75 0V5.625m0 12.75v-1.5c0-.621.504-1.125 1.125-1.125m18.375 2.625V5.625m0 12.75c0 .621-.504 1.125-1.125 1.125m1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125m0 3.75h-7.5A1.125 1.125 0 0112 18.375m9.75-12.75c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125m19.5 0v1.5c0 .621-.504 1.125-1.125 1.125M2.25 5.625v1.5c0 .621.504 1.125 1.125 1.125m0 0h17.25m-17.25 0h7.5c.621 0 1.125.504 1.125 1.125M3.375 8.25c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125m17.25-3.75h-7.5c-.621 0-1.125.504-1.125 1.125m8.625-1.125c.621 0 1.125.504 1.125 1.125v1.5c0 .621-.504 1.125-1.125 1.125m-17.25 0h7.5m-7.5 0c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125M12 10.875v-1.5m0 1.5c0 .621-.504 1.125-1.125 1.125M12 10.875c0 .621.504 1.125 1.125 1.125m-2.25 0c.621 0 1.125.504 1.125 1.125M13.125 12h7.5m-7.5 0c-.621 0-1.125.504-1.125 1.125M20.625 12c.621 0 1.125.504 1.125 1.125v1.5c0 .621-.504 1.125-1.125 1.125m-17.25 0h7.5M12 14.625v-1.5m0 1.5c0 .621-.504 1.125-1.125 1.125M12 14.625c0 .621.504 1.125 1.125 1.125m-2.25 0c.621 0 1.125.504 1.125 1.125m0 0v1.5c0 .621-.504 1.125-1.125 1.125" />
    </svg>
    """)
  end

  defp type_icon("csv") do
    Phoenix.HTML.raw("""
    <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
    </svg>
    """)
  end

  defp type_icon(_) do
    Phoenix.HTML.raw("""
    <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
      <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375m16.5 0v3.75m-16.5-3.75v3.75m16.5 0v3.75C20.25 16.153 16.556 18 12 18s-8.25-1.847-8.25-4.125v-3.75m16.5 0c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125" />
    </svg>
    """)
  end

  defp type_icon_small("excel") do
    Phoenix.HTML.raw("""
    <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
      <path stroke-linecap="round" stroke-linejoin="round" d="M3.375 19.5h17.25m-17.25 0a1.125 1.125 0 01-1.125-1.125M3.375 19.5h7.5c.621 0 1.125-.504 1.125-1.125m-9.75 0V5.625m0 12.75v-1.5c0-.621.504-1.125 1.125-1.125m18.375 2.625V5.625m0 12.75c0 .621-.504 1.125-1.125 1.125m1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125m0 3.75h-7.5A1.125 1.125 0 0112 18.375" />
    </svg>
    """)
  end

  defp type_icon_small("csv") do
    Phoenix.HTML.raw("""
    <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
      <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12" />
    </svg>
    """)
  end

  defp type_icon_small(_) do
    Phoenix.HTML.raw("""
    <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
      <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375" />
    </svg>
    """)
  end
end
