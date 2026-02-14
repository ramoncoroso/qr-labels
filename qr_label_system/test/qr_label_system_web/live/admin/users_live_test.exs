defmodule QrLabelSystemWeb.Admin.UsersLiveTest do
  use QrLabelSystemWeb.ConnCase

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures

  describe "User Management" do
    setup %{conn: conn} do
      admin = admin_fixture()
      conn = log_in_user(conn, admin)
      %{conn: conn, admin: admin}
    end

    test "displays user list", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ "User Management"
      assert html =~ user.email
    end

    test "displays user roles", %{conn: conn} do
      _operator = operator_fixture()
      _viewer = viewer_fixture()

      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ "Operator"
      assert html =~ "Viewer"
    end

    test "filters by role", %{conn: conn} do
      _operator = operator_fixture()
      _viewer = viewer_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      # Use the form with phx-change instead of the select directly
      view
      |> form("form[phx-change=filter_role]", %{role: "operator"})
      |> render_change()

      # Should still show operator (filter via patch)
      assert view |> render() =~ "operator"
    end

    test "searches by email", %{conn: conn} do
      _user = user_fixture(%{email: "searchable@example.com"})

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      _html = view
        |> form("form[phx-submit=search]", %{search: "searchable"})
        |> render_submit()

      # Search triggers push_patch
      assert_patch(view)
    end

    test "opens edit modal", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view
      |> element("button[phx-click=edit_user][phx-value-id=#{user.id}]")
      |> render_click()

      html = render(view)
      assert html =~ "Edit User Role"
      assert html =~ user.email
    end

    test "closes edit modal", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      # Open modal
      view
      |> element("button[phx-click=edit_user][phx-value-id=#{user.id}]")
      |> render_click()

      # Close modal
      view
      |> element("button[phx-click=close_modal]")
      |> render_click()

      html = render(view)
      refute html =~ "Edit User Role"
    end

    test "updates user role", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      # Open modal
      view
      |> element("button[phx-click=edit_user][phx-value-id=#{user.id}]")
      |> render_click()

      # Update role - use the modal form with phx-submit=update_role
      view
      |> form("form[phx-submit=update_role]", %{user: %{role: "operator"}})
      |> render_submit()

      html = render(view)
      assert html =~ "User role updated successfully"
    end

    test "cannot delete own account", %{conn: conn, admin: admin} do
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      # Try to delete self - button shouldn't exist
      html = render(view)
      refute html =~ "phx-click=\"delete_user\" phx-value-id=\"#{admin.id}\""
    end

    test "can delete other user", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view
      |> element("button[phx-click=delete_user][phx-value-id=#{user.id}]")
      |> render_click()

      html = render(view)
      assert html =~ "User deleted successfully"
    end
  end

  describe "User Management - access control" do
    test "non-admin cannot access user management", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/users")
      assert path == "/"
    end
  end
end
