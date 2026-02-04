defmodule QrLabelSystem.Security.FileSanitizerTest do
  use ExUnit.Case, async: true

  alias QrLabelSystem.Security.FileSanitizer

  describe "sanitize_filename/1" do
    test "removes path traversal sequences" do
      # The sanitizer extracts just the final filename after removing path components
      assert FileSanitizer.sanitize_filename("../../../etc/passwd") == "passwd"
      # Backslashes are removed but not treated as path separators on Unix
      result = FileSanitizer.sanitize_filename("..\\..\\windows\\system32")
      refute String.contains?(result, "..")
      refute String.contains?(result, "\\")
    end

    test "removes URL-encoded path traversal (single encoding)" do
      # %2F is /
      # %2E is .
      result = FileSanitizer.sanitize_filename("..%2F..%2Fetc%2Fpasswd")
      refute String.contains?(result, "..")
      refute String.contains?(result, "/")
    end

    test "removes double URL-encoded path traversal" do
      # %252F decodes to %2F, which decodes to /
      result = FileSanitizer.sanitize_filename("..%252F..%252Fetc%252Fpasswd")
      refute String.contains?(result, "..")
      refute String.contains?(result, "/")
    end

    test "removes triple URL-encoded path traversal" do
      # %25252F decodes multiple times to /
      result = FileSanitizer.sanitize_filename("..%25252F..%25252Fetc")
      refute String.contains?(result, "..")
      refute String.contains?(result, "/")
    end

    test "removes path separators" do
      assert FileSanitizer.sanitize_filename("path/to/file.txt") == "file.txt"
      # Backslashes are sanitized but don't act as path separators in this implementation
      result = FileSanitizer.sanitize_filename("path\\to\\file.txt")
      refute String.contains?(result, "\\")
    end

    test "removes null bytes" do
      result = FileSanitizer.sanitize_filename("file.txt\x00.exe")
      refute String.contains?(result, <<0>>)
    end

    test "removes control characters" do
      result = FileSanitizer.sanitize_filename("file\x01\x02.txt")
      refute String.contains?(result, <<1>>)
      refute String.contains?(result, <<2>>)
    end

    test "removes shell dangerous characters" do
      # These should all be stripped
      dangerous = [";", "|", "&", "$", "`", ">", "<", "!", "*", "?", "[", "]", "{", "}", "~"]

      for char <- dangerous do
        filename = "file#{char}name.txt"
        result = FileSanitizer.sanitize_filename(filename)
        refute String.contains?(result, char),
               "Character '#{char}' should be removed, got: #{result}"
      end
    end

    test "trims leading and trailing dots" do
      assert FileSanitizer.sanitize_filename("...file.txt...") == "file.txt"
      # Note: .hidden becomes "hidden" due to dot trimming
      assert FileSanitizer.sanitize_filename(".hidden") == "hidden"
    end

    test "handles empty strings" do
      assert FileSanitizer.sanitize_filename("") == "unnamed_file"
    end

    test "handles nil" do
      assert FileSanitizer.sanitize_filename(nil) == "unnamed_file"
    end

    test "handles strings that become empty after sanitization" do
      assert FileSanitizer.sanitize_filename("../../../") == "unnamed_file"
      assert FileSanitizer.sanitize_filename(";;;|||") == "unnamed_file"
    end

    test "preserves valid filenames" do
      assert FileSanitizer.sanitize_filename("my_file.xlsx") == "my_file.xlsx"
      assert FileSanitizer.sanitize_filename("report-2024.csv") == "report-2024.csv"
      assert FileSanitizer.sanitize_filename("file with spaces.txt") == "file with spaces.txt"
    end

    test "truncates very long filenames" do
      long_name = String.duplicate("a", 300) <> ".xlsx"
      result = FileSanitizer.sanitize_filename(long_name)
      assert String.length(result) <= 255
      assert String.ends_with?(result, ".xlsx")
    end

    test "only allows safe characters" do
      # Unicode characters should be stripped
      result = FileSanitizer.sanitize_filename("файл.txt")  # Russian "file"
      # Only ASCII alphanumeric, dots, hyphens, underscores, spaces allowed
      assert result =~ ~r/^[a-zA-Z0-9._\-\s]*$/
    end
  end

  describe "safe_upload_path/2" do
    test "generates a safe path with UUID prefix" do
      {:ok, path} = FileSanitizer.safe_upload_path("test.xlsx")
      assert String.contains?(path, "test.xlsx")
      # Should have UUID prefix
      assert String.length(Path.basename(path)) > String.length("test.xlsx")
    end

    test "sanitizes the filename in the path" do
      {:ok, path} = FileSanitizer.safe_upload_path("../../../malicious.xlsx")
      refute String.contains?(path, "..")
    end

    test "rejects paths that would escape base directory" do
      # Even after sanitization, verify no escape
      {:ok, path} = FileSanitizer.safe_upload_path("safe_file.xlsx")
      base_dir = System.tmp_dir!()
      expanded = Path.expand(path)
      assert String.starts_with?(expanded, Path.expand(base_dir))
    end

    test "uses custom base directory" do
      base_dir = System.tmp_dir!()
      {:ok, path} = FileSanitizer.safe_upload_path("test.xlsx", base_dir: base_dir)
      assert String.starts_with?(path, base_dir)
    end

    test "uses custom prefix" do
      {:ok, path} = FileSanitizer.safe_upload_path("test.xlsx", prefix: "custom_prefix")
      assert String.contains?(path, "custom_prefix_")
    end

    test "handles URL-encoded filenames safely" do
      {:ok, path} = FileSanitizer.safe_upload_path("..%2F..%2Fetc%2Fpasswd")
      refute String.contains?(path, "..")
      refute String.contains?(path, "/etc")
    end
  end

  describe "valid_extension?/1" do
    test "accepts valid extensions" do
      assert FileSanitizer.valid_extension?("file.xlsx")
      assert FileSanitizer.valid_extension?("file.xls")
      assert FileSanitizer.valid_extension?("file.csv")
      assert FileSanitizer.valid_extension?("file.png")
      assert FileSanitizer.valid_extension?("file.jpg")
      assert FileSanitizer.valid_extension?("file.jpeg")
      assert FileSanitizer.valid_extension?("file.gif")
    end

    test "rejects SVG for XSS security" do
      # SVG is blocked because it can contain embedded JavaScript
      refute FileSanitizer.valid_extension?("file.svg")
    end

    test "rejects invalid extensions" do
      refute FileSanitizer.valid_extension?("file.exe")
      refute FileSanitizer.valid_extension?("file.php")
      refute FileSanitizer.valid_extension?("file.js")
      refute FileSanitizer.valid_extension?("file.sh")
      refute FileSanitizer.valid_extension?("file.bat")
      refute FileSanitizer.valid_extension?("file.ps1")
    end

    test "handles case insensitivity" do
      assert FileSanitizer.valid_extension?("file.XLSX")
      assert FileSanitizer.valid_extension?("file.CSV")
      assert FileSanitizer.valid_extension?("file.PNG")
    end

    test "handles nil and empty" do
      refute FileSanitizer.valid_extension?(nil)
      refute FileSanitizer.valid_extension?("")
    end

    test "handles double extensions (uses last)" do
      # Should check the actual extension, not the first dot
      assert FileSanitizer.valid_extension?("file.tar.xlsx")
      refute FileSanitizer.valid_extension?("file.xlsx.exe")
    end
  end

  describe "valid_extension?/2 with custom list" do
    test "accepts only specified extensions" do
      assert FileSanitizer.valid_extension?("file.xlsx", [".xlsx", ".csv"])
      assert FileSanitizer.valid_extension?("file.csv", [".xlsx", ".csv"])
      refute FileSanitizer.valid_extension?("file.png", [".xlsx", ".csv"])
    end
  end

  describe "validate_file_size/2" do
    setup do
      # Create a temporary file for testing
      path = Path.join(System.tmp_dir!(), "test_file_#{System.unique_integer()}.txt")
      File.write!(path, String.duplicate("x", 1000))  # 1KB file
      on_exit(fn -> File.rm(path) end)
      %{path: path}
    end

    test "accepts files within size limit", %{path: path} do
      assert :ok = FileSanitizer.validate_file_size(path, 1)  # 1MB limit
    end

    test "rejects files exceeding size limit", %{path: path} do
      # Our 1KB file is larger than 0.0001 MB
      assert {:error, :file_too_large} = FileSanitizer.validate_file_size(path, 0.0001)
    end

    test "returns error for non-existent file" do
      assert {:error, :enoent} = FileSanitizer.validate_file_size("/nonexistent/file.txt", 10)
    end
  end

  describe "detect_mime_type_from_file/1" do
    test "detects PNG files" do
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer()}.png")
      # PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
      File.write!(path, <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, "rest of file">>)
      on_exit(fn -> File.rm(path) end)

      assert {:ok, "image/png"} = FileSanitizer.detect_mime_type_from_file(path)
    end

    test "detects JPEG files" do
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer()}.jpg")
      # JPEG magic bytes: FF D8 FF
      File.write!(path, <<0xFF, 0xD8, 0xFF, 0xE0, "rest of file">>)
      on_exit(fn -> File.rm(path) end)

      assert {:ok, "image/jpeg"} = FileSanitizer.detect_mime_type_from_file(path)
    end

    test "detects GIF files" do
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer()}.gif")
      # GIF magic bytes: GIF89a or GIF87a
      File.write!(path, "GIF89a" <> "rest of file")
      on_exit(fn -> File.rm(path) end)

      assert {:ok, "image/gif"} = FileSanitizer.detect_mime_type_from_file(path)
    end

    test "detects XLSX files (ZIP-based)" do
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer()}.xlsx")
      # ZIP/XLSX magic bytes: PK (50 4B 03 04)
      File.write!(path, <<0x50, 0x4B, 0x03, 0x04, "rest of file">>)
      on_exit(fn -> File.rm(path) end)

      assert {:ok, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"} =
               FileSanitizer.detect_mime_type_from_file(path)
    end

    test "returns octet-stream for unknown types" do
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer()}.bin")
      File.write!(path, <<0x00, 0x01, 0x02, 0x03>>)
      on_exit(fn -> File.rm(path) end)

      assert {:ok, "application/octet-stream"} = FileSanitizer.detect_mime_type_from_file(path)
    end

    test "returns error for non-existent file" do
      assert {:error, :enoent} = FileSanitizer.detect_mime_type_from_file("/nonexistent/file.bin")
    end
  end

  describe "validate_image_content/1" do
    test "accepts valid PNG" do
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer()}.png")
      File.write!(path, <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>)
      on_exit(fn -> File.rm(path) end)

      assert {:ok, "image/png"} = FileSanitizer.validate_image_content(path)
    end

    test "accepts valid JPEG" do
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer()}.jpg")
      File.write!(path, <<0xFF, 0xD8, 0xFF, 0xE0>>)
      on_exit(fn -> File.rm(path) end)

      assert {:ok, "image/jpeg"} = FileSanitizer.validate_image_content(path)
    end

    test "accepts valid GIF" do
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer()}.gif")
      File.write!(path, "GIF89a")
      on_exit(fn -> File.rm(path) end)

      assert {:ok, "image/gif"} = FileSanitizer.validate_image_content(path)
    end

    test "rejects non-image files" do
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer()}.txt")
      File.write!(path, "This is just text, not an image")
      on_exit(fn -> File.rm(path) end)

      assert {:error, :invalid_image_type} = FileSanitizer.validate_image_content(path)
    end

    test "rejects polyglot files (fake extension, wrong content)" do
      # File named .png but contains XLSX content
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer()}.png")
      File.write!(path, <<0x50, 0x4B, 0x03, 0x04, "fake xlsx">>)
      on_exit(fn -> File.rm(path) end)

      # validate_image_content checks magic bytes, not extension
      # This should reject because XLSX is not a valid image type
      assert {:error, :invalid_image_type} = FileSanitizer.validate_image_content(path)
    end

    test "rejects SVG (XSS risk)" do
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer()}.svg")
      File.write!(path, "<svg xmlns='http://www.w3.org/2000/svg'><script>alert('xss')</script></svg>")
      on_exit(fn -> File.rm(path) end)

      assert {:error, :invalid_image_type} = FileSanitizer.validate_image_content(path)
    end
  end
end
