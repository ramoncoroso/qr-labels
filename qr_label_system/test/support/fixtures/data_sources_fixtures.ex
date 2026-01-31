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
    {:ok, data_source} =
      attrs
      |> valid_data_source_attributes()
      |> DataSources.create_data_source()

    data_source
  end

  def db_data_source_fixture(attrs \\ %{}) do
    {:ok, data_source} =
      attrs
      |> valid_db_data_source_attributes()
      |> DataSources.create_data_source()

    data_source
  end
end
