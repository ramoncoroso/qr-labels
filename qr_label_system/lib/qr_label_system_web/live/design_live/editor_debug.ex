defmodule QrLabelSystemWeb.DesignLive.EditorDebug do
  @moduledoc "Debug version of editor without authentication - DEV ONLY"
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    design = Designs.get_design!(id)

    # Create a fake user for debug purposes
    fake_user = %{id: 0, email: "debug@test.com", role: :admin}

    {:ok,
     socket
     |> assign(:current_user, fake_user)
     |> assign(:page_title, "Editor DEBUG: #{design.name}")
     |> assign(:design, design)
     |> assign(:selected_element, nil)
     |> assign(:selected_elements, [])
     |> assign(:clipboard, [])
     |> assign(:available_columns, [])
     |> assign(:show_properties, true)
     |> assign(:show_preview, false)
     |> assign(:show_layers, true)
     |> assign(:preview_data, %{"col1" => "Ejemplo 1", "col2" => "Ejemplo 2", "col3" => "12345"})
     |> assign(:history, [])
     |> assign(:history_index, -1)
     |> assign(:has_unsaved_changes, false)
     |> assign(:zoom, 100)
     |> assign(:snap_enabled, true)
     |> assign(:grid_snap_enabled, false)
     |> assign(:grid_size, 5)
     |> assign(:snap_threshold, 5)
     |> allow_upload(:element_image,
       accept: ~w(.png .jpg .jpeg .gif .svg),
       max_entries: 1,
       max_file_size: 2_000_000)}
  end

  # Delegate all other callbacks to the main Editor module
  defdelegate handle_event(event, params, socket), to: QrLabelSystemWeb.DesignLive.Editor
  defdelegate render(assigns), to: QrLabelSystemWeb.DesignLive.Editor
end
