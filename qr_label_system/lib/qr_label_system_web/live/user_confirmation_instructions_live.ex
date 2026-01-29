defmodule QrLabelSystemWeb.UserConfirmationInstructionsLive do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Reenviar instrucciones de confirmación
      </.header>

      <.simple_form for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.button phx-disable-with="Enviando..." class="w-full">
            Reenviar instrucciones de confirmación
          </.button>
        </:actions>
      </.simple_form>

      <p class="text-center mt-4">
        <.link href={~p"/users/register"}>Registrarse</.link>
        | <.link href={~p"/users/log_in"}>Iniciar Sesión</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    info =
      "Si tu email está en nuestro sistema y no ha sido confirmado aún, recibirás un email con instrucciones."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
