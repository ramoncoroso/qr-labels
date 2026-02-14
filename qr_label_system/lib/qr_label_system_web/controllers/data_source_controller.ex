defmodule QrLabelSystemWeb.DataSourceController do
  use QrLabelSystemWeb, :controller

  alias QrLabelSystem.DataSources
  alias QrLabelSystem.Security.FileSanitizer

  require Logger

  # Allowed extensions for data source files
  @allowed_extensions ~w(.xlsx .xls .csv)
  # Max file size: 10MB
  @max_file_size_mb 10

  @doc """
  Handles file upload and redirects to the details form.
  Validates file extension, size, and content before saving.
  """
  def upload(conn, %{"file" => upload}) do
    # Sanitize filename and get extension
    sanitized_name = FileSanitizer.sanitize_filename(upload.filename)
    ext = Path.extname(sanitized_name) |> String.downcase()

    with :ok <- validate_extension(ext),
         :ok <- validate_file_size(upload.path),
         :ok <- validate_file_content(upload.path, ext) do
      # File is valid, save it
      detected_type = detect_type(ext)

      uploads_dir = Path.join([:code.priv_dir(:qr_label_system), "uploads", "data_sources"])
      File.mkdir_p!(uploads_dir)

      dest_filename = "#{Ecto.UUID.generate()}#{ext}"
      dest_path = Path.join(uploads_dir, dest_filename)

      File.cp!(upload.path, dest_path)

      # Suggest name based on original filename (without extension)
      suggested_name = Path.basename(sanitized_name, ext)

      conn
      |> put_session(:uploaded_file_path, dest_path)
      |> put_session(:uploaded_file_name, sanitized_name)
      |> put_session(:detected_type, detected_type)
      |> put_session(:suggested_name, suggested_name)
      |> redirect(to: ~p"/data-sources/new/details")
    else
      {:error, :invalid_extension} ->
        Logger.warning("Upload rejected: invalid extension #{ext}")
        conn
        |> put_flash(:error, "Tipo de archivo no permitido. Solo se aceptan: #{Enum.join(@allowed_extensions, ", ")}")
        |> redirect(to: ~p"/data-sources/new")

      {:error, :file_too_large} ->
        Logger.warning("Upload rejected: file too large")
        conn
        |> put_flash(:error, "El archivo es demasiado grande. Máximo: #{@max_file_size_mb}MB")
        |> redirect(to: ~p"/data-sources/new")

      {:error, :mime_type_mismatch} ->
        Logger.warning("Upload rejected: MIME type mismatch for extension #{ext}")
        conn
        |> put_flash(:error, "El contenido del archivo no coincide con su extensión")
        |> redirect(to: ~p"/data-sources/new")

      {:error, reason} ->
        Logger.warning("Upload rejected: #{inspect(reason)}")
        conn
        |> put_flash(:error, "Error al procesar el archivo")
        |> redirect(to: ~p"/data-sources/new")
    end
  end

  def upload(conn, _params) do
    conn
    |> put_flash(:error, "Por favor selecciona un archivo")
    |> redirect(to: ~p"/data-sources/new")
  end

  defp validate_extension(ext) when ext in @allowed_extensions, do: :ok
  defp validate_extension(_ext), do: {:error, :invalid_extension}

  defp validate_file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size <= @max_file_size_mb * 1024 * 1024 -> :ok
      {:ok, _} -> {:error, :file_too_large}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_file_content(path, ext) do
    FileSanitizer.validate_file_content(path, ext)
  end

  defp detect_type(".xlsx"), do: "excel"
  defp detect_type(".xls"), do: "excel"
  defp detect_type(".csv"), do: "csv"
  defp detect_type(_), do: "excel"

  @doc """
  Fallback POST handler for when LiveView websocket doesn't connect.
  Creates a new data source and redirects to the index.
  """
  def create(conn, %{"data_source" => data_source_params}) do
    data_source_params =
      data_source_params
      |> Map.put("user_id", conn.assigns.current_user.id)
      |> Map.put("workspace_id", conn.assigns.current_workspace.id)

    # Build connection_config for database types
    data_source_params =
      if data_source_params["type"] in ["postgresql", "mysql", "sqlserver"] do
        connection_config = %{
          "host" => data_source_params["host"],
          "port" => data_source_params["port"],
          "database" => data_source_params["database"],
          "username" => data_source_params["username"],
          "password" => data_source_params["password"]
        }

        data_source_params
        |> Map.put("connection_config", connection_config)
        |> Map.drop(["host", "port", "database", "username", "password"])
      else
        data_source_params
      end

    case DataSources.create_data_source(data_source_params) do
      {:ok, _data_source} ->
        # Don't delete the file — it's needed for get_data_from_source later.
        # File cleanup happens when the data source is deleted.
        conn
        |> delete_session(:uploaded_file_path)
        |> delete_session(:uploaded_file_name)
        |> delete_session(:detected_type)
        |> delete_session(:suggested_name)
        |> put_flash(:info, "Datos agregados exitosamente")
        |> redirect(to: ~p"/data-sources")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Error al agregar los datos. Verifica la información.")
        |> redirect(to: ~p"/data-sources/new/details")
    end
  end

  @doc """
  Cancels an in-progress upload, cleaning up the temporary file.
  """
  def cancel_upload(conn, _params) do
    cleanup_uploaded_file(conn)

    conn
    |> delete_session(:uploaded_file_path)
    |> delete_session(:uploaded_file_name)
    |> delete_session(:detected_type)
    |> delete_session(:suggested_name)
    |> redirect(to: ~p"/data-sources")
  end

  @doc """
  Deletes a data source.
  """
  def delete(conn, %{"id" => id}) do
    data_source = DataSources.get_data_source!(id)

    if data_source.user_id == conn.assigns.current_user.id do
      {:ok, _} = DataSources.delete_data_source(data_source)

      conn
      |> put_flash(:info, "Datos eliminados exitosamente")
      |> redirect(to: ~p"/data-sources")
    else
      conn
      |> put_flash(:error, "No tienes permiso para eliminar estos datos")
      |> redirect(to: ~p"/data-sources")
    end
  end

  defp cleanup_uploaded_file(conn) do
    case get_session(conn, :uploaded_file_path) do
      nil -> :ok
      path when is_binary(path) ->
        if File.exists?(path), do: File.rm(path)
      _ -> :ok
    end
  end
end
