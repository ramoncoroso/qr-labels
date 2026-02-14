defmodule QrLabelSystemWeb.DesignLive.EditorTest do
  use QrLabelSystemWeb.ConnCase

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.DesignsFixtures

  describe "Editor" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      design = design_fixture(%{
        user_id: user.id,
        name: "Editor Test",
        width_mm: 100.0,
        height_mm: 50.0
      })
      %{conn: conn, user: user, design: design}
    end

    test "displays editor interface", %{conn: conn, design: design} do
      {:ok, _view, html} = live(conn, ~p"/designs/#{design.id}/edit")

      assert html =~ "Editor Test"
    end

    test "shows toolbar with element types", %{conn: conn, design: design} do
      {:ok, _view, html} = live(conn, ~p"/designs/#{design.id}/edit")

      # Should show element type buttons
      assert html =~ "QR" or html =~ "qr"
      assert html =~ "Texto" or html =~ "text"
    end

    test "shows canvas area", %{conn: conn, design: design} do
      {:ok, _view, html} = live(conn, ~p"/designs/#{design.id}/edit")

      assert html =~ "canvas" or html =~ "editor"
    end

    test "shows save button", %{conn: conn, design: design} do
      {:ok, _view, html} = live(conn, ~p"/designs/#{design.id}/edit")

      assert html =~ "Guardar" or html =~ "Save"
    end
  end

  describe "Editor - elements" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      design = design_fixture(%{
        user_id: user.id,
        elements: [
          %{id: "el_1", type: "qr", x: 10, y: 10, width: 20, height: 20},
          %{id: "el_2", type: "text", x: 35, y: 10, width: 50, height: 10, text_content: "Hello"}
        ]
      })
      %{conn: conn, user: user, design: design}
    end

    test "displays existing elements", %{conn: conn, design: design} do
      {:ok, _view, html} = live(conn, ~p"/designs/#{design.id}/edit")

      # Elements should be rendered
      assert html =~ "el_1" or html =~ "qr"
    end
  end

  describe "Editor - access control" do
    test "cannot edit other user's design", %{conn: conn} do
      other_user = user_fixture()
      other_design = design_fixture(%{user_id: other_user.id})

      user = user_fixture()
      conn = log_in_user(conn, user)

      result = live(conn, ~p"/designs/#{other_design.id}/edit")

      case result do
        {:error, {:redirect, _}} -> assert true
        {:error, {:live_redirect, _}} -> assert true
        {:ok, view, _html} ->
          # If allowed, should be read-only or redirected
          html = render(view)
          refute html =~ "Guardar"
      end
    end
  end

  describe "Editor - compliance semaphore" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      design = design_fixture(%{
        user_id: user.id,
        name: "Compliance Test",
        width_mm: 100.0,
        height_mm: 50.0
      })
      %{conn: conn, user: user, design: design}
    end

    test "semaphore starts gray with no standard", %{conn: conn, design: design} do
      {:ok, _view, html} = live(conn, ~p"/designs/#{design.id}/edit")

      # Should show gray semaphore (no standard selected)
      assert html =~ "bg-gray-300"
      assert html =~ "Sin norma seleccionada"
    end

    test "semaphore changes color when standard is selected", %{conn: conn, design: design} do
      {:ok, view, html} = live(conn, ~p"/designs/#{design.id}/edit")

      # Initially gray - no standard selected
      assert html =~ "Sin norma seleccionada"

      # Select GS1 standard
      html = render_change(view, "set_compliance_standard", %{"standard" => "gs1"})

      # Should show GS1 name and amber warning indicator
      assert html =~ "GS1"
      assert html =~ "bg-amber-400"
      # Should show warning count
      assert html =~ "aviso"
    end

    test "semaphore shows red for EU 1169 with empty design", %{conn: conn, design: design} do
      {:ok, view, _html} = live(conn, ~p"/designs/#{design.id}/edit")

      html = render_change(view, "set_compliance_standard", %{"standard" => "eu1169"})

      # EU 1169 with no elements = 5 errors → red
      assert html =~ "bg-red-500"
      assert html =~ "EU 1169/2011"
    end

    test "semaphore shows red for FMD with empty design", %{conn: conn, design: design} do
      {:ok, view, _html} = live(conn, ~p"/designs/#{design.id}/edit")

      html = render_change(view, "set_compliance_standard", %{"standard" => "fmd"})

      # FMD with no elements = 7 errors → red
      assert html =~ "bg-red-500"
      assert html =~ "FMD"
    end

    test "semaphore goes back to gray when standard is cleared", %{conn: conn, design: design} do
      {:ok, view, _html} = live(conn, ~p"/designs/#{design.id}/edit")

      # Select a standard
      render_change(view, "set_compliance_standard", %{"standard" => "gs1"})

      # Clear standard
      html = render_change(view, "set_compliance_standard", %{"standard" => ""})

      assert html =~ "bg-gray-300"
      assert html =~ "Sin norma seleccionada"
    end
  end

  describe "Editor - unauthenticated" do
    test "redirects to login", %{conn: conn} do
      design = design_fixture()
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/designs/#{design.id}/edit")
      assert path =~ "/users/log_in"
    end
  end
end
