# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :d9s,
  ecto_repos: [D9s.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :d9s, D9sWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: D9sWeb.ErrorHTML, json: D9sWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: D9s.PubSub,
  live_view: [signing_salt: "sbC384mo"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :d9s, D9s.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  d9s: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  d9s: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :d9s, Oban,
  engine: Oban.Engines.Lite,
  queues: [default: 10, cleanup: 1],
  repo: D9s.Repo,
  notifier: Oban.Notifiers.PG,
  plugins: [
    {Oban.Plugins.Pruner, max_age: _thirty_days = 30 * 24 * 60 * 60},
    {D9s.JobTrains.CleanupPlugin, interval: :timer.minutes(5)}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
