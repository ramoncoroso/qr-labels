defmodule QrLabelSystem.Audit.AuditExporter do
  @moduledoc """
  Export audit logs to various formats.

  Supports:
  - CSV export
  - JSON export
  - Filtered exports by date range, action, user

  ## Usage

      # Export all logs as CSV
      {:ok, csv_data} = AuditExporter.export(:csv)

      # Export with filters
      {:ok, csv_data} = AuditExporter.export(:csv,
        from: ~D[2024-01-01],
        to: ~D[2024-01-31],
        action: "create",
        user_id: 123
      )

      # Export as JSON
      {:ok, json_data} = AuditExporter.export(:json)

      # Stream export for large datasets
      AuditExporter.stream_export(:csv, opts)
      |> Stream.into(file)
      |> Stream.run()
  """

  import Ecto.Query
  alias QrLabelSystem.Repo
  alias QrLabelSystem.Audit.Log

  @csv_headers [
    "ID",
    "Action",
    "Resource Type",
    "Resource ID",
    "User ID",
    "User Email",
    "IP Address",
    "User Agent",
    "Metadata",
    "Timestamp"
  ]

  @doc """
  Exports audit logs in the specified format.

  ## Options
  - `:from` - Start date (Date)
  - `:to` - End date (Date)
  - `:action` - Filter by action (string)
  - `:resource_type` - Filter by resource type (string)
  - `:user_id` - Filter by user ID (integer)
  - `:limit` - Maximum number of records (integer, default: 10000)
  """
  def export(format, opts \\ []) do
    logs = fetch_logs(opts)

    case format do
      :csv -> {:ok, to_csv(logs)}
      :json -> {:ok, to_json(logs)}
      _ -> {:error, :unsupported_format}
    end
  end

  @doc """
  Returns a stream for exporting large datasets.
  Useful for downloading without loading all data into memory.
  """
  def stream_export(format, opts \\ []) do
    query = build_query(opts)

    case format do
      :csv ->
        Stream.concat(
          [csv_header_row()],
          Repo.stream(query)
          |> Stream.map(&to_csv_row/1)
        )

      :json ->
        Repo.stream(query)
        |> Stream.map(&to_json_row/1)

      _ ->
        Stream.resource(fn -> :error end, fn _ -> {:halt, :error} end, fn _ -> :ok end)
    end
  end

  @doc """
  Exports audit logs to a file.
  """
  def export_to_file(format, path, opts \\ []) do
    case export(format, opts) do
      {:ok, data} ->
        File.write(path, data)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns statistics about audit logs.
  """
  def stats(opts \\ []) do
    # Use base query without order_by for aggregate functions
    query = build_base_query(opts)

    %{
      total: Repo.aggregate(query, :count),
      by_action: count_by_field(query, :action),
      by_resource_type: count_by_field(query, :resource_type),
      by_user: count_by_user(query),
      date_range: get_date_range(query)
    }
  end

  # Private functions

  defp fetch_logs(opts) do
    opts
    |> build_query()
    |> Repo.all()
    |> Repo.preload(:user)
  end

  defp build_base_query(opts) do
    Log
    |> maybe_filter_date_range(opts)
    |> maybe_filter_action(opts)
    |> maybe_filter_resource_type(opts)
    |> maybe_filter_user(opts)
  end

  defp build_query(opts) do
    limit = Keyword.get(opts, :limit, 10_000)

    opts
    |> build_base_query()
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
  end

  defp maybe_filter_date_range(query, opts) do
    from_date = Keyword.get(opts, :from)
    to_date = Keyword.get(opts, :to)

    query
    |> maybe_filter_from_date(from_date)
    |> maybe_filter_to_date(to_date)
  end

  defp maybe_filter_from_date(query, nil), do: query
  defp maybe_filter_from_date(query, from_date) do
    from_datetime = DateTime.new!(from_date, ~T[00:00:00], "Etc/UTC")
    from(a in query, where: a.inserted_at >= ^from_datetime)
  end

  defp maybe_filter_to_date(query, nil), do: query
  defp maybe_filter_to_date(query, to_date) do
    to_datetime = DateTime.new!(to_date, ~T[23:59:59], "Etc/UTC")
    from(a in query, where: a.inserted_at <= ^to_datetime)
  end

  defp maybe_filter_action(query, opts) do
    case Keyword.get(opts, :action) do
      nil -> query
      action -> from(a in query, where: a.action == ^action)
    end
  end

  defp maybe_filter_resource_type(query, opts) do
    case Keyword.get(opts, :resource_type) do
      nil -> query
      resource_type -> from(a in query, where: a.resource_type == ^resource_type)
    end
  end

  defp maybe_filter_user(query, opts) do
    case Keyword.get(opts, :user_id) do
      nil -> query
      user_id -> from(a in query, where: a.user_id == ^user_id)
    end
  end

  defp count_by_field(base_query, field) do
    base_query
    |> group_by([a], field(a, ^field))
    |> select([a], {field(a, ^field), count(a.id)})
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp count_by_user(base_query) do
    base_query
    |> join(:left, [a], u in assoc(a, :user))
    |> group_by([a, u], [a.user_id, u.email])
    |> select([a, u], {u.email, count(a.id)})
    |> limit(10)
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp get_date_range(base_query) do
    result = base_query
    |> select([a], %{
      min: min(a.inserted_at),
      max: max(a.inserted_at)
    })
    |> Repo.one()

    case result do
      %{min: nil, max: nil} -> nil
      %{min: min, max: max} -> %{from: min, to: max}
    end
  end

  # CSV formatting

  defp to_csv(logs) do
    [csv_header_row() | Enum.map(logs, &to_csv_row/1)]
    |> Enum.join("\n")
  end

  defp csv_header_row do
    Enum.join(@csv_headers, ",")
  end

  defp to_csv_row(log) do
    [
      log.id,
      escape_csv(log.action),
      escape_csv(log.resource_type),
      log.resource_id,
      log.user_id,
      escape_csv(get_user_email(log)),
      escape_csv(log.ip_address),
      escape_csv(log.user_agent),
      escape_csv(encode_metadata(log.metadata)),
      format_timestamp(log.inserted_at)
    ]
    |> Enum.join(",")
  end

  defp escape_csv(nil), do: ""
  defp escape_csv(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"#{String.replace(value, "\"", "\"\"")}\""
    else
      value
    end
  end
  defp escape_csv(value), do: to_string(value)

  # JSON formatting

  defp to_json(logs) do
    logs
    |> Enum.map(&to_json_row/1)
    |> Jason.encode!(pretty: true)
  end

  defp to_json_row(log) do
    %{
      id: log.id,
      action: log.action,
      resource_type: log.resource_type,
      resource_id: log.resource_id,
      user_id: log.user_id,
      user_email: get_user_email(log),
      ip_address: log.ip_address,
      user_agent: log.user_agent,
      metadata: log.metadata,
      timestamp: format_timestamp(log.inserted_at)
    }
  end

  # Helpers

  defp get_user_email(%{user: %{email: email}}), do: email
  defp get_user_email(_), do: nil

  defp encode_metadata(nil), do: ""
  defp encode_metadata(metadata) when is_map(metadata) do
    Jason.encode!(metadata)
  end
  defp encode_metadata(metadata), do: to_string(metadata)

  defp format_timestamp(nil), do: ""
  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end
end
