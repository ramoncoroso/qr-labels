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
        <.link navigate={~p"/generate"} class="block mb-4 bg-slate-50 rounded-lg border-2 border-dashed border-slate-300 hover:border-blue-500 hover:bg-blue-50 p-4 transition-colors">
          <div class="flex items-center space-x-4">
            <div class="w-12 h-12 rounded-lg bg-slate-200 flex items-center justify-center">
              <svg class="w-6 h-6 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-slate-600">Nueva combinación</h3>
              <p class="text-sm text-slate-500">Combina un diseño con tus datos para imprimir</p>
            </div>
          </div>
        </.link>

        <div id="batches" phx-update="stream" class="space-y-4">
          <div :for={{dom_id, batch} <- @streams.batches} id={dom_id} class="bg-white rounded-lg shadow border border-gray-200 p-4">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-4">
                <div class="w-12 h-12 rounded-lg bg-indigo-100 flex items-center justify-center">
                  <svg class="w-6 h-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
                  </svg>
                </div>
                <div>
                  <h3 class="text-lg font-semibold text-gray-900">
                    Combinación #<%= batch.id %>
                  </h3>
                  <p class="text-sm text-gray-500">
                    <%= batch.total_labels %> etiquetas
                    · Creado <%= Calendar.strftime(batch.inserted_at, "%d/%m/%Y %H:%M") %>
                  </p>
                </div>
              </div>

              <div class="flex items-center space-x-4">
                <div class="text-right">
                  <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{status_color(batch.status)}"}>
                    <%= status_label(batch.status) %>
                  </span>
                  <%= if batch.printed_count > 0 do %>
                    <p class="text-xs text-gray-500 mt-1">
                      <%= batch.printed_count %> impresas
                    </p>
                  <% end %>
                </div>

                <div class="flex space-x-2">
                  <.link navigate={~p"/batches/#{batch.id}"} class="text-indigo-600 hover:text-indigo-800 text-sm font-medium">
                    Ver
                  </.link>
                  <.link navigate={~p"/batches/#{batch.id}/print"} class="text-green-600 hover:text-green-800 text-sm font-medium">
                    Imprimir
                  </.link>
                  <form action={~p"/batches/#{batch.id}"} method="post" class="inline">
                    <input type="hidden" name="_method" value="delete" />
                    <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
                    <button
                      type="submit"
                      onclick="return confirm('¿Estás seguro de que quieres eliminar esta combinación?')"
                      class="text-red-500 hover:text-red-700 text-sm"
                    >
                      Eliminar
                    </button>
                  </form>
                </div>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
    """
  end

  defp status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("ready"), do: "bg-green-100 text-green-800"
  defp status_color("printed"), do: "bg-blue-100 text-blue-800"
  defp status_color("partial"), do: "bg-orange-100 text-orange-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp status_label("pending"), do: "Pendiente"
  defp status_label("ready"), do: "Listo"
  defp status_label("printed"), do: "Impreso"
  defp status_label("partial"), do: "Parcial"
  defp status_label(status), do: status
end
