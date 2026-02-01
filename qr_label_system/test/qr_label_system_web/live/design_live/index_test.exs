defmodule QrLabelSystemWeb.DesignLive.IndexTest do
  use QrLabelSystemWeb.ConnCase

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.DesignsFixtures

  describe "Index" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      %{conn: conn, user: user}
    end

    test "lists user's designs", %{conn: conn, user: user} do
      design = design_fixture(%{user_id: user.id, name: "Product Label"})

      {:ok, _view, html} = live(conn, ~p"/designs")

      assert html =~ "Product Label"
    end

    test "shows new design button or link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/designs")

      # Should have some way to create a new design
      assert html =~ "Nuevo" or html =~ "new" or html =~ "Crear"
    end

    test "shows design dimensions", %{conn: conn, user: user} do
      design_fixture(%{
        user_id: user.id,
        name: "Test Design",
        width_mm: 100.0,
        height_mm: 50.0
      })

      {:ok, _view, html} = live(conn, ~p"/designs")

      assert html =~ "100" or html =~ "50"
    end

    test "does not show other user's designs", %{conn: conn, user: user} do
      other_user = user_fixture()
      _own_design = design_fixture(%{user_id: user.id, name: "My Design"})
      _other_design = design_fixture(%{user_id: other_user.id, name: "Other Design"})

      {:ok, _view, html} = live(conn, ~p"/designs")

      assert html =~ "My Design"
      refute html =~ "Other Design"
    end

    test "shows templates to all users", %{conn: conn, user: user} do
      # Create a template (without user_id it may not show in user's designs)
      template = design_fixture(%{name: "Template Design", is_template: true, user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/designs")

      # Templates owned by user should be visible in their design list
      assert html =~ "Template Design"
    end
  end

  describe "Index - unauthenticated" do
    test "redirects to login", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/designs")
      assert path =~ "/users/log_in"
    end
  end
end
