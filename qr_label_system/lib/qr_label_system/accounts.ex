defmodule QrLabelSystem.Accounts do
  @moduledoc """
  The Accounts context.
  Handles user management, authentication, and authorization.
  """

  import Ecto.Query, warn: false
  alias QrLabelSystem.Repo
  alias QrLabelSystem.Accounts.{User, UserToken, UserNotifier}

  ## User queries

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Lists all users.
  """
  def list_users do
    Repo.all(from u in User, order_by: [asc: u.email])
  end

  @doc """
  Lists users with pagination, search, and role filtering.
  Optimized to avoid N+1 queries.
  """
  def list_users(params) do
    page = params |> Map.get("page", "1") |> parse_integer(1)
    per_page = params |> Map.get("per_page", "20") |> parse_integer(20)
    search = Map.get(params, "search", "")
    role = Map.get(params, "role")
    offset = (page - 1) * per_page

    base_query = from u in User

    # Apply search filter (sanitized)
    base_query = if search != "" do
      search_term = sanitize_search_term(search)
      from u in base_query, where: ilike(u.email, ^"%#{search_term}%")
    else
      base_query
    end

    # Apply role filter
    base_query = if role && role != "" do
      from u in base_query, where: u.role == ^role
    else
      base_query
    end

    # Get total count (single query)
    total = Repo.aggregate(base_query, :count)

    # Get paginated users (single query)
    users =
      base_query
      |> order_by([u], asc: u.email)
      |> limit(^per_page)
      |> offset(^offset)
      |> Repo.all()

    %{
      users: users,
      page: page,
      per_page: per_page,
      total: total,
      total_pages: max(ceil(total / per_page), 1)
    }
  end

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end
  defp parse_integer(value, _default) when is_integer(value) and value > 0, do: value
  defp parse_integer(_, default), do: default

  # Sanitize search input to prevent SQL injection via LIKE patterns
  defp sanitize_search_term(term) do
    term
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
    |> String.slice(0, 100)  # Limit search term length
  end

  @doc """
  Returns a changeset for changing the user role.
  """
  def change_user_role(%User{} = user, attrs \\ %{}) do
    User.role_changeset(user, attrs)
  end

  ## User registration

  @doc """
  Registers a user.
  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Registers a user without password (for magic link auth).
  Marks user as confirmed since we verified their email via magic link.
  """
  def register_user_passwordless(attrs) do
    %User{}
    |> User.passwordless_registration_changeset(attrs)
    |> User.confirm_changeset()
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking passwordless user changes.
  """
  def change_user_passwordless_registration(%User{} = user, attrs \\ %{}) do
    User.passwordless_registration_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## User updates

  @doc """
  Updates a user's role.
  """
  def update_user_role(%User{} = user, attrs) do
    user
    |> User.role_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.
  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Updates the user email using the given token.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_email_token_query(token, context),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(change_user_email_multi(user, user.email)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp change_user_email_multi(user, email) do
    changeset = user |> User.email_changeset(%{email: email}) |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["change:#{email}"]))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.
  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.
  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Confirms a user by the given token.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["confirm"]))
  end

  ## Magic Link Authentication

  @doc """
  Delivers magic link instructions to the given user.
  If the user doesn't exist, it returns :ok anyway to prevent email enumeration.
  """
  def deliver_magic_link_instructions(email, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    case get_user_by_email(email) do
      %User{} = user ->
        {encoded_token, user_token} = UserToken.build_magic_link_token(user)
        Repo.insert!(user_token)
        UserNotifier.deliver_magic_link_instructions(user, magic_link_url_fun.(encoded_token))

      nil ->
        # Return :ok anyway to prevent email enumeration
        {:ok, :not_found}
    end
  end

  @doc """
  Gets the user by magic link token and validates it.
  Returns the user if the token is valid, nil otherwise.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Deletes the magic link token (single use).
  """
  def delete_magic_link_token(token) do
    case UserToken.magic_link_token_query(token) do
      {:ok, query} -> Repo.delete_all(query)
      :error -> :error
    end
  end

  ## Email delivery

  @doc """
  Delivers the confirmation instructions to the given user.
  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
    Repo.insert!(user_token)
    UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
  end

  @doc """
  Delivers the reset password instructions to the given user.
  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Delivers the update email instructions to the given user.
  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")
    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Applies the given email change to the user.
  Returns {:ok, applied_user} if successful, {:error, changeset} otherwise.
  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  ## Reset password

  @doc """
  Gets the user by reset password token.
  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.
  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end
end
