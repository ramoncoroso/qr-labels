defmodule QrLabelSystem.DataSources do
  @moduledoc """
  The DataSources context.
  Handles data source management and data retrieval from Excel/CSV files
  and external databases.
  """

  import Ecto.Query, warn: false
  alias QrLabelSystem.Repo
  alias QrLabelSystem.DataSources.{DataSource, ExcelParser, DbConnector}

  @doc """
  Returns the list of data sources.
  """
  def list_data_sources do
    Repo.all(from d in DataSource, order_by: [desc: d.updated_at])
  end

  @doc """
  Returns the list of data sources for a specific user.
  """
  def list_user_data_sources(user_id) do
    Repo.all(
      from d in DataSource,
        where: d.user_id == ^user_id,
        order_by: [desc: d.updated_at]
    )
  end

  @doc """
  Returns data sources for a workspace.
  """
  def list_workspace_data_sources(workspace_id) do
    Repo.all(
      from d in DataSource,
        where: d.workspace_id == ^workspace_id,
        order_by: [desc: d.updated_at]
    )
  end

  @doc """
  Gets a single data source.
  """
  def get_data_source!(id), do: Repo.get!(DataSource, id)

  @doc """
  Gets a single data source, returns nil if not found.
  """
  def get_data_source(id), do: Repo.get(DataSource, id)

  @doc """
  Creates a data source.
  """
  def create_data_source(attrs \\ %{}) do
    %DataSource{}
    |> DataSource.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a data source.
  """
  def update_data_source(%DataSource{} = data_source, attrs) do
    data_source
    |> DataSource.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a data source.
  """
  def delete_data_source(%DataSource{} = data_source) do
    result = Repo.delete(data_source)

    case result do
      {:ok, deleted} ->
        # Clean up associated file if it exists
        if deleted.file_path && File.exists?(deleted.file_path) do
          File.rm(deleted.file_path)
        end

        {:ok, deleted}

      error ->
        error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking data source changes.
  """
  def change_data_source(%DataSource{} = data_source, attrs \\ %{}) do
    DataSource.changeset(data_source, attrs)
  end

  # ==========================================
  # DATA RETRIEVAL
  # ==========================================

  @doc """
  Convenience function to get data from a data source using its stored file_path.
  For database sources, file_path is not needed.

  Returns {:ok, %{columns: [...], rows: [...], total: n}} or {:error, reason}
  """
  def get_data_from_source(%DataSource{} = source, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    result = get_data(source, source.file_path, max_rows: limit)

    case result do
      {:ok, %{headers: headers} = data} ->
        {:ok, %{columns: headers, rows: data.rows, total: data.total}}

      {:ok, data} ->
        {:ok, data}

      error ->
        error
    end
  end

  @doc """
  Retrieves data from a data source.
  For Excel sources, parses the uploaded file.
  For database sources, executes the configured query.

  Returns {:ok, %{headers: [...], rows: [...], total: n}} or {:error, reason}
  """
  def get_data(source, file_path, opts \\ [])

  def get_data(%DataSource{type: type} = _source, file_path, opts)
      when type in ~w(excel csv) do
    ExcelParser.parse_file(file_path, opts)
  end

  def get_data(%DataSource{type: type} = source, _file_path, opts)
      when type in ~w(postgresql mysql sqlserver) do
    case DbConnector.validate_query(source.query || "") do
      :ok ->
        DbConnector.execute_query(type, source.connection_config, source.query, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_data(%DataSource{type: type}, _, _) do
    {:error, "Unknown data source type: #{type}"}
  end

  @doc """
  Gets a preview of data from a data source (first few rows).
  """
  def preview_data(source, file_path, opts \\ [])

  def preview_data(%DataSource{type: type} = _source, file_path, opts)
      when type in ~w(excel csv) do
    preview_rows = Keyword.get(opts, :preview_rows, 5)
    ExcelParser.preview_file(file_path, preview_rows: preview_rows)
  end

  def preview_data(%DataSource{type: type} = source, _file_path, opts)
      when type in ~w(postgresql mysql sqlserver) do
    preview_rows = Keyword.get(opts, :preview_rows, 5)

    case DbConnector.validate_query(source.query || "") do
      :ok ->
        DbConnector.execute_query(type, source.connection_config, source.query, max_rows: preview_rows)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ==========================================
  # CONNECTION TESTING
  # ==========================================

  @doc """
  Tests a database connection and updates the data source with results.
  """
  def test_connection(%DataSource{type: type} = data_source)
      when type in ~w(postgresql mysql sqlserver) do
    result = DbConnector.test_connection(type, data_source.connection_config)

    attrs = case result do
      {:ok, :connected} ->
        %{
          last_tested_at: DateTime.utc_now(),
          test_status: "success",
          test_error: nil
        }

      {:error, reason} ->
        %{
          last_tested_at: DateTime.utc_now(),
          test_status: "failed",
          test_error: reason
        }
    end

    data_source
    |> DataSource.test_result_changeset(attrs)
    |> Repo.update()

    result
  end

  def test_connection(%DataSource{type: type}) when type in ~w(excel csv) do
    {:ok, :not_applicable}
  end

  def test_connection(%DataSource{type: type}) do
    {:error, "Cannot test connection for type: #{type}"}
  end

  @doc """
  Validates a SQL query.
  """
  def validate_query(query) do
    DbConnector.validate_query(query)
  end
end
