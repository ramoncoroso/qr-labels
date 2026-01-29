defmodule QrLabelSystem.PaginationTest do
  use ExUnit.Case, async: true

  alias QrLabelSystem.Pagination

  describe "parse_int/2" do
    test "parses valid integer strings" do
      assert Pagination.parse_int("123", 0) == 123
      assert Pagination.parse_int("1", 0) == 1
      assert Pagination.parse_int("999", 0) == 999
    end

    test "returns default for invalid strings" do
      assert Pagination.parse_int("abc", 10) == 10
      assert Pagination.parse_int("", 5) == 5
      assert Pagination.parse_int("12.5", 0) == 12  # Stops at decimal
    end

    test "handles integers directly" do
      assert Pagination.parse_int(42, 0) == 42
      assert Pagination.parse_int(100, 0) == 100
    end

    test "returns default for nil" do
      assert Pagination.parse_int(nil, 15) == 15
    end
  end

  describe "parse_positive_int/2" do
    test "returns positive integers" do
      assert Pagination.parse_positive_int("5", 1) == 5
      assert Pagination.parse_positive_int(10, 1) == 10
    end

    test "returns default for zero" do
      assert Pagination.parse_positive_int("0", 1) == 1
      assert Pagination.parse_positive_int(0, 5) == 5
    end

    test "returns default for negative numbers" do
      assert Pagination.parse_positive_int("-5", 1) == 1
      assert Pagination.parse_positive_int(-10, 3) == 3
    end
  end

  describe "parse_page/1" do
    test "parses page from string params" do
      assert Pagination.parse_page(%{"page" => "2"}) == 2
      assert Pagination.parse_page(%{"page" => "10"}) == 10
    end

    test "parses page from atom params" do
      assert Pagination.parse_page(%{page: "3"}) == 3
      assert Pagination.parse_page(%{page: 5}) == 5
    end

    test "returns default page 1 for missing or invalid" do
      assert Pagination.parse_page(%{}) == 1
      assert Pagination.parse_page(%{"page" => ""}) == 1
      assert Pagination.parse_page(%{"page" => "abc"}) == 1
      assert Pagination.parse_page(%{"page" => "0"}) == 1
      assert Pagination.parse_page(%{"page" => "-1"}) == 1
    end
  end

  describe "parse_per_page/1" do
    test "parses per_page from string params" do
      assert Pagination.parse_per_page(%{"per_page" => "50"}) == 50
    end

    test "parses per_page from atom params" do
      assert Pagination.parse_per_page(%{per_page: "25"}) == 25
      assert Pagination.parse_per_page(%{per_page: 30}) == 30
    end

    test "returns default 20 for missing or invalid" do
      assert Pagination.parse_per_page(%{}) == 20
      assert Pagination.parse_per_page(%{"per_page" => ""}) == 20
      assert Pagination.parse_per_page(%{"per_page" => "abc"}) == 20
    end

    test "caps at maximum 100" do
      assert Pagination.parse_per_page(%{"per_page" => "500"}) == 100
      assert Pagination.parse_per_page(%{"per_page" => "200"}) == 100
    end
  end
end
