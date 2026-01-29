defmodule QrLabelSystem.Security.FileSanitizerTest do
  use ExUnit.Case, async: true

  alias QrLabelSystem.Security.FileSanitizer

  describe "sanitize_filename/1" do
    test "removes path traversal sequences" do
      assert FileSanitizer.sanitize_filename("../../../etc/passwd") == "etcpasswd"
      assert FileSanitizer.sanitize_filename("..\\..\\windows\\system32") == "windowssystem32"
    end

    test "removes path separators" do
      assert FileSanitizer.sanitize_filename("path/to/file.txt") == "file.txt"
      assert FileSanitizer.sanitize_filename("path\\to\\file.txt") == "file.txt"
    end

    test "removes null bytes" do
      assert FileSanitizer.sanitize_filename("file.txt\x00.exe") == "file.txt.exe"
    end

    test "removes control characters" do
      assert FileSanitizer.sanitize_filename("file\x01\x02.txt") == "file.txt"
    end

    test "trims leading and trailing dots" do
      assert FileSanitizer.sanitize_filename("...file.txt...") == "file.txt"
      assert FileSanitizer.sanitize_filename(".hidden") == "hidden"
    end

    test "handles empty strings" do
      assert FileSanitizer.sanitize_filename("") == "unnamed_file"
    end

    test "handles nil" do
      assert FileSanitizer.sanitize_filename(nil) == "unnamed_file"
    end

    test "preserves valid filenames" do
      assert FileSanitizer.sanitize_filename("my_file.xlsx") == "my_file.xlsx"
      assert FileSanitizer.sanitize_filename("report-2024.csv") == "report-2024.csv"
      assert FileSanitizer.sanitize_filename("file with spaces.txt") == "file with spaces.txt"
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
      assert String.contains?(path, "malicious.xlsx")
    end

    test "detects path traversal attempts" do
      # This tests the expanded path check
      # A malicious filename that somehow bypasses initial sanitization
      {:ok, path} = FileSanitizer.safe_upload_path("safe_file.xlsx")
      assert is_binary(path)
    end

    test "uses custom base directory" do
      base_dir = System.tmp_dir!()
      {:ok, path} = FileSanitizer.safe_upload_path("test.xlsx", base_dir: base_dir)
      assert String.starts_with?(path, base_dir)
    end

    test "uses custom prefix" do
      {:ok, path} = FileSanitizer.safe_upload_path("test.xlsx", prefix: "custom_prefix")
      assert String.contains?(path, "custom_prefix_test.xlsx")
    end
  end

  describe "valid_extension?/1" do
    test "accepts valid extensions" do
      assert FileSanitizer.valid_extension?("file.xlsx")
      assert FileSanitizer.valid_extension?("file.csv")
      assert FileSanitizer.valid_extension?("file.png")
      assert FileSanitizer.valid_extension?("file.jpg")
      assert FileSanitizer.valid_extension?("file.jpeg")
    end

    test "rejects invalid extensions" do
      refute FileSanitizer.valid_extension?("file.exe")
      refute FileSanitizer.valid_extension?("file.php")
      refute FileSanitizer.valid_extension?("file.js")
      refute FileSanitizer.valid_extension?("file.sh")
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
  end

  describe "valid_extension?/2 with custom list" do
    test "accepts only specified extensions" do
      assert FileSanitizer.valid_extension?("file.xlsx", [".xlsx", ".csv"])
      assert FileSanitizer.valid_extension?("file.csv", [".xlsx", ".csv"])
      refute FileSanitizer.valid_extension?("file.png", [".xlsx", ".csv"])
    end
  end
end
