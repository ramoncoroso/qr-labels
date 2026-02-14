defmodule QrLabelSystem.Compliance.Gs1Validator do
  @moduledoc """
  GS1 compliance validator.
  Checks barcode elements for correct format, length, and checksums
  according to GS1 standards.
  """

  @behaviour QrLabelSystem.Compliance.Validator

  alias QrLabelSystem.Compliance.Issue
  alias QrLabelSystem.Compliance.Gs1.Checksum
  alias QrLabelSystem.Designs.Design

  @impl true
  def standard_name, do: "GS1"

  @impl true
  def standard_code, do: "gs1"

  @impl true
  def standard_description, do: "Estándares GS1 para códigos de barras (EAN-13, EAN-8, UPC-A, ITF-14, GS1-128, DataMatrix)"

  @gs1_barcode_formats ~w(EAN13 EAN8 UPC ITF14 GS1_128 GS1_DATABAR GS1_DATABAR_STACKED GS1_DATABAR_EXPANDED DATAMATRIX)

  @impl true
  def validate(%Design{} = design) do
    elements = design.elements || []
    barcode_elements = Enum.filter(elements, &barcode_element?/1)
    gs1_barcodes = Enum.filter(barcode_elements, &gs1_barcode?/1)

    global_issues = validate_global(gs1_barcodes)
    element_issues = Enum.flat_map(gs1_barcodes, &validate_element/1)

    global_issues ++ element_issues
  end

  defp barcode_element?(%{type: "barcode"}), do: true
  defp barcode_element?(_), do: false

  defp gs1_barcode?(%{barcode_format: fmt}) when fmt in @gs1_barcode_formats, do: true
  defp gs1_barcode?(_), do: false

  defp validate_global(gs1_barcodes) do
    if gs1_barcodes == [] do
      [Issue.warning("GS1_NO_BARCODE", "El diseño no contiene ningún código de barras GS1",
        fix_hint: "Agregue un código de barras EAN-13, EAN-8, UPC-A, ITF-14 o GS1-128",
        fix_action: %{type: "barcode", name: "Código EAN-13", barcode_format: "EAN13", text_content: "0000000000000"})]
    else
      []
    end
  end

  defp validate_element(element) do
    value = get_value(element)
    element_id = Map.get(element, :id) || Map.get(element, "id")
    format = Map.get(element, :barcode_format) || Map.get(element, "barcode_format")

    cond do
      dynamic_value?(value) ->
        [Issue.info("GS1_DYNAMIC_SKIP",
          "Elemento con datos dinámicos ({{...}}): el checksum se validará en impresión",
          element_id: element_id)]

      is_nil(value) || value == "" ->
        # Empty value — not an error per se, will be caught by other checks
        []

      true ->
        validate_by_format(format, value, element_id)
    end
  end

  defp validate_by_format("EAN13", value, element_id) do
    validate_numeric(value, element_id) ++ validate_ean13(value, element_id)
  end

  defp validate_by_format("EAN8", value, element_id) do
    validate_numeric(value, element_id) ++ validate_ean8(value, element_id)
  end

  defp validate_by_format("UPC", value, element_id) do
    validate_numeric(value, element_id) ++ validate_upc(value, element_id)
  end

  defp validate_by_format("ITF14", value, element_id) do
    validate_numeric(value, element_id) ++ validate_itf14(value, element_id)
  end

  defp validate_by_format("GS1_128", value, element_id) do
    validate_gs1_128(value, element_id)
  end

  defp validate_by_format("DATAMATRIX", value, element_id) do
    validate_datamatrix(value, element_id)
  end

  defp validate_by_format(_format, _value, _element_id), do: []

  # Numeric-only check for EAN/UPC/ITF
  defp validate_numeric(value, element_id) do
    if Checksum.digits_only?(value) do
      []
    else
      [Issue.error("GS1_DIGITS_ONLY",
        "El código solo debe contener dígitos (0-9)",
        element_id: element_id,
        fix_hint: "Elimine letras y caracteres especiales del código")]
    end
  end

  # EAN-13 validation
  defp validate_ean13(value, element_id) do
    if !Checksum.digits_only?(value), do: [], else: do_validate_ean13(value, element_id)
  end

  defp do_validate_ean13(value, element_id) do
    case String.length(value) do
      13 ->
        case Checksum.verify_check_digit(value) do
          :ok -> []
          {:error, expected} ->
            [Issue.error("GS1_EAN13_CHECKSUM",
              "Dígito de control EAN-13 inválido. Esperado: #{expected}",
              element_id: element_id,
              fix_hint: "El último dígito debería ser #{expected}")]
        end

      _ ->
        [Issue.error("GS1_EAN13_LENGTH",
          "EAN-13 debe tener exactamente 13 dígitos (tiene #{String.length(value)})",
          element_id: element_id,
          fix_hint: "Ajuste la longitud del código a 13 dígitos")]
    end
  end

  # EAN-8 validation
  defp validate_ean8(value, element_id) do
    if !Checksum.digits_only?(value), do: [], else: do_validate_ean8(value, element_id)
  end

  defp do_validate_ean8(value, element_id) do
    case String.length(value) do
      8 ->
        case Checksum.verify_check_digit(value) do
          :ok -> []
          {:error, expected} ->
            [Issue.error("GS1_EAN8_CHECKSUM",
              "Dígito de control EAN-8 inválido. Esperado: #{expected}",
              element_id: element_id,
              fix_hint: "El último dígito debería ser #{expected}")]
        end

      _ ->
        [Issue.error("GS1_EAN8_LENGTH",
          "EAN-8 debe tener exactamente 8 dígitos (tiene #{String.length(value)})",
          element_id: element_id,
          fix_hint: "Ajuste la longitud del código a 8 dígitos")]
    end
  end

  # UPC-A validation
  defp validate_upc(value, element_id) do
    if !Checksum.digits_only?(value), do: [], else: do_validate_upc(value, element_id)
  end

  defp do_validate_upc(value, element_id) do
    case String.length(value) do
      12 ->
        case Checksum.verify_check_digit(value) do
          :ok -> []
          {:error, expected} ->
            [Issue.error("GS1_UPC_CHECKSUM",
              "Dígito de control UPC-A inválido. Esperado: #{expected}",
              element_id: element_id,
              fix_hint: "El último dígito debería ser #{expected}")]
        end

      _ ->
        [Issue.error("GS1_UPC_LENGTH",
          "UPC-A debe tener exactamente 12 dígitos (tiene #{String.length(value)})",
          element_id: element_id,
          fix_hint: "Ajuste la longitud del código a 12 dígitos")]
    end
  end

  # ITF-14 validation
  defp validate_itf14(value, element_id) do
    if !Checksum.digits_only?(value), do: [], else: do_validate_itf14(value, element_id)
  end

  defp do_validate_itf14(value, element_id) do
    case String.length(value) do
      14 ->
        case Checksum.verify_check_digit(value) do
          :ok -> []
          {:error, expected} ->
            [Issue.error("GS1_ITF14_CHECKSUM",
              "Dígito de control ITF-14 inválido. Esperado: #{expected}",
              element_id: element_id,
              fix_hint: "El último dígito debería ser #{expected}")]
        end

      _ ->
        [Issue.error("GS1_ITF14_LENGTH",
          "ITF-14 debe tener exactamente 14 dígitos (tiene #{String.length(value)})",
          element_id: element_id,
          fix_hint: "Ajuste la longitud del código a 14 dígitos")]
    end
  end

  # GS1-128 validation
  defp validate_gs1_128(value, element_id) do
    case Checksum.parse_gs1_128(value) do
      {:ok, []} ->
        [Issue.warning("GS1_128_AI_MANDATORY",
          "El código GS1-128 debería contener al menos un Application Identifier",
          element_id: element_id,
          fix_hint: "Agregue datos con formato GS1 AI (ej: 01 + GTIN-14)")]

      {:ok, _ais} ->
        []

      {:error, {:invalid_ai, ai_str}} ->
        [Issue.error("GS1_128_AI_INVALID",
          "Application Identifier inválido: \"#{ai_str}\"",
          element_id: element_id,
          fix_hint: "Verifique que los AIs sean códigos GS1 válidos (01, 10, 17, 21, etc.)")]

      {:error, _} ->
        [Issue.error("GS1_128_AI_INVALID",
          "No se pudo parsear el contenido GS1-128",
          element_id: element_id,
          fix_hint: "Verifique el formato del código GS1-128")]
    end
  end

  # DataMatrix GS1 validation
  defp validate_datamatrix(value, element_id) do
    if Checksum.looks_like_gs1?(value) do
      []
    else
      [Issue.warning("GS1_DATAMATRIX_NO_GS1",
        "El DataMatrix no parece contener datos GS1",
        element_id: element_id,
        fix_hint: "En contexto GS1, el DataMatrix debería codificar AIs (ej: 01+GTIN, 17+fecha, 10+lote)")]
    end
  end

  # Helper to get the effective value of an element
  defp get_value(element) do
    text = Map.get(element, :text_content) || Map.get(element, "text_content")
    binding = Map.get(element, :binding) || Map.get(element, "binding")

    cond do
      text && text != "" -> text
      binding && binding != "" -> "{{#{binding}}}"
      true -> nil
    end
  end

  # Helper to detect dynamic bindings
  defp dynamic_value?(nil), do: false
  defp dynamic_value?(value), do: String.contains?(value, "{{")
end
