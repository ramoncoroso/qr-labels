defmodule QrLabelSystemWeb.UserLoginLive do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Accounts

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
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v1m6 11h2m-6 0h-2v4m0-11v3m0 0h.01M12 12h4.01M16 20h4M4 12h4m12 0h.01M5 8h2a1 1 0 001-1V5a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1zm12 0h2a1 1 0 001-1V5a1 1 0 00-1-1h-2a1 1 0 00-1 1v2a1 1 0 001 1zM5 20h2a1 1 0 001-1v-2a1 1 0 00-1-1H5a1 1 0 00-1 1v2a1 1 0 001 1z" />
                </svg>
              </div>
              <h2 class="text-2xl font-bold text-slate-800 mb-2">Bienvenido</h2>
              <p class="text-slate-600">Ingresa tu email para recibir un enlace de acceso</p>
            </div>

            <.simple_form for={@form} id="login_form" phx-submit="send_magic_link" phx-change="validate">
              <div class="space-y-6">
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
                    class="w-full px-4 py-3 rounded-xl border border-slate-300 focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 transition text-slate-800 placeholder-slate-400"
                  />
                </div>

                <button
                  type="submit"
                  phx-disable-with="Enviando..."
                  class="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 px-4 rounded-xl transition shadow-lg shadow-blue-600/25 flex items-center justify-center gap-2"
                >
                  Enviar enlace de acceso
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
                  </svg>
                </button>
              </div>
            </.simple_form>

            <div class="mt-8 pt-6 border-t border-slate-200 text-center">
              <p class="text-slate-600">
                ¿No tienes una cuenta?
                <.link navigate={~p"/users/register"} class="font-semibold text-blue-600 hover:text-blue-700 transition">
                  Regístrate
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
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")

    {:ok,
     assign(socket,
       form: form,
       magic_link_sent: false,
       sent_to_email: nil
     )}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    form = to_form(user_params, as: "user")
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("send_magic_link", %{"user" => %{"email" => email}}, socket) do
    email = String.trim(email)

    if email != "" do
      # Always send magic link (even if user doesn't exist, to prevent enumeration)
      Accounts.deliver_magic_link_instructions(email, &url(~p"/users/magic_link/#{&1}"))

      {:noreply,
       socket
       |> assign(magic_link_sent: true, sent_to_email: email)
       |> put_flash(:info, "Si existe una cuenta con ese email, recibirás un enlace de acceso.")}
    else
      {:noreply, put_flash(socket, :error, "Por favor ingresa tu email")}
    end
  end

  def handle_event("reset", _params, socket) do
    form = to_form(%{"email" => ""}, as: "user")

    {:noreply,
     socket
     |> assign(form: form, magic_link_sent: false, sent_to_email: nil)
     |> clear_flash()}
  end
end
