defmodule QrLabelSystemWeb.UserForgotPasswordLive do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        ¿Olvidaste tu contraseña?
        <:subtitle>Te enviaremos un enlace para restablecer tu contraseña.</:subtitle>
      </.header>

      <.simple_form for={@form} id="reset_password_form" phx-submit="send_email">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.button phx-disable-with="Enviando..." class="w-full">
            Enviar instrucciones
          </.button>
        </:actions>
      </.simple_form>
      <p class="text-center text-sm mt-4">
        <.link href={~p"/users/register"}>Registrarse</.link>
        | <.link href={~p"/users/log_in"}>Iniciar Sesión</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    info =
      "Si tu email está en nuestro sistema, recibirás instrucciones para restablecer tu contraseña."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
