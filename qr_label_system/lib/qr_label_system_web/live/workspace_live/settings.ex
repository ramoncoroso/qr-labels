defmodule QrLabelSystemWeb.WorkspaceLive.Settings do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Workspaces
  alias QrLabelSystem.Accounts.UserNotifier

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user

    case Workspaces.get_workspace(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Espacio de trabajo no encontrado")
         |> push_navigate(to: ~p"/workspaces")}

      %{type: "personal"} ->
        {:ok,
         socket
         |> put_flash(:error, "No se puede configurar el espacio personal")
         |> push_navigate(to: ~p"/workspaces")}

      workspace ->
        if Workspaces.workspace_admin?(workspace.id, user.id) do
          members = Workspaces.list_members(workspace.id)
          invitations = Workspaces.list_pending_invitations(workspace.id)
          changeset = Workspaces.Workspace.changeset(workspace, %{})

          {:ok,
           socket
           |> assign(:page_title, "Configurar - #{workspace.name}")
           |> assign(:workspace, workspace)
           |> assign(:members, members)
           |> assign(:invitations, invitations)
           |> assign(:invite_email, "")
           |> assign(:invite_role, "operator")
           |> assign_form(changeset)}
        else
          {:ok,
           socket
           |> put_flash(:error, "No tienes permisos de administrador en este espacio")
           |> push_navigate(to: ~p"/workspaces")}
        end
    end
  end

  @impl true
  def handle_event("validate", %{"workspace" => workspace_params}, socket) do
    changeset =
      socket.assigns.workspace
      |> Workspaces.Workspace.changeset(workspace_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"workspace" => workspace_params}, socket) do
    if not verify_still_admin(socket) do
      {:noreply, socket |> put_flash(:error, "Ya no tienes permisos de administrador") |> push_navigate(to: ~p"/workspaces")}
    else
      case Workspaces.update_workspace(socket.assigns.workspace, workspace_params) do
        {:ok, workspace} ->
          changeset = Workspaces.Workspace.changeset(workspace, %{})

          {:noreply,
           socket
           |> assign(:workspace, workspace)
           |> assign(:page_title, "Configurar - #{workspace.name}")
           |> assign_form(changeset)
           |> put_flash(:info, "Espacio actualizado correctamente")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign_form(socket, changeset)}

        {:error, :personal_workspace_immutable} ->
          {:noreply, put_flash(socket, :error, "No se puede modificar el espacio personal")}
      end
    end
  end

  @impl true
  def handle_event("update_invite_email", %{"value" => email}, socket) do
    {:noreply, assign(socket, :invite_email, email)}
  end

  @impl true
  def handle_event("update_invite_role", %{"value" => role}, socket) do
    {:noreply, assign(socket, :invite_role, role)}
  end

  @impl true
  def handle_event("send_invitation", _params, socket) do
    if not verify_still_admin(socket) do
      {:noreply, socket |> put_flash(:error, "Ya no tienes permisos de administrador") |> push_navigate(to: ~p"/workspaces")}
    else
      send_invitation_impl(socket)
    end
  end

  def handle_event("cancel_invitation", %{"id" => invitation_id}, socket) do
    if not verify_still_admin(socket) do
      {:noreply, socket |> put_flash(:error, "Ya no tienes permisos de administrador") |> push_navigate(to: ~p"/workspaces")}
    else
      workspace = socket.assigns.workspace

      invitation =
        Enum.find(socket.assigns.invitations, fn inv ->
          to_string(inv.id) == invitation_id
        end)

      if invitation do
        case Workspaces.cancel_invitation(invitation) do
          {:ok, _} ->
            invitations = Workspaces.list_pending_invitations(workspace.id)

            {:noreply,
             socket
             |> assign(:invitations, invitations)
             |> put_flash(:info, "Invitacion cancelada")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Error al cancelar la invitacion")}
        end
      else
        {:noreply, put_flash(socket, :error, "Invitacion no encontrada")}
      end
    end
  end

  @impl true
  def handle_event("change_role", %{"membership-id" => membership_id, "role" => new_role}, socket) do
    if not verify_still_admin(socket) do
      {:noreply, socket |> put_flash(:error, "Ya no tienes permisos de administrador") |> push_navigate(to: ~p"/workspaces")}
    else
      membership =
        Enum.find(socket.assigns.members, fn m ->
          to_string(m.id) == membership_id
        end)

      if membership do
        case Workspaces.update_member_role(membership, new_role) do
          {:ok, _} ->
            members = Workspaces.list_members(socket.assigns.workspace.id)

            {:noreply,
             socket
             |> assign(:members, members)
             |> put_flash(:info, "Rol actualizado correctamente")}

          {:error, :cannot_demote_owner} ->
            {:noreply, put_flash(socket, :error, "No se puede cambiar el rol del propietario")}

          {:error, :last_admin} ->
            {:noreply, put_flash(socket, :error, "Debe haber al menos un administrador")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Error al actualizar el rol")}
        end
      else
        {:noreply, put_flash(socket, :error, "Miembro no encontrado")}
      end
    end
  end

  @impl true
  def handle_event("remove_member", %{"membership-id" => membership_id}, socket) do
    if not verify_still_admin(socket) do
      {:noreply, socket |> put_flash(:error, "Ya no tienes permisos de administrador") |> push_navigate(to: ~p"/workspaces")}
    else
      membership =
        Enum.find(socket.assigns.members, fn m ->
          to_string(m.id) == membership_id
        end)

      if membership do
        case Workspaces.remove_member(membership) do
          {:ok, _} ->
            members = Workspaces.list_members(socket.assigns.workspace.id)

            {:noreply,
             socket
             |> assign(:members, members)
             |> put_flash(:info, "Miembro eliminado del espacio")}

          {:error, :cannot_remove_owner} ->
            {:noreply, put_flash(socket, :error, "No se puede eliminar al propietario")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Error al eliminar miembro")}
        end
      else
        {:noreply, put_flash(socket, :error, "Miembro no encontrado")}
      end
    end
  end

  defp send_invitation_impl(socket) do
    email = String.trim(socket.assigns.invite_email)
    role = socket.assigns.invite_role
    workspace = socket.assigns.workspace
    user = socket.assigns.current_user

    if email == "" do
      {:noreply, put_flash(socket, :error, "El email es obligatorio")}
    else
      case Workspaces.create_invitation(workspace, user, email, role) do
        {:ok, invitation} ->
          url = url(~p"/workspaces/invite/#{invitation.token}")
          UserNotifier.deliver_workspace_invitation(email, workspace.name, user.email, url)

          invitations = Workspaces.list_pending_invitations(workspace.id)

          {:noreply,
           socket
           |> assign(:invitations, invitations)
           |> assign(:invite_email, "")
           |> assign(:invite_role, "operator")
           |> put_flash(:info, "Invitacion enviada a #{email}")}

        {:error, :already_member} ->
          {:noreply, put_flash(socket, :error, "Este usuario ya es miembro del espacio")}

        {:error, :already_invited} ->
          {:noreply, put_flash(socket, :error, "Ya existe una invitacion pendiente para este email")}

        {:error, %Ecto.Changeset{} = changeset} ->
          message = changeset_error_message(changeset)
          {:noreply, put_flash(socket, :error, "Error al crear la invitacion: #{message}")}
      end
    end
  end

  # Re-verify admin role before mutating actions (guards against role changes in other sessions)
  defp verify_still_admin(socket) do
    Workspaces.workspace_admin?(socket.assigns.workspace.id, socket.assigns.current_user.id)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp changeset_error_message(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
    |> Enum.join("; ")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <.header>
        Configurar espacio de trabajo
        <:subtitle><%= @workspace.name %></:subtitle>
        <:actions>
          <.link navigate={~p"/workspaces"} class="text-sm text-gray-600 hover:text-gray-900">
            Volver a espacios
          </.link>
        </:actions>
      </.header>

      <div class="mt-8 space-y-8">
        <!-- General Info Section -->
        <section>
          <h2 class="text-lg font-semibold text-gray-900 mb-4">Informacion general</h2>
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <.simple_form for={@form} id="workspace-form" phx-change="validate" phx-submit="save">
              <.input field={@form[:name]} type="text" label="Nombre" required />
              <.input field={@form[:description]} type="textarea" label="Descripcion" placeholder="Describe el proposito de este espacio de trabajo" />
              <:actions>
                <.button phx-disable-with="Guardando...">Guardar cambios</.button>
              </:actions>
            </.simple_form>
          </div>
        </section>

        <!-- Members Section -->
        <section>
          <h2 class="text-lg font-semibold text-gray-900 mb-4">
            Miembros
            <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-600">
              <%= length(@members) %>
            </span>
          </h2>
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 divide-y divide-gray-100">
            <%= for member <- @members do %>
              <div class="flex items-center justify-between p-4">
                <div class="flex items-center gap-3 min-w-0">
                  <!-- Avatar -->
                  <div class="flex-shrink-0 w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center text-gray-500 text-sm font-medium">
                    <%= String.first(member.user.email) |> String.upcase() %>
                  </div>
                  <div class="min-w-0">
                    <p class="text-sm font-medium text-gray-900 truncate"><%= member.user.email %></p>
                    <p class="text-xs text-gray-400">
                      Miembro desde <%= Calendar.strftime(member.inserted_at, "%d/%m/%Y") %>
                    </p>
                  </div>
                </div>

                <div class="flex items-center gap-3 flex-shrink-0">
                  <!-- Role badge / selector -->
                  <%= if @workspace.owner_id == member.user_id do %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700">
                      Propietario
                    </span>
                  <% else %>
                    <form phx-change="change_role" phx-value-membership-id={member.id}>
                      <select
                        name="role"
                        class="text-sm border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500 py-1 pr-8"
                      >
                        <option value="admin" selected={member.role == "admin"}>Admin</option>
                        <option value="operator" selected={member.role == "operator"}>Operador</option>
                        <option value="viewer" selected={member.role == "viewer"}>Visor</option>
                      </select>
                    </form>

                    <button
                      phx-click="remove_member"
                      phx-value-membership-id={member.id}
                      data-confirm={"Estas seguro de eliminar a #{member.user.email} del espacio?"}
                      class="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition"
                      title="Eliminar miembro"
                    >
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                      </svg>
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </section>

        <!-- Pending Invitations Section -->
        <%= if @invitations != [] do %>
          <section>
            <h2 class="text-lg font-semibold text-gray-900 mb-4">
              Invitaciones pendientes
              <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700">
                <%= length(@invitations) %>
              </span>
            </h2>
            <div class="bg-white rounded-xl shadow-sm border border-gray-200 divide-y divide-gray-100">
              <%= for invitation <- @invitations do %>
                <div class="flex items-center justify-between p-4">
                  <div class="min-w-0">
                    <p class="text-sm font-medium text-gray-900 truncate"><%= invitation.email %></p>
                    <p class="text-xs text-gray-400">
                      Rol: <%= role_label(invitation.role) %> · Expira <%= Calendar.strftime(invitation.expires_at, "%d/%m/%Y") %>
                    </p>
                  </div>
                  <button
                    phx-click="cancel_invitation"
                    phx-value-id={invitation.id}
                    class="inline-flex items-center gap-1 px-3 py-1.5 text-sm font-medium text-red-600 hover:text-red-700 bg-red-50 hover:bg-red-100 border border-red-200 rounded-lg transition"
                  >
                    <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                    Cancelar
                  </button>
                </div>
              <% end %>
            </div>
          </section>
        <% end %>

        <!-- Invite Form Section -->
        <section>
          <h2 class="text-lg font-semibold text-gray-900 mb-4">Invitar miembro</h2>
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <form phx-submit="send_invitation" class="flex items-end gap-4">
              <div class="flex-1">
                <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
                <input
                  type="email"
                  name="email"
                  value={@invite_email}
                  phx-change="update_invite_email"
                  phx-debounce="300"
                  placeholder="usuario@ejemplo.com"
                  required
                  class="block w-full rounded-lg border-gray-300 shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                />
              </div>
              <div class="w-40">
                <label class="block text-sm font-medium text-gray-700 mb-1">Rol</label>
                <select
                  name="role"
                  phx-change="update_invite_role"
                  class="block w-full rounded-lg border-gray-300 shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                >
                  <option value="admin" selected={@invite_role == "admin"}>Admin</option>
                  <option value="operator" selected={@invite_role == "operator"}>Operador</option>
                  <option value="viewer" selected={@invite_role == "viewer"}>Visor</option>
                </select>
              </div>
              <button
                type="submit"
                class="bg-blue-600 hover:bg-blue-500 text-white px-4 py-2 rounded-lg font-medium transition inline-flex items-center gap-2"
              >
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75" />
                </svg>
                Invitar
              </button>
            </form>
          </div>
        </section>
      </div>
    </div>
    """
  end

  defp role_label("admin"), do: "Admin"
  defp role_label("operator"), do: "Operador"
  defp role_label("viewer"), do: "Visor"
  defp role_label(_), do: "Miembro"
end
