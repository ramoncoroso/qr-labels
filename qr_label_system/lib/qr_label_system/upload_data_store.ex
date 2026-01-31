defmodule QrLabelSystem.UploadDataStore do
  @moduledoc """
  Temporary storage for upload data during the design workflow.
  Data is stored per user and expires after 30 minutes.
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
  Store upload data for a user.
  """
  def put(user_id, data, columns) do
    user_id = ensure_integer(user_id)
    GenServer.call(__MODULE__, {:put, user_id, data, columns})
  end

  @doc """
  Get upload data for a user.
  Returns {data, columns} or {nil, []} if not found or expired.
  """
  def get(user_id) do
    user_id = ensure_integer(user_id)
    GenServer.call(__MODULE__, {:get, user_id})
  end

  @doc """
  Clear upload data for a user.
  """
  def clear(user_id) do
    user_id = ensure_integer(user_id)
    GenServer.cast(__MODULE__, {:clear, user_id})
  end

  defp ensure_integer(id) when is_integer(id), do: id
  defp ensure_integer(id) when is_binary(id), do: String.to_integer(id)
  defp ensure_integer(nil), do: 0

  # Server callbacks

  @impl true
  def init(_) do
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    # Schedule periodic cleanup
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_call({:put, user_id, data, columns}, _from, state) do
    expiry = System.monotonic_time(:millisecond) + @expiry_ms
    :ets.insert(@table_name, {user_id, data, columns, expiry})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get, user_id}, _from, state) do
    case :ets.lookup(@table_name, user_id) do
      [{^user_id, data, columns, expiry}] ->
        now = System.monotonic_time(:millisecond)
        if now < expiry do
          {:reply, {data, columns}, state}
        else
          :ets.delete(@table_name, user_id)
          {:reply, {nil, []}, state}
        end

      [] ->
        {:reply, {nil, []}, state}
    end
  end

  @impl true
  def handle_cast({:clear, user_id}, state) do
    :ets.delete(@table_name, user_id)
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
