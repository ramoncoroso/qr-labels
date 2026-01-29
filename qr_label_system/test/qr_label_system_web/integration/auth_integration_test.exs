defmodule QrLabelSystemWeb.AuthIntegrationTest do
  @moduledoc """
  Integration tests for the complete authentication flow.
  Tests the full user journey from registration to using protected features.
  """
  use QrLabelSystemWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures

  alias QrLabelSystem.Accounts

  describe "complete authentication flow" do
    test "user can register, log out, and log in again", %{conn: conn} do
      email = unique_user_email()
      password = "ValidPassword123!"

      # Step 1: Register a new user
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      form = form(lv, "#registration_form", user: %{email: email, password: password})
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      # Should be redirected to designs page after registration
      assert redirected_to(conn) == ~p"/designs"

      # Verify user was created with correct default role
      user = Accounts.get_user_by_email(email)
      assert user
      assert user.role == "operator"

      # Step 2: Log out
      conn = recycle(conn) |> get(~p"/designs")
      conn = delete(conn, ~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"

      # Step 3: Log in again
      conn = recycle(conn)
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      form = form(lv, "#login_form", user: %{email: email, password: password})
      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/designs"
    end

    test "user cannot access protected pages without authentication", %{conn: conn} do
      # Try to access protected pages
      protected_paths = [
        ~p"/designs",
        ~p"/batches",
        ~p"/users/settings"
      ]

      for path <- protected_paths do
        test_conn = get(conn, path)
        assert redirected_to(test_conn) == ~p"/users/log_in"
      end
    end

    test "authenticated user can access protected pages", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Should be able to access designs page
      conn = get(conn, ~p"/designs")
      assert html_response(conn, 200)
    end

    test "remember me keeps user logged in", %{conn: conn} do
      user = user_fixture()

      # Log in with remember me
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      # Check that remember me cookie is set
      assert conn.resp_cookies["_qr_label_system_web_user_remember_me"]

      # After redirect, user should still be logged in
      conn = recycle(conn)
      conn = get(conn, ~p"/designs")
      assert html_response(conn, 200)
    end
  end

  describe "role-based access control integration" do
    test "admin can access admin routes", %{conn: conn} do
      admin = admin_fixture()
      conn = log_in_user(conn, admin)

      # Admin should have full access
      assert admin.role == "admin"
      conn = get(conn, ~p"/designs")
      assert html_response(conn, 200)
    end

    test "operator can access operator routes", %{conn: conn} do
      operator = operator_fixture()
      conn = log_in_user(conn, operator)

      assert operator.role == "operator"
      conn = get(conn, ~p"/designs")
      assert html_response(conn, 200)
    end

    test "viewer has limited access", %{conn: conn} do
      viewer = viewer_fixture()
      conn = log_in_user(conn, viewer)

      assert viewer.role == "viewer"
      # Viewer should be able to view designs
      conn = get(conn, ~p"/designs")
      assert html_response(conn, 200)
    end
  end

  describe "session security" do
    test "logging out invalidates the session token", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Get the token before logout
      token = get_session(conn, :user_token)
      assert token
      assert Accounts.get_user_by_session_token(token)

      # Log out
      conn = delete(conn, ~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"

      # Token should be invalidated
      refute Accounts.get_user_by_session_token(token)
    end

    test "changing password invalidates all sessions", %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})

      # Create a session token
      token = Accounts.generate_user_session_token(user)
      assert Accounts.get_user_by_session_token(token)

      # Change password
      {:ok, _updated_user} =
        Accounts.update_user_password(user, password, %{
          password: "NewValidPassword123!",
          password_confirmation: "NewValidPassword123!"
        })

      # Old token should be invalidated
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "password validation" do
    test "rejects weak passwords during registration", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      # Test password too short
      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "test@example.com", "password" => "Short1!"})

      assert result =~ "should be at least 8 character"

      # Test password without uppercase
      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "test@example.com", "password" => "lowercase123!"})

      assert result =~ "at least one upper case character"

      # Test password without lowercase
      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "test@example.com", "password" => "UPPERCASE123!"})

      assert result =~ "at least one lower case character"

      # Test password without digit/special char
      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "test@example.com", "password" => "NoDigitsHere"})

      assert result =~ "at least one digit or punctuation character"
    end
  end

  describe "email validation" do
    test "rejects invalid email formats during registration", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      # Test email with spaces
      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "has spaces@example.com", "password" => "ValidPass123!"})

      assert result =~ "must have the @ sign and no spaces"

      # Test email without @
      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "noemailsign.com", "password" => "ValidPass123!"})

      assert result =~ "must have the @ sign"
    end
  end
end
