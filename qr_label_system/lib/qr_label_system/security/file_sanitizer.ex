defmodule QrLabelSystem.Security.FileSanitizer do
  @moduledoc """
  File security utilities for handling uploads safely.

  Provides functions to:
  - Sanitize file names (prevent path traversal)
  - Validate file types
  - Generate safe file paths
  - Validate file content via magic bytes

  ## Security Features
  - URL decoding to catch encoded path traversal attempts (..%2F)
  - Multiple sanitization passes until filename stabilizes
  - Path expansion verification to prevent symlink attacks
  - MIME type validation via magic bytes
  - File size validation
  """

  @allowed_extensions ~w(.xlsx .xls .csv .png .jpg .jpeg .gif .svg)
  @max_filename_length 255
  @max_file_size_mb 10

  # Dangerous patterns to remove
  @dangerous_patterns [
    "..",           # Parent directory
    "./",           # Current directory explicit
    "..\\",         # Windows parent
    ".\\",          # Windows current
    "~",            # Home directory
    "$",            # Shell variable expansion
    "`",            # Command substitution
    "|",            # Pipe
    ";",            # Command separator
    "&",            # Background/AND
    ">",            # Redirect
    "<",            # Redirect
    "!",            # History expansion
    "*",            # Glob
    "?",            # Glob single char
    "[",            # Glob range
    "]",            # Glob range
    "{",            # Brace expansion
    "}",            # Brace expansion
    "\n",           # Newline
    "\r",           # Carriage return
    "\t"            # Tab
  ]

  @doc """
  Sanitizes a filename to prevent path traversal attacks.

  Security measures:
  - URL decodes the filename first (catches %2F, %2E%2E, etc.)
  - Removes dangerous patterns iteratively until stable
  - Limits filename length
  - Only allows alphanumeric, dots, hyphens, underscores, and spaces

  ## Examples

      iex> sanitize_filename("../../../etc/passwd")
      "etcpasswd"

      iex> sanitize_filename("..%2F..%2Fetc%2Fpasswd")
      "etcpasswd"

      iex> sanitize_filename("normal_file.xlsx")
      "normal_file.xlsx"
  """
  def sanitize_filename(filename) when is_binary(filename) do
    filename
    |> decode_url_encoding()
    |> do_sanitize()
    |> ensure_valid_filename()
    |> truncate_filename()
  end

  def sanitize_filename(_), do: "unnamed_file"

  # Recursively decode and sanitize until stable
  defp do_sanitize(filename) do
    sanitized =
      filename
      |> Path.basename()
      |> remove_dangerous_patterns()
      |> String.replace(~r/[\/\\]/, "")
      |> String.replace(<<0>>, "")
      |> String.replace(~r/[\x00-\x1f\x7f]/, "")
      |> String.trim(".")
      |> String.trim()

    # If sanitization changed the filename, sanitize again
    # This catches double-encoded attacks
    if sanitized != filename do
      do_sanitize(sanitized)
    else
      sanitized
    end
  end

  defp decode_url_encoding(filename) do
    # Decode multiple times to catch double/triple encoding
    decode_until_stable(filename, 0)
  end

  defp decode_until_stable(filename, depth) when depth >= 5 do
    # Prevent infinite loops - max 5 decoding passes
    filename
  end

  defp decode_until_stable(filename, depth) do
    decoded = URI.decode(filename)
    if decoded == filename do
      filename
    else
      decode_until_stable(decoded, depth + 1)
    end
  end

  defp remove_dangerous_patterns(filename) do
    Enum.reduce(@dangerous_patterns, filename, fn pattern, acc ->
      String.replace(acc, pattern, "")
    end)
  end

  defp ensure_valid_filename(""), do: "unnamed_file"
  defp ensure_valid_filename(name) do
    # Only allow safe characters
    safe_name = String.replace(name, ~r/[^a-zA-Z0-9._\-\s]/, "")
    if safe_name == "", do: "unnamed_file", else: safe_name
  end

  defp truncate_filename(filename) do
    if String.length(filename) > @max_filename_length do
      # Keep extension if present
      ext = Path.extname(filename)
      base = Path.basename(filename, ext)
      max_base_length = @max_filename_length - String.length(ext)
      String.slice(base, 0, max_base_length) <> ext
    else
      filename
    end
  end

  @doc """
  Generates a safe file path for an upload.

  Uses UUID prefix to ensure uniqueness and sanitizes the original filename.
  Validates that the final path doesn't escape the base directory.

  ## Options
    * `:base_dir` - Base directory for uploads (default: System.tmp_dir!())
    * `:prefix` - Prefix for filename (default: UUID)

  ## Returns
    * `{:ok, path}` - Safe path generated
    * `{:error, :path_traversal_detected}` - Attempted path escape
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

    # Double check: expanded path must start with base AND not contain ..
    cond do
      not String.starts_with?(expanded_full, expanded_base) ->
        {:error, :path_traversal_detected}

      String.contains?(expanded_full, "..") ->
        {:error, :path_traversal_detected}

      true ->
        {:ok, full_path}
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
  Validates file size and MIME type.

  ## Options
    * `:max_size_mb` - Maximum file size in MB (default: 10)

  ## Returns
    * `:ok` - File is valid
    * `{:error, :file_too_large}` - File exceeds size limit
    * `{:error, :mime_type_mismatch}` - Content doesn't match extension
    * `{:error, reason}` - File read error
  """
  def validate_file(file_path, expected_extension, opts \\ []) do
    max_size_mb = Keyword.get(opts, :max_size_mb, @max_file_size_mb)

    with :ok <- validate_file_size(file_path, max_size_mb),
         :ok <- validate_file_content(file_path, expected_extension) do
      :ok
    end
  end

  @doc """
  Validates file size against a maximum.
  """
  def validate_file_size(file_path, max_size_mb \\ @max_file_size_mb) do
    case File.stat(file_path) do
      {:ok, %{size: size}} when size <= max_size_mb * 1024 * 1024 ->
        :ok

      {:ok, _} ->
        {:error, :file_too_large}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates the MIME type of a file by reading its magic bytes.

  This provides an additional layer of security beyond just checking
  the file extension.
  """
  def validate_file_content(file_path, expected_type) do
    # Read only first 8 bytes for magic byte detection
    case File.open(file_path, [:read, :binary]) do
      {:ok, file} ->
        header = IO.binread(file, 8)
        File.close(file)

        actual_type = detect_mime_type(header)
        if mime_matches?(actual_type, expected_type) do
          :ok
        else
          {:error, :mime_type_mismatch}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Magic bytes detection for common file types
  # ZIP/XLSX signature: PK (0x50 0x4B)
  defp detect_mime_type(<<0x50, 0x4B, 0x03, 0x04, _rest::binary>>), do: :xlsx
  # OLE2 (old Excel .xls)
  defp detect_mime_type(<<0xD0, 0xCF, 0x11, 0xE0, _rest::binary>>), do: :xls
  # PNG signature
  defp detect_mime_type(<<0x89, 0x50, 0x4E, 0x47, _rest::binary>>), do: :png
  # JPEG signature
  defp detect_mime_type(<<0xFF, 0xD8, 0xFF, _rest::binary>>), do: :jpeg
  # GIF signature (GIF87a or GIF89a)
  defp detect_mime_type(<<0x47, 0x49, 0x46, 0x38, _rest::binary>>), do: :gif
  # XML declaration (potentially SVG)
  defp detect_mime_type(<<"<?xml", _rest::binary>>), do: :xml
  # SVG tag directly
  defp detect_mime_type(<<"<svg", _rest::binary>>), do: :svg
  # Text file (starts with printable ASCII)
  defp detect_mime_type(<<first, _rest::binary>>) when first in 0x20..0x7E, do: :text
  # Unknown
  defp detect_mime_type(_), do: :unknown

  # MIME type matching
  defp mime_matches?(:xlsx, ".xlsx"), do: true
  defp mime_matches?(:xls, ".xls"), do: true
  defp mime_matches?(:png, ".png"), do: true
  defp mime_matches?(:jpeg, ".jpg"), do: true
  defp mime_matches?(:jpeg, ".jpeg"), do: true
  defp mime_matches?(:gif, ".gif"), do: true
  defp mime_matches?(:svg, ".svg"), do: true
  defp mime_matches?(:xml, ".svg"), do: true  # SVG can start with XML declaration
  # CSV is plain text
  defp mime_matches?(:text, ".csv"), do: true
  defp mime_matches?(:unknown, ".csv"), do: true
  # Reject mismatches
  defp mime_matches?(_, _), do: false
end
