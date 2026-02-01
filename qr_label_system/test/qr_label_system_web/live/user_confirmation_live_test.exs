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
      |> form("#confirmation_form")
      |> render_submit()

      # Should redirect after confirmation
      flash = assert_redirect(view, "/")
      assert flash["info"] =~ "confirmado" or flash["info"] =~ "confirmed"
    end

    test "does not confirm with invalid token", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/confirm/invalid-token")

      view
      |> form("#confirmation_form")
      |> render_submit()

      # Should redirect with error flash
      flash = assert_redirect(view, "/")
      assert flash["error"] =~ "inválido" or flash["error"] =~ "invalid" or flash["error"] =~ "expirado"
    end
  end
end
