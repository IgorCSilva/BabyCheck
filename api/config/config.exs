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

# Used by Swoosh's HTTP-API-based adapters (e.g. Resend in prod); SMTP
# (dev/test, via Mailpit) doesn't need it and turns it off below.
config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
