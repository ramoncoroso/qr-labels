defmodule QrLabelSystem.SoftDeleteTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.SoftDelete
  alias QrLabelSystem.Repo

  # Define a test schema with deleted_at for testing soft delete functionality
  # In real usage, you would add deleted_at field to your actual schemas
  defmodule TestSoftDeleteSchema do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "audit_logs" do
      # Using audit_logs as it has a deleted_at-compatible structure
      # We'll use its fields and manually manage our test data
      field :action, :string
      field :deleted_at, :utc_datetime, virtual: true
      timestamps()
    end
  end

  # Since we can't easily create a test table, we'll test the module's
  # functions that don't require database operations
  describe "deleted?/1" do
    test "returns true for record with deleted_at set" do
      record = %{deleted_at: DateTime.utc_now()}
      assert SoftDelete.deleted?(record) == true
    end

    test "returns false for record with nil deleted_at" do
      record = %{deleted_at: nil}
      assert SoftDelete.deleted?(record) == false
    end

    test "returns false for map without deleted_at" do
      record = %{name: "test"}
      assert SoftDelete.deleted?(record) == false
    end
  end

  describe "with_deleted/1" do
    test "returns the same query" do
      import Ecto.Query
      query = from(l in "audit_logs", select: l.id)

      result = SoftDelete.with_deleted(query)

      # with_deleted just returns the same query unchanged
      assert result == query
    end
  end

  describe "not_deleted/1" do
    test "adds where clause for nil deleted_at" do
      import Ecto.Query
      query = from(l in "audit_logs", select: l.id)

      result = SoftDelete.not_deleted(query)

      # The query should have a where clause added
      assert %Ecto.Query{} = result
      assert result != query
    end
  end

  describe "only_deleted/1" do
    test "adds where clause for non-nil deleted_at" do
      import Ecto.Query
      query = from(l in "audit_logs", select: l.id)

      result = SoftDelete.only_deleted(query)

      # The query should have a where clause added
      assert %Ecto.Query{} = result
      assert result != query
    end
  end

  describe "hard_delete/1" do
    test "returns error for record without deleted_at set" do
      # A record that hasn't been soft-deleted (nil deleted_at)
      record = %{deleted_at: nil, __struct__: TestStruct}

      assert {:error, :not_soft_deleted} = SoftDelete.hard_delete(record)
    end

    test "returns error for map without deleted_at" do
      record = %{name: "test"}

      assert {:error, :not_soft_deleted} = SoftDelete.hard_delete(record)
    end
  end

  # Integration tests with actual database operations
  # These require a schema with deleted_at field in the database
  # For now, we test the query building functionality

  describe "query building" do
    import Ecto.Query

    test "not_deleted query excludes deleted records" do
      base_query = from(l in "logs")
      query = SoftDelete.not_deleted(base_query)

      # Check query has where clause
      assert %Ecto.Query{wheres: wheres} = query
      assert length(wheres) > 0
    end

    test "only_deleted query includes only deleted records" do
      base_query = from(l in "logs")
      query = SoftDelete.only_deleted(base_query)

      # Check query has where clause
      assert %Ecto.Query{wheres: wheres} = query
      assert length(wheres) > 0
    end

    test "queries can be chained" do
      base_query = from(l in "logs", where: l.action == "test")
      query = SoftDelete.not_deleted(base_query)

      # Should have original where + soft delete where
      assert %Ecto.Query{wheres: wheres} = query
      assert length(wheres) == 2
    end
  end
end

defmodule TestStruct do
  defstruct [:deleted_at, :name]
end
