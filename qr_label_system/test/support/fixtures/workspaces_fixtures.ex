defmodule QrLabelSystem.WorkspacesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `QrLabelSystem.Workspaces` context.
  """

  alias QrLabelSystem.Workspaces

  def unique_workspace_name, do: "workspace_#{System.unique_integer([:positive])}"

  def valid_workspace_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_workspace_name(),
      description: "Test workspace"
    })
  end

  @doc """
  Creates a team workspace owned by the given user.
  """
  def workspace_fixture(owner, attrs \\ %{}) do
    {:ok, workspace} =
      attrs
      |> valid_workspace_attributes()
      |> then(&Workspaces.create_workspace(owner, &1))

    workspace
  end

  @doc """
  Gets the personal workspace for a user.
  Raises if not found.
  """
  def get_personal_workspace!(user) do
    Workspaces.get_personal_workspace(user.id) ||
      raise "No personal workspace found for user #{user.id}"
  end

  @doc """
  Creates a membership for a user in a workspace.
  """
  def membership_fixture(workspace, user, role \\ "operator") do
    {:ok, membership} =
      Workspaces.create_invitation(workspace, user, user.email, role)
      |> case do
        {:ok, invitation} ->
          Workspaces.accept_invitation(invitation.token, user)
        error -> error
      end

    membership
  end
end
