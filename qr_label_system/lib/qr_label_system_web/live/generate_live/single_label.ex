defmodule QrLabelSystemWeb.GenerateLive.SingleLabel do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Designs.Design
  alias QrLabelSystem.Settings

  @impl true
  def mount(%{"design_id" => design_id}, _session, socket) do
    design = Designs.get_design!(design_id)

    if design.user_id != socket.assigns.current_user.id do
      {:ok,
       socket
       |> put_flash(:error, "No tienes permiso para usar este diseño")
       |> push_navigate(to: ~p"/generate/single")}
    else
      {:ok,
       socket
       |> assign(:page_title, "Imprimir: #{design.name}")
       |> assign(:design, design)
       |> assign(:quantity, 1)
       |> assign(:printing, false)
       |> assign(:zpl_dpi, 203)
       |> assign(:approval_required, Settings.approval_required?())
       |> push_event("update_preview", %{
         design: Design.to_json_light(design),
         row: %{},
         mapping: %{},
         preview_index: 0,
         total_rows: 1
       })}
    end
  end

  @impl true
  def handle_event("request_preview_data", _params, socket) do
    {:noreply,
     push_event(socket, "update_preview", %{
       design: Design.to_json_light(socket.assigns.design),
       row: %{},
       mapping: %{},
       preview_index: 0,
       total_rows: 1
     })}
  end

  @impl true
  def handle_event("update_quantity", %{"quantity" => quantity}, socket) do
    qty = case Integer.parse(quantity) do
      {n, ""} -> max(1, min(n, 100))
      _ -> socket.assigns.quantity
    end
    {:noreply, assign(socket, :quantity, qty)}
  end

  @impl true
  def handle_event("print", _params, socket) do
    if print_blocked?(socket) do
      {:noreply, put_flash(socket, :error, "Este diseno requiere aprobacion antes de imprimir")}
    else
      {:noreply,
       socket
       |> assign(:printing, true)
       |> push_event("print_single_labels", %{
         design: Design.to_json(socket.assigns.design),
         quantity: socket.assigns.quantity
       })}
    end
  end

  @impl true
  def handle_event("print_complete", _params, socket) do
    {:noreply,
     socket
     |> assign(:printing, false)
     |> put_flash(:info, "Etiquetas generadas correctamente")}
  end

  @impl true
  def handle_event("download_pdf", _params, socket) do
    if print_blocked?(socket) do
      {:noreply, put_flash(socket, :error, "Este diseno requiere aprobacion antes de descargar")}
    else
      {:noreply,
       push_event(socket, "download_single_pdf", %{
         design: Design.to_json(socket.assigns.design),
         quantity: socket.assigns.quantity
       })}
    end
  end

  @impl true
  def handle_event("set_zpl_dpi", %{"dpi" => dpi_str}, socket) do
    dpi = case Integer.parse(dpi_str) do
      {n, _} when n in [203, 300, 600] -> n
      _ -> 203
    end
    {:noreply, assign(socket, :zpl_dpi, dpi)}
  end

  @impl true
  def handle_event("download_zpl", _params, socket) do
    if print_blocked?(socket) do
      {:noreply, put_flash(socket, :error, "Este diseno requiere aprobacion antes de descargar")}
    else
      design = socket.assigns.design
      dpi = socket.assigns.zpl_dpi
      quantity = socket.assigns.quantity

      rows = List.duplicate(%{}, quantity)
      zpl_content = QrLabelSystem.Export.ZplGenerator.generate_batch(design, rows, dpi: dpi)
      filename = "#{design.name || "etiqueta"}-#{dpi}dpi.zpl"

      {:noreply,
       push_event(socket, "download_file", %{
         content: zpl_content,
         filename: filename,
         mime_type: "application/x-zpl"
       })}
    end
  end

  defp print_blocked?(socket) do
    socket.assigns.approval_required && socket.assigns.design.status != "approved"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto" id="single-label-page" phx-hook="SingleLabelPrint">
      <.header>
        Imprimir Etiqueta
        <:subtitle>
          Configura la cantidad y genera tu etiqueta
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
              <span class="ml-2 text-sm font-medium text-green-600">Diseño elegido</span>
            </div>
            <div class="w-16 h-0.5 bg-indigo-600"></div>
            <div class="flex items-center">
              <div class="w-8 h-8 bg-indigo-600 rounded-full flex items-center justify-center text-white font-bold text-sm">2</div>
              <span class="ml-2 text-sm font-medium text-indigo-600">Imprimir</span>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Preview Panel -->
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Vista previa</h3>

            <div class="bg-gray-100 rounded-xl p-6 flex justify-center items-center min-h-[300px]">
              <div
                id="label-preview"
                phx-hook="LabelPreview"
                phx-update="ignore"
                class="inline-block"
              >
              </div>
            </div>

            <div class="mt-4 grid grid-cols-2 gap-4 text-sm">
              <div class="bg-gray-50 rounded-lg p-3">
                <p class="text-gray-500">Tamaño</p>
                <p class="font-semibold text-gray-900"><%= @design.width_mm %> × <%= @design.height_mm %> mm</p>
              </div>
              <div class="bg-gray-50 rounded-lg p-3">
                <p class="text-gray-500">Elementos</p>
                <p class="font-semibold text-gray-900"><%= length(@design.elements || []) %></p>
              </div>
            </div>
          </div>

          <!-- Configuration Panel -->
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-6">Configuración</h3>

            <!-- Design Info -->
            <div class="bg-indigo-50 rounded-xl p-4 mb-6">
              <h4 class="font-semibold text-indigo-900"><%= @design.name %></h4>
              <p class="text-sm text-indigo-700 mt-1"><%= @design.description || "Sin descripción" %></p>
            </div>

            <!-- Quantity -->
            <div class="mb-6">
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Cantidad de etiquetas
              </label>
              <div class="flex items-center space-x-4">
                <button
                  phx-click="update_quantity"
                  phx-value-quantity={@quantity - 1}
                  disabled={@quantity <= 1}
                  class={"w-12 h-12 rounded-xl flex items-center justify-center transition #{if @quantity <= 1, do: "bg-gray-100 text-gray-300 cursor-not-allowed", else: "bg-gray-100 text-gray-600 hover:bg-gray-200"}"}
                >
                  <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4" />
                  </svg>
                </button>
                <input
                  type="number"
                  min="1"
                  max="100"
                  value={@quantity}
                  phx-change="update_quantity"
                  name="quantity"
                  class="w-24 text-center text-2xl font-bold border-gray-300 rounded-xl"
                />
                <button
                  phx-click="update_quantity"
                  phx-value-quantity={@quantity + 1}
                  disabled={@quantity >= 100}
                  class={"w-12 h-12 rounded-xl flex items-center justify-center transition #{if @quantity >= 100, do: "bg-gray-100 text-gray-300 cursor-not-allowed", else: "bg-gray-100 text-gray-600 hover:bg-gray-200"}"}
                >
                  <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                </button>
              </div>
              <p class="mt-2 text-sm text-gray-500">Máximo 100 etiquetas por impresión</p>
            </div>

            <!-- Quick quantity buttons -->
            <div class="flex flex-wrap gap-2 mb-8">
              <%= for qty <- [1, 5, 10, 25, 50, 100] do %>
                <button
                  phx-click="update_quantity"
                  phx-value-quantity={qty}
                  class={"px-4 py-2 rounded-lg text-sm font-medium transition #{if @quantity == qty, do: "bg-indigo-600 text-white", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
                >
                  <%= qty %>
                </button>
              <% end %>
            </div>

            <!-- Action Buttons -->
            <div class="space-y-3">
              <button
                phx-click="print"
                disabled={@printing}
                class={"w-full py-4 rounded-xl font-medium transition flex items-center justify-center space-x-2 #{if @printing, do: "bg-gray-400 cursor-not-allowed", else: "bg-indigo-600 hover:bg-indigo-700"} text-white"}
              >
                <%= if @printing do %>
                  <svg class="animate-spin w-5 h-5" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  <span>Generando...</span>
                <% else %>
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z" />
                  </svg>
                  <span>Imprimir <%= @quantity %> etiqueta<%= if @quantity > 1, do: "s", else: "" %></span>
                <% end %>
              </button>

              <div class="flex items-center justify-center gap-3">
                <button phx-click="download_pdf" class="flex-1 py-3 rounded-xl font-medium transition flex items-center justify-center gap-2 border-2 border-gray-200 text-gray-700 hover:bg-gray-50 hover:border-gray-300">
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  <span>PDF</span>
                </button>
                <button phx-click="download_zpl" class="flex-1 py-3 rounded-xl font-medium transition flex items-center justify-center gap-2 border-2 border-gray-200 text-gray-700 hover:bg-gray-50 hover:border-gray-300">
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                  </svg>
                  <span>ZPL <span class="text-gray-400 text-sm"><%= @zpl_dpi %> dpi</span></span>
                </button>
              </div>

              <.link
                navigate={~p"/designs/#{@design.id}/edit"}
                class="w-full py-4 rounded-xl font-medium transition flex items-center justify-center space-x-2 border-2 border-indigo-200 text-indigo-700 hover:bg-indigo-50 hover:border-indigo-300"
              >
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
                <span>Editar en Canvas</span>
              </.link>
            </div>
          </div>
        </div>

        <!-- Back link -->
        <div class="mt-8">
          <.back navigate={~p"/generate/single"}>Elegir otro diseño</.back>
        </div>
      </div>
    </div>
    """
  end
end
