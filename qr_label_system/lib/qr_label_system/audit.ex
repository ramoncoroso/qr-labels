defmodule QrLabelSystem.Audit do
  @moduledoc """
  The Audit context.
  Handles logging of all important actions in the system.
  """

  import Ecto.Query, warn: false
  alias QrLabelSystem.Repo
  alias QrLabelSystem.Audit.Log

  @doc """
  Creates an audit log entry.
  """
  def log(action, resource_type, resource_id \\ nil, opts \\ []) do
    attrs = %{
      action: to_string(action),
      resource_type: to_string(resource_type),
      resource_id: resource_id,
      user_id: Keyword.get(opts, :user_id),
      metadata: Keyword.get(opts, :metadata, %{}),
      ip_address: Keyword.get(opts, :ip_address),
      user_agent: Keyword.get(opts, :user_agent)
    }

    %Log{}
    |> Log.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates an audit log entry asynchronously (non-blocking).
  """
  def log_async(action, resource_type, resource_id \\ nil, opts \\ []) do
    Task.start(fn ->
      log(action, resource_type, resource_id, opts)
    end)
    :ok
  end

  @doc """
  Returns audit logs with pagination and filters.
  """
  def list_logs(params \\ %{}) do
    page = Map.get(params, "page", "1") |> parse_int(1)
    per_page = Map.get(params, "per_page", "50") |> parse_int(50)
    user_id = Map.get(params, "user_id")
    action = Map.get(params, "action")
    resource_type = Map.get(params, "resource_type")
    from_date = Map.get(params, "from_date")
    to_date = Map.get(params, "to_date")

    offset = (page - 1) * per_page

    base_query = from(l in Log,
      preload: [:user],
      order_by: [desc: l.inserted_at]
    )

    query =
      base_query
      |> maybe_filter_by_user(user_id)
      |> maybe_filter_by_action(action)
      |> maybe_filter_by_resource_type(resource_type)
      |> maybe_filter_by_date_range(from_date, to_date)

    logs = query |> limit(^per_page) |> offset(^offset) |> Repo.all()
    total = query |> exclude(:preload) |> Repo.aggregate(:count)

    %{
      logs: logs,
      page: page,
      per_page: per_page,
      total: total,
      total_pages: ceil(total / per_page)
    }
  end

  @doc """
  Returns recent logs for a specific resource.
  """
  def logs_for_resource(resource_type, resource_id, limit \\ 20) do
    Repo.all(
      from l in Log,
        where: l.resource_type == ^to_string(resource_type) and l.resource_id == ^resource_id,
        preload: [:user],
        order_by: [desc: l.inserted_at],
        limit: ^limit
    )
  end

  @doc """
  Returns recent logs for a specific user.
  """
  def logs_for_user(user_id, limit \\ 50) do
    Repo.all(
      from l in Log,
        where: l.user_id == ^user_id,
        order_by: [desc: l.inserted_at],
        limit: ^limit
    )
  end

  @doc """
  Deletes old logs (for data retention compliance).
  """
  def cleanup_old_logs(days \\ 90) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    from(l in Log, where: l.inserted_at < ^cutoff)
    |> Repo.delete_all()
  end

  # Private functions

  defp maybe_filter_by_user(query, nil), do: query
  defp maybe_filter_by_user(query, user_id) do
    from l in query, where: l.user_id == ^user_id
  end

  defp maybe_filter_by_action(query, nil), do: query
  defp maybe_filter_by_action(query, ""), do: query
  defp maybe_filter_by_action(query, action) do
    from l in query, where: l.action == ^action
  end

  defp maybe_filter_by_resource_type(query, nil), do: query
  defp maybe_filter_by_resource_type(query, ""), do: query
  defp maybe_filter_by_resource_type(query, resource_type) do
    from l in query, where: l.resource_type == ^resource_type
  end

  defp maybe_filter_by_date_range(query, nil, nil), do: query
  defp maybe_filter_by_date_range(query, from_date, nil) when is_binary(from_date) do
    case Date.from_iso8601(from_date) do
      {:ok, date} ->
        datetime = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
        from l in query, where: l.inserted_at >= ^datetime
      _ -> query
    end
  end
  defp maybe_filter_by_date_range(query, nil, to_date) when is_binary(to_date) do
    case Date.from_iso8601(to_date) do
      {:ok, date} ->
        datetime = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
        from l in query, where: l.inserted_at <= ^datetime
      _ -> query
    end
  end
  defp maybe_filter_by_date_range(query, from_date, to_date) do
    query
    |> maybe_filter_by_date_range(from_date, nil)
    |> maybe_filter_by_date_range(nil, to_date)
  end

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end
  defp parse_int(value, _default) when is_integer(value), do: value
  defp parse_int(_, default), do: default
end
