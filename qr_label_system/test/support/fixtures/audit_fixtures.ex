defmodule QrLabelSystem.AuditFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `QrLabelSystem.Audit` context.
  """

  alias QrLabelSystem.Audit

  @valid_actions ~w(
    login logout
    create_design update_design delete_design export_design import_design
    create_data_source update_data_source delete_data_source test_connection
    create_batch update_batch delete_batch print_batch export_pdf
    create_user update_user delete_user update_role
  )

  def valid_audit_log_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      action: Enum.random(@valid_actions),
      resource_type: "design",
      resource_id: System.unique_integer([:positive])
    })
  end

  def audit_log_fixture(attrs \\ %{}) do
    attrs = valid_audit_log_attributes(attrs)

    {:ok, log} = Audit.log(
      attrs.action,
      attrs.resource_type,
      attrs[:resource_id],
      user_id: attrs[:user_id],
      metadata: attrs[:metadata] || %{},
      ip_address: attrs[:ip_address],
      user_agent: attrs[:user_agent]
    )

    log
  end
end
