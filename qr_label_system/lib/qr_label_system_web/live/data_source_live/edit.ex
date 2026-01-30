defmodule QrLabelSystemWeb.DataSourceLive.Edit do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.DataSources

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    data_source = DataSources.get_data_source!(id)

    # Verify ownership
    if data_source.user_id != socket.assigns.current_user.id do
      {:ok,
       socket
       |> put_flash(:error, "No tienes permiso para editar estos datos")
       |> push_navigate(to: ~p"/data-sources")}
    else
      changeset = DataSources.change_data_source(data_source)

      {:ok,
       socket
       |> assign(:page_title, "Editar datos")
       |> assign(:data_source, data_source)
       |> assign(:source_type, data_source.type || "excel")
       |> assign(:connection_status, nil)
       |> assign(:connection_error, nil)
       |> assign_form(changeset)}
    end
  end

  @impl true
  def handle_event("validate", %{"data_source" => data_source_params}, socket) do
    source_type = data_source_params["type"] || socket.assigns.source_type

    changeset =
      socket.assigns.data_source
      |> DataSources.change_data_source(data_source_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:source_type, source_type)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("save", %{"data_source" => data_source_params}, socket) do
    # Build connection_config for database types
    data_source_params =
      if data_source_params["type"] in ["postgresql", "mysql", "sqlserver"] do
        connection_config = %{
          "host" => data_source_params["host"],
          "port" => data_source_params["port"],
          "database" => data_source_params["database"],
          "username" => data_source_params["username"],
          "password" => data_source_params["password"]
        }

        data_source_params
        |> Map.put("connection_config", connection_config)
        |> Map.drop(["host", "port", "database", "username", "password"])
      else
        data_source_params
      end

    case DataSources.update_data_source(socket.assigns.data_source, data_source_params) do
      {:ok, _data_source} ->
        {:noreply,
         socket
         |> put_flash(:info, "Datos actualizados exitosamente")
         |> push_navigate(to: ~p"/data-sources")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("test_connection", _params, socket) do
    form_data = socket.assigns.form.source.changes

    config = %{
      type: form_data[:type] || socket.assigns.source_type,
      host: form_data[:host],
      port: form_data[:port],
      database: form_data[:database],
      username: form_data[:username],
      password: form_data[:password]
    }

    case QrLabelSystem.DataSources.DbConnector.test_connection(config) do
      :ok ->
        {:noreply, assign(socket, connection_status: :ok, connection_error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, connection_status: :error, connection_error: reason)}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case DataSources.delete_data_source(socket.assigns.data_source) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Datos eliminados exitosamente")
         |> push_navigate(to: ~p"/data-sources")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al eliminar los datos")}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "data_source"))
  end

  defp default_port("postgresql"), do: "5432"
  defp default_port("mysql"), do: "3306"
  defp default_port("sqlserver"), do: "1433"
  defp default_port(_), do: ""

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Editar datos
        <:subtitle>Modifica la configuración de tus datos</:subtitle>
      </.header>

      <div class="mt-8 max-w-2xl">
        <.simple_form
          for={@form}
          id="data-source-form"
          action={~p"/data-sources/#{@data_source.id}"}
          phx-change="validate"
          phx-submit="save"
        >
          <.input field={@form[:name]} type="text" label="Nombre" required />

          <.input
            field={@form[:type]}
            type="select"
            label="Tipo de fuente"
            options={[
              {"Excel (.xlsx)", "excel"},
              {"CSV", "csv"},
              {"PostgreSQL", "postgresql"},
              {"MySQL", "mysql"},
              {"SQL Server", "sqlserver"}
            ]}
            required
          />

          <%= if @source_type in ["postgresql", "mysql", "sqlserver"] do %>
            <div class="border-t pt-4 mt-4">
              <h4 class="font-medium text-gray-900 mb-4">Configuración de conexión</h4>

              <div class="grid grid-cols-2 gap-4">
                <.input field={@form[:host]} type="text" label="Host" placeholder="localhost" required />
                <.input field={@form[:port]} type="number" label="Puerto" placeholder={default_port(@source_type)} required />
              </div>

              <.input field={@form[:database]} type="text" label="Base de datos" required />

              <div class="grid grid-cols-2 gap-4">
                <.input field={@form[:username]} type="text" label="Usuario" required />
                <.input field={@form[:password]} type="password" label="Contraseña" required />
              </div>

              <.input
                field={@form[:query]}
                type="textarea"
                label="Query SQL"
                placeholder="SELECT * FROM tabla WHERE ..."
              />

              <div class="mt-4">
                <button
                  type="button"
                  phx-click="test_connection"
                  class="text-indigo-600 hover:text-indigo-800 text-sm font-medium"
                >
                  Probar conexión
                </button>
                <%= if @connection_status do %>
                  <span class={"ml-2 text-sm #{if @connection_status == :ok, do: "text-green-600", else: "text-red-600"}"}>
                    <%= if @connection_status == :ok, do: "Conexión exitosa", else: @connection_error %>
                  </span>
                <% end %>
              </div>
            </div>
          <% end %>

          <:actions>
            <.link navigate={~p"/data-sources"} class="text-sm text-gray-600 hover:text-gray-900">
              Cancelar
            </.link>
            <.button phx-disable-with="Guardando...">Guardar</.button>
          </:actions>
        </.simple_form>

        <div class="mt-8 pt-8 border-t border-gray-200">
          <h3 class="text-lg font-medium text-red-600">Zona de peligro</h3>
          <p class="mt-1 text-sm text-gray-500">Esta acción no se puede deshacer.</p>
          <form action={~p"/data-sources/#{@data_source.id}"} method="post" class="mt-4">
            <input type="hidden" name="_method" value="delete" />
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <button
              type="submit"
              class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 text-sm font-medium"
              onclick="return confirm('¿Estás seguro de que quieres eliminar estos datos?')"
            >
              Eliminar datos
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
