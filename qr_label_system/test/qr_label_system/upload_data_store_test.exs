defmodule QrLabelSystem.UploadDataStoreTest do
  use ExUnit.Case

  alias QrLabelSystem.UploadDataStore

  # Note: UploadDataStore is started by the application supervisor

  setup do
    # Clear test user data before each test
    UploadDataStore.clear(999)
    UploadDataStore.clear(998)
    :ok
  end

  describe "put_metadata/5 and get_metadata/2" do
    test "stores and retrieves metadata" do
      columns = ["name", "age"]
      sample_rows = [%{"name" => "John", "age" => "30"}, %{"name" => "Jane", "age" => "25"}]

      :ok = UploadDataStore.put_metadata(999, nil, columns, 2, sample_rows)
      {retrieved_columns, total_rows, retrieved_sample} = UploadDataStore.get_metadata(999, nil)

      assert retrieved_columns == columns
      assert total_rows == 2
      assert retrieved_sample == sample_rows
    end

    test "stores metadata with design_id" do
      columns = ["product", "price"]
      sample_rows = [%{"product" => "Widget", "price" => "9.99"}]

      :ok = UploadDataStore.put_metadata(999, 42, columns, 100, sample_rows)
      {retrieved_columns, total_rows, retrieved_sample} = UploadDataStore.get_metadata(999, 42)

      assert retrieved_columns == columns
      assert total_rows == 100
      assert retrieved_sample == sample_rows
    end

    test "returns empty for non-existent user" do
      {columns, total_rows, sample_rows} = UploadDataStore.get_metadata(12345, nil)
      assert columns == []
      assert total_rows == 0
      assert sample_rows == []
    end

    test "isolates data between users" do
      UploadDataStore.put_metadata(999, nil, ["a"], 1, [%{"a" => "1"}])
      UploadDataStore.put_metadata(998, nil, ["b"], 2, [%{"b" => "2"}])

      {cols1, total1, _} = UploadDataStore.get_metadata(999, nil)
      {cols2, total2, _} = UploadDataStore.get_metadata(998, nil)

      assert cols1 == ["a"]
      assert total1 == 1
      assert cols2 == ["b"]
      assert total2 == 2
    end

    test "overwrites existing metadata" do
      UploadDataStore.put_metadata(999, nil, ["original"], 1, [%{"original" => "yes"}])
      UploadDataStore.put_metadata(999, nil, ["updated"], 5, [%{"updated" => "yes"}])

      {columns, total_rows, _} = UploadDataStore.get_metadata(999, nil)

      assert columns == ["updated"]
      assert total_rows == 5
    end
  end

  describe "put_metadata with string user_id" do
    test "converts string user_id to integer" do
      :ok = UploadDataStore.put_metadata("999", nil, ["a"], 1, [%{"a" => "1"}])
      {cols, total, _} = UploadDataStore.get_metadata(999, nil)
      assert cols == ["a"]
      assert total == 1
    end
  end

  describe "get_metadata with string user_id" do
    test "converts string user_id to integer" do
      UploadDataStore.put_metadata(999, nil, ["a"], 1, [%{"a" => "1"}])
      {cols, _, _} = UploadDataStore.get_metadata("999", nil)
      assert cols == ["a"]
    end
  end

  describe "has_data?/2" do
    test "returns true when data exists" do
      UploadDataStore.put_metadata(999, nil, ["a"], 1, [%{"a" => "1"}])
      assert UploadDataStore.has_data?(999, nil) == true
    end

    test "returns false when no data" do
      assert UploadDataStore.has_data?(999, nil) == false
    end

    test "returns false when total_rows is 0" do
      UploadDataStore.put_metadata(999, nil, ["a"], 0, [])
      assert UploadDataStore.has_data?(999, nil) == false
    end
  end

  describe "associate_with_design/2" do
    test "moves metadata from nil to design_id" do
      UploadDataStore.put_metadata(999, nil, ["a"], 5, [%{"a" => "1"}])

      :ok = UploadDataStore.associate_with_design(999, 42)

      {cols_nil, total_nil, _} = UploadDataStore.get_metadata(999, nil)
      assert cols_nil == []
      assert total_nil == 0

      {cols_42, total_42, _} = UploadDataStore.get_metadata(999, 42)
      assert cols_42 == ["a"]
      assert total_42 == 5
    end

    test "returns error when no source data" do
      assert {:error, :no_data} == UploadDataStore.associate_with_design(999, 42)
    end
  end

  describe "clear/2" do
    test "clears user data" do
      UploadDataStore.put_metadata(999, nil, ["a"], 1, [%{"a" => "1"}])
      assert UploadDataStore.has_data?(999, nil) == true

      UploadDataStore.clear(999)
      {columns, total_rows, sample} = UploadDataStore.get_metadata(999, nil)

      assert columns == []
      assert total_rows == 0
      assert sample == []
    end

    test "only clears specified user" do
      UploadDataStore.put_metadata(999, nil, ["a"], 1, [%{"a" => "1"}])
      UploadDataStore.put_metadata(998, nil, ["b"], 2, [%{"b" => "2"}])

      UploadDataStore.clear(999)

      assert UploadDataStore.has_data?(999, nil) == false
      assert UploadDataStore.has_data?(998, nil) == true
    end

    test "handles string user_id" do
      UploadDataStore.put_metadata(999, nil, ["a"], 1, [%{"a" => "1"}])
      UploadDataStore.clear("999")

      assert UploadDataStore.has_data?(999, nil) == false
    end
  end

  describe "ensure_integer/1" do
    test "handles nil user_id" do
      {columns, total_rows, sample} = UploadDataStore.get_metadata(nil, nil)
      assert columns == []
      assert total_rows == 0
      assert sample == []
    end
  end
end
