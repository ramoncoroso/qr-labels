defmodule QrLabelSystem.DataSources.DataSource do
  @moduledoc """
  Schema for data sources.

  Supports multiple types:
  - excel: Uploaded Excel/CSV files
  - postgresql: PostgreSQL database connection
  - mysql: MySQL database connection
  - sqlserver: SQL Server database connection

  Connection configurations are encrypted using Cloak.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @source_types ~w(excel csv postgresql mysql sqlserver)

  schema "data_sources" do
    field :name, :string
    field :type, :string
    field :query, :string

    # File path for Excel/CSV uploads
    field :file_path, :string
    field :file_name, :string

    # Connection config stored as encrypted binary
    field :connection_config, QrLabelSystem.Encrypted.Map

    # Virtual fields for form handling
    field :host, :string, virtual: true
    field :port, :integer, virtual: true
    field :database, :string, virtual: true
    field :username, :string, virtual: true
    field :password, :string, virtual: true

    # Test connection results
    field :last_tested_at, :utc_datetime
    field :test_status, :string
    field :test_error, :string

    belongs_to :user, QrLabelSystem.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating a data source.
  """
  def changeset(data_source, attrs) do
    data_source
    |> cast(attrs, [:name, :type, :query, :connection_config, :user_id, :host, :port, :database, :username, :password, :file_path, :file_name])
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, @source_types)
    |> validate_connection_config()
  end

  @doc """
  Changeset for updating test results.
  """
  def test_result_changeset(data_source, attrs) do
    data_source
    |> cast(attrs, [:last_tested_at, :test_status, :test_error])
    |> validate_inclusion(:test_status, ~w(success failed pending))
  end

  defp validate_connection_config(changeset) do
    type = get_field(changeset, :type)
    config = get_field(changeset, :connection_config)

    cond do
      type in ~w(excel csv) ->
        # Excel/CSV don't need connection config
        changeset

      type in ~w(postgresql mysql sqlserver) and is_nil(config) ->
        add_error(changeset, :connection_config, "is required for database connections")

      type in ~w(postgresql mysql sqlserver) ->
        validate_db_config(changeset, config)

      true ->
        changeset
    end
  end

  defp validate_db_config(changeset, config) when is_map(config) do
    required_fields = ~w(host database username password)
    missing = Enum.filter(required_fields, fn field ->
      is_nil(config[field]) or config[field] == ""
    end)

    if Enum.empty?(missing) do
      changeset
    else
      add_error(changeset, :connection_config, "missing required fields: #{Enum.join(missing, ", ")}")
    end
  end

  defp validate_db_config(changeset, _), do: changeset

  def source_types, do: @source_types

  @doc """
  Returns the connection config without sensitive data (for display).
  """
  def safe_connection_config(%__MODULE__{connection_config: nil}), do: nil
  def safe_connection_config(%__MODULE__{connection_config: config}) when is_map(config) do
    config
    |> Map.drop(["password"])
    |> Map.put("password", "••••••••")
  end
  def safe_connection_config(_), do: nil
end
