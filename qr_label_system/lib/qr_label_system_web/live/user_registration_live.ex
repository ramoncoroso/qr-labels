defmodule QrLabelSystemWeb.UserRegistrationLive do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Accounts
  alias QrLabelSystem.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="min-h-[80vh] flex items-center justify-center">
      <div class="w-full max-w-md">
        <!-- Card con glassmorphism -->
        <div class="bg-white/95 backdrop-blur-sm rounded-2xl shadow-2xl p-8 border border-slate-200">
          <%= if @magic_link_sent do %>
            <!-- Estado: Email enviado -->
            <div class="text-center">
              <div class="mx-auto w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center mb-6">
                <svg class="w-8 h-8 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
                </svg>
              </div>

              <h2 class="text-2xl font-bold text-slate-800 mb-2">Revisa tu correo</h2>
              <p class="text-slate-600 mb-6">
                Hemos enviado un enlace de acceso a<br/>
                <span class="font-semibold text-blue-600"><%= @sent_to_email %></span>
              </p>

              <div class="bg-slate-50 rounded-xl p-4 mb-6 border border-slate-200">
                <p class="text-sm text-slate-600">
                  El enlace es válido por <span class="font-semibold text-slate-800">15 minutos</span>
                  y solo puede usarse una vez.
                </p>
              </div>

              <p class="text-sm text-slate-500 mb-4">
                ¿No recibiste el correo? Revisa tu carpeta de spam.
              </p>

              <button
                phx-click="reset"
                class="text-blue-600 hover:text-blue-700 font-semibold text-sm transition"
              >
                ← Usar otro email
              </button>
            </div>
          <% else %>
            <!-- Estado: Formulario -->
            <div class="text-center mb-8">
              <div class="mx-auto w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mb-6">
                <svg class="w-8 h-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                </svg>
              </div>
              <h2 class="text-2xl font-bold text-slate-800 mb-2">Crear cuenta</h2>
              <p class="text-slate-600">Ingresa tu email para comenzar</p>
            </div>

            <.simple_form
              for={@form}
              id="registration_form"
              phx-submit="save"
              phx-change="validate"
            >
              <div class="space-y-6">
                <.error :if={@check_errors}>
                  <div class="bg-red-50 border border-red-200 rounded-xl p-4 text-red-700 text-sm">
                    Oops, algo salió mal. Por favor revisa los errores abajo.
                  </div>
                </.error>

                <div>
                  <label for="user_email" class="block text-sm font-semibold text-slate-700 mb-2">
                    Email
                  </label>
                  <input
                    type="email"
                    name="user[email]"
                    id="user_email"
                    value={@form[:email].value}
                    required
                    autocomplete="email"
                    placeholder="tu@email.com"
                    phx-debounce="300"
                    class={"w-full px-4 py-3 rounded-xl border transition text-slate-800 placeholder-slate-400 " <>
                      if(@form[:email].errors != [],
                        do: "border-red-400 focus:border-red-500 focus:ring-2 focus:ring-red-500/20",
                        else: "border-slate-300 focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20"
                      )}
                  />
                  <%= if @form[:email].errors != [] do %>
                    <p class="mt-2 text-sm text-red-600">
                      <%= translate_error(hd(@form[:email].errors)) %>
                    </p>
                  <% end %>
                </div>

                <button
                  type="submit"
                  phx-disable-with="Creando cuenta..."
                  class="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 px-4 rounded-xl transition shadow-lg shadow-blue-600/25 flex items-center justify-center gap-2"
                >
                  Crear cuenta
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
                  </svg>
                </button>
              </div>
            </.simple_form>

            <div class="mt-8 pt-6 border-t border-slate-200 text-center">
              <p class="text-slate-600">
                ¿Ya tienes una cuenta?
                <.link navigate={~p"/users/log_in"} class="font-semibold text-blue-600 hover:text-blue-700 transition">
                  Inicia sesión
                </.link>
              </p>
            </div>
          <% end %>
        </div>

        <!-- Link a inicio -->
        <div class="mt-6 text-center">
          <.link navigate={~p"/"} class="text-slate-500 hover:text-slate-700 text-sm transition">
            ← Volver al inicio
          </.link>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_passwordless_registration(%User{})

    socket =
      socket
      |> assign(check_errors: false, magic_link_sent: false, sent_to_email: nil)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    email = user_params["email"] |> String.trim()

    # Check if user already exists
    case Accounts.get_user_by_email(email) do
      %User{} = _existing_user ->
        # User exists, just send magic link (like login)
        Accounts.deliver_magic_link_instructions(email, &url(~p"/users/magic_link/#{&1}"))

        {:noreply,
         socket
         |> assign(magic_link_sent: true, sent_to_email: email)
         |> put_flash(:info, "Te hemos enviado un enlace de acceso.")}

      nil ->
        # Create new user without password
        case Accounts.register_user_passwordless(user_params) do
          {:ok, user} ->
            # Send magic link for the new user
            Accounts.deliver_magic_link_instructions(user.email, &url(~p"/users/magic_link/#{&1}"))

            {:noreply,
             socket
             |> assign(magic_link_sent: true, sent_to_email: user.email)
             |> put_flash(:info, "Cuenta creada. Te hemos enviado un enlace de acceso.")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
        end
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_passwordless_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("reset", _params, socket) do
    changeset = Accounts.change_user_passwordless_registration(%User{})

    {:noreply,
     socket
     |> assign(check_errors: false, magic_link_sent: false, sent_to_email: nil)
     |> assign_form(changeset)
     |> clear_flash()}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
