# General application configuration
import Config

config :qr_label_system,
  ecto_repos: [QrLabelSystem.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :qr_label_system, QrLabelSystemWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: QrLabelSystemWeb.ErrorHTML, json: QrLabelSystemWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: QrLabelSystem.PubSub,
  live_view: [signing_salt: "qr_label_hospital_2024"]

# Configure esbuild
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind
config :tailwind,
  version: "3.4.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Oban configuration
config :qr_label_system, Oban,
  repo: QrLabelSystem.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, cleanup: 5]

# Cloak encryption vault
config :qr_label_system, QrLabelSystem.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key: Base.decode64!("your-32-byte-key-base64-encoded-here=="),
      iv_length: 12
    }
  ]

# Import environment specific config
import_config "#{config_env()}.exs"
