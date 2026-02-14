defmodule QrLabelSystem.DataSourcesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `QrLabelSystem.DataSources` context.
  """

  alias QrLabelSystem.DataSources

  def unique_data_source_name, do: "data_source_#{System.unique_integer()}"

  def valid_data_source_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_data_source_name(),
      type: "excel"
    })
  end

  def valid_db_data_source_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_data_source_name(),
      type: "postgresql",
      connection_config: %{
        "host" => "localhost",
        "port" => 5432,
        "database" => "test_db",
        "username" => "test_user",
        "password" => "test_password"
      }
    })
  end

  def data_source_fixture(attrs \\ %{}) do
    attrs = ensure_workspace_id(attrs)

    {:ok, data_source} =
      attrs
      |> valid_data_source_attributes()
      |> DataSources.create_data_source()

    data_source
  end

  def db_data_source_fixture(attrs \\ %{}) do
    attrs = ensure_workspace_id(attrs)

    {:ok, data_source} =
      attrs
      |> valid_db_data_source_attributes()
      |> DataSources.create_data_source()

    data_source
  end

  # Auto-provide workspace_id when user_id is given but workspace_id is not.
  # If neither is provided, creates a user+workspace automatically.
  defp ensure_workspace_id(attrs) do
    attrs = Map.new(attrs)

    cond do
      Map.has_key?(attrs, :workspace_id) ->
        attrs

      Map.has_key?(attrs, :user_id) ->
        workspace = QrLabelSystem.Workspaces.get_personal_workspace(attrs.user_id)
        Map.put(attrs, :workspace_id, workspace && workspace.id)

      true ->
        user = QrLabelSystem.AccountsFixtures.user_fixture()
        workspace = QrLabelSystem.Workspaces.get_personal_workspace(user.id)
        attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:workspace_id, workspace && workspace.id)
    end
  end
end
