defmodule QrLabelSystem.Cache do
  @moduledoc """
  Caching layer for frequently accessed data.

  Uses ETS tables for fast in-memory caching with TTL support.
  Automatically cleans up expired entries.

  ## Usage

      # Store a value with default TTL (5 minutes)
      Cache.put(:designs, design_id, design)

      # Store with custom TTL (10 minutes)
      Cache.put(:designs, design_id, design, ttl: 600_000)

      # Retrieve a value
      case Cache.get(:designs, design_id) do
        {:ok, design} -> design
        :miss -> load_from_db()
      end

      # Delete a value
      Cache.delete(:designs, design_id)

      # Clear all entries in a namespace
      Cache.clear(:designs)

  ## Available Namespaces

  - `:designs` - Label design configurations
  - `:users` - User data
  - `:stats` - Computed statistics
  """

  use GenServer
  require Logger

  @default_ttl 300_000  # 5 minutes
  @cleanup_interval 60_000  # 1 minute
  @namespaces [:designs, :users, :stats]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stores a value in the cache.

  ## Options
  - `:ttl` - Time to live in milliseconds (default: 5 minutes)
  """
  def put(namespace, key, value, opts \\ []) when namespace in @namespaces do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    expires_at = System.monotonic_time(:millisecond) + ttl

    true = :ets.insert(table_name(namespace), {{namespace, key}, value, expires_at})
    :ok
  end

  @doc """
  Retrieves a value from the cache.

  Returns `{:ok, value}` if found and not expired, `:miss` otherwise.
  """
  def get(namespace, key) when namespace in @namespaces do
    case :ets.lookup(table_name(namespace), {namespace, key}) do
      [{{^namespace, ^key}, value, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:ok, value}
        else
          # Expired, delete and return miss
          delete(namespace, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  @doc """
  Retrieves a value or computes it if not cached.

  ## Example

      Cache.fetch(:designs, design_id, fn ->
        Repo.get!(Design, design_id)
      end)
  """
  def fetch(namespace, key, compute_fn, opts \\ []) when is_function(compute_fn, 0) do
    case get(namespace, key) do
      {:ok, value} ->
        value

      :miss ->
        value = compute_fn.()
        put(namespace, key, value, opts)
        value
    end
  end

  @doc """
  Deletes a specific key from the cache.
  """
  def delete(namespace, key) when namespace in @namespaces do
    :ets.delete(table_name(namespace), {namespace, key})
    :ok
  end

  @doc """
  Clears all entries in a namespace.
  """
  def clear(namespace) when namespace in @namespaces do
    :ets.match_delete(table_name(namespace), {{namespace, :_}, :_, :_})
    :ok
  end

  @doc """
  Clears all caches.
  """
  def clear_all do
    for namespace <- @namespaces do
      clear(namespace)
    end

    :ok
  end

  @doc """
  Returns cache statistics.
  """
  def stats do
    for namespace <- @namespaces, into: %{} do
      table = table_name(namespace)
      info = :ets.info(table)

      {namespace, %{
        size: Keyword.get(info, :size, 0),
        memory: Keyword.get(info, :memory, 0) * :erlang.system_info(:wordsize)
      }}
    end
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS tables for each namespace
    for namespace <- @namespaces do
      :ets.new(table_name(namespace), [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private functions

  defp table_name(namespace), do: :"qr_cache_#{namespace}"

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_expired_entries do
    now = System.monotonic_time(:millisecond)
    deleted_count = Enum.reduce(@namespaces, 0, fn namespace, acc ->
      table = table_name(namespace)

      # Find and delete expired entries
      expired =
        :ets.select(table, [
          {{{:_, :_}, :_, :"$1"}, [{:<, :"$1", now}], [:"$_"]}
        ])

      for entry <- expired do
        :ets.delete_object(table, entry)
      end

      acc + length(expired)
    end)

    if deleted_count > 0 do
      Logger.debug("Cache cleanup: removed #{deleted_count} expired entries")
    end
  end
end
