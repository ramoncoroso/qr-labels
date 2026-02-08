defmodule QrLabelSystem.Export.ExpressionEvaluatorTest do
  use ExUnit.Case, async: true

  alias QrLabelSystem.Export.ExpressionEvaluator

  describe "is_expression?/1" do
    test "returns true for expressions with {{" do
      assert ExpressionEvaluator.is_expression?("{{HOY()}}")
      assert ExpressionEvaluator.is_expression?("Lote: {{lote}}")
    end

    test "returns false for plain bindings" do
      refute ExpressionEvaluator.is_expression?("nombre")
      refute ExpressionEvaluator.is_expression?("")
      refute ExpressionEvaluator.is_expression?(nil)
    end
  end

  describe "evaluate/3 - column references" do
    test "resolves simple column reference" do
      assert ExpressionEvaluator.evaluate("{{nombre}}", %{"nombre" => "Juan"}, %{}) == "Juan"
    end

    test "resolves case-insensitive column" do
      assert ExpressionEvaluator.evaluate("{{Nombre}}", %{"nombre" => "Juan"}, %{}) == "Juan"
    end

    test "mixed text and expressions" do
      assert ExpressionEvaluator.evaluate(
        "Lote: {{lote}} - {{tipo}}",
        %{"lote" => "A1", "tipo" => "Premium"},
        %{}
      ) == "Lote: A1 - Premium"
    end

    test "missing column returns empty" do
      assert ExpressionEvaluator.evaluate("{{missing}}", %{}, %{}) == ""
    end

    test "nil template returns empty" do
      assert ExpressionEvaluator.evaluate(nil, %{}, %{}) == ""
    end

    test "template without expressions passes through" do
      assert ExpressionEvaluator.evaluate("Hello World", %{}, %{}) == "Hello World"
    end
  end

  describe "evaluate/3 - text functions" do
    test "MAYUS converts to uppercase" do
      assert ExpressionEvaluator.evaluate("{{MAYUS(hello)}}", %{}, %{}) == "HELLO"
    end

    test "MAYUS with column reference" do
      assert ExpressionEvaluator.evaluate("{{MAYUS(nombre)}}", %{"nombre" => "juan"}, %{}) == "JUAN"
    end

    test "MINUS converts to lowercase" do
      assert ExpressionEvaluator.evaluate("{{MINUS(HELLO)}}", %{}, %{}) == "hello"
    end

    test "RECORTAR truncates string" do
      assert ExpressionEvaluator.evaluate("{{RECORTAR(abcdef, 3)}}", %{}, %{}) == "abc"
    end

    test "CONCAT joins values" do
      assert ExpressionEvaluator.evaluate(
        "{{CONCAT(nombre, -, apellido)}}",
        %{"nombre" => "Juan", "apellido" => "Perez"},
        %{}
      ) == "Juan-Perez"
    end

    test "REEMPLAZAR replaces text" do
      assert ExpressionEvaluator.evaluate(
        "{{REEMPLAZAR(hello world, world, earth)}}",
        %{},
        %{}
      ) == "hello earth"
    end

    test "LARGO returns string length" do
      assert ExpressionEvaluator.evaluate("{{LARGO(abcde)}}", %{}, %{}) == "5"
    end
  end

  describe "evaluate/3 - date functions" do
    test "HOY returns ISO date when no format" do
      now = ~U[2026-03-15 10:30:00Z]
      result = ExpressionEvaluator.evaluate("{{HOY()}}", %{}, %{now: now})
      assert result == "2026-03-15"
    end

    test "HOY with custom format" do
      now = ~U[2026-03-15 10:30:00Z]
      result = ExpressionEvaluator.evaluate("{{HOY(AA-MM-DD)}}", %{}, %{now: now})
      assert result == "26-03-15"
    end

    test "SUMAR_DIAS adds days" do
      now = ~U[2026-01-01 00:00:00Z]
      result = ExpressionEvaluator.evaluate("{{SUMAR_DIAS(, 30)}}", %{}, %{now: now})
      assert result == "2026-01-31"
    end

    test "SUMAR_MESES adds months" do
      now = ~U[2026-01-15 00:00:00Z]
      result = ExpressionEvaluator.evaluate("{{SUMAR_MESES(, 6)}}", %{}, %{now: now})
      # 6 months ≈ 180 days
      assert String.length(result) > 0
    end
  end

  describe "evaluate/3 - counter functions" do
    test "CONTADOR with start, step, padding" do
      assert ExpressionEvaluator.evaluate("{{CONTADOR(1, 1, 4)}}", %{}, %{row_index: 0}) == "0001"
      assert ExpressionEvaluator.evaluate("{{CONTADOR(1, 1, 4)}}", %{}, %{row_index: 4}) == "0005"
    end

    test "CONTADOR with custom start and step" do
      assert ExpressionEvaluator.evaluate("{{CONTADOR(100, 10, 0)}}", %{}, %{row_index: 2}) == "120"
    end

    test "LOTE generates batch codes" do
      now = ~U[2026-03-15 10:30:00Z]
      result = ExpressionEvaluator.evaluate("{{LOTE(AAMM-####)}}", %{}, %{now: now, row_index: 0})
      assert result == "2603-0001"
    end

    test "LOTE with different format" do
      now = ~U[2026-12-05 10:30:00Z]
      result = ExpressionEvaluator.evaluate("{{LOTE(AAAA-MM-##)}}", %{}, %{now: now, row_index: 4})
      assert result == "2026-12-05"
    end

    test "REDONDEAR rounds number" do
      assert ExpressionEvaluator.evaluate("{{REDONDEAR(3.14159, 2)}}", %{}, %{}) == "3.14"
    end

    test "FORMATO_NUM with comma separator" do
      assert ExpressionEvaluator.evaluate("{{FORMATO_NUM(1234.5, 2, \",\")}}", %{}, %{}) == "1234,50"
    end
  end

  describe "evaluate/3 - conditional functions" do
    test "SI with equality" do
      assert ExpressionEvaluator.evaluate(
        "{{SI(A == A, si, no)}}",
        %{},
        %{}
      ) == "si"
    end

    test "SI with inequality" do
      assert ExpressionEvaluator.evaluate(
        "{{SI(A != B, diferente, igual)}}",
        %{},
        %{}
      ) == "diferente"
    end

    test "SI with numeric comparison" do
      assert ExpressionEvaluator.evaluate(
        "{{SI(10 > 5, mayor, menor)}}",
        %{},
        %{}
      ) == "mayor"
    end

    test "VACIO returns true for empty" do
      assert ExpressionEvaluator.evaluate("{{VACIO()}}", %{}, %{}) == "true"
    end

    test "VACIO returns false for non-empty" do
      assert ExpressionEvaluator.evaluate("{{VACIO(hola)}}", %{}, %{}) == "false"
    end

    test "POR_DEFECTO uses value when present" do
      assert ExpressionEvaluator.evaluate(
        "{{POR_DEFECTO(nombre, Sin nombre)}}",
        %{"nombre" => "Juan"},
        %{}
      ) == "Juan"
    end

    test "POR_DEFECTO uses alternative when empty" do
      assert ExpressionEvaluator.evaluate(
        "{{POR_DEFECTO(, Sin nombre)}}",
        %{},
        %{}
      ) == "Sin nombre"
    end
  end

  describe "evaluate/3 - default operator" do
    test "uses primary when available" do
      assert ExpressionEvaluator.evaluate("{{nombre || Sin nombre}}", %{"nombre" => "Juan"}, %{}) == "Juan"
    end

    test "uses alternative when primary is empty" do
      assert ExpressionEvaluator.evaluate("{{missing || Alternativa}}", %{}, %{}) == "Alternativa"
    end
  end

  describe "evaluate/3 - error handling" do
    test "unknown function returns #ERR#" do
      assert ExpressionEvaluator.evaluate("{{FUNCION_INEXISTENTE()}}", %{}, %{}) == "#ERR#"
    end
  end

  describe "resolve_text/3" do
    test "expression binding" do
      element = %{binding: "Hola {{nombre}}", text_content: "fallback"}
      assert ExpressionEvaluator.resolve_text(element, %{"nombre" => "Mundo"}) == "Hola Mundo"
    end

    test "plain binding resolves from row" do
      element = %{binding: "nombre", text_content: "fallback"}
      assert ExpressionEvaluator.resolve_text(element, %{"nombre" => "Juan"}) == "Juan"
    end

    test "plain binding falls back to text_content" do
      element = %{binding: "missing", text_content: "fallback"}
      assert ExpressionEvaluator.resolve_text(element, %{}) == "fallback"
    end

    test "no binding returns text_content" do
      element = %{binding: nil, text_content: "fixed text"}
      assert ExpressionEvaluator.resolve_text(element) == "fixed text"
    end

    test "empty binding returns text_content" do
      element = %{binding: "", text_content: "fixed text"}
      assert ExpressionEvaluator.resolve_text(element) == "fixed text"
    end
  end

  describe "resolve_code_value/3" do
    test "expression in code" do
      element = %{binding: "{{CONTADOR(1, 1, 6)}}", text_content: "default"}
      assert ExpressionEvaluator.resolve_code_value(element, %{}, %{row_index: 0}) == "000001"
    end

    test "plain binding for code" do
      element = %{binding: "sku", text_content: "12345"}
      assert ExpressionEvaluator.resolve_code_value(element, %{"sku" => "ABC123"}) == "ABC123"
    end

    test "fallback to text_content" do
      element = %{binding: nil, text_content: "12345"}
      assert ExpressionEvaluator.resolve_code_value(element) == "12345"
    end
  end

  describe "nested functions" do
    test "MAYUS with column ref" do
      result = ExpressionEvaluator.evaluate(
        "{{MAYUS(nombre)}}",
        %{"nombre" => "juan perez"},
        %{}
      )
      assert result == "JUAN PEREZ"
    end
  end
end
