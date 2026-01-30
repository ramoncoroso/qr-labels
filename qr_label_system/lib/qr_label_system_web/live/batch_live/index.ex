defmodule QrLabelSystemWeb.BatchLive.Index do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Batches

  @impl true
  def mount(_params, _session, socket) do
    batches = Batches.list_user_batches(socket.assigns.current_user.id)
    {:ok,
     socket
     |> assign(:has_batches, length(batches) > 0)
     |> stream(:batches, batches)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :page_title, "Combinar e imprimir")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    batch = Batches.get_batch!(id)

    if batch.user_id == socket.assigns.current_user.id do
      {:ok, _} = Batches.delete_batch(batch)
      {:noreply, stream_delete(socket, :batches, batch)}
    else
      {:noreply, put_flash(socket, :error, "No tienes permiso para eliminar esta combinación")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Combinar e imprimir
        <:subtitle>Asocia diseños de etiquetas con tus datos e imprime</:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Add New Batch Card -->
        <.link navigate={~p"/generate"} class="group block mb-6 bg-gradient-to-br from-gray-50 to-gray-100/50 rounded-xl border-2 border-dashed border-gray-300 hover:border-violet-400 hover:from-violet-50 hover:to-purple-50/50 p-5 transition-all duration-300 hover:shadow-lg hover:shadow-violet-100/50">
          <div class="flex items-center space-x-4">
            <div class="w-14 h-14 rounded-xl bg-white shadow-sm border border-gray-200 group-hover:border-violet-200 group-hover:shadow-md group-hover:shadow-violet-100/50 flex items-center justify-center transition-all duration-300">
              <svg class="w-7 h-7 text-gray-400 group-hover:text-violet-500 transition-colors duration-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-semibold text-gray-700 group-hover:text-violet-700 transition-colors">Nueva combinación</h3>
              <p class="text-sm text-gray-500 group-hover:text-violet-600/70 transition-colors">Combina un diseño con tus datos para imprimir</p>
            </div>
            <div class="flex-1"></div>
            <div class="w-10 h-10 rounded-full bg-white shadow-sm border border-gray-200 group-hover:bg-violet-500 group-hover:border-violet-500 flex items-center justify-center transition-all duration-300 opacity-0 group-hover:opacity-100">
              <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3" />
              </svg>
            </div>
          </div>
        </.link>

        <div id="batches" phx-update="stream" class="space-y-4 pb-4">
          <div :for={{dom_id, batch} <- @streams.batches} id={dom_id} class="group/card bg-white rounded-xl shadow-sm border border-gray-200/80 p-4 hover:shadow-md hover:border-gray-300 transition-all duration-200">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-4 min-w-0 flex-1">
                <div class={["w-12 h-12 rounded-xl shadow-lg flex items-center justify-center", status_gradient(batch.status)]}>
                  <%= status_icon(batch.status) %>
                </div>
                <div class="min-w-0 flex-1">
                  <h3 class="text-base font-semibold text-gray-900 truncate group-hover/card:text-violet-700 transition-colors">
                    Combinación #<%= batch.id %>
                  </h3>
                  <p class="text-sm text-gray-500 flex items-center gap-2 flex-wrap">
                    <span class="inline-flex items-center">
                      <svg class="w-3.5 h-3.5 mr-1 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9.568 3H5.25A2.25 2.25 0 003 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 005.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 009.568 3z" />
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6 6h.008v.008H6V6z" />
                      </svg>
                      <%= batch.total_labels %> etiquetas
                    </span>
                    <span class="text-gray-300">·</span>
                    <span class="inline-flex items-center">
                      <svg class="w-3.5 h-3.5 mr-1 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      <%= Calendar.strftime(batch.inserted_at, "%d/%m/%Y %H:%M") %>
                    </span>
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-3">
                <!-- Status Badge -->
                <div class="text-right">
                  <span class={["inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium shadow-sm", status_badge(batch.status)]}>
                    <%= status_icon_small(batch.status) %>
                    <%= status_label(batch.status) %>
                  </span>
                  <%= if batch.print_count > 0 do %>
                    <p class="text-xs text-gray-500 mt-1 flex items-center justify-end gap-1">
                      <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0110.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0l.229 2.523a1.125 1.125 0 01-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0021 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 00-1.913-.247" />
                      </svg>
                      <%= batch.print_count %>× impreso
                    </p>
                  <% end %>
                </div>

                <div class="flex items-center gap-1">
                  <!-- View Button -->
                  <.link
                    navigate={~p"/batches/#{batch.id}"}
                    class="group relative inline-flex items-center justify-center w-9 h-9 rounded-lg bg-gray-50 hover:bg-indigo-50 border border-gray-200 hover:border-indigo-200 transition-all duration-200 hover:shadow-sm"
                  >
                    <svg class="w-4 h-4 text-gray-500 group-hover:text-indigo-600 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    <span class="sr-only">Ver</span>
                    <span class="absolute -bottom-8 left-1/2 -translate-x-1/2 px-2 py-1 bg-gray-900 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none z-10">
                      Ver detalles
                    </span>
                  </.link>

                  <!-- Print Button -->
                  <.link
                    navigate={~p"/batches/#{batch.id}/print"}
                    class="group relative inline-flex items-center justify-center w-9 h-9 rounded-lg bg-gray-50 hover:bg-emerald-50 border border-gray-200 hover:border-emerald-200 transition-all duration-200 hover:shadow-sm"
                  >
                    <svg class="w-4 h-4 text-gray-500 group-hover:text-emerald-600 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0110.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0l.229 2.523a1.125 1.125 0 01-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0021 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 00-1.913-.247M6.34 18H5.25A2.25 2.25 0 013 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 011.913-.247m10.5 0a48.536 48.536 0 00-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659M18 10.5h.008v.008H18V10.5zm-3 0h.008v.008H15V10.5z" />
                    </svg>
                    <span class="sr-only">Imprimir</span>
                    <span class="absolute -bottom-8 left-1/2 -translate-x-1/2 px-2 py-1 bg-gray-900 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none z-10">
                      Imprimir
                    </span>
                  </.link>

                  <!-- Divider -->
                  <div class="w-px h-6 bg-gray-200 mx-1"></div>

                  <!-- Delete Button -->
                  <button
                    phx-click="delete"
                    phx-value-id={batch.id}
                    data-confirm="¿Estás seguro de que quieres eliminar esta combinación? Esta acción no se puede deshacer."
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

  defp status_gradient("pending"), do: "bg-gradient-to-br from-amber-400 to-yellow-500 shadow-amber-400/25"
  defp status_gradient("ready"), do: "bg-gradient-to-br from-emerald-500 to-green-600 shadow-emerald-500/25"
  defp status_gradient("printed"), do: "bg-gradient-to-br from-blue-500 to-indigo-600 shadow-blue-500/25"
  defp status_gradient("partial"), do: "bg-gradient-to-br from-orange-500 to-amber-600 shadow-orange-500/25"
  defp status_gradient(_), do: "bg-gradient-to-br from-gray-400 to-slate-500 shadow-gray-400/25"

  defp status_badge("pending"), do: "bg-gradient-to-r from-amber-50 to-yellow-50 text-amber-700 border border-amber-200/50"
  defp status_badge("ready"), do: "bg-gradient-to-r from-emerald-50 to-green-50 text-emerald-700 border border-emerald-200/50"
  defp status_badge("printed"), do: "bg-gradient-to-r from-blue-50 to-indigo-50 text-blue-700 border border-blue-200/50"
  defp status_badge("partial"), do: "bg-gradient-to-r from-orange-50 to-amber-50 text-orange-700 border border-orange-200/50"
  defp status_badge(_), do: "bg-gradient-to-r from-gray-50 to-slate-50 text-gray-700 border border-gray-200/50"

  defp status_label("pending"), do: "Pendiente"
  defp status_label("ready"), do: "Listo"
  defp status_label("printed"), do: "Impreso"
  defp status_label("partial"), do: "Parcial"
  defp status_label(status), do: status

  defp status_icon("pending") do
    Phoenix.HTML.raw("""
    <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """)
  end

  defp status_icon("ready") do
    Phoenix.HTML.raw("""
    <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
      <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """)
  end

  defp status_icon("printed") do
    Phoenix.HTML.raw("""
    <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
      <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0110.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0l.229 2.523a1.125 1.125 0 01-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0021 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 00-1.913-.247M6.34 18H5.25A2.25 2.25 0 013 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.041 48.041 0 011.913-.247m10.5 0a48.536 48.536 0 00-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659M18 10.5h.008v.008H18V10.5zm-3 0h.008v.008H15V10.5z" />
    </svg>
    """)
  end

  defp status_icon(_) do
    Phoenix.HTML.raw("""
    <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
      <path stroke-linecap="round" stroke-linejoin="round" d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z" />
    </svg>
    """)
  end

  defp status_icon_small("pending") do
    Phoenix.HTML.raw("""
    <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
      <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """)
  end

  defp status_icon_small("ready") do
    Phoenix.HTML.raw("""
    <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
      <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """)
  end

  defp status_icon_small("printed") do
    Phoenix.HTML.raw("""
    <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
      <path stroke-linecap="round" stroke-linejoin="round" d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0110.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18" />
    </svg>
    """)
  end

  defp status_icon_small(_) do
    Phoenix.HTML.raw("""
    <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
      <path stroke-linecap="round" stroke-linejoin="round" d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712" />
    </svg>
    """)
  end
end
