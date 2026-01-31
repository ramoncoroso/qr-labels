defmodule QrLabelSystemWeb.Admin.DashboardLive do
  @moduledoc """
  Admin dashboard with system statistics and management tools.
  """
  use QrLabelSystemWeb, :live_view

  alias QrLabelSystem.Repo
  alias QrLabelSystem.Accounts.User

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Refresh stats every 30 seconds
      :timer.send_interval(30_000, self(), :refresh_stats)
    end

    {:ok, assign_stats(socket)}
  end

  @impl true
  def handle_info(:refresh_stats, socket) do
    {:noreply, assign_stats(socket)}
  end

  defp assign_stats(socket) do
    socket
    |> assign(:user_stats, get_user_stats())
    |> assign(:design_stats, get_design_stats())
    |> assign(:recent_activity, get_recent_activity())
    |> assign(:system_stats, get_system_stats())
  end

  defp get_user_stats do
    total = Repo.aggregate(User, :count)
    by_role = Repo.all(
      from u in User,
      group_by: u.role,
      select: {u.role, count(u.id)}
    ) |> Enum.into(%{})

    today = Date.utc_today()
    week_ago = Date.add(today, -7)

    new_this_week = Repo.one(
      from u in User,
      where: fragment("DATE(?)", u.inserted_at) >= ^week_ago,
      select: count(u.id)
    )

    %{
      total: total,
      admins: Map.get(by_role, "admin", 0),
      operators: Map.get(by_role, "operator", 0),
      viewers: Map.get(by_role, "viewer", 0),
      new_this_week: new_this_week
    }
  end

  defp get_design_stats do
    # Placeholder - would query actual design stats
    %{
      total: 0,
      active: 0,
      deleted: 0
    }
  end

  defp get_recent_activity do
    # Placeholder - would query audit logs
    []
  end

  defp get_system_stats do
    memory = :erlang.memory()
    {_, run_queue} = :erlang.statistics(:total_run_queue_lengths)

    %{
      memory_total_mb: div(Keyword.get(memory, :total, 0), 1024 * 1024),
      memory_processes_mb: div(Keyword.get(memory, :processes, 0), 1024 * 1024),
      process_count: :erlang.system_info(:process_count),
      run_queue: run_queue,
      uptime: get_uptime()
    }
  end

  defp get_uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    seconds = div(uptime_ms, 1000)
    minutes = div(seconds, 60)
    hours = div(minutes, 60)
    days = div(hours, 24)

    cond do
      days > 0 -> "#{days}d #{rem(hours, 24)}h"
      hours > 0 -> "#{hours}h #{rem(minutes, 60)}m"
      true -> "#{minutes}m #{rem(seconds, 60)}s"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        <%= gettext("Admin Dashboard") %>
        <:subtitle><%= gettext("System overview and management") %></:subtitle>
      </.header>

      <!-- Stats Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <!-- Users Card -->
        <.stat_card
          title={gettext("Users")}
          value={@user_stats.total}
          icon="hero-users"
          color="blue"
        >
          <div class="text-xs text-gray-500 mt-2">
            <span class="text-green-600">+<%= @user_stats.new_this_week %></span>
            <%= gettext("this week") %>
          </div>
        </.stat_card>

        <!-- Designs Card -->
        <.stat_card
          title={gettext("Designs")}
          value={@design_stats.total}
          icon="hero-document"
          color="purple"
        >
          <div class="text-xs text-gray-500 mt-2">
            <%= @design_stats.active %> <%= gettext("active") %>
          </div>
        </.stat_card>

        <!-- Security Info Card -->
        <.stat_card
          title={gettext("Data Security")}
          value="OK"
          icon="hero-shield-check"
          color="green"
        >
          <div class="text-xs text-gray-500 mt-2">
            <%= gettext("No print data stored") %>
          </div>
        </.stat_card>
      </div>

      <!-- User Roles -->
      <.card title={gettext("Users by Role")}>
        <div class="space-y-4">
          <.role_bar label={gettext("Admin")} count={@user_stats.admins} total={@user_stats.total} color="red" />
          <.role_bar label={gettext("Operator")} count={@user_stats.operators} total={@user_stats.total} color="blue" />
          <.role_bar label={gettext("Viewer")} count={@user_stats.viewers} total={@user_stats.total} color="gray" />
        </div>
      </.card>

      <!-- System Health -->
      <.card title={gettext("System Health")}>
        <div class="grid grid-cols-2 md:grid-cols-5 gap-4 text-center">
          <div>
            <div class="text-2xl font-bold text-gray-900"><%= @system_stats.memory_total_mb %> MB</div>
            <div class="text-sm text-gray-500"><%= gettext("Total Memory") %></div>
          </div>
          <div>
            <div class="text-2xl font-bold text-gray-900"><%= @system_stats.memory_processes_mb %> MB</div>
            <div class="text-sm text-gray-500"><%= gettext("Process Memory") %></div>
          </div>
          <div>
            <div class="text-2xl font-bold text-gray-900"><%= @system_stats.process_count %></div>
            <div class="text-sm text-gray-500"><%= gettext("Processes") %></div>
          </div>
          <div>
            <div class="text-2xl font-bold text-gray-900"><%= @system_stats.run_queue %></div>
            <div class="text-sm text-gray-500"><%= gettext("Run Queue") %></div>
          </div>
          <div>
            <div class="text-2xl font-bold text-gray-900"><%= @system_stats.uptime %></div>
            <div class="text-sm text-gray-500"><%= gettext("Uptime") %></div>
          </div>
        </div>
      </.card>

      <!-- Quick Actions -->
      <.card title={gettext("Quick Actions")}>
        <div class="flex flex-wrap gap-3">
          <.link navigate={~p"/admin/users"} class="btn-primary">
            <.icon name="hero-users" class="w-4 h-4 mr-2" />
            <%= gettext("Manage Users") %>
          </.link>
          <.link navigate={~p"/admin/audit"} class="btn-secondary">
            <.icon name="hero-document-text" class="w-4 h-4 mr-2" />
            <%= gettext("View Audit Log") %>
          </.link>
          <.link href={~p"/api/health"} target="_blank" class="btn-secondary">
            <.icon name="hero-heart" class="w-4 h-4 mr-2" />
            <%= gettext("API Health") %>
          </.link>
          <.link href="/dev/dashboard" target="_blank" class="btn-secondary">
            <.icon name="hero-chart-bar" class="w-4 h-4 mr-2" />
            <%= gettext("Phoenix Dashboard") %>
          </.link>
        </div>
      </.card>
    </div>
    """
  end

  # Components

  defp stat_card(assigns) do
    color_classes = %{
      "blue" => "bg-blue-50 text-blue-600",
      "purple" => "bg-purple-50 text-purple-600",
      "green" => "bg-green-50 text-green-600",
      "orange" => "bg-orange-50 text-orange-600"
    }

    assigns = assign(assigns, :color_class, Map.get(color_classes, assigns.color, "bg-gray-50 text-gray-600"))

    ~H"""
    <div class="bg-white rounded-lg shadow p-6">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm font-medium text-gray-500"><%= @title %></p>
          <p class="text-3xl font-bold text-gray-900"><%= @value %></p>
          <%= render_slot(@inner_block) %>
        </div>
        <div class={"p-3 rounded-full #{@color_class}"}>
          <.icon name={@icon} class="w-6 h-6" />
        </div>
      </div>
    </div>
    """
  end

  defp card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-lg font-semibold text-gray-900 mb-4"><%= @title %></h3>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  defp role_bar(assigns) do
    percentage = if assigns.total > 0, do: assigns.count / assigns.total * 100, else: 0
    assigns = assign(assigns, :percentage, percentage)

    color_classes = %{
      "red" => "bg-red-500",
      "blue" => "bg-blue-500",
      "gray" => "bg-gray-500"
    }

    assigns = assign(assigns, :color_class, Map.get(color_classes, assigns.color, "bg-gray-500"))

    ~H"""
    <div>
      <div class="flex justify-between text-sm mb-1">
        <span class="text-gray-600"><%= @label %></span>
        <span class="font-medium"><%= @count %></span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div class={"h-2 rounded-full #{@color_class}"} style={"width: #{@percentage}%"}></div>
      </div>
    </div>
    """
  end

end
