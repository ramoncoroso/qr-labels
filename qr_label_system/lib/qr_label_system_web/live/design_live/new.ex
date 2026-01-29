defmodule QrLabelSystemWeb.DesignLive.New do
  use QrLabelSystemWeb, :live_view

  import Plug.CSRFProtection, only: [get_csrf_token: 0]

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Designs.Design

  @impl true
  def mount(_params, _session, socket) do
    changeset = Designs.change_design(%Design{})

    {:ok,
     socket
     |> assign(:page_title, "Nuevo Diseño")
     |> assign(:design, %Design{})
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"design" => design_params}, socket) do
    changeset =
      socket.assigns.design
      |> Designs.change_design(design_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"design" => design_params}, socket) do
    design_params = Map.put(design_params, "user_id", socket.assigns.current_user.id)

    case Designs.create_design(design_params) do
      {:ok, design} ->
        {:noreply,
         socket
         |> put_flash(:info, "Diseño creado exitosamente")
         |> push_navigate(to: ~p"/designs/#{design.id}/edit")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Nuevo Diseño
        <:subtitle>Define las dimensiones básicas de tu etiqueta</:subtitle>
      </.header>

      <div class="mt-8 max-w-2xl">
        <.simple_form
          for={@form}
          id="design-form"
          phx-change="validate"
          phx-submit="save"
          action={~p"/designs/new"}
          method="post"
        >
          <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
          <.input field={@form[:name]} type="text" label="Nombre del diseño" required />
          <.input field={@form[:description]} type="textarea" label="Descripción" />

          <div class="grid grid-cols-2 gap-4">
            <.input field={@form[:width_mm]} type="number" label="Ancho (mm)" step="0.1" min="1" max="500" required />
            <.input field={@form[:height_mm]} type="number" label="Alto (mm)" step="0.1" min="1" max="500" required />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <.input field={@form[:background_color]} type="color" label="Color de fondo" value="#FFFFFF" />
            <.input field={@form[:border_width]} type="number" label="Grosor del borde (mm)" step="0.1" min="0" value="0" />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <.input field={@form[:border_color]} type="color" label="Color del borde" value="#000000" />
            <.input field={@form[:border_radius]} type="number" label="Radio del borde (mm)" step="0.1" min="0" value="0" />
          </div>

          <.input field={@form[:is_template]} type="checkbox" label="Guardar como plantilla reutilizable" />

          <:actions>
            <.link navigate={~p"/designs"} class="text-sm text-gray-600 hover:text-gray-900">
              Cancelar
            </.link>
            <.button phx-disable-with="Guardando...">Crear Diseño</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end
end
