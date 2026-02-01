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

  describe "Editor - unauthenticated" do
    test "redirects to login", %{conn: conn} do
      design = design_fixture()
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/designs/#{design.id}/edit")
      assert path =~ "/users/log_in"
    end
  end
end
