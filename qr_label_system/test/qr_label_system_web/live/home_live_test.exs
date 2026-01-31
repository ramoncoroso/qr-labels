defmodule QrLabelSystemWeb.HomeLiveTest do
  use QrLabelSystemWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures

  describe "Home page" do
    test "renders login form for unauthenticated users", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "QR Label System"
      assert html =~ "Continuar"
      assert html =~ "Email"
    end

    test "redirects authenticated users to generate", %{conn: conn} do
      user = user_fixture()

      result =
        conn
        |> log_in_user(user)
        |> live(~p"/")
        |> follow_redirect(conn, ~p"/generate")

      assert {:ok, _conn} = result
    end
  end

  describe "magic link login from home" do
    test "shows success message after sending magic link", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/")

      result =
        lv
        |> form("form", email: user.email)
        |> render_submit()

      assert result =~ "Revisa tu correo"
      assert result =~ user.email
    end

    test "shows success message even for non-existent email (prevents enumeration)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      result =
        lv
        |> form("form", email: "nonexistent@email.com")
        |> render_submit()

      # Should still show success message to prevent email enumeration
      assert result =~ "Revisa tu correo"
    end

    test "can reset and use different email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      # Send magic link
      lv
      |> form("form", email: "first@email.com")
      |> render_submit()

      # Click reset button
      result =
        lv
        |> element("button", "Usar otro email")
        |> render_click()

      # Should show login form again
      assert result =~ "Continuar"
      refute result =~ "Revisa tu correo"
    end
  end
end
