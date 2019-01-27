use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :zcms, ZcmsWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :zcms, Zcms.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "Test",
  password: "test",
  database: "captchaproxy_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
