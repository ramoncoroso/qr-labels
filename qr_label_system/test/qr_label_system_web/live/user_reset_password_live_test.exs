defmodule QrLabelSystemWeb.UserResetPasswordLiveTest do
  use QrLabelSystemWeb.ConnCase

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures

  alias QrLabelSystem.Accounts

  describe "Reset Password" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "renders reset password page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/reset_password/some-token")

      assert html =~ "Reset" or html =~ "Restablecer" or html =~ "password" or html =~ "contraseña"
    end

    test "renders errors for invalid data", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, view, _html} = live(conn, ~p"/users/reset_password/#{token}")

      # Try with short password
      result =
        view
        |> form("form", %{user: %{password: "short", password_confirmation: "short"}})
        |> render_submit()

      assert result =~ "at least" or result =~ "mínimo" or result =~ "error"
    end

    test "renders errors for mismatched passwords", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, view, _html} = live(conn, ~p"/users/reset_password/#{token}")

      result =
        view
        |> form("form", %{user: %{password: "ValidPass123!", password_confirmation: "Different123!"}})
        |> render_submit()

      assert result =~ "match" or result =~ "coincide" or result =~ "error"
    end

    test "resets password with valid token and data", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, view, _html} = live(conn, ~p"/users/reset_password/#{token}")

      view
      |> form("form", %{user: %{password: "NewPassword123!", password_confirmation: "NewPassword123!"}})
      |> render_submit()

      # Should redirect to login
      assert_redirect(view, ~p"/users/log_in")
    end

    test "shows error for invalid token", %{conn: conn} do
      result = live(conn, ~p"/users/reset_password/invalid-token")

      case result do
        {:ok, view, _html} ->
          view
          |> form("form", %{user: %{password: "ValidPass123!", password_confirmation: "ValidPass123!"}})
          |> render_submit()

          html = render(view)
          assert html =~ "invalid" or html =~ "inválido" or html =~ "error" or html =~ "expired"

        {:error, {:redirect, %{flash: flash}}} ->
          # Redirect with error flash is also valid
          assert flash["error"] =~ "inválido" or flash["error"] =~ "expirado"
      end
    end
  end
end
