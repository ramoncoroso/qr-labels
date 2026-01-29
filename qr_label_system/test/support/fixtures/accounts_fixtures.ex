defmodule QrLabelSystem.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `QrLabelSystem.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "Hello123!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> QrLabelSystem.Accounts.register_user()

    user
  end

  def admin_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{role: "admin"})
      |> valid_user_attributes()
      |> QrLabelSystem.Accounts.register_user()

    user
  end

  def operator_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{role: "operator"})
      |> valid_user_attributes()
      |> QrLabelSystem.Accounts.register_user()

    user
  end

  def viewer_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{role: "viewer"})
      |> valid_user_attributes()
      |> QrLabelSystem.Accounts.register_user()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
