defmodule QrLabelSystemWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :qr_label_system

  # The session will be stored in the cookie and signed and encrypted.
  # Session security configuration:
  # - signing_salt: Ensures session integrity (prevents tampering)
  # - encryption_salt: Encrypts session contents (prevents reading)
  # - same_site: "Strict" for better CSRF protection
  # - max_age: Session expiration time
  #
  # IMPORTANT: In production, override these salts via environment variables
  # Generate with: mix phx.gen.secret 32
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
  plug Plug.Static,
    at: "/",
    from: :qr_label_system,
    gzip: false,
    only: QrLabelSystemWeb.static_paths()

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

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug QrLabelSystemWeb.Router
end
