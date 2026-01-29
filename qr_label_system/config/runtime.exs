import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# temporary table. Therefore, you should not introduce any compile-time
# configuration changes here, like defining new modules

# Configure Hammer rate limiter backend (works in all environments)
# Using ETS backend - for distributed systems, use Redis backend
config :hammer,
  backend: {Hammer.Backend.ETS, [
    expiry_ms: 60_000 * 60 * 2,  # 2 hours
    cleanup_interval_ms: 60_000 * 10  # 10 minutes
  ]}

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :qr_label_system, QrLabelSystem.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # Session security salts - MUST be set in production
  # Generate with: :crypto.strong_rand_bytes(32) |> Base.encode64()
  signing_salt =
    System.get_env("SESSION_SIGNING_SALT") ||
      raise """
      environment variable SESSION_SIGNING_SALT is missing.
      Generate one with: :crypto.strong_rand_bytes(32) |> Base.encode64()
      """

  encryption_salt =
    System.get_env("SESSION_ENCRYPTION_SALT") ||
      raise """
      environment variable SESSION_ENCRYPTION_SALT is missing.
      Generate one with: :crypto.strong_rand_bytes(32) |> Base.encode64()
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :qr_label_system, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :qr_label_system, QrLabelSystemWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true,
    # Override session options with environment salts
    session_options: [
      store: :cookie,
      key: "_qr_label_system_key",
      signing_salt: signing_salt,
      encryption_salt: encryption_salt,
      same_site: "Strict",
      max_age: 60 * 60 * 24 * 7  # 7 days
    ]

  # Cloak encryption key from environment
  cloak_key =
    System.get_env("CLOAK_KEY") ||
      raise """
      environment variable CLOAK_KEY is missing.
      Generate one with: :crypto.strong_rand_bytes(32) |> Base.encode64()
      """

  config :qr_label_system, QrLabelSystem.Vault,
    ciphers: [
      default: {
        Cloak.Ciphers.AES.GCM,
        tag: "AES.GCM.V1",
        key: Base.decode64!(cloak_key),
        iv_length: 12
      }
    ]

  # Swoosh SMTP configuration for production
  # Configure these environment variables for your email provider
  if System.get_env("SMTP_HOST") do
    config :qr_label_system, QrLabelSystem.Mailer,
      adapter: Swoosh.Adapters.SMTP,
      relay: System.get_env("SMTP_HOST"),
      port: String.to_integer(System.get_env("SMTP_PORT") || "587"),
      username: System.get_env("SMTP_USERNAME"),
      password: System.get_env("SMTP_PASSWORD"),
      ssl: System.get_env("SMTP_SSL") == "true",
      tls: :if_available,
      auth: :always
  end
end
