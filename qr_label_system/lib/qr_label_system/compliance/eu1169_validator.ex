defmodule QrLabelSystem.Compliance.Eu1169Validator do
  @moduledoc """
  EU Regulation 1169/2011 compliance validator for food labeling.
  Checks that mandatory information is present on the label design.
  Uses heuristic field detection based on element names, bindings, and text content.
  """

  @behaviour QrLabelSystem.Compliance.Validator

  alias QrLabelSystem.Compliance.Issue
  alias QrLabelSystem.Designs.Design

  @impl true
  def standard_name, do: "EU 1169/2011"

  @impl true
  def standard_code, do: "eu1169"

  @impl true
  def standard_description, do: "Reglamento UE 1169/2011 sobre información alimentaria facilitada al consumidor"

  # Patterns for detecting mandatory fields (case-insensitive, ES + EN)
  @field_patterns %{
    product_name: ~r/(?:nombre|denominaci[oó]n|product.?name|product.?title)/iu,
    ingredients: ~r/(?:ingrediente|ingredient)/iu,
    allergens: ~r/(?:al[eé]rgeno|allergen)/iu,
    net_quantity: ~r/(?:peso|weight|cantidad.?neta|net.?(?:quantity|weight|content)|volumen|volume|(?:^|\s)g(?:\s|$)|(?:^|\s)ml(?:\s|$)|(?:^|\s)kg(?:\s|$)|(?:^|\s)l(?:\s|$))/iu,
    best_before: ~r/(?:caducidad|consumir.?antes|expir|best.?before|use.?by|fecha.?(?:de\s+)?(?:consumo|vencimiento))/iu,
    manufacturer: ~r/(?:fabricant|manufactur|elaborad|produc(?:id|tor)|envasad|empresa)/iu,
    origin: ~r/(?:origen|origin|pa[ií]s|country|procedencia|hecho.?en|made.?in)/iu,
    nutrition: ~r/(?:nutric|nutrition|calor[ií]|energ|prote[ií]n|grasa|fat|carbohidrato|carbohydrate|fibra|fiber|sodio|sodium|sal(?:\s|$)|salt(?:\s|$))/iu,
    lot: ~r/(?:lote|lot|batch)/iu
  }

  @impl true
  def validate(%Design{} = design) do
    elements = design.elements || []
    text_elements = Enum.filter(elements, &text_like_element?/1)
    barcode_elements = Enum.filter(elements, &(&1.type == "barcode"))

    detected = detect_fields(text_elements)

    mandatory_issues = validate_mandatory_fields(detected)
    recommended_issues = validate_recommended_fields(detected, barcode_elements)
    font_issues = validate_font_sizes(text_elements, design)
    allergen_issues = validate_allergen_highlighting(text_elements, detected)

    mandatory_issues ++ recommended_issues ++ font_issues ++ allergen_issues
  end

  defp text_like_element?(%{type: "text"}), do: true
  defp text_like_element?(_), do: false

  defp detect_fields(text_elements) do
    Enum.reduce(@field_patterns, %{}, fn {field, pattern}, acc ->
      matched = Enum.filter(text_elements, fn el ->
        searchable_text(el) |> String.match?(pattern)
      end)

      if matched != [] do
        Map.put(acc, field, matched)
      else
        acc
      end
    end)
  end

  defp searchable_text(element) do
    name = to_string(Map.get(element, :name) || Map.get(element, "name") || "")
    binding = to_string(Map.get(element, :binding) || Map.get(element, "binding") || "")
    text = to_string(Map.get(element, :text_content) || Map.get(element, "text_content") || "")
    "#{name} #{binding} #{text}"
  end

  # Mandatory fields (errors)
  defp validate_mandatory_fields(detected) do
    mandatory = [
      {:product_name, "EU_MISSING_NAME", "Falta la denominación del producto",
       "Agregue un campo de texto con el nombre del producto"},
      {:ingredients, "EU_MISSING_INGREDIENTS", "Falta la lista de ingredientes",
       "Agregue un campo de texto con la lista de ingredientes"},
      {:allergens, "EU_MISSING_ALLERGENS", "Falta información de alérgenos",
       "Agregue un campo que identifique los alérgenos (Reg. UE 1169/2011 Art. 21)"},
      {:net_quantity, "EU_MISSING_NET_QUANTITY", "Falta la cantidad neta (peso/volumen)",
       "Agregue un campo con el peso neto o volumen del producto"},
      {:best_before, "EU_MISSING_BEST_BEFORE", "Falta la fecha de caducidad o consumo preferente",
       "Agregue un campo con la fecha de caducidad/consumo preferente"}
    ]

    Enum.flat_map(mandatory, fn {field, code, msg, hint} ->
      if Map.has_key?(detected, field) do
        []
      else
        [Issue.error(code, msg, fix_hint: hint)]
      end
    end)
  end

  # Recommended fields (warnings)
  defp validate_recommended_fields(detected, barcode_elements) do
    recommended = [
      {:manufacturer, "EU_MISSING_MANUFACTURER", "Falta nombre/dirección del fabricante o envasador",
       "Agregue la identificación del operador responsable"},
      {:origin, "EU_MISSING_ORIGIN", "Falta el país de origen",
       "Agregue el país de origen cuando sea obligatorio (carnes, frutas, verduras, etc.)"},
      {:nutrition, "EU_MISSING_NUTRITION", "Falta la declaración nutricional",
       "Agregue la información nutricional (Reg. UE 1169/2011 Art. 30)"},
      {:lot, "EU_MISSING_LOT", "Falta el número de lote",
       "Agregue el número de lote para trazabilidad"}
    ]

    field_issues = Enum.flat_map(recommended, fn {field, code, msg, hint} ->
      if Map.has_key?(detected, field) do
        []
      else
        [Issue.warning(code, msg, fix_hint: hint)]
      end
    end)

    barcode_issue = if barcode_elements == [] do
      [Issue.info("EU_MISSING_BARCODE", "Considere agregar un código EAN-13 para distribución retail",
        fix_hint: "Un código EAN-13 facilita la venta en supermercados y tiendas")]
    else
      []
    end

    field_issues ++ barcode_issue
  end

  # Font size validation
  # EU requires x-height >= 1.2mm (normal) or >= 0.9mm (labels < 80cm²)
  # Approximation: min 8pt (normal) / 6pt (small)
  defp validate_font_sizes(text_elements, design) do
    area = (design.width_mm || 0) * (design.height_mm || 0)
    min_pt = if area < 8000, do: 6.0, else: 8.0

    text_elements
    |> Enum.filter(fn el ->
      font_size = Map.get(el, :font_size) || Map.get(el, "font_size") || 10.0
      font_size < min_pt
    end)
    |> Enum.map(fn el ->
      element_id = Map.get(el, :id) || Map.get(el, "id")
      font_size = Map.get(el, :font_size) || Map.get(el, "font_size")
      Issue.error("EU_FONT_SIZE_MIN",
        "Tamaño de fuente (#{font_size}pt) inferior al mínimo legal (#{min_pt}pt)",
        element_id: element_id,
        fix_hint: "Aumente el tamaño de fuente a al menos #{min_pt}pt")
    end)
  end

  # Allergen highlighting check
  defp validate_allergen_highlighting(_text_elements, detected) do
    case Map.get(detected, :allergens) do
      nil -> []
      allergen_elements ->
        Enum.flat_map(allergen_elements, fn el ->
          font_weight = Map.get(el, :font_weight) || Map.get(el, "font_weight") || "normal"
          element_id = Map.get(el, :id) || Map.get(el, "id")

          if font_weight in ["bold", "800", "900", "700"] do
            []
          else
            [Issue.warning("EU_ALLERGEN_HIGHLIGHT",
              "Los alérgenos deben destacarse tipográficamente (Art. 21 UE 1169/2011)",
              element_id: element_id,
              fix_hint: "Use negrita u otro recurso tipográfico para resaltar los alérgenos")]
          end
        end)
    end
  end
end
