defmodule QrLabelSystemWeb.DataSourceController do
  use QrLabelSystemWeb, :controller

  alias QrLabelSystem.DataSources

  @doc """
  Handles file upload and redirects to the details form.
  """
  def upload(conn, %{"file" => upload}) do
    # Detect type from file extension
    ext = Path.extname(upload.filename) |> String.downcase()
    detected_type = detect_type(ext)

    # Save the uploaded file
    uploads_dir = Path.join([:code.priv_dir(:qr_label_system), "uploads", "data_sources"])
    File.mkdir_p!(uploads_dir)

    dest_filename = "#{Ecto.UUID.generate()}#{ext}"
    dest_path = Path.join(uploads_dir, dest_filename)

    File.cp!(upload.path, dest_path)

    # Suggest name based on filename (without extension)
    suggested_name = Path.basename(upload.filename, ext)

    conn
    |> put_session(:uploaded_file_path, dest_path)
    |> put_session(:uploaded_file_name, upload.filename)
    |> put_session(:detected_type, detected_type)
    |> put_session(:suggested_name, suggested_name)
    |> redirect(to: ~p"/data-sources/new/details")
  end

  def upload(conn, _params) do
    conn
    |> put_flash(:error, "Por favor selecciona un archivo")
    |> redirect(to: ~p"/data-sources/new")
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
    data_source_params = Map.put(data_source_params, "user_id", conn.assigns.current_user.id)

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
end
