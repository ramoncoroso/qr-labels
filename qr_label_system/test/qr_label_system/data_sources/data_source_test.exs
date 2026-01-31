defmodule QrLabelSystem.DataSources.DataSourceTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.DataSources.DataSource

  describe "changeset/2 - required fields" do
    test "valid changeset with required fields" do
      attrs = %{name: "Test Source", type: "excel"}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      assert changeset.valid?
    end

    test "invalid without name" do
      attrs = %{type: "excel"}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "invalid without type" do
      attrs = %{name: "Test"}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).type
    end
  end

  describe "changeset/2 - type validation" do
    test "accepts excel type" do
      attrs = %{name: "Test", type: "excel"}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      assert changeset.valid?
    end

    test "accepts postgresql type with connection_config" do
      attrs = %{
        name: "Test",
        type: "postgresql",
        connection_config: valid_db_config()
      }
      changeset = DataSource.changeset(%DataSource{}, attrs)
      assert changeset.valid?
    end

    test "accepts mysql type with connection_config" do
      attrs = %{
        name: "Test",
        type: "mysql",
        connection_config: valid_db_config()
      }
      changeset = DataSource.changeset(%DataSource{}, attrs)
      assert changeset.valid?
    end

    test "accepts sqlserver type with connection_config" do
      attrs = %{
        name: "Test",
        type: "sqlserver",
        connection_config: valid_db_config()
      }
      changeset = DataSource.changeset(%DataSource{}, attrs)
      assert changeset.valid?
    end

    test "rejects invalid type" do
      attrs = %{name: "Test", type: "invalid"}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).type
    end
  end

  describe "changeset/2 - connection_config validation" do
    test "requires connection_config for postgresql" do
      attrs = %{name: "Test", type: "postgresql"}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      refute changeset.valid?
      assert "is required for database connections" in errors_on(changeset).connection_config
    end

    test "requires connection_config for mysql" do
      attrs = %{name: "Test", type: "mysql"}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      refute changeset.valid?
      assert "is required for database connections" in errors_on(changeset).connection_config
    end

    test "requires connection_config for sqlserver" do
      attrs = %{name: "Test", type: "sqlserver"}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      refute changeset.valid?
      assert "is required for database connections" in errors_on(changeset).connection_config
    end

    test "does not require connection_config for excel" do
      attrs = %{name: "Test", type: "excel"}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      assert changeset.valid?
    end

    test "validates required fields in connection_config" do
      attrs = %{
        name: "Test",
        type: "postgresql",
        connection_config: %{"host" => "localhost"}
      }
      changeset = DataSource.changeset(%DataSource{}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).connection_config != nil
    end

    test "validates host in connection_config" do
      config = valid_db_config() |> Map.delete("host")
      attrs = %{name: "Test", type: "postgresql", connection_config: config}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      refute changeset.valid?
    end

    test "validates database in connection_config" do
      config = valid_db_config() |> Map.delete("database")
      attrs = %{name: "Test", type: "postgresql", connection_config: config}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      refute changeset.valid?
    end

    test "validates username in connection_config" do
      config = valid_db_config() |> Map.delete("username")
      attrs = %{name: "Test", type: "postgresql", connection_config: config}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      refute changeset.valid?
    end

    test "validates password in connection_config" do
      config = valid_db_config() |> Map.delete("password")
      attrs = %{name: "Test", type: "postgresql", connection_config: config}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      refute changeset.valid?
    end

    test "rejects empty strings in connection_config" do
      config = valid_db_config() |> Map.put("host", "")
      attrs = %{name: "Test", type: "postgresql", connection_config: config}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      refute changeset.valid?
    end
  end

  describe "changeset/2 - optional fields" do
    test "accepts query field" do
      attrs = %{
        name: "Test",
        type: "postgresql",
        connection_config: valid_db_config(),
        query: "SELECT * FROM users"
      }
      changeset = DataSource.changeset(%DataSource{}, attrs)
      assert changeset.valid?
    end

    test "accepts file_path and file_name for excel" do
      attrs = %{
        name: "Test",
        type: "excel",
        file_path: "/path/to/file.xlsx",
        file_name: "file.xlsx"
      }
      changeset = DataSource.changeset(%DataSource{}, attrs)
      assert changeset.valid?
    end

    test "accepts user_id" do
      attrs = %{name: "Test", type: "excel", user_id: 1}
      changeset = DataSource.changeset(%DataSource{}, attrs)
      assert changeset.valid?
    end
  end

  describe "test_result_changeset/2" do
    test "accepts valid test result fields" do
      source = %DataSource{}
      attrs = %{
        last_tested_at: DateTime.utc_now(),
        test_status: "success",
        test_error: nil
      }
      changeset = DataSource.test_result_changeset(source, attrs)
      assert changeset.valid?
    end

    test "validates test_status values" do
      source = %DataSource{}
      attrs = %{test_status: "invalid_status"}
      changeset = DataSource.test_result_changeset(source, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).test_status
    end

    test "accepts success status" do
      source = %DataSource{}
      attrs = %{test_status: "success"}
      changeset = DataSource.test_result_changeset(source, attrs)
      assert changeset.valid?
    end

    test "accepts failed status" do
      source = %DataSource{}
      attrs = %{test_status: "failed", test_error: "Connection refused"}
      changeset = DataSource.test_result_changeset(source, attrs)
      assert changeset.valid?
    end

    test "accepts pending status" do
      source = %DataSource{}
      attrs = %{test_status: "pending"}
      changeset = DataSource.test_result_changeset(source, attrs)
      assert changeset.valid?
    end
  end

  describe "source_types/0" do
    test "returns all valid source types" do
      types = DataSource.source_types()
      assert "excel" in types
      assert "postgresql" in types
      assert "mysql" in types
      assert "sqlserver" in types
    end
  end

  describe "safe_connection_config/1" do
    test "returns nil for nil config" do
      source = %DataSource{connection_config: nil}
      assert DataSource.safe_connection_config(source) == nil
    end

    test "masks password in config" do
      source = %DataSource{
        connection_config: %{
          "host" => "localhost",
          "database" => "test",
          "username" => "user",
          "password" => "secret123"
        }
      }

      safe = DataSource.safe_connection_config(source)
      assert safe["host"] == "localhost"
      assert safe["database"] == "test"
      assert safe["username"] == "user"
      assert safe["password"] == "••••••••"
    end

    test "handles empty source" do
      source = %DataSource{}
      assert DataSource.safe_connection_config(source) == nil
    end
  end

  # Helper functions
  defp valid_db_config do
    %{
      "host" => "localhost",
      "port" => 5432,
      "database" => "test_db",
      "username" => "test_user",
      "password" => "test_password"
    }
  end
end
