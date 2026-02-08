defmodule QrLabelSystemWeb.DesignLive.Index do
  use QrLabelSystemWeb, :live_view

  import QrLabelSystemWeb.DesignComponents

  alias QrLabelSystem.Designs
  alias QrLabelSystem.UploadDataStore

  @max_file_size 5 * 1024 * 1024

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    designs = Designs.list_user_designs(user_id) |> Designs.preload_tags()
    tags = Designs.list_user_tags(user_id)

    {:ok,
     socket
     |> assign(:all_designs, designs)
     |> assign(:has_designs, length(designs) > 0)
     |> assign(:page_title, "Mis diseños")
     |> assign(:import_error, nil)
     |> assign(:renaming_id, nil)
     |> assign(:rename_value, "")
     |> assign(:editing_desc_id, nil)
     |> assign(:desc_value, "")
     |> assign(:show_data_modal, false)
     |> assign(:pending_edit_design, nil)
     |> assign(:filter, "all")
     # Tag state
     |> assign(:tags, tags)
     |> assign(:active_tag_ids, [])
     |> assign(:tag_input, "")
     |> assign(:tag_suggestions, [])
     |> assign(:tagging_design_id, nil)
     # Import modal state
     |> assign(:show_import_modal, false)
     |> assign(:import_preview_designs, [])
     |> assign(:import_selected_ids, MapSet.new())
     |> assign(:import_filename, nil)
     |> assign(:import_file_content, nil)
     |> allow_upload(:backup_file,
       accept: ~w(.json),
       max_entries: 1,
       max_file_size: @max_file_size,
       auto_upload: true,
       progress: &__MODULE__.handle_progress/3
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
        updated_all = Enum.reject(socket.assigns.all_designs, &(&1.id == design.id))
        {:noreply,
         socket
         |> assign(:all_designs, updated_all)
         |> assign(:has_designs, length(updated_all) > 0)
         |> stream_delete(:designs, design)}

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
            updated_all = [new_design | socket.assigns.all_designs]
            socket = socket
              |> assign(:all_designs, updated_all)
              |> put_flash(:info, "Diseño duplicado exitosamente")

            if should_show_design?(new_design, socket.assigns.filter) do
              {:noreply, stream_insert(socket, :designs, new_design, at: 0)}
            else
              {:noreply, socket}
            end

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Error al duplicar el diseño")}
        end
    end
  end

  @impl true
  def handle_event("start_rename", %{"id" => id, "name" => name}, socket) do
    {id_int, ""} = Integer.parse(id)
    design = find_design(socket.assigns.all_designs, id_int)
    {:noreply,
     socket
     |> assign(:renaming_id, id)
     |> assign(:rename_value, name)
     |> stream_insert(:designs, design)}
  end

  @impl true
  def handle_event("cancel_rename", _params, socket) do
    old_id = socket.assigns.renaming_id
    design = if old_id do
      {id_int, ""} = Integer.parse(old_id)
      find_design(socket.assigns.all_designs, id_int)
    end
    socket = socket
     |> assign(:renaming_id, nil)
     |> assign(:rename_value, "")
    socket = if design, do: stream_insert(socket, :designs, design), else: socket
    {:noreply, socket}
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
            updated_design = Designs.preload_tags(updated_design)
            updated_all = Enum.map(socket.assigns.all_designs, fn d ->
              if d.id == updated_design.id, do: updated_design, else: d
            end)
            {:noreply,
             socket
             |> assign(:all_designs, updated_all)
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
  def handle_event("start_edit_desc", %{"id" => id, "desc" => desc}, socket) do
    {id_int, ""} = Integer.parse(id)
    design = find_design(socket.assigns.all_designs, id_int)
    {:noreply,
     socket
     |> assign(:editing_desc_id, id)
     |> assign(:desc_value, desc)
     |> stream_insert(:designs, design)}
  end

  @impl true
  def handle_event("cancel_edit_desc", _params, socket) do
    old_id = socket.assigns.editing_desc_id
    design = if old_id do
      {id_int, ""} = Integer.parse(old_id)
      find_design(socket.assigns.all_designs, id_int)
    end
    socket = socket
     |> assign(:editing_desc_id, nil)
     |> assign(:desc_value, "")
    socket = if design, do: stream_insert(socket, :designs, design), else: socket
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_desc", %{"value" => value}, socket) do
    {:noreply, assign(socket, :desc_value, value)}
  end

  @impl true
  def handle_event("save_desc", %{"id" => id}, socket) do
    new_desc = String.trim(socket.assigns.desc_value)

    case Designs.get_design(id) do
      nil ->
        {:noreply,
         socket
         |> assign(:editing_desc_id, nil)
         |> assign(:desc_value, "")
         |> put_flash(:error, "El diseño ya no existe")}

      design when design.user_id == socket.assigns.current_user.id ->
        case Designs.update_design(design, %{description: new_desc}) do
          {:ok, updated_design} ->
            updated_design = Designs.preload_tags(updated_design)
            updated_all = Enum.map(socket.assigns.all_designs, fn d ->
              if d.id == updated_design.id, do: updated_design, else: d
            end)
            {:noreply,
             socket
             |> assign(:all_designs, updated_all)
             |> assign(:editing_desc_id, nil)
             |> assign(:desc_value, "")
             |> stream_insert(:designs, updated_design)}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Error al actualizar la descripción")}
        end

      _design ->
        {:noreply,
         socket
         |> assign(:editing_desc_id, nil)
         |> assign(:desc_value, "")}
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
  def handle_event("toggle_import_selection", %{"index" => index_str}, socket) do
    {index, ""} = Integer.parse(index_str)
    selected = socket.assigns.import_selected_ids

    new_selected =
      if MapSet.member?(selected, index) do
        MapSet.delete(selected, index)
      else
        MapSet.put(selected, index)
      end

    {:noreply, assign(socket, :import_selected_ids, new_selected)}
  end

  @impl true
  def handle_event("toggle_all_import", _params, socket) do
    designs = socket.assigns.import_preview_designs
    selected = socket.assigns.import_selected_ids
    all_ids = MapSet.new(0..(length(designs) - 1))

    new_selected =
      if MapSet.size(selected) == length(designs) do
        MapSet.new()
      else
        all_ids
      end

    {:noreply, assign(socket, :import_selected_ids, new_selected)}
  end

  @impl true
  def handle_event("cancel_import", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_import_modal, false)
     |> assign(:import_preview_designs, [])
     |> assign(:import_selected_ids, MapSet.new())
     |> assign(:import_filename, nil)
     |> assign(:import_file_content, nil)}
  end

  @impl true
  def handle_event("confirm_import", _params, socket) do
    user_id = socket.assigns.current_user.id
    designs = socket.assigns.import_preview_designs
    selected_ids = socket.assigns.import_selected_ids

    selected_designs =
      designs
      |> Enum.with_index()
      |> Enum.filter(fn {_design, idx} -> MapSet.member?(selected_ids, idx) end)
      |> Enum.map(fn {design, _idx} -> design end)

    case Designs.import_designs_list(selected_designs, user_id) do
      {:ok, imported_designs} ->
        {:noreply,
         socket
         |> assign(:show_import_modal, false)
         |> assign(:import_preview_designs, [])
         |> assign(:import_selected_ids, MapSet.new())
         |> assign(:import_filename, nil)
         |> assign(:import_file_content, nil)
         |> put_flash(:info, "#{length(imported_designs)} diseños importados correctamente")
         |> push_navigate(to: ~p"/designs")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:show_import_modal, false)
         |> put_flash(:error, "Error al importar: #{reason}")}
    end
  end

  @impl true
  def handle_event("import_backup", _params, socket) do
    {:noreply, socket}
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
        {:noreply, push_navigate(socket, to: ~p"/designs/#{design.id}/edit")}
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

  # ==========================================
  # TYPE FILTER
  # ==========================================

  @impl true
  def handle_event("filter", %{"type" => filter_type}, socket) do
    filtered_designs = apply_filters(
      socket.assigns.all_designs,
      filter_type,
      socket.assigns.active_tag_ids
    )

    {:noreply,
     socket
     |> assign(:filter, filter_type)
     |> stream(:designs, filtered_designs, reset: true)}
  end

  # ==========================================
  # TAG FILTER EVENTS
  # ==========================================

  @impl true
  def handle_event("toggle_tag_filter", %{"id" => tag_id_str}, socket) do
    {tag_id, ""} = Integer.parse(tag_id_str)
    active = socket.assigns.active_tag_ids

    new_active =
      if tag_id in active do
        List.delete(active, tag_id)
      else
        [tag_id | active]
      end

    filtered = apply_filters(socket.assigns.all_designs, socket.assigns.filter, new_active)

    {:noreply,
     socket
     |> assign(:active_tag_ids, new_active)
     |> stream(:designs, filtered, reset: true)}
  end

  @impl true
  def handle_event("clear_tag_filters", _params, socket) do
    filtered = apply_filters(socket.assigns.all_designs, socket.assigns.filter, [])

    {:noreply,
     socket
     |> assign(:active_tag_ids, [])
     |> stream(:designs, filtered, reset: true)}
  end

  # ==========================================
  # TAG INLINE INPUT EVENTS
  # ==========================================

  @impl true
  def handle_event("open_tag_input", %{"id" => design_id}, socket) do
    {id_int, ""} = Integer.parse(design_id)
    design = find_design(socket.assigns.all_designs, id_int)

    {:noreply,
     socket
     |> assign(:tagging_design_id, design_id)
     |> assign(:tag_input, "")
     |> assign(:tag_suggestions, [])
     |> stream_insert(:designs, design)}
  end

  @impl true
  def handle_event("close_tag_input", _params, socket) do
    prev_id = socket.assigns.tagging_design_id
    socket = socket
      |> assign(:tagging_design_id, nil)
      |> assign(:tag_input, "")
      |> assign(:tag_suggestions, [])

    # Re-render the previously open design to show the button again
    socket =
      if prev_id do
        {id_int, ""} = Integer.parse(prev_id)
        design = find_design(socket.assigns.all_designs, id_int)
        stream_insert(socket, :designs, design)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("tag_input_change", %{"value" => value}, socket) do
    user_id = socket.assigns.current_user.id
    value = String.trim(value)

    suggestions =
      if value != "" do
        Designs.search_user_tags(user_id, value)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:tag_input, value)
     |> assign(:tag_suggestions, suggestions)}
  end

  @impl true
  def handle_event("add_tag_to_design", %{"design-id" => design_id_str}, socket) do
    tag_name = String.trim(socket.assigns.tag_input)

    if tag_name == "" do
      {:noreply, socket}
    else
      do_add_tag(socket, design_id_str, tag_name)
    end
  end

  @impl true
  def handle_event("select_tag_suggestion", %{"id" => tag_id_str, "design-id" => design_id_str}, socket) do
    {tag_id_int, ""} = Integer.parse(tag_id_str)
    {design_id, ""} = Integer.parse(design_id_str)
    tag = Designs.get_tag!(tag_id_int)
    design = find_design(socket.assigns.all_designs, design_id)

    case Designs.add_tag_to_design(design, tag) do
      {:ok, updated_design} ->
        {:noreply, update_design_in_state(socket, updated_design)}

      _ ->
        {:noreply, put_flash(socket, :error, "Error al asignar tag")}
    end
  end

  @impl true
  def handle_event("remove_tag_from_design", %{"design-id" => design_id_str, "tag-id" => tag_id_str}, socket) do
    {design_id, ""} = Integer.parse(design_id_str)
    {tag_id, ""} = Integer.parse(tag_id_str)
    design = find_design(socket.assigns.all_designs, design_id)

    case Designs.remove_tag_from_design(design, tag_id) do
      {:ok, updated_design} ->
        updated_all = Enum.map(socket.assigns.all_designs, fn d ->
          if d.id == updated_design.id, do: updated_design, else: d
        end)

        tags = Designs.list_user_tags(socket.assigns.current_user.id)
        filtered = apply_filters(updated_all, socket.assigns.filter, socket.assigns.active_tag_ids)

        {:noreply,
         socket
         |> assign(:all_designs, updated_all)
         |> assign(:tags, tags)
         |> stream(:designs, filtered, reset: true)}

      _ ->
        {:noreply, put_flash(socket, :error, "Error al remover tag")}
    end
  end

  # ==========================================
  # UPLOAD PROGRESS CALLBACK
  # ==========================================

  def handle_progress(:backup_file, entry, socket) do
    if entry.done? do
      [content] =
        consume_uploaded_entries(socket, :backup_file, fn %{path: path}, _entry ->
          {:ok, File.read!(path)}
        end)

      case parse_import_file(content) do
        {:ok, designs} ->
          selected_ids = MapSet.new(0..(length(designs) - 1))
          {:noreply,
           socket
           |> assign(:show_import_modal, true)
           |> assign(:import_preview_designs, designs)
           |> assign(:import_selected_ids, selected_ids)
           |> assign(:import_filename, entry.client_name)
           |> assign(:import_file_content, content)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Error al leer el archivo: #{reason}")}
      end
    else
      {:noreply, socket}
    end
  end

  # ==========================================
  # PRIVATE HELPERS
  # ==========================================

  defp parse_import_file(content) do
    case Jason.decode(content) do
      {:ok, %{"type" => "backup", "designs" => designs}} when is_list(designs) ->
        {:ok, designs}

      {:ok, %{"design" => design}} ->
        {:ok, [design]}

      {:ok, _} ->
        {:error, "Formato de archivo no reconocido"}

      {:error, _} ->
        {:error, "JSON inválido"}
    end
  end

  defp do_add_tag(socket, design_id_str, tag_name) do
    user_id = socket.assigns.current_user.id
    {design_id, ""} = Integer.parse(design_id_str)
    design = find_design(socket.assigns.all_designs, design_id)

    case Designs.find_or_create_tag(user_id, tag_name) do
      {:ok, tag} ->
        case Designs.add_tag_to_design(design, tag) do
          {:ok, updated_design} ->
            {:noreply, update_design_in_state(socket, updated_design)}

          _ ->
            {:noreply, put_flash(socket, :error, "Error al asignar tag")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al crear tag")}
    end
  end

  defp update_design_in_state(socket, updated_design) do
    updated_all = Enum.map(socket.assigns.all_designs, fn d ->
      if d.id == updated_design.id, do: updated_design, else: d
    end)

    tags = Designs.list_user_tags(socket.assigns.current_user.id)
    filtered = apply_filters(updated_all, socket.assigns.filter, socket.assigns.active_tag_ids)

    socket
    |> assign(:all_designs, updated_all)
    |> assign(:tags, tags)
    |> assign(:tagging_design_id, nil)
    |> assign(:tag_input, "")
    |> assign(:tag_suggestions, [])
    |> stream(:designs, filtered, reset: true)
  end

  defp find_design(all_designs, design_id) do
    Enum.find(all_designs, fn d -> d.id == design_id end)
  end

  defp apply_filters(designs, type_filter, active_tag_ids) do
    designs
    |> filter_designs(type_filter)
    |> filter_by_tags(active_tag_ids)
  end

  defp filter_designs(designs, "all"), do: designs
  defp filter_designs(designs, "single"), do: Enum.filter(designs, &(&1.label_type == "single"))
  defp filter_designs(designs, "multiple"), do: Enum.filter(designs, &(&1.label_type == "multiple"))

  defp filter_by_tags(designs, []), do: designs
  defp filter_by_tags(designs, active_tag_ids) do
    Enum.filter(designs, fn design ->
      design_tag_ids = Enum.map(design.tags, & &1.id)
      Enum.all?(active_tag_ids, &(&1 in design_tag_ids))
    end)
  end

  defp count_by_type(designs, type) do
    Enum.count(designs, &(&1.label_type == type))
  end

  defp should_show_design?(_design, "all"), do: true
  defp should_show_design?(design, filter), do: design.label_type == filter

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Mis diseños
        <:subtitle>Pulsa sobre un diseño para editarlo en el canvas. Usa los botones para duplicar o eliminar.</:subtitle>
        <:actions>
          <div class="flex items-center gap-2">
            <!-- Import Button -->
            <form phx-change="validate_import" class="contents">
              <label class="cursor-pointer inline-flex items-center gap-2 px-4 py-2 rounded-lg border border-gray-300 bg-white hover:bg-gray-50 text-sm font-medium text-gray-700 transition">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                </svg>
                <span>Importar</span>
                <.live_file_input upload={@uploads.backup_file} class="sr-only" />
              </label>
            </form>
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

      <div class="mt-6">
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

        <!-- Filter Tabs + Tag Chips (same row) -->
        <div :if={@has_designs} class="mb-4 border-b border-gray-200 flex items-end justify-between gap-4">
          <nav class="-mb-px flex space-x-6 flex-shrink-0" aria-label="Tabs">
            <button
              phx-click="filter"
              phx-value-type="all"
              class={"whitespace-nowrap py-3 px-1 border-b-2 font-medium text-sm transition-colors #{if @filter == "all", do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              Todas
              <span class={"ml-2 py-0.5 px-2 rounded-full text-xs #{if @filter == "all", do: "bg-blue-100 text-blue-600", else: "bg-gray-100 text-gray-600"}"}>
                <%= length(@all_designs) %>
              </span>
            </button>
            <button
              phx-click="filter"
              phx-value-type="single"
              class={"whitespace-nowrap py-3 px-1 border-b-2 font-medium text-sm transition-colors #{if @filter == "single", do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              <span class="inline-flex items-center gap-1.5">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
                </svg>
                Únicas
              </span>
              <span class={"ml-2 py-0.5 px-2 rounded-full text-xs #{if @filter == "single", do: "bg-blue-100 text-blue-600", else: "bg-gray-100 text-gray-600"}"}>
                <%= count_by_type(@all_designs, "single") %>
              </span>
            </button>
            <button
              phx-click="filter"
              phx-value-type="multiple"
              class={"whitespace-nowrap py-3 px-1 border-b-2 font-medium text-sm transition-colors #{if @filter == "multiple", do: "border-blue-500 text-blue-600", else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"}"}
            >
              <span class="inline-flex items-center gap-1.5">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 01-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75a9.06 9.06 0 011.5.124m7.5 10.376h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 00-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 01-1.125-1.125v-9.25m12 6.625v-1.875a3.375 3.375 0 00-3.375-3.375h-1.5a1.125 1.125 0 01-1.125-1.125v-1.5a3.375 3.375 0 00-3.375-3.375H9.75" />
                </svg>
                Múltiples
              </span>
              <span class={"ml-2 py-0.5 px-2 rounded-full text-xs #{if @filter == "multiple", do: "bg-blue-100 text-blue-600", else: "bg-gray-100 text-gray-600"}"}>
                <%= count_by_type(@all_designs, "multiple") %>
              </span>
            </button>
          </nav>
          <!-- Tag Filter Chips -->
          <div :if={@tags != []} class="flex flex-wrap items-center gap-2 pb-2">
            <%= for tag <- @tags do %>
              <button
                phx-click="toggle_tag_filter"
                phx-value-id={tag.id}
                class={"inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium transition-all cursor-pointer border " <>
                  if(tag.id in @active_tag_ids,
                    do: "ring-2 ring-offset-1 ring-blue-400",
                    else: "opacity-75 hover:opacity-100"
                  )}
                style={"background-color: #{tag.color}20; color: #{tag.color}; border-color: #{tag.color}40;"}
              >
                <span class="w-2 h-2 rounded-full" style={"background-color: #{tag.color};"}></span>
                <%= tag.name %>
              </button>
            <% end %>
            <button
              :if={@active_tag_ids != []}
              phx-click="clear_tag_filters"
              class="text-xs text-gray-500 hover:text-gray-700 underline ml-1"
            >
              Limpiar filtros
            </button>
          </div>
        </div>

        <div id="designs" phx-update="stream" class="space-y-4 pb-4">
          <div :for={{dom_id, design} <- @streams.designs} id={dom_id} class="group/card relative bg-white rounded-xl shadow-sm border border-gray-200/80 p-4 hover:shadow-md hover:border-gray-300 transition-all duration-200">
            <div class="flex gap-4">
              <!-- Thumbnail spanning full card height -->
              <.link navigate={~p"/designs/#{design.id}/edit"} class="flex-shrink-0 self-stretch flex items-center cursor-pointer">
                <div class="rounded-lg border border-gray-200 shadow-sm overflow-hidden">
                  <.design_thumbnail design={design} max_width={80} max_height={80} />
                </div>
              </.link>
              <!-- Right content -->
              <div class="min-w-0 flex-1">
                <div class="flex items-center justify-between">
                  <div class="min-w-0 flex-1">
                    <!-- Name row: editable inline -->
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
                      <div class="flex items-center gap-1.5 group/name">
                        <.link navigate={~p"/designs/#{design.id}/edit"} class="min-w-0 after:absolute after:inset-0 after:content-['']">
                          <h3 class="text-base font-semibold text-gray-900 truncate group-hover/card:text-blue-700 transition-colors">
                            <%= design.name %>
                          </h3>
                        </.link>
                        <button
                          type="button"
                          phx-click="start_rename"
                          phx-value-id={design.id}
                          phx-value-name={design.name}
                          class="relative z-10 p-0.5 text-gray-300 hover:text-gray-500 opacity-0 group-hover/card:opacity-100 transition-opacity flex-shrink-0"
                          title="Renombrar"
                        >
                          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                          </svg>
                        </button>
                      </div>
                    <% end %>
                    <!-- Description -->
                    <%= if @editing_desc_id == to_string(design.id) do %>
                      <form phx-submit="save_desc" phx-value-id={design.id} class="flex items-center gap-2 mt-0.5">
                        <input
                          type="text"
                          value={@desc_value}
                          phx-change="update_desc"
                          phx-debounce="100"
                          name="value"
                          autofocus
                          placeholder="Añadir descripción..."
                          class="text-sm text-gray-500 border border-blue-300 rounded-lg px-2 py-0.5 flex-1 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        />
                        <button type="submit" class="p-1 text-green-600 hover:text-green-700">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                          </svg>
                        </button>
                        <button type="button" phx-click="cancel_edit_desc" class="p-1 text-gray-400 hover:text-gray-600">
                          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                          </svg>
                        </button>
                      </form>
                    <% else %>
                      <div class="flex items-center gap-1 group/desc mt-0.5">
                        <%= if design.description && design.description != "" do %>
                          <p class="text-sm text-gray-400 truncate"><%= design.description %></p>
                        <% else %>
                          <p class="text-sm text-gray-300 italic">Sin descripción</p>
                        <% end %>
                        <button
                          type="button"
                          phx-click="start_edit_desc"
                          phx-value-id={design.id}
                          phx-value-desc={design.description || ""}
                          class="relative z-10 p-0.5 text-gray-300 hover:text-gray-500 opacity-0 group-hover/card:opacity-100 transition-opacity flex-shrink-0"
                          title="Editar descripción"
                        >
                          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                          </svg>
                        </button>
                      </div>
                    <% end %>
                    <!-- Info row with tags -->
                    <div class="flex items-center gap-2 flex-wrap mt-0.5">
                      <.link navigate={~p"/designs/#{design.id}/edit"} class="cursor-pointer inline-flex items-center gap-2 text-sm text-gray-500">
                        <span class="inline-flex items-center">
                          <svg class="w-3.5 h-3.5 mr-1 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 3.75v4.5m0-4.5h4.5m-4.5 0L9 9M3.75 20.25v-4.5m0 4.5h4.5m-4.5 0L9 15M20.25 3.75h-4.5m4.5 0v4.5m0-4.5L15 9m5.25 11.25h-4.5m4.5 0v-4.5m0 4.5L15 15" />
                          </svg>
                          <%= design.width_mm %> × <%= design.height_mm %> mm
                        </span>
                        <span class="text-gray-300">·</span>
                        <span><%= if design.label_type == "single", do: "Única", else: "Múltiple" %></span>
                        <%= if design.is_template do %>
                          <span class="text-gray-300">·</span>
                          <span>Plantilla</span>
                        <% end %>
                      </.link>
                      <!-- Tags -->
                      <div class="relative z-10 flex items-center gap-1.5 flex-wrap pointer-events-none [&>*]:pointer-events-auto">
                        <%= for tag <- (design.tags || []) do %>
                          <span
                            class="group/tag inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium"
                            style={"background-color: #{tag.color}20; color: #{tag.color};"}
                          >
                            <%= tag.name %>
                            <button
                              type="button"
                              phx-click="remove_tag_from_design"
                              phx-value-design-id={design.id}
                              phx-value-tag-id={tag.id}
                              class="ml-0.5 opacity-0 group-hover/tag:opacity-100 hover:text-red-500 transition-opacity"
                              title="Quitar tag"
                            >
                              <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                              </svg>
                            </button>
                          </span>
                        <% end %>
                        <%= if to_string(design.id) == @tagging_design_id do %>
                          <div class="relative" phx-click-away="close_tag_input">
                            <form phx-submit="add_tag_to_design" phx-value-design-id={design.id}>
                              <input
                                type="text"
                                value={@tag_input}
                                phx-keyup="tag_input_change"
                                phx-debounce="200"
                                name="value"
                                placeholder="Nombre del tag..."
                                autofocus
                                class="text-xs border border-gray-300 rounded-full px-2.5 py-0.5 w-32 focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                              />
                            </form>
                            <div :if={@tag_suggestions != []} class="absolute z-10 mt-1 w-48 bg-white border border-gray-200 rounded-lg shadow-lg py-1">
                              <%= for suggestion <- @tag_suggestions do %>
                                <button
                                  type="button"
                                  phx-click="select_tag_suggestion"
                                  phx-value-id={suggestion.id}
                                  phx-value-design-id={design.id}
                                  class="w-full text-left px-3 py-1.5 text-sm hover:bg-gray-50 flex items-center gap-2"
                                >
                                  <span class="w-3 h-3 rounded-full flex-shrink-0" style={"background-color: #{suggestion.color};"}></span>
                                  <span class="truncate"><%= suggestion.name %></span>
                                </button>
                              <% end %>
                            </div>
                          </div>
                        <% else %>
                          <button
                            type="button"
                            phx-click="open_tag_input"
                            phx-value-id={design.id}
                            class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 hover:bg-blue-100 text-gray-400 hover:text-blue-500 border border-dashed border-gray-300 hover:border-blue-300 transition"
                          >
                            <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                            </svg>
                            Tag
                          </button>
                        <% end %>
                      </div>
                    </div>
                  </div>

                  <div class="relative z-10 flex items-center gap-2">
                    <!-- Duplicate Button -->
                    <button
                      phx-click="duplicate"
                      phx-value-id={design.id}
                      class="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg bg-purple-50 hover:bg-purple-100 border border-purple-200 hover:border-purple-300 text-purple-700 hover:text-purple-800 text-sm font-medium transition-all duration-200"
                    >
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125 0 01-1.125-1.125V7.875c0-.621.504-1.125 1.125-1.125H6.75a9.06 9.06 0 011.5.124m7.5 10.376h3.375c.621 0 1.125-.504 1.125-1.125V11.25c0-4.46-3.243-8.161-7.5-8.876a9.06 9.06 0 00-1.5-.124H9.375c-.621 0-1.125.504-1.125 1.125v3.5m7.5 10.375H9.375a1.125 1.125 0 01-1.125-1.125v-9.25m12 6.625v-1.875a3.375 3.375 0 00-3.375-3.375h-1.5a1.125 1.125 0 01-1.125-1.125v-1.5a3.375 3.375 0 00-3.375-3.375H9.75" />
                      </svg>
                      Duplicar
                    </button>

                    <!-- Delete Button -->
                    <button
                      phx-click="delete"
                      phx-value-id={design.id}
                      data-confirm="¿Estás seguro de que quieres eliminar este diseño? Esta acción no se puede deshacer."
                      class="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg bg-red-50 hover:bg-red-100 border border-red-200 hover:border-red-300 text-red-600 hover:text-red-700 text-sm font-medium transition-all duration-200"
                    >
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                      </svg>
                      Eliminar
                    </button>
                  </div>
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

      <!-- Import Modal -->
      <div :if={@show_import_modal} class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="import-modal-title" role="dialog" aria-modal="true">
        <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
          <!-- Background overlay -->
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" phx-click="cancel_import"></div>

          <!-- Spacer for centering -->
          <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

          <!-- Modal panel -->
          <div class="inline-block align-bottom bg-white rounded-xl text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
            <div class="bg-white px-6 pt-6 pb-4">
              <!-- Header -->
              <div class="flex items-center justify-between mb-4">
                <div class="flex items-center gap-3">
                  <div class="flex-shrink-0 flex items-center justify-center h-10 w-10 rounded-full bg-blue-100">
                    <svg class="h-5 w-5 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                    </svg>
                  </div>
                  <div>
                    <h3 class="text-lg font-semibold text-gray-900" id="import-modal-title">
                      Importar diseños
                    </h3>
                    <p class="text-sm text-gray-500"><%= @import_filename %></p>
                  </div>
                </div>
                <button phx-click="cancel_import" class="text-gray-400 hover:text-gray-600 transition">
                  <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>

              <!-- Select all checkbox -->
              <div class="flex items-center justify-between py-3 border-b border-gray-200">
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={MapSet.size(@import_selected_ids) == length(@import_preview_designs)}
                    phx-click="toggle_all_import"
                    class="w-4 h-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                  />
                  <span class="text-sm font-medium text-gray-700">Seleccionar todas</span>
                </label>
                <span class="text-sm text-gray-500">
                  <%= MapSet.size(@import_selected_ids) %> de <%= length(@import_preview_designs) %> seleccionadas
                </span>
              </div>

              <!-- Design list -->
              <div class="max-h-64 overflow-y-auto divide-y divide-gray-100">
                <%= for {design, index} <- Enum.with_index(@import_preview_designs) do %>
                  <label class="flex items-center gap-3 py-3 px-1 hover:bg-gray-50 cursor-pointer transition">
                    <input
                      type="checkbox"
                      checked={MapSet.member?(@import_selected_ids, index)}
                      phx-click="toggle_import_selection"
                      phx-value-index={index}
                      class="w-4 h-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
                    />
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-gray-900 truncate">
                        <%= design["name"] || "Sin nombre" %>
                      </p>
                      <p class="text-xs text-gray-500">
                        <%= design["label_type"] || "single" %> · <%= length(design["elements"] || []) %> elementos
                      </p>
                    </div>
                  </label>
                <% end %>
              </div>
            </div>

            <!-- Footer -->
            <div class="bg-gray-50 px-6 py-4 flex justify-end gap-3">
              <button
                phx-click="cancel_import"
                class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition"
              >
                Cancelar
              </button>
              <button
                phx-click="confirm_import"
                disabled={MapSet.size(@import_selected_ids) == 0}
                class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition"
              >
                Importar <%= MapSet.size(@import_selected_ids) %> diseño(s)
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
