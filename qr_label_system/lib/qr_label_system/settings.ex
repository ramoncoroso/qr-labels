defmodule QrLabelSystem.Settings do
  @moduledoc """
  Context for system-wide settings with ETS cache.
  Settings are stored in the database and cached in ETS
  for fast reads without hitting the DB on every request.

  The ETS table is :protected (only GenServer can write).
  DB reads happen in the calling process for Ecto Sandbox compatibility.
  Writes are serialized through GenServer to prevent race conditions.
  """
  use GenServer

  import Ecto.Query, warn: false
  alias QrLabelSystem.Repo
  alias QrLabelSystem.Settings.SystemSetting

  @table_name :system_settings_cache
  @cache_ttl_ms 60_000

  # Client API

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Get a setting value by key. Returns cached value if available.
  On cache miss, reads DB from caller process and populates cache via GenServer.
  """
  def get_setting(key) do
    case lookup_cache(key) do
      {:ok, value} ->
        value

      :miss ->
        # DB read in caller process (Ecto Sandbox compatible)
        case Repo.one(from s in SystemSetting, where: s.key == ^key) do
          nil ->
            nil

          setting ->
            # Populate cache via GenServer (ETS owner)
            GenServer.cast(__MODULE__, {:put_cache, key, setting.value})
            setting.value
        end
    end
  rescue
    # Handle case where GenServer isn't started yet or DB unavailable
    _ -> nil
  end

  @doc """
  Set a setting value. Updates DB and invalidates cache.
  Serialized through GenServer to prevent race conditions.
  """
  def set_setting(key, value) do
    GenServer.call(__MODULE__, {:set_setting, key, value})
  end

  @doc """
  Returns true if approval workflow is required.
  """
  def approval_required? do
    get_setting("approval_required") == "true"
  end

  @doc """
  Clears the ETS cache. Used in tests to avoid stale cache.
  """
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  rescue
    _ -> :ok
  end

  # GenServer callbacks

  @impl true
  def init(_) do
    :ets.new(@table_name, [:named_table, :set, :protected, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:set_setting, key, value}, {from_pid, _}, state) do
    # Allow caller's sandbox connection for DB access
    result =
      try do
        Ecto.Adapters.SQL.Sandbox.allow(Repo, from_pid, self())
        do_set_setting(key, value)
      rescue
        # Fallback for non-sandbox (prod) or if allow fails
        _ -> do_set_setting(key, value)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:put_cache, key, value}, state) do
    put_cache(key, value)
    {:noreply, state}
  end

  # Private helpers

  defp do_set_setting(key, value) do
    result =
      case Repo.one(from s in SystemSetting, where: s.key == ^key) do
        nil ->
          %SystemSetting{}
          |> SystemSetting.changeset(%{key: key, value: value})
          |> Repo.insert()

        setting ->
          setting
          |> SystemSetting.changeset(%{value: value})
          |> Repo.update()
      end

    case result do
      {:ok, setting} ->
        put_cache(key, setting.value)
        {:ok, setting}

      error ->
        error
    end
  end

  defp lookup_cache(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expiry}] ->
        if System.monotonic_time(:millisecond) < expiry do
          {:ok, value}
        else
          :miss
        end

      [] ->
        :miss
    end
  rescue
    ArgumentError -> :miss
  end

  defp put_cache(key, value) do
    expiry = System.monotonic_time(:millisecond) + @cache_ttl_ms
    :ets.insert(@table_name, {key, value, expiry})
  rescue
    ArgumentError -> :ok
  end
end
