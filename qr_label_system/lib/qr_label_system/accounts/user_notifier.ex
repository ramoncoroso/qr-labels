defmodule QrLabelSystem.Accounts.UserNotifier do
  @moduledoc """
  Email notifications for user accounts.
  """
  import Swoosh.Email

  alias QrLabelSystem.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"QR Label System", "noreply@qrlabelsystem.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver magic link instructions to log in to the account.
  """
  def deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Enlace de acceso - QR Label System", """

    ==============================

    Hola,

    Puedes acceder a tu cuenta haciendo clic en el enlace de abajo:

    #{url}

    Este enlace expira en 15 minutos y solo puede usarse una vez.

    Si no solicitaste este enlace, puedes ignorar este mensaje.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Instrucciones de confirmación - QR Label System", """

    ==============================

    Hola #{user.email},

    Puedes confirmar tu cuenta visitando el siguiente enlace:

    #{url}

    Si no creaste una cuenta, por favor ignora este mensaje.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Restablecer contraseña - QR Label System", """

    ==============================

    Hola #{user.email},

    Puedes restablecer tu contraseña visitando el siguiente enlace:

    #{url}

    Si no solicitaste este cambio, por favor ignora este mensaje.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Actualizar email - QR Label System", """

    ==============================

    Hola #{user.email},

    Puedes cambiar tu email visitando el siguiente enlace:

    #{url}

    Si no solicitaste este cambio, por favor ignora este mensaje.

    ==============================
    """)
  end
end
