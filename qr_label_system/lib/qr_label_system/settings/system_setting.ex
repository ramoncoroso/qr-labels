defmodule QrLabelSystem.Settings.SystemSetting do
  @moduledoc """
  Schema for system-wide settings stored in the database.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "system_settings" do
    field :key, :string
    field :value, :string
    timestamps()
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value])
    |> validate_required([:key])
    |> unique_constraint(:key)
  end
end
