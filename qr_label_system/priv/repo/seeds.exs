# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     QrLabelSystem.Repo.insert!(%QrLabelSystem.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias QrLabelSystem.Repo
alias QrLabelSystem.Accounts
alias QrLabelSystem.Designs
alias QrLabelSystem.Designs.Design

# Create admin user
{:ok, admin} = Accounts.register_user(%{
  email: "admin@example.com",
  password: "admin123456",
  role: "admin"
})

IO.puts("Created admin user: admin@example.com / admin123456")

# Create sample design
{:ok, _design} = Designs.create_design(%{
  name: "Etiqueta Muestra Laboratorio",
  description: "Diseño estándar para muestras de laboratorio",
  width_mm: 50,
  height_mm: 25,
  background_color: "#FFFFFF",
  border_width: 0.5,
  border_color: "#000000",
  border_radius: 2,
  is_template: true,
  user_id: admin.id,
  elements: [
    %{
      id: Ecto.UUID.generate(),
      type: "qr",
      x: 2,
      y: 2,
      width: 20,
      height: 20,
      rotation: 0,
      qr_error_level: "M",
      binding: "ID"
    },
    %{
      id: Ecto.UUID.generate(),
      type: "text",
      x: 25,
      y: 3,
      width: 23,
      height: 6,
      rotation: 0,
      font_size: 10,
      font_family: "Arial",
      font_weight: "bold",
      text_align: "left",
      color: "#000000",
      binding: "Paciente"
    },
    %{
      id: Ecto.UUID.generate(),
      type: "text",
      x: 25,
      y: 10,
      width: 23,
      height: 5,
      rotation: 0,
      font_size: 8,
      font_family: "Arial",
      font_weight: "normal",
      text_align: "left",
      color: "#333333",
      binding: "Fecha"
    },
    %{
      id: Ecto.UUID.generate(),
      type: "text",
      x: 25,
      y: 16,
      width: 23,
      height: 5,
      rotation: 0,
      font_size: 8,
      font_family: "Arial",
      font_weight: "normal",
      text_align: "left",
      color: "#333333",
      binding: "Tipo"
    }
  ]
})

IO.puts("Created sample design: Etiqueta Muestra Laboratorio")

# Create another sample design
{:ok, _design2} = Designs.create_design(%{
  name: "Etiqueta Producto",
  description: "Diseño para etiquetas de productos con código de barras",
  width_mm: 70,
  height_mm: 40,
  background_color: "#FFFFFF",
  border_width: 0,
  border_color: "#000000",
  border_radius: 0,
  is_template: true,
  user_id: admin.id,
  elements: [
    %{
      id: Ecto.UUID.generate(),
      type: "text",
      x: 5,
      y: 3,
      width: 60,
      height: 8,
      rotation: 0,
      font_size: 14,
      font_family: "Arial",
      font_weight: "bold",
      text_align: "center",
      color: "#000000",
      binding: "Nombre"
    },
    %{
      id: Ecto.UUID.generate(),
      type: "barcode",
      x: 10,
      y: 14,
      width: 50,
      height: 18,
      rotation: 0,
      barcode_format: "CODE128",
      barcode_show_text: true,
      binding: "Codigo"
    },
    %{
      id: Ecto.UUID.generate(),
      type: "text",
      x: 5,
      y: 34,
      width: 30,
      height: 5,
      rotation: 0,
      font_size: 8,
      font_family: "Arial",
      font_weight: "normal",
      text_align: "left",
      color: "#666666",
      binding: "Precio"
    },
    %{
      id: Ecto.UUID.generate(),
      type: "text",
      x: 40,
      y: 34,
      width: 25,
      height: 5,
      rotation: 0,
      font_size: 8,
      font_family: "Arial",
      font_weight: "normal",
      text_align: "right",
      color: "#666666",
      binding: "Fecha"
    }
  ]
})

IO.puts("Created sample design: Etiqueta Producto")

IO.puts("\nSeeding completed!")
