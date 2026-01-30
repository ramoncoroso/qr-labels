import Config

# Mark this as development environment
config :qr_label_system, env: :dev

# Configure your database
config :qr_label_system, QrLabelSystem.Repo,
  username: "coroso",
  password: "",
  hostname: "localhost",
  database: "qr_label_system_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable debugging
config :qr_label_system, QrLabelSystemWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_at_least_64_bytes_long_for_development_only_do_not_use_in_production",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading
config :qr_label_system, QrLabelSystemWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/qr_label_system_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :qr_label_system, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Disable Oban in dev for simplicity
config :qr_label_system, Oban, testing: :inline

# Swoosh local adapter for development (view emails at /dev/mailbox)
config :qr_label_system, QrLabelSystem.Mailer, adapter: Swoosh.Adapters.Local

# Development encryption key (DO NOT use in production)
config :qr_label_system, QrLabelSystem.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      # This is a development-only key, generated with :crypto.strong_rand_bytes(32) |> Base.encode64()
      key: Base.decode64!("L7vYmJbxq3h5QZF9nK2wR8tP4uA6sDfG1jK3lO5pN0M="),
      iv_length: 12
    }
  ]
