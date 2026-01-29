defmodule QrLabelSystem.AccountsTest do
  use QrLabelSystem.DataCase

  alias QrLabelSystem.Accounts
  alias QrLabelSystem.Accounts.User

  import QrLabelSystem.AccountsFixtures

  describe "get_user_by_email/1" do
    test "returns nil if email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "returns nil if email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "Hello123!")
    end

    test "returns nil if password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if email and password are valid" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "register_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_user(%{})
      assert %{email: ["can't be blank"], password: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid", password: "short"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["at least one upper case character", "should be at least 8 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password" do
      too_long = String.duplicate("a", 161)
      {:error, changeset} = Accounts.register_user(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email, password: valid_user_password()})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users with a hashed password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end

    test "defaults role to operator" do
      {:ok, user} = Accounts.register_user(valid_user_attributes())
      assert user.role == "operator"
    end

    test "allows setting role during registration" do
      {:ok, admin} = Accounts.register_user(valid_user_attributes(role: "admin"))
      assert admin.role == "admin"

      {:ok, viewer} = Accounts.register_user(valid_user_attributes(role: "viewer"))
      assert viewer.role == "viewer"
    end

    test "rejects invalid roles" do
      {:error, changeset} = Accounts.register_user(valid_user_attributes(role: "superuser"))
      assert "must be one of: admin, operator, viewer" in errors_on(changeset).role
    end
  end

  describe "User role helpers" do
    test "admin?/1 returns true only for admins" do
      admin = admin_fixture()
      operator = operator_fixture()
      viewer = viewer_fixture()

      assert User.admin?(admin)
      refute User.admin?(operator)
      refute User.admin?(viewer)
    end

    test "operator?/1 returns true for admins and operators" do
      admin = admin_fixture()
      operator = operator_fixture()
      viewer = viewer_fixture()

      assert User.operator?(admin)
      assert User.operator?(operator)
      refute User.operator?(viewer)
    end

    test "viewer?/1 returns true for all authenticated users" do
      admin = admin_fixture()
      operator = operator_fixture()
      viewer = viewer_fixture()

      assert User.viewer?(admin)
      assert User.viewer?(operator)
      assert User.viewer?(viewer)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(Accounts.UserToken, token: token)
      assert user_token.context == "session"

      # Token should not be valid for other contexts
      assert_raise Ecto.NoResultsError, fn ->
        Repo.get_by!(Accounts.UserToken, token: token, context: "reset_password")
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "returns nil for invalid token" do
      refute Accounts.get_user_by_session_token("invalid")
    end

    test "returns nil for expired token", %{token: token} do
      {1, nil} = Repo.update_all(Accounts.UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end
end
