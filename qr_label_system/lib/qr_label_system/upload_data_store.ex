defmodule QrLabelSystem.UploadDataStore do
  @moduledoc """
  Metadata-only storage for upload data during the design workflow.
  Full row data lives in the browser's IndexedDB; only lightweight
  metadata (columns, total_rows, sample_rows) is kept here.

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
  Store metadata for a user and design.
  sample_rows: first N rows for preview (typically 5).
  """
  def put_metadata(user_id, design_id, columns, total_rows, sample_rows) do
    user_id = ensure_integer(user_id)
    design_id = normalize_design_id(design_id)
    GenServer.call(__MODULE__, {:put_metadata, {user_id, design_id}, columns, total_rows, sample_rows})
  end

  @doc """
  Get metadata for a user and design.
  Returns {columns, total_rows, sample_rows} or {[], 0, []} if not found or expired.
  """
  def get_metadata(user_id, design_id) do
    user_id = ensure_integer(user_id)
    design_id = normalize_design_id(design_id)
    GenServer.call(__MODULE__, {:get_metadata, {user_id, design_id}})
  end

  @doc """
  Check if metadata exists for a user and design.
  """
  def has_data?(user_id, design_id) do
    user_id = ensure_integer(user_id)
    design_id = normalize_design_id(design_id)
    GenServer.call(__MODULE__, {:has_data, {user_id, design_id}})
  end

  @doc """
  Move metadata from {user_id, nil} to {user_id, design_id}.
  Used when selecting a design in the data-first flow.
  """
  def associate_with_design(user_id, design_id) do
    user_id = ensure_integer(user_id)
    design_id = normalize_design_id(design_id)
    GenServer.call(__MODULE__, {:associate, user_id, design_id})
  end

  @doc """
  Clear metadata for a user and design.
  """
  def clear(user_id, design_id) do
    user_id = ensure_integer(user_id)
    design_id = normalize_design_id(design_id)
    GenServer.cast(__MODULE__, {:clear, {user_id, design_id}})
  end

  # Convenience: clear for nil design_id
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
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:put_metadata, key, columns, total_rows, sample_rows}, _from, state) do
    expiry = System.monotonic_time(:millisecond) + @expiry_ms
    :ets.insert(@table_name, {key, columns, total_rows, sample_rows, expiry})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_metadata, key}, _from, state) do
    case :ets.lookup(@table_name, key) do
      [{^key, columns, total_rows, sample_rows, expiry}] ->
        now = System.monotonic_time(:millisecond)
        if now < expiry do
          {:reply, {columns, total_rows, sample_rows}, state}
        else
          :ets.delete(@table_name, key)
          {:reply, {[], 0, []}, state}
        end

      [] ->
        {:reply, {[], 0, []}, state}
    end
  end

  @impl true
  def handle_call({:has_data, key}, _from, state) do
    case :ets.lookup(@table_name, key) do
      [{^key, _columns, total_rows, _sample_rows, expiry}] ->
        now = System.monotonic_time(:millisecond)
        if now < expiry and total_rows > 0 do
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
      [{^source_key, columns, total_rows, sample_rows, _expiry}] ->
        new_expiry = System.monotonic_time(:millisecond) + @expiry_ms
        :ets.insert(@table_name, {target_key, columns, total_rows, sample_rows, new_expiry})
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
    # Delete all expired entries (5-tuple format: {key, columns, total_rows, sample_rows, expiry})
    :ets.select_delete(@table_name, [{{:_, :_, :_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 5 * 60 * 1000)
  end
end
