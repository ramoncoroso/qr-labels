defmodule QrLabelSystemWeb.UserLoginLiveTest do
  use QrLabelSystemWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures

  describe "Log in page" do
    test "renders log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log_in")

      assert html =~ "Bienvenido"
      assert html =~ "Regístrate"
      assert html =~ "Enviar enlace de acceso"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/log_in")
        |> follow_redirect(conn, ~p"/designs")

      assert {:ok, _conn} = result
    end
  end

  describe "magic link login" do
    test "shows success message after sending magic link", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      result =
        lv
        |> form("#login_form", user: %{email: user.email})
        |> render_submit()

      assert result =~ "Revisa tu correo"
      assert result =~ user.email
    end

    test "shows success message even for non-existent email (prevents enumeration)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      result =
        lv
        |> form("#login_form", user: %{email: "nonexistent@email.com"})
        |> render_submit()

      # Should still show success message to prevent email enumeration
      assert result =~ "Revisa tu correo"
    end

    test "can reset and use different email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      # Send magic link
      lv
      |> form("#login_form", user: %{email: "first@email.com"})
      |> render_submit()

      # Click reset button
      result =
        lv
        |> element("button", "Usar otro email")
        |> render_click()

      # Should show login form again
      assert result =~ "Enviar enlace de acceso"
      refute result =~ "Revisa tu correo"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      {:ok, _login_live, login_html} =
        lv
        |> element(~s|main a:fl-contains("Regístrate")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/users/register")

      assert login_html =~ "Crear cuenta"
    end
  end
end
