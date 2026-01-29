defmodule QrLabelSystemWeb.Plugs.ApiAuth do
  @moduledoc """
  API Authentication plug.

  Validates API requests using Bearer tokens.
  Tokens are the same session tokens used for web authentication.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias QrLabelSystem.Accounts

  @doc """
  Authenticates API requests using Bearer token.

  Expects header: Authorization: Bearer <token>
  """
  def authenticate_api(conn, _opts) do
    with {:ok, token} <- get_bearer_token(conn),
         {:ok, user} <- get_user_from_token(token) do
      conn
      |> assign(:current_user, user)
      |> assign(:api_token, token)
    else
      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: reason})
        |> halt()
    end
  end

  @doc """
  Optional API authentication - doesn't halt if no token provided.
  """
  def maybe_authenticate_api(conn, _opts) do
    case get_bearer_token(conn) do
      {:ok, token} ->
        case get_user_from_token(token) do
          {:ok, user} ->
            conn
            |> assign(:current_user, user)
            |> assign(:api_token, token)

          {:error, _} ->
            assign(conn, :current_user, nil)
        end

      {:error, _} ->
        assign(conn, :current_user, nil)
    end
  end

  # Private functions

  defp get_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      ["bearer " <> token] -> {:ok, token}
      [] -> {:error, "Missing authorization header"}
      _ -> {:error, "Invalid authorization header format"}
    end
  end

  defp get_user_from_token(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        case Accounts.get_user_by_session_token(decoded_token) do
          nil -> {:error, "Invalid or expired token"}
          user -> {:ok, user}
        end

      :error ->
        # Try as raw token (for compatibility)
        case Accounts.get_user_by_session_token(token) do
          nil -> {:error, "Invalid or expired token"}
          user -> {:ok, user}
        end
    end
  end
end
