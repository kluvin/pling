# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :pling,
  ecto_repos: [Pling.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure Gettext
config :pling, PlingWeb.Gettext,
  default_locale: "nb",
  locales: ~w(en nb)

# Configures the endpoint
config :pling, PlingWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  server: true,
  render_errors: [
    formats: [html: PlingWeb.ErrorHTML, json: PlingWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Pling.PubSub,
  live_view: [signing_salt: "Kv4Mctnk"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :pling, Pling.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  pling: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.0",
  pling: [
    args: ~w(
      --input=assets/css/app.css
      --output=./priv/static/assets/app.css
    ),
    cd: Path.expand("../", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# config :phoenix_analytics,
#   duckdb_path: System.get_env("DUCKDB_PATH"),
#   app_domain: System.get_env("PHX_HOST") || "https://pling.fly.dev"

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
