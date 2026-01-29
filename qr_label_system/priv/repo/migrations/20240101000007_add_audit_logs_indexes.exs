defmodule QrLabelSystem.Repo.Migrations.AddAuditLogsIndexes do
  use Ecto.Migration

  @doc """
  Adds performance indexes for audit_logs table.

  These indexes improve query performance for:
  - Filtering by user_id (user activity lookup)
  - Filtering by action (action-based queries)
  - Filtering by resource_type and resource_id (resource history)
  - Sorting by inserted_at (chronological queries)
  - Combined filters commonly used in the admin dashboard
  """

  def change do
    # Index for user activity queries
    create_if_not_exists index(:audit_logs, [:user_id])

    # Index for action-based queries
    create_if_not_exists index(:audit_logs, [:action])

    # Index for resource history queries
    create_if_not_exists index(:audit_logs, [:resource_type, :resource_id])

    # Index for chronological queries (most recent first)
    create_if_not_exists index(:audit_logs, [:inserted_at])

    # Composite index for common dashboard queries (user + date range)
    create_if_not_exists index(:audit_logs, [:user_id, :inserted_at])

    # Composite index for filtering by action and date
    create_if_not_exists index(:audit_logs, [:action, :inserted_at])

    # Composite index for resource type + date (admin reports)
    create_if_not_exists index(:audit_logs, [:resource_type, :inserted_at])
  end
end
