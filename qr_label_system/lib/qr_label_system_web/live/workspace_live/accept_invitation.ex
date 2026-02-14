defmodule QrLabelSystemWeb.WorkspaceLive.AcceptInvitation do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Workspaces
  alias QrLabelSystem.Workspaces.Invitation

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    user = socket.assigns[:current_user]
    invitation = Workspaces.get_invitation_by_token(token)

    cond do
      # Invalid or missing invitation
      is_nil(invitation) ->
        {:ok,
         socket
         |> assign(:page_title, "Invitacion no encontrada")
         |> assign(:status, :not_found)
         |> assign(:invitation, nil)
         |> assign(:token, token)}

      # Invitation already used
      !Invitation.pending?(invitation) ->
        {:ok,
         socket
         |> assign(:page_title, "Invitacion utilizada")
         |> assign(:status, :already_used)
         |> assign(:invitation, invitation)
         |> assign(:token, token)}

      # Invitation expired
      Invitation.expired?(invitation) ->
        {:ok,
         socket
         |> assign(:page_title, "Invitacion expirada")
         |> assign(:status, :expired)
         |> assign(:invitation, invitation)
         |> assign(:token, token)}

      # Not logged in - redirect to login with return_to
      is_nil(user) ->
        {:ok,
         socket
         |> put_flash(:info, "Inicia sesion para aceptar la invitacion")
         |> redirect(to: ~p"/users/log_in?#{[return_to: ~p"/workspaces/invite/#{token}"]}")}

      # Logged in but email doesn't match
      String.downcase(user.email) != String.downcase(invitation.email) ->
        {:ok,
         socket
         |> assign(:page_title, "Email incorrecto")
         |> assign(:status, :email_mismatch)
         |> assign(:invitation, invitation)
         |> assign(:token, token)}

      # Logged in and email matches - show accept button
      true ->
        {:ok,
         socket
         |> assign(:page_title, "Aceptar invitacion")
         |> assign(:status, :ready)
         |> assign(:invitation, invitation)
         |> assign(:token, token)}
    end
  end

  @impl true
  def handle_event("accept", _params, socket) do
    user = socket.assigns.current_user
    token = socket.assigns.token

    case Workspaces.accept_invitation(token, user) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Te has unido al espacio \"#{socket.assigns.invitation.workspace.name}\"")
         |> redirect(to: ~p"/designs")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> assign(:status, :not_found)
         |> put_flash(:error, "La invitacion no fue encontrada")}

      {:error, :already_used} ->
        {:noreply,
         socket
         |> assign(:status, :already_used)
         |> put_flash(:error, "Esta invitacion ya fue utilizada")}

      {:error, :expired} ->
        {:noreply,
         socket
         |> assign(:status, :expired)
         |> put_flash(:error, "Esta invitacion ha expirado")}

      {:error, :email_mismatch} ->
        {:noreply,
         socket
         |> assign(:status, :email_mismatch)
         |> put_flash(:error, "Esta invitacion es para otro email")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al aceptar la invitacion")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto mt-16">
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-8 text-center">
        <%= case @status do %>
          <% :ready -> %>
            <!-- Ready to accept -->
            <div class="mx-auto w-16 h-16 rounded-full bg-green-100 flex items-center justify-center mb-6">
              <svg class="w-8 h-8 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75" />
              </svg>
            </div>
            <h2 class="text-xl font-semibold text-gray-900 mb-2">Invitacion a espacio de trabajo</h2>
            <p class="text-gray-600 mb-6">
              Has sido invitado a unirte al espacio
              <span class="font-semibold text-gray-900">"<%= @invitation.workspace.name %>"</span>
              con el rol de
              <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium " <>
                case @invitation.role do
                  "admin" -> "bg-amber-100 text-amber-700"
                  "operator" -> "bg-green-100 text-green-700"
                  _ -> "bg-gray-100 text-gray-600"
                end}>
                <%= role_label(@invitation.role) %>
              </span>
            </p>
            <button
              phx-click="accept"
              phx-disable-with="Aceptando..."
              class="bg-blue-600 hover:bg-blue-500 text-white px-6 py-3 rounded-lg font-medium transition inline-flex items-center gap-2 text-base"
            >
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
              </svg>
              Aceptar invitacion
            </button>

          <% :not_found -> %>
            <!-- Invitation not found -->
            <div class="mx-auto w-16 h-16 rounded-full bg-red-100 flex items-center justify-center mb-6">
              <svg class="w-8 h-8 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
              </svg>
            </div>
            <h2 class="text-xl font-semibold text-gray-900 mb-2">Invitacion no encontrada</h2>
            <p class="text-gray-600 mb-6">
              Esta invitacion no existe o el enlace es invalido. Solicita una nueva invitacion al administrador del espacio.
            </p>
            <.link navigate={~p"/designs"} class="text-blue-600 hover:text-blue-500 font-medium">
              Ir a mis disenos
            </.link>

          <% :already_used -> %>
            <!-- Already used -->
            <div class="mx-auto w-16 h-16 rounded-full bg-amber-100 flex items-center justify-center mb-6">
              <svg class="w-8 h-8 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
              </svg>
            </div>
            <h2 class="text-xl font-semibold text-gray-900 mb-2">Invitacion ya utilizada</h2>
            <p class="text-gray-600 mb-6">
              Esta invitacion ya fue aceptada o cancelada anteriormente.
            </p>
            <.link navigate={~p"/designs"} class="text-blue-600 hover:text-blue-500 font-medium">
              Ir a mis disenos
            </.link>

          <% :expired -> %>
            <!-- Expired -->
            <div class="mx-auto w-16 h-16 rounded-full bg-amber-100 flex items-center justify-center mb-6">
              <svg class="w-8 h-8 text-amber-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <h2 class="text-xl font-semibold text-gray-900 mb-2">Invitacion expirada</h2>
            <p class="text-gray-600 mb-6">
              Esta invitacion ha expirado. Solicita una nueva invitacion al administrador del espacio.
            </p>
            <.link navigate={~p"/designs"} class="text-blue-600 hover:text-blue-500 font-medium">
              Ir a mis disenos
            </.link>

          <% :email_mismatch -> %>
            <!-- Email mismatch -->
            <div class="mx-auto w-16 h-16 rounded-full bg-red-100 flex items-center justify-center mb-6">
              <svg class="w-8 h-8 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
              </svg>
            </div>
            <h2 class="text-xl font-semibold text-gray-900 mb-2">Email incorrecto</h2>
            <p class="text-gray-600 mb-6">
              Esta invitacion es para otro email. Inicia sesion con la cuenta correcta o solicita una nueva invitacion.
            </p>
            <.link navigate={~p"/designs"} class="text-blue-600 hover:text-blue-500 font-medium">
              Ir a mis disenos
            </.link>
        <% end %>
      </div>
    </div>
    """
  end

  defp role_label("admin"), do: "Admin"
  defp role_label("operator"), do: "Operador"
  defp role_label("viewer"), do: "Visor"
  defp role_label(_), do: "Miembro"
end
