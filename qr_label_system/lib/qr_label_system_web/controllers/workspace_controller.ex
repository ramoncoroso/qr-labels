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

    case Integer.parse(id) do
      {int_id, ""} when int_id > 0 ->
        if Workspaces.member?(int_id, user.id) do
          conn
          |> put_session(:current_workspace_id, int_id)
          |> put_flash(:info, "Espacio de trabajo cambiado")
          |> redirect(to: ~p"/designs")
        else
          conn
          |> put_flash(:error, "No tienes acceso a ese espacio de trabajo")
          |> redirect(to: ~p"/designs")
        end

      _ ->
        conn
        |> put_flash(:error, "ID de espacio invalido")
        |> redirect(to: ~p"/designs")
    end
  end
end
