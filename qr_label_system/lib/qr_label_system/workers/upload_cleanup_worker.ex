defmodule QrLabelSystem.Workers.UploadCleanupWorker do
  @moduledoc """
  Oban worker that cleans up orphaned upload files.

  Files in priv/uploads/data_sources older than the configured TTL
  are deleted to prevent disk space accumulation from abandoned uploads.

  Runs on the :cleanup queue.
  """
  use Oban.Worker, queue: :cleanup, max_attempts: 3

  require Logger

  # Files older than 24 hours are considered orphaned
  @default_ttl_hours 24

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    ttl_hours = Map.get(args, "ttl_hours", @default_ttl_hours)
    uploads_dir = uploads_directory()

    Logger.info("UploadCleanupWorker: Starting cleanup (TTL: #{ttl_hours}h)")

    {:ok, deleted_count} = cleanup_old_files(uploads_dir, ttl_hours)
    Logger.info("UploadCleanupWorker: Deleted #{deleted_count} orphaned files")
    :ok
  end

  @doc """
  Returns the uploads directory path.
  """
  def uploads_directory do
    Path.join([:code.priv_dir(:qr_label_system), "uploads", "data_sources"])
  end

  @doc """
  Cleans up files older than the specified TTL.
  Returns {:ok, deleted_count} or {:error, reason}.
  """
  def cleanup_old_files(directory, ttl_hours \\ @default_ttl_hours) do
    cutoff_time = DateTime.utc_now() |> DateTime.add(-ttl_hours * 3600, :second)

    if File.dir?(directory) do
      files = File.ls!(directory)

      deleted_count =
        files
        |> Enum.filter(&should_delete?(&1, directory, cutoff_time))
        |> Enum.reduce(0, fn file, count ->
          path = Path.join(directory, file)
          case File.rm(path) do
            :ok ->
              Logger.debug("UploadCleanupWorker: Deleted #{file}")
              count + 1
            {:error, reason} ->
              Logger.warning("UploadCleanupWorker: Failed to delete #{file}: #{inspect(reason)}")
              count
          end
        end)

      {:ok, deleted_count}
    else
      {:ok, 0}
    end
  end

  defp should_delete?(filename, directory, cutoff_time) do
    path = Path.join(directory, filename)

    case File.stat(path, time: :posix) do
      {:ok, %{mtime: mtime}} ->
        file_time = DateTime.from_unix!(mtime)
        DateTime.compare(file_time, cutoff_time) == :lt

      {:error, _} ->
        false
    end
  end

  @doc """
  Schedules an immediate cleanup job.
  Useful for manual triggering.
  """
  def schedule_now(opts \\ []) do
    ttl_hours = Keyword.get(opts, :ttl_hours, @default_ttl_hours)

    %{ttl_hours: ttl_hours}
    |> new()
    |> Oban.insert()
  end
end
