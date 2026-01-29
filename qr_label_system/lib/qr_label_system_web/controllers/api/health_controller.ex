defmodule QrLabelSystemWeb.API.HealthController do
  @moduledoc """
  Health check endpoint for monitoring and load balancers.
  """
  use QrLabelSystemWeb, :controller

  alias QrLabelSystem.Repo

  @doc """
  Returns the health status of the application.

  Checks:
  - Application is running
  - Database is connected
  """
  def check(conn, _params) do
    db_status = check_database()

    status = if db_status == :ok, do: :ok, else: :error
    http_status = if status == :ok, do: 200, else: 503

    json(conn |> put_status(http_status), %{
      status: status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: %{
        database: db_status,
        application: :ok
      },
      version: Application.spec(:qr_label_system, :vsn) |> to_string()
    })
  end

  defp check_database do
    try do
      Repo.query!("SELECT 1")
      :ok
    rescue
      _ -> :error
    end
  end
end
