defmodule QrLabelSystemWeb.UserConfirmationLive do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Accounts

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Confirmar Cuenta</.header>

      <.simple_form for={@form} id="confirmation_form" phx-submit="confirm_account">
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <:actions>
          <.button phx-disable-with="Confirmando..." class="w-full">Confirmar mi cuenta</.button>
        </:actions>
      </.simple_form>

      <p class="text-center mt-4">
        <.link href={~p"/users/register"}>Registrarse</.link>
        | <.link href={~p"/users/log_in"}>Iniciar Sesión</.link>
      </p>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: nil]}
  end

  def handle_event("confirm_account", %{"user" => %{"token" => token}}, socket) do
    case Accounts.confirm_user(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Usuario confirmado exitosamente.")
         |> redirect(to: ~p"/")}

      :error ->
        case socket.assigns do
          %{current_user: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "El enlace de confirmación es inválido o ha expirado.")
             |> redirect(to: ~p"/")}
        end
    end
  end
end
