defmodule QrLabelSystem.UploadDataStore do
  @moduledoc """
  Temporary storage for upload data during the design workflow.
  Data is stored per user and design, and expires after 30 minutes.

  Key format: {user_id, design_id} where design_id can be nil for unassigned data.
  """
  use GenServer

  @table_name :upload_data_store
  @expiry_ms 30 * 60 * 1000  # 30 minutes

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
  Store upload data for a user and design.
  Use design_id = nil for data not yet associated with a design.
  """
  def put(user_id, design_id, data, columns) do
    user_id = ensure_integer(user_id)
    design_id = normalize_design_id(design_id)
    GenServer.call(__MODULE__, {:put, {user_id, design_id}, data, columns})
  end

  @doc """
  Get upload data for a user and design.
  Returns {data, columns} or {nil, []} if not found or expired.
  """
  def get(user_id, design_id) do
    user_id = ensure_integer(user_id)
    design_id = normalize_design_id(design_id)
    GenServer.call(__MODULE__, {:get, {user_id, design_id}})
  end

  @doc """
  Check if data exists for a user and design.
  """
  def has_data?(user_id, design_id) do
    user_id = ensure_integer(user_id)
    design_id = normalize_design_id(design_id)
    GenServer.call(__MODULE__, {:has_data, {user_id, design_id}})
  end

  @doc """
  Move data from {user_id, nil} to {user_id, design_id}.
  Used when selecting a design in the data-first flow.
  """
  def associate_with_design(user_id, design_id) do
    user_id = ensure_integer(user_id)
    design_id = normalize_design_id(design_id)
    GenServer.call(__MODULE__, {:associate, user_id, design_id})
  end

  @doc """
  Clear upload data for a user and design.
  """
  def clear(user_id, design_id) do
    user_id = ensure_integer(user_id)
    design_id = normalize_design_id(design_id)
    GenServer.cast(__MODULE__, {:clear, {user_id, design_id}})
  end

  # Deprecated: Use put/4 instead
  @doc false
  def put(user_id, data, columns) do
    put(user_id, nil, data, columns)
  end

  # Deprecated: Use get/2 instead
  @doc false
  def get(user_id) do
    get(user_id, nil)
  end

  # Deprecated: Use clear/2 instead
  @doc false
  def clear(user_id) do
    clear(user_id, nil)
  end

  defp ensure_integer(id) when is_integer(id), do: id
  defp ensure_integer(id) when is_binary(id), do: String.to_integer(id)
  defp ensure_integer(nil), do: 0

  defp normalize_design_id(nil), do: nil
  defp normalize_design_id(id) when is_integer(id), do: id
  defp normalize_design_id(id) when is_binary(id), do: String.to_integer(id)

  # Server callbacks

  @impl true
  def init(_) do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    # Schedule periodic cleanup
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:put, key, data, columns}, _from, state) do
    expiry = System.monotonic_time(:millisecond) + @expiry_ms
    :ets.insert(@table_name, {key, data, columns, expiry})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    case :ets.lookup(@table_name, key) do
      [{^key, data, columns, expiry}] ->
        now = System.monotonic_time(:millisecond)
        if now < expiry do
          {:reply, {data, columns}, state}
        else
          :ets.delete(@table_name, key)
          {:reply, {nil, []}, state}
        end

      [] ->
        {:reply, {nil, []}, state}
    end
  end

  @impl true
  def handle_call({:has_data, key}, _from, state) do
    case :ets.lookup(@table_name, key) do
      [{^key, data, _columns, expiry}] ->
        now = System.monotonic_time(:millisecond)
        if now < expiry and data != nil and data != [] do
          {:reply, true, state}
        else
          if now >= expiry, do: :ets.delete(@table_name, key)
          {:reply, false, state}
        end

      [] ->
        {:reply, false, state}
    end
  end

  @impl true
  def handle_call({:associate, user_id, design_id}, _from, state) do
    source_key = {user_id, nil}
    target_key = {user_id, design_id}

    case :ets.lookup(@table_name, source_key) do
      [{^source_key, data, columns, _expiry}] ->
        # Create new entry with fresh expiry
        new_expiry = System.monotonic_time(:millisecond) + @expiry_ms
        :ets.insert(@table_name, {target_key, data, columns, new_expiry})
        # Delete the source entry
        :ets.delete(@table_name, source_key)
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :no_data}, state}
    end
  end

  @impl true
  def handle_cast({:clear, key}, state) do
    :ets.delete(@table_name, key)
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)
    # Delete all expired entries
    :ets.select_delete(@table_name, [{{:_, :_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    # Run cleanup every 5 minutes
    Process.send_after(self(), :cleanup, 5 * 60 * 1000)
  end
end
