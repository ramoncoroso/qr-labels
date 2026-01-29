defmodule QrLabelSystemWeb.TelemetryHandler do
  @moduledoc """
  Telemetry event handlers for web-specific events.

  Attaches handlers to Phoenix and custom telemetry events
  for logging and metrics collection.
  """

  require Logger

  @doc """
  Attaches all telemetry handlers.
  Call this from your application supervisor.
  """
  def attach do
    handlers = [
      # Phoenix request logging
      {:phoenix_request_handler, [:phoenix, :endpoint, :stop], &__MODULE__.handle_request/4},

      # Slow query logging
      {:slow_query_handler, [:qr_label_system, :repo, :query], &__MODULE__.handle_query/4},

      # Authentication events
      {:auth_handler, [:qr_label_system, :auth, :login], &__MODULE__.handle_auth/4},

      # Rate limiting events
      {:rate_limit_handler, [:qr_label_system, :rate_limit, :denied], &__MODULE__.handle_rate_limit/4}
    ]

    for {name, event, handler} <- handlers do
      :telemetry.attach(to_string(name), event, handler, nil)
    end
  end

  @doc """
  Handles Phoenix request completion events.
  Logs slow requests (> 1 second).
  """
  def handle_request(_event, %{duration: duration}, metadata, _config) do
    duration_ms = System.convert_time_unit(duration, :native, :millisecond)

    if duration_ms > 1000 do
      Logger.warning(
        "Slow request",
        duration_ms: duration_ms,
        method: metadata[:conn].method,
        path: metadata[:conn].request_path,
        status: metadata[:conn].status
      )
    end
  end

  @doc """
  Handles database query events.
  Logs slow queries (> 100ms).
  """
  def handle_query(_event, %{total_time: total_time}, metadata, _config) do
    duration_ms = System.convert_time_unit(total_time, :native, :millisecond)

    if duration_ms > 100 do
      Logger.warning(
        "Slow database query",
        duration_ms: duration_ms,
        source: metadata[:source],
        query: truncate_query(metadata[:query])
      )
    end
  end

  @doc """
  Handles authentication events.
  """
  def handle_auth(_event, _measurements, metadata, _config) do
    case metadata do
      %{success: true, user_id: user_id} ->
        Logger.info("User logged in", user_id: user_id)

      %{success: false, reason: reason} ->
        Logger.warning("Failed login attempt", reason: reason)

      _ ->
        :ok
    end
  end

  @doc """
  Handles rate limit denial events.
  """
  def handle_rate_limit(_event, _measurements, metadata, _config) do
    Logger.warning(
      "Rate limit exceeded",
      action: metadata[:action],
      identifier: metadata[:identifier]
    )
  end

  defp truncate_query(query) when is_binary(query) do
    if String.length(query) > 200 do
      String.slice(query, 0, 200) <> "..."
    else
      query
    end
  end

  defp truncate_query(_), do: "unknown"
end
