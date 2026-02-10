defmodule QrLabelSystem.Compliance.Gs1.Checksum do
  @moduledoc """
  GS1 checksum utilities for EAN-13, EAN-8, UPC-A, GTIN-14, SSCC-18,
  and GS1-128 Application Identifier parsing.

  The mod-10 algorithm (shared by all GS1 linear barcodes):
  1. From the rightmost digit (excluding check digit), alternate multipliers 3 and 1
  2. Sum all products
  3. Check digit = (10 - (sum mod 10)) mod 10
  """

  @doc """
  Calculates the GS1 mod-10 check digit for a string of digits.
  The input should NOT include the check digit position.
  """
  def calculate_check_digit(digits) when is_binary(digits) do
    digits
    |> String.graphemes()
    |> Enum.map(&String.to_integer/1)
    |> calculate_check_digit_from_list()
  end

  def calculate_check_digit(digits) when is_list(digits) do
    calculate_check_digit_from_list(digits)
  end

  defp calculate_check_digit_from_list(digits) do
    # GS1 mod-10: from rightmost, alternate 3 and 1
    sum =
      digits
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.reduce(0, fn {d, i}, acc ->
        multiplier = if rem(i, 2) == 0, do: 3, else: 1
        acc + d * multiplier
      end)

    rem(10 - rem(sum, 10), 10)
  end

  @doc """
  Validates the check digit of a complete GS1 code (last digit is the check digit).
  Returns :ok or {:error, expected_check_digit}.
  """
  def verify_check_digit(code) when is_binary(code) do
    {payload, check_str} = String.split_at(code, -1)
    {check, _} = Integer.parse(check_str)
    expected = calculate_check_digit(payload)

    if check == expected do
      :ok
    else
      {:error, expected}
    end
  end

  @doc "Returns true if string contains only digits."
  def digits_only?(str), do: Regex.match?(~r/^\d+$/, str)

  @doc "Validates EAN-13 format and checksum. Returns :ok or {:error, reason}."
  def validate_ean13(code) do
    cond do
      !digits_only?(code) -> {:error, :not_digits}
      String.length(code) != 13 -> {:error, :wrong_length}
      true -> verify_check_digit(code)
    end
  end

  @doc "Validates EAN-8 format and checksum."
  def validate_ean8(code) do
    cond do
      !digits_only?(code) -> {:error, :not_digits}
      String.length(code) != 8 -> {:error, :wrong_length}
      true -> verify_check_digit(code)
    end
  end

  @doc "Validates UPC-A format and checksum."
  def validate_upc(code) do
    cond do
      !digits_only?(code) -> {:error, :not_digits}
      String.length(code) != 12 -> {:error, :wrong_length}
      true -> verify_check_digit(code)
    end
  end

  @doc "Validates ITF-14 (GTIN-14) format and checksum."
  def validate_itf14(code) do
    cond do
      !digits_only?(code) -> {:error, :not_digits}
      String.length(code) != 14 -> {:error, :wrong_length}
      true -> verify_check_digit(code)
    end
  end

  @doc "Validates SSCC-18 format and checksum."
  def validate_sscc18(code) do
    cond do
      !digits_only?(code) -> {:error, :not_digits}
      String.length(code) != 18 -> {:error, :wrong_length}
      true -> verify_check_digit(code)
    end
  end

  # Fixed-length Application Identifiers: AI code => total data length (excluding AI itself)
  @fixed_length_ais %{
    "00" => 18,
    "01" => 14,
    "02" => 14,
    "11" => 6,
    "12" => 6,
    "13" => 6,
    "15" => 6,
    "16" => 6,
    "17" => 6,
    "20" => 2
  }

  # Known valid AI prefixes (2, 3, or 4 digit)
  @known_ai_prefixes ~w(00 01 02 10 11 12 13 15 16 17 20 21 22 30 37
    240 241 242 243 250 251 253 254 255
    310 311 312 313 314 315 316 320 321 322 323 324 325 326 327 328 329
    330 331 332 333 334 335 336 337 340 341 342 343 344 345 346 347 348 349
    350 351 352 353 354 355 356 357 360 361 362 363 364 365 366 367 368 369
    390 391 392 393 394 395
    400 401 402 403 410 411 412 413 414 415 416 417 420 421 422 423 424 425 426 427
    710 711 712 713 714 715 723 7001 7002 7003 7004 7005 7006 7007 7008 7009 7010
    8001 8002 8003 8004 8005 8006 8007 8008 8010 8011 8012 8013 8017 8018 8019 8020
    8026 8110 8111 8112 8200
    91 92 93 94 95 96 97 98 99)

  @doc """
  Parses GS1-128 data string into a list of {ai, value} tuples.
  Handles FNC1 separator (ASCII GS = \\x1D or literal "FNC1").
  Returns {:ok, [{ai, value}, ...]} or {:error, reason}.
  """
  def parse_gs1_128(data) when is_binary(data) do
    # Strip leading FNC1 if present (it's the symbology identifier)
    data = data
    |> String.replace(~r/^\x1D/, "")
    |> String.replace(~r/^FNC1/, "")
    |> String.trim()

    case do_parse_ais(data, []) do
      {:ok, ais} -> {:ok, Enum.reverse(ais)}
      error -> error
    end
  end

  defp do_parse_ais("", acc), do: {:ok, acc}

  defp do_parse_ais(data, acc) do
    case extract_ai(data) do
      {:ok, ai, value, rest} ->
        do_parse_ais(rest, [{ai, value} | acc])

      {:error, _} = error ->
        error
    end
  end

  defp extract_ai(data) do
    # Try 4-digit, 3-digit, then 2-digit AI prefixes
    with {:error, _} <- try_ai(data, 4),
         {:error, _} <- try_ai(data, 3),
         {:error, _} <- try_ai(data, 2) do
      {:error, {:invalid_ai, String.slice(data, 0, 4)}}
    end
  end

  defp try_ai(data, ai_len) do
    if String.length(data) >= ai_len do
      ai = String.slice(data, 0, ai_len)

      if ai in @known_ai_prefixes do
        rest = String.slice(data, ai_len, String.length(data))
        extract_ai_value(ai, rest)
      else
        {:error, :not_known}
      end
    else
      {:error, :too_short}
    end
  end

  defp extract_ai_value(ai, rest) do
    case Map.get(@fixed_length_ais, ai) do
      nil ->
        # Variable length — terminated by FNC1 (GS char \x1D) or end of data
        {value, remaining} = split_at_fnc1(rest)
        {:ok, ai, value, remaining}

      fixed_len ->
        if String.length(rest) >= fixed_len do
          value = String.slice(rest, 0, fixed_len)
          remaining = String.slice(rest, fixed_len, String.length(rest))
          # Strip trailing FNC1 separator if present
          remaining = String.replace(remaining, ~r/^\x1D/, "")
          {:ok, ai, value, remaining}
        else
          {:ok, ai, rest, ""}
        end
    end
  end

  defp split_at_fnc1(data) do
    case String.split(data, "\x1D", parts: 2) do
      [value, rest] -> {value, rest}
      [value] -> {value, ""}
    end
  end

  @doc """
  Checks if data looks like GS1 content (starts with known AI patterns).
  """
  def looks_like_gs1?(data) when is_binary(data) do
    cleaned = data
    |> String.replace(~r/^\x1D/, "")
    |> String.replace(~r/^FNC1/, "")
    |> String.trim()

    prefix2 = String.slice(cleaned, 0, 2)
    prefix3 = String.slice(cleaned, 0, 3)
    prefix4 = String.slice(cleaned, 0, 4)

    prefix2 in @known_ai_prefixes or
      prefix3 in @known_ai_prefixes or
      prefix4 in @known_ai_prefixes
  end

  def looks_like_gs1?(_), do: false
end
