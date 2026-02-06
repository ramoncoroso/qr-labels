defmodule QrLabelSystemWeb.API.HealthController do
  @moduledoc """
  Health check endpoint for monitoring and load balancers.
  Provides detailed system health information and metrics.
  """
  use QrLabelSystemWeb, :controller

  alias QrLabelSystem.Repo
  alias QrLabelSystem.Cache

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

    # Note: Version intentionally omitted from public endpoint for security
    json(conn |> put_status(http_status), %{
      status: status,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: %{
        database: db_status,
        application: :ok
      }
    })
  end

  @doc """
  Returns detailed health information including all system components.
  In production, sensitive version information is omitted to prevent
  attackers from identifying specific vulnerabilities.
  """
  def detailed(conn, _params) do
    checks = %{
      database: check_database_detailed(),
      cache: check_cache(),
      memory: check_memory(),
      processes: check_processes(),
      oban: check_oban()
    }

    all_healthy = Enum.all?(checks, fn {_k, v} -> v.status == :ok end)
    http_status = if all_healthy, do: 200, else: 503

    response = %{
      status: if(all_healthy, do: :healthy, else: :degraded),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: checks
    }

    # Only include version info in non-production environments
    response =
      if Application.get_env(:qr_label_system, :env) != :prod do
        response
        |> Map.put(:uptime_seconds, get_uptime())
        |> Map.put(:version, Application.spec(:qr_label_system, :vsn) |> to_string())
        |> Map.put(:elixir_version, System.version())
        |> Map.put(:otp_version, :erlang.system_info(:otp_release) |> to_string())
      else
        response
      end

    json(conn |> put_status(http_status), response)
  end

  @doc """
  Returns Prometheus-compatible metrics.
  In production, only operational metrics are included (no version info).
  """
  def metrics(conn, _params) do
    is_prod = Application.get_env(:qr_label_system, :env) == :prod
    metrics = build_prometheus_metrics(is_prod)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, metrics)
  end

  # Private functions

  defp check_database do
    try do
      Repo.query!("SELECT 1")
      :ok
    rescue
      _ -> :error
    end
  end

  defp check_database_detailed do
    start_time = System.monotonic_time(:millisecond)

    try do
      Repo.query!("SELECT 1")
      latency = System.monotonic_time(:millisecond) - start_time

      pool_info = get_pool_info()

      %{
        status: :ok,
        latency_ms: latency,
        pool_size: pool_info.size,
        pool_checked_out: pool_info.checked_out
      }
    rescue
      _e ->
        # Don't expose internal error details for security
        %{
          status: :error,
          error: "Database connection failed"
        }
    end
  end

  defp get_pool_info do
    # Pool metrics are not reliably available via public APIs
    # Return configured pool size from repo config, not simulated values
    repo_config = Application.get_env(:qr_label_system, QrLabelSystem.Repo, [])
    pool_size = Keyword.get(repo_config, :pool_size, 10)
    %{size: pool_size, checked_out: :unavailable}
  end

  defp check_cache do
    try do
      stats = Cache.stats()
      total_entries = Enum.reduce(stats, 0, fn {_ns, s}, acc -> acc + s.size end)
      total_memory = Enum.reduce(stats, 0, fn {_ns, s}, acc -> acc + s.memory end)

      %{
        status: :ok,
        total_entries: total_entries,
        memory_bytes: total_memory,
        namespaces: stats
      }
    rescue
      _ ->
        %{status: :error, error: "Cache unavailable"}
    end
  end

  defp check_memory do
    memory = :erlang.memory()
    total = Keyword.get(memory, :total, 0)
    processes = Keyword.get(memory, :processes, 0)
    binary = Keyword.get(memory, :binary, 0)

    # Warn if using more than 80% of available memory
    memory_limit = Application.get_env(:qr_label_system, :memory_limit, 1_073_741_824)  # 1GB default
    usage_percent = (total / memory_limit) * 100

    status = cond do
      usage_percent > 90 -> :critical
      usage_percent > 80 -> :warning
      true -> :ok
    end

    %{
      status: status,
      total_bytes: total,
      processes_bytes: processes,
      binary_bytes: binary,
      usage_percent: Float.round(usage_percent, 2)
    }
  end

  defp check_processes do
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)
    usage_percent = (process_count / process_limit) * 100

    {:total, run_queue_total} = :erlang.statistics(:total_run_queue_lengths)

    status = cond do
      usage_percent > 90 -> :critical
      usage_percent > 70 -> :warning
      run_queue_total > 100 -> :warning
      true -> :ok
    end

    %{
      status: status,
      count: process_count,
      limit: process_limit,
      usage_percent: Float.round(usage_percent, 2),
      run_queue_length: run_queue_total
    }
  end

  defp check_oban do
    try do
      # Check if Oban is running
      case Process.whereis(Oban) do
        nil ->
          %{status: :error, error: "Oban not running"}

        _pid ->
          %{status: :ok, running: true}
      end
    rescue
      _ ->
        %{status: :error, error: "Cannot check Oban status"}
    end
  end

  defp get_uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    div(uptime_ms, 1000)
  end

  defp build_prometheus_metrics(is_prod) do
    memory = :erlang.memory()
    process_count = :erlang.system_info(:process_count)
    {:total, run_queue} = :erlang.statistics(:total_run_queue_lengths)

    cache_stats = try do
      Cache.stats()
    rescue
      _ -> %{}
    end

    cache_entries = Enum.reduce(cache_stats, 0, fn {_ns, s}, acc -> acc + s.size end)
    cache_memory = Enum.reduce(cache_stats, 0, fn {_ns, s}, acc -> acc + s.memory end)

    # Base metrics (always included)
    base_metrics = """
    # HELP qr_label_system_up Is the application running
    # TYPE qr_label_system_up gauge
    qr_label_system_up 1

    # HELP erlang_process_count Current number of processes
    # TYPE erlang_process_count gauge
    erlang_process_count #{process_count}

    # HELP erlang_run_queue_length Total run queue length
    # TYPE erlang_run_queue_length gauge
    erlang_run_queue_length #{run_queue}

    # HELP qr_label_system_cache_entries Total cache entries
    # TYPE qr_label_system_cache_entries gauge
    qr_label_system_cache_entries #{cache_entries}

    # HELP qr_label_system_cache_memory_bytes Cache memory usage in bytes
    # TYPE qr_label_system_cache_memory_bytes gauge
    qr_label_system_cache_memory_bytes #{cache_memory}
    """

    # Extended metrics (only in non-production - detailed memory and uptime)
    if is_prod do
      base_metrics
    else
      {uptime_ms, _} = :erlang.statistics(:wall_clock)

      base_metrics <> """
      # HELP qr_label_system_uptime_seconds Application uptime in seconds
      # TYPE qr_label_system_uptime_seconds counter
      qr_label_system_uptime_seconds #{div(uptime_ms, 1000)}

      # HELP erlang_memory_bytes Erlang VM memory usage
      # TYPE erlang_memory_bytes gauge
      erlang_memory_bytes{type="total"} #{Keyword.get(memory, :total, 0)}
      erlang_memory_bytes{type="processes"} #{Keyword.get(memory, :processes, 0)}
      erlang_memory_bytes{type="binary"} #{Keyword.get(memory, :binary, 0)}
      erlang_memory_bytes{type="ets"} #{Keyword.get(memory, :ets, 0)}
      erlang_memory_bytes{type="atom"} #{Keyword.get(memory, :atom, 0)}
      """
    end
  end
end
