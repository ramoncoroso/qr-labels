defmodule QrLabelSystem.DataSources.DbConnector do
  @moduledoc """
  Connector for external databases.
  Supports PostgreSQL, MySQL, and SQL Server.
  """

  @timeout 30_000
  @max_retries 3

  @doc """
  Tests a database connection.
  Returns {:ok, :connected} or {:error, reason}
  """
  def test_connection(type, config) do
    with {:ok, conn} <- connect(type, config) do
      disconnect(type, conn)
      {:ok, :connected}
    end
  end

  @doc """
  Executes a query and returns the results.
  Returns {:ok, %{headers: [...], rows: [...], total: n}} or {:error, reason}
  """
  def execute_query(type, config, query, opts \\ []) do
    max_rows = Keyword.get(opts, :max_rows, 10_000)

    with {:ok, conn} <- connect(type, config),
         {:ok, result} <- run_query(type, conn, query, max_rows) do
      disconnect(type, conn)
      {:ok, result}
    end
  end

  @doc """
  Validates a SQL query with comprehensive security checks.
  Only allows safe SELECT queries.
  """
  def validate_query(query) when is_binary(query) do
    query = String.trim(query)

    # Define dangerous patterns that should never appear in queries
    dangerous_patterns = [
      # DDL statements
      ~r/\b(DROP|DELETE|UPDATE|INSERT|ALTER|CREATE|TRUNCATE|GRANT|REVOKE)\b/i,
      # Command execution
      ~r/\b(EXEC|EXECUTE|xp_|sp_)\b/i,
      # Comments (can be used to bypass filters)
      ~r/(--|\/\*|\*\/|#)/,
      # UNION-based injection attempts
      ~r/\bUNION\s+(ALL\s+)?SELECT\b/i,
      # Stacked queries
      ~r/;\s*(SELECT|INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|EXEC)/i,
      # Sleep/benchmark attacks
      ~r/\b(SLEEP|BENCHMARK|WAITFOR|PG_SLEEP)\s*\(/i,
      # File operations
      ~r/\b(LOAD_FILE|INTO\s+OUTFILE|INTO\s+DUMPFILE)\b/i,
      # Information schema exploitation
      ~r/\bINFORMATION_SCHEMA\b/i,
      # Hex encoding (bypass attempts)
      ~r/0x[0-9a-fA-F]+/,
      # Char/chr functions (bypass attempts)
      ~r/\b(CHAR|CHR|CONCAT)\s*\(/i
    ]

    cond do
      String.length(query) == 0 ->
        {:error, "Query cannot be empty"}

      String.length(query) > 10_000 ->
        {:error, "Query is too long (max 10,000 characters)"}

      not String.match?(query, ~r/^\s*SELECT\b/i) ->
        {:error, "Only SELECT queries are allowed"}

      String.match?(query, ~r/;\s*\w/i) ->
        {:error, "Multiple statements are not allowed"}

      Enum.any?(dangerous_patterns, &String.match?(query, &1)) ->
        {:error, "Query contains potentially dangerous patterns"}

      true ->
        :ok
    end
  end

  def validate_query(_), do: {:error, "Query must be a string"}

  # Connection functions

  defp connect("postgresql", config) do
    opts = [
      hostname: config["host"],
      port: config["port"] || 5432,
      database: config["database"],
      username: config["username"],
      password: config["password"],
      timeout: @timeout,
      connect_timeout: @timeout
    ]

    case Postgrex.start_link(opts) do
      {:ok, conn} -> {:ok, {:postgrex, conn}}
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  defp connect("mysql", config) do
    opts = [
      hostname: config["host"],
      port: config["port"] || 3306,
      database: config["database"],
      username: config["username"],
      password: config["password"],
      timeout: @timeout,
      connect_timeout: @timeout
    ]

    if Code.ensure_loaded?(MyXQL) do
      case MyXQL.start_link(opts) do
        {:ok, conn} -> {:ok, {:myxql, conn}}
        {:error, reason} -> {:error, format_error(reason)}
      end
    else
      {:error, "MySQL driver not available. Install :myxql dependency."}
    end
  end

  defp connect("sqlserver", config) do
    opts = [
      hostname: config["host"],
      port: config["port"] || 1433,
      database: config["database"],
      username: config["username"],
      password: config["password"],
      timeout: @timeout
    ]

    if Code.ensure_loaded?(Tds) do
      case Tds.start_link(opts) do
        {:ok, conn} -> {:ok, {:tds, conn}}
        {:error, reason} -> {:error, format_error(reason)}
      end
    else
      {:error, "SQL Server driver not available. Install :tds dependency."}
    end
  end

  defp connect(type, _config) do
    {:error, "Unsupported database type: #{type}"}
  end

  defp disconnect(_type, {_driver, conn}) do
    GenServer.stop(conn, :normal)
  rescue
    _ -> :ok
  end

  # Query execution

  defp run_query(type, {driver, conn}, query, max_rows) do
    # Add LIMIT if not present for safety
    limited_query = add_limit(type, query, max_rows)

    result = case driver do
      :postgrex -> Postgrex.query(conn, limited_query, [], timeout: @timeout)
      :myxql -> if Code.ensure_loaded?(MyXQL), do: MyXQL.query(conn, limited_query, [], timeout: @timeout), else: {:error, "MyXQL not loaded"}
      :tds -> if Code.ensure_loaded?(Tds), do: Tds.query(conn, limited_query, [], timeout: @timeout), else: {:error, "Tds not loaded"}
    end

    case result do
      {:ok, %{columns: columns, rows: rows}} ->
        headers = columns || []
        data_rows = Enum.map(rows || [], &row_to_map(headers, &1))

        {:ok, %{
          headers: headers,
          rows: data_rows,
          total: length(data_rows)
        }}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp add_limit("postgresql", query, max_rows) do
    if String.match?(query, ~r/LIMIT\s+\d+/i) do
      query
    else
      "#{query} LIMIT #{max_rows}"
    end
  end

  defp add_limit("mysql", query, max_rows) do
    if String.match?(query, ~r/LIMIT\s+\d+/i) do
      query
    else
      "#{query} LIMIT #{max_rows}"
    end
  end

  defp add_limit("sqlserver", query, max_rows) do
    if String.match?(query, ~r/TOP\s+\d+/i) do
      query
    else
      String.replace(query, ~r/^SELECT/i, "SELECT TOP #{max_rows}")
    end
  end

  defp row_to_map(headers, row) when is_list(row) do
    headers
    |> Enum.zip(row)
    |> Enum.into(%{}, fn {header, value} ->
      {header, normalize_value(value)}
    end)
  end

  defp normalize_value(nil), do: nil
  defp normalize_value(value) when is_binary(value), do: value
  defp normalize_value(value) when is_number(value), do: value
  defp normalize_value(%Date{} = date), do: Date.to_iso8601(date)
  defp normalize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp normalize_value(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp normalize_value(value), do: to_string(value)

  defp format_error(%{message: message}), do: message
  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
