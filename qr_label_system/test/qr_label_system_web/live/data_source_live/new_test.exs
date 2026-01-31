defmodule QrLabelSystemWeb.DataSourceLive.NewTest do
  use QrLabelSystemWeb.ConnCase

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures

  describe "New Data Source" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      %{conn: conn, user: user}
    end

    test "displays new data source form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/data-sources/new")

      assert html =~ "Nueva Fuente de Datos" or html =~ "New Data Source"
    end

    test "shows file upload option", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/data-sources/new")

      assert html =~ "xlsx" or html =~ "csv" or html =~ "file"
    end
  end

  describe "New Data Source - unauthenticated" do
    test "redirects to login", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/data-sources/new")
      assert path =~ "/users/log_in"
    end
  end
end
