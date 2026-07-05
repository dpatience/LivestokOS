import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :livestok_os_core, LivestokOs.Repo,
  username: "postgres",
  password: "Patience@159!",
  hostname: "localhost",
  database: "livestok_os_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :livestok_os_web, LivestokOsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "+rmJaIZ+JcRfXQTv+ExXTIJ7WSj8ejL071RjYHqWfYiHbyw9cAx2q1g0UcoryjaM",
  server: false

# In test we don't send emails
config :livestok_os_web, LivestokOs.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Oban: inline mode runs jobs synchronously in tests (no background workers needed)
config :livestok_os_ingest, Oban, testing: :inline

# Disable the periodic GrazingPressureWorker in tests to avoid spurious DB
# queries and scheduling noise during the test suite.
config :livestok_os_ops, start_grazing_worker: false

# AI app: use mock LLM client in tests
config :livestok_os_ai, :llm_client, LivestokOs.AI.MockLLMClient
config :livestok_os_ai, :llm_api_key, "test-key"
config :livestok_os_ai, :llm_api_base_url, "http://localhost:9999/v1"
