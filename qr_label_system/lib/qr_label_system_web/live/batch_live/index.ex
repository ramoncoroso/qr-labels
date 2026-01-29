defmodule QrLabelSystemWeb.BatchLive.Index do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Batches

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :batches, Batches.list_batches(socket.assigns.current_user.id))}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :page_title, "Lotes Generados")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    batch = Batches.get_batch!(id)

    if batch.user_id == socket.assigns.current_user.id do
      {:ok, _} = Batches.delete_batch(batch)
      {:noreply, stream_delete(socket, :batches, batch)}
    else
      {:noreply, put_flash(socket, :error, "No tienes permiso para eliminar este lote")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Lotes Generados
        <:subtitle>Historial de lotes de etiquetas generados</:subtitle>
        <:actions>
          <.link navigate={~p"/generate"}>
            <.button>+ Generar Nuevo Lote</.button>
          </.link>
        </:actions>
      </.header>

      <div class="mt-8">
        <div id="batches" phx-update="stream" class="space-y-4">
          <div :for={{dom_id, batch} <- @streams.batches} id={dom_id} class="bg-white rounded-lg shadow border border-gray-200 p-4">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-4">
                <div class="w-12 h-12 rounded-lg bg-indigo-100 flex items-center justify-center">
                  <svg class="w-6 h-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
                  </svg>
                </div>
                <div>
                  <h3 class="text-lg font-semibold text-gray-900">
                    Lote #<%= batch.id %>
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
                  <button
                    phx-click="delete"
                    phx-value-id={batch.id}
                    data-confirm="¿Estás seguro de que quieres eliminar este lote?"
                    class="text-red-500 hover:text-red-700 text-sm"
                  >
                    Eliminar
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div :if={@streams.batches |> Enum.empty?()} class="text-center py-12">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No hay lotes generados</h3>
          <p class="mt-1 text-sm text-gray-500">Comienza generando un nuevo lote de etiquetas.</p>
          <div class="mt-6">
            <.link navigate={~p"/generate"}>
              <.button>+ Generar Nuevo Lote</.button>
            </.link>
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
