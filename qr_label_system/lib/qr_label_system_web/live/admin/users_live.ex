defmodule QrLabelSystemWeb.Admin.UsersLive do
  @moduledoc """
  Admin user management interface.
  """
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Accounts
  alias QrLabelSystem.Audit

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      users: list_users(),
      search: "",
      role_filter: nil,
      show_modal: false,
      selected_user: nil,
      changeset: nil,
      form: nil
    )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = Map.get(params, "page", "1")
    search = Map.get(params, "search", "")
    role = Map.get(params, "role")

    {:noreply,
      socket
      |> assign(:search, search)
      |> assign(:role_filter, role)
      |> assign(:users, list_users(%{"page" => page, "search" => search, "role" => role}))
    }
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/users?search=#{search}")}
  end

  @impl true
  def handle_event("filter_role", %{"role" => role}, socket) do
    role = if role == "", do: nil, else: role
    params = if role, do: %{"role" => role}, else: %{}

    {:noreply, push_patch(socket, to: ~p"/admin/users?#{params}")}
  end

  @impl true
  def handle_event("edit_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    changeset = Accounts.change_user_role(user)

    {:noreply,
      socket
      |> assign(:form, to_form(changeset))
      |> assign(:show_modal, true)
      |> assign(:selected_user, user)
      |> assign(:changeset, changeset)
    }
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply,
      socket
      |> assign(:show_modal, false)
      |> assign(:selected_user, nil)
      |> assign(:changeset, nil)
    }
  end

  @impl true
  def handle_event("update_role", %{"user" => user_params}, socket) do
    selected_user = socket.assigns.selected_user
    old_role = selected_user.role

    case Accounts.update_user_role(selected_user, user_params) do
      {:ok, updated_user} ->
        # Log the admin action
        Audit.log_async(:update_role, :user, updated_user.id,
          user_id: socket.assigns.current_user.id,
          metadata: %{
            target_user_email: updated_user.email,
            old_role: old_role,
            new_role: updated_user.role,
            admin_email: socket.assigns.current_user.email
          }
        )

        {:noreply,
          socket
          |> put_flash(:info, gettext("User role updated successfully"))
          |> assign(:show_modal, false)
          |> assign(:users, list_users())
        }

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("delete_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    # Don't allow deleting yourself
    if user.id == socket.assigns.current_user.id do
      {:noreply, put_flash(socket, :error, gettext("You cannot delete your own account"))}
    else
      case Accounts.delete_user(user) do
        {:ok, _} ->
          # Log the admin action
          Audit.log_async(:delete_user, :user, user.id,
            user_id: socket.assigns.current_user.id,
            metadata: %{
              deleted_user_email: user.email,
              deleted_user_role: user.role,
              admin_email: socket.assigns.current_user.email
            }
          )

          {:noreply,
            socket
            |> put_flash(:info, gettext("User deleted successfully"))
            |> assign(:users, list_users())
          }

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to delete user"))}
      end
    end
  end

  defp list_users(params \\ %{}) do
    Accounts.list_users(params)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        <%= gettext("User Management") %>
        <:subtitle><%= gettext("Manage user accounts and roles") %></:subtitle>
      </.header>

      <!-- Filters -->
      <div class="bg-white rounded-lg shadow p-4">
        <div class="flex flex-col md:flex-row gap-4">
          <div class="flex-1">
            <form phx-submit="search" class="relative">
              <input
                type="text"
                name="search"
                value={@search}
                placeholder={gettext("Search by email...")}
                class="w-full pl-10 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
              />
              <.icon name="hero-magnifying-glass" class="absolute left-3 top-2.5 w-5 h-5 text-gray-400" />
            </form>
          </div>
          <div>
            <form phx-change="filter_role">
              <select name="role" class="border rounded-lg px-4 py-2 focus:ring-2 focus:ring-blue-500">
                <option value=""><%= gettext("All Roles") %></option>
                <option value="admin" selected={@role_filter == "admin"}><%= gettext("Admin") %></option>
                <option value="operator" selected={@role_filter == "operator"}><%= gettext("Operator") %></option>
                <option value="viewer" selected={@role_filter == "viewer"}><%= gettext("Viewer") %></option>
              </select>
            </form>
          </div>
        </div>
      </div>

      <!-- Users Table -->
      <div class="bg-white rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                <%= gettext("Email") %>
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                <%= gettext("Role") %>
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                <%= gettext("Status") %>
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                <%= gettext("Created") %>
              </th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                <%= gettext("Actions") %>
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for user <- @users.users do %>
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    <div class="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white font-semibold">
                      <%= String.first(user.email) |> String.upcase() %>
                    </div>
                    <div class="ml-4">
                      <div class="text-sm font-medium text-gray-900"><%= user.email %></div>
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <.role_badge role={user.role} />
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <%= if user.confirmed_at do %>
                    <span class="px-2 py-1 text-xs font-medium bg-green-100 text-green-800 rounded-full">
                      <%= gettext("Confirmed") %>
                    </span>
                  <% else %>
                    <span class="px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-800 rounded-full">
                      <%= gettext("Pending") %>
                    </span>
                  <% end %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= Calendar.strftime(user.inserted_at, "%Y-%m-%d") %>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button
                    phx-click="edit_user"
                    phx-value-id={user.id}
                    class="text-blue-600 hover:text-blue-900 mr-3"
                  >
                    <%= gettext("Edit") %>
                  </button>
                  <%= if user.id != @current_user.id do %>
                    <button
                      phx-click="delete_user"
                      phx-value-id={user.id}
                      data-confirm={gettext("Are you sure you want to delete this user?")}
                      class="text-red-600 hover:text-red-900"
                    >
                      <%= gettext("Delete") %>
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>

        <!-- Pagination -->
        <%= if @users.total_pages > 1 do %>
          <div class="bg-gray-50 px-6 py-3 flex items-center justify-between">
            <div class="text-sm text-gray-500">
              <%= gettext("Showing") %> <%= (@users.page - 1) * @users.per_page + 1 %>
              - <%= min(@users.page * @users.per_page, @users.total) %>
              <%= gettext("of") %> <%= @users.total %> <%= gettext("users") %>
            </div>
            <div class="flex gap-2">
              <%= if @users.page > 1 do %>
                <.link patch={~p"/admin/users?page=#{@users.page - 1}"} class="px-3 py-1 border rounded hover:bg-gray-100">
                  <%= gettext("Previous") %>
                </.link>
              <% end %>
              <%= if @users.page < @users.total_pages do %>
                <.link patch={~p"/admin/users?page=#{@users.page + 1}"} class="px-3 py-1 border rounded hover:bg-gray-100">
                  <%= gettext("Next") %>
                </.link>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Edit Role Modal -->
      <%= if @show_modal do %>
        <.modal id="edit-role-modal" show on_cancel={JS.push("close_modal")}>
          <.header>
            <%= gettext("Edit User Role") %>
            <:subtitle><%= @selected_user.email %></:subtitle>
          </.header>

          <.simple_form for={@form} phx-submit="update_role">
            <.input
              field={@form[:role]}
              type="select"
              label={gettext("Role")}
              options={[
                {gettext("Admin"), "admin"},
                {gettext("Operator"), "operator"},
                {gettext("Viewer"), "viewer"}
              ]}
            />

            <:actions>
              <.button type="button" phx-click="close_modal" class="bg-gray-200 text-gray-800 hover:bg-gray-300">
                <%= gettext("Cancel") %>
              </.button>
              <.button type="submit">
                <%= gettext("Save Changes") %>
              </.button>
            </:actions>
          </.simple_form>
        </.modal>
      <% end %>
    </div>
    """
  end

  defp role_badge(assigns) do
    {bg_color, text_color} = case assigns.role do
      "admin" -> {"bg-red-100", "text-red-800"}
      "operator" -> {"bg-blue-100", "text-blue-800"}
      "viewer" -> {"bg-gray-100", "text-gray-800"}
      _ -> {"bg-gray-100", "text-gray-800"}
    end

    assigns = assign(assigns, :bg_color, bg_color)
    assigns = assign(assigns, :text_color, text_color)

    ~H"""
    <span class={"px-2 py-1 text-xs font-medium rounded-full #{@bg_color} #{@text_color}"}>
      <%= String.capitalize(@role) %>
    </span>
    """
  end
end
