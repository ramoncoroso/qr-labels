defmodule QrLabelSystem.DataSourcesTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.DataSources
  alias QrLabelSystem.DataSources.DataSource

  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.DataSourcesFixtures

  describe "list_data_sources/0" do
    test "returns all data sources" do
      source1 = data_source_fixture()
      source2 = data_source_fixture()

      sources = DataSources.list_data_sources()
      assert length(sources) == 2
      # Both sources should be in the list (order may vary due to timestamp ties)
      source_ids = Enum.map(sources, & &1.id)
      assert source1.id in source_ids
      assert source2.id in source_ids
    end

    test "returns empty list when no data sources exist" do
      assert DataSources.list_data_sources() == []
    end
  end

  describe "list_user_data_sources/1" do
    test "returns data sources for a specific user" do
      user = user_fixture()
      other_user = user_fixture()

      source1 = data_source_fixture(%{user_id: user.id})
      _source2 = data_source_fixture(%{user_id: other_user.id})

      sources = DataSources.list_user_data_sources(user.id)
      assert length(sources) == 1
      assert hd(sources).id == source1.id
    end

    test "returns empty list when user has no data sources" do
      user = user_fixture()
      assert DataSources.list_user_data_sources(user.id) == []
    end
  end

  describe "get_data_source!/1" do
    test "returns the data source with given id" do
      source = data_source_fixture()
      assert DataSources.get_data_source!(source.id).id == source.id
    end

    test "raises Ecto.NoResultsError if data source does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        DataSources.get_data_source!(0)
      end
    end
  end

  describe "get_data_source/1" do
    test "returns the data source with given id" do
      source = data_source_fixture()
      assert DataSources.get_data_source(source.id).id == source.id
    end

    test "returns nil if data source does not exist" do
      assert DataSources.get_data_source(0) == nil
    end
  end

  describe "create_data_source/1" do
    test "creates a data source with valid data" do
      user = user_fixture()
      workspace = QrLabelSystem.Workspaces.get_personal_workspace(user.id)
      attrs = valid_data_source_attributes(%{user_id: user.id, workspace_id: workspace.id})

      assert {:ok, %DataSource{} = source} = DataSources.create_data_source(attrs)
      assert source.name == attrs.name
      assert source.type == attrs.type
    end

    test "returns error changeset with invalid data" do
      assert {:error, %Ecto.Changeset{}} = DataSources.create_data_source(%{})
    end

    test "validates required fields" do
      assert {:error, changeset} = DataSources.create_data_source(%{})
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).type
    end

    test "validates type inclusion" do
      attrs = %{name: "Test", type: "invalid_type"}
      assert {:error, changeset} = DataSources.create_data_source(attrs)
      assert "is invalid" in errors_on(changeset).type
    end

    test "creates excel type data source" do
      user = user_fixture()
      workspace = QrLabelSystem.Workspaces.get_personal_workspace(user.id)
      attrs = valid_data_source_attributes(%{user_id: user.id, workspace_id: workspace.id, type: "excel"})

      assert {:ok, source} = DataSources.create_data_source(attrs)
      assert source.type == "excel"
    end

    test "requires connection_config for database types" do
      attrs = %{name: "Test", type: "postgresql"}
      assert {:error, changeset} = DataSources.create_data_source(attrs)
      assert "is required for database connections" in errors_on(changeset).connection_config
    end

    # Note: Database data source tests require Vault to be running for encryption
    # These tests are skipped in the default test environment

    @tag :skip
    test "creates postgresql data source with connection_config" do
      user = user_fixture()
      attrs = valid_db_data_source_attributes(%{user_id: user.id, type: "postgresql"})

      assert {:ok, source} = DataSources.create_data_source(attrs)
      assert source.type == "postgresql"
    end

    @tag :skip
    test "creates mysql data source with connection_config" do
      user = user_fixture()
      attrs = valid_db_data_source_attributes(%{user_id: user.id, type: "mysql"})

      assert {:ok, source} = DataSources.create_data_source(attrs)
      assert source.type == "mysql"
    end

    @tag :skip
    test "creates sqlserver data source with connection_config" do
      user = user_fixture()
      attrs = valid_db_data_source_attributes(%{user_id: user.id, type: "sqlserver"})

      assert {:ok, source} = DataSources.create_data_source(attrs)
      assert source.type == "sqlserver"
    end
  end

  describe "update_data_source/2" do
    test "updates data source with valid data" do
      source = data_source_fixture()
      attrs = %{name: "Updated Name"}

      assert {:ok, updated} = DataSources.update_data_source(source, attrs)
      assert updated.name == "Updated Name"
    end

    test "returns error changeset with invalid data" do
      source = data_source_fixture()
      attrs = %{type: "invalid_type"}

      assert {:error, %Ecto.Changeset{}} = DataSources.update_data_source(source, attrs)
    end
  end

  describe "delete_data_source/1" do
    test "deletes the data source" do
      source = data_source_fixture()
      assert {:ok, %DataSource{}} = DataSources.delete_data_source(source)
      assert_raise Ecto.NoResultsError, fn -> DataSources.get_data_source!(source.id) end
    end
  end

  describe "change_data_source/2" do
    test "returns a changeset" do
      source = data_source_fixture()
      assert %Ecto.Changeset{} = DataSources.change_data_source(source)
    end
  end

  describe "test_connection/1" do
    test "returns :not_applicable for excel type" do
      source = data_source_fixture(%{type: "excel"})
      assert {:ok, :not_applicable} = DataSources.test_connection(source)
    end

    test "returns error for unsupported type" do
      # This test simulates an edge case where type is somehow invalid
      source = %DataSource{type: "unknown"}
      assert {:error, "Cannot test connection for type: unknown"} = DataSources.test_connection(source)
    end
  end

  describe "validate_query/1" do
    test "validates query using DbConnector" do
      assert :ok = DataSources.validate_query("SELECT * FROM users")
    end

    test "returns error for invalid query" do
      assert {:error, _} = DataSources.validate_query("DROP TABLE users")
    end
  end
end
