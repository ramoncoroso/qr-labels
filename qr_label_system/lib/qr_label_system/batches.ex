defmodule QrLabelSystem.Batches do
  @moduledoc """
  The Batches context.
  Handles label batch creation, management, and generation.
  """

  import Ecto.Query, warn: false
  alias QrLabelSystem.Repo
  alias QrLabelSystem.Batches.Batch
  alias QrLabelSystem.Designs
  alias QrLabelSystem.DataSources

  @doc """
  Returns the list of batches.
  """
  def list_batches do
    Repo.all(
      from b in Batch,
        preload: [:design, :user],
        order_by: [desc: b.updated_at]
    )
  end

  @doc """
  Returns the list of batches for a specific user.
  """
  def list_user_batches(user_id) do
    Repo.all(
      from b in Batch,
        where: b.user_id == ^user_id,
        preload: [:design],
        order_by: [desc: b.updated_at]
    )
  end

  @doc """
  Returns batches with pagination and optional filters.
  """
  def list_batches(params) do
    page = Map.get(params, "page", "1") |> parse_int(1)
    per_page = Map.get(params, "per_page", "20") |> parse_int(20)
    user_id = Map.get(params, "user_id")
    status = Map.get(params, "status")

    offset = (page - 1) * per_page

    base_query = from(b in Batch,
      preload: [:design, :user],
      order_by: [desc: b.updated_at]
    )

    query =
      base_query
      |> maybe_filter_by_user(user_id)
      |> maybe_filter_by_status(status)

    batches = query |> limit(^per_page) |> offset(^offset) |> Repo.all()
    total = query |> exclude(:preload) |> Repo.aggregate(:count)

    %{
      batches: batches,
      page: page,
      per_page: per_page,
      total: total,
      total_pages: ceil(total / per_page)
    }
  end

  defp maybe_filter_by_user(query, nil), do: query
  defp maybe_filter_by_user(query, user_id) do
    from b in query, where: b.user_id == ^user_id
  end

  defp maybe_filter_by_status(query, nil), do: query
  defp maybe_filter_by_status(query, ""), do: query
  defp maybe_filter_by_status(query, status) do
    from b in query, where: b.status == ^status
  end

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end
  defp parse_int(value, _default) when is_integer(value), do: value
  defp parse_int(_, default), do: default

  @doc """
  Gets a single batch with preloaded associations.
  """
  def get_batch!(id) do
    Repo.get!(Batch, id)
    |> Repo.preload([:design, :data_source, :user, :printed_by])
  end

  @doc """
  Gets a single batch, returns nil if not found.
  """
  def get_batch(id), do: Repo.get(Batch, id)

  @doc """
  Creates a batch.
  """
  def create_batch(attrs \\ %{}) do
    %Batch{}
    |> Batch.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a batch.
  """
  def update_batch(%Batch{} = batch, attrs) do
    batch
    |> Batch.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates batch status.
  """
  def update_batch_status(%Batch{} = batch, status) do
    batch
    |> Batch.status_changeset(status)
    |> Repo.update()
  end

  @doc """
  Deletes a batch.
  """
  def delete_batch(%Batch{} = batch) do
    Repo.delete(batch)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking batch changes.
  """
  def change_batch(%Batch{} = batch, attrs \\ %{}) do
    Batch.changeset(batch, attrs)
  end

  # ==========================================
  # BATCH GENERATION
  # ==========================================

  @doc """
  Prepares a batch for label generation.
  Returns the design, data rows, and mapping.
  """
  def prepare_generation(%Batch{} = batch, file_path \\ nil) do
    batch = Repo.preload(batch, [:design, :data_source])

    with {:ok, data} <- get_batch_data(batch, file_path) do
      {:ok, %{
        batch: batch,
        design: batch.design,
        column_mapping: batch.column_mapping,
        rows: data.rows,
        total: data.total
      }}
    end
  end

  defp get_batch_data(%Batch{data_source: nil}, file_path) when is_binary(file_path) do
    # Excel file uploaded directly
    DataSources.ExcelParser.parse_file(file_path)
  end

  defp get_batch_data(%Batch{data_source: %{type: "excel"} = _source}, file_path)
       when is_binary(file_path) do
    DataSources.ExcelParser.parse_file(file_path)
  end

  defp get_batch_data(%Batch{data_source: source}, _file_path) when not is_nil(source) do
    DataSources.get_data(source, nil)
  end

  defp get_batch_data(%Batch{data_snapshot: snapshot}, _) when is_list(snapshot) do
    # Use cached data snapshot
    headers = if Enum.empty?(snapshot), do: [], else: Map.keys(List.first(snapshot))
    {:ok, %{headers: headers, rows: snapshot, total: length(snapshot)}}
  end

  defp get_batch_data(_, _) do
    {:error, "No data source configured for this batch"}
  end

  @doc """
  Records that a batch was printed.
  """
  def record_print(%Batch{} = batch, user_id) do
    batch
    |> Batch.print_changeset(user_id)
    |> Repo.update()
  end

  @doc """
  Saves the print configuration for a batch.
  """
  def save_print_config(%Batch{} = batch, config) do
    batch
    |> Batch.print_config_changeset(config)
    |> Repo.update()
  end

  @doc """
  Archives old batches (older than specified days).
  """
  def archive_old_batches(days \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    from(b in Batch,
      where: b.status == "printed" and b.updated_at < ^cutoff
    )
    |> Repo.update_all(set: [status: "archived"])
  end

  # ==========================================
  # STATISTICS
  # ==========================================

  @doc """
  Returns batch statistics for a user.

  Optimized to use a single query with conditional aggregates
  instead of multiple queries (N+1 fix).
  """
  def get_user_stats(user_id) do
    # Single query with conditional counts
    result =
      from(b in Batch,
        where: b.user_id == ^user_id,
        select: %{
          total_batches: count(b.id),
          total_labels: coalesce(sum(b.total_labels), 0),
          printed_batches: sum(fragment("CASE WHEN ? = 'printed' THEN 1 ELSE 0 END", b.status)),
          draft_batches: sum(fragment("CASE WHEN ? = 'draft' THEN 1 ELSE 0 END", b.status)),
          pending_batches: sum(fragment("CASE WHEN ? = 'pending' THEN 1 ELSE 0 END", b.status))
        }
      )
      |> Repo.one()

    # Ensure we return integers, not nil
    %{
      total_batches: result.total_batches || 0,
      total_labels: result.total_labels || 0,
      printed_batches: result.printed_batches || 0,
      draft_batches: result.draft_batches || 0,
      pending_batches: result.pending_batches || 0
    }
  end

  @doc """
  Returns global batch statistics (for admin dashboard).
  """
  def get_global_stats do
    result =
      from(b in Batch,
        select: %{
          total_batches: count(b.id),
          total_labels: coalesce(sum(b.total_labels), 0),
          printed_batches: sum(fragment("CASE WHEN ? = 'printed' THEN 1 ELSE 0 END", b.status)),
          draft_batches: sum(fragment("CASE WHEN ? = 'draft' THEN 1 ELSE 0 END", b.status)),
          unique_users: count(b.user_id, :distinct)
        }
      )
      |> Repo.one()

    %{
      total_batches: result.total_batches || 0,
      total_labels: result.total_labels || 0,
      printed_batches: result.printed_batches || 0,
      draft_batches: result.draft_batches || 0,
      unique_users: result.unique_users || 0
    }
  end
end
