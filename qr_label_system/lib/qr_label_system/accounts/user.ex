defmodule QrLabelSystem.Accounts.User do
  @moduledoc """
  User schema with role-based access control.

  Roles:
  - admin: Full access to all features including user management
  - operator: Can create designs, import data, generate and print labels
  - viewer: Read-only access to designs and batches
  """
  use Ecto.Schema
  import Ecto.Changeset

  @roles ~w(admin operator viewer)

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :role, :string, default: "operator"
    field :confirmed_at, :naive_datetime

    has_many :designs, QrLabelSystem.Designs.Design
    has_many :batches, QrLabelSystem.Batches.Batch

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :role])
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_role()
  end

  @doc """
  A user changeset for passwordless registration (magic link).
  Generates a random secure password since the DB requires hashed_password.
  Users authenticate via magic links, not passwords.
  """
  def passwordless_registration_changeset(user, attrs, opts \\ []) do
    # Generate a random 32-byte password (produces ~44 char base64 string)
    # Users won't use this, they authenticate via magic links
    random_password = :crypto.strong_rand_bytes(32) |> Base.encode64()

    user
    |> cast(attrs, [:email, :role])
    |> put_change(:password, random_password)
    |> validate_email(opts)
    |> validate_role()
    |> maybe_hash_password(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp validate_role(changeset) do
    changeset
    |> validate_inclusion(:role, @roles, message: "must be one of: #{Enum.join(@roles, ", ")}")
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, QrLabelSystem.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  A user changeset for changing the role.
  """
  def role_changeset(user, attrs) do
    user
    |> cast(attrs, [:role])
    |> validate_role()
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  # Role helper functions
  def admin?(%__MODULE__{role: "admin"}), do: true
  def admin?(_), do: false

  def operator?(%__MODULE__{role: role}) when role in ["admin", "operator"], do: true
  def operator?(_), do: false

  def viewer?(%__MODULE__{}), do: true
  def viewer?(_), do: false

  def roles, do: @roles
end
