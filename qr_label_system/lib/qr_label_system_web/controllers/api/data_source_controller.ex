defmodule QrLabelSystemWeb.API.DataSourceController do
  @moduledoc """
  API controller for data source operations.
  """
  use QrLabelSystemWeb, :controller
  import Bitwise

  alias QrLabelSystem.DataSources
  alias QrLabelSystem.DataSources.DbConnector

  @doc """
  Returns a preview of data from a data source.
  """
  def preview(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    workspace = resolve_api_workspace(conn)

    case DataSources.get_data_source(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Not found"})

      data_source when data_source.user_id != user.id ->
        conn |> put_status(:not_found) |> json(%{error: "Not found"})

      data_source when not is_nil(workspace) and data_source.workspace_id != workspace.id ->
        conn |> put_status(:not_found) |> json(%{error: "Not found"})

      data_source ->
        case DataSources.get_data_from_source(data_source, limit: 10) do
          {:ok, %{columns: columns, rows: rows}} ->
            json(conn, %{
              columns: columns,
              rows: rows,
              preview: true
            })

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to fetch preview", reason: to_string(reason)})
        end
    end
  end

  @doc """
  Tests a database connection with the provided configuration.
  """
  def test_connection(conn, %{"config" => config}) do
    host = config["host"] || ""

    case validate_host(host) do
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: reason})

      :ok ->
        connection_config = %{
          type: config["type"],
          host: host,
          port: config["port"],
          database: config["database"],
          username: config["username"],
          password: config["password"]
        }

        case DbConnector.test_connection(connection_config) do
          :ok ->
            json(conn, %{status: "ok", message: "Connection successful"})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{status: "error", message: to_string(reason)})
        end
    end
  end

  def test_connection(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing config parameter"})
  end

  # SSRF protection: block connections to private/internal networks
  @blocked_cidrs [
    {127, 0, 0, 0, 8},       # 127.0.0.0/8 loopback
    {10, 0, 0, 0, 8},        # 10.0.0.0/8 private
    {172, 16, 0, 0, 12},     # 172.16.0.0/12 private
    {192, 168, 0, 0, 16},    # 192.168.0.0/16 private
    {169, 254, 0, 0, 16},    # 169.254.0.0/16 link-local / cloud metadata
    {0, 0, 0, 0, 8}          # 0.0.0.0/8
  ]

  defp validate_host(""), do: {:error, "Host is required"}

  defp validate_host(host) do
    case :inet.getaddr(String.to_charlist(host), :inet) do
      {:ok, ip} ->
        if blocked_ip?(ip), do: {:error, "Connection to private/internal networks is not allowed"}, else: :ok

      {:error, _} ->
        {:error, "Cannot resolve hostname: #{host}"}
    end
  end

  defp blocked_ip?({a, b, c, d}) do
    ip_int = a * 16_777_216 + b * 65_536 + c * 256 + d

    Enum.any?(@blocked_cidrs, fn {na, nb, nc, nd, prefix_len} ->
      net_int = na * 16_777_216 + nb * 65_536 + nc * 256 + nd
      mask = bsl(0xFFFFFFFF, 32 - prefix_len) |> band(0xFFFFFFFF)
      band(ip_int, mask) == band(net_int, mask)
    end)
  end

  defp resolve_api_workspace(conn) do
    case conn.assigns do
      %{current_workspace: ws} when not is_nil(ws) -> ws
      _ ->
        user = conn.assigns.current_user
        QrLabelSystem.Workspaces.get_personal_workspace(user.id)
    end
  end
end
