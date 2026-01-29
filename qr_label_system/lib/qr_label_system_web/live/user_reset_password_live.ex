defmodule QrLabelSystemWeb.UserResetPasswordLive do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Restablecer Contraseña</.header>

      <.simple_form
        for={@form}
        id="reset_password_form"
        phx-submit="reset_password"
        phx-change="validate"
      >
        <.error :if={@form.errors != []}>
          Oops, algo salió mal. Por favor revisa los errores abajo.
        </.error>

        <.input field={@form[:password]} type="password" label="Nueva contraseña" required />
        <.input
          field={@form[:password_confirmation]}
          type="password"
          label="Confirmar nueva contraseña"
          required
        />
        <:actions>
          <.button phx-disable-with="Restableciendo..." class="w-full">Restablecer Contraseña</.button>
        </:actions>
      </.simple_form>

      <p class="text-center text-sm mt-4">
        <.link href={~p"/users/register"}>Registrarse</.link>
        | <.link href={~p"/users/log_in"}>Iniciar Sesión</.link>
      </p>
    </div>
    """
  end

  def mount(params, _session, socket) do
    socket = assign_user_and_token(socket, params)

    form_source =
      case socket.assigns do
        %{user: user} ->
          Accounts.change_user_password(user)

        _ ->
          %{}
      end

    {:ok, assign_form(socket, form_source), temporary_assigns: [form: nil]}
  end

  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Contraseña restablecida exitosamente.")
         |> redirect(to: ~p"/users/log_in")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_password(socket.assigns.user, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_user_and_token(socket, %{"token" => token}) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      assign(socket, user: user, token: token)
    else
      socket
      |> put_flash(:error, "El enlace para restablecer la contraseña es inválido o ha expirado.")
      |> redirect(to: ~p"/")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "user"))
  end
end
