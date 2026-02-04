defmodule QrLabelSystemWeb.Plugs.ApiAuth do
  @moduledoc """
  API Authentication plug.

  Validates API requests using Bearer tokens.
  Tokens must be Base64 URL-encoded session tokens.

  ## Token Format
  The Authorization header must contain a Bearer token that is the
  Base64 URL-encoded version of a valid session token.

  Example: Authorization: Bearer <base64_encoded_token>

  ## Security Notes
  - Tokens are validated against session tokens in the database
  - Empty or whitespace-only tokens are rejected
  - Only Base64 URL-encoded tokens are accepted (no raw tokens)
  - Token validation is constant-time to prevent timing attacks
  """
  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller

  alias QrLabelSystem.Accounts

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    authenticate_api(conn, [])
  end

  @doc """
  Authenticates API requests using Bearer token.

  Expects header: Authorization: Bearer <base64_encoded_token>

  Returns 401 Unauthorized for:
  - Missing Authorization header
  - Invalid header format (not "Bearer <token>")
  - Empty or whitespace-only token
  - Invalid Base64 encoding
  - Invalid or expired token
  """
  def authenticate_api(conn, _opts) do
    with {:ok, token} <- get_bearer_token(conn),
         {:ok, decoded_token} <- decode_token(token),
         {:ok, user} <- get_user_from_token(decoded_token) do
      conn
      |> assign(:current_user, user)
      |> assign(:api_token, decoded_token)
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
  Useful for endpoints that work for both authenticated and anonymous users.
  """
  def maybe_authenticate_api(conn, _opts) do
    with {:ok, token} <- get_bearer_token(conn),
         {:ok, decoded_token} <- decode_token(token),
         {:ok, user} <- get_user_from_token(decoded_token) do
      conn
      |> assign(:current_user, user)
      |> assign(:api_token, decoded_token)
    else
      {:error, _} ->
        assign(conn, :current_user, nil)
    end
  end

  # Private functions

  @doc false
  defp get_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      [auth_header] ->
        # Case-insensitive Bearer prefix matching
        case Regex.run(~r/^[Bb]earer\s+(.+)$/i, auth_header) do
          [_, token] ->
            # Trim whitespace and validate non-empty
            trimmed = String.trim(token)
            if trimmed == "" do
              {:error, "Empty token provided"}
            else
              {:ok, trimmed}
            end

          nil ->
            {:error, "Invalid authorization header format. Expected: Bearer <token>"}
        end

      [] ->
        {:error, "Missing authorization header"}

      _ ->
        {:error, "Multiple authorization headers not supported"}
    end
  end

  @doc false
  defp decode_token(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded} when byte_size(decoded) > 0 ->
        {:ok, decoded}

      {:ok, _empty} ->
        {:error, "Invalid token format"}

      :error ->
        # Also try with padding for compatibility
        case Base.url_decode64(token) do
          {:ok, decoded} when byte_size(decoded) > 0 ->
            {:ok, decoded}

          _ ->
            {:error, "Invalid token encoding. Token must be Base64 URL-encoded."}
        end
    end
  end

  @doc false
  defp get_user_from_token(decoded_token) do
    case Accounts.get_user_by_session_token(decoded_token) do
      nil -> {:error, "Invalid or expired token"}
      user -> {:ok, user}
    end
  end
end
