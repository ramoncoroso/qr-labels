defmodule QrLabelSystem.DataSources.DbConnector do
  @moduledoc """
  Connector for external databases.
  Supports PostgreSQL, MySQL, and SQL Server.
  """

  @timeout 30_000

  # Compiled once at module load - more efficient than creating on each call
  @dangerous_patterns [
    # DDL/DML statements
    ~r/\b(DROP|DELETE|UPDATE|INSERT|ALTER|CREATE|TRUNCATE|GRANT|REVOKE|MERGE)\b/i,

    # SELECT INTO (creates tables)
    ~r/\bSELECT\b[^;]*\bINTO\s+(OUTFILE|DUMPFILE|TEMPORARY|TABLE|\w+\.\w+|\w+)\b/i,

    # CTEs can wrap dangerous operations
    ~r/\bWITH\s+\w+\s+(AS\s*)?\(/i,

    # Comments (bypass filters)
    ~r/(--|\/\*|\*\/|#)/,

    # UNION-based injection
    ~r/\bUNION\s+(ALL\s+)?SELECT\b/i,

    # Stacked queries
    ~r/;\s*(SELECT|INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|EXEC|WITH)/i,

    # PostgreSQL dangerous functions
    ~r/\b(pg_read_file|pg_read_binary_file|pg_ls_dir|pg_stat_file)\s*\(/i,
    ~r/\b(lo_import|lo_export|lo_get|lo_put)\s*\(/i,
    ~r/\b(pg_sleep|pg_terminate_backend|pg_cancel_backend)\s*\(/i,
    ~r/\b(dblink|dblink_exec|dblink_connect)\s*\(/i,
    ~r/\bCOPY\s+\w+\s+(FROM|TO)\b/i,

    # MySQL dangerous functions and operations
    ~r/\b(LOAD_FILE|LOAD\s+DATA)\s*[\(\s]/i,
    ~r/\bINTO\s+(OUTFILE|DUMPFILE)\b/i,
    ~r/\b(BENCHMARK|SLEEP)\s*\(/i,

    # SQL Server dangerous operations
    ~r/\b(xp_|sp_)\w+/i,
    ~r/\b(EXEC|EXECUTE)\s*[\(\s@]/i,
    ~r/\b(OPENROWSET|OPENDATASOURCE|OPENQUERY)\s*\(/i,
    ~r/\bWAITFOR\s+(DELAY|TIME)\b/i,
    ~r/\bBULK\s+INSERT\b/i,

    # Information schema (recon)
    ~r/\bINFORMATION_SCHEMA\b/i,
    ~r/\bpg_catalog\b/i,
    ~r/\bsys\.(databases|tables|columns|objects)\b/i,

    # Hex encoding (bypass attempts)
    ~r/0x[0-9a-fA-F]{4,}/,

    # String manipulation functions (often used for bypass)
    ~r/\b(CHAR|CHR|UNHEX|CONV)\s*\(/i,

    # Dynamic SQL construction
    ~r/\b(PREPARE|DEALLOCATE)\s+\w+/i
  ]

  @doc """
  Tests a database connection.
  Returns :ok or {:error, reason}

  Accepts either:
  - `test_connection(type, config)` - explicit type and config
  - `test_connection(config)` - config map with :type key
  """
  def test_connection(%{type: type} = config) do
    test_connection(type, config)
  end

  def test_connection(type, config) do
    with {:ok, conn} <- connect(type, config) do
      disconnect(type, conn)
      :ok
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

  IMPORTANT: For production use, also configure the database connection
  with a read-only user that only has SELECT privileges on specific tables.
  This provides defense-in-depth against SQL injection.
  """
  def validate_query(query) when is_binary(query) do
    # Normalize Unicode to prevent bypass with fullwidth characters (e.g., ＤＥＬＥＴＥ)
    normalized_query =
      query
      |> String.trim()
      |> normalize_unicode()

    cond do
      String.length(normalized_query) == 0 ->
        {:error, "Query cannot be empty"}

      String.length(normalized_query) > 10_000 ->
        {:error, "Query is too long (max 10,000 characters)"}

      not String.match?(normalized_query, ~r/^\s*SELECT\b/i) ->
        {:error, "Only SELECT queries are allowed"}

      String.match?(normalized_query, ~r/;\s*\w/i) ->
        {:error, "Multiple statements are not allowed"}

      has_dangerous_pattern?(normalized_query) ->
        {:error, "Query contains potentially dangerous patterns"}

      true ->
        :ok
    end
  end

  def validate_query(_), do: {:error, "Query must be a string"}

  # Normalize fullwidth Unicode characters to ASCII equivalents
  # Prevents bypass attempts using characters like Ａ-Ｚ (U+FF21-U+FF3A)
  defp normalize_unicode(query) do
    query
    |> String.to_charlist()
    |> Enum.map(&normalize_char/1)
    |> List.to_string()
  end

  # Fullwidth ASCII variants (U+FF01-U+FF5E) map to ASCII (U+0021-U+007E)
  defp normalize_char(char) when char >= 0xFF01 and char <= 0xFF5E do
    char - 0xFF01 + 0x0021
  end
  defp normalize_char(char), do: char

  defp has_dangerous_pattern?(query) do
    Enum.any?(@dangerous_patterns, &String.match?(query, &1))
  end

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
