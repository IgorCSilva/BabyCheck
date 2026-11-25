# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :api,
  ecto_repos: [Api.Repo],
  env: Mix.env()

# Configures the endpoint
config :api, ApiWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: ApiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Api.PubSub

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :api, Api.Guardian,
  issuer: "babycheck_api",
  ttl: {15, :minutes}

config :api, cors_origin: "http://localhost:3000"
config :api, web_base_url: "http://localhost:3000"

config :api, Api.Mailer, adapter: Swoosh.Adapters.Local

# Recomputes rolling averages / gap-reminder flags for every baby on a
# schedule, independent of anyone having the app open — the same job that
# will eventually drive Step 10's push notifications. The live chip values
# shown in the feed are computed fresh on each request (see `Api.Insights`),
# so this periodic pass only needs to be frequent enough for that future
# reminder consumer, not for UI freshness.
config :api, Oban,
  repo: Api.Repo,
  plugins: [
    {Oban.Plugins.Cron, crontab: [{"*/10 * * * *", Api.Insights.ComputeInsightsWorker}]},
    {Oban.Plugins.Pruner, max_age: 86_400}
  ],
  queues: [insights: 5]

# Used by Swoosh's HTTP-API-based adapters (e.g. Resend in prod); SMTP
# (dev/test, via Mailpit) doesn't need it and turns it off below.
config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
