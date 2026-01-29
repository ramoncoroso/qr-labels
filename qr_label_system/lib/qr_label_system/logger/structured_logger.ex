defmodule QrLabelSystem.Logger.StructuredLogger do
  @moduledoc """
  Structured logging utilities for consistent log formatting.

  Provides helper functions for emitting structured logs with consistent
  metadata across the application. All logs include:
  - Timestamp (ISO8601)
  - Log level
  - Event name
  - Context (user_id, request_id, etc.)
  - Custom metadata

  ## Usage

      alias QrLabelSystem.Logger.StructuredLogger, as: Log

      Log.info("batch.created", %{batch_id: 123, label_count: 100}, user_id: 456)
      Log.error("database.connection_failed", %{error: "timeout"})

  ## Configuration

  Add to config/config.exs:

      config :logger, :console,
        format: {QrLabelSystem.Logger.StructuredLogger, :format},
        metadata: [:request_id, :user_id, :event]
  """

  require Logger

  @doc """
  Logs an info-level structured event.
  """
  def info(event, data \\ %{}, metadata \\ []) do
    log(:info, event, data, metadata)
  end

  @doc """
  Logs a warning-level structured event.
  """
  def warn(event, data \\ %{}, metadata \\ []) do
    log(:warning, event, data, metadata)
  end

  @doc """
  Logs an error-level structured event.
  """
  def error(event, data \\ %{}, metadata \\ []) do
    log(:error, event, data, metadata)
  end

  @doc """
  Logs a debug-level structured event.
  """
  def debug(event, data \\ %{}, metadata \\ []) do
    log(:debug, event, data, metadata)
  end

  @doc """
  Logs a structured event at the specified level.
  """
  def log(level, event, data, metadata) do
    enriched_metadata = Keyword.merge([event: event], metadata)

    message = build_message(event, data)

    Logger.log(level, message, enriched_metadata)
  end

  @doc """
  Formats log messages in JSON format for structured logging.
  Can be used as the format function in Logger configuration.
  """
  def format(level, message, timestamp, metadata) do
    log_entry = %{
      timestamp: format_timestamp(timestamp),
      level: level,
      message: IO.iodata_to_binary(message),
      event: Keyword.get(metadata, :event),
      request_id: Keyword.get(metadata, :request_id),
      user_id: Keyword.get(metadata, :user_id),
      module: Keyword.get(metadata, :module),
      function: Keyword.get(metadata, :function),
      line: Keyword.get(metadata, :line)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    Jason.encode!(log_entry) <> "\n"
  rescue
    _ ->
      # Fallback to simple format if JSON encoding fails
      "[#{level}] #{message}\n"
  end

  # Private functions

  # Keys that should never be logged
  @sensitive_keys ~w(password token secret api_key access_token refresh_token credit_card ssn)a

  defp build_message(event, data) when map_size(data) == 0 do
    event
  end

  defp build_message(event, data) do
    data_str = data
    |> sanitize_sensitive_data()
    |> Enum.map(fn {k, v} -> "#{k}=#{inspect(v)}" end)
    |> Enum.join(" ")

    "#{event} #{data_str}"
  end

  defp sanitize_sensitive_data(data) do
    Enum.map(data, fn {key, value} ->
      atom_key = if is_binary(key), do: String.to_existing_atom(key), else: key
      if atom_key in @sensitive_keys do
        {key, "[REDACTED]"}
      else
        {key, value}
      end
    rescue
      ArgumentError -> {key, value}
    end)
    |> Map.new()
  end

  defp format_timestamp({date, {hour, minute, second, millisecond}}) do
    {:ok, datetime} = NaiveDateTime.new(
      elem(date, 0), elem(date, 1), elem(date, 2),
      hour, minute, second, millisecond * 1000
    )

    datetime
    |> NaiveDateTime.to_iso8601()
  end

  defp format_timestamp(_), do: DateTime.utc_now() |> DateTime.to_iso8601()
end
