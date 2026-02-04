import Config

# Mark this as test environment
config :qr_label_system, env: :test

# Configure your database
config :qr_label_system, QrLabelSystem.Repo,
  username: "coroso",
  password: "",
  hostname: "localhost",
  database: "qr_label_system_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test
config :qr_label_system, QrLabelSystemWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_for_testing_only_not_for_production_use_at_least_64_bytes",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Disable Oban during tests
config :qr_label_system, Oban, testing: :manual

# Reduce bcrypt rounds for faster tests
config :bcrypt_elixir, log_rounds: 1

# Swoosh test adapter
config :qr_label_system, QrLabelSystem.Mailer, adapter: Swoosh.Adapters.Test

# Test encryption key (DO NOT use in production)
config :qr_label_system, QrLabelSystem.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      # This is a test-only key
      key: Base.decode64!("qmirOjOMQ6BfH2RmVNiWQqKMfvLJTe+8nDWk7XH3lEI="),
      iv_length: 12
    }
  ]
