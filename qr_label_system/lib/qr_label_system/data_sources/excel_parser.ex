defmodule QrLabelSystem.DataSources.ExcelParser do
  @moduledoc """
  Parser for Excel (.xlsx) and CSV files.
  Extracts headers and rows from uploaded files.
  """

  @doc """
  Parses an Excel file and returns the data.

  Returns {:ok, %{headers: [...], rows: [...], total: n}} or {:error, reason}
  """
  def parse_excel(file_path, opts \\ []) do
    sheet_index = Keyword.get(opts, :sheet, 0)
    max_rows = Keyword.get(opts, :max_rows, 10_000)
    header_row = Keyword.get(opts, :header_row, 0)

    try do
      {:ok, table_id} = Xlsxir.multi_extract(file_path, sheet_index)

      all_rows = Xlsxir.get_list(table_id)
      Xlsxir.close(table_id)

      if Enum.empty?(all_rows) do
        {:error, "Empty file or sheet"}
      else
        headers = Enum.at(all_rows, header_row) |> normalize_headers()
        data_rows = all_rows
          |> Enum.drop(header_row + 1)
          |> Enum.take(max_rows)
          |> Enum.map(&row_to_map(headers, &1))

        {:ok, %{
          headers: headers,
          rows: data_rows,
          total: length(data_rows)
        }}
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
        |> NimbleCSV.RFC4180.parse_stream(separator: separator)
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

  # Private functions

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
  defp normalize_value(%Date{} = date), do: Date.to_iso8601(date)
  defp normalize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp normalize_value(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp normalize_value(value), do: to_string(value)
end
