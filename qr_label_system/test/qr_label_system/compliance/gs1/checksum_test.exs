defmodule QrLabelSystem.Compliance.Gs1.ChecksumTest do
  use ExUnit.Case, async: true

  alias QrLabelSystem.Compliance.Gs1.Checksum

  describe "calculate_check_digit/1" do
    test "calculates EAN-13 check digit" do
      # 4006381333931 => check digit 1
      assert Checksum.calculate_check_digit("400638133393") == 1
    end

    test "calculates EAN-13 check digit for 0000000000000" do
      assert Checksum.calculate_check_digit("000000000000") == 0
    end

    test "calculates EAN-13 check digit for various codes" do
      # 5901234123457 => check 7
      assert Checksum.calculate_check_digit("590123412345") == 7
      # 4902778920527 => check 7
      assert Checksum.calculate_check_digit("490277892052") == 7
    end

    test "calculates EAN-8 check digit" do
      # 96385074 => check 4
      assert Checksum.calculate_check_digit("9638507") == 4
    end

    test "calculates UPC-A check digit" do
      # 036000291452 => check 2
      assert Checksum.calculate_check_digit("03600029145") == 2
    end

    test "calculates ITF-14 check digit" do
      # 10012345678902 => check 2
      assert Checksum.calculate_check_digit("1001234567890") == 2
    end

    test "calculates SSCC-18 check digit" do
      # 376130321109103420 => check 0
      assert Checksum.calculate_check_digit("37613032110910342") == 0
    end

    test "works with integer list" do
      assert Checksum.calculate_check_digit([4, 0, 0, 6, 3, 8, 1, 3, 3, 3, 9, 3]) == 1
    end
  end

  describe "verify_check_digit/1" do
    test "valid EAN-13 returns :ok" do
      assert Checksum.verify_check_digit("4006381333931") == :ok
    end

    test "valid EAN-8 returns :ok" do
      assert Checksum.verify_check_digit("96385074") == :ok
    end

    test "valid UPC-A returns :ok" do
      assert Checksum.verify_check_digit("036000291452") == :ok
    end

    test "valid ITF-14 returns :ok" do
      assert Checksum.verify_check_digit("10012345678902") == :ok
    end

    test "invalid check digit returns error with expected" do
      assert Checksum.verify_check_digit("4006381333935") == {:error, 1}
    end

    test "all-zeros is valid" do
      assert Checksum.verify_check_digit("0000000000000") == :ok
    end
  end

  describe "digits_only?/1" do
    test "returns true for digits" do
      assert Checksum.digits_only?("1234567890")
    end

    test "returns false for letters" do
      refute Checksum.digits_only?("123abc")
    end

    test "returns false for special chars" do
      refute Checksum.digits_only?("123-456")
    end

    test "returns false for empty string" do
      refute Checksum.digits_only?("")
    end
  end

  describe "validate_ean13/1" do
    test "valid EAN-13" do
      assert Checksum.validate_ean13("4006381333931") == :ok
    end

    test "wrong length" do
      assert Checksum.validate_ean13("12345") == {:error, :wrong_length}
    end

    test "non-digits" do
      assert Checksum.validate_ean13("400638133393A") == {:error, :not_digits}
    end

    test "wrong checksum" do
      assert {:error, 1} = Checksum.validate_ean13("4006381333935")
    end

    test "5901234123457 is valid" do
      assert Checksum.validate_ean13("5901234123457") == :ok
    end
  end

  describe "validate_ean8/1" do
    test "valid EAN-8" do
      assert Checksum.validate_ean8("96385074") == :ok
    end

    test "wrong length" do
      assert Checksum.validate_ean8("1234") == {:error, :wrong_length}
    end

    test "non-digits" do
      assert Checksum.validate_ean8("9638507A") == {:error, :not_digits}
    end

    test "wrong checksum" do
      assert {:error, _} = Checksum.validate_ean8("96385079")
    end
  end

  describe "validate_upc/1" do
    test "valid UPC-A" do
      assert Checksum.validate_upc("036000291452") == :ok
    end

    test "wrong length" do
      assert Checksum.validate_upc("12345") == {:error, :wrong_length}
    end

    test "non-digits" do
      assert Checksum.validate_upc("03600029145X") == {:error, :not_digits}
    end

    test "wrong checksum" do
      assert {:error, _} = Checksum.validate_upc("036000291459")
    end
  end

  describe "validate_itf14/1" do
    test "valid ITF-14" do
      assert Checksum.validate_itf14("10012345678902") == :ok
    end

    test "wrong length" do
      assert Checksum.validate_itf14("123") == {:error, :wrong_length}
    end

    test "wrong checksum" do
      assert {:error, _} = Checksum.validate_itf14("10012345678909")
    end
  end

  describe "validate_sscc18/1" do
    test "valid SSCC-18" do
      assert Checksum.validate_sscc18("376130321109103420") == :ok
    end

    test "wrong length" do
      assert Checksum.validate_sscc18("123") == {:error, :wrong_length}
    end
  end

  describe "parse_gs1_128/1" do
    test "parses single fixed-length AI (01 = GTIN-14)" do
      assert {:ok, [{"01", "12345678901234"}]} = Checksum.parse_gs1_128("0112345678901234")
    end

    test "parses multiple fixed-length AIs" do
      # AI 01 (14 digits) + AI 17 (6 digits)
      data = "01123456789012341726011510ABC123"
      assert {:ok, ais} = Checksum.parse_gs1_128(data)
      assert {"01", "12345678901234"} in ais
      assert {"17", "260115"} in ais
    end

    test "parses variable-length AI with FNC1 separator" do
      # AI 10 (lot) terminated by GS char, then AI 17
      data = "10LOT123\x1D17260115"
      assert {:ok, ais} = Checksum.parse_gs1_128(data)
      assert {"10", "LOT123"} in ais
      assert {"17", "260115"} in ais
    end

    test "parses AI 21 (serial)" do
      data = "21SERIAL001"
      assert {:ok, [{"21", "SERIAL001"}]} = Checksum.parse_gs1_128(data)
    end

    test "returns error for invalid AI" do
      assert {:error, {:invalid_ai, _}} = Checksum.parse_gs1_128("XXXXINVALID")
    end

    test "strips leading FNC1" do
      assert {:ok, [{"01", "12345678901234"}]} = Checksum.parse_gs1_128("\x1D0112345678901234")
    end

    test "empty data returns empty list" do
      assert {:ok, []} = Checksum.parse_gs1_128("")
    end

    test "parses SSCC (AI 00)" do
      data = "00376130321109103420"
      assert {:ok, [{"00", "376130321109103420"}]} = Checksum.parse_gs1_128(data)
    end

    test "parses full FMD DataMatrix content" do
      # AI 01 (GTIN) + AI 17 (expiry) + AI 10 (lot) + AI 21 (serial)
      data = "011234567890123417260115\x1D10LOT456\x1D21SER789"
      assert {:ok, ais} = Checksum.parse_gs1_128(data)
      assert length(ais) == 4
      ai_codes = Enum.map(ais, &elem(&1, 0))
      assert "01" in ai_codes
      assert "17" in ai_codes
      assert "10" in ai_codes
      assert "21" in ai_codes
    end
  end

  describe "looks_like_gs1?/1" do
    test "recognizes AI 01 prefix" do
      assert Checksum.looks_like_gs1?("0112345678901234")
    end

    test "recognizes AI 10 prefix" do
      assert Checksum.looks_like_gs1?("10LOT123")
    end

    test "does not match random text" do
      refute Checksum.looks_like_gs1?("Hello World")
    end

    test "handles nil" do
      refute Checksum.looks_like_gs1?(nil)
    end

    test "handles empty string" do
      refute Checksum.looks_like_gs1?("")
    end
  end
end
