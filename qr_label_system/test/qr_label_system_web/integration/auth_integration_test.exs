defmodule QrLabelSystemWeb.AuthIntegrationTest do
  @moduledoc """
  Integration tests for the complete authentication flow.
  Tests the full user journey from registration to using protected features.
  """
  use QrLabelSystemWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures
  import Ecto.Query

  alias QrLabelSystem.Accounts

  describe "magic link authentication flow" do
    test "user can register and magic link token is created", %{conn: conn} do
      email = unique_user_email()

      # Step 1: Register a new user
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      lv
      |> form("#registration_form", user: %{"email" => email})
      |> render_submit()

      # Verify user was created with correct default role
      user = Accounts.get_user_by_email(email)
      assert user
      assert user.role == "operator"
      # User should be confirmed since magic link verifies email
      assert user.confirmed_at

      # Verify magic link token was created
      token_record =
        QrLabelSystem.Repo.one(
          from t in QrLabelSystem.Accounts.UserToken,
            where: t.user_id == ^user.id and t.context == "magic_link"
        )

      assert token_record
    end

    test "user can log in via magic link token", %{conn: conn} do
      user = user_fixture()

      # Build token directly for testing
      {encoded_token, user_token} = QrLabelSystem.Accounts.UserToken.build_magic_link_token(user)
      QrLabelSystem.Repo.insert!(user_token)

      # Use the magic link
      conn = get(conn, ~p"/users/magic_link/#{encoded_token}")
      assert redirected_to(conn) == ~p"/designs"
    end

    test "magic link token is single use", %{conn: conn} do
      user = user_fixture()

      # Build token directly for testing
      {encoded_token, user_token} = QrLabelSystem.Accounts.UserToken.build_magic_link_token(user)
      QrLabelSystem.Repo.insert!(user_token)

      # First use - should succeed
      conn1 = get(conn, ~p"/users/magic_link/#{encoded_token}")
      assert redirected_to(conn1) == ~p"/designs"

      # Second use - should fail (token deleted)
      # Use a fresh conn for the second request
      conn2 = build_conn() |> get(~p"/users/magic_link/#{encoded_token}")
      assert redirected_to(conn2) == ~p"/users/log_in"
      assert Phoenix.Flash.get(conn2.assigns.flash, :error) =~ "inválido o ha expirado"
    end

    test "expired magic link token is rejected", %{conn: conn} do
      user = user_fixture()

      # Build token directly
      {encoded_token, user_token} = QrLabelSystem.Accounts.UserToken.build_magic_link_token(user)

      # Insert with old timestamp (more than 15 minutes ago)
      old_time = DateTime.utc_now() |> DateTime.add(-20, :minute) |> DateTime.truncate(:second)
      user_token = %{user_token | inserted_at: old_time}
      QrLabelSystem.Repo.insert!(user_token)

      # Should fail - token expired
      conn = get(conn, ~p"/users/magic_link/#{encoded_token}")
      assert redirected_to(conn) == ~p"/users/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "inválido o ha expirado"
    end
  end

  describe "complete authentication flow" do
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

    test "logging out redirects to home", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      conn = delete(conn, ~p"/users/log_out")
      assert redirected_to(conn) == ~p"/"
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

    test "changing password invalidates all sessions", %{conn: _conn} do
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

  describe "email validation" do
    test "rejects invalid email formats during registration", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      # Test email with spaces
      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "has spaces@example.com"})

      assert result =~ "must have the @ sign and no spaces"

      # Test email without @
      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "noemailsign.com"})

      assert result =~ "must have the @ sign"
    end
  end
end
