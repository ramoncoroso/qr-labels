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
  """
  def get_setting(key) do
    case lookup_cache(key) do
      {:ok, value} -> value
      :miss -> fetch_and_cache(key)
    end
  end

  @doc """
  Set a setting value. Updates DB and invalidates cache.
  """
  def set_setting(key, value) do
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
    :ets.delete_all_objects(@table_name)
  rescue
    ArgumentError -> :ok
  end

  # GenServer callbacks

  @impl true
  def init(_) do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  # Private helpers

  defp lookup_cache(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expiry}] ->
        if System.monotonic_time(:millisecond) < expiry do
          {:ok, value}
        else
          :ets.delete(@table_name, key)
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
