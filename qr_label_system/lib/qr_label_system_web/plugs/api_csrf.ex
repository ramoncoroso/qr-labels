defmodule QrLabelSystemWeb.Plugs.ApiCsrf do
  @moduledoc """
  CSRF protection for API endpoints using double-submit cookie pattern.

  This plug implements CSRF protection for API requests by:
  1. Setting a CSRF token in a cookie on GET requests
  2. Validating that the X-CSRF-Token header matches the cookie on mutating requests

  ## Usage

  Add to your router pipeline:

      pipeline :api_with_csrf do
        plug :accepts, ["json"]
        plug QrLabelSystemWeb.Plugs.ApiCsrf
      end

  ## Client Implementation

  1. Make a GET request to get the CSRF cookie
  2. Read the `_csrf_token` cookie value
  3. Include it in the `X-CSRF-Token` header for POST/PUT/PATCH/DELETE requests

  ## Configuration

  Configure in your config:

      config :qr_label_system, QrLabelSystemWeb.Plugs.ApiCsrf,
        cookie_name: "_csrf_token",
        header_name: "x-csrf-token",
        cookie_options: [http_only: false, same_site: "Strict"]
  """
  import Plug.Conn

  @behaviour Plug

  @default_cookie_name "_csrf_token"
  @default_header_name "x-csrf-token"
  @token_size 32
  @safe_methods ~w(GET HEAD OPTIONS)

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if safe_method?(conn) do
      ensure_csrf_cookie(conn)
    else
      validate_csrf_token(conn)
    end
  end

  @doc """
  Generates a new CSRF token.
  """
  def generate_token do
    :crypto.strong_rand_bytes(@token_size)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Gets the CSRF token from the cookie.
  """
  def get_csrf_token(conn) do
    conn = fetch_cookies(conn)
    conn.cookies[cookie_name()]
  end

  # Private functions

  defp safe_method?(conn) do
    conn.method in @safe_methods
  end

  defp ensure_csrf_cookie(conn) do
    conn = fetch_cookies(conn)

    case conn.cookies[cookie_name()] do
      nil ->
        token = generate_token()
        put_csrf_cookie(conn, token)

      _existing ->
        conn
    end
  end

  defp put_csrf_cookie(conn, token) do
    opts = cookie_options()
    put_resp_cookie(conn, cookie_name(), token, opts)
  end

  defp validate_csrf_token(conn) do
    conn = fetch_cookies(conn)

    cookie_token = conn.cookies[cookie_name()]
    header_token = get_csrf_header(conn)

    cond do
      is_nil(cookie_token) ->
        csrf_error(conn, "Missing CSRF cookie. Make a GET request first to obtain the token.")

      is_nil(header_token) ->
        csrf_error(conn, "Missing X-CSRF-Token header")

      not secure_compare(cookie_token, header_token) ->
        csrf_error(conn, "Invalid CSRF token")

      true ->
        conn
    end
  end

  defp get_csrf_header(conn) do
    case get_req_header(conn, header_name()) do
      [token | _] -> token
      [] -> nil
    end
  end

  defp csrf_error(conn, message) do
    conn
    |> put_status(:forbidden)
    |> Phoenix.Controller.json(%{error: message, code: "csrf_error"})
    |> halt()
  end

  # Constant-time comparison to prevent timing attacks
  defp secure_compare(a, b) when is_binary(a) and is_binary(b) do
    byte_size(a) == byte_size(b) and :crypto.hash_equals(a, b)
  end

  defp secure_compare(_, _), do: false

  defp cookie_name do
    Application.get_env(:qr_label_system, __MODULE__, [])
    |> Keyword.get(:cookie_name, @default_cookie_name)
  end

  defp header_name do
    Application.get_env(:qr_label_system, __MODULE__, [])
    |> Keyword.get(:header_name, @default_header_name)
  end

  defp cookie_options do
    default_opts = [
      http_only: false,  # Must be readable by JavaScript
      secure: Application.get_env(:qr_label_system, :env) == :prod,
      same_site: "Strict",
      max_age: 60 * 60 * 24  # 24 hours
    ]

    Application.get_env(:qr_label_system, __MODULE__, [])
    |> Keyword.get(:cookie_options, default_opts)
  end
end
