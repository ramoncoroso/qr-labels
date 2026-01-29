defmodule QrLabelSystemWeb.UserSessionController do
  use QrLabelSystemWeb, :controller

  alias QrLabelSystem.Accounts
  alias QrLabelSystemWeb.UserAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Cuenta creada exitosamente!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Contraseña actualizada exitosamente!")
  end

  def create(conn, params) do
    create(conn, params, "Bienvenido!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      conn
      |> put_flash(:error, "Email o contraseña inválidos")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Sesión cerrada exitosamente.")
    |> UserAuth.log_out_user()
  end
end
