# Seeds for system templates
# Run with: mix run priv/repo/seeds/templates.exs
#
# 30 system templates across 5 categories:
# - Alimentación (6): product, nutrition, wine, frozen, allergens, bulk
# - Farmacéutica (6): medicine, sample, hospital, pediatric, blood product, supplement
# - Logística (6): shipping, pallet, express, hazmat, cross-dock, warehouse
# - Manufactura (6): industrial part, QC, inventory, kanban, calibration, finished product
# - Retail (6): price tag, textile, jewelry, shelf, promo, electronics
#
# Font size rules applied:
# - Compact labels (≤50×30mm): min 7pt
# - Medium labels (≤100×70mm): min 8pt
# - Large labels (>100mm): min 9pt
#
# Idempotent: deletes existing system templates before inserting.

alias QrLabelSystem.Repo
alias QrLabelSystem.Designs.Design
import Ecto.Query

# Clean existing system templates
Repo.delete_all(from d in Design, where: d.template_source == "system")
IO.puts("Deleted existing system templates.")

# ── Compact element helpers ──────────────────────────────────────────
defmodule SeedEl do
  def id(t, e), do: "el_tpl_#{t}_#{e}"

  def t(id, x, y, w, h, opts \\ []) do
    %{id: id, type: "text", x: x, y: y, width: w, height: h,
      text_content: opts[:t], binding: opts[:b],
      font_size: opts[:s] || 10.0, font_weight: opts[:w] || "normal",
      font_family: "Arial", text_align: opts[:a] || "left",
      color: opts[:c] || "#000000",
      z_index: opts[:z] || 10, name: opts[:n] || "Texto",
      visible: true, locked: false, rotation: 0.0}
  end

  def l(id, x, y, w, opts \\ []) do
    %{id: id, type: "line", x: x, y: y, width: w, height: opts[:h] || 0.3,
      color: opts[:c] || "#CCCCCC",
      z_index: opts[:z] || 5, name: opts[:n] || "Línea",
      visible: true, locked: false, rotation: 0.0}
  end

  def q(id, x, y, size, opts \\ []) do
    %{id: id, type: "qr", x: x, y: y, width: size, height: size,
      binding: opts[:b], qr_error_level: opts[:lvl] || "M",
      color: "#000000",
      z_index: opts[:z] || 8, name: opts[:n] || "QR",
      visible: true, locked: false, rotation: 0.0}
  end

  def bc(id, x, y, w, h, opts \\ []) do
    %{id: id, type: "barcode", x: x, y: y, width: w, height: h,
      binding: opts[:b], barcode_format: opts[:f] || "CODE128",
      barcode_show_text: if(opts[:st] == false, do: false, else: true),
      color: "#000000",
      z_index: opts[:z] || 8, name: opts[:n] || "Código de barras",
      visible: true, locked: false, rotation: 0.0}
  end

  def r(id, x, y, w, h, opts \\ []) do
    %{id: id, type: "rectangle", x: x, y: y, width: w, height: h,
      color: opts[:c] || "#000000",
      background_color: opts[:bg],
      border_width: opts[:bw] || 0.5,
      border_color: opts[:bc] || "#000000",
      border_radius: opts[:br] || 0.0,
      z_index: opts[:z] || 3, name: opts[:n] || "Rectángulo",
      visible: true, locked: false, rotation: 0.0}
  end
end

templates = [
  # ═══════════════════════════════════════════════════════════════════
  # ALIMENTACIÓN (6)
  # ═══════════════════════════════════════════════════════════════════

  # 1. Producto alimentario básico (100×70mm)
  %{
    name: "Producto alimentario",
    description: "Etiqueta estándar con nombre, peso, EAN-13, lote y caducidad",
    width_mm: 100.0, height_mm: 70.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "alimentacion",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(1,1), 5.0, 4.0, 90.0, 8.0, b: "nombre", s: 14.0, w: "bold", a: "center", n: "Nombre producto"),
      SeedEl.l(SeedEl.id(1,2), 5.0, 13.0, 90.0, c: "#000000"),
      SeedEl.t(SeedEl.id(1,3), 5.0, 16.0, 24.0, 5.0, t: "Peso neto:", s: 9.0, c: "#666666", n: "Label peso"),
      SeedEl.t(SeedEl.id(1,4), 30.0, 16.0, 25.0, 5.5, b: "peso_neto", s: 10.0, w: "bold", n: "Peso neto"),
      SeedEl.t(SeedEl.id(1,5), 5.0, 23.0, 14.0, 5.0, t: "Lote:", s: 8.0, c: "#666666", n: "Label lote"),
      SeedEl.t(SeedEl.id(1,6), 20.0, 23.0, 25.0, 5.0, b: "lote", s: 9.0, w: "bold", n: "Lote"),
      SeedEl.t(SeedEl.id(1,7), 52.0, 23.0, 13.0, 5.0, t: "Cad.:", s: 8.0, c: "#666666", n: "Label cad."),
      SeedEl.t(SeedEl.id(1,8), 66.0, 23.0, 29.0, 5.0, b: "fecha_caducidad", s: 9.0, w: "bold", n: "Caducidad"),
      SeedEl.bc(SeedEl.id(1,9), 15.0, 34.0, 70.0, 28.0, b: "ean13", f: "EAN13", n: "EAN-13")
    ]
  },

  # 2. Información nutricional (80×120mm)
  %{
    name: "Información nutricional",
    description: "Tabla de valores nutricionales conforme a normativa UE",
    width_mm: 80.0, height_mm: 120.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "alimentacion",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(2,1), 4.0, 4.0, 72.0, 7.0, t: "INFORMACIÓN NUTRICIONAL", s: 12.0, w: "bold", a: "center", n: "Título"),
      SeedEl.l(SeedEl.id(2,2), 4.0, 12.0, 72.0, h: 0.5, c: "#000000"),
      SeedEl.t(SeedEl.id(2,3), 4.0, 14.0, 72.0, 5.0, t: "Valores medios por 100g", s: 9.0, w: "bold", a: "center", c: "#333333", n: "Subtítulo"),
      SeedEl.l(SeedEl.id(2,4), 4.0, 20.0, 72.0),
      # Valor energético
      SeedEl.t(SeedEl.id(2,5), 4.0, 22.0, 45.0, 5.0, t: "Valor energético", s: 9.0, n: "Label energía"),
      SeedEl.t(SeedEl.id(2,6), 50.0, 22.0, 26.0, 5.0, b: "energia_kcal", s: 9.0, w: "bold", a: "right", n: "Energía"),
      SeedEl.l(SeedEl.id(2,7), 4.0, 28.0, 72.0, c: "#EEEEEE"),
      # Grasas
      SeedEl.t(SeedEl.id(2,8), 4.0, 30.0, 45.0, 5.0, t: "Grasas", s: 9.0, n: "Label grasas"),
      SeedEl.t(SeedEl.id(2,9), 50.0, 30.0, 26.0, 5.0, b: "grasas_g", s: 9.0, w: "bold", a: "right", n: "Grasas"),
      SeedEl.l(SeedEl.id(2,10), 4.0, 36.0, 72.0, c: "#EEEEEE"),
      # Hidratos
      SeedEl.t(SeedEl.id(2,11), 4.0, 38.0, 45.0, 5.0, t: "Hidratos de carbono", s: 9.0, n: "Label hidratos"),
      SeedEl.t(SeedEl.id(2,12), 50.0, 38.0, 26.0, 5.0, b: "hidratos_g", s: 9.0, w: "bold", a: "right", n: "Hidratos"),
      SeedEl.l(SeedEl.id(2,13), 4.0, 44.0, 72.0, c: "#EEEEEE"),
      # Azúcares (indented)
      SeedEl.t(SeedEl.id(2,14), 8.0, 46.0, 41.0, 5.0, t: "  de los cuales azúcares", s: 9.0, c: "#555555", n: "Label azúcares"),
      SeedEl.t(SeedEl.id(2,15), 50.0, 46.0, 26.0, 5.0, b: "azucares_g", s: 9.0, a: "right", c: "#555555", n: "Azúcares"),
      SeedEl.l(SeedEl.id(2,16), 4.0, 52.0, 72.0, c: "#EEEEEE"),
      # Proteínas
      SeedEl.t(SeedEl.id(2,17), 4.0, 54.0, 45.0, 5.0, t: "Proteínas", s: 9.0, n: "Label proteínas"),
      SeedEl.t(SeedEl.id(2,18), 50.0, 54.0, 26.0, 5.0, b: "proteinas_g", s: 9.0, w: "bold", a: "right", n: "Proteínas"),
      SeedEl.l(SeedEl.id(2,19), 4.0, 60.0, 72.0, c: "#EEEEEE"),
      # Sal
      SeedEl.t(SeedEl.id(2,20), 4.0, 62.0, 45.0, 5.0, t: "Sal", s: 9.0, n: "Label sal"),
      SeedEl.t(SeedEl.id(2,21), 50.0, 62.0, 26.0, 5.0, b: "sal_g", s: 9.0, w: "bold", a: "right", n: "Sal"),
      SeedEl.l(SeedEl.id(2,22), 4.0, 68.0, 72.0, c: "#EEEEEE"),
      # Fibra
      SeedEl.t(SeedEl.id(2,23), 4.0, 70.0, 45.0, 5.0, t: "Fibra alimentaria", s: 9.0, n: "Label fibra"),
      SeedEl.t(SeedEl.id(2,24), 50.0, 70.0, 26.0, 5.0, b: "fibra_g", s: 9.0, w: "bold", a: "right", n: "Fibra"),
      SeedEl.l(SeedEl.id(2,25), 4.0, 76.0, 72.0, h: 0.5, c: "#000000"),
      # Alérgenos
      SeedEl.t(SeedEl.id(2,26), 4.0, 79.0, 72.0, 5.0, t: "ALÉRGENOS:", s: 9.0, w: "bold", n: "Label alérgenos"),
      SeedEl.t(SeedEl.id(2,27), 4.0, 85.0, 72.0, 10.0, b: "alergenos", s: 9.0, n: "Alérgenos"),
      SeedEl.bc(SeedEl.id(2,28), 10.0, 98.0, 60.0, 18.0, b: "ean13", f: "EAN13", n: "EAN-13")
    ]
  },

  # 3. Etiqueta de vino (100×130mm)
  %{
    name: "Etiqueta de vino",
    description: "Etiqueta elegante para botellas de vino con denominación de origen",
    width_mm: 100.0, height_mm: 130.0,
    background_color: "#FFFFFF", border_width: 0.5, border_color: "#333333", border_radius: 2.0,
    is_template: true, template_source: "system", template_category: "alimentacion",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(3,1), 5.0, 6.0, 90.0, 10.0, b: "bodega", s: 18.0, w: "bold", a: "center", n: "Bodega"),
      SeedEl.l(SeedEl.id(3,2), 15.0, 18.0, 70.0, h: 0.5, c: "#999999"),
      SeedEl.t(SeedEl.id(3,3), 5.0, 22.0, 90.0, 9.0, b: "nombre_vino", s: 16.0, w: "bold", a: "center", n: "Nombre vino"),
      SeedEl.t(SeedEl.id(3,4), 5.0, 34.0, 90.0, 6.0, b: "denominacion", s: 10.0, a: "center", c: "#555555", n: "D.O."),
      SeedEl.t(SeedEl.id(3,5), 5.0, 44.0, 90.0, 8.0, b: "anada", s: 14.0, w: "bold", a: "center", n: "Añada"),
      SeedEl.l(SeedEl.id(3,6), 20.0, 54.0, 60.0, c: "#CCCCCC"),
      SeedEl.t(SeedEl.id(3,7), 5.0, 58.0, 25.0, 5.5, t: "Variedad:", s: 10.0, c: "#666666", n: "Label variedad"),
      SeedEl.t(SeedEl.id(3,8), 31.0, 58.0, 64.0, 5.5, b: "variedad", s: 10.0, n: "Variedad"),
      SeedEl.t(SeedEl.id(3,9), 5.0, 66.0, 30.0, 5.5, t: "Vol. alcohol:", s: 10.0, c: "#666666", n: "Label alcohol"),
      SeedEl.t(SeedEl.id(3,10), 36.0, 66.0, 25.0, 5.5, b: "alcohol", s: 10.0, w: "bold", n: "Alcohol"),
      SeedEl.t(SeedEl.id(3,11), 5.0, 74.0, 25.0, 5.0, t: "Contenido:", s: 10.0, c: "#666666", n: "Label volumen"),
      SeedEl.t(SeedEl.id(3,12), 31.0, 74.0, 20.0, 5.0, b: "volumen_cl", s: 10.0, n: "Volumen"),
      SeedEl.l(SeedEl.id(3,13), 10.0, 82.0, 80.0, c: "#CCCCCC"),
      SeedEl.t(SeedEl.id(3,14), 5.0, 86.0, 12.0, 5.0, t: "Lote:", s: 9.0, c: "#666666", n: "Label lote"),
      SeedEl.t(SeedEl.id(3,15), 18.0, 86.0, 30.0, 5.0, b: "lote", s: 9.0, n: "Lote"),
      SeedEl.q(SeedEl.id(3,16), 5.0, 95.0, 28.0, b: "url_producto", n: "QR producto"),
      SeedEl.bc(SeedEl.id(3,17), 38.0, 98.0, 57.0, 22.0, b: "ean13", f: "EAN13", n: "EAN-13")
    ]
  },

  # 4. Producto congelado (80×50mm)
  %{
    name: "Producto congelado",
    description: "Etiqueta para alimentos congelados con conservación y caducidad",
    width_mm: 80.0, height_mm: 50.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "alimentacion",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(4,1), 4.0, 3.0, 72.0, 7.0, b: "nombre", s: 12.0, w: "bold", a: "center", n: "Producto"),
      SeedEl.l(SeedEl.id(4,2), 4.0, 11.0, 72.0),
      SeedEl.t(SeedEl.id(4,3), 4.0, 14.0, 15.0, 5.0, t: "Peso:", s: 9.0, c: "#666666", n: "Label peso"),
      SeedEl.t(SeedEl.id(4,4), 20.0, 14.0, 25.0, 5.5, b: "peso_neto", s: 10.0, w: "bold", n: "Peso"),
      SeedEl.t(SeedEl.id(4,5), 4.0, 21.0, 72.0, 4.5, t: "Conservar a -18°C", s: 8.0, w: "bold", c: "#0055AA", n: "Conservación"),
      SeedEl.t(SeedEl.id(4,6), 4.0, 27.0, 13.0, 5.0, t: "Cad.:", s: 9.0, c: "#666666", n: "Label cad."),
      SeedEl.t(SeedEl.id(4,7), 18.0, 27.0, 30.0, 5.0, b: "fecha_caducidad", s: 9.0, w: "bold", n: "Caducidad"),
      SeedEl.bc(SeedEl.id(4,8), 5.0, 34.0, 70.0, 13.0, b: "codigo", f: "CODE128", n: "Código")
    ]
  },

  # 5. Etiqueta alérgenos (60×40mm)
  %{
    name: "Etiqueta alérgenos",
    description: "Etiqueta de información de alérgenos para productos alimentarios",
    width_mm: 60.0, height_mm: 40.0,
    background_color: "#FFFFFF", border_width: 0.5, border_color: "#CC0000", border_radius: 1.0,
    is_template: true, template_source: "system", template_category: "alimentacion",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(5,1), 3.0, 3.0, 54.0, 6.0, t: "CONTIENE", s: 10.0, w: "bold", a: "center", c: "#CC0000", n: "Título"),
      SeedEl.l(SeedEl.id(5,2), 3.0, 10.0, 54.0, c: "#CC0000"),
      SeedEl.t(SeedEl.id(5,3), 3.0, 12.0, 54.0, 10.0, b: "alergenos", s: 9.0, w: "bold", a: "center", n: "Alérgenos"),
      SeedEl.l(SeedEl.id(5,4), 3.0, 23.0, 54.0),
      SeedEl.t(SeedEl.id(5,5), 3.0, 25.0, 54.0, 4.5, t: "Puede contener trazas de:", s: 8.0, c: "#666666", n: "Label trazas"),
      SeedEl.t(SeedEl.id(5,6), 3.0, 30.0, 54.0, 7.0, b: "trazas", s: 8.0, n: "Trazas")
    ]
  },

  # 6. Producto a granel (50×30mm)
  %{
    name: "Producto a granel",
    description: "Etiqueta compacta para productos vendidos por peso",
    width_mm: 50.0, height_mm: 30.0,
    background_color: "#FFFFFF", border_width: 0.2, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "alimentacion",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(6,1), 3.0, 2.0, 44.0, 5.0, b: "nombre", s: 9.0, w: "bold", a: "center", n: "Producto"),
      SeedEl.t(SeedEl.id(6,2), 3.0, 8.0, 44.0, 6.0, b: "precio_kg", s: 11.0, w: "bold", a: "center", n: "Precio/kg"),
      SeedEl.t(SeedEl.id(6,3), 3.0, 15.0, 18.0, 4.0, t: "Código:", s: 7.0, c: "#666666", n: "Label código"),
      SeedEl.t(SeedEl.id(6,4), 21.0, 15.0, 26.0, 4.0, b: "codigo", s: 7.0, n: "Código"),
      SeedEl.bc(SeedEl.id(6,5), 5.0, 20.0, 40.0, 8.0, b: "codigo", f: "CODE128", st: false, n: "Código barras")
    ]
  },

  # ═══════════════════════════════════════════════════════════════════
  # FARMACÉUTICA (6)
  # ═══════════════════════════════════════════════════════════════════

  # 7. Medicamento genérico (80×50mm)
  %{
    name: "Medicamento genérico",
    description: "Etiqueta para medicamentos con principio activo, dosis, lote y caducidad",
    width_mm: 80.0, height_mm: 50.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "farmaceutica",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(7,1), 4.0, 3.0, 72.0, 7.0, b: "nombre_medicamento", s: 12.0, w: "bold", a: "center", n: "Medicamento"),
      SeedEl.t(SeedEl.id(7,2), 4.0, 11.0, 72.0, 5.0, b: "principio_activo", s: 9.0, a: "center", c: "#555555", n: "Principio activo"),
      SeedEl.l(SeedEl.id(7,3), 4.0, 17.0, 72.0),
      SeedEl.t(SeedEl.id(7,4), 4.0, 19.0, 18.0, 5.0, t: "Dosis:", s: 9.0, c: "#666666", n: "Label dosis"),
      SeedEl.t(SeedEl.id(7,5), 23.0, 19.0, 30.0, 5.5, b: "dosis", s: 10.0, w: "bold", n: "Dosis"),
      SeedEl.t(SeedEl.id(7,6), 4.0, 26.0, 14.0, 4.5, t: "Lote:", s: 8.0, c: "#666666", n: "Label lote"),
      SeedEl.t(SeedEl.id(7,7), 19.0, 26.0, 20.0, 4.5, b: "lote", s: 8.0, w: "bold", n: "Lote"),
      SeedEl.t(SeedEl.id(7,8), 42.0, 26.0, 13.0, 4.5, t: "Cad.:", s: 8.0, c: "#666666", n: "Label cad."),
      SeedEl.t(SeedEl.id(7,9), 56.0, 26.0, 20.0, 4.5, b: "fecha_caducidad", s: 8.0, w: "bold", n: "Caducidad"),
      SeedEl.bc(SeedEl.id(7,10), 5.0, 33.0, 14.0, 14.0, b: "codigo_nacional", f: "DATAMATRIX", n: "DataMatrix")
    ]
  },

  # 8. Muestra médica (60×30mm)
  %{
    name: "Muestra médica",
    description: "Etiqueta compacta para muestras médicas gratuitas",
    width_mm: 60.0, height_mm: 30.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#0055AA", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "farmaceutica",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(8,1), 3.0, 2.0, 54.0, 4.5, t: "MUESTRA MÉDICA", s: 8.0, w: "bold", a: "center", c: "#0055AA", n: "Título"),
      SeedEl.l(SeedEl.id(8,2), 3.0, 7.0, 54.0, c: "#0055AA"),
      SeedEl.t(SeedEl.id(8,3), 3.0, 9.0, 54.0, 5.0, b: "nombre_medicamento", s: 9.0, w: "bold", a: "center", n: "Medicamento"),
      SeedEl.t(SeedEl.id(8,4), 3.0, 15.0, 13.0, 4.0, t: "Lote:", s: 7.0, c: "#666666", n: "Label lote"),
      SeedEl.t(SeedEl.id(8,5), 17.0, 15.0, 15.0, 4.0, b: "lote", s: 7.0, w: "bold", n: "Lote"),
      SeedEl.t(SeedEl.id(8,6), 34.0, 15.0, 10.0, 4.0, t: "Cad.:", s: 7.0, c: "#666666", n: "Label cad."),
      SeedEl.t(SeedEl.id(8,7), 45.0, 15.0, 12.0, 4.0, b: "fecha_caducidad", s: 7.0, w: "bold", n: "Caducidad"),
      SeedEl.bc(SeedEl.id(8,8), 5.0, 20.0, 50.0, 8.0, b: "codigo", f: "CODE128", st: false, n: "Código")
    ]
  },

  # 9. Producto hospitalario (100×50mm)
  %{
    name: "Producto hospitalario",
    description: "Etiqueta para productos de uso hospitalario con trazabilidad QR",
    width_mm: 100.0, height_mm: 50.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "farmaceutica",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(9,1), 4.0, 3.0, 92.0, 7.0, b: "nombre_producto", s: 12.0, w: "bold", n: "Producto"),
      SeedEl.t(SeedEl.id(9,2), 4.0, 11.0, 50.0, 5.5, b: "concentracion", s: 10.0, w: "bold", c: "#0055AA", n: "Concentración"),
      SeedEl.l(SeedEl.id(9,3), 4.0, 18.0, 92.0),
      SeedEl.t(SeedEl.id(9,4), 4.0, 20.0, 14.0, 4.5, t: "Lote:", s: 8.0, c: "#666666", n: "Label lote"),
      SeedEl.t(SeedEl.id(9,5), 19.0, 20.0, 25.0, 4.5, b: "lote", s: 8.0, w: "bold", n: "Lote"),
      SeedEl.t(SeedEl.id(9,6), 48.0, 20.0, 13.0, 4.5, t: "Cad.:", s: 8.0, c: "#666666", n: "Label cad."),
      SeedEl.t(SeedEl.id(9,7), 62.0, 20.0, 34.0, 4.5, b: "fecha_caducidad", s: 8.0, w: "bold", n: "Caducidad"),
      SeedEl.q(SeedEl.id(9,8), 4.0, 27.0, 20.0, b: "codigo_trazabilidad", n: "QR trazabilidad"),
      SeedEl.bc(SeedEl.id(9,9), 28.0, 30.0, 15.0, 15.0, b: "codigo_nacional", f: "DATAMATRIX", n: "DataMatrix")
    ]
  },

  # 10. Dosificación pediátrica (70×40mm)
  %{
    name: "Dosificación pediátrica",
    description: "Etiqueta para dosificación pediátrica con peso del paciente y frecuencia",
    width_mm: 70.0, height_mm: 40.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#009900", border_radius: 1.0,
    is_template: true, template_source: "system", template_category: "farmaceutica",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(10,1), 3.0, 2.0, 64.0, 6.0, b: "nombre_medicamento", s: 10.0, w: "bold", a: "center", n: "Medicamento"),
      SeedEl.l(SeedEl.id(10,2), 3.0, 9.0, 64.0, c: "#009900"),
      SeedEl.t(SeedEl.id(10,3), 3.0, 11.0, 15.0, 5.0, t: "Dosis:", s: 9.0, c: "#666666", n: "Label dosis"),
      SeedEl.t(SeedEl.id(10,4), 19.0, 11.0, 48.0, 5.5, b: "dosis", s: 10.0, w: "bold", n: "Dosis"),
      SeedEl.t(SeedEl.id(10,5), 3.0, 18.0, 27.0, 4.5, t: "Peso paciente:", s: 8.0, c: "#666666", n: "Label peso"),
      SeedEl.t(SeedEl.id(10,6), 31.0, 18.0, 20.0, 4.5, b: "peso_paciente", s: 8.0, w: "bold", n: "Peso paciente"),
      SeedEl.t(SeedEl.id(10,7), 3.0, 24.0, 24.0, 4.5, t: "Frecuencia:", s: 8.0, c: "#666666", n: "Label frecuencia"),
      SeedEl.t(SeedEl.id(10,8), 28.0, 24.0, 39.0, 4.5, b: "frecuencia", s: 8.0, w: "bold", n: "Frecuencia"),
      SeedEl.bc(SeedEl.id(10,9), 5.0, 30.0, 60.0, 8.0, b: "codigo", f: "CODE128", st: false, n: "Código")
    ]
  },

  # 11. Hemoderivado (80×60mm)
  %{
    name: "Hemoderivado",
    description: "Etiqueta para hemoderivados con grupo sanguíneo, donante y trazabilidad",
    width_mm: 80.0, height_mm: 60.0,
    background_color: "#FFFFFF", border_width: 0.5, border_color: "#CC0000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "farmaceutica",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(11,1), 4.0, 3.0, 72.0, 5.5, t: "HEMODERIVADO", s: 10.0, w: "bold", a: "center", c: "#CC0000", n: "Título"),
      SeedEl.l(SeedEl.id(11,2), 4.0, 9.0, 72.0, c: "#CC0000"),
      SeedEl.t(SeedEl.id(11,3), 4.0, 11.0, 72.0, 7.0, b: "componente", s: 12.0, w: "bold", a: "center", n: "Componente"),
      SeedEl.t(SeedEl.id(11,4), 4.0, 20.0, 16.0, 5.5, t: "Grupo:", s: 9.0, c: "#666666", n: "Label grupo"),
      SeedEl.t(SeedEl.id(11,5), 21.0, 20.0, 20.0, 6.0, b: "grupo_sanguineo", s: 11.0, w: "bold", c: "#CC0000", n: "Grupo sanguíneo"),
      SeedEl.t(SeedEl.id(11,6), 4.0, 28.0, 20.0, 4.5, t: "Donante:", s: 8.0, c: "#666666", n: "Label donante"),
      SeedEl.t(SeedEl.id(11,7), 25.0, 28.0, 30.0, 4.5, b: "id_donante", s: 8.0, w: "bold", n: "Donante"),
      SeedEl.t(SeedEl.id(11,8), 4.0, 34.0, 24.0, 4.5, t: "Extracción:", s: 8.0, c: "#666666", n: "Label extracción"),
      SeedEl.t(SeedEl.id(11,9), 29.0, 34.0, 25.0, 4.5, b: "fecha_extraccion", s: 8.0, n: "Extracción"),
      SeedEl.t(SeedEl.id(11,10), 4.0, 40.0, 13.0, 5.0, t: "Cad.:", s: 9.0, c: "#666666", n: "Label cad."),
      SeedEl.t(SeedEl.id(11,11), 18.0, 40.0, 25.0, 5.0, b: "fecha_caducidad", s: 9.0, w: "bold", n: "Caducidad"),
      SeedEl.bc(SeedEl.id(11,12), 5.0, 47.0, 70.0, 10.0, b: "codigo_donacion", f: "CODE128", st: false, n: "Código donación")
    ]
  },

  # 12. Suplemento alimenticio (60×40mm)
  %{
    name: "Suplemento alimenticio",
    description: "Etiqueta para suplementos alimenticios con contenido y dosis diaria",
    width_mm: 60.0, height_mm: 40.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "farmaceutica",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(12,1), 3.0, 2.0, 54.0, 6.0, b: "nombre", s: 10.0, w: "bold", a: "center", n: "Nombre"),
      SeedEl.l(SeedEl.id(12,2), 3.0, 9.0, 54.0),
      SeedEl.t(SeedEl.id(12,3), 3.0, 11.0, 24.0, 4.5, t: "Contenido:", s: 8.0, c: "#666666", n: "Label contenido"),
      SeedEl.t(SeedEl.id(12,4), 28.0, 11.0, 29.0, 4.5, b: "contenido", s: 8.0, w: "bold", n: "Contenido"),
      SeedEl.t(SeedEl.id(12,5), 3.0, 17.0, 24.0, 4.5, t: "Dosis diaria:", s: 8.0, c: "#666666", n: "Label dosis"),
      SeedEl.t(SeedEl.id(12,6), 28.0, 17.0, 29.0, 4.5, b: "dosis_diaria", s: 8.0, w: "bold", n: "Dosis diaria"),
      SeedEl.bc(SeedEl.id(12,7), 5.0, 24.0, 50.0, 13.0, b: "ean13", f: "EAN13", n: "EAN-13")
    ]
  },

  # ═══════════════════════════════════════════════════════════════════
  # LOGÍSTICA (6)
  # ═══════════════════════════════════════════════════════════════════

  # 13. Etiqueta de envío (100×70mm)
  %{
    name: "Etiqueta de envío",
    description: "Etiqueta de envío con destinatario, dirección y código de seguimiento",
    width_mm: 100.0, height_mm: 70.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "logistica",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(13,1), 4.0, 3.0, 92.0, 5.0, t: "DESTINATARIO", s: 9.0, w: "bold", c: "#666666", n: "Label dest."),
      SeedEl.t(SeedEl.id(13,2), 4.0, 9.0, 92.0, 7.0, b: "nombre_destinatario", s: 12.0, w: "bold", n: "Destinatario"),
      SeedEl.t(SeedEl.id(13,3), 4.0, 17.0, 92.0, 5.5, b: "direccion", s: 10.0, n: "Dirección"),
      SeedEl.t(SeedEl.id(13,4), 4.0, 24.0, 50.0, 5.5, b: "ciudad_cp", s: 10.0, w: "bold", n: "Ciudad/CP"),
      SeedEl.l(SeedEl.id(13,5), 4.0, 31.0, 92.0),
      SeedEl.t(SeedEl.id(13,6), 4.0, 33.0, 25.0, 4.5, t: "Remitente:", s: 8.0, c: "#666666", n: "Label remitente"),
      SeedEl.t(SeedEl.id(13,7), 30.0, 33.0, 66.0, 4.5, b: "remitente", s: 8.0, n: "Remitente"),
      SeedEl.t(SeedEl.id(13,8), 4.0, 39.0, 16.0, 4.5, t: "Ref.:", s: 8.0, c: "#666666", n: "Label ref."),
      SeedEl.t(SeedEl.id(13,9), 21.0, 39.0, 30.0, 4.5, b: "referencia", s: 8.0, w: "bold", n: "Referencia"),
      SeedEl.q(SeedEl.id(13,10), 4.0, 46.0, 20.0, b: "tracking", n: "QR tracking"),
      SeedEl.bc(SeedEl.id(13,11), 28.0, 48.0, 68.0, 16.0, b: "tracking", f: "CODE128", n: "Código tracking")
    ]
  },

  # 14. Pallet industrial (148×210mm) - A5
  %{
    name: "Pallet industrial",
    description: "Etiqueta A5 para pallets con información completa de envío y trazabilidad",
    width_mm: 148.0, height_mm: 210.0,
    background_color: "#FFFFFF", border_width: 0.5, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "logistica",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(14,1), 8.0, 8.0, 132.0, 10.0, t: "PALLET", s: 18.0, w: "bold", a: "center", n: "Título"),
      SeedEl.l(SeedEl.id(14,2), 8.0, 20.0, 132.0, h: 0.5, c: "#000000"),
      SeedEl.t(SeedEl.id(14,3), 8.0, 25.0, 132.0, 8.0, b: "nombre_producto", s: 14.0, w: "bold", n: "Producto"),
      SeedEl.t(SeedEl.id(14,4), 8.0, 36.0, 30.0, 6.0, t: "Cantidad:", s: 10.0, c: "#666666", n: "Label cantidad"),
      SeedEl.t(SeedEl.id(14,5), 40.0, 36.0, 50.0, 7.0, b: "cantidad", s: 12.0, w: "bold", n: "Cantidad"),
      SeedEl.t(SeedEl.id(14,6), 8.0, 46.0, 20.0, 5.5, t: "Lote:", s: 10.0, c: "#666666", n: "Label lote"),
      SeedEl.t(SeedEl.id(14,7), 30.0, 46.0, 50.0, 5.5, b: "lote", s: 10.0, w: "bold", n: "Lote"),
      SeedEl.t(SeedEl.id(14,8), 8.0, 55.0, 30.0, 5.5, t: "Peso bruto:", s: 10.0, c: "#666666", n: "Label peso"),
      SeedEl.t(SeedEl.id(14,9), 40.0, 55.0, 40.0, 5.5, b: "peso_bruto", s: 10.0, w: "bold", n: "Peso bruto"),
      SeedEl.l(SeedEl.id(14,10), 8.0, 63.0, 132.0),
      SeedEl.t(SeedEl.id(14,11), 8.0, 67.0, 22.0, 5.5, t: "Origen:", s: 10.0, c: "#666666", n: "Label origen"),
      SeedEl.t(SeedEl.id(14,12), 32.0, 67.0, 108.0, 5.5, b: "origen", s: 10.0, n: "Origen"),
      SeedEl.t(SeedEl.id(14,13), 8.0, 76.0, 25.0, 6.0, t: "Destino:", s: 10.0, c: "#666666", n: "Label destino"),
      SeedEl.t(SeedEl.id(14,14), 35.0, 76.0, 105.0, 6.0, b: "destino", s: 10.0, w: "bold", n: "Destino"),
      SeedEl.l(SeedEl.id(14,15), 8.0, 85.0, 132.0),
      SeedEl.t(SeedEl.id(14,16), 8.0, 90.0, 25.0, 5.5, t: "Fecha:", s: 10.0, c: "#666666", n: "Label fecha"),
      SeedEl.t(SeedEl.id(14,17), 35.0, 90.0, 40.0, 5.5, b: "fecha_envio", s: 10.0, n: "Fecha envío"),
      SeedEl.q(SeedEl.id(14,18), 8.0, 105.0, 60.0, b: "sscc", n: "QR SSCC"),
      SeedEl.bc(SeedEl.id(14,19), 8.0, 172.0, 132.0, 30.0, b: "sscc", f: "GS1_128", n: "GS1-128 SSCC")
    ]
  },

  # 15. Paquetería express (100×150mm)
  %{
    name: "Paquetería express",
    description: "Etiqueta para envíos urgentes con tracking y datos del destinatario",
    width_mm: 100.0, height_mm: 150.0,
    background_color: "#FFFFFF", border_width: 0.5, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "logistica",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(15,1), 5.0, 5.0, 90.0, 8.0, t: "ENVÍO EXPRESS", s: 14.0, w: "bold", a: "center", n: "Título"),
      SeedEl.l(SeedEl.id(15,2), 5.0, 15.0, 90.0, h: 0.5, c: "#000000"),
      SeedEl.t(SeedEl.id(15,3), 5.0, 19.0, 25.0, 5.0, t: "Tracking:", s: 9.0, c: "#666666", n: "Label tracking"),
      SeedEl.t(SeedEl.id(15,4), 31.0, 19.0, 64.0, 7.0, b: "tracking", s: 12.0, w: "bold", n: "Tracking"),
      SeedEl.l(SeedEl.id(15,5), 5.0, 28.0, 90.0),
      SeedEl.t(SeedEl.id(15,6), 5.0, 31.0, 90.0, 7.0, b: "nombre_destinatario", s: 12.0, w: "bold", n: "Destinatario"),
      SeedEl.t(SeedEl.id(15,7), 5.0, 39.0, 90.0, 5.5, b: "direccion", s: 10.0, n: "Dirección"),
      SeedEl.t(SeedEl.id(15,8), 5.0, 46.0, 90.0, 5.5, b: "ciudad_cp", s: 10.0, w: "bold", n: "Ciudad/CP"),
      SeedEl.t(SeedEl.id(15,9), 5.0, 53.0, 25.0, 5.5, t: "Teléfono:", s: 10.0, c: "#666666", n: "Label teléfono"),
      SeedEl.t(SeedEl.id(15,10), 31.0, 53.0, 64.0, 5.5, b: "telefono", s: 10.0, n: "Teléfono"),
      SeedEl.l(SeedEl.id(15,11), 5.0, 61.0, 90.0),
      SeedEl.t(SeedEl.id(15,12), 5.0, 64.0, 16.0, 5.0, t: "Ref.:", s: 9.0, c: "#666666", n: "Label ref."),
      SeedEl.t(SeedEl.id(15,13), 22.0, 64.0, 73.0, 5.0, b: "referencia", s: 9.0, n: "Referencia"),
      SeedEl.t(SeedEl.id(15,14), 5.0, 71.0, 18.0, 5.0, t: "Bultos:", s: 9.0, c: "#666666", n: "Label bultos"),
      SeedEl.t(SeedEl.id(15,15), 24.0, 71.0, 20.0, 5.0, b: "bultos", s: 9.0, w: "bold", n: "Bultos"),
      SeedEl.t(SeedEl.id(15,16), 50.0, 71.0, 16.0, 5.0, t: "Peso:", s: 9.0, c: "#666666", n: "Label peso"),
      SeedEl.t(SeedEl.id(15,17), 67.0, 71.0, 28.0, 5.0, b: "peso_kg", s: 9.0, w: "bold", n: "Peso"),
      SeedEl.q(SeedEl.id(15,18), 5.0, 80.0, 30.0, b: "tracking", n: "QR tracking"),
      SeedEl.bc(SeedEl.id(15,19), 5.0, 115.0, 90.0, 28.0, b: "tracking", f: "GS1_128", n: "GS1-128 tracking")
    ]
  },

  # 16. ADR mercancías peligrosas (100×100mm)
  %{
    name: "ADR mercancías peligrosas",
    description: "Etiqueta de transporte de mercancías peligrosas con número ONU y clase ADR",
    width_mm: 100.0, height_mm: 100.0,
    background_color: "#FFFFFF", border_width: 1.0, border_color: "#FF6600", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "logistica",
    label_type: "multiple",
    elements: [
      SeedEl.r(SeedEl.id(16,1), 3.0, 3.0, 94.0, 12.0, bg: "#FF6600", bw: 0.0, n: "Fondo título"),
      SeedEl.t(SeedEl.id(16,2), 5.0, 4.0, 90.0, 9.0, t: "MERCANCÍA PELIGROSA", s: 12.0, w: "bold", a: "center", c: "#FFFFFF", z: 12, n: "Título"),
      SeedEl.l(SeedEl.id(16,3), 5.0, 18.0, 90.0, h: 0.5, c: "#FF6600"),
      SeedEl.t(SeedEl.id(16,4), 5.0, 22.0, 22.0, 5.5, t: "N° ONU:", s: 10.0, c: "#666666", n: "Label ONU"),
      SeedEl.t(SeedEl.id(16,5), 28.0, 22.0, 67.0, 8.0, b: "numero_onu", s: 14.0, w: "bold", n: "N° ONU"),
      SeedEl.t(SeedEl.id(16,6), 5.0, 33.0, 90.0, 6.0, b: "nombre_producto", s: 10.0, w: "bold", n: "Producto"),
      SeedEl.l(SeedEl.id(16,7), 5.0, 41.0, 90.0),
      SeedEl.t(SeedEl.id(16,8), 5.0, 44.0, 25.0, 5.5, t: "Clase ADR:", s: 10.0, c: "#666666", n: "Label clase"),
      SeedEl.t(SeedEl.id(16,9), 31.0, 44.0, 30.0, 7.0, b: "clase_adr", s: 12.0, w: "bold", c: "#FF6600", n: "Clase ADR"),
      SeedEl.t(SeedEl.id(16,10), 5.0, 54.0, 15.0, 5.0, t: "Peso:", s: 9.0, c: "#666666", n: "Label peso"),
      SeedEl.t(SeedEl.id(16,11), 21.0, 54.0, 25.0, 5.0, b: "peso_kg", s: 9.0, w: "bold", n: "Peso"),
      SeedEl.t(SeedEl.id(16,12), 50.0, 54.0, 18.0, 5.0, t: "Bultos:", s: 9.0, c: "#666666", n: "Label bultos"),
      SeedEl.t(SeedEl.id(16,13), 69.0, 54.0, 26.0, 5.0, b: "bultos", s: 9.0, w: "bold", n: "Bultos"),
      SeedEl.t(SeedEl.id(16,14), 5.0, 62.0, 25.0, 5.0, t: "Expedidor:", s: 9.0, c: "#666666", n: "Label expedidor"),
      SeedEl.t(SeedEl.id(16,15), 31.0, 62.0, 64.0, 5.0, b: "expedidor", s: 9.0, n: "Expedidor"),
      SeedEl.bc(SeedEl.id(16,16), 10.0, 72.0, 80.0, 22.0, b: "codigo_envio", f: "CODE128", n: "Código envío")
    ]
  },

  # 17. Cross-docking (100×60mm)
  %{
    name: "Cross-docking",
    description: "Etiqueta para operaciones de cross-docking con origen, destino y prioridad",
    width_mm: 100.0, height_mm: 60.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "logistica",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(17,1), 4.0, 3.0, 92.0, 5.5, t: "CROSS-DOCK", s: 10.0, w: "bold", a: "center", n: "Título"),
      SeedEl.l(SeedEl.id(17,2), 4.0, 10.0, 92.0),
      SeedEl.t(SeedEl.id(17,3), 4.0, 12.0, 20.0, 5.5, t: "Origen:", s: 9.0, c: "#666666", n: "Label origen"),
      SeedEl.t(SeedEl.id(17,4), 25.0, 12.0, 25.0, 7.0, b: "origen", s: 12.0, w: "bold", n: "Origen"),
      SeedEl.t(SeedEl.id(17,5), 55.0, 14.0, 10.0, 5.0, t: "→", s: 14.0, a: "center", c: "#999999", n: "Flecha"),
      SeedEl.t(SeedEl.id(17,6), 68.0, 12.0, 28.0, 7.0, b: "destino", s: 12.0, w: "bold", n: "Destino"),
      SeedEl.t(SeedEl.id(17,7), 4.0, 22.0, 20.0, 5.0, t: "Pedido:", s: 9.0, c: "#666666", n: "Label pedido"),
      SeedEl.t(SeedEl.id(17,8), 25.0, 22.0, 30.0, 5.0, b: "num_pedido", s: 9.0, w: "bold", n: "Pedido"),
      SeedEl.t(SeedEl.id(17,9), 58.0, 22.0, 18.0, 5.0, t: "Bultos:", s: 9.0, c: "#666666", n: "Label bultos"),
      SeedEl.t(SeedEl.id(17,10), 77.0, 22.0, 19.0, 5.0, b: "bultos", s: 9.0, w: "bold", n: "Bultos"),
      SeedEl.t(SeedEl.id(17,11), 4.0, 29.0, 24.0, 5.5, t: "Prioridad:", s: 9.0, c: "#666666", n: "Label prioridad"),
      SeedEl.t(SeedEl.id(17,12), 29.0, 29.0, 30.0, 5.5, b: "prioridad", s: 10.0, w: "bold", n: "Prioridad"),
      SeedEl.bc(SeedEl.id(17,13), 5.0, 37.0, 90.0, 18.0, b: "codigo_pedido", f: "CODE128", n: "Código pedido")
    ]
  },

  # 18. Almacén ubicación (60×40mm)
  %{
    name: "Almacén ubicación",
    description: "Etiqueta de ubicación de almacén con zona, pasillo y código de barras",
    width_mm: 60.0, height_mm: 40.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "logistica",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(18,1), 3.0, 2.0, 54.0, 7.0, b: "zona", s: 12.0, w: "bold", a: "center", n: "Zona"),
      SeedEl.t(SeedEl.id(18,2), 3.0, 10.0, 54.0, 8.0, b: "ubicacion", s: 14.0, w: "bold", a: "center", n: "Ubicación"),
      SeedEl.l(SeedEl.id(18,3), 3.0, 19.0, 54.0),
      SeedEl.t(SeedEl.id(18,4), 3.0, 21.0, 18.0, 4.5, t: "Pasillo:", s: 8.0, c: "#666666", n: "Label pasillo"),
      SeedEl.t(SeedEl.id(18,5), 22.0, 21.0, 35.0, 4.5, b: "pasillo", s: 8.0, w: "bold", n: "Pasillo"),
      SeedEl.bc(SeedEl.id(18,6), 5.0, 27.0, 50.0, 10.0, b: "codigo_ubicacion", f: "CODE128", st: false, n: "Código ubicación")
    ]
  },

  # ═══════════════════════════════════════════════════════════════════
  # MANUFACTURA (6)
  # ═══════════════════════════════════════════════════════════════════

  # 19. Pieza industrial (80×40mm)
  %{
    name: "Pieza industrial",
    description: "Etiqueta de identificación de pieza con número de parte, lote y fecha",
    width_mm: 80.0, height_mm: 40.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "manufactura",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(19,1), 4.0, 2.0, 72.0, 7.0, b: "num_parte", s: 12.0, w: "bold", n: "N° parte"),
      SeedEl.t(SeedEl.id(19,2), 4.0, 10.0, 72.0, 5.0, b: "descripcion", s: 9.0, c: "#555555", n: "Descripción"),
      SeedEl.l(SeedEl.id(19,3), 4.0, 16.0, 72.0),
      SeedEl.t(SeedEl.id(19,4), 4.0, 18.0, 14.0, 4.5, t: "Lote:", s: 8.0, c: "#666666", n: "Label lote"),
      SeedEl.t(SeedEl.id(19,5), 19.0, 18.0, 25.0, 4.5, b: "lote", s: 8.0, w: "bold", n: "Lote"),
      SeedEl.t(SeedEl.id(19,6), 48.0, 18.0, 14.0, 4.5, t: "Fecha:", s: 8.0, c: "#666666", n: "Label fecha"),
      SeedEl.t(SeedEl.id(19,7), 63.0, 18.0, 13.0, 4.5, b: "fecha", s: 8.0, n: "Fecha"),
      SeedEl.bc(SeedEl.id(19,8), 5.0, 25.0, 70.0, 12.0, b: "num_parte", f: "CODE128", n: "Código parte")
    ]
  },

  # 20. Control de calidad (100×60mm)
  %{
    name: "Control de calidad",
    description: "Etiqueta de control de calidad con resultado de inspección y trazabilidad",
    width_mm: 100.0, height_mm: 60.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "manufactura",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(20,1), 4.0, 3.0, 92.0, 5.5, t: "CONTROL DE CALIDAD", s: 10.0, w: "bold", a: "center", n: "Título"),
      SeedEl.l(SeedEl.id(20,2), 4.0, 10.0, 92.0),
      SeedEl.t(SeedEl.id(20,3), 4.0, 12.0, 92.0, 6.0, b: "nombre_producto", s: 11.0, w: "bold", n: "Producto"),
      SeedEl.t(SeedEl.id(20,4), 4.0, 20.0, 24.0, 5.0, t: "Inspector:", s: 9.0, c: "#666666", n: "Label inspector"),
      SeedEl.t(SeedEl.id(20,5), 29.0, 20.0, 30.0, 5.0, b: "inspector", s: 9.0, n: "Inspector"),
      SeedEl.t(SeedEl.id(20,6), 62.0, 20.0, 24.0, 5.0, t: "Resultado:", s: 9.0, c: "#666666", n: "Label resultado"),
      SeedEl.t(SeedEl.id(20,7), 4.0, 27.0, 55.0, 6.0, b: "resultado", s: 10.0, w: "bold", n: "Resultado"),
      SeedEl.t(SeedEl.id(20,8), 62.0, 27.0, 14.0, 4.5, t: "Fecha:", s: 8.0, c: "#666666", n: "Label fecha"),
      SeedEl.t(SeedEl.id(20,9), 77.0, 27.0, 19.0, 4.5, b: "fecha_inspeccion", s: 8.0, n: "Fecha"),
      SeedEl.t(SeedEl.id(20,10), 4.0, 34.0, 14.0, 4.5, t: "Lote:", s: 8.0, c: "#666666", n: "Label lote"),
      SeedEl.t(SeedEl.id(20,11), 19.0, 34.0, 25.0, 4.5, b: "lote", s: 8.0, w: "bold", n: "Lote"),
      SeedEl.q(SeedEl.id(20,12), 4.0, 41.0, 16.0, b: "codigo_inspeccion", n: "QR inspección"),
      SeedEl.bc(SeedEl.id(20,13), 24.0, 43.0, 72.0, 13.0, b: "num_parte", f: "CODE128", n: "Código parte")
    ]
  },

  # 21. Inventario almacén (60×40mm)
  %{
    name: "Inventario almacén",
    description: "Etiqueta de inventario con SKU, ubicación y stock",
    width_mm: 60.0, height_mm: 40.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "manufactura",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(21,1), 3.0, 2.0, 54.0, 7.0, b: "sku", s: 12.0, w: "bold", a: "center", n: "SKU"),
      SeedEl.t(SeedEl.id(21,2), 3.0, 10.0, 54.0, 4.5, b: "descripcion", s: 8.0, c: "#555555", a: "center", n: "Descripción"),
      SeedEl.l(SeedEl.id(21,3), 3.0, 16.0, 54.0),
      SeedEl.t(SeedEl.id(21,4), 3.0, 18.0, 24.0, 4.5, t: "Ubicación:", s: 8.0, c: "#666666", n: "Label ubicación"),
      SeedEl.t(SeedEl.id(21,5), 28.0, 18.0, 29.0, 4.5, b: "ubicacion", s: 8.0, w: "bold", n: "Ubicación"),
      SeedEl.t(SeedEl.id(21,6), 3.0, 24.0, 16.0, 5.5, t: "Stock:", s: 9.0, c: "#666666", n: "Label stock"),
      SeedEl.t(SeedEl.id(21,7), 20.0, 24.0, 20.0, 6.0, b: "stock", s: 10.0, w: "bold", n: "Stock"),
      SeedEl.bc(SeedEl.id(21,8), 5.0, 31.0, 50.0, 7.0, b: "sku", f: "CODE128", st: false, n: "Código SKU")
    ]
  },

  # 22. Kanban producción (100×60mm)
  %{
    name: "Kanban producción",
    description: "Tarjeta Kanban para producción con origen, destino y cantidad",
    width_mm: 100.0, height_mm: 60.0,
    background_color: "#FFFFFF", border_width: 0.5, border_color: "#0066CC", border_radius: 1.0,
    is_template: true, template_source: "system", template_category: "manufactura",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(22,1), 4.0, 3.0, 92.0, 5.5, t: "KANBAN", s: 10.0, w: "bold", a: "center", c: "#0066CC", n: "Título"),
      SeedEl.l(SeedEl.id(22,2), 4.0, 10.0, 92.0, c: "#0066CC"),
      SeedEl.t(SeedEl.id(22,3), 4.0, 12.0, 92.0, 7.0, b: "num_parte", s: 12.0, w: "bold", n: "N° parte"),
      SeedEl.t(SeedEl.id(22,4), 4.0, 20.0, 92.0, 5.0, b: "descripcion", s: 9.0, c: "#555555", n: "Descripción"),
      SeedEl.t(SeedEl.id(22,5), 4.0, 27.0, 24.0, 5.5, t: "Cantidad:", s: 9.0, c: "#666666", n: "Label cantidad"),
      SeedEl.t(SeedEl.id(22,6), 29.0, 27.0, 30.0, 6.0, b: "cantidad", s: 10.0, w: "bold", n: "Cantidad"),
      SeedEl.t(SeedEl.id(22,7), 4.0, 35.0, 18.0, 4.5, t: "Origen:", s: 8.0, c: "#666666", n: "Label origen"),
      SeedEl.t(SeedEl.id(22,8), 23.0, 35.0, 25.0, 4.5, b: "origen", s: 8.0, w: "bold", n: "Origen"),
      SeedEl.t(SeedEl.id(22,9), 52.0, 35.0, 20.0, 4.5, t: "Destino:", s: 8.0, c: "#666666", n: "Label destino"),
      SeedEl.t(SeedEl.id(22,10), 73.0, 35.0, 23.0, 4.5, b: "destino", s: 8.0, w: "bold", n: "Destino"),
      SeedEl.bc(SeedEl.id(22,11), 5.0, 42.0, 90.0, 14.0, b: "num_parte", f: "CODE128", n: "Código parte")
    ]
  },

  # 23. Calibración equipo (70×40mm)
  %{
    name: "Calibración equipo",
    description: "Etiqueta de calibración con fecha, próxima calibración y técnico",
    width_mm: 70.0, height_mm: 40.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#006600", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "manufactura",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(23,1), 3.0, 2.0, 64.0, 5.0, t: "CALIBRACIÓN", s: 9.0, w: "bold", a: "center", c: "#006600", n: "Título"),
      SeedEl.l(SeedEl.id(23,2), 3.0, 8.0, 64.0, c: "#006600"),
      SeedEl.t(SeedEl.id(23,3), 3.0, 10.0, 64.0, 5.5, b: "id_equipo", s: 10.0, w: "bold", a: "center", n: "ID equipo"),
      SeedEl.t(SeedEl.id(23,4), 3.0, 17.0, 22.0, 4.5, t: "Fecha cal.:", s: 8.0, c: "#666666", n: "Label fecha"),
      SeedEl.t(SeedEl.id(23,5), 26.0, 17.0, 20.0, 4.5, b: "fecha_calibracion", s: 8.0, n: "Fecha cal."),
      SeedEl.t(SeedEl.id(23,6), 3.0, 23.0, 22.0, 5.0, t: "Próxima:", s: 8.0, c: "#666666", n: "Label próxima"),
      SeedEl.t(SeedEl.id(23,7), 26.0, 23.0, 20.0, 5.0, b: "proxima_calibracion", s: 9.0, w: "bold", n: "Próxima cal."),
      SeedEl.t(SeedEl.id(23,8), 3.0, 29.0, 20.0, 4.5, t: "Técnico:", s: 8.0, c: "#666666", n: "Label técnico"),
      SeedEl.t(SeedEl.id(23,9), 24.0, 29.0, 22.0, 4.5, b: "tecnico", s: 8.0, n: "Técnico"),
      SeedEl.q(SeedEl.id(23,10), 49.0, 17.0, 18.0, b: "id_equipo", n: "QR equipo")
    ]
  },

  # 24. Producto terminado (100×70mm)
  %{
    name: "Producto terminado",
    description: "Etiqueta para producto terminado con referencia, lote, peso y QR",
    width_mm: 100.0, height_mm: 70.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "manufactura",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(24,1), 5.0, 4.0, 90.0, 8.0, b: "nombre_producto", s: 14.0, w: "bold", n: "Producto"),
      SeedEl.t(SeedEl.id(24,2), 5.0, 13.0, 15.0, 5.5, t: "Ref.:", s: 9.0, c: "#666666", n: "Label ref."),
      SeedEl.t(SeedEl.id(24,3), 21.0, 13.0, 74.0, 5.5, b: "referencia", s: 10.0, w: "bold", n: "Referencia"),
      SeedEl.l(SeedEl.id(24,4), 5.0, 20.0, 90.0),
      SeedEl.t(SeedEl.id(24,5), 5.0, 22.0, 14.0, 5.0, t: "Lote:", s: 9.0, c: "#666666", n: "Label lote"),
      SeedEl.t(SeedEl.id(24,6), 20.0, 22.0, 30.0, 5.0, b: "lote", s: 9.0, w: "bold", n: "Lote"),
      SeedEl.t(SeedEl.id(24,7), 55.0, 22.0, 14.0, 5.0, t: "Fecha:", s: 9.0, c: "#666666", n: "Label fecha"),
      SeedEl.t(SeedEl.id(24,8), 70.0, 22.0, 25.0, 5.0, b: "fecha_produccion", s: 9.0, n: "Fecha"),
      SeedEl.t(SeedEl.id(24,9), 5.0, 29.0, 14.0, 5.0, t: "Peso:", s: 9.0, c: "#666666", n: "Label peso"),
      SeedEl.t(SeedEl.id(24,10), 20.0, 29.0, 25.0, 5.0, b: "peso", s: 9.0, w: "bold", n: "Peso"),
      SeedEl.t(SeedEl.id(24,11), 50.0, 29.0, 20.0, 5.0, t: "Cantidad:", s: 9.0, c: "#666666", n: "Label cantidad"),
      SeedEl.t(SeedEl.id(24,12), 71.0, 29.0, 24.0, 5.0, b: "cantidad", s: 9.0, w: "bold", n: "Cantidad"),
      SeedEl.q(SeedEl.id(24,13), 5.0, 38.0, 24.0, b: "codigo_trazabilidad", n: "QR trazabilidad"),
      SeedEl.bc(SeedEl.id(24,14), 33.0, 40.0, 62.0, 22.0, b: "referencia", f: "CODE128", n: "Código referencia")
    ]
  },

  # ═══════════════════════════════════════════════════════════════════
  # RETAIL (6)
  # ═══════════════════════════════════════════════════════════════════

  # 25. Precio producto (60×40mm)
  %{
    name: "Precio producto",
    description: "Etiqueta de precio para productos de retail con nombre y código de barras",
    width_mm: 60.0, height_mm: 40.0,
    background_color: "#FFFFFF", border_width: 0.2, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "retail",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(25,1), 3.0, 2.0, 54.0, 5.0, b: "nombre_producto", s: 9.0, w: "bold", a: "center", n: "Producto"),
      SeedEl.t(SeedEl.id(25,2), 3.0, 8.0, 54.0, 9.0, b: "precio", s: 16.0, w: "bold", a: "center", n: "Precio"),
      SeedEl.l(SeedEl.id(25,3), 3.0, 18.0, 54.0),
      SeedEl.t(SeedEl.id(25,4), 3.0, 20.0, 14.0, 4.5, t: "Ref.:", s: 8.0, c: "#666666", n: "Label ref."),
      SeedEl.t(SeedEl.id(25,5), 18.0, 20.0, 39.0, 4.5, b: "referencia", s: 8.0, n: "Referencia"),
      SeedEl.bc(SeedEl.id(25,6), 5.0, 26.0, 50.0, 11.0, b: "ean13", f: "EAN13", n: "EAN-13")
    ]
  },

  # 26. Etiqueta textil (40×80mm) - Tall/narrow
  %{
    name: "Etiqueta textil",
    description: "Etiqueta para prendas de vestir con marca, talla, color y precio",
    width_mm: 40.0, height_mm: 80.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "retail",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(26,1), 3.0, 3.0, 34.0, 6.0, b: "marca", s: 10.0, w: "bold", a: "center", n: "Marca"),
      SeedEl.l(SeedEl.id(26,2), 3.0, 10.0, 34.0),
      SeedEl.t(SeedEl.id(26,3), 3.0, 12.0, 34.0, 5.0, b: "producto", s: 9.0, a: "center", n: "Producto"),
      SeedEl.t(SeedEl.id(26,4), 3.0, 20.0, 34.0, 7.0, b: "talla", s: 12.0, w: "bold", a: "center", n: "Talla"),
      SeedEl.t(SeedEl.id(26,5), 3.0, 29.0, 16.0, 4.5, t: "Color:", s: 8.0, c: "#666666", n: "Label color"),
      SeedEl.t(SeedEl.id(26,6), 20.0, 29.0, 17.0, 4.5, b: "color", s: 8.0, n: "Color"),
      SeedEl.l(SeedEl.id(26,7), 3.0, 35.0, 34.0),
      SeedEl.t(SeedEl.id(26,8), 3.0, 37.0, 34.0, 6.0, b: "precio", s: 10.0, w: "bold", a: "center", n: "Precio"),
      SeedEl.t(SeedEl.id(26,9), 3.0, 45.0, 12.0, 4.5, t: "Ref.:", s: 8.0, c: "#666666", n: "Label ref."),
      SeedEl.t(SeedEl.id(26,10), 16.0, 45.0, 21.0, 4.5, b: "referencia", s: 8.0, n: "Referencia"),
      SeedEl.bc(SeedEl.id(26,11), 4.0, 52.0, 32.0, 24.0, b: "ean13", f: "EAN13", n: "EAN-13")
    ]
  },

  # 27. Joyería y accesorios (30×50mm) - Small/tall
  %{
    name: "Joyería y accesorios",
    description: "Etiqueta pequeña para joyería y accesorios con marca, referencia y precio",
    width_mm: 30.0, height_mm: 50.0,
    background_color: "#FFFFFF", border_width: 0.2, border_color: "#999999", border_radius: 1.0,
    is_template: true, template_source: "system", template_category: "retail",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(27,1), 2.0, 2.0, 26.0, 5.0, b: "marca", s: 8.0, w: "bold", a: "center", n: "Marca"),
      SeedEl.l(SeedEl.id(27,2), 2.0, 8.0, 26.0),
      SeedEl.t(SeedEl.id(27,3), 2.0, 10.0, 26.0, 4.0, b: "producto", s: 7.0, a: "center", n: "Producto"),
      SeedEl.t(SeedEl.id(27,4), 2.0, 15.0, 10.0, 4.0, t: "Ref.:", s: 7.0, c: "#666666", n: "Label ref."),
      SeedEl.t(SeedEl.id(27,5), 13.0, 15.0, 15.0, 4.0, b: "referencia", s: 7.0, n: "Referencia"),
      SeedEl.t(SeedEl.id(27,6), 2.0, 21.0, 26.0, 6.0, b: "precio", s: 10.0, w: "bold", a: "center", n: "Precio"),
      SeedEl.bc(SeedEl.id(27,7), 3.0, 30.0, 24.0, 16.0, b: "ean8", f: "EAN8", n: "EAN-8")
    ]
  },

  # 28. Estantería (60×30mm)
  %{
    name: "Estantería",
    description: "Etiqueta de estantería con nombre, precio destacado y código de barras",
    width_mm: 60.0, height_mm: 30.0,
    background_color: "#FFFFFF", border_width: 0.2, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "retail",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(28,1), 3.0, 1.0, 54.0, 5.0, b: "nombre_producto", s: 8.0, w: "bold", n: "Producto"),
      SeedEl.t(SeedEl.id(28,2), 3.0, 7.0, 30.0, 8.0, b: "precio", s: 14.0, w: "bold", n: "Precio"),
      SeedEl.t(SeedEl.id(28,3), 35.0, 9.0, 22.0, 4.0, b: "precio_kg", s: 7.0, c: "#666666", a: "right", n: "Precio/kg"),
      SeedEl.l(SeedEl.id(28,4), 3.0, 16.0, 54.0),
      SeedEl.t(SeedEl.id(28,5), 3.0, 18.0, 10.0, 4.0, t: "Ref.:", s: 7.0, c: "#666666", n: "Label ref."),
      SeedEl.t(SeedEl.id(28,6), 14.0, 18.0, 15.0, 4.0, b: "referencia", s: 7.0, n: "Referencia"),
      SeedEl.bc(SeedEl.id(28,7), 32.0, 17.0, 25.0, 11.0, b: "ean13", f: "EAN13", st: false, n: "EAN-13")
    ]
  },

  # 29. Promoción / descuento (80×50mm)
  %{
    name: "Promoción descuento",
    description: "Etiqueta promocional con precio original, precio rebajado y porcentaje de descuento",
    width_mm: 80.0, height_mm: 50.0,
    background_color: "#FFFFFF", border_width: 0.5, border_color: "#CC0000", border_radius: 1.0,
    is_template: true, template_source: "system", template_category: "retail",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(29,1), 4.0, 2.0, 72.0, 5.5, b: "nombre_producto", s: 10.0, w: "bold", a: "center", n: "Producto"),
      SeedEl.l(SeedEl.id(29,2), 4.0, 8.0, 72.0),
      SeedEl.t(SeedEl.id(29,3), 4.0, 10.0, 20.0, 5.0, t: "Antes:", s: 9.0, c: "#999999", n: "Label antes"),
      SeedEl.t(SeedEl.id(29,4), 25.0, 10.0, 30.0, 5.0, b: "precio_original", s: 9.0, c: "#999999", n: "Precio original"),
      SeedEl.t(SeedEl.id(29,5), 4.0, 17.0, 20.0, 9.0, t: "AHORA:", s: 10.0, w: "bold", c: "#CC0000", n: "Label ahora"),
      SeedEl.t(SeedEl.id(29,6), 25.0, 16.0, 30.0, 10.0, b: "precio_oferta", s: 16.0, w: "bold", c: "#CC0000", n: "Precio oferta"),
      SeedEl.t(SeedEl.id(29,7), 58.0, 10.0, 18.0, 14.0, b: "descuento_pct", s: 14.0, w: "bold", c: "#CC0000", a: "center", n: "% Dto."),
      SeedEl.l(SeedEl.id(29,8), 4.0, 28.0, 72.0),
      SeedEl.t(SeedEl.id(29,9), 4.0, 30.0, 28.0, 4.5, t: "Válido hasta:", s: 8.0, c: "#666666", n: "Label validez"),
      SeedEl.t(SeedEl.id(29,10), 33.0, 30.0, 25.0, 4.5, b: "fecha_fin", s: 8.0, w: "bold", n: "Fecha fin"),
      SeedEl.bc(SeedEl.id(29,11), 5.0, 37.0, 70.0, 10.0, b: "ean13", f: "EAN13", st: false, n: "EAN-13")
    ]
  },

  # 30. Producto electrónica (70×40mm)
  %{
    name: "Producto electrónica",
    description: "Etiqueta para productos electrónicos con modelo, número de serie y QR de soporte",
    width_mm: 70.0, height_mm: 40.0,
    background_color: "#FFFFFF", border_width: 0.3, border_color: "#000000", border_radius: 0.0,
    is_template: true, template_source: "system", template_category: "retail",
    label_type: "multiple",
    elements: [
      SeedEl.t(SeedEl.id(30,1), 3.0, 2.0, 64.0, 6.0, b: "nombre_producto", s: 10.0, w: "bold", n: "Producto"),
      SeedEl.t(SeedEl.id(30,2), 3.0, 9.0, 18.0, 5.0, t: "Modelo:", s: 9.0, c: "#666666", n: "Label modelo"),
      SeedEl.t(SeedEl.id(30,3), 22.0, 9.0, 45.0, 5.0, b: "modelo", s: 9.0, n: "Modelo"),
      SeedEl.t(SeedEl.id(30,4), 3.0, 15.0, 10.0, 4.5, t: "S/N:", s: 8.0, c: "#666666", n: "Label S/N"),
      SeedEl.t(SeedEl.id(30,5), 14.0, 15.0, 35.0, 4.5, b: "numero_serie", s: 8.0, w: "bold", n: "N° serie"),
      SeedEl.q(SeedEl.id(30,6), 3.0, 22.0, 15.0, b: "url_soporte", n: "QR soporte"),
      SeedEl.bc(SeedEl.id(30,7), 21.0, 23.0, 46.0, 13.0, b: "ean13", f: "EAN13", n: "EAN-13")
    ]
  }
]

# Insert all templates
Enum.each(templates, fn template_data ->
  %Design{}
  |> Design.changeset(template_data)
  |> Repo.insert!()
end)

IO.puts("Inserted #{length(templates)} system templates.")
