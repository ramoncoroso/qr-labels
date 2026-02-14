defmodule QrLabelSystemWeb.DesignController do
  use QrLabelSystemWeb, :controller

  alias QrLabelSystem.Designs

  @doc """
  Fallback POST handler for when LiveView websocket doesn't connect.
  Creates a new design and redirects to the editor.
  """
  def create(conn, %{"design" => design_params}) do
    design_params =
      design_params
      |> Map.put("user_id", conn.assigns.current_user.id)
      |> Map.put("workspace_id", conn.assigns.current_workspace.id)

    case Designs.create_design(design_params) do
      {:ok, design} ->
        conn
        |> put_flash(:info, "Diseño creado exitosamente")
        |> redirect(to: ~p"/designs/#{design.id}/edit")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Error al crear el diseño. Verifica los datos.")
        |> redirect(to: ~p"/designs/new")
    end
  end

  @doc """
  Deletes a design.
  """
  def delete(conn, %{"id" => id}) do
    case Designs.get_design(id) do
      nil ->
        conn
        |> put_flash(:error, "Diseño no encontrado")
        |> redirect(to: ~p"/designs")

      design ->
        if design.user_id == conn.assigns.current_user.id and
           design.workspace_id == conn.assigns.current_workspace.id do
          {:ok, _} = Designs.delete_design(design)

          conn
          |> put_flash(:info, "Diseño eliminado exitosamente")
          |> redirect(to: ~p"/designs")
        else
          conn
          |> put_flash(:error, "No tienes permiso para eliminar este diseño")
          |> redirect(to: ~p"/designs")
        end
    end
  end
end
