defmodule QrLabelSystemWeb.DesignLive.FormComponent do
  use QrLabelSystemWeb, :live_component

  alias QrLabelSystem.Designs

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Define las dimensiones básicas de tu etiqueta</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="design-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Nombre del diseño" required />
        <.input field={@form[:description]} type="textarea" label="Descripción" />

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:width_mm]} type="number" label="Ancho (mm)" step="0.1" min="1" max="500" required />
          <.input field={@form[:height_mm]} type="number" label="Alto (mm)" step="0.1" min="1" max="500" required />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:background_color]} type="color" label="Color de fondo" />
          <.input field={@form[:border_width]} type="number" label="Grosor del borde (mm)" step="0.1" min="0" />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:border_color]} type="color" label="Color del borde" />
          <.input field={@form[:border_radius]} type="number" label="Radio del borde (mm)" step="0.1" min="0" />
        </div>

        <.input field={@form[:is_template]} type="checkbox" label="Guardar como plantilla reutilizable" />

        <:actions>
          <.button phx-disable-with="Guardando...">Guardar Diseño</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{design: design} = assigns, socket) do
    changeset = Designs.change_design(design)

    {:ok,
     socket
     |> assign(assigns)
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

  def handle_event("save", %{"design" => design_params}, socket) do
    design_params = Map.put(design_params, "user_id", socket.assigns.user_id)
    save_design(socket, socket.assigns.action, design_params)
  end

  defp save_design(socket, :new, design_params) do
    case Designs.create_design(design_params) do
      {:ok, design} ->
        notify_parent({:saved, design})

        {:noreply,
         socket
         |> put_flash(:info, "Diseño creado exitosamente")
         |> push_navigate(to: ~p"/designs/#{design.id}/edit")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_design(socket, :edit, design_params) do
    case Designs.update_design(socket.assigns.design, design_params) do
      {:ok, design} ->
        notify_parent({:saved, design})

        {:noreply,
         socket
         |> put_flash(:info, "Diseño actualizado exitosamente")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "design"))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
