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
      |> form("#reset_password_form", %{user: %{email: user.email}})
      |> render_submit()

      # The form redirects after submit
      flash = assert_redirect(view, "/")
      assert flash["info"] =~ "email" or flash["info"] =~ "correo" or flash["info"] =~ "instrucciones"
    end

    test "does not reveal if email exists", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/reset_password")

      view
      |> form("#reset_password_form", %{user: %{email: "nonexistent@example.com"}})
      |> render_submit()

      # Should show same message regardless of whether email exists (redirect happens)
      flash = assert_redirect(view, "/")
      assert flash["info"] =~ "email" or flash["info"] =~ "correo" or flash["info"] =~ "instrucciones"
    end
  end
end
