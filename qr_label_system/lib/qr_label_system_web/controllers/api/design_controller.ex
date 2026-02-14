defmodule QrLabelSystemWeb.API.DesignController do
  @moduledoc """
  API controller for design export/import operations.
  """
  use QrLabelSystemWeb, :controller

  alias QrLabelSystem.Designs

  @doc """
  Exports a design as JSON.
  """
  def export(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    workspace = resolve_api_workspace(conn)

    case Designs.get_design(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Not found"})

      design when design.user_id != user.id ->
        conn |> put_status(:not_found) |> json(%{error: "Not found"})

      design when not is_nil(workspace) and design.workspace_id != workspace.id ->
        conn |> put_status(:not_found) |> json(%{error: "Not found"})

      design ->
        export_data = %{
          name: design.name,
          width: design.width,
          height: design.height,
          elements: design.elements,
          exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          version: "1.0"
        }

        safe_name = design.name
          |> String.replace(~r/[^\w\s\-\.]/u, "")
          |> String.slice(0, 100)

        conn
        |> put_resp_header("content-disposition", "attachment; filename=\"#{safe_name}.json\"")
        |> json(export_data)
    end
  end

  @doc """
  Imports a design from JSON.
  """
  def import(conn, %{"design" => design_params}) do
    user = conn.assigns.current_user
    workspace = resolve_api_workspace(conn)

    attrs = %{
      name: design_params["name"] || "Imported Design",
      width: design_params["width"] || 100,
      height: design_params["height"] || 50,
      elements: design_params["elements"] || [],
      user_id: user.id,
      workspace_id: workspace && workspace.id
    }

    case Designs.create_design(attrs) do
      {:ok, design} ->
        conn
        |> put_status(:created)
        |> json(%{
          message: "Design imported successfully",
          design_id: design.id
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to import design", details: format_errors(changeset)})
    end
  end

  def import(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing design parameter"})
  end

  defp resolve_api_workspace(conn) do
    case conn.assigns do
      %{current_workspace: ws} when not is_nil(ws) -> ws
      _ ->
        user = conn.assigns.current_user
        QrLabelSystem.Workspaces.get_personal_workspace(user.id)
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
