defmodule QrLabelSystemWeb.Admin.AuditLiveTest do
  use QrLabelSystemWeb.ConnCase

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures
  import QrLabelSystem.AuditFixtures

  describe "Audit Log" do
    setup %{conn: conn} do
      admin = admin_fixture()
      conn = log_in_user(conn, admin)
      %{conn: conn, admin: admin}
    end

    test "displays audit log page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/audit")

      assert html =~ "Audit Log"
      assert html =~ "Export CSV"
      assert html =~ "Export JSON"
    end

    test "displays log entries", %{conn: conn, admin: admin} do
      log = audit_log_fixture(%{user_id: admin.id})

      {:ok, _view, html} = live(conn, ~p"/admin/audit")

      assert html =~ log.action
      assert html =~ log.resource_type
    end

    test "displays stats summary", %{conn: conn} do
      audit_log_fixture()

      {:ok, _view, html} = live(conn, ~p"/admin/audit")

      assert html =~ "Total Events"
      assert html =~ "Actions"
      assert html =~ "Resource Types"
    end

    test "filters by date range", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/audit")

      today = Date.utc_today() |> Date.to_iso8601()

      view
      |> form("form", %{
        filters: %{
          from: today,
          to: today
        }
      })
      |> render_submit()

      assert_patch(view)
    end

    test "filters by action", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/audit")

      view
      |> form("form", %{filters: %{action: "login"}})
      |> render_submit()

      assert_patch(view)
    end

    test "filters by resource type", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/audit")

      view
      |> form("form", %{filters: %{resource_type: "user"}})
      |> render_submit()

      assert_patch(view)
    end

    test "clears filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/audit?action=login")

      view
      |> element("button[phx-click=clear_filters]")
      |> render_click()

      assert_patch(view, ~p"/admin/audit")
    end

    test "displays empty state when no logs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/audit?action=nonexistent")

      assert html =~ "No audit logs found"
    end

    test "paginates results", %{conn: conn} do
      for _ <- 1..60, do: audit_log_fixture()

      {:ok, view, html} = live(conn, ~p"/admin/audit")

      assert html =~ "Next"

      # Go to next page
      view
      |> element("a", "Next")
      |> render_click()

      assert_patch(view, ~p"/admin/audit?page=2")
    end
  end

  describe "Audit Log - export" do
    setup %{conn: conn} do
      admin = admin_fixture()
      conn = log_in_user(conn, admin)
      audit_log_fixture(%{user_id: admin.id})
      %{conn: conn, admin: admin}
    end

    test "exports CSV", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/audit")

      view
      |> element("button[phx-click=export_csv]")
      |> render_click()

      # Should push download event
      assert_push_event(view, "download", %{
        filename: filename,
        content_type: "text/csv"
      })

      assert filename =~ "audit_logs_"
      assert filename =~ ".csv"
    end

    test "exports JSON", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/audit")

      view
      |> element("button[phx-click=export_json]")
      |> render_click()

      assert_push_event(view, "download", %{
        filename: filename,
        content_type: "application/json"
      })

      assert filename =~ "audit_logs_"
      assert filename =~ ".json"
    end
  end

  describe "Audit Log - access control" do
    test "non-admin cannot access audit log", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/audit")
      assert path == "/"
    end
  end
end
