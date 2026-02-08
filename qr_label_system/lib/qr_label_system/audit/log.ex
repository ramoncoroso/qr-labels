defmodule QrLabelSystem.Audit.Log do
  @moduledoc """
  Schema for audit logs.
  Tracks all important actions in the system for compliance and debugging.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @actions ~w(
    login logout
    create_design update_design delete_design export_design import_design
    create_version restore_version
    create_data_source update_data_source delete_data_source test_connection
    create_batch update_batch delete_batch print_batch export_pdf
    create_user update_user delete_user update_role
  )

  schema "audit_logs" do
    field :action, :string
    field :resource_type, :string
    field :resource_id, :integer
    field :metadata, :map, default: %{}
    field :ip_address, :string
    field :user_agent, :string

    belongs_to :user, QrLabelSystem.Accounts.User

    timestamps(updated_at: false, type: :utc_datetime)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:action, :resource_type, :resource_id, :metadata, :ip_address, :user_agent, :user_id])
    |> validate_required([:action, :resource_type])
    |> validate_inclusion(:action, @actions)
  end

  def actions, do: @actions
end
