defmodule QrLabelSystem.CacheTest do
  use ExUnit.Case

  alias QrLabelSystem.Cache

  # Note: Cache is started by the application supervisor
  # If tests fail, ensure Cache GenServer is running

  setup do
    # Clear all caches before each test
    Cache.clear_all()
    :ok
  end

  describe "put/4 and get/2" do
    test "stores and retrieves a value" do
      Cache.put(:designs, "key1", "value1")
      assert {:ok, "value1"} = Cache.get(:designs, "key1")
    end

    test "stores complex values" do
      value = %{id: 1, name: "Test", nested: %{a: 1, b: 2}}
      Cache.put(:designs, "complex", value)
      assert {:ok, ^value} = Cache.get(:designs, "complex")
    end

    test "returns :miss for non-existent key" do
      assert :miss = Cache.get(:designs, "nonexistent")
    end

    test "works with different namespaces" do
      Cache.put(:designs, "key", "design_value")
      Cache.put(:users, "key", "user_value")
      Cache.put(:stats, "key", "stats_value")

      assert {:ok, "design_value"} = Cache.get(:designs, "key")
      assert {:ok, "user_value"} = Cache.get(:users, "key")
      assert {:ok, "stats_value"} = Cache.get(:stats, "key")
    end

    test "overwrites existing value" do
      Cache.put(:designs, "key", "original")
      Cache.put(:designs, "key", "updated")
      assert {:ok, "updated"} = Cache.get(:designs, "key")
    end
  end

  describe "put/4 with TTL" do
    test "respects TTL" do
      Cache.put(:designs, "short_ttl", "value", ttl: 50)

      assert {:ok, "value"} = Cache.get(:designs, "short_ttl")

      # Wait for expiration
      Process.sleep(60)

      assert :miss = Cache.get(:designs, "short_ttl")
    end
  end

  describe "delete/2" do
    test "deletes a key" do
      Cache.put(:designs, "to_delete", "value")
      assert {:ok, "value"} = Cache.get(:designs, "to_delete")

      Cache.delete(:designs, "to_delete")
      assert :miss = Cache.get(:designs, "to_delete")
    end

    test "returns :ok for non-existent key" do
      assert :ok = Cache.delete(:designs, "nonexistent")
    end
  end

  describe "clear/1" do
    test "clears all keys in namespace" do
      Cache.put(:designs, "key1", "value1")
      Cache.put(:designs, "key2", "value2")
      Cache.put(:users, "key3", "value3")

      Cache.clear(:designs)

      assert :miss = Cache.get(:designs, "key1")
      assert :miss = Cache.get(:designs, "key2")
      assert {:ok, "value3"} = Cache.get(:users, "key3")
    end
  end

  describe "clear_all/0" do
    test "clears all namespaces" do
      Cache.put(:designs, "key1", "value1")
      Cache.put(:users, "key2", "value2")
      Cache.put(:stats, "key3", "value3")

      Cache.clear_all()

      assert :miss = Cache.get(:designs, "key1")
      assert :miss = Cache.get(:users, "key2")
      assert :miss = Cache.get(:stats, "key3")
    end
  end

  describe "fetch/4" do
    test "returns cached value if exists" do
      Cache.put(:designs, "cached", "cached_value")

      result = Cache.fetch(:designs, "cached", fn -> "computed_value" end)
      assert result == "cached_value"
    end

    test "computes and caches value if not exists" do
      result = Cache.fetch(:designs, "new_key", fn -> "computed" end)

      assert result == "computed"
      assert {:ok, "computed"} = Cache.get(:designs, "new_key")
    end

    test "passes TTL to put" do
      Cache.fetch(:designs, "ttl_key", fn -> "value" end, ttl: 50)

      assert {:ok, "value"} = Cache.get(:designs, "ttl_key")
      Process.sleep(60)
      assert :miss = Cache.get(:designs, "ttl_key")
    end
  end

  describe "stats/0" do
    test "returns stats for all namespaces" do
      Cache.put(:designs, "key", "value")

      stats = Cache.stats()

      assert Map.has_key?(stats, :designs)
      assert Map.has_key?(stats, :users)
      assert Map.has_key?(stats, :stats)

      assert Map.has_key?(stats.designs, :size)
      assert Map.has_key?(stats.designs, :memory)
    end

    test "returns size count" do
      Cache.clear(:designs)
      Cache.put(:designs, "key1", "value1")
      Cache.put(:designs, "key2", "value2")

      stats = Cache.stats()
      assert stats.designs.size == 2
    end
  end
end
