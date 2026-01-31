defmodule QrLabelSystem.DesignsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `QrLabelSystem.Designs` context.
  """

  alias QrLabelSystem.Designs

  def unique_design_name, do: "design_#{System.unique_integer()}"

  def valid_design_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_design_name(),
      description: "Test design description",
      width_mm: 50.0,
      height_mm: 30.0,
      background_color: "#FFFFFF",
      border_width: 0.5,
      border_color: "#000000",
      border_radius: 2.0,
      elements: []
    })
  end

  def design_fixture(attrs \\ %{}) do
    {:ok, design} =
      attrs
      |> valid_design_attributes()
      |> Designs.create_design()

    design
  end
end
