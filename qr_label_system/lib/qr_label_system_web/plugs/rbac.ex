defmodule QrLabelSystemWeb.Plugs.RBAC do
  @moduledoc """
  Role-Based Access Control (RBAC) plugs.

  Provides authorization based on user roles:
  - admin: Full access to all features including user management
  - operator: Can create designs, import data, generate and print labels
  - viewer: Read-only access to designs and batches

  Usage in router:
    plug :require_admin
    plug :require_operator
    plug :require_viewer
  """
  import Plug.Conn
  import Phoenix.Controller

  alias QrLabelSystem.Accounts.User

  @doc """
  Requires the current user to be an admin.
  """
  def require_admin(conn, _opts) do
    if has_role?(conn, :admin) do
      conn
    else
      unauthorized(conn, "Se requieren permisos de administrador")
    end
  end

  @doc """
  Requires the current user to be an admin or operator.
  """
  def require_operator(conn, _opts) do
    if has_role?(conn, :operator) and has_workspace_role?(conn, :operator) do
      conn
    else
      unauthorized(conn, "Se requieren permisos de operador")
    end
  end

  @doc """
  Requires the current user to have at least viewer role.
  All authenticated users have viewer access.
  """
  def require_viewer(conn, _opts) do
    if has_role?(conn, :viewer) do
      conn
    else
      unauthorized(conn, "Se requiere autenticación")
    end
  end

  @doc """
  Checks if the current user can perform an action on a resource.

  Used for resource-level authorization (e.g., can user edit this design?)
  """
  def authorize_resource(conn, resource, action) do
    user = conn.assigns[:current_user]

    cond do
      # Admins can do anything
      User.admin?(user) ->
        conn

      # Check resource ownership for operators
      User.operator?(user) and can_access_resource?(user, resource, action) ->
        conn

      # Viewers can only read
      User.viewer?(user) and action in [:show, :index, :list] ->
        conn

      true ->
        unauthorized(conn, "No tienes permiso para realizar esta acción")
    end
  end

  # LiveView on_mount callbacks for RBAC

  @doc """
  LiveView on_mount callbacks for role-based access control.

  - `:require_admin` - Only allows admin users
  - `:require_operator` - Only allows operator users (includes admins)
  - `:require_viewer` - Any authenticated user
  """
  def on_mount(role, params, session, socket)

  def on_mount(:require_admin, _params, _session, socket) do
    if socket.assigns[:current_user] && User.admin?(socket.assigns.current_user) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "Se requieren permisos de administrador")
        |> Phoenix.LiveView.redirect(to: "/")

      {:halt, socket}
    end
  end

  def on_mount(:require_operator, _params, _session, socket) do
    if socket.assigns[:current_user] && User.operator?(socket.assigns.current_user) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "Se requieren permisos de operador")
        |> Phoenix.LiveView.redirect(to: "/")

      {:halt, socket}
    end
  end

  def on_mount(:require_viewer, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "Se requiere autenticación")
        |> Phoenix.LiveView.redirect(to: "/users/log_in")

      {:halt, socket}
    end
  end

  # Private functions

  defp has_role?(conn, :admin), do: User.admin?(conn.assigns[:current_user])
  defp has_role?(conn, :operator), do: User.operator?(conn.assigns[:current_user])
  defp has_role?(conn, :viewer), do: User.viewer?(conn.assigns[:current_user])

  defp has_workspace_role?(conn, :operator) do
    case conn.assigns[:current_workspace] do
      nil -> true
      workspace ->
        role = QrLabelSystem.Workspaces.get_user_role(workspace.id, conn.assigns[:current_user].id)
        role in ["admin", "operator"]
    end
  end

  defp can_access_resource?(user, %{user_id: owner_id}, action) when action in [:edit, :update, :delete] do
    # Users can modify their own resources
    user.id == owner_id
  end

  defp can_access_resource?(_user, _resource, action) when action in [:show, :index, :list] do
    # Everyone can view
    true
  end

  defp can_access_resource?(_user, _resource, _action) do
    # Default deny
    false
  end

  defp unauthorized(conn, message) do
    if is_api_request?(conn) do
      conn
      |> put_status(:forbidden)
      |> json(%{error: message})
      |> halt()
    else
      conn
      |> put_flash(:error, message)
      |> redirect(to: "/")
      |> halt()
    end
  end

  defp is_api_request?(conn) do
    case get_req_header(conn, "accept") do
      ["application/json" <> _] -> true
      _ -> String.starts_with?(conn.request_path, "/api")
    end
  end
end
