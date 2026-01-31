defmodule QrLabelSystemWeb.PageControllerTest do
  use QrLabelSystemWeb.ConnCase

  import QrLabelSystem.AccountsFixtures

  describe "home/2" do
    test "redirects when logged in" do
      conn =
        build_conn()
        |> log_in_user(user_fixture())
        |> get(~p"/")

      # Redirects to either /designs or /generate depending on config
      assert redirected_to(conn) in [~p"/designs", ~p"/generate"]
    end

    test "renders home page when not logged in" do
      conn = get(build_conn(), ~p"/")

      assert html_response(conn, 200)
    end
  end
end
