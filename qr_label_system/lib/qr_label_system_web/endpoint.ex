defmodule QrLabelSystemWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :qr_label_system

  # Cache headers for static files based on environment
  # In development, we disable caching to ensure fresh assets are loaded
  @env Application.compile_env(:qr_label_system, :env)
  @static_cache_headers (case @env do
    :dev -> %{"cache-control" => "no-cache, no-store, must-revalidate"}
    _ -> %{}
  end)

  # The session will be stored in the cookie and signed and encrypted.
  # Session security configuration:
  # - signing_salt: Ensures session integrity (prevents tampering)
  # - encryption_salt: Encrypts session contents (prevents reading)
  # - same_site: "Strict" for better CSRF protection
  # - max_age: Session expiration time
  #
  # IMPORTANT: In production, these salts MUST be overridden via environment
  # variables in runtime.exs. Generate with: :crypto.strong_rand_bytes(32) |> Base.encode64()
  #
  # The values below are ONLY for development and testing.
  @session_options [
    store: :cookie,
    key: "_qr_label_system_key",
    signing_salt: "Kx8mP2qL9nR4vT7wY1zA3bC6dE8fG0hJ",
    encryption_salt: "Nq5rS8uV2xY4zA7bC0dE3fG6hI9jK1lM",
    same_site: "Strict",
    max_age: 60 * 60 * 24 * 7  # 7 days
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  #
  # In development, we disable caching to ensure fresh assets are loaded.
  plug Plug.Static,
    at: "/",
    from: :qr_label_system,
    gzip: false,
    only: QrLabelSystemWeb.static_paths(),
    headers: @static_cache_headers

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :qr_label_system
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # File upload limits: 10MB max per request, 10MB per field
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["text/*", "application/json", "multipart/form-data"],
    json_decoder: Phoenix.json_library(),
    length: 10_000_000,  # 10MB total request size
    multipart: [length: 10_000_000]  # 10MB per multipart field

  plug Plug.MethodOverride
  plug Plug.Head

  # Security headers for all responses
  plug :put_security_headers

  plug Plug.Session, @session_options
  plug QrLabelSystemWeb.Router

  @doc """
  Adds security headers to all responses.

  Headers added:
  - X-Content-Type-Options: Prevents MIME type sniffing
  - X-Frame-Options: Prevents clickjacking (SAMEORIGIN)
  - X-XSS-Protection: Legacy XSS protection for older browsers
  - Referrer-Policy: Controls referrer information
  - Strict-Transport-Security: Forces HTTPS (production only)
  - Permissions-Policy: Restricts browser features
  - Content-Security-Policy: Controls resource loading
  """
  def put_security_headers(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_header("x-content-type-options", "nosniff")
    |> Plug.Conn.put_resp_header("x-frame-options", "SAMEORIGIN")
    |> Plug.Conn.put_resp_header("x-xss-protection", "1; mode=block")
    |> Plug.Conn.put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> Plug.Conn.put_resp_header("permissions-policy", "geolocation=(), microphone=(), camera=()")
    |> put_csp_header()
    |> maybe_put_hsts_header()
  end

  # Content Security Policy header
  # Allows inline scripts/styles for Phoenix LiveView compatibility
  defp put_csp_header(conn) do
    csp = build_csp_policy()
    Plug.Conn.put_resp_header(conn, "content-security-policy", csp)
  end

  defp build_csp_policy do
    [
      "default-src 'self'",
      # Scripts: self + unsafe-inline for LiveView + unsafe-eval for some JS libs
      "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
      # Styles: self + unsafe-inline for Tailwind/dynamic styles
      "style-src 'self' 'unsafe-inline'",
      # Images: self + data URIs for QR codes + blob for canvas
      "img-src 'self' data: blob:",
      # Fonts: self + data URIs
      "font-src 'self' data:",
      # Connect: self for API calls + websockets
      "connect-src 'self' ws: wss:",
      # Frame ancestors: none (we use X-Frame-Options)
      "frame-ancestors 'self'",
      # Form actions: self only
      "form-action 'self'",
      # Base URI: self
      "base-uri 'self'",
      # Object/embed: none
      "object-src 'none'",
      # Upgrade insecure requests in production
      if Application.get_env(:qr_label_system, :env) == :prod do
        "upgrade-insecure-requests"
      end
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("; ")
  end

  # Only add HSTS header in production (when using HTTPS)
  defp maybe_put_hsts_header(conn) do
    if Application.get_env(:qr_label_system, :env) == :prod do
      Plug.Conn.put_resp_header(
        conn,
        "strict-transport-security",
        "max-age=31536000; includeSubDomains"
      )
    else
      conn
    end
  end
end
