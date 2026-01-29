defmodule QrLabelSystemWeb.UserRegistrationLiveTest do
  use QrLabelSystemWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import QrLabelSystem.AccountsFixtures
  import Ecto.Query

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Crear cuenta"
      assert html =~ "Inicia sesión"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, ~p"/designs")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces"})

      assert result =~ "must have the @ sign and no spaces"
    end
  end

  describe "register user" do
    test "creates account when form is submitted", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      # Submit the form
      lv
      |> form("#registration_form", user: %{"email" => email})
      |> render_submit()

      # Verify user was created
      user = QrLabelSystem.Accounts.get_user_by_email(email)
      assert user
      assert user.role == "operator"
      # User should be confirmed since we auto-confirm passwordless users
      assert user.confirmed_at
    end

    test "creates magic link token when form is submitted", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      # Submit the form
      lv
      |> form("#registration_form", user: %{"email" => email})
      |> render_submit()

      # Verify magic link token was created
      user = QrLabelSystem.Accounts.get_user_by_email(email)
      assert user

      # Check that a magic_link token exists for this user
      token_record =
        QrLabelSystem.Repo.one(
          from t in QrLabelSystem.Accounts.UserToken,
            where: t.user_id == ^user.id and t.context == "magic_link"
        )

      assert token_record
    end

    test "sends magic link for existing user without revealing existence", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "existing@email.com"})

      # Clear any existing magic link tokens
      QrLabelSystem.Repo.delete_all(
        from t in QrLabelSystem.Accounts.UserToken,
          where: t.user_id == ^user.id and t.context == "magic_link"
      )

      lv
      |> form("#registration_form", user: %{"email" => user.email})
      |> render_submit()

      # Check that a magic_link token was created for existing user
      token_record =
        QrLabelSystem.Repo.one(
          from t in QrLabelSystem.Accounts.UserToken,
            where: t.user_id == ^user.id and t.context == "magic_link"
        )

      assert token_record
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element(~s|main a:fl-contains("Inicia sesión")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log_in")

      assert login_html =~ "Bienvenido"
    end
  end
end
