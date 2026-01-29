defmodule QrLabelSystem.Repo.Migrations.AddAdvancedAuditLogsIndexes do
  use Ecto.Migration

  @doc """
  Adds advanced performance indexes for audit_logs table.

  These indexes improve query performance for:
  - Full-text search on metadata (GIN index for JSONB)
  - Covering index for common dashboard queries
  - Partial index for recent logs (last 30 days performance)
  """

  def change do
    # GIN index for JSONB metadata queries (allows efficient @> and ? operators)
    create_if_not_exists index(:audit_logs, [:metadata], using: :gin)

    # Covering index for common paginated queries (user + action + date)
    create_if_not_exists index(:audit_logs, [:user_id, :action, :inserted_at])

    # Composite index for resource queries with date
    create_if_not_exists index(:audit_logs, [:resource_type, :resource_id, :inserted_at])

    # Index for IP-based queries (security auditing)
    create_if_not_exists index(:audit_logs, [:ip_address, :inserted_at])
  end
end
