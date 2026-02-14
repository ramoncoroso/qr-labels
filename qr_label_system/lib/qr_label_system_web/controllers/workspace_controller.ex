defmodule QrLabelSystemWeb.WorkspaceController do
  use QrLabelSystemWeb, :controller

  alias QrLabelSystem.Workspaces

  @doc """
  Switches the current workspace for the user's session.
  Must be a regular controller (not LiveView) because session
  is read-only in WebSocket connections.
  """
  def switch(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    if Workspaces.member?(id, user.id) do
      conn
      |> put_session(:current_workspace_id, String.to_integer(id))
      |> put_flash(:info, "Espacio de trabajo cambiado")
      |> redirect(to: ~p"/designs")
    else
      conn
      |> put_flash(:error, "No tienes acceso a ese espacio de trabajo")
      |> redirect(to: ~p"/designs")
    end
  end
end
