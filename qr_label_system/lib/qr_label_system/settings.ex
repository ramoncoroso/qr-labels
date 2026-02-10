defmodule QrLabelSystem.Settings do
  @moduledoc """
  Context for system-wide settings with ETS cache.
  Settings are stored in the database and cached in ETS
  for fast reads without hitting the DB on every request.
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
  On cache miss, fetches from DB via GenServer (which owns the ETS table).
  """
  def get_setting(key) do
    case lookup_cache(key) do
      {:ok, value} -> value
      :miss -> GenServer.call(__MODULE__, {:fetch_setting, key})
    end
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
  Routed through GenServer since ETS table is :protected.
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
  def handle_call({:fetch_setting, key}, _from, state) do
    # Re-check cache (another process may have populated it)
    result = case lookup_cache(key) do
      {:ok, value} -> value
      :miss -> fetch_and_cache(key)
    end
    {:reply, result, state}
  end

  @impl true
  def handle_call({:set_setting, key, value}, _from, state) do
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
        {:reply, {:ok, setting}, state}

      error ->
        {:reply, error, state}
    end
  end

  # Private helpers

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

  defp fetch_and_cache(key) do
    case Repo.one(from s in SystemSetting, where: s.key == ^key) do
      nil -> nil
      setting ->
        put_cache(key, setting.value)
        setting.value
    end
  end

  defp put_cache(key, value) do
    expiry = System.monotonic_time(:millisecond) + @cache_ttl_ms
    :ets.insert(@table_name, {key, value, expiry})
  rescue
    ArgumentError -> :ok
  end
end
