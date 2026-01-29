defmodule QrLabelSystem.Security.FileSanitizer do
  @moduledoc """
  File security utilities for handling uploads safely.

  Provides functions to:
  - Sanitize file names (prevent path traversal)
  - Validate file types
  - Generate safe file paths
  """

  @allowed_extensions ~w(.xlsx .xls .csv .png .jpg .jpeg .gif .svg)

  @doc """
  Sanitizes a filename to prevent path traversal attacks.

  Removes:
  - Path separators (/, \\)
  - Parent directory references (..)
  - Null bytes
  - Control characters
  - Leading/trailing dots and spaces
  """
  def sanitize_filename(filename) when is_binary(filename) do
    filename
    |> Path.basename()  # Remove any path components
    |> String.replace(~r/[\/\\]/, "")  # Remove path separators
    |> String.replace("..", "")  # Remove parent directory references
    |> String.replace(<<0>>, "")  # Remove null bytes
    |> String.replace(~r/[\x00-\x1f\x7f]/, "")  # Remove control characters
    |> String.trim(".")  # Remove leading/trailing dots
    |> String.trim()  # Remove leading/trailing spaces
    |> ensure_valid_filename()
  end

  def sanitize_filename(_), do: "unnamed_file"

  @doc """
  Generates a safe file path for an upload.

  Uses UUID prefix to ensure uniqueness and sanitizes the original filename.
  """
  def safe_upload_path(original_filename, opts \\ []) do
    base_dir = Keyword.get(opts, :base_dir, System.tmp_dir!())
    prefix = Keyword.get(opts, :prefix, Ecto.UUID.generate())

    sanitized_name = sanitize_filename(original_filename)
    safe_name = "#{prefix}_#{sanitized_name}"

    # Ensure we're not escaping the base directory
    full_path = Path.join(base_dir, safe_name)
    expanded_base = Path.expand(base_dir)
    expanded_full = Path.expand(full_path)

    if String.starts_with?(expanded_full, expanded_base) do
      {:ok, full_path}
    else
      {:error, :path_traversal_detected}
    end
  end

  @doc """
  Validates that a file extension is allowed.
  """
  def valid_extension?(filename) when is_binary(filename) do
    ext = filename |> Path.extname() |> String.downcase()
    ext in @allowed_extensions
  end

  def valid_extension?(_), do: false

  @doc """
  Validates file extension against a specific list.
  """
  def valid_extension?(filename, allowed_extensions) when is_list(allowed_extensions) do
    ext = filename |> Path.extname() |> String.downcase()
    ext in allowed_extensions
  end

  @doc """
  Returns the allowed file extensions.
  """
  def allowed_extensions, do: @allowed_extensions

  @doc """
  Validates the MIME type of a file by reading its magic bytes.

  This provides an additional layer of security beyond just checking
  the file extension.
  """
  def validate_file_content(file_path, expected_type) do
    case File.read(file_path) do
      {:ok, content} ->
        actual_type = detect_mime_type(content)
        if mime_matches?(actual_type, expected_type) do
          :ok
        else
          {:error, :mime_type_mismatch}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp ensure_valid_filename(""), do: "unnamed_file"
  defp ensure_valid_filename(name), do: name

  # Magic bytes detection for common file types
  defp detect_mime_type(<<0x50, 0x4B, 0x03, 0x04, _rest::binary>>), do: :xlsx  # ZIP/XLSX
  defp detect_mime_type(<<0xD0, 0xCF, 0x11, 0xE0, _rest::binary>>), do: :xls   # OLE2 (old Excel)
  defp detect_mime_type(<<0x89, 0x50, 0x4E, 0x47, _rest::binary>>), do: :png
  defp detect_mime_type(<<0xFF, 0xD8, 0xFF, _rest::binary>>), do: :jpeg
  defp detect_mime_type(<<0x47, 0x49, 0x46, _rest::binary>>), do: :gif
  defp detect_mime_type(<<"<?xml", _rest::binary>>), do: :svg
  defp detect_mime_type(<<"<svg", _rest::binary>>), do: :svg
  defp detect_mime_type(_), do: :unknown

  defp mime_matches?(:xlsx, ".xlsx"), do: true
  defp mime_matches?(:xls, ".xls"), do: true
  defp mime_matches?(:png, ".png"), do: true
  defp mime_matches?(:jpeg, ".jpg"), do: true
  defp mime_matches?(:jpeg, ".jpeg"), do: true
  defp mime_matches?(:gif, ".gif"), do: true
  defp mime_matches?(:svg, ".svg"), do: true
  # CSV is text, no magic bytes to check
  defp mime_matches?(:unknown, ".csv"), do: true
  defp mime_matches?(_, _), do: false
end
