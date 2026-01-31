defmodule QrLabelSystemWeb.DataSourceLive.IndexTest do
  use QrLabelSystemWeb.ConnCase

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.DataSourcesFixtures

  describe "Index" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      %{conn: conn, user: user}
    end

    test "lists user's data sources", %{conn: conn, user: user} do
      data_source = data_source_fixture(%{user_id: user.id, name: "My Excel Data"})

      {:ok, _view, html} = live(conn, ~p"/data-sources")

      assert html =~ "My Excel Data"
      assert html =~ data_source.type
    end

    test "shows empty state when no data sources", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/data-sources")

      assert html =~ "No tienes fuentes de datos" or html =~ "data-sources/new"
    end

    test "shows new data source button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/data-sources")

      assert html =~ "/data-sources/new"
    end

    test "does not show other user's data sources", %{conn: conn, user: user} do
      other_user = user_fixture()
      _own_source = data_source_fixture(%{user_id: user.id, name: "My Data"})
      _other_source = data_source_fixture(%{user_id: other_user.id, name: "Other Data"})

      {:ok, _view, html} = live(conn, ~p"/data-sources")

      assert html =~ "My Data"
      refute html =~ "Other Data"
    end
  end

  describe "Index - unauthenticated" do
    test "redirects to login", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/data-sources")
      assert path =~ "/users/log_in"
    end
  end
end
