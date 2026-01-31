defmodule QrLabelSystemWeb.UserConfirmationLiveTest do
  use QrLabelSystemWeb.ConnCase

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures

  alias QrLabelSystem.Accounts

  describe "Confirm User" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "renders confirmation page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/confirm/some-token")

      assert html =~ "Confirm" or html =~ "Confirmar"
    end

    test "confirms user with valid token", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, view, _html} = live(conn, ~p"/users/confirm/#{token}")

      view
      |> form("form")
      |> render_submit()

      # Should show success or redirect
      assert_redirect(view, "/") or render(view) =~ "confirmed"
    end

    test "does not confirm with invalid token", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/confirm/invalid-token")

      view
      |> form("form")
      |> render_submit()

      html = render(view)
      assert html =~ "invalid" or html =~ "error" or html =~ "inválido"
    end
  end
end
