defmodule QrLabelSystemWeb.DesignLive.NewTest do
  use QrLabelSystemWeb.ConnCase

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures

  describe "New Design" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      %{conn: conn, user: user}
    end

    test "displays new design form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/designs/new")

      assert html =~ "Nuevo Diseño" or html =~ "New Design"
    end

    test "shows dimension inputs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/designs/new")

      assert html =~ "width" or html =~ "ancho"
      assert html =~ "height" or html =~ "alto"
    end

    test "shows name input", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/designs/new")

      assert html =~ "name" or html =~ "nombre"
    end
  end

  describe "New Design - unauthenticated" do
    test "redirects to login", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/designs/new")
      assert path =~ "/users/log_in"
    end
  end
end
