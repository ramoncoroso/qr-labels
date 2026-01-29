defmodule QrLabelSystemWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug using Hammer.

  Provides protection against brute force attacks and API abuse.

  ## Configuration
  - Login attempts: 5 per minute per IP
  - API requests: 100 per minute per user/IP
  - File uploads: 10 per minute per user
  - Batch generation: 5 per minute per user

  ## Security Notes
  - X-Forwarded-For headers are ONLY trusted from configured proxy IPs
  - By default, uses conn.remote_ip for rate limiting
  - Configure TRUSTED_PROXIES environment variable in production

  ## Production Setup
  Set environment variable with comma-separated proxy IPs:
    TRUSTED_PROXIES=10.0.0.1,10.0.0.2,192.168.1.1

  If not set, X-Forwarded-For headers are ignored for security.
  """
  import Plug.Conn
  import Phoenix.Controller
  import Bitwise

  @retry_after_seconds 60
  @default_window_ms 60_000

  # Rate limits per endpoint type
  @login_limit 5
  @api_limit 100
  @upload_limit 10
  @batch_limit 5

  @doc """
  Rate limits login attempts.
  #{@login_limit} attempts per minute per IP address.
  """
  def rate_limit_login(conn, _opts) do
    ip = get_client_ip(conn)
    key = "login:#{ip}"

    case Hammer.check_rate(key, @default_window_ms, @login_limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        rate_limited_response(conn, "Demasiados intentos de login. Intenta de nuevo en 1 minuto.")
    end
  end

  @doc """
  Rate limits API requests.
  #{@api_limit} requests per minute per user (or IP if not authenticated).
  """
  def rate_limit_api(conn, _opts) do
    identifier = get_rate_limit_identifier(conn)
    key = "api:#{identifier}"

    case Hammer.check_rate(key, @default_window_ms, @api_limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        rate_limited_response(conn, "Rate limit exceeded. Please try again later.")
    end
  end

  @doc """
  Rate limits file uploads.
  #{@upload_limit} uploads per minute per user.
  """
  def rate_limit_uploads(conn, _opts) do
    identifier = get_rate_limit_identifier(conn)
    key = "upload:#{identifier}"

    case Hammer.check_rate(key, @default_window_ms, @upload_limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        rate_limited_response(conn, "Demasiadas subidas de archivo. Intenta de nuevo en 1 minuto.")
    end
  end

  @doc """
  Rate limits batch generation.
  #{@batch_limit} batch generations per minute per user.
  """
  def rate_limit_batch_generation(conn, _opts) do
    identifier = get_rate_limit_identifier(conn)
    key = "batch:#{identifier}"

    case Hammer.check_rate(key, @default_window_ms, @batch_limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        rate_limited_response(conn, "Demasiadas generaciones de lotes. Intenta de nuevo en 1 minuto.")
    end
  end

  # Private functions

  defp rate_limited_response(conn, message) do
    conn
    |> put_status(:too_many_requests)
    |> put_resp_header("retry-after", Integer.to_string(@retry_after_seconds))
    |> json(%{
      error: message,
      retry_after: @retry_after_seconds
    })
    |> halt()
  end

  defp get_rate_limit_identifier(conn) do
    case conn.assigns[:current_user] do
      nil -> "ip:#{get_client_ip(conn)}"
      user -> "user:#{user.id}"
    end
  end

  @doc """
  Gets the client IP address securely.

  Security: X-Forwarded-For and X-Real-IP headers are ONLY trusted
  if the request comes from a configured trusted proxy IP.

  This prevents attackers from spoofing their IP by sending fake headers.
  """
  def get_client_ip(conn) do
    remote_ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    if trusted_proxy?(remote_ip) do
      # Only trust forwarded headers from known proxies
      extract_forwarded_ip(conn) || remote_ip
    else
      # Direct connection - use remote_ip only
      remote_ip
    end
  end

  defp extract_forwarded_ip(conn) do
    # Try X-Forwarded-For first (standard), then X-Real-IP (Nginx)
    forwarded_for = get_req_header(conn, "x-forwarded-for")
    real_ip = get_req_header(conn, "x-real-ip")

    cond do
      forwarded_for != [] ->
        # X-Forwarded-For format: client, proxy1, proxy2
        # The first IP is the original client
        forwarded_for
        |> List.first()
        |> String.split(",")
        |> List.first()
        |> String.trim()
        |> validate_ip()

      real_ip != [] ->
        real_ip
        |> List.first()
        |> String.trim()
        |> validate_ip()

      true ->
        nil
    end
  end

  defp validate_ip(ip_string) do
    # Validate IP format to prevent injection
    case :inet.parse_address(String.to_charlist(ip_string)) do
      {:ok, _} -> ip_string
      {:error, _} -> nil
    end
  end

  defp trusted_proxy?(ip) do
    trusted_proxies = get_trusted_proxies()

    cond do
      # Empty list means no proxies trusted (most secure default)
      trusted_proxies == [] -> false

      # Check if IP is in trusted list
      ip in trusted_proxies -> true

      # Check for CIDR ranges (e.g., "10.0.0.0/8")
      Enum.any?(trusted_proxies, &ip_in_cidr?(ip, &1)) -> true

      true -> false
    end
  end

  defp get_trusted_proxies do
    # Cache in persistent_term for performance
    case :persistent_term.get({__MODULE__, :trusted_proxies}, :not_set) do
      :not_set ->
        proxies = parse_trusted_proxies()
        :persistent_term.put({__MODULE__, :trusted_proxies}, proxies)
        proxies

      proxies ->
        proxies
    end
  end

  defp parse_trusted_proxies do
    case System.get_env("TRUSTED_PROXIES") do
      nil -> []
      "" -> []
      proxies_string ->
        proxies_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end

  defp ip_in_cidr?(ip, cidr) do
    # Simple CIDR check - supports common private ranges
    case String.split(cidr, "/") do
      [base_ip, mask_str] ->
        case Integer.parse(mask_str) do
          {mask, ""} when mask >= 0 and mask <= 32 ->
            check_cidr_match(ip, base_ip, mask)
          _ -> false
        end
      [single_ip] ->
        ip == single_ip
      _ -> false
    end
  end

  defp check_cidr_match(ip, base_ip, mask) do
    with {:ok, ip_tuple} <- :inet.parse_address(String.to_charlist(ip)),
         {:ok, base_tuple} <- :inet.parse_address(String.to_charlist(base_ip)) do
      ip_int = tuple_to_int(ip_tuple)
      base_int = tuple_to_int(base_tuple)
      mask_int = 0xFFFFFFFF <<< (32 - mask) &&& 0xFFFFFFFF
      (ip_int &&& mask_int) == (base_int &&& mask_int)
    else
      _ -> false
    end
  end

  defp tuple_to_int({a, b, c, d}) do
    a <<< 24 ||| b <<< 16 ||| c <<< 8 ||| d
  end
end
