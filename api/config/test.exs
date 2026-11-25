import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :api, Api.Repo,
  username: "babycheck",
  password: "babycheck",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  database: "babycheck_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :api, Api.Guardian, secret_key: "test_guardian_secret_change_me_test_guardian_secret"

config :api, Api.Mailer, adapter: Swoosh.Adapters.Test
config :swoosh, :api_client, false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :api, ApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "xGwkwczJVFFGNgDQPPuimj/6/CzR1ZIOTzq10077E7MNBvSwVYxydUyjbm0lQBS3",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
