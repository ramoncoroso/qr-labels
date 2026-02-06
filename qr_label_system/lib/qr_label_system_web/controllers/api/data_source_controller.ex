defmodule QrLabelSystemWeb.API.DataSourceController do
  @moduledoc """
  API controller for data source operations.
  """
  use QrLabelSystemWeb, :controller

  alias QrLabelSystem.DataSources
  alias QrLabelSystem.DataSources.DbConnector

  @doc """
  Returns a preview of data from a data source.
  """
  def preview(conn, %{"id" => id}) do
    case DataSources.get_data_source(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Data source not found"})

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
    connection_config = %{
      type: config["type"],
      host: config["host"],
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

  def test_connection(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing config parameter"})
  end
end
