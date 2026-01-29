defmodule QrLabelSystemWeb.HomeLive do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-full flex flex-col">
      <!-- Main content -->
      <main class="flex-1 flex items-center justify-center px-4 py-8 sm:py-12">
        <div class="w-full max-w-md">
          <!-- Header -->
          <div class="text-center mb-8">
            <div class="inline-flex items-center justify-center w-14 h-14 bg-gray-900 rounded-xl mb-4">
              <svg class="w-7 h-7 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 013.75 9.375v-4.5zM3.75 14.625c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 01-1.125-1.125v-4.5zM13.5 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0113.5 9.375v-4.5z" />
                <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 14.625v6m3-3h6" />
              </svg>
            </div>
            <h1 class="text-2xl font-bold text-gray-900 mb-2">QR Label System</h1>
            <p class="text-gray-600 text-sm">Genera etiquetas con codigos QR desde tus datos</p>
          </div>

          <!-- Login Card -->
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <%= if @magic_link_sent do %>
              <!-- Estado: Email enviado -->
              <div class="text-center">
                <div class="mx-auto w-12 h-12 bg-green-100 rounded-full flex items-center justify-center mb-4">
                  <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
                  </svg>
                </div>

                <h2 class="text-lg font-semibold text-gray-900 mb-2">Revisa tu correo</h2>
                <p class="text-gray-600 text-sm mb-1">
                  Enviamos un enlace de acceso a
                </p>
                <p class="text-gray-900 font-medium mb-4">
                  <%= @sent_to_email %>
                </p>

                <p class="text-gray-500 text-xs mb-4">
                  El enlace expira en 15 minutos
                </p>

                <button
                  phx-click="reset"
                  class="text-gray-500 hover:text-gray-700 text-sm font-medium transition"
                >
                  Usar otro email
                </button>
              </div>
            <% else %>
              <!-- Estado: Formulario de login -->
              <form phx-submit="send_magic_link" class="space-y-4">
                <div>
                  <label for="email" class="block text-sm font-medium text-gray-700 mb-1.5">
                    Email
                  </label>
                  <input
                    type="email"
                    name="email"
                    id="email"
                    value={@email}
                    placeholder="tu@email.com"
                    required
                    autocomplete="email"
                    autofocus
                    class="w-full px-3 py-2.5 rounded-lg border border-gray-300 text-gray-900 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent text-sm"
                  />
                </div>

                <button
                  type="submit"
                  phx-disable-with="Enviando..."
                  class="w-full bg-gray-900 hover:bg-gray-800 text-white font-medium py-2.5 px-4 rounded-lg transition text-sm"
                >
                  Continuar
                </button>
              </form>

              <p class="text-center text-gray-500 text-xs mt-4">
                Recibiras un enlace para acceder sin contrasena
              </p>
            <% end %>
          </div>

          <!-- Como funciona -->
          <%= unless @magic_link_sent do %>
            <div class="mt-10">
              <h2 class="text-sm font-semibold text-gray-900 text-center mb-6">Como funciona</h2>

              <div class="space-y-4">
                <!-- Paso 1 -->
                <div class="flex items-start gap-4">
                  <div class="flex-shrink-0 w-8 h-8 bg-gray-900 text-white rounded-lg flex items-center justify-center text-sm font-medium">
                    1
                  </div>
                  <div>
                    <h3 class="text-sm font-medium text-gray-900">Disena tu etiqueta</h3>
                    <p class="text-xs text-gray-500 mt-0.5">Crea plantillas con campos dinamicos, logos y codigos QR</p>
                  </div>
                </div>

                <!-- Paso 2 -->
                <div class="flex items-start gap-4">
                  <div class="flex-shrink-0 w-8 h-8 bg-gray-900 text-white rounded-lg flex items-center justify-center text-sm font-medium">
                    2
                  </div>
                  <div>
                    <h3 class="text-sm font-medium text-gray-900">Importa tus datos</h3>
                    <p class="text-xs text-gray-500 mt-0.5">Sube archivos Excel o CSV con la informacion de tus productos</p>
                  </div>
                </div>

                <!-- Paso 3 -->
                <div class="flex items-start gap-4">
                  <div class="flex-shrink-0 w-8 h-8 bg-gray-900 text-white rounded-lg flex items-center justify-center text-sm font-medium">
                    3
                  </div>
                  <div>
                    <h3 class="text-sm font-medium text-gray-900">Genera e imprime</h3>
                    <p class="text-xs text-gray-500 mt-0.5">Obtiene un PDF listo para imprimir o envia a tu impresora de etiquetas</p>
                  </div>
                </div>
              </div>
            </div>

            <!-- Formatos soportados -->
            <div class="mt-8 pt-6 border-t border-gray-200">
              <p class="text-xs text-gray-500 text-center">
                Compatible con Excel, CSV y conexiones a bases de datos
              </p>
            </div>
          <% end %>
        </div>
      </main>

      <!-- Footer -->
      <footer class="py-4 border-t border-gray-100">
        <p class="text-center text-gray-400 text-xs">
          QR Label System - Generador de etiquetas profesionales
        </p>
      </footer>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    require Logger
    Logger.info("=== HomeLive MOUNT === connected?=#{connected?(socket)}")
    {:ok,
     assign(socket,
       page_title: "Generador de Etiquetas QR",
       meta_description: "Crea etiquetas profesionales con codigos QR. Importa datos desde Excel o CSV, disena tus plantillas y genera lotes de etiquetas listas para imprimir.",
       meta_keywords: "etiquetas QR, generador QR, codigos QR, etiquetas productos, impresion etiquetas, Excel a QR",
       og_title: "QR Label System",
       og_description: "Genera etiquetas con codigos QR desde tus datos. Importa Excel, disena plantillas e imprime.",
       body_class: "bg-gray-50",
       email: "",
       magic_link_sent: false,
       sent_to_email: nil
     ), layout: {QrLabelSystemWeb.Layouts, :home}}
  end

  @impl true
  def handle_event("send_magic_link", %{"email" => email}, socket) do
    require Logger
    email = String.trim(email)
    Logger.info("=== MAGIC LINK REQUEST for email: #{email} ===")

    if email != "" do
      # Always send magic link (even if user doesn't exist, to prevent enumeration)
      # If user doesn't exist, create them
      result = case Accounts.get_user_by_email(email) do
        nil ->
          Logger.info("User not found, creating new user...")
          # Create new user
          case Accounts.register_user_passwordless(%{"email" => email}) do
            {:ok, user} ->
              Logger.info("User created: #{user.id}")
              Accounts.deliver_magic_link_instructions(email, &url(~p"/users/magic_link/#{&1}"))
            {:error, changeset} ->
              Logger.error("Failed to create user: #{inspect(changeset.errors)}")
              # Still show success to prevent enumeration
              :ok
          end

        user ->
          Logger.info("User found: #{user.id}, sending magic link...")
          Accounts.deliver_magic_link_instructions(email, &url(~p"/users/magic_link/#{&1}"))
      end

      Logger.info("Magic link result: #{inspect(result)}")

      {:noreply,
       socket
       |> assign(magic_link_sent: true, sent_to_email: email)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply,
     assign(socket,
       email: "",
       magic_link_sent: false,
       sent_to_email: nil
     )}
  end
end
