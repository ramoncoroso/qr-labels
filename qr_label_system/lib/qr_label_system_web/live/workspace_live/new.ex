defmodule QrLabelSystemWeb.WorkspaceLive.New do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Workspaces
  alias QrLabelSystem.Workspaces.Workspace

  @impl true
  def mount(_params, _session, socket) do
    changeset = Workspace.changeset(%Workspace{}, %{})

    {:ok,
     socket
     |> assign(:page_title, "Nuevo espacio de trabajo")
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"workspace" => workspace_params}, socket) do
    changeset =
      %Workspace{}
      |> Workspace.changeset(workspace_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"workspace" => workspace_params}, socket) do
    user = socket.assigns.current_user

    # Ensure only team workspaces can be created through this form
    attrs = Map.merge(workspace_params, %{"type" => "team"})

    case Workspaces.create_workspace(user, attrs) do
      {:ok, _workspace} ->
        {:noreply,
         socket
         |> put_flash(:info, "Espacio de trabajo creado exitosamente")
         |> push_navigate(to: ~p"/workspaces")}

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
    <div class="max-w-2xl mx-auto">
      <.header>
        Crear espacio de trabajo
        <:subtitle>Los espacios de equipo permiten colaborar con otros usuarios en diseños compartidos</:subtitle>
      </.header>

      <div class="mt-8">
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <.simple_form for={@form} id="workspace-form" phx-change="validate" phx-submit="save">
            <.input field={@form[:name]} type="text" label="Nombre del espacio" required placeholder="Ej: Equipo de produccion" />
            <.input field={@form[:description]} type="textarea" label="Descripcion (opcional)" placeholder="Describe el proposito de este espacio de trabajo" />

            <:actions>
              <div class="flex items-center justify-between w-full">
                <.link navigate={~p"/workspaces"} class="text-sm text-gray-600 hover:text-gray-900">
                  Cancelar
                </.link>
                <.button phx-disable-with="Creando...">Crear espacio</.button>
              </div>
            </:actions>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end
end
