defmodule QrLabelSystemWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug using Hammer.

  Provides protection against brute force attacks and API abuse.

  Configuration:
  - Login attempts: 5 per minute per IP
  - API requests: 100 per minute per user/IP
  - File uploads: 10 per minute per user
  """
  import Plug.Conn
  import Phoenix.Controller

  @doc """
  Rate limits login attempts.
  5 attempts per minute per IP address.
  """
  def rate_limit_login(conn, _opts) do
    ip = get_client_ip(conn)
    key = "login:#{ip}"

    case Hammer.check_rate(key, 60_000, 5) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", "60")
        |> json(%{
          error: "Demasiados intentos de login. Intenta de nuevo en 1 minuto.",
          retry_after: 60
        })
        |> halt()
    end
  end

  @doc """
  Rate limits API requests.
  100 requests per minute per user (or IP if not authenticated).
  """
  def rate_limit_api(conn, _opts) do
    identifier = get_rate_limit_identifier(conn)
    key = "api:#{identifier}"

    case Hammer.check_rate(key, 60_000, 100) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", "60")
        |> json(%{
          error: "Rate limit exceeded. Please try again later.",
          retry_after: 60
        })
        |> halt()
    end
  end

  @doc """
  Rate limits file uploads.
  10 uploads per minute per user.
  """
  def rate_limit_uploads(conn, _opts) do
    identifier = get_rate_limit_identifier(conn)
    key = "upload:#{identifier}"

    case Hammer.check_rate(key, 60_000, 10) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{
          error: "Demasiadas subidas de archivo. Intenta de nuevo en 1 minuto.",
          retry_after: 60
        })
        |> halt()
    end
  end

  @doc """
  Rate limits batch generation.
  5 batch generations per minute per user.
  """
  def rate_limit_batch_generation(conn, _opts) do
    identifier = get_rate_limit_identifier(conn)
    key = "batch:#{identifier}"

    case Hammer.check_rate(key, 60_000, 5) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{
          error: "Demasiadas generaciones de lotes. Intenta de nuevo en 1 minuto.",
          retry_after: 60
        })
        |> halt()
    end
  end

  # Private functions

  defp get_rate_limit_identifier(conn) do
    case conn.assigns[:current_user] do
      nil -> "ip:#{get_client_ip(conn)}"
      user -> "user:#{user.id}"
    end
  end

  defp get_client_ip(conn) do
    # Check for forwarded IP (if behind proxy/load balancer)
    forwarded_for = get_req_header(conn, "x-forwarded-for")
    real_ip = get_req_header(conn, "x-real-ip")

    cond do
      forwarded_for != [] ->
        forwarded_for
        |> List.first()
        |> String.split(",")
        |> List.first()
        |> String.trim()

      real_ip != [] ->
        List.first(real_ip)

      true ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
end
