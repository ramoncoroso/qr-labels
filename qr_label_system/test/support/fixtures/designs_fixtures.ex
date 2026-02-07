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

  def template_fixture(attrs \\ %{}) do
    {:ok, design} =
      attrs
      |> Enum.into(%{is_template: true})
      |> valid_design_attributes()
      |> Designs.create_design()

    design
  end

  def system_template_fixture(attrs \\ %{}) do
    {:ok, design} =
      attrs
      |> Enum.into(%{
        is_template: true,
        template_source: "system",
        template_category: "logistica"
      })
      |> valid_design_attributes()
      |> Designs.create_design()

    design
  end

  def design_with_elements_fixture(attrs \\ %{}) do
    elements = [
      qr_element_attrs(),
      text_element_attrs(),
      barcode_element_attrs()
    ]

    {:ok, design} =
      attrs
      |> Enum.into(%{elements: elements})
      |> valid_design_attributes()
      |> Designs.create_design()

    design
  end

  # Element attribute helpers

  def qr_element_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      id: "el_qr_#{System.unique_integer([:positive])}",
      type: "qr",
      x: 10.0,
      y: 10.0,
      width: 20.0,
      height: 20.0,
      qr_error_level: "M",
      binding: "product_code"
    })
  end

  def text_element_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      id: "el_text_#{System.unique_integer([:positive])}",
      type: "text",
      x: 35.0,
      y: 10.0,
      width: 50.0,
      height: 10.0,
      font_size: 12.0,
      font_family: "Arial",
      text_content: "Sample Text",
      color: "#000000"
    })
  end

  def barcode_element_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      id: "el_barcode_#{System.unique_integer([:positive])}",
      type: "barcode",
      x: 10.0,
      y: 35.0,
      width: 40.0,
      height: 15.0,
      barcode_format: "CODE128",
      barcode_show_text: true,
      binding: "sku"
    })
  end

  def rectangle_element_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      id: "el_rect_#{System.unique_integer([:positive])}",
      type: "rectangle",
      x: 0.0,
      y: 0.0,
      width: 50.0,
      height: 30.0,
      border_width: 1.0,
      border_color: "#000000",
      background_color: "#FFFFFF"
    })
  end

  def line_element_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      id: "el_line_#{System.unique_integer([:positive])}",
      type: "line",
      x: 0.0,
      y: 25.0,
      width: 50.0,
      height: 0.0,
      color: "#000000",
      border_width: 1.0
    })
  end

  def image_element_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      id: "el_image_#{System.unique_integer([:positive])}",
      type: "image",
      x: 5.0,
      y: 5.0,
      width: 15.0,
      height: 15.0,
      image_url: "/images/logo.png"
    })
  end
end
