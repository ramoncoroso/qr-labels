defmodule QrLabelSystemWeb.Admin.AuditLive do
  @moduledoc """
  Admin audit log viewer with filtering and export capabilities.
  """
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Audit
  alias QrLabelSystem.Audit.AuditExporter

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
      socket
      |> assign(:logs, [])
      |> assign(:filters, default_filters())
      |> assign(:stats, nil)
      |> assign(:page, 1)
      |> assign(:per_page, 50)
      |> assign(:total, 0)
      |> load_logs()
      |> load_stats()
    }
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = String.to_integer(Map.get(params, "page", "1"))

    filters = %{
      from: parse_date(Map.get(params, "from")),
      to: parse_date(Map.get(params, "to")),
      action: Map.get(params, "action"),
      resource_type: Map.get(params, "resource_type"),
      user_id: parse_integer(Map.get(params, "user_id"))
    }

    {:noreply,
      socket
      |> assign(:page, page)
      |> assign(:filters, filters)
      |> load_logs()
    }
  end

  @impl true
  def handle_event("filter", %{"filters" => filter_params}, socket) do
    params =
      filter_params
      |> Enum.reject(fn {_k, v} -> v == "" end)
      |> Enum.into(%{})

    {:noreply, push_patch(socket, to: ~p"/admin/audit?#{params}")}
  end

  @impl true
  def handle_event("clear_filters", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/audit")}
  end

  @impl true
  def handle_event("export_csv", _, socket) do
    opts = filters_to_opts(socket.assigns.filters)

    case AuditExporter.export(:csv, opts) do
      {:ok, csv_data} ->
        {:noreply,
          socket
          |> push_event("download", %{
            filename: "audit_logs_#{Date.utc_today()}.csv",
            content: csv_data,
            content_type: "text/csv"
          })
        }

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to export logs"))}
    end
  end

  @impl true
  def handle_event("export_json", _, socket) do
    opts = filters_to_opts(socket.assigns.filters)

    case AuditExporter.export(:json, opts) do
      {:ok, json_data} ->
        {:noreply,
          socket
          |> push_event("download", %{
            filename: "audit_logs_#{Date.utc_today()}.json",
            content: json_data,
            content_type: "application/json"
          })
        }

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to export logs"))}
    end
  end

  defp load_logs(socket) do
    %{filters: filters, page: page, per_page: per_page} = socket.assigns

    # Convert filters to params map expected by Audit.list_logs
    params =
      filters
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.map(fn
        {:from, date} -> {"from_date", Date.to_iso8601(date)}
        {:to, date} -> {"to_date", Date.to_iso8601(date)}
        {k, v} -> {to_string(k), v}
      end)
      |> Enum.into(%{})
      |> Map.merge(%{"page" => to_string(page), "per_page" => to_string(per_page)})

    result = Audit.list_logs(params)

    socket
    |> assign(:logs, result.logs)
    |> assign(:total, result.total)
  end

  defp load_stats(socket) do
    stats = AuditExporter.stats()
    assign(socket, :stats, stats)
  end

  defp filters_to_opts(filters) do
    filters
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.map(fn {k, v} -> {k, v} end)
    |> Keyword.new()
  end

  defp default_filters do
    %{
      from: nil,
      to: nil,
      action: nil,
      resource_type: nil,
      user_id: nil
    }
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil
  defp parse_integer(string) do
    case Integer.parse(string) do
      {int, ""} -> int
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6" id="audit-log" phx-hook="DownloadHook">
      <.header>
        <%= gettext("Audit Log") %>
        <:subtitle><%= gettext("View and export system activity logs") %></:subtitle>
        <:actions>
          <div class="flex gap-2">
            <button phx-click="export_csv" class="btn-secondary">
              <.icon name="hero-document-text" class="w-4 h-4 mr-2" />
              <%= gettext("Export CSV") %>
            </button>
            <button phx-click="export_json" class="btn-secondary">
              <.icon name="hero-code-bracket" class="w-4 h-4 mr-2" />
              <%= gettext("Export JSON") %>
            </button>
          </div>
        </:actions>
      </.header>

      <!-- Stats Summary -->
      <%= if @stats do %>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div class="bg-white rounded-lg shadow p-4">
            <div class="text-sm text-gray-500"><%= gettext("Total Events") %></div>
            <div class="text-2xl font-bold"><%= @stats.total %></div>
          </div>
          <div class="bg-white rounded-lg shadow p-4">
            <div class="text-sm text-gray-500"><%= gettext("Actions") %></div>
            <div class="text-2xl font-bold"><%= map_size(@stats.by_action) %></div>
          </div>
          <div class="bg-white rounded-lg shadow p-4">
            <div class="text-sm text-gray-500"><%= gettext("Resource Types") %></div>
            <div class="text-2xl font-bold"><%= map_size(@stats.by_resource_type) %></div>
          </div>
          <div class="bg-white rounded-lg shadow p-4">
            <div class="text-sm text-gray-500"><%= gettext("Active Users") %></div>
            <div class="text-2xl font-bold"><%= map_size(@stats.by_user) %></div>
          </div>
        </div>
      <% end %>

      <!-- Filters -->
      <div class="bg-white rounded-lg shadow p-4">
        <form phx-submit="filter" class="grid grid-cols-1 md:grid-cols-6 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              <%= gettext("From Date") %>
            </label>
            <input
              type="date"
              name="filters[from]"
              value={@filters.from && Date.to_iso8601(@filters.from)}
              class="w-full border rounded-lg px-3 py-2"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              <%= gettext("To Date") %>
            </label>
            <input
              type="date"
              name="filters[to]"
              value={@filters.to && Date.to_iso8601(@filters.to)}
              class="w-full border rounded-lg px-3 py-2"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              <%= gettext("Action") %>
            </label>
            <select name="filters[action]" class="w-full border rounded-lg px-3 py-2">
              <option value=""><%= gettext("All") %></option>
              <option value="create" selected={@filters.action == "create"}>Create</option>
              <option value="update" selected={@filters.action == "update"}>Update</option>
              <option value="delete" selected={@filters.action == "delete"}>Delete</option>
              <option value="login" selected={@filters.action == "login"}>Login</option>
              <option value="logout" selected={@filters.action == "logout"}>Logout</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              <%= gettext("Resource Type") %>
            </label>
            <select name="filters[resource_type]" class="w-full border rounded-lg px-3 py-2">
              <option value=""><%= gettext("All") %></option>
              <option value="user" selected={@filters.resource_type == "user"}>User</option>
              <option value="design" selected={@filters.resource_type == "design"}>Design</option>
              <option value="batch" selected={@filters.resource_type == "batch"}>Batch</option>
              <option value="data_source" selected={@filters.resource_type == "data_source"}>Data Source</option>
            </select>
          </div>
          <div class="flex items-end gap-2">
            <button type="submit" class="btn-primary">
              <%= gettext("Filter") %>
            </button>
            <button type="button" phx-click="clear_filters" class="btn-secondary">
              <%= gettext("Clear") %>
            </button>
          </div>
        </form>
      </div>

      <!-- Logs Table -->
      <div class="bg-white rounded-lg shadow overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                <%= gettext("Timestamp") %>
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                <%= gettext("Action") %>
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                <%= gettext("Resource") %>
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                <%= gettext("User") %>
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                <%= gettext("IP Address") %>
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                <%= gettext("Details") %>
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for log <- @logs do %>
              <tr class="hover:bg-gray-50">
                <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-500">
                  <%= Calendar.strftime(log.inserted_at, "%Y-%m-%d %H:%M:%S") %>
                </td>
                <td class="px-4 py-3 whitespace-nowrap">
                  <.action_badge action={log.action} />
                </td>
                <td class="px-4 py-3 whitespace-nowrap text-sm">
                  <span class="font-medium"><%= log.resource_type %></span>
                  <span class="text-gray-500">#<%= log.resource_id %></span>
                </td>
                <td class="px-4 py-3 whitespace-nowrap text-sm">
                  <%= if log.user do %>
                    <%= log.user.email %>
                  <% else %>
                    <span class="text-gray-400">-</span>
                  <% end %>
                </td>
                <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-500">
                  <%= log.ip_address || "-" %>
                </td>
                <td class="px-4 py-3 text-sm">
                  <%= if log.metadata && map_size(log.metadata) > 0 do %>
                    <button
                      class="text-blue-600 hover:text-blue-800"
                      title={Jason.encode!(log.metadata, pretty: true)}
                    >
                      <%= gettext("View changes") %>
                    </button>
                  <% else %>
                    <span class="text-gray-400">-</span>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>

        <!-- Empty State -->
        <%= if @logs == [] do %>
          <div class="text-center py-12 text-gray-500">
            <%= gettext("No audit logs found") %>
          </div>
        <% end %>

        <!-- Pagination -->
        <div class="bg-gray-50 px-6 py-3 flex items-center justify-between">
          <div class="text-sm text-gray-500">
            <%= gettext("Showing") %> <%= length(@logs) %> <%= gettext("of") %> <%= @total %>
          </div>
          <div class="flex gap-2">
            <%= if @page > 1 do %>
              <.link patch={~p"/admin/audit?page=#{@page - 1}"} class="px-3 py-1 border rounded hover:bg-gray-100">
                <%= gettext("Previous") %>
              </.link>
            <% end %>
            <%= if @page * @per_page < @total do %>
              <.link patch={~p"/admin/audit?page=#{@page + 1}"} class="px-3 py-1 border rounded hover:bg-gray-100">
                <%= gettext("Next") %>
              </.link>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp action_badge(assigns) do
    {bg_color, text_color} = case assigns.action do
      "create" -> {"bg-green-100", "text-green-800"}
      "update" -> {"bg-blue-100", "text-blue-800"}
      "delete" -> {"bg-red-100", "text-red-800"}
      "login" -> {"bg-purple-100", "text-purple-800"}
      "logout" -> {"bg-gray-100", "text-gray-800"}
      _ -> {"bg-gray-100", "text-gray-800"}
    end

    assigns = assign(assigns, :bg_color, bg_color)
    assigns = assign(assigns, :text_color, text_color)

    ~H"""
    <span class={"px-2 py-1 text-xs font-medium rounded-full #{@bg_color} #{@text_color}"}>
      <%= @action %>
    </span>
    """
  end
end
