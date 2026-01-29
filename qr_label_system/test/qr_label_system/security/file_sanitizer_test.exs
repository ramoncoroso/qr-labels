defmodule QrLabelSystem.Security.FileSanitizerTest do
  use ExUnit.Case, async: true

  alias QrLabelSystem.Security.FileSanitizer

  describe "sanitize_filename/1" do
    test "removes path traversal sequences" do
      assert FileSanitizer.sanitize_filename("../../../etc/passwd") == "etcpasswd"
      assert FileSanitizer.sanitize_filename("..\\..\\windows\\system32") == "windowssystem32"
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
      assert FileSanitizer.sanitize_filename("path\\to\\file.txt") == "file.txt"
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
      assert FileSanitizer.valid_extension?("file.csv")
      assert FileSanitizer.valid_extension?("file.png")
      assert FileSanitizer.valid_extension?("file.jpg")
      assert FileSanitizer.valid_extension?("file.jpeg")
      assert FileSanitizer.valid_extension?("file.gif")
      assert FileSanitizer.valid_extension?("file.svg")
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
end
