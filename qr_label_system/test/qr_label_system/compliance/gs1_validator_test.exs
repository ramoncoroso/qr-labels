defmodule QrLabelSystem.Compliance.Gs1ValidatorTest do
  use QrLabelSystem.DataCase, async: true

  alias QrLabelSystem.Compliance.Gs1Validator

  defp make_design(elements) do
    %QrLabelSystem.Designs.Design{
      id: 1,
      name: "Test GS1",
      width_mm: 100.0,
      height_mm: 50.0,
      elements: elements,
      groups: [],
      compliance_standard: "gs1"
    }
  end

  defp barcode(format, text_content, opts \\ []) do
    %QrLabelSystem.Designs.Element{
      id: Keyword.get(opts, :id, "el_#{System.unique_integer([:positive])}"),
      type: "barcode",
      x: 10.0,
      y: 10.0,
      width: 40.0,
      height: 15.0,
      barcode_format: format,
      text_content: text_content,
      binding: Keyword.get(opts, :binding)
    }
  end

  describe "standard metadata" do
    test "returns correct standard info" do
      assert Gs1Validator.standard_name() == "GS1"
      assert Gs1Validator.standard_code() == "gs1"
      assert is_binary(Gs1Validator.standard_description())
    end
  end

  describe "global validation" do
    test "warns when no GS1 barcodes present" do
      design = make_design([])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_NO_BARCODE"))
    end

    test "no global warning when GS1 barcode exists" do
      design = make_design([barcode("EAN13", "4006381333931")])
      issues = Gs1Validator.validate(design)
      refute Enum.any?(issues, &(&1.code == "GS1_NO_BARCODE"))
    end

    test "ignores non-GS1 barcodes" do
      design = make_design([barcode("CODE128", "ABC123")])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_NO_BARCODE"))
    end
  end

  describe "EAN-13 validation" do
    test "valid EAN-13 produces no errors" do
      design = make_design([barcode("EAN13", "4006381333931")])
      issues = Gs1Validator.validate(design)
      assert issues == []
    end

    test "invalid checksum produces error" do
      design = make_design([barcode("EAN13", "4006381333935")])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_EAN13_CHECKSUM" && &1.severity == :error))
    end

    test "wrong length produces error" do
      design = make_design([barcode("EAN13", "12345")])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_EAN13_LENGTH"))
    end

    test "non-digits produces error" do
      design = make_design([barcode("EAN13", "400638133393A")])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_DIGITS_ONLY"))
    end
  end

  describe "EAN-8 validation" do
    test "valid EAN-8 produces no errors" do
      design = make_design([barcode("EAN8", "96385074")])
      issues = Gs1Validator.validate(design)
      assert issues == []
    end

    test "invalid checksum produces error" do
      design = make_design([barcode("EAN8", "96385079")])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_EAN8_CHECKSUM"))
    end

    test "wrong length produces error" do
      design = make_design([barcode("EAN8", "123")])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_EAN8_LENGTH"))
    end
  end

  describe "UPC-A validation" do
    test "valid UPC-A produces no errors" do
      design = make_design([barcode("UPC", "036000291452")])
      issues = Gs1Validator.validate(design)
      assert issues == []
    end

    test "invalid checksum produces error" do
      design = make_design([barcode("UPC", "036000291459")])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_UPC_CHECKSUM"))
    end

    test "wrong length produces error" do
      design = make_design([barcode("UPC", "1234")])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_UPC_LENGTH"))
    end
  end

  describe "ITF-14 validation" do
    test "valid ITF-14 produces no errors" do
      design = make_design([barcode("ITF14", "10012345678902")])
      issues = Gs1Validator.validate(design)
      assert issues == []
    end

    test "invalid checksum produces error" do
      design = make_design([barcode("ITF14", "10012345678909")])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_ITF14_CHECKSUM"))
    end

    test "wrong length produces error" do
      design = make_design([barcode("ITF14", "123")])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_ITF14_LENGTH"))
    end
  end

  describe "GS1-128 validation" do
    test "valid GS1-128 with AI 01 produces no errors" do
      design = make_design([barcode("GS1_128", "0112345678901234")])
      issues = Gs1Validator.validate(design)
      assert issues == []
    end

    test "invalid AI produces error" do
      design = make_design([barcode("GS1_128", "XXXINVALID")])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_128_AI_INVALID"))
    end
  end

  describe "DataMatrix validation" do
    test "DataMatrix with GS1 content produces no errors" do
      design = make_design([barcode("DATAMATRIX", "0112345678901234")])
      issues = Gs1Validator.validate(design)
      assert issues == []
    end

    test "DataMatrix without GS1 content produces warning" do
      design = make_design([barcode("DATAMATRIX", "Hello World")])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_DATAMATRIX_NO_GS1"))
    end
  end

  describe "dynamic bindings" do
    test "element with binding produces info about dynamic skip" do
      design = make_design([barcode("EAN13", nil, binding: "ean_code")])
      issues = Gs1Validator.validate(design)
      assert Enum.any?(issues, &(&1.code == "GS1_DYNAMIC_SKIP" && &1.severity == :info))
    end
  end

  describe "element_id tracking" do
    test "issues include the element_id" do
      el = barcode("EAN13", "12345", id: "el_test_123")
      design = make_design([el])
      issues = Gs1Validator.validate(design)
      issue = Enum.find(issues, &(&1.code == "GS1_EAN13_LENGTH"))
      assert issue.element_id == "el_test_123"
    end

    test "issues include fix_hint" do
      design = make_design([barcode("EAN13", "12345")])
      issues = Gs1Validator.validate(design)
      issue = Enum.find(issues, &(&1.code == "GS1_EAN13_LENGTH"))
      assert issue.fix_hint != nil
    end
  end
end
