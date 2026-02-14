defmodule QrLabelSystem.Compliance.FmdValidator do
  @moduledoc """
  EU Falsified Medicines Directive (2011/62/EU) compliance validator.
  Checks pharmaceutical label designs for mandatory FMD fields
  and DataMatrix requirements.
  """

  @behaviour QrLabelSystem.Compliance.Validator

  alias QrLabelSystem.Compliance.Issue
  alias QrLabelSystem.Compliance.Gs1.Checksum
  alias QrLabelSystem.Designs.Design

  @impl true
  def standard_name, do: "FMD (Directiva 2011/62/EU)"

  @impl true
  def standard_code, do: "fmd"

  @impl true
  def standard_description, do: "Directiva de Medicamentos Falsificados: requisitos de serialización y trazabilidad farmacéutica"

  # Patterns for detecting FMD mandatory fields
  @field_patterns %{
    product_name: ~r/(?:nombre|denominaci[oó]n|medicamento|drug.?name|product.?name|specialit)/iu,
    active_ingredient: ~r/(?:principio.?activo|active.?ingredient|sustancia|substance|\b(?:DCI|INN)\b)/iu,
    lot: ~r/(?:lote|lot\b|batch)/iu,
    expiry: ~r/(?:caducidad|expir|vencimiento|best.?before|use.?by)/iu,
    national_code: ~r/(?:c[oó]digo.?nacional|\bCN\b|\bPZN\b|\bCIP\b|national.?code|\bNDC\b)/iu,
    serial: ~r/(?:serial|serie|n[uú]mero.?(?:de\s+)?serie|\bSN\b)/iu,
    dosage: ~r/(?:dosis|dosage|forma.?farmac[eé]|pharmaceutical.?form|posolog|\b\d+\s*mg\b|\b\d+\s*ml\b|comprimido|tablet|c[aá]psula|capsule|jarabe|syrup|inyectable|injectable)/iu,
    manufacturer: ~r/(?:fabricant|manufactur|laboratorio|titular|marketing.?auth|\bMAH\b)/iu
  }

  # FMD mandatory GS1 AIs in DataMatrix: 01(GTIN), 17(expiry), 10(lot), 21(serial)
  @fmd_mandatory_ais ~w(01 17 10 21)

  @impl true
  def validate(%Design{} = design) do
    elements = design.elements || []
    text_elements = Enum.filter(elements, &text_like_element?/1)
    barcode_elements = Enum.filter(elements, &(&1.type == "barcode"))
    datamatrix_elements = Enum.filter(barcode_elements, &datamatrix?/1)

    detected = detect_fields(text_elements)

    mandatory_issues = validate_mandatory_fields(detected)
    recommended_issues = validate_recommended_fields(detected)
    datamatrix_issues = validate_datamatrix(datamatrix_elements)

    mandatory_issues ++ recommended_issues ++ datamatrix_issues
  end

  defp text_like_element?(%{type: "text"}), do: true
  defp text_like_element?(_), do: false

  defp datamatrix?(%{barcode_format: "DATAMATRIX"}), do: true
  defp datamatrix?(_), do: false

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
      {:product_name, "FMD_MISSING_PRODUCT_NAME", "Falta el nombre del medicamento",
       "Agregue el nombre comercial del medicamento",
       %{type: "text", name: "Nombre medicamento", text_content: "Nombre comercial del medicamento", font_size: 12}},
      {:active_ingredient, "FMD_MISSING_ACTIVE_INGREDIENT", "Falta el principio activo (DCI/INN)",
       "Agregue la denominación común internacional del principio activo",
       %{type: "text", name: "Principio activo (DCI)", text_content: "DCI: Principio activo 000mg", font_size: 9}},
      {:lot, "FMD_MISSING_LOT", "Falta el número de lote",
       "Agregue el número de lote (obligatorio FMD Art. 54)",
       %{type: "text", name: "Lote", text_content: "Lote: XXXXXX", font_size: 8}},
      {:expiry, "FMD_MISSING_EXPIRY", "Falta la fecha de caducidad",
       "Agregue la fecha de caducidad del medicamento",
       %{type: "text", name: "Fecha caducidad", text_content: "CAD: MM/AAAA", font_size: 8}},
      {:national_code, "FMD_MISSING_NATIONAL_CODE", "Falta el código nacional (CN/PZN/CIP)",
       "Agregue el código nacional del medicamento",
       %{type: "text", name: "Código nacional (CN)", text_content: "CN: 000000", font_size: 8}},
      {:serial, "FMD_MISSING_SERIAL", "Falta el número de serie único (anti-falsificación)",
       "Agregue un identificador de serie único (Reglamento Delegado UE 2016/161)",
       %{type: "text", name: "Número de serie (SN)", text_content: "SN: XXXXXXXXXXXX", font_size: 7}}
    ]

    Enum.flat_map(mandatory, fn {field, code, msg, hint, action} ->
      if Map.has_key?(detected, field) do
        []
      else
        [Issue.error(code, msg, fix_hint: hint, fix_action: action)]
      end
    end)
  end

  # Recommended fields (warnings)
  defp validate_recommended_fields(detected) do
    recommended = [
      {:dosage, "FMD_MISSING_DOSAGE", "Falta la forma farmacéutica/dosis",
       "Agregue información sobre la forma farmacéutica y dosificación",
       %{type: "text", name: "Forma farmacéutica", text_content: "Comprimidos recubiertos 000mg", font_size: 8}},
      {:manufacturer, "FMD_MISSING_MANUFACTURER", "Falta el titular de autorización de comercialización",
       "Agregue el nombre del laboratorio titular",
       %{type: "text", name: "Laboratorio titular", text_content: "Laboratorio S.A.", font_size: 7}}
    ]

    Enum.flat_map(recommended, fn {field, code, msg, hint, action} ->
      if Map.has_key?(detected, field) do
        []
      else
        [Issue.warning(code, msg, fix_hint: hint, fix_action: action)]
      end
    end)
  end

  # DataMatrix validation
  defp validate_datamatrix([]) do
    [Issue.error("FMD_MISSING_DATAMATRIX",
      "Falta código DataMatrix (obligatorio para FMD)",
      fix_hint: "Agregue un código DataMatrix con datos GS1 (GTIN + serial + lote + caducidad)",
      fix_action: %{type: "barcode", name: "DataMatrix FMD", barcode_format: "DATAMATRIX", text_content: "(01)00000000000000(17)000000(10)LOT000(21)SN000"})]
  end

  defp validate_datamatrix(datamatrix_elements) do
    Enum.flat_map(datamatrix_elements, fn el ->
      value = get_value(el)
      element_id = Map.get(el, :id) || Map.get(el, "id")

      cond do
        is_nil(value) || value == "" ->
          []

        dynamic_value?(value) ->
          []

        true ->
          validate_datamatrix_content(value, element_id)
      end
    end)
  end

  defp validate_datamatrix_content(value, element_id) do
    if Checksum.looks_like_gs1?(value) do
      case Checksum.parse_gs1_128(value) do
        {:ok, ais} ->
          ai_codes = Enum.map(ais, &elem(&1, 0))
          missing = @fmd_mandatory_ais -- ai_codes

          if missing == [] do
            []
          else
            ai_names = Enum.map(missing, &ai_description/1)
            [Issue.warning("FMD_DATAMATRIX_NO_GS1",
              "El DataMatrix no contiene todos los AIs obligatorios FMD. Faltan: #{Enum.join(ai_names, ", ")}",
              element_id: element_id,
              fix_hint: "El DataMatrix FMD debe codificar: GTIN (01) + Caducidad (17) + Lote (10) + Serial (21)")]
          end

        _ ->
          [Issue.warning("FMD_DATAMATRIX_NO_GS1",
            "El DataMatrix debería codificar datos GS1 (GTIN+SN+LOT+EXP)",
            element_id: element_id,
            fix_hint: "Use formato GS1 con AIs: 01(GTIN) + 17(caducidad) + 10(lote) + 21(serial)")]
      end
    else
      [Issue.warning("FMD_DATAMATRIX_NO_GS1",
        "El DataMatrix debería codificar datos GS1 (GTIN+SN+LOT+EXP)",
        element_id: element_id,
        fix_hint: "Use formato GS1 con AIs: 01(GTIN) + 17(caducidad) + 10(lote) + 21(serial)")]
    end
  end

  defp ai_description("01"), do: "GTIN (01)"
  defp ai_description("17"), do: "Caducidad (17)"
  defp ai_description("10"), do: "Lote (10)"
  defp ai_description("21"), do: "Serial (21)"
  defp ai_description(ai), do: "AI #{ai}"

  defp get_value(element) do
    text = Map.get(element, :text_content) || Map.get(element, "text_content")
    binding = Map.get(element, :binding) || Map.get(element, "binding")

    cond do
      text && text != "" -> text
      binding && binding != "" -> "{{#{binding}}}"
      true -> nil
    end
  end

  defp dynamic_value?(nil), do: false
  defp dynamic_value?(value), do: String.contains?(value, "{{")
end
