defmodule QrLabelSystemWeb.WorkspaceLive.Index do
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    workspaces = Workspaces.list_user_workspaces(user.id)

    # Preload membership counts and user roles for each workspace
    workspaces_with_info =
      Enum.map(workspaces, fn workspace ->
        members = Workspaces.list_members(workspace.id)
        role = Workspaces.get_user_role(workspace.id, user.id)

        %{
          workspace: workspace,
          member_count: length(members),
          role: role
        }
      end)

    {:ok,
     socket
     |> assign(:page_title, "Espacios de trabajo")
     |> assign(:workspaces, workspaces_with_info)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <.header>
        Espacios de trabajo
        <:subtitle>Gestiona tus espacios de trabajo personales y de equipo</:subtitle>
        <:actions>
          <.link navigate={~p"/workspaces/new"}>
            <.button>
              <svg class="w-4 h-4 mr-2 inline-block" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Nuevo espacio
            </.button>
          </.link>
        </:actions>
      </.header>

      <div class="mt-8 space-y-4">
        <%= for info <- @workspaces do %>
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-4 hover:shadow-md hover:border-gray-300 transition-all duration-200">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-4 min-w-0">
                <!-- Icon -->
                <div class={"flex-shrink-0 w-10 h-10 rounded-lg flex items-center justify-center " <>
                  if(info.workspace.type == "personal",
                    do: "bg-blue-100 text-blue-600",
                    else: "bg-purple-100 text-purple-600"
                  )}>
                  <%= if info.workspace.type == "personal" do %>
                    <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
                    </svg>
                  <% else %>
                    <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" />
                    </svg>
                  <% end %>
                </div>

                <!-- Info -->
                <div class="min-w-0">
                  <div class="flex items-center gap-2">
                    <h3 class="text-base font-semibold text-gray-900 truncate">
                      <%= info.workspace.name %>
                    </h3>
                    <!-- Type badge -->
                    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium " <>
                      if(info.workspace.type == "personal",
                        do: "bg-blue-100 text-blue-700",
                        else: "bg-purple-100 text-purple-700"
                      )}>
                      <%= if info.workspace.type == "personal", do: "Personal", else: "Equipo" %>
                    </span>
                    <!-- Role badge -->
                    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium " <>
                      case info.role do
                        "admin" -> "bg-amber-100 text-amber-700"
                        "operator" -> "bg-green-100 text-green-700"
                        _ -> "bg-gray-100 text-gray-600"
                      end}>
                      <%= role_label(info.role) %>
                    </span>
                  </div>
                  <div class="flex items-center gap-3 mt-1">
                    <%= if info.workspace.description do %>
                      <p class="text-sm text-gray-500 truncate"><%= info.workspace.description %></p>
                      <span class="text-gray-300">·</span>
                    <% end %>
                    <p class="text-sm text-gray-400">
                      <svg class="w-3.5 h-3.5 inline-block mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" />
                      </svg>
                      <%= info.member_count %> <%= if info.member_count == 1, do: "miembro", else: "miembros" %>
                    </p>
                  </div>
                </div>
              </div>

              <!-- Actions -->
              <div class="flex items-center gap-2 flex-shrink-0">
                <%= if info.role == "admin" && info.workspace.type == "team" do %>
                  <.link
                    navigate={~p"/workspaces/#{info.workspace.id}/settings"}
                    class="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg bg-gray-50 hover:bg-gray-100 border border-gray-200 hover:border-gray-300 text-gray-600 hover:text-gray-700 text-sm font-medium transition-all duration-200"
                  >
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z" />
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    Configurar
                  </.link>
                <% end %>
              </div>
            </div>
          </div>
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
