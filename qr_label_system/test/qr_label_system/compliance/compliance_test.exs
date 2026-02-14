defmodule QrLabelSystem.Compliance.ComplianceTest do
  use QrLabelSystem.DataCase, async: true

  alias QrLabelSystem.Compliance
  alias QrLabelSystem.Compliance.Issue
  alias QrLabelSystem.Designs.Design

  defp make_design(standard, elements \\ []) do
    %Design{
      id: 1,
      name: "Test",
      width_mm: 100.0,
      height_mm: 50.0,
      elements: elements,
      groups: [],
      compliance_standard: standard
    }
  end

  describe "validate/1" do
    test "returns nil for design without compliance standard" do
      assert {nil, []} = Compliance.validate(make_design(nil))
    end

    test "returns nil for empty string standard" do
      assert {nil, []} = Compliance.validate(make_design(""))
    end

    test "returns nil for unknown standard" do
      assert {nil, []} = Compliance.validate(make_design("unknown"))
    end

    test "dispatches to GS1 validator" do
      {name, issues} = Compliance.validate(make_design("gs1"))
      assert name == "GS1"
      assert is_list(issues)
    end

    test "dispatches to EU 1169 validator" do
      {name, issues} = Compliance.validate(make_design("eu1169"))
      assert name == "EU 1169/2011"
      assert is_list(issues)
    end

    test "dispatches to FMD validator" do
      {name, issues} = Compliance.validate(make_design("fmd"))
      assert name =~ "FMD"
      assert is_list(issues)
    end
  end

  describe "available_standards/0" do
    test "returns list of standards with code, name, description" do
      standards = Compliance.available_standards()
      assert length(standards) == 3

      codes = Enum.map(standards, &elem(&1, 0))
      assert "gs1" in codes
      assert "eu1169" in codes
      assert "fmd" in codes
    end
  end

  describe "has_errors?/1" do
    test "returns true when errors present" do
      issues = [Issue.error("TEST", "test error")]
      assert Compliance.has_errors?(issues)
    end

    test "returns false for only warnings" do
      issues = [Issue.warning("TEST", "test warning")]
      refute Compliance.has_errors?(issues)
    end

    test "returns false for empty list" do
      refute Compliance.has_errors?([])
    end
  end

  describe "count_by_severity/1" do
    test "counts issues correctly" do
      issues = [
        Issue.error("E1", "error 1"),
        Issue.error("E2", "error 2"),
        Issue.warning("W1", "warning 1"),
        Issue.info("I1", "info 1")
      ]

      counts = Compliance.count_by_severity(issues)
      assert counts.errors == 2
      assert counts.warnings == 1
      assert counts.infos == 1
    end

    test "returns zeros for empty list" do
      counts = Compliance.count_by_severity([])
      assert counts == %{errors: 0, warnings: 0, infos: 0}
    end
  end

  describe "sort_issues/1" do
    test "sorts errors first, then warnings, then infos" do
      issues = [
        Issue.info("I1", "info"),
        Issue.error("E1", "error"),
        Issue.warning("W1", "warning")
      ]

      sorted = Compliance.sort_issues(issues)
      assert Enum.map(sorted, & &1.severity) == [:error, :warning, :info]
    end
  end

  describe "compliance_role detection" do
    test "EU1169: element with compliance_role is detected without regex match" do
      element = %QrLabelSystem.Designs.Element{
        id: "el_1", type: "text", x: 0, y: 0,
        name: "Campo genérico",
        text_content: "abc",
        compliance_role: "product_name"
      }
      design = make_design("eu1169", [element])
      {_name, issues} = Compliance.validate(design)
      codes = Enum.map(issues, & &1.code)
      refute "EU_MISSING_NAME" in codes
    end

    test "EU1169: element without compliance_role falls back to regex" do
      element = %QrLabelSystem.Designs.Element{
        id: "el_1", type: "text", x: 0, y: 0,
        name: "Nombre del producto",
        text_content: "Denominación",
        compliance_role: nil
      }
      design = make_design("eu1169", [element])
      {_name, issues} = Compliance.validate(design)
      codes = Enum.map(issues, & &1.code)
      refute "EU_MISSING_NAME" in codes
    end

    test "FMD: element with compliance_role is detected without regex match" do
      element = %QrLabelSystem.Designs.Element{
        id: "el_1", type: "text", x: 0, y: 0,
        name: "X",
        text_content: "Y",
        compliance_role: "lot"
      }
      design = make_design("fmd", [element])
      {_name, issues} = Compliance.validate(design)
      codes = Enum.map(issues, & &1.code)
      refute "FMD_MISSING_LOT" in codes
    end

    test "EU1169: fix_actions include compliance_role" do
      design = make_design("eu1169", [])
      {_name, issues} = Compliance.validate(design)
      actions_with_role = Enum.filter(issues, fn issue ->
        issue.fix_action && Map.has_key?(issue.fix_action, :compliance_role)
      end)
      assert length(actions_with_role) > 0
    end
  end

  describe "issues_to_map/1" do
    test "serializes issues to maps" do
      issues = [Issue.error("TEST", "test msg", element_id: "el_1", fix_hint: "fix it")]
      [map] = Compliance.issues_to_map(issues)
      assert map.severity == "error"
      assert map.code == "TEST"
      assert map.message == "test msg"
      assert map.element_id == "el_1"
      assert map.fix_hint == "fix it"
    end
  end
end
