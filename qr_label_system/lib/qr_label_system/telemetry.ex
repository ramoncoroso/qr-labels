defmodule QrLabelSystem.Telemetry do
  @moduledoc """
  Telemetry metrics and instrumentation for the QR Label System.

  Provides metrics for:
  - HTTP request duration and counts
  - Database query performance
  - Phoenix LiveView events
  - Business metrics (batches, labels, designs)
  - Authentication events
  - Rate limiting events

  ## Prometheus Integration

  To expose metrics via Prometheus, add to your endpoint:

      plug PromEx.Plug, prom_ex_module: QrLabelSystem.PromEx

  ## Custom Events

  Emit custom events using:

      :telemetry.execute(
        [:qr_label_system, :batch, :generated],
        %{label_count: 100},
        %{batch_id: 123, user_id: 456}
      )
  """

  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Returns all metrics definitions for the application.
  """
  def metrics do
    [
      # Phoenix HTTP Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond},
        description: "Request start time"
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        description: "Request duration",
        tags: [:route]
      ),
      counter("phoenix.endpoint.stop.duration",
        tags: [:method, :route, :status],
        description: "Total HTTP requests"
      ),

      # Phoenix Router Metrics
      summary("phoenix.router_dispatch.stop.duration",
        unit: {:native, :millisecond},
        tags: [:route],
        description: "Router dispatch duration"
      ),

      # Phoenix LiveView Metrics
      summary("phoenix.live_view.mount.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view],
        description: "LiveView mount duration"
      ),
      summary("phoenix.live_view.handle_event.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view, :event],
        description: "LiveView event handling duration"
      ),
      counter("phoenix.live_view.handle_event.stop.duration",
        tags: [:view, :event],
        description: "Total LiveView events"
      ),

      # Database Metrics (Ecto)
      summary("qr_label_system.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "Database query total time",
        tags: [:source]
      ),
      summary("qr_label_system.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "Database query queue time"
      ),
      summary("qr_label_system.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "Database query execution time"
      ),
      counter("qr_label_system.repo.query.total_time",
        tags: [:source],
        description: "Total database queries"
      ),

      # Authentication Metrics
      counter("qr_label_system.auth.login.success",
        tags: [:method],
        description: "Successful logins"
      ),
      counter("qr_label_system.auth.login.failure",
        tags: [:reason],
        description: "Failed login attempts"
      ),
      counter("qr_label_system.auth.logout",
        description: "Logout events"
      ),

      # API Metrics
      counter("qr_label_system.api.request",
        tags: [:endpoint, :method, :status],
        description: "API requests"
      ),
      summary("qr_label_system.api.response_time",
        unit: {:native, :millisecond},
        tags: [:endpoint],
        description: "API response time"
      ),

      # Rate Limiting Metrics
      counter("qr_label_system.rate_limit.allowed",
        tags: [:action],
        description: "Allowed requests"
      ),
      counter("qr_label_system.rate_limit.denied",
        tags: [:action],
        description: "Rate limited requests"
      ),

      # Business Metrics
      counter("qr_label_system.batch.created",
        tags: [:user_role],
        description: "Batches created"
      ),
      counter("qr_label_system.batch.generated",
        description: "Batches generated"
      ),
      summary("qr_label_system.batch.labels_count",
        description: "Labels per batch"
      ),
      counter("qr_label_system.design.created",
        description: "Designs created"
      ),
      counter("qr_label_system.file.uploaded",
        tags: [:type],
        description: "Files uploaded"
      ),

      # VM Metrics
      last_value("vm.memory.total",
        unit: :byte,
        description: "Total VM memory"
      ),
      last_value("vm.memory.processes",
        unit: :byte,
        description: "Process memory"
      ),
      last_value("vm.memory.binary",
        unit: :byte,
        description: "Binary memory"
      ),
      last_value("vm.total_run_queue_lengths.total",
        description: "Run queue length"
      ),
      last_value("vm.system_counts.process_count",
        description: "Process count"
      )
    ]
  end

  @doc """
  Periodic measurements executed by telemetry_poller.
  """
  def periodic_measurements do
    [
      # VM metrics
      {__MODULE__, :vm_memory_measurements, []},
      {__MODULE__, :vm_statistics_measurements, []},
      # Custom business metrics
      {__MODULE__, :business_metrics, []}
    ]
  end

  @doc false
  def vm_memory_measurements do
    memory = :erlang.memory()

    :telemetry.execute(
      [:vm, :memory],
      %{
        total: Keyword.get(memory, :total, 0),
        processes: Keyword.get(memory, :processes, 0),
        binary: Keyword.get(memory, :binary, 0),
        ets: Keyword.get(memory, :ets, 0),
        atom: Keyword.get(memory, :atom, 0)
      },
      %{}
    )
  end

  @doc false
  def vm_statistics_measurements do
    {:total, run_queue_total} = :erlang.statistics(:total_run_queue_lengths)
    process_count = :erlang.system_info(:process_count)

    :telemetry.execute(
      [:vm, :system_counts],
      %{
        process_count: process_count,
        run_queue_total: run_queue_total
      },
      %{}
    )
  end

  @doc false
  def business_metrics do
    # These would query the database for current counts
    # Implemented as no-op for now to avoid DB dependency during startup
    :ok
  end

  @doc """
  Emit a custom telemetry event for authentication.
  """
  def emit_auth_event(event_type, metadata \\ %{}) do
    :telemetry.execute(
      [:qr_label_system, :auth, event_type],
      %{count: 1},
      metadata
    )
  end

  @doc """
  Emit a custom telemetry event for batch operations.
  """
  def emit_batch_event(event_type, measurements, metadata \\ %{}) do
    :telemetry.execute(
      [:qr_label_system, :batch, event_type],
      measurements,
      metadata
    )
  end

  @doc """
  Emit a custom telemetry event for rate limiting.
  """
  def emit_rate_limit_event(action, allowed?) do
    event = if allowed?, do: :allowed, else: :denied

    :telemetry.execute(
      [:qr_label_system, :rate_limit, event],
      %{count: 1},
      %{action: action}
    )
  end
end
