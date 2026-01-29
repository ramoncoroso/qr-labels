defmodule QrLabelSystem.SoftDelete do
  @moduledoc """
  Soft delete behavior for Ecto schemas.

  Provides soft delete functionality that marks records as deleted
  instead of physically removing them from the database.

  ## Usage

  1. Add the `deleted_at` field to your schema:

      schema "designs" do
        # ... other fields
        field :deleted_at, :utc_datetime
        timestamps()
      end

  2. Use the SoftDelete functions in your context:

      def delete_design(design) do
        SoftDelete.soft_delete(design)
      end

      def list_designs() do
        Design
        |> SoftDelete.not_deleted()
        |> Repo.all()
      end

      def list_deleted_designs() do
        Design
        |> SoftDelete.only_deleted()
        |> Repo.all()
      end

      def restore_design(design) do
        SoftDelete.restore(design)
      end

  3. Create the migration:

      alter table(:designs) do
        add :deleted_at, :utc_datetime
      end

      create index(:designs, [:deleted_at])
  """

  import Ecto.Query
  alias QrLabelSystem.Repo

  @doc """
  Soft deletes a record by setting its `deleted_at` timestamp.
  """
  def soft_delete(struct) do
    struct
    |> Ecto.Changeset.change(deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  @doc """
  Soft deletes a record and also soft deletes associated records.

  ## Options
  - `:cascade` - List of associations to cascade the soft delete to
  """
  def soft_delete(struct, opts) do
    Repo.transaction(fn ->
      case soft_delete(struct) do
        {:ok, deleted_struct} ->
          cascade_associations = Keyword.get(opts, :cascade, [])

          for assoc <- cascade_associations do
            soft_delete_association(deleted_struct, assoc)
          end

          deleted_struct

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Restores a soft-deleted record by clearing its `deleted_at` timestamp.
  """
  def restore(struct) do
    struct
    |> Ecto.Changeset.change(deleted_at: nil)
    |> Repo.update()
  end

  @doc """
  Permanently deletes a soft-deleted record.
  Only works on records that have been soft-deleted.
  """
  def hard_delete(%{deleted_at: deleted_at} = struct) when not is_nil(deleted_at) do
    Repo.delete(struct)
  end

  def hard_delete(_struct) do
    {:error, :not_soft_deleted}
  end

  @doc """
  Returns a query that excludes soft-deleted records.
  """
  def not_deleted(query) do
    from(q in query, where: is_nil(q.deleted_at))
  end

  @doc """
  Returns a query that only includes soft-deleted records.
  """
  def only_deleted(query) do
    from(q in query, where: not is_nil(q.deleted_at))
  end

  @doc """
  Returns a query that includes all records (deleted and not deleted).
  """
  def with_deleted(query) do
    query
  end

  @doc """
  Checks if a record has been soft-deleted.
  """
  def deleted?(%{deleted_at: deleted_at}) when not is_nil(deleted_at), do: true
  def deleted?(_), do: false

  @doc """
  Permanently deletes all records that have been soft-deleted
  for longer than the specified duration.

  ## Options
  - `:older_than_days` - Only delete records soft-deleted more than N days ago (default: 30)
  """
  def purge_deleted(schema, opts \\ []) do
    days = Keyword.get(opts, :older_than_days, 30)
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    from(s in schema,
      where: not is_nil(s.deleted_at),
      where: s.deleted_at < ^cutoff
    )
    |> Repo.delete_all()
  end

  @doc """
  Returns statistics about soft-deleted records.
  """
  def stats(schema) do
    total = Repo.aggregate(schema, :count)
    deleted = Repo.aggregate(only_deleted(schema), :count)
    active = Repo.aggregate(not_deleted(schema), :count)

    %{
      total: total,
      active: active,
      deleted: deleted,
      deletion_rate: if(total > 0, do: deleted / total * 100, else: 0)
    }
  end

  # Private functions

  defp soft_delete_association(struct, assoc_name) do
    case Map.get(struct, assoc_name) do
      %Ecto.Association.NotLoaded{} ->
        struct = Repo.preload(struct, assoc_name)
        soft_delete_association(struct, assoc_name)

      nil ->
        :ok

      records when is_list(records) ->
        for record <- records do
          soft_delete(record)
        end

      record ->
        soft_delete(record)
    end
  end
end
