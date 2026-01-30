import Config

# Mark this as production environment
config :qr_label_system, env: :prod

# For production, don't forget to configure the url host
config :qr_label_system, QrLabelSystemWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
