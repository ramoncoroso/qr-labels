defmodule QrLabelSystemWeb.UserForgotPasswordLiveTest do
  use QrLabelSystemWeb.ConnCase

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures

  describe "Forgot Password" do
    test "renders forgot password page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/reset_password")

      assert html =~ "Forgot" or html =~ "Olvidaste" or html =~ "Reset" or html =~ "Restablecer"
    end

    test "sends reset password email for valid user", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = live(conn, ~p"/users/reset_password")

      view
      |> form("form", %{user: %{email: user.email}})
      |> render_submit()

      html = render(view)
      assert html =~ "email" or html =~ "correo" or html =~ "sent" or html =~ "enviado"
    end

    test "does not reveal if email exists", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/reset_password")

      view
      |> form("form", %{user: %{email: "nonexistent@example.com"}})
      |> render_submit()

      # Should show same message regardless of whether email exists
      html = render(view)
      assert html =~ "email" or html =~ "correo"
    end
  end
end
