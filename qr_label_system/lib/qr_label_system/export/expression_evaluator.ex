defmodule QrLabelSystem.Export.ExpressionEvaluator do
  @moduledoc """
  Server-side expression evaluator (Elixir mirror of expression_engine.js).
  Evaluates {{}} expressions in element bindings for ZPL export and server-side rendering.

  Functions use Spanish names matching the JS engine: HOY(), MAYUS(), CONTADOR(), SI(), etc.
  Security: No Code.eval_string. All functions are whitelisted.
  """

  @doc """
  Check if a binding string is an expression (contains `{{`).
  """
  def is_expression?(nil), do: false
  def is_expression?(binding) when is_binary(binding), do: String.contains?(binding, "{{")
  def is_expression?(_), do: false

  @doc """
  Evaluate a template string, replacing all {{...}} with resolved values.
  """
  def evaluate(nil, _row, _context), do: ""
  def evaluate(template, row, context) when is_binary(template) do
    if String.contains?(template, "{{") do
      Regex.replace(~r/\{\{(.+?)\}\}/, template, fn _match, expr ->
        try do
          resolve_expression(String.trim(expr), row, context)
        rescue
          _ -> "#ERR#"
        end
      end)
    else
      template
    end
  end

  @doc """
  Resolve the final text for an element, handling expressions, bindings, and fallbacks.
  """
  def resolve_text(element, row \\ %{}, context \\ %{}) do
    binding = get_field(element, :binding)
    text_content = get_field(element, :text_content) || ""

    cond do
      # Expression mode
      is_expression?(binding) ->
        evaluate(binding, row, context)

      # Column binding mode
      is_binary(binding) && binding != "" ->
        resolve_column(binding, row) || text_content

      # Fixed text mode
      true ->
        text_content
    end
  end

  @doc """
  Resolve value for QR/barcode elements.
  """
  def resolve_code_value(element, row \\ %{}, context \\ %{}) do
    binding = get_field(element, :binding)
    text_content = get_field(element, :text_content) || ""

    cond do
      is_expression?(binding) ->
        evaluate(binding, row, context)

      is_binary(binding) && binding != "" ->
        resolve_column(binding, row) || text_content || binding

      true ->
        text_content || binding || ""
    end
  end

  # ── Expression resolver ──────────────────────────────────────

  defp resolve_expression(expr, row, context) do
    cond do
      # Default operator: expr || alternative
      String.contains?(expr, "||") ->
        [primary | rest] = String.split(expr, "||", parts: 2)
        result = resolve_expression(String.trim(primary), row, context)
        if result != "" && result != "#ERR#" do
          result
        else
          alt = String.trim(Enum.join(rest, "||"))
          alt_result = resolve_expression(alt, row, context)
          # If alternative doesn't resolve (not a column or function), use it as literal
          if alt_result == "" && alt != "" && !String.contains?(alt, "("), do: alt, else: alt_result
        end

      # Function call
      String.contains?(expr, "(") ->
        resolve_function(expr, row, context)

      # Column reference
      true ->
        resolve_column(expr, row) || ""
    end
  end

  defp resolve_column(name, row) when is_map(row) do
    case Map.get(row, name) do
      nil ->
        # Case-insensitive match
        key = Enum.find(Map.keys(row), fn k ->
          String.downcase(k) == String.downcase(name)
        end)
        if key, do: to_string(Map.get(row, key)), else: nil
      val ->
        to_string(val)
    end
  end
  defp resolve_column(_name, _row), do: nil

  # ── Function parser ──────────────────────────────────────────

  defp resolve_function(expr, row, context) do
    paren_idx = :binary.match(expr, "(") |> elem(0)
    name = expr |> binary_part(0, paren_idx) |> String.trim() |> String.upcase()
    inner = expr |> String.slice((paren_idx + 1)..-2//1) |> String.trim()
    args = parse_args(inner, row, context)

    call_function(name, args, row, context)
  end

  defp parse_args("", _row, _context), do: []
  defp parse_args(args_str, row, context) do
    # Simple comma-split that respects parentheses and quotes
    {args, current, _depth, _in_quote} =
      args_str
      |> String.graphemes()
      |> Enum.reduce({[], "", 0, false}, fn char, {args, current, depth, in_quote} ->
        cond do
          in_quote && char in ["\"", "'"] ->
            {args, current, depth, false}
          !in_quote && char in ["\"", "'"] ->
            {args, current, depth, true}
          in_quote ->
            {args, current <> char, depth, true}
          char == "(" ->
            {args, current <> char, depth + 1, false}
          char == ")" ->
            {args, current <> char, depth - 1, false}
          char == "," && depth == 0 ->
            {args ++ [resolve_arg(String.trim(current), row, context)], "", 0, false}
          true ->
            {args, current <> char, depth, in_quote}
        end
      end)

    if String.trim(current) != "" do
      args ++ [resolve_arg(String.trim(current), row, context)]
    else
      args
    end
  end

  defp resolve_arg(arg, row, context) do
    cond do
      arg == "" -> ""
      String.contains?(arg, "(") -> resolve_function(arg, row, context)
      match?({_, ""}, Float.parse(arg)) -> arg
      match?({_, ""}, Integer.parse(arg)) -> arg
      true ->
        case resolve_column(arg, row) do
          nil -> arg
          val -> val
        end
    end
  end

  # ── Function registry ────────────────────────────────────────

  # Text functions
  defp call_function("MAYUS", args, _row, _ctx), do: String.upcase(to_s(Enum.at(args, 0)))
  defp call_function("MINUS", args, _row, _ctx), do: String.downcase(to_s(Enum.at(args, 0)))

  defp call_function("RECORTAR", args, _row, _ctx) do
    val = to_s(Enum.at(args, 0))
    len = to_i(Enum.at(args, 1), String.length(val))
    String.slice(val, 0, len)
  end

  defp call_function("CONCAT", args, _row, _ctx) do
    Enum.map_join(args, "", &to_s/1)
  end

  defp call_function("REEMPLAZAR", args, _row, _ctx) do
    val = to_s(Enum.at(args, 0))
    search = to_s(Enum.at(args, 1))
    replace = to_s(Enum.at(args, 2))
    if search == "", do: val, else: String.replace(val, search, replace)
  end

  defp call_function("LARGO", args, _row, _ctx) do
    to_string(String.length(to_s(Enum.at(args, 0))))
  end

  # Date functions
  defp call_function("HOY", args, _row, ctx) do
    now = Map.get(ctx, :now, DateTime.utc_now())
    fmt = to_s(Enum.at(args, 0))
    fmt = if fmt == "", do: "DD/MM/AAAA", else: fmt
    format_date(now, fmt)
  end

  defp call_function("AHORA", args, _row, ctx) do
    now = Map.get(ctx, :now, DateTime.utc_now())
    fmt = to_s(Enum.at(args, 0))
    fmt = if fmt == "", do: "DD/MM/AAAA hh:mm", else: fmt
    format_date(now, fmt)
  end

  defp call_function("SUMAR_DIAS", args, _row, ctx) do
    base = parse_date(Enum.at(args, 0), ctx)
    days = to_i(Enum.at(args, 1), 0)
    fmt = to_s(Enum.at(args, 2))
    fmt = if fmt == "", do: "DD/MM/AAAA", else: fmt
    result = Date.add(base, days)
    format_date(result, fmt)
  end

  defp call_function("SUMAR_MESES", args, _row, ctx) do
    base = parse_date(Enum.at(args, 0), ctx)
    months = to_i(Enum.at(args, 1), 0)
    fmt = to_s(Enum.at(args, 2))
    fmt = if fmt == "", do: "DD/MM/AAAA", else: fmt
    result = Date.add(base, months * 30)
    format_date(result, fmt)
  end

  defp call_function("FORMATO_FECHA", args, _row, _ctx) do
    date = parse_date_str(to_s(Enum.at(args, 0)))
    fmt = to_s(Enum.at(args, 1))
    fmt = if fmt == "", do: "DD/MM/AAAA", else: fmt
    format_date(date, fmt)
  end

  # Counter functions
  defp call_function("CONTADOR", args, _row, ctx) do
    start = to_i(Enum.at(args, 0), 1)
    step = to_i(Enum.at(args, 1), 1)
    padding = to_i(Enum.at(args, 2), 0)
    idx = Map.get(ctx, :row_index, 0)
    value = start + idx * step
    if padding > 0 do
      value |> to_string() |> String.pad_leading(padding, "0")
    else
      to_string(value)
    end
  end

  defp call_function("LOTE", args, _row, ctx) do
    fmt = to_s(Enum.at(args, 0))
    fmt = if fmt == "", do: "AAMM-####", else: fmt
    now = Map.get(ctx, :now, DateTime.utc_now())
    idx = Map.get(ctx, :row_index, 0) + 1

    yyyy = now.year |> to_string()
    yy = String.slice(yyyy, -2, 2)
    mm = now.month |> to_string() |> String.pad_leading(2, "0")
    dd = now.day |> to_string() |> String.pad_leading(2, "0")

    result = fmt
      |> String.replace("AAAA", yyyy)
      |> String.replace("AA", yy)
      |> String.replace("MM", mm)
      |> String.replace("DD", dd)

    # Replace # sequences with counter
    Regex.replace(~r/#+/, result, fn match ->
      idx |> to_string() |> String.pad_leading(String.length(match), "0")
    end)
  end

  defp call_function("REDONDEAR", args, _row, _ctx) do
    val = to_f(Enum.at(args, 0))
    dec = to_i(Enum.at(args, 1), 0)
    :erlang.float_to_binary(val, decimals: dec)
  end

  defp call_function("FORMATO_NUM", args, _row, _ctx) do
    val = to_f(Enum.at(args, 0))
    dec = to_i(Enum.at(args, 1), 0)
    sep = to_s(Enum.at(args, 2))
    formatted = :erlang.float_to_binary(val, decimals: dec)
    if sep == "," do
      String.replace(formatted, ".", ",")
    else
      formatted
    end
  end

  # Conditional functions
  defp call_function("SI", args, _row, _ctx) do
    cond_str = to_s(Enum.at(args, 0))
    true_val = to_s(Enum.at(args, 1))
    false_val = to_s(Enum.at(args, 2))

    if eval_condition(cond_str), do: true_val, else: false_val
  end

  defp call_function("VACIO", args, _row, _ctx) do
    if to_s(Enum.at(args, 0)) == "", do: "true", else: "false"
  end

  defp call_function("POR_DEFECTO", args, _row, _ctx) do
    val = to_s(Enum.at(args, 0))
    alt = to_s(Enum.at(args, 1))
    if val != "", do: val, else: alt
  end

  defp call_function(_name, _args, _row, _ctx), do: "#ERR#"

  # ── Condition evaluator ──────────────────────────────────────

  defp eval_condition(cond_str) do
    ops = ["==", "!=", ">=", "<=", ">", "<"]

    result = Enum.find_value(ops, fn op ->
      case String.split(cond_str, op, parts: 2) do
        [left, right] when left != cond_str ->
          compare(String.trim(left), op, String.trim(right))
        _ ->
          nil
      end
    end)

    case result do
      nil ->
        # Truthy check
        cond_str != "" && cond_str != "0" && cond_str != "false"
      val ->
        val
    end
  end

  defp compare(left, op, right) do
    num_l = parse_number(left)
    num_r = parse_number(right)

    if num_l && num_r do
      numeric_compare(num_l, op, num_r)
    else
      string_compare(left, op, right)
    end
  end

  defp numeric_compare(l, "==", r), do: l == r
  defp numeric_compare(l, "!=", r), do: l != r
  defp numeric_compare(l, ">", r), do: l > r
  defp numeric_compare(l, "<", r), do: l < r
  defp numeric_compare(l, ">=", r), do: l >= r
  defp numeric_compare(l, "<=", r), do: l <= r

  defp string_compare(l, "==", r), do: l == r
  defp string_compare(l, "!=", r), do: l != r
  defp string_compare(l, ">", r), do: l > r
  defp string_compare(l, "<", r), do: l < r
  defp string_compare(l, ">=", r), do: l >= r
  defp string_compare(l, "<=", r), do: l <= r

  # ── Helpers ──────────────────────────────────────────────────

  defp get_field(element, key) when is_map(element) do
    Map.get(element, key) || Map.get(element, to_string(key))
  end

  defp to_s(nil), do: ""
  defp to_s(val) when is_binary(val), do: val
  defp to_s(val), do: to_string(val)

  defp to_i(nil, default), do: default
  defp to_i(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end
  defp to_i(val, _default) when is_integer(val), do: val
  defp to_i(val, _default) when is_float(val), do: round(val)
  defp to_i(_, default), do: default

  defp to_f(nil), do: 0.0
  defp to_f(val) when is_binary(val) do
    case Float.parse(val) do
      {n, _} -> n
      :error -> 0.0
    end
  end
  defp to_f(val) when is_number(val), do: val / 1
  defp to_f(_), do: 0.0

  defp parse_number(str) do
    case Float.parse(str) do
      {n, ""} -> n
      _ ->
        case Integer.parse(str) do
          {n, ""} -> n / 1
          _ -> nil
        end
    end
  end

  defp format_date(%DateTime{} = dt, fmt), do: format_date(DateTime.to_date(dt), fmt)
  defp format_date(%NaiveDateTime{} = dt, fmt), do: format_date(NaiveDateTime.to_date(dt), fmt)
  defp format_date(%Date{} = date, fmt) do
    d = date.day |> to_string() |> String.pad_leading(2, "0")
    m = date.month |> to_string() |> String.pad_leading(2, "0")
    yyyy = date.year |> to_string()
    yy = String.slice(yyyy, -2, 2)

    fmt
    |> String.replace("DD", d)
    |> String.replace("MM", m)
    |> String.replace("AAAA", yyyy)
    |> String.replace("AA", yy)
    |> String.replace("hh", "00")
    |> String.replace("mm", "00")
    |> String.replace("ss", "00")
  end
  defp format_date(_, fmt), do: fmt

  defp parse_date(nil, ctx), do: Map.get(ctx, :now, DateTime.utc_now()) |> to_date()
  defp parse_date("", ctx), do: Map.get(ctx, :now, DateTime.utc_now()) |> to_date()
  defp parse_date(str, ctx) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> Map.get(ctx, :now, DateTime.utc_now()) |> to_date()
    end
  end
  defp parse_date(_, ctx), do: Map.get(ctx, :now, DateTime.utc_now()) |> to_date()

  defp parse_date_str(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> Date.utc_today()
    end
  end

  defp to_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp to_date(%NaiveDateTime{} = dt), do: NaiveDateTime.to_date(dt)
  defp to_date(%Date{} = d), do: d
  defp to_date(_), do: Date.utc_today()
end
