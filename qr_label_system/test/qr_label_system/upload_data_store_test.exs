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

  describe "put/3 and get/1" do
    test "stores and retrieves data" do
      data = [%{name: "John", age: 30}, %{name: "Jane", age: 25}]
      columns = ["name", "age"]

      :ok = UploadDataStore.put(999, data, columns)
      {retrieved_data, retrieved_columns} = UploadDataStore.get(999)

      assert retrieved_data == data
      assert retrieved_columns == columns
    end

    test "stores complex data" do
      data = [
        %{product: "Widget", price: 9.99, quantity: 100},
        %{product: "Gadget", price: 19.99, quantity: 50}
      ]
      columns = ["product", "price", "quantity"]

      :ok = UploadDataStore.put(999, data, columns)
      {retrieved_data, retrieved_columns} = UploadDataStore.get(999)

      assert retrieved_data == data
      assert retrieved_columns == columns
    end

    test "returns empty for non-existent user" do
      {data, columns} = UploadDataStore.get(12345)
      assert data == nil
      assert columns == []
    end

    test "isolates data between users" do
      UploadDataStore.put(999, [%{a: 1}], ["a"])
      UploadDataStore.put(998, [%{b: 2}], ["b"])

      {data1, cols1} = UploadDataStore.get(999)
      {data2, cols2} = UploadDataStore.get(998)

      assert data1 == [%{a: 1}]
      assert cols1 == ["a"]
      assert data2 == [%{b: 2}]
      assert cols2 == ["b"]
    end

    test "overwrites existing data" do
      UploadDataStore.put(999, [%{original: true}], ["original"])
      UploadDataStore.put(999, [%{updated: true}], ["updated"])

      {data, columns} = UploadDataStore.get(999)

      assert data == [%{updated: true}]
      assert columns == ["updated"]
    end
  end

  describe "put/3 with string user_id" do
    test "converts string user_id to integer" do
      :ok = UploadDataStore.put("999", [%{a: 1}], ["a"])
      {data, _} = UploadDataStore.get(999)
      assert data == [%{a: 1}]
    end
  end

  describe "get/1 with string user_id" do
    test "converts string user_id to integer" do
      UploadDataStore.put(999, [%{a: 1}], ["a"])
      {data, _} = UploadDataStore.get("999")
      assert data == [%{a: 1}]
    end
  end

  describe "clear/1" do
    test "clears user data" do
      UploadDataStore.put(999, [%{a: 1}], ["a"])
      {data, _} = UploadDataStore.get(999)
      assert data != nil

      UploadDataStore.clear(999)
      {data, columns} = UploadDataStore.get(999)

      assert data == nil
      assert columns == []
    end

    test "only clears specified user" do
      UploadDataStore.put(999, [%{a: 1}], ["a"])
      UploadDataStore.put(998, [%{b: 2}], ["b"])

      UploadDataStore.clear(999)

      {data1, _} = UploadDataStore.get(999)
      {data2, _} = UploadDataStore.get(998)

      assert data1 == nil
      assert data2 == [%{b: 2}]
    end

    test "handles string user_id" do
      UploadDataStore.put(999, [%{a: 1}], ["a"])
      UploadDataStore.clear("999")

      {data, _} = UploadDataStore.get(999)
      assert data == nil
    end
  end

  describe "ensure_integer/1" do
    test "handles nil user_id" do
      {data, columns} = UploadDataStore.get(nil)
      assert data == nil
      assert columns == []
    end
  end
end
