defmodule QrLabelSystemWeb.DesignLive.Index do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs
  alias QrLabelSystem.UploadDataStore

  @max_file_size 5 * 1024 * 1024

  @impl true
  def mount(_params, _session, socket) do
    designs = Designs.list_user_designs(socket.assigns.current_user.id)
    {:ok,
     socket
     |> assign(:has_designs, length(designs) > 0)
     |> assign(:page_title, "Diseños de etiquetas")
     |> assign(:import_error, nil)
     |> assign(:renaming_id, nil)
     |> assign(:rename_value, "")
     |> assign(:show_data_modal, false)
     |> assign(:pending_edit_design, nil)
     |> allow_upload(:backup_file,
       accept: ~w(.json),
       max_entries: 1,
       max_file_size: @max_file_size
     )
     |> stream(:designs, designs)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Designs.get_design(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "El diseño ya no existe")}

      design when design.user_id == socket.assigns.current_user.id ->
        {:ok, _} = Designs.delete_design(design)
        {:noreply, stream_delete(socket, :designs, design)}

      _design ->
        {:noreply, put_flash(socket, :error, "No tienes permiso para eliminar este diseño")}
    end
  end

  @impl true
  def handle_event("duplicate", %{"id" => id}, socket) do
    case Designs.get_design(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "El diseño ya no existe")}

      design ->
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
  end

  @impl true
  def handle_event("start_rename", %{"id" => id, "name" => name}, socket) do
    {:noreply,
     socket
     |> assign(:renaming_id, id)
     |> assign(:rename_value, name)}
  end

  @impl true
  def handle_event("cancel_rename", _params, socket) do
    {:noreply,
     socket
     |> assign(:renaming_id, nil)
     |> assign(:rename_value, "")}
  end

  @impl true
  def handle_event("update_rename", %{"value" => value}, socket) do
    {:noreply, assign(socket, :rename_value, value)}
  end

  @impl true
  def handle_event("save_rename", %{"id" => id}, socket) do
    new_name = String.trim(socket.assigns.rename_value)

    case Designs.get_design(id) do
      nil ->
        {:noreply,
         socket
         |> assign(:renaming_id, nil)
         |> assign(:rename_value, "")
         |> put_flash(:error, "El diseño ya no existe")}

      design when design.user_id == socket.assigns.current_user.id and new_name != "" ->
        case Designs.update_design(design, %{name: new_name}) do
          {:ok, updated_design} ->
            {:noreply,
             socket
             |> assign(:renaming_id, nil)
             |> assign(:rename_value, "")
             |> stream_insert(:designs, updated_design)}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Error al renombrar el diseño")}
        end

      _design ->
        {:noreply,
         socket
         |> assign(:renaming_id, nil)
         |> assign(:rename_value, "")}
    end
  end

  @impl true
  def handle_event("export_all", _params, socket) do
    designs = Designs.list_user_designs(socket.assigns.current_user.id)
    json = Designs.export_all_designs_to_json(designs)
    date = Date.utc_today() |> Date.to_iso8601()

    {:noreply,
     push_event(socket, "download_file", %{
       content: json,
       filename: "qr_label_designs_backup_#{date}.json",
       mime_type: "application/json"
     })}
  end

  @impl true
  def handle_event("validate_import", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("import_backup", _params, socket) do
    user_id = socket.assigns.current_user.id

    uploaded_files =
      consume_uploaded_entries(socket, :backup_file, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    case uploaded_files do
      [content] ->
        case Designs.import_designs_from_json(content, user_id) do
          {:ok, imported_designs} ->
            {:noreply,
             socket
             |> put_flash(:info, "#{length(imported_designs)} diseños importados correctamente")
             |> push_navigate(to: ~p"/designs")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:import_error, reason)
             |> put_flash(:error, "Error al importar: #{reason}")}
        end

      [] ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_design", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case Designs.get_design(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "El diseño ya no existe")}

      design when design.user_id != user_id ->
        {:noreply, put_flash(socket, :error, "No tienes permiso para editar este diseño")}

      design ->
        # For single designs, navigate directly to editor
        if design.label_type == "single" do
          {:noreply, push_navigate(socket, to: ~p"/designs/#{design.id}/edit")}
        else
          # For multiple designs, check if data exists
          if UploadDataStore.has_data?(user_id, design.id) do
            # Show modal asking whether to use existing or load new
            {:noreply,
             socket
             |> assign(:show_data_modal, true)
             |> assign(:pending_edit_design, design)}
          else
            # No data, redirect to data loading
            {:noreply, push_navigate(socket, to: ~p"/generate/data/#{design.id}")}
          end
        end
    end
  end

  @impl true
  def handle_event("use_existing_data", _params, socket) do
    design = socket.assigns.pending_edit_design

    {:noreply,
     socket
     |> assign(:show_data_modal, false)
     |> assign(:pending_edit_design, nil)
     |> push_navigate(to: ~p"/designs/#{design.id}/edit")}
  end

  @impl true
  def handle_event("load_new_data", _params, socket) do
    design = socket.assigns.pending_edit_design
    user_id = socket.assigns.current_user.id

    # Clear existing data for this design
    UploadDataStore.clear(user_id, design.id)

    {:noreply,
     socket
     |> assign(:show_data_modal, false)
     |> assign(:pending_edit_design, nil)
     |> push_navigate(to: ~p"/generate/data/#{design.id}")}
  end

  @impl true
  def handle_event("close_data_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_data_modal, false)
     |> assign(:pending_edit_design, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Diseños de etiquetas
        <:subtitle>Crea y administra tus diseños de etiquetas personalizadas</:subtitle>
        <:actions>
          <div class="flex items-center gap-2">
            <!-- Import Button -->
            <div class="relative">
              <form phx-submit="import_backup" phx-change="validate_import" class="flex items-center">
                <label class="cursor-pointer inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-gray-300 bg-white hover:bg-gray-50 text-sm font-medium text-gray-700 transition">
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                  </svg>
                  <span>Importar</span>
                  <.live_file_input upload={@uploads.backup_file} class="sr-only" />
                </label>
                <%= for entry <- @uploads.backup_file.entries do %>
                  <div class="ml-2 flex items-center gap-2">
                    <span class="text-sm text-gray-600"><%= entry.client_name %></span>
                    <button type="submit" class="px-3 py-1 bg-indigo-600 text-white text-sm rounded-lg hover:bg-indigo-700">
                      Cargar
                    </button>
                  </div>
                <% end %>
              </form>
            </div>
            <!-- Export Button -->
            <button
              :if={@has_designs}
              phx-click="export_all"
              class="inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-gray-300 bg-white hover:bg-gray-50 text-sm font-medium text-gray-700 transition"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
              </svg>
              <span>Exportar todo</span>
            </button>
          </div>
        </:actions>
      </.header>

      <div class="mt-8">
        <!-- Add New Design Card -->
        <.link navigate={~p"/generate"} class="group block mb-6 bg-gradient-to-br from-gray-50 to-gray-100/50 rounded-xl border-2 border-dashed border-gray-300 hover:border-blue-400 hover:from-blue-50 hover:to-indigo-50/50 p-5 transition-all duration-300 hover:shadow-lg hover:shadow-blue-100/50">
          <div class="flex items-center space-x-4">
            <div class="w-14 h-14 rounded-xl bg-white shadow-sm border border-gray-200 group-hover:border-blue-200 group-hover:shadow-md group-hover:shadow-blue-100/50 flex items-center justify-center transition-all duration-300">
              <svg class="w-7 h-7 text-gray-400 group-hover:text-blue-500 transition-colors duration-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-semibold text-gray-700 group-hover:text-blue-700 transition-colors">Nuevo Diseño</h3>
              <p class="text-sm text-gray-500 group-hover:text-blue-600/70 transition-colors">Crea una nueva plantilla de etiqueta</p>
            </div>
            <div class="flex-1"></div>
            <div class="w-10 h-10 rounded-full bg-white shadow-sm border border-gray-200 group-hover:bg-blue-500 group-hover:border-blue-500 flex items-center justify-center transition-all duration-300 opacity-0 group-hover:opacity-100">
              <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3" />
              </svg>
            </div>
          </div>
        </.link>

        <div id="designs" phx-update="stream" class="space-y-4 pb-4">
          <div :for={{dom_id, design} <- @streams.designs} id={dom_id} class="group/card bg-white rounded-xl shadow-sm border border-gray-200/80 p-4 hover:shadow-md hover:border-gray-300 transition-all duration-200">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-4">
                <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-blue-500 to-indigo-600 shadow-lg shadow-blue-500/25 flex items-center justify-center">
                  <svg class="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" />
                  </svg>
                </div>
                <div class="min-w-0 flex-1">
                  <%= if @renaming_id == design.id do %>
                    <form phx-submit="save_rename" phx-value-id={design.id} class="flex items-center gap-2">
                      <input
                        type="text"
                        value={@rename_value}
                        phx-change="update_rename"
                        phx-debounce="100"
                        name="value"
                        autofocus
                        class="text-base font-semibold text-gray-900 border border-blue-300 rounded-lg px-2 py-1 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      />
                      <button type="submit" class="p-1 text-green-600 hover:text-green-700">
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                        </svg>
                      </button>
                      <button type="button" phx-click="cancel_rename" class="p-1 text-gray-400 hover:text-gray-600">
                        <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    </form>
                  <% else %>
                    <h3 class="text-base font-semibold text-gray-900 truncate group-hover/card:text-blue-700 transition-colors">
                      <%= design.name %>
                    </h3>
                  <% end %>
                  <p class="text-sm text-gray-500 flex items-center gap-2">
                    <span class="inline-flex items-center">
                      <svg class="w-3.5 h-3.5 mr-1 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15" />
                      </svg>
                      <%= design.width_mm %> × <%= design.height_mm %> mm
                    </span>
                    <span class="text-gray-300">·</span>
                    <span class="inline-flex items-center">
                      <svg class="w-3.5 h-3.5 mr-1 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6.429 9.75L2.25 12l4.179 2.25m0-4.5l5.571 3 5.571-3m-11.142 0L2.25 7.5 12 2.25l9.75 5.25-4.179 2.25m0 0L12 12.75l-5.571-3m11.142 0l4.179 2.25L12 17.25l-9.75-5.25 4.179-2.25m11.142 0l4.179 2.25-4.179 2.25m0-4.5v4.5" />
                      </svg>
                      <%= length(design.elements || []) %> elementos
                    </span>
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-3">
                <%= if design.is_template do %>
                  <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-gradient-to-r from-amber-50 to-orange-50 text-amber-700 border border-amber-200/50 shadow-sm">
                    <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10.868 2.884c-.321-.772-1.415-.772-1.736 0l-1.83 4.401-4.753.381c-.833.067-1.171 1.107-.536 1.651l3.62 3.102-1.106 4.637c-.194.813.691 1.456 1.405 1.02L10 15.591l4.069 2.485c.713.436 1.598-.207 1.404-1.02l-1.106-4.637 3.62-3.102c.635-.544.297-1.584-.536-1.65l-4.752-.382-1.831-4.401z" clip-rule="evenodd" />
                    </svg>
                    Plantilla
                  </span>
                <% end %>

                <div class="flex items-center gap-2">
                  <!-- Edit Button - Primary Action -->
                  <button
                    phx-click="edit_design"
                    phx-value-id={design.id}
                    class="group relative inline-flex items-center justify-center w-10 h-10 rounded-lg bg-blue-50 hover:bg-blue-100 border border-blue-200 hover:border-blue-300 transition-all duration-200 hover:shadow-sm"
                  >
                    <svg class="w-5 h-5 text-blue-600 group-hover:text-blue-700 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125" />
                    </svg>
                    <span class="sr-only">Editar</span>
                    <span class="absolute -bottom-9 left-1/2 -translate-x-1/2 px-2 py-1 bg-gray-900 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none z-10">
                      Editar
                    </span>
                  </button>

                  <!-- Preview Button -->
                  <.link
                    navigate={~p"/designs/#{design.id}"}
                    class="group relative inline-flex items-center justify-center w-10 h-10 rounded-lg bg-gray-50 hover:bg-indigo-50 border border-gray-200 hover:border-indigo-300 transition-all duration-200 hover:shadow-sm"
                  >
                    <svg class="w-5 h-5 text-gray-500 group-hover:text-indigo-600 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    <span class="sr-only">Vista previa</span>
                    <span class="absolute -bottom-9 left-1/2 -translate-x-1/2 px-2 py-1 bg-gray-900 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none z-10">
                      Vista previa
                    </span>
                  </.link>

                  <!-- Duplicate Button -->
                  <button
                    phx-click="duplicate"
                    phx-value-id={design.id}
                    class="group relative inline-flex items-center justify-center w-10 h-10 rounded-lg bg-gray-50 hover:bg-emerald-50 border border-gray-200 hover:border-emerald-300 transition-all duration-200 hover:shadow-sm"
                  >
                    <svg class="w-5 h-5 text-gray-500 group-hover:text-emerald-600 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 01-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75a9.06 9.06 0 011.5.124m7.5 10.376h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 00-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 01-1.125-1.125v-9.25m12 6.625v-1.875a3.375 3.375 0 00-3.375-3.375h-1.5a1.125 1.125 0 01-1.125-1.125v-1.5a3.375 3.375 0 00-3.375-3.375H9.75" />
                    </svg>
                    <span class="sr-only">Duplicar</span>
                    <span class="absolute -bottom-9 left-1/2 -translate-x-1/2 px-2 py-1 bg-gray-900 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none z-10">
                      Duplicar
                    </span>
                  </button>

                  <!-- Divider -->
                  <div class="w-px h-8 bg-gray-200 mx-1"></div>

                  <!-- Delete Button -->
                  <button
                    phx-click="delete"
                    phx-value-id={design.id}
                    data-confirm="¿Estás seguro de que quieres eliminar este diseño? Esta acción no se puede deshacer."
                    class="group relative inline-flex items-center justify-center w-10 h-10 rounded-lg bg-gray-50 hover:bg-red-50 border border-gray-200 hover:border-red-300 transition-all duration-200 hover:shadow-sm"
                  >
                    <svg class="w-5 h-5 text-gray-400 group-hover:text-red-500 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                    </svg>
                    <span class="sr-only">Eliminar</span>
                    <span class="absolute -bottom-9 left-1/2 -translate-x-1/2 px-2 py-1 bg-gray-900 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none z-10">
                      Eliminar
                    </span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

      </div>

      <!-- Data Modal for Multiple Designs -->
      <div :if={@show_data_modal && @pending_edit_design} class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
          <!-- Background overlay -->
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" phx-click="close_data_modal"></div>

          <!-- Modal panel -->
          <div class="inline-block align-bottom bg-white rounded-xl text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
            <div class="bg-white px-6 pt-6 pb-4">
              <div class="sm:flex sm:items-start">
                <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-indigo-100 sm:mx-0 sm:h-12 sm:w-12">
                  <svg class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
                  </svg>
                </div>
                <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
                  <h3 class="text-lg leading-6 font-semibold text-gray-900" id="modal-title">
                    Datos existentes detectados
                  </h3>
                  <div class="mt-2">
                    <p class="text-sm text-gray-500">
                      Ya tienes datos cargados para el diseño "<%= @pending_edit_design.name %>".
                      ¿Qué deseas hacer?
                    </p>
                  </div>
                </div>
              </div>
            </div>
            <div class="bg-gray-50 px-6 py-4 sm:flex sm:flex-row-reverse gap-3">
              <button
                phx-click="use_existing_data"
                class="w-full inline-flex justify-center rounded-lg border border-transparent shadow-sm px-4 py-2.5 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:w-auto sm:text-sm transition"
              >
                Usar datos existentes
              </button>
              <button
                phx-click="load_new_data"
                class="mt-3 w-full inline-flex justify-center rounded-lg border border-gray-300 shadow-sm px-4 py-2.5 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:w-auto sm:text-sm transition"
              >
                Cargar nuevos datos
              </button>
              <button
                phx-click="close_data_modal"
                class="mt-3 w-full inline-flex justify-center rounded-lg border border-gray-300 shadow-sm px-4 py-2.5 bg-white text-base font-medium text-gray-500 hover:bg-gray-50 focus:outline-none sm:mt-0 sm:w-auto sm:text-sm transition"
              >
                Cancelar
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
