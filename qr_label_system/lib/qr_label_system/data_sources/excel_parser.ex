defmodule QrLabelSystem.DataSources.ExcelParser do
  @moduledoc """
  Parser for Excel (.xlsx) and CSV files.
  Extracts headers and rows from uploaded files.

  Uses a custom SAX-based parser for xlsx that handles:
  - Inline strings (t="inlineStr")
  - Shared strings (t="s")
  - Numeric values (t="n" or no type)
  - Absolute paths in rels (e.g., /xl/worksheets/sheet1.xml)
  """

  @doc """
  Parses an Excel file and returns the data.

  Returns {:ok, %{headers: [...], rows: [...], total: n}} or {:error, reason}
  """
  def parse_excel(file_path, opts \\ []) do
    max_rows = Keyword.get(opts, :max_rows, 10_000)

    try do
      {:ok, zip_handle} = :zip.zip_open(String.to_charlist(file_path), [:memory])

      try do
        # Read shared strings if present
        shared_strings = read_shared_strings(zip_handle)

        # Find and read first worksheet
        sheet_xml = read_first_sheet(zip_handle)

        case sheet_xml do
          nil ->
            {:error, "No worksheet found in Excel file"}

          xml ->
            all_rows = parse_worksheet_xml(xml, shared_strings)

            if Enum.empty?(all_rows) do
              {:error, "Empty file or sheet"}
            else
              [header_row | data_rows] = all_rows
              headers = normalize_headers(header_row)

              rows =
                data_rows
                |> Enum.take(max_rows)
                |> Enum.map(&row_to_map(headers, &1))

              {:ok, %{
                headers: headers,
                rows: rows,
                total: length(rows)
              }}
            end
        end
      after
        :zip.zip_close(zip_handle)
      end
    rescue
      e -> {:error, "Failed to parse Excel file: #{Exception.message(e)}"}
    end
  end

  @doc """
  Parses a CSV file and returns the data.
  """
  def parse_csv(file_path, opts \\ []) do
    max_rows = Keyword.get(opts, :max_rows, 10_000)
    separator = Keyword.get(opts, :separator, ",")

    try do
      [headers | data_rows] =
        file_path
        |> File.stream!()
        |> NimbleCSV.RFC4180.parse_stream(skip_headers: false, separator: separator)
        |> Enum.take(max_rows + 1)

      normalized_headers = normalize_headers(headers)
      rows = Enum.map(data_rows, &row_to_map(normalized_headers, &1))

      {:ok, %{
        headers: normalized_headers,
        rows: rows,
        total: length(rows)
      }}
    rescue
      e -> {:error, "Failed to parse CSV file: #{Exception.message(e)}"}
    end
  end

  @doc """
  Auto-detects file type and parses accordingly.
  """
  def parse_file(file_path, opts \\ []) do
    extension = Path.extname(file_path) |> String.downcase()

    case extension do
      ".xlsx" -> parse_excel(file_path, opts)
      ".xls" -> {:error, "Legacy .xls format not supported. Please save as .xlsx"}
      ".csv" -> parse_csv(file_path, opts)
      _ -> {:error, "Unsupported file format: #{extension}"}
    end
  end

  @doc """
  Returns a preview of the file (first n rows).
  """
  def preview_file(file_path, opts \\ []) do
    preview_rows = Keyword.get(opts, :preview_rows, 5)
    parse_file(file_path, Keyword.put(opts, :max_rows, preview_rows))
  end

  # ── XLSX internals ──

  defp read_shared_strings(zip_handle) do
    case :zip.zip_get(~c"xl/sharedStrings.xml", zip_handle) do
      {:ok, {_, xml_binary}} ->
        parse_shared_strings(xml_binary)

      {:error, _} ->
        []
    end
  end

  defp parse_shared_strings(xml) do
    # Extract each <si>...</si> block, then collect all <t>...</t> text within it.
    # Handles both simple (<si><t>text</t></si>) and rich text
    # (<si><r><t>part1</t></r><r><t>part2</t></r></si>) formats.
    Regex.scan(~r/<si>(.*?)<\/si>/s, xml)
    |> Enum.map(fn [_, si_content] ->
      Regex.scan(~r/<t[^>]*>(.*?)<\/t>/s, si_content)
      |> Enum.map(fn [_, text] -> unescape_xml(text) end)
      |> Enum.join()
    end)
  end

  defp read_first_sheet(zip_handle) do
    # Try common paths for the first worksheet
    paths = [
      ~c"xl/worksheets/sheet1.xml",
      ~c"xl/worksheets/Sheet1.xml"
    ]

    Enum.find_value(paths, fn path ->
      case :zip.zip_get(path, zip_handle) do
        {:ok, {_, xml_binary}} -> xml_binary
        {:error, _} -> nil
      end
    end)
  end

  defp parse_worksheet_xml(xml, shared_strings) do
    # Parse all rows from the worksheet XML
    xml_str = if is_binary(xml), do: xml, else: to_string(xml)

    Regex.scan(~r/<row[^>]*>(.*?)<\/row>/s, xml_str)
    |> Enum.map(fn [_, row_xml] ->
      parse_row_cells(row_xml, shared_strings)
    end)
  end

  defp parse_row_cells(row_xml, shared_strings) do
    # Extract cell references and values
    cells = Regex.scan(~r/<c\s+([^>]*)(?:\/>|>(.*?)<\/c>)/s, row_xml)

    # Determine max column from cell references
    cell_data =
      Enum.map(cells, fn
        [_, attrs, content] -> parse_cell(attrs, content, shared_strings)
        [_, attrs] -> parse_cell(attrs, "", shared_strings)
      end)

    # Convert column letters to indices and fill gaps
    max_col = Enum.reduce(cell_data, 0, fn {col_idx, _}, acc -> max(col_idx, acc) end)

    row = List.duplicate(nil, max_col + 1)

    Enum.reduce(cell_data, row, fn {col_idx, value}, acc ->
      List.replace_at(acc, col_idx, value)
    end)
  end

  defp parse_cell(attrs, content, shared_strings) do
    # Get cell reference (e.g., "A1", "B2")
    ref = case Regex.run(~r/r="([A-Z]+)\d+"/, attrs) do
      [_, col] -> col
      _ -> "A"
    end

    col_idx = col_letter_to_index(ref)

    # Get cell type
    type = case Regex.run(~r/t="([^"]*)"/, attrs) do
      [_, t] -> t
      _ -> nil
    end

    value = case type do
      "inlineStr" ->
        # Inline string: <is><t>value</t></is>
        case Regex.run(~r/<is>\s*<t[^>]*>(.*?)<\/t>/s, content) do
          [_, v] -> unescape_xml(v)
          _ -> nil
        end

      "s" ->
        # Shared string index
        case Regex.run(~r/<v>(.*?)<\/v>/, content) do
          [_, idx_str] ->
            case Integer.parse(idx_str) do
              {idx, _} -> Enum.at(shared_strings, idx, nil)
              :error -> nil
            end
          _ -> nil
        end

      "b" ->
        # Boolean
        case Regex.run(~r/<v>(.*?)<\/v>/, content) do
          [_, "1"] -> true
          [_, "0"] -> false
          _ -> nil
        end

      _ ->
        # Numeric or default
        case Regex.run(~r/<v>(.*?)<\/v>/, content) do
          [_, v] -> parse_number(v)
          _ -> nil
        end
    end

    {col_idx, value}
  end

  defp col_letter_to_index(letters) do
    result =
      letters
      |> String.to_charlist()
      |> Enum.reduce(0, fn char, acc ->
        acc * 26 + (char - ?A + 1)
      end)

    result - 1
  end

  defp parse_number(str) do
    case Float.parse(str) do
      {f, ""} ->
        # Return integer if it's a whole number
        if f == trunc(f), do: trunc(f), else: f
      _ ->
        str
    end
  end

  defp unescape_xml(str) do
    str
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
    |> String.replace("&#10;", "\n")
    |> String.replace("&#13;", "\r")
    |> String.replace("&#xA;", "\n")
    |> String.replace("&#xD;", "\r")
  end

  # ── Common helpers ──

  defp normalize_headers(headers) when is_list(headers) do
    headers
    |> Enum.with_index()
    |> Enum.map(fn {header, index} ->
      case header do
        nil -> "Column_#{index + 1}"
        h when is_binary(h) -> String.trim(h)
        h -> to_string(h)
      end
    end)
  end

  defp row_to_map(headers, row) when is_list(row) do
    headers
    |> Enum.zip(row)
    |> Enum.into(%{}, fn {header, value} ->
      {header, normalize_value(value)}
    end)
  end

  defp normalize_value(nil), do: nil
  defp normalize_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_value(value) when is_number(value), do: value
  defp normalize_value(value) when is_boolean(value), do: to_string(value)
  defp normalize_value(%Date{} = date), do: Date.to_iso8601(date)
  defp normalize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp normalize_value(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp normalize_value(value), do: to_string(value)
end
