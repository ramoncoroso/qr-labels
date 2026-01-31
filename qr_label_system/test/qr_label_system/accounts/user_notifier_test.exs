defmodule QrLabelSystem.Accounts.UserNotifierTest do
  use ExUnit.Case, async: true

  import Swoosh.TestAssertions

  alias QrLabelSystem.Accounts.UserNotifier

  describe "deliver_magic_link_instructions/2" do
    test "delivers magic link email" do
      user = %{email: "test@example.com"}
      url = "http://localhost:4000/magic-link/abc123"

      {:ok, email} = UserNotifier.deliver_magic_link_instructions(user, url)

      assert email.to == [{"", "test@example.com"}]
      assert email.subject == "Enlace de acceso - QR Label System"
      assert email.text_body =~ url
      assert email.text_body =~ "15 minutos"
    end

    test "includes correct sender" do
      user = %{email: "test@example.com"}

      {:ok, email} = UserNotifier.deliver_magic_link_instructions(user, "http://example.com")

      assert email.from == {"QR Label System", "noreply@qrlabelsystem.com"}
    end
  end

  describe "deliver_confirmation_instructions/2" do
    test "delivers confirmation email" do
      user = %{email: "newuser@example.com"}
      url = "http://localhost:4000/confirm/token123"

      {:ok, email} = UserNotifier.deliver_confirmation_instructions(user, url)

      assert email.to == [{"", "newuser@example.com"}]
      assert email.subject == "Instrucciones de confirmación - QR Label System"
      assert email.text_body =~ url
      assert email.text_body =~ "confirmar tu cuenta"
    end

    test "includes user email in body" do
      user = %{email: "user@test.com"}

      {:ok, email} = UserNotifier.deliver_confirmation_instructions(user, "http://example.com")

      assert email.text_body =~ "user@test.com"
    end
  end

  describe "deliver_reset_password_instructions/2" do
    test "delivers password reset email" do
      user = %{email: "forgot@example.com"}
      url = "http://localhost:4000/reset-password/token456"

      {:ok, email} = UserNotifier.deliver_reset_password_instructions(user, url)

      assert email.to == [{"", "forgot@example.com"}]
      assert email.subject == "Restablecer contraseña - QR Label System"
      assert email.text_body =~ url
      assert email.text_body =~ "restablecer tu contraseña"
    end

    test "includes user email in body" do
      user = %{email: "forgot@test.com"}

      {:ok, email} = UserNotifier.deliver_reset_password_instructions(user, "http://example.com")

      assert email.text_body =~ "forgot@test.com"
    end
  end

  describe "deliver_update_email_instructions/2" do
    test "delivers email update instructions" do
      user = %{email: "current@example.com"}
      url = "http://localhost:4000/update-email/token789"

      {:ok, email} = UserNotifier.deliver_update_email_instructions(user, url)

      assert email.to == [{"", "current@example.com"}]
      assert email.subject == "Actualizar email - QR Label System"
      assert email.text_body =~ url
      assert email.text_body =~ "cambiar tu email"
    end

    test "includes user email in body" do
      user = %{email: "update@test.com"}

      {:ok, email} = UserNotifier.deliver_update_email_instructions(user, "http://example.com")

      assert email.text_body =~ "update@test.com"
    end
  end
end
