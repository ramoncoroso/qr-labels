defmodule QrLabelSystemWeb.Admin.ApprovalsLive do
  @moduledoc """
  Admin panel for reviewing and approving/rejecting designs.
  """
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Designs
  alias QrLabelSystem.Settings

  @impl true
  def mount(_params, _session, socket) do
    pending = Designs.list_pending_approvals()

    {:ok,
     socket
     |> assign(:page_title, "Aprobaciones pendientes")
     |> assign(:pending_designs, pending)
     |> assign(:selected_design, nil)
     |> assign(:approval_history, [])
     |> assign(:comment, "")
     |> assign(:approval_required, Settings.approval_required?())}
  end

  @impl true
  def handle_event("select_design", %{"id" => id_str}, socket) do
    case Integer.parse(id_str) do
      {id, _} ->
        design = Designs.get_design(id)
        history = Designs.get_approval_history(id)

        {:noreply,
         socket
         |> assign(:selected_design, design)
         |> assign(:approval_history, history)
         |> assign(:comment, "")}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("approve", _params, socket) do
    design = socket.assigns.selected_design
    admin = socket.assigns.current_user
    comment = socket.assigns.comment

    case Designs.approve_design(design, admin, comment) do
      {:ok, _updated} ->
        pending = Designs.list_pending_approvals()

        {:noreply,
         socket
         |> assign(:pending_designs, pending)
         |> assign(:selected_design, nil)
         |> assign(:comment, "")
         |> put_flash(:info, "Diseno aprobado")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("reject", _params, socket) do
    design = socket.assigns.selected_design
    admin = socket.assigns.current_user
    comment = socket.assigns.comment

    if String.trim(comment) == "" do
      {:noreply, put_flash(socket, :error, "Debes agregar un comentario al rechazar")}
    else
      case Designs.reject_design(design, admin, comment) do
        {:ok, _updated} ->
          pending = Designs.list_pending_approvals()

          {:noreply,
           socket
           |> assign(:pending_designs, pending)
           |> assign(:selected_design, nil)
           |> assign(:comment, "")
           |> put_flash(:info, "Diseno rechazado y devuelto a borrador")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    end
  end

  @impl true
  def handle_event("update_comment", %{"value" => value}, socket) do
    {:noreply, assign(socket, :comment, value)}
  end

  @impl true
  def handle_event("toggle_approval_required", _params, socket) do
    unless socket.assigns.current_user.role == "admin" do
      {:noreply, put_flash(socket, :error, "Solo administradores pueden cambiar esta configuracion")}
    else
      new_value = if socket.assigns.approval_required, do: "false", else: "true"
      Settings.set_setting("approval_required", new_value)

      {:noreply,
       socket
       |> assign(:approval_required, new_value == "true")
       |> put_flash(:info, if(new_value == "true", do: "Aprobacion activada", else: "Aprobacion desactivada"))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        Aprobaciones
        <:subtitle>Revisa y aprueba disenos antes de que puedan imprimirse</:subtitle>
        <:actions>
          <button
            phx-click="toggle_approval_required"
            class={"inline-flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition " <>
              if(@approval_required,
                do: "bg-green-100 text-green-700 border border-green-200 hover:bg-green-200",
                else: "bg-gray-100 text-gray-600 border border-gray-200 hover:bg-gray-200"
              )}
          >
            <div class={"w-8 h-5 rounded-full transition-colors relative " <> if(@approval_required, do: "bg-green-500", else: "bg-gray-300")}>
              <div class={"absolute top-0.5 w-4 h-4 rounded-full bg-white transition-transform " <> if(@approval_required, do: "translate-x-3.5", else: "translate-x-0.5")}></div>
            </div>
            <%= if @approval_required, do: "Aprobacion activa", else: "Aprobacion desactivada" %>
          </button>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Pending designs list -->
        <div class="lg:col-span-1">
          <div class="bg-white rounded-lg shadow">
            <div class="px-4 py-3 border-b border-gray-200">
              <h3 class="font-semibold text-gray-900">
                Pendientes
                <span class="ml-2 px-2 py-0.5 rounded-full text-xs bg-amber-100 text-amber-700">
                  <%= length(@pending_designs) %>
                </span>
              </h3>
            </div>
            <%= if @pending_designs == [] do %>
              <div class="p-6 text-center text-sm text-gray-500">
                <svg class="w-12 h-12 mx-auto mb-3 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <p>No hay disenos pendientes de aprobacion</p>
              </div>
            <% else %>
              <div class="divide-y divide-gray-200">
                <%= for design <- @pending_designs do %>
                  <button
                    phx-click="select_design"
                    phx-value-id={design.id}
                    class={"w-full text-left px-4 py-3 hover:bg-gray-50 transition " <>
                      if(@selected_design && @selected_design.id == design.id, do: "bg-blue-50 border-l-4 border-blue-500", else: "")}
                  >
                    <p class="font-medium text-gray-900 truncate"><%= design.name %></p>
                    <p class="text-xs text-gray-500 mt-0.5">
                      <%= design.user.email %> · <%= design.width_mm %> x <%= design.height_mm %> mm
                    </p>
                    <p class="text-xs text-gray-400 mt-0.5">
                      <%= Calendar.strftime(design.updated_at, "%d/%m/%Y %H:%M") %>
                    </p>
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Design detail + actions -->
        <div class="lg:col-span-2">
          <%= if @selected_design do %>
            <div class="bg-white rounded-lg shadow">
              <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-semibold text-gray-900"><%= @selected_design.name %></h3>
                <%= if @selected_design.description do %>
                  <p class="text-sm text-gray-500 mt-1"><%= @selected_design.description %></p>
                <% end %>
                <div class="flex items-center gap-4 mt-2 text-sm text-gray-500">
                  <span><%= @selected_design.width_mm %> x <%= @selected_design.height_mm %> mm</span>
                  <span><%= length(@selected_design.elements || []) %> elementos</span>
                  <.link navigate={~p"/designs/#{@selected_design.id}/edit"} class="text-blue-600 hover:text-blue-800 underline">
                    Ver en editor
                  </.link>
                </div>
              </div>

              <!-- Approval actions -->
              <div class="px-6 py-4 border-b border-gray-200">
                <label class="block text-sm font-medium text-gray-700 mb-2">Comentario</label>
                <textarea
                  phx-keyup="update_comment"
                  phx-debounce="300"
                  name="value"
                  rows="2"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  placeholder="Comentario opcional para aprobar, obligatorio para rechazar..."
                ><%= @comment %></textarea>
                <div class="flex items-center gap-3 mt-3">
                  <button
                    phx-click="approve"
                    class="inline-flex items-center gap-2 px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg text-sm font-medium transition"
                  >
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                    </svg>
                    Aprobar
                  </button>
                  <button
                    phx-click="reject"
                    class="inline-flex items-center gap-2 px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg text-sm font-medium transition"
                  >
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                    Rechazar
                  </button>
                </div>
              </div>

              <!-- Approval history -->
              <div class="px-6 py-4">
                <h4 class="text-sm font-medium text-gray-700 mb-3">Historial</h4>
                <%= if @approval_history == [] do %>
                  <p class="text-sm text-gray-400 italic">Sin historial previo</p>
                <% else %>
                  <div class="space-y-3">
                    <%= for approval <- @approval_history do %>
                      <div class="flex items-start gap-3">
                        <span class={"flex-shrink-0 mt-0.5 w-2 h-2 rounded-full " <>
                          case approval.action do
                            "request_review" -> "bg-amber-400"
                            "approve" -> "bg-green-400"
                            "reject" -> "bg-red-400"
                            _ -> "bg-gray-400"
                          end} />
                        <div class="flex-1 min-w-0">
                          <div class="flex items-center gap-2 text-sm">
                            <span class="font-medium text-gray-900">
                              <%= case approval.action do
                                "request_review" -> "Enviado a revision"
                                "approve" -> "Aprobado"
                                "reject" -> "Rechazado"
                                _ -> approval.action
                              end %>
                            </span>
                            <span class="text-gray-400">por</span>
                            <span class="text-gray-600"><%= approval.user.email %></span>
                            <span class="text-gray-400 text-xs"><%= Calendar.strftime(approval.inserted_at, "%d/%m/%Y %H:%M") %></span>
                          </div>
                          <%= if approval.comment do %>
                            <p class="text-sm text-gray-600 mt-1 bg-gray-50 rounded px-3 py-1.5"><%= approval.comment %></p>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% else %>
            <div class="bg-white rounded-lg shadow p-12 text-center">
              <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
              </svg>
              <p class="text-gray-500">Selecciona un diseno para revisar</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
