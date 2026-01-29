defmodule QrLabelSystemWeb.UserSessionControllerTest do
  use QrLabelSystemWeb.ConnCase, async: true

  import QrLabelSystem.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "POST /users/log_in" do
    test "logs the user in", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/designs"

      # Verify user can access protected page
      conn = get(conn, ~p"/designs")
      response = html_response(conn, 200)
      assert response =~ "Diseños" or response =~ "designs"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_qr_label_system_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/designs"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/batches")
        |> post(~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/batches"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Bienvenido"
    end

    test "login following registration", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in?_action=registered", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == ~p"/designs"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "exitosamente"
    end

    test "login following password update", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in?_action=password_updated", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Contraseña actualizada"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => "invalid@email.com", "password" => "wrong_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "inválidos"
      assert redirected_to(conn) == ~p"/users/log_in"
    end

    test "redirects to login page with missing credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => ""}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "inválidos"
      assert redirected_to(conn) == ~p"/users/log_in"
    end
  end

  describe "DELETE /users/log_out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "cerrada"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
    end
  end
end
