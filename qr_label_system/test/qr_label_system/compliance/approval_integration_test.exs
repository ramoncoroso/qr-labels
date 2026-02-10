defmodule QrLabelSystem.Compliance.ApprovalIntegrationTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.Designs

  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.DesignsFixtures

  describe "request_review blocks on compliance errors" do
    test "blocks request_review when GS1 design has errors" do
      user = user_fixture()
      # Create design with GS1 standard and a barcode with invalid checksum
      design = design_fixture(%{
        user_id: user.id,
        compliance_standard: "gs1",
        elements: [
          barcode_element_attrs(%{
            barcode_format: "EAN13",
            text_content: "1234567890123"
          })
        ]
      })

      assert {:error, msg} = Designs.request_review(design, user)
      assert msg =~ "cumplimiento normativo"
    end

    test "allows request_review when GS1 design passes" do
      user = user_fixture()
      # 4006381333931 is a valid EAN-13
      design = design_fixture(%{
        user_id: user.id,
        compliance_standard: "gs1",
        elements: [
          barcode_element_attrs(%{
            barcode_format: "EAN13",
            text_content: "4006381333931"
          })
        ]
      })

      assert {:ok, updated} = Designs.request_review(design, user)
      assert updated.status == "pending_review"
    end

    test "allows request_review when no compliance standard set" do
      user = user_fixture()
      design = design_fixture(%{user_id: user.id})

      assert {:ok, updated} = Designs.request_review(design, user)
      assert updated.status == "pending_review"
    end

    test "warnings do not block request_review" do
      user = user_fixture()
      # GS1 design with no barcodes → only warning, no errors
      design = design_fixture(%{
        user_id: user.id,
        compliance_standard: "gs1",
        elements: [
          text_element_attrs()
        ]
      })

      assert {:ok, _} = Designs.request_review(design, user)
    end
  end

  describe "approve_design blocks on compliance errors" do
    test "blocks approve when GS1 design has errors" do
      user = user_fixture()
      admin = user_fixture(%{email: "admin_#{System.unique_integer()}@example.com", role: "admin"})

      design = design_fixture(%{
        user_id: user.id,
        compliance_standard: "gs1",
        status: "pending_review",
        elements: [
          barcode_element_attrs(%{
            barcode_format: "EAN13",
            text_content: "1234567890123"
          })
        ]
      })

      assert {:error, msg} = Designs.approve_design(design, admin)
      assert msg =~ "cumplimiento normativo"
    end

    test "allows approve when compliance passes" do
      user = user_fixture()
      admin = user_fixture(%{email: "admin_#{System.unique_integer()}@example.com", role: "admin"})

      design = design_fixture(%{
        user_id: user.id,
        compliance_standard: "gs1",
        status: "pending_review",
        elements: [
          barcode_element_attrs(%{
            barcode_format: "EAN13",
            text_content: "4006381333931"
          })
        ]
      })

      assert {:ok, updated} = Designs.approve_design(design, admin)
      assert updated.status == "approved"
    end

    test "allows approve when no compliance standard" do
      user = user_fixture()
      admin = user_fixture(%{email: "admin_#{System.unique_integer()}@example.com", role: "admin"})

      design = design_fixture(%{
        user_id: user.id,
        status: "pending_review"
      })

      assert {:ok, _} = Designs.approve_design(design, admin)
    end
  end
end
